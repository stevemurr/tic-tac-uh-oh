class_name ClocksmithCharacter
extends "res://scripts/run/character_base.gd"


func _init() -> void:
	character_id = "clocksmith"
	display_name = "Clocksmith"
	description = "A measured tactician who keeps chaos on a short leash."
	color = Color(0.52, 0.88, 1.0)
	starter_rune_id = "anchor_rune"
	max_charge = 3
	active_name = "Lockstep"
	active_description = "Reserve a perfect move window while the castle machinery stutters."


func modify_charge_gain(amount: int, reason: String) -> int:
	if reason == "move":
		return amount + 1
	return amount
