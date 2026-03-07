class_name DungeonStateClass
extends Node

enum CrawlStatus { INACTIVE, MAP, BATTLE, REWARD, WON, LOST }

const BASE_MAP_WIDTH := 9
const BASE_MAP_HEIGHT := 9
const MAX_MAP_WIDTH := 13
const MAX_MAP_HEIGHT := 13
const VIEWPORT_WIDTH := 5
const VIEWPORT_HEIGHT := 5
const START_HP := 12

var seed: int = 0
var floor_index: int = 1
var max_hp: int = START_HP
var player_hp: int = START_HP
var gold: int = 0
var status: CrawlStatus = CrawlStatus.INACTIVE
var map_width: int = BASE_MAP_WIDTH
var map_height: int = BASE_MAP_HEIGHT
var player_index: int = 0
var current_room_index: int = -1
var tiles: Array = []
var discovered: Array[bool] = []
var equipment_ids: Array[String] = []
var pending_enemy: Dictionary = {}
var last_reward_options: Array = []


func reset() -> void:
	seed = 0
	floor_index = 1
	max_hp = START_HP
	player_hp = START_HP
	gold = 0
	status = CrawlStatus.INACTIVE
	map_width = BASE_MAP_WIDTH
	map_height = BASE_MAP_HEIGHT
	player_index = 0
	current_room_index = -1
	tiles.clear()
	discovered.clear()
	equipment_ids.clear()
	pending_enemy.clear()
	last_reward_options.clear()


func start_new_run(seed_value: int = -1) -> void:
	reset()
	seed = seed_value if seed_value >= 0 else int(Time.get_unix_time_from_system())
	generate_floor()
	status = CrawlStatus.MAP


func generate_floor() -> void:
	seed(seed + floor_index * 97)
	var size_step: int = int((floor_index - 1) / 2) * 2
	map_width = mini(BASE_MAP_WIDTH + size_step, MAX_MAP_WIDTH)
	map_height = mini(BASE_MAP_HEIGHT + size_step, MAX_MAP_HEIGHT)
	player_index = _index(int(map_height / 2), int(map_width / 2))
	current_room_index = -1
	pending_enemy.clear()
	last_reward_options.clear()

	tiles.clear()
	for i in map_width * map_height:
		tiles.append({
			"index": i,
			"type": "empty",
			"visited": false,
		})

	_set_tile_type(player_index, "start")

	var stairs_index := _index(map_height - 1, map_width - 1)
	if stairs_index == player_index:
		stairs_index = _index(0, map_width - 1)
	_set_tile_type(stairs_index, "stairs")

	var reserved: Array[int] = [player_index, stairs_index]
	var map_growth_bonus: int = maxi(int((map_width - BASE_MAP_WIDTH) / 2), 0)
	var enemy_count: int = 5 + mini(floor_index - 1, 4) + map_growth_bonus
	for enemy_index in _pick_open_indices(enemy_count, reserved):
		_set_tile_type(enemy_index, "enemy")
		reserved.append(enemy_index)

	var treasure_count: int = 3 + mini(int((floor_index - 1) / 2), 2)
	for treasure_index in _pick_open_indices(treasure_count, reserved):
		_set_tile_type(treasure_index, "treasure")
		reserved.append(treasure_index)

	discovered.resize(map_width * map_height)
	discovered.fill(false)
	_reveal_around(player_index)
	status = CrawlStatus.MAP


func get_tile(index: int) -> Dictionary:
	if index < 0 or index >= tiles.size():
		return {}
	return tiles[index]


func get_remaining_enemy_count() -> int:
	var count := 0
	for tile in tiles:
		if String(tile.get("type", "")) == "enemy":
			count += 1
	return count


func get_page_count_x(view_width: int = VIEWPORT_WIDTH) -> int:
	return maxi(int(ceili(float(map_width) / maxf(float(view_width), 1.0))), 1)


func get_page_count_y(view_height: int = VIEWPORT_HEIGHT) -> int:
	return maxi(int(ceili(float(map_height) / maxf(float(view_height), 1.0))), 1)


func can_move_to(index: int) -> bool:
	if status != CrawlStatus.MAP:
		return false
	if index < 0 or index >= tiles.size():
		return false
	if index == player_index:
		return false
	return _is_adjacent(player_index, index)


func move_to(index: int) -> String:
	if not can_move_to(index):
		return "blocked"

	player_index = index
	_reveal_around(player_index)

	var tile: Dictionary = get_tile(index)
	var tile_type := String(tile.get("type", "empty"))
	match tile_type:
		"enemy":
			current_room_index = index
			pending_enemy = _registry_script().build_enemy_for_floor(floor_index)
			status = CrawlStatus.BATTLE
			return "enemy"
		"treasure":
			current_room_index = index
			last_reward_options = _registry_script().build_reward_options(self, false)
			status = CrawlStatus.REWARD
			return "treasure"
		"stairs":
			if get_remaining_enemy_count() > 0:
				return "stairs_locked"
			floor_index += 1
			generate_floor()
			return "stairs"
		_:
			return "empty"


