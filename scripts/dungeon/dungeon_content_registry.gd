class_name DungeonContentRegistry
extends RefCounted

const ENEMIES := [
	{
		"enemy_id": "cell_rat",
		"display_name": "Cell Rat",
		"description": "Quick scavenger that punishes missed reads.",
		"base_hp": 6,
		"base_damage": 2,
		"gold_reward": 14,
		"preferred_variants": ["line_strike", "shield_block"],
		"accent_color": Color(0.84, 0.52, 0.4, 1.0),
	},
	{
		"enemy_id": "fork_witch",
		"display_name": "Fork Witch",
		"description": "Twists the grid into double-threat setups.",
		"base_hp": 7,
		"base_damage": 2,
		"gold_reward": 18,
		"preferred_variants": ["fork_setup", "line_strike"],
		"accent_color": Color(0.58, 0.8, 0.56, 1.0),
	},
	{
		"enemy_id": "gate_guard",
		"display_name": "Gate Guard",
		"description": "Heavy bruiser that loves defensive puzzles.",
		"base_hp": 9,
		"base_damage": 3,
		"gold_reward": 22,
		"preferred_variants": ["shield_block", "fork_setup"],
		"accent_color": Color(0.86, 0.72, 0.46, 1.0),
	},
]

const EQUIPMENT := {
	"iron_blade": {
		"display_name": "Iron Blade",
		"description": "+1 damage in every puzzle duel.",
		"damage_bonus": 1,
		"color": Color(0.9, 0.72, 0.46, 1.0),
	},
	"tower_shield": {
		"display_name": "Tower Shield",
		"description": "Reduce incoming battle damage by 1.",
		"defense_bonus": 1,
		"color": Color(0.58, 0.72, 0.92, 1.0),
	},
	"lantern_lens": {
		"display_name": "Lantern Lens",
		"description": "Reveal one correct move in each puzzle.",
		"reveal_hint": true,
		"color": Color(0.96, 0.82, 0.54, 1.0),
	},
	"medic_satchel": {
		"display_name": "Medic Satchel",
		"description": "+2 max HP and heal 2 immediately.",
		"max_hp_bonus": 2,
		"heal_on_pick": 2,
		"color": Color(0.64, 0.9, 0.78, 1.0),
	},
	"forked_sigil": {
		"display_name": "Forked Sigil",
		"description": "+2 damage on fork puzzles.",
		"variant_bonus": {"fork_setup": 2},
		"color": Color(0.72, 0.58, 0.96, 1.0),
	},
	"bounty_ring": {
		"display_name": "Bounty Ring",
		"description": "+10 gold after each victory.",
		"gold_bonus": 10,
		"color": Color(0.94, 0.82, 0.52, 1.0),
	},
}


static func build_enemy_for_floor(floor_index: int) -> Dictionary:
	var base: Dictionary = ENEMIES[randi() % ENEMIES.size()].duplicate(true)
	base["current_hp"] = int(base.get("base_hp", 0)) + floor_index - 1
	base["base_damage"] = int(base.get("base_damage", 0)) + ((floor_index - 1) / 2)
	base["gold_reward"] = int(base.get("gold_reward", 0)) + (floor_index - 1) * 6
	base["floor_index"] = floor_index
	return base


static func build_reward_options(state, from_battle: bool) -> Array:
	var options: Array = []
	var equipment_pool: Array[String] = []
	for equipment_id in EQUIPMENT.keys():
		if equipment_id not in state.equipment_ids:
			equipment_pool.append(equipment_id)
	equipment_pool.shuffle()

	var equipment_count := mini(2, equipment_pool.size())
	for i in equipment_count:
		var item_id: String = equipment_pool[i]
		var item: Dictionary = get_equipment_data(item_id)
		options.append({
			"reward_type": "equipment",
			"payload_id": item_id,
			"display_name": item.get("display_name", item_id),
			"description": item.get("description", ""),
			"accent_color": item.get("color", Color.WHITE),
		})

	if from_battle:
		options.append({
			"reward_type": "heal",
			"amount": 3,
			"display_name": "Patch Up",
			"description": "Recover 3 HP before the next room.",
			"accent_color": Color(0.62, 0.92, 0.8, 1.0),
		})
	else:
		options.append({
			"reward_type": "gold",
			"amount": 20 + state.floor_index * 4,
			"display_name": "Pocket the Cache",
			"description": "Take a safer haul of gold instead of new gear.",
			"accent_color": Color(0.96, 0.8, 0.5, 1.0),
		})

	return options


static func get_equipment_data(equipment_id: String) -> Dictionary:
	return EQUIPMENT.get(equipment_id, {}).duplicate(true)
