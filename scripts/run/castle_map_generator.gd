class_name CastleMapGenerator
extends RefCounted

const MapNodeDataScript = preload("res://scripts/run/map_node_data.gd")


static func generate_outer_wall(_seed: int) -> Array:
	var nodes: Array = [
		MapNodeDataScript.new("gate", 0, "duel", "Gate Clash", 0, ["forge", "stairs"], "gate_clash", 1),
		MapNodeDataScript.new("forge", 1, "forge", "Siege Forge", -1, ["engine"], "", 1),
		MapNodeDataScript.new("stairs", 1, "duel", "Wall Stairs", 1, ["engine"], "wall_stairs", 1),
		MapNodeDataScript.new("engine", 2, "elite", "Siege Engine", 0, ["sanctum", "rampart"], "siege_engine", 2),
		MapNodeDataScript.new("sanctum", 3, "sanctum", "Chapel of Breath", -1, ["boss_gate"], "", 2),
		MapNodeDataScript.new("rampart", 3, "duel", "Rampart Duel", 1, ["boss_gate"], "rampart_duel", 2),
		MapNodeDataScript.new("boss_gate", 4, "boss", "Gate Warden", 0, [], "gate_warden", 3),
	]

	if not nodes.is_empty():
		nodes[0].available = true
	return nodes
