class_name RewardOption
extends RefCounted

var reward_type: String
var payload_id: String
var amount: int
var display_name: String
var description: String
var rarity: String


func _init(
	type_value: String = "",
	payload_id_value: String = "",
	amount_value: int = 0,
	display_name_value: String = "",
	description_value: String = "",
	rarity_value: String = "common"
) -> void:
	reward_type = type_value
	payload_id = payload_id_value
	amount = amount_value
	display_name = display_name_value
	description = description_value
	rarity = rarity_value
