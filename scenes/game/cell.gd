extends TextureButton

signal cell_clicked(index: int)

@export var cell_index: int = 0

var _mark: int = -1  # -1=empty, 0=X, 1=O, 2=wildcard
var _is_blocked: bool = false
var _is_wildcard: bool = false
var _is_bomb: bool = false
var _mark_alpha: float = 1.0
var _mark_scale: Vector2 = Vector2.ONE
var _mark_progress: float = 1.0

@onready var label: Label = $Label
@onready var mark_layer: Control = $MarkLayer
@onready var surface: ColorRect = $Surface
@onready var overlay: ColorRect = $Overlay
@onready var effect_overlay: ColorRect = $EffectOverlay

var mark_alpha: float = 1.0:
	set(value):
		_mark_alpha = value
		_redraw_mark()
	get:
		return _mark_alpha

var mark_scale: Vector2 = Vector2.ONE:
	set(value):
		_mark_scale = value
		_redraw_mark()
	get:
		return _mark_scale

var mark_progress: float = 1.0:
	set(value):
		_mark_progress = clampf(value, 0.0, 1.0)
		_redraw_mark()
	get:
		return _mark_progress

func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset = custom_minimum_size / 2.0
	_update_font_size()
	update_display()

func _on_pressed() -> void:
	cell_clicked.emit(cell_index)

func _on_mouse_entered() -> void:
	if disabled or _is_blocked:
		return
	# Brighten neon outline on hover
	_set_outline_brightness(0.8)
	_set_outline_color(NeonColors.CELL_HOVER_GLOW)
	_set_surface_glow(NeonColors.CELL_HOVER_GLOW, 0.26)
	# Slight scale up
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	# Restore neon state
	_update_neon_state()
	# Scale back
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)

func _update_font_size() -> void:
	if not label:
		return
	var cell_px := custom_minimum_size.x
	if cell_px <= 0:
		cell_px = 100.0
	var font_size := int(cell_px * 0.48)
	font_size = clampi(font_size, 10, 48)
	label.add_theme_font_size_override("font_size", font_size)

func set_mark(player: int) -> void:
	_mark = player
	update_display()

func set_blocked(blocked: bool) -> void:
	_is_blocked = blocked
	disabled = blocked
	update_display()

func set_wildcard(wild: bool) -> void:
	_is_wildcard = wild
	update_display()

func set_bomb(bomb: bool) -> void:
	_is_bomb = bomb
	update_display()

func get_mark() -> int:
	return _mark

func update_display() -> void:
	if not is_inside_tree():
		return

	_update_font_size()

	if _is_blocked:
		label.text = ""
		label.visible = false
		modulate = NeonColors.CELL_BLOCKED
		_set_outline_brightness(0.1)
		_set_outline_color(Color(0.2, 0.2, 0.3, 0.2))
		_set_surface_glow(Color(0.18, 0.22, 0.28), 0.08)
		_redraw_mark()
		return

	modulate = Color.WHITE
	label.visible = false

	match _mark:
		-1:
			label.text = ""
			if _is_bomb:
				label.text = "B"
				label.add_theme_color_override("font_color", NeonColors.BOMB)
				label.visible = true
			if _is_wildcard:
				label.text = "*"
				label.add_theme_color_override("font_color", NeonColors.WILDCARD)
				label.visible = true
		0:
			label.text = ""
			mark_alpha = 1.0
			mark_scale = Vector2.ONE
			mark_progress = 1.0
		1:
			label.text = ""
			mark_alpha = 1.0
			mark_scale = Vector2.ONE
			mark_progress = 1.0
		2:
			label.text = "*"
			label.add_theme_color_override("font_color", NeonColors.WILDCARD)
			label.visible = true

	_update_neon_state()
	_redraw_mark()

func _update_neon_state() -> void:
	if not overlay:
		return
	match _mark:
		-1:
			if _is_wildcard:
				_set_outline_color(NeonColors.WILDCARD)
				_set_outline_brightness(0.5)
				_set_outline_pulse(1.5)
			elif _is_bomb:
				_set_outline_color(NeonColors.BOMB)
				_set_outline_brightness(0.4)
				_set_outline_pulse(2.0)
				_set_surface_glow(NeonColors.BOMB, 0.16)
			else:
				_set_outline_color(NeonColors.DIM_OUTLINE)
				_set_outline_brightness(0.3)
				_set_outline_pulse(0.0)
				_set_surface_glow(NeonColors.GRID_LINE_BRIGHT, 0.14)
		0:
			_set_outline_color(NeonColors.PLAYER_X)
			_set_outline_brightness(0.6)
			_set_outline_pulse(0.0)
			_set_surface_glow(NeonColors.PLAYER_X, 0.18)
		1:
			_set_outline_color(NeonColors.PLAYER_O)
			_set_outline_brightness(0.6)
			_set_outline_pulse(0.0)
			_set_surface_glow(NeonColors.PLAYER_O, 0.18)
		2:
			_set_outline_color(NeonColors.WILDCARD)
			_set_outline_brightness(0.5)
			_set_outline_pulse(1.5)
			_set_surface_glow(NeonColors.WILDCARD, 0.18)

func _set_outline_brightness(val: float) -> void:
	if overlay and overlay.material is ShaderMaterial:
		(overlay.material as ShaderMaterial).set_shader_parameter("brightness", val)

func _set_outline_color(color: Color) -> void:
	if overlay and overlay.material is ShaderMaterial:
		(overlay.material as ShaderMaterial).set_shader_parameter("glow_color", color)

func _set_outline_pulse(speed: float) -> void:
	if overlay and overlay.material is ShaderMaterial:
		(overlay.material as ShaderMaterial).set_shader_parameter("pulse_speed", speed)

func _set_surface_glow(color: Color, alpha: float) -> void:
	if surface and surface.material is ShaderMaterial:
		(surface.material as ShaderMaterial).set_shader_parameter("glow_color", Color(color.r, color.g, color.b, alpha))

func get_effect_overlay() -> ColorRect:
	return effect_overlay

func set_shader_material(shader: Shader) -> void:
	if effect_overlay:
		effect_overlay.material = ShaderMaterial.new()
		(effect_overlay.material as ShaderMaterial).shader = shader
		effect_overlay.visible = true

func clear_shader_material() -> void:
	if effect_overlay:
		effect_overlay.material = null
		effect_overlay.visible = false

func get_label() -> Label:
	return label

func get_mark_layer() -> Control:
	return mark_layer

func _redraw_mark() -> void:
	if mark_layer:
		mark_layer.queue_redraw()
	else:
		queue_redraw()

func reset_effects() -> void:
	scale = Vector2.ONE
	rotation = 0.0
	modulate = Color.WHITE
	pivot_offset = custom_minimum_size / 2.0
	mark_alpha = 1.0
	mark_scale = Vector2.ONE
	mark_progress = 1.0
	if mark_layer:
		mark_layer.position = Vector2.ZERO
		mark_layer.rotation = 0.0
	if effect_overlay:
		effect_overlay.material = null
		effect_overlay.visible = false

func reset_cell() -> void:
	_mark = -1
	_is_blocked = false
	_is_wildcard = false
	_is_bomb = false
	disabled = false
	reset_effects()
	update_display()
