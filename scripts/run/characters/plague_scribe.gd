class_name PlagueScribeCharacter
extends "res://scripts/run/character_base.gd"


func _init() -> void:
	character_id = "plague_scribe"
	display_name = "Plague Scribe"
	description = "A toxic scholar who thrives when the board starts to rot."
	color = Color(0.38, 0.92, 0.58)
	starter_rune_id = "bloom_rune"
	max_charge = 4
	active_name = "Viridian Bloom"
	active_description = "Store noxious pressure for a decisive conversion later."
