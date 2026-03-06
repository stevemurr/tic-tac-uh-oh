class_name RunContentRegistry
extends RefCounted

const ClocksmithCharacterScript = preload("res://scripts/run/characters/clocksmith.gd")
const PlagueScribeCharacterScript = preload("res://scripts/run/characters/plague_scribe.gd")
const BastionHeirCharacterScript = preload("res://scripts/run/characters/bastion_heir.gd")
const AnchorRuneScript = preload("res://scripts/run/runes/anchor_rune.gd")
const MirrorRuneScript = preload("res://scripts/run/runes/mirror_rune.gd")
const BloomRuneScript = preload("res://scripts/run/runes/bloom_rune.gd")
const FuseRuneScript = preload("res://scripts/run/runes/fuse_rune.gd")
const HourglassRuneScript = preload("res://scripts/run/runes/hourglass_rune.gd")
const RampartRuneScript = preload("res://scripts/run/runes/rampart_rune.gd")
const CrownRuneScript = preload("res://scripts/run/runes/crown_rune.gd")
const CastleKeyRuneScript = preload("res://scripts/run/runes/castle_key_rune.gd")
const WallGuardTraitScript = preload("res://scripts/run/enemies/wall_guard.gd")
const SiegeEngineTraitScript = preload("res://scripts/run/enemies/siege_engine.gd")
const GateWardenBossTraitScript = preload("res://scripts/run/enemies/gate_warden_boss.gd")
const RewardOptionScript = preload("res://scripts/run/reward_option.gd")
const EncounterProfileScript = preload("res://scripts/run/encounter_profile.gd")


static func get_all_characters() -> Array:
	return [
		ClocksmithCharacterScript.new(),
		PlagueScribeCharacterScript.new(),
		BastionHeirCharacterScript.new(),
	]


static func create_character(id: String):
	match id:
		"clocksmith":
			return ClocksmithCharacterScript.new()
		"plague_scribe":
			return PlagueScribeCharacterScript.new()
		"bastion_heir":
			return BastionHeirCharacterScript.new()
	return null


static func create_rune(id: String):
	match id:
		"anchor_rune":
			return AnchorRuneScript.new()
		"mirror_rune":
			return MirrorRuneScript.new()
		"bloom_rune":
			return BloomRuneScript.new()
		"fuse_rune":
			return FuseRuneScript.new()
		"hourglass_rune":
			return HourglassRuneScript.new()
		"rampart_rune":
			return RampartRuneScript.new()
		"crown_rune":
			return CrownRuneScript.new()
		"castle_key_rune":
			return CastleKeyRuneScript.new()
	return null


static func get_all_rune_ids() -> Array[String]:
	return [
		"anchor_rune",
		"mirror_rune",
		"bloom_rune",
		"fuse_rune",
		"hourglass_rune",
		"rampart_rune",
		"crown_rune",
		"castle_key_rune",
	]


static func create_enemy_trait(id: String):
	match id:
		"wall_guard":
			return WallGuardTraitScript.new()
		"siege_engine":
			return SiegeEngineTraitScript.new()
		"gate_warden_boss":
			return GateWardenBossTraitScript.new()
	return null


static func build_encounter_for_node(node):
	var encounter = EncounterProfileScript.new()
	encounter.encounter_id = node.encounter_id if node.encounter_id != "" else node.node_id
	encounter.display_name = node.title
	encounter.encounter_type = node.node_type
	encounter.reward_tier = node.reward_tier

	match node.node_type:
		"elite":
			encounter.board_size = 5
			encounter.win_length = 4
			encounter.ai_difficulty = GameState.Difficulty.HARD
			encounter.enemy_trait_id = "siege_engine"
			encounter.opening_complication_ids = ["gravity"]
			encounter.resolve_damage_on_loss = 2
		"boss":
			encounter.board_size = 5
			encounter.win_length = 4
			encounter.ai_difficulty = GameState.Difficulty.HARD
			encounter.enemy_trait_id = "gate_warden_boss"
			encounter.opening_complication_ids = ["gravity", "rotating_board"]
			encounter.resolve_damage_on_loss = 3
		_:
			encounter.board_size = 3 if node.floor <= 1 else 5
			encounter.win_length = 3 if encounter.board_size <= 3 else 4
			encounter.ai_difficulty = GameState.Difficulty.MEDIUM
			encounter.enemy_trait_id = "wall_guard"
			encounter.opening_complication_ids = []
			encounter.resolve_damage_on_loss = 1

	var enemy_trait = create_enemy_trait(encounter.enemy_trait_id)
	if enemy_trait:
		for comp_id in enemy_trait.get_opening_complication_ids():
			if comp_id not in encounter.opening_complication_ids:
				encounter.opening_complication_ids.append(comp_id)
	return encounter


static func build_battle_rewards(run_state: Node, tier: int) -> Array:
	var options: Array = []
	for rune_id in _pick_rune_rewards(run_state, 2):
		var rune = create_rune(rune_id)
		if rune:
			options.append(RewardOptionScript.new(
				"rune",
				rune.rune_id,
				0,
				rune.display_name,
				rune.description,
				rune.rarity
			))

	options.append(RewardOptionScript.new(
		"heal",
		"",
		1,
		"Restore Resolve",
		"Recover 1 resolve before the next battle.",
		"common"
	))
	if tier >= 2:
		options[options.size() - 1] = RewardOptionScript.new(
			"sigils",
			"",
			30 * tier,
			"Gather Sigils",
			"Take %d sigils back to the climb." % (30 * tier),
			"common"
		)
	return options


static func build_noncombat_rewards(node_type: String, run_state: Node) -> Array:
	var options: Array = []
	match node_type:
		"forge":
			for rune_id in _pick_rune_rewards(run_state, 3):
				var rune = create_rune(rune_id)
				if rune:
					options.append(RewardOptionScript.new(
						"rune",
						rune.rune_id,
						0,
						rune.display_name,
						rune.description,
						rune.rarity
					))
		"sanctum":
			options.append(RewardOptionScript.new(
				"heal",
				"",
				2,
				"Take Sanctuary",
				"Restore 2 resolve.",
				"common"
			))
			options.append(RewardOptionScript.new(
				"sigils",
				"",
				40,
				"Open the Offering Box",
				"Claim 40 sigils.",
				"common"
			))
			var rune_ids := _pick_rune_rewards(run_state, 1)
			if not rune_ids.is_empty():
				var rune = create_rune(rune_ids[0])
				if rune:
					options.append(RewardOptionScript.new(
						"rune",
						rune.rune_id,
						0,
						rune.display_name,
						rune.description,
						rune.rarity
					))
	return options


static func _pick_rune_rewards(run_state: Node, count: int) -> Array[String]:
	var available := get_all_rune_ids()
	if run_state and run_state.has_method("has_rune"):
		available = available.filter(func(id: String) -> bool: return not run_state.has_rune(id))

	var picked: Array[String] = []
	while picked.size() < count and not available.is_empty():
		picked.append(available.pop_front())
	return picked
