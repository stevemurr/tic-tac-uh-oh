class_name ComplicationRegistryClass
extends Node

var _all_complications: Array[ComplicationBase] = []


func _ready() -> void:
	_register_all()


func _register_all() -> void:
	_all_complications = [
		ShrinkingBoardComplication.new(),
		GravityComplication.new(),
		MirrorMovesComplication.new(),
		TheBombComplication.new(),
		RotatingBoardComplication.new(),
		StolenTurnComplication.new(),
		TimePressureComplication.new(),
		WildcardCellComplication.new(),
		DecayComplication.new(),
		AftershockComplication.new(),
		ChainReactionComplication.new(),
		InfectionComplication.new(),
	]


func get_all() -> Array[ComplicationBase]:
	return _all_complications


func get_by_id(id: String) -> ComplicationBase:
	for comp in _all_complications:
		if comp.complication_id == id:
			return comp
	return null


func pick_random(active_ids: Array[String]) -> ComplicationBase:
	var available: Array[ComplicationBase] = []
	for comp in _all_complications:
		if comp.complication_id in active_ids:
			continue
		# Check incompatibilities
		var dominated := false
		for active_id in active_ids:
			if active_id in comp.incompatible_with:
				dominated = true
				break
		if not dominated:
			available.append(comp)

	if available.is_empty():
		return null

	# Create a fresh instance so state is clean
	var picked := available[randi() % available.size()]
	return _create_fresh(picked.complication_id)


func _create_fresh(id: String) -> ComplicationBase:
	match id:
		"shrinking_board": return ShrinkingBoardComplication.new()
		"gravity": return GravityComplication.new()
		"mirror_moves": return MirrorMovesComplication.new()
		"the_bomb": return TheBombComplication.new()
		"rotating_board": return RotatingBoardComplication.new()
		"stolen_turn": return StolenTurnComplication.new()
		"time_pressure": return TimePressureComplication.new()
		"wildcard_cell": return WildcardCellComplication.new()
		"decay": return DecayComplication.new()
		"aftershock": return AftershockComplication.new()
		"chain_reaction": return ChainReactionComplication.new()
		"infection": return InfectionComplication.new()
	return null


func get_available_count(active_ids: Array[String]) -> int:
	var count := 0
	for comp in _all_complications:
		if comp.complication_id not in active_ids:
			count += 1
	return count
