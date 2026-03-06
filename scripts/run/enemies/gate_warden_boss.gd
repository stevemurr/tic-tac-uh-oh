class_name GateWardenBossTrait
extends "res://scripts/run/enemy_trait_base.gd"


func _init() -> void:
	trait_id = "gate_warden_boss"
	display_name = "Gate Warden"
	description = "The first true guardian of the ascent, all mass and machinery."
	color = Color(1.0, 0.8, 0.44)


func get_opening_complication_ids() -> Array[String]:
	return ["gravity", "rotating_board"]
