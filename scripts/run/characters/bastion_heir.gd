class_name BastionHeirCharacter
extends "res://scripts/run/character_base.gd"


func _init() -> void:
	character_id = "bastion_heir"
	display_name = "Bastion Heir"
	description = "A fortress-born duelist who turns edges and corners into strongholds."
	color = Color(1.0, 0.72, 0.38)
	starter_rune_id = "rampart_rune"
	max_charge = 3
	active_name = "Raise Gate"
	active_description = "Bank momentum and make the next engagement sturdier."