func grant_equipment(equipment_id: String) -> void:
	if equipment_id == "" or equipment_id in equipment_ids:
		return
	equipment_ids.append(equipment_id)
	var item: Dictionary = _registry_script().get_equipment_data(equipment_id)
	if item.is_empty():
		return
	var hp_bonus := int(item.get("max_hp_bonus", 0))
	if hp_bonus > 0:
		max_hp += hp_bonus
		player_hp = mini(max_hp, player_hp + hp_bonus)
	var heal_on_pick := int(item.get("heal_on_pick", 0))
	if heal_on_pick > 0:
		heal(heal_on_pick)


func heal(amount: int) -> void:
	player_hp = mini(max_hp, player_hp + amount)


func apply_damage(amount: int) -> void:
	player_hp = maxi(player_hp - amount, 0)
	if player_hp <= 0:
		status = CrawlStatus.LOST


func get_player_damage_bonus(variant_id: String) -> int:
	var bonus := 0
	for equipment_id in equipment_ids:
		var item: Dictionary = _registry_script().get_equipment_data(equipment_id)
		bonus += int(item.get("damage_bonus", 0))
		var variant_bonus: Dictionary = item.get("variant_bonus", {})
		bonus += int(variant_bonus.get(variant_id, 0))
	return bonus


func get_enemy_damage_reduction() -> int:
	var reduction := 0
	for equipment_id in equipment_ids:
		var item: Dictionary = _registry_script().get_equipment_data(equipment_id)
		reduction += int(item.get("defense_bonus", 0))
	return reduction


func get_battle_gold_bonus() -> int:
	var bonus := 0
	for equipment_id in equipment_ids:
		var item: Dictionary = _registry_script().get_equipment_data(equipment_id)
		bonus += int(item.get("gold_bonus", 0))
	return bonus


func should_reveal_hint() -> bool:
	for equipment_id in equipment_ids:
		var item: Dictionary = _registry_script().get_equipment_data(equipment_id)
		if bool(item.get("reveal_hint", false)):
			return true
	return false


func complete_battle_win() -> void:
	if current_room_index >= 0:
		_set_tile_type(current_room_index, "cleared")
	gold += int(pending_enemy.get("gold_reward", 0)) + get_battle_gold_bonus()
	pending_enemy.clear()
	last_reward_options = _registry_script().build_reward_options(self, true)
	status = CrawlStatus.REWARD if not last_reward_options.is_empty() else CrawlStatus.MAP


func complete_reward_node_without_pick() -> void:
	_finish_reward_room()


func claim_reward(index: int) -> bool:
	if index < 0 or index >= last_reward_options.size():
		return false

	var option: Dictionary = last_reward_options[index]
	match String(option.get("reward_type", "")):
		"equipment":
			grant_equipment(String(option.get("payload_id", "")))
		"heal":
			heal(int(option.get("amount", 0)))
		"gold":
			gold += int(option.get("amount", 0))
		_:
			return false

	_finish_reward_room()
	return true


func get_equipment_descriptions() -> Array[String]:
	var result: Array[String] = []
	for equipment_id in equipment_ids:
		var item: Dictionary = _registry_script().get_equipment_data(equipment_id)
		if not item.is_empty():
			result.append("%s: %s" % [item.get("display_name", equipment_id), item.get("description", "")])
	return result


func _finish_reward_room() -> void:
	if current_room_index >= 0:
		var current_tile: Dictionary = get_tile(current_room_index)
		if String(current_tile.get("type", "")) == "treasure":
			_set_tile_type(current_room_index, "cleared")
	current_room_index = -1
	last_reward_options.clear()
	status = CrawlStatus.MAP


func _set_tile_type(index: int, tile_type: String) -> void:
	if index < 0 or index >= tiles.size():
		return
	var tile: Dictionary = tiles[index]
	tile["type"] = tile_type
	tiles[index] = tile


func _pick_open_indices(count: int, reserved: Array[int]) -> Array[int]:
	var pool: Array[int] = []
	for i in map_width * map_height:
		if i in reserved:
			continue
		pool.append(i)
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


func _reveal_around(index: int) -> void:
	var row := _row(index)
	var col := _col(index)
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			var next_row := row + dr
			var next_col := col + dc
			if next_row < 0 or next_row >= map_height or next_col < 0 or next_col >= map_width:
				continue
			var next_index := _index(next_row, next_col)
			discovered[next_index] = true


func _is_adjacent(a: int, b: int) -> bool:
	var row_delta := absi(_row(a) - _row(b))
	var col_delta := absi(_col(a) - _col(b))
	return row_delta + col_delta == 1


func _row(index: int) -> int:
	return index / map_width


func _col(index: int) -> int:
	return index % map_width


func _index(row: int, col: int) -> int:
	return row * map_width + col


func _registry_script() -> Script:
	return load("res://scripts/dungeon/dungeon_content_registry.gd")
