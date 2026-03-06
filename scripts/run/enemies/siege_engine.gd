class_name SiegeEngineTrait
extends "res://scripts/run/enemy_trait_base.gd"


func _init() -> void:
	trait_id = "siege_engine"
	display_name = "Siege Engine"
	description = "Heavy pressure that leans on gravity and board control."
	color = Color(1.0, 0.58, 0.24)


func get_opening_complication_ids() -> Array[String]:
	return ["gravity"]
