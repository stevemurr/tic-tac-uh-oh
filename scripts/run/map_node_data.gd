class_name MapNodeData
extends RefCounted

var node_id: String
var floor: int
var node_type: String
var title: String
var lane: int
var next_ids: Array[String]
var encounter_id: String
var reward_tier: int
var visited: bool
var available: bool


func _init(
	id: String = "",
	floor_value: int = 0,
	type_value: String = "",
	title_value: String = "",
	lane_value: int = 0,
	next_ids_value: Array[String] = [],
	encounter_id_value: String = "",
	reward_tier_value: int = 1
) -> void:
	node_id = id
	floor = floor_value
	node_type = type_value
	title = title_value
	lane = lane_value
	next_ids = next_ids_value.duplicate()
	encounter_id = encounter_id_value
	reward_tier = reward_tier_value
	visited = false
	available = false
