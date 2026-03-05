class_name MoveResult
extends RefCounted

var cell: int = -1
var player: int = -1
var is_valid: bool = false
var reason: String = ""
var is_steal: bool = false  # For stolen turn complication
var steal_target: int = -1  # Cell being stolen
var extra_data: Dictionary = {}  # For complications to attach data
