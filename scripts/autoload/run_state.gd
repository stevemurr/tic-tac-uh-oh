class_name RunStateClass
extends Node

enum RunStatus { INACTIVE, MAP, IN_BATTLE, REWARD, WON, LOST }

var seed: int = 0
var act_index: int = 0
var resolve: int = 0
var max_resolve: int = 3
var sigils: int = 0
var charge: int = 0
var character_id: String = ""
var character = null
var equipped_runes: Array = []
var map_nodes: Array = []
var current_node_id: String = ""
var pending_encounter = null
var visited_node_ids: Array[String] = []
var last_reward_options: Array = []
var boss_phase: int = 0
var run_status: RunStatus = RunStatus.INACTIVE


func reset() -> void:
	seed = 0
	act_index = 0
	resolve = 0
	max_resolve = 3
	sigils = 0
	charge = 0
	character_id = ""
	character = null
	equipped_runes.clear()
	map_nodes.clear()
	current_node_id = ""
	pending_encounter = null
	visited_node_ids.clear()
	last_reward_options.clear()
	boss_phase = 0
	run_status = RunStatus.INACTIVE


func start_new_run(new_character_id: String, seed_value: int = -1) -> void:
	reset()
	seed = seed_value if seed_value >= 0 else int(Time.get_unix_time_from_system())
	act_index = 0
	max_resolve = 3
	resolve = max_resolve
	sigils = 0
	character_id = new_character_id
	character = _registry_script().create_character(character_id)
	if character == null:
		run_status = RunStatus.INACTIVE
		return

	grant_rune(character.starter_rune_id)
	character.on_run_start(self)
	generate_map()
	run_status = RunStatus.MAP


func generate_map() -> void:
	map_nodes = _map_generator_script().generate_outer_wall(seed)


func get_node_by_id(node_id: String):
	for node in map_nodes:
		if node.node_id == node_id:
			return node
	return null


func get_current_node():
	return get_node_by_id(current_node_id)


func select_node(node_id: String) -> bool:
	var node = get_node_by_id(node_id)
	if node == null or not node.available or node.visited:
		return false

	current_node_id = node_id
	last_reward_options.clear()
	pending_encounter = null

	if node.node_type in ["duel", "elite", "boss"]:
		pending_encounter = _registry_script().build_encounter_for_node(node)
		run_status = RunStatus.IN_BATTLE
	else:
		last_reward_options = _registry_script().build_noncombat_rewards(node.node_type, self)
		run_status = RunStatus.REWARD
	return true


func begin_encounter():
	return pending_encounter


func apply_battle_win(result: Dictionary) -> void:
	var node = get_current_node()
	if node == null:
		return

	sigils += int(result.get("sigils", 0))
	node.visited = true
	if node.node_id not in visited_node_ids:
		visited_node_ids.append(node.node_id)
	_unlock_from(node)
	pending_encounter = null

	if node.node_type == "boss":
		run_status = RunStatus.WON
		current_node_id = ""
		last_reward_options.clear()
		return

	last_reward_options = _registry_script().build_battle_rewards(self, int(result.get("reward_tier", node.reward_tier)))
	run_status = RunStatus.REWARD if not last_reward_options.is_empty() else RunStatus.MAP
	current_node_id = "" if run_status == RunStatus.MAP else current_node_id


func apply_battle_loss(result: Dictionary) -> void:
	resolve = maxi(resolve - int(result.get("resolve_damage", 1)), 0)
	pending_encounter = null
	last_reward_options.clear()
	if resolve <= 0:
		run_status = RunStatus.LOST
	else:
		run_status = RunStatus.MAP
	current_node_id = ""


func claim_reward(index: int) -> bool:
	if index < 0 or index >= last_reward_options.size():
		return false

	var option = last_reward_options[index]
	match option.reward_type:
		"rune":
			grant_rune(option.payload_id)
		"heal":
			resolve = mini(max_resolve, resolve + option.amount)
		"sigils":
			sigils += option.amount
		_:
			return false

	_complete_current_reward_node()
	return true


func complete_reward_node_without_pick() -> void:
	_complete_current_reward_node()


func has_rune(rune_id: String) -> bool:
	for rune in equipped_runes:
		if rune.rune_id == rune_id:
			return true
	return false


func grant_rune(rune_id: String) -> void:
	if rune_id == "" or has_rune(rune_id):
		return
	var rune = _registry_script().create_rune(rune_id)
	if rune == null:
		return
	equipped_runes.append(rune)
	rune.on_run_start(self)


func gain_charge(amount: int) -> void:
	if character == null:
		return
	charge = mini(charge + amount, character.max_charge)


func spend_charge(amount: int) -> bool:
	if charge < amount:
		return false
	charge -= amount
	return true


func _complete_current_reward_node() -> void:
	var node = get_current_node()
	if node:
		node.visited = true
		if node.node_id not in visited_node_ids:
			visited_node_ids.append(node.node_id)
		_unlock_from(node)
	last_reward_options.clear()
	current_node_id = ""
	run_status = RunStatus.MAP


func _unlock_from(node) -> void:
	for next_id in node.next_ids:
		var next_node = get_node_by_id(next_id)
		if next_node:
			next_node.available = true


func _registry_script() -> Script:
	return load("res://scripts/run/run_content_registry.gd")


func _map_generator_script() -> Script:
	return load("res://scripts/run/castle_map_generator.gd")
