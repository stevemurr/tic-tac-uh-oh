// Signaling server for WebRTC P2P matchmaking
// Run: deno run --allow-net server/signaling.ts
// Deploy: Deno Deploy free tier

const PORT = parseInt(Deno.env.get("PORT") || "8080");

interface Peer {
  ws: WebSocket;
  id: "host" | "client";
  lastActivity: number;
}

interface Room {
  code: string;
  peers: Map<string, Peer>;
  createdAt: number;
}

const rooms = new Map<string, Room>();
const ROOM_TIMEOUT_MS = 5 * 60 * 1000; // 5 minutes
const SWEEP_INTERVAL_MS = 30 * 1000;

function generateRoomCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // No I/O/0/1 to avoid confusion
  let code = "";
  for (let i = 0; i < 4; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  // Ensure uniqueness
  if (rooms.has(code)) return generateRoomCode();
  return code;
}

function send(ws: WebSocket, msg: Record<string, unknown>): void {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(msg));
  }
}

function getOtherPeer(room: Room, myId: string): Peer | undefined {
  for (const [id, peer] of room.peers) {
    if (id !== myId) return peer;
  }
  return undefined;
}

function removeFromRoom(room: Room, peerId: string): void {
  room.peers.delete(peerId);
  const other = getOtherPeer(room, peerId);
  if (other) {
    send(other.ws, { type: "peer_disconnected" });
  }
  if (room.peers.size === 0) {
    rooms.delete(room.code);
  }
}

function findRoomByWs(ws: WebSocket): { room: Room; peerId: string } | null {
  for (const room of rooms.values()) {
    for (const [id, peer] of room.peers) {
      if (peer.ws === ws) return { room, peerId: id };
    }
  }
  return null;
}

function handleMessage(ws: WebSocket, data: string): void {
  let msg: Record<string, unknown>;
  try {
    msg = JSON.parse(data);
  } catch {
    send(ws, { type: "error", message: "Invalid JSON" });
    return;
  }

  const type = msg.type as string;

  switch (type) {
    case "create_room": {
      // Check if already in a room
      const existing = findRoomByWs(ws);
      if (existing) {
        send(ws, { type: "error", message: "Already in a room" });
        return;
      }

      const code = generateRoomCode();
      const room: Room = {
        code,
        peers: new Map(),
        createdAt: Date.now(),
      };
      room.peers.set("host", { ws, id: "host", lastActivity: Date.now() });
      rooms.set(code, room);

      send(ws, { type: "room_created", room_code: code, peer_id: "host" });
      console.log(`Room ${code} created`);
      break;
    }

    case "join_room": {
      const existing = findRoomByWs(ws);
      if (existing) {
        send(ws, { type: "error", message: "Already in a room" });
        return;
      }

      const code = (msg.room_code as string || "").toUpperCase();
      const room = rooms.get(code);

      if (!room) {
        send(ws, { type: "error", message: "Room not found" });
        return;
      }

      if (room.peers.size >= 2) {
        send(ws, { type: "error", message: "Room is full" });
        return;
      }

      room.peers.set("client", { ws, id: "client", lastActivity: Date.now() });

      send(ws, { type: "room_joined", room_code: code, peer_id: "client" });

      // Notify host
      const host = room.peers.get("host");
      if (host) {
        send(host.ws, { type: "peer_joined", peer_id: "client" });
      }

      console.log(`Client joined room ${code}`);
      break;
    }

    case "signal": {
      const found = findRoomByWs(ws);
      if (!found) {
        send(ws, { type: "error", message: "Not in a room" });
        return;
      }

      found.room.peers.get(found.peerId)!.lastActivity = Date.now();

      const other = getOtherPeer(found.room, found.peerId);
      if (other) {
        send(other.ws, { type: "signal", data: msg.data });
      }
      break;
    }

    case "leave": {
      const found = findRoomByWs(ws);
      if (found) {
        console.log(`Peer ${found.peerId} left room ${found.room.code}`);
        removeFromRoom(found.room, found.peerId);
      }
      break;
    }

    default:
      send(ws, { type: "error", message: `Unknown type: ${type}` });
  }
}

function handleDisconnect(ws: WebSocket): void {
  const found = findRoomByWs(ws);
  if (found) {
    console.log(`Peer ${found.peerId} disconnected from room ${found.room.code}`);
    removeFromRoom(found.room, found.peerId);
  }
}

// Sweep stale rooms
setInterval(() => {
  const now = Date.now();
  for (const [code, room] of rooms) {
    let lastActivity = room.createdAt;
    for (const peer of room.peers.values()) {
      if (peer.lastActivity > lastActivity) {
        lastActivity = peer.lastActivity;
      }
    }
    if (now - lastActivity > ROOM_TIMEOUT_MS) {
      // Notify remaining peers
      for (const peer of room.peers.values()) {
        send(peer.ws, { type: "error", message: "Room timed out" });
        peer.ws.close();
      }
      rooms.delete(code);
      console.log(`Room ${code} timed out`);
    }
  }
}, SWEEP_INTERVAL_MS);

Deno.serve({ port: PORT }, (req) => {
  if (req.headers.get("upgrade") !== "websocket") {
    return new Response("WebSocket signaling server", { status: 200 });
  }

  const { socket, response } = Deno.upgradeWebSocket(req);

  socket.addEventListener("message", (event) => {
    handleMessage(socket, event.data as string);
  });

  socket.addEventListener("close", () => {
    handleDisconnect(socket);
  });

  socket.addEventListener("error", (e) => {
    console.error("WebSocket error:", e);
    handleDisconnect(socket);
  });

  return response;
});

console.log(`Signaling server running on port ${PORT}`);
