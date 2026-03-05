class_name CellEffects
extends RefCounted

## Static tween helpers for cell animations.
## All methods create and return tweens so callers can await them.


static func pop_scale(cell: Control, duration: float = 0.2) -> Tween:
	var tween := cell.create_tween()
	tween.tween_property(cell, "scale", Vector2(1.3, 1.3), duration * 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(cell, "scale", Vector2.ONE, duration * 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return tween


static func flash_color(cell: Control, color: Color, duration: float = 0.2) -> Tween:
	var eff_overlay: ColorRect = cell.get_node_or_null("EffectOverlay")
	if not eff_overlay:
		return cell.create_tween()  # no-op tween
	var old_visible := eff_overlay.visible
	var old_color := eff_overlay.color
	eff_overlay.visible = true
	eff_overlay.color = color
	var tween := cell.create_tween()
	tween.tween_property(eff_overlay, "color:a", 0.0, duration)
	tween.tween_callback(func():
		eff_overlay.color = old_color
		eff_overlay.visible = old_visible
	)
	return tween


static func slide_from(cell: Control, offset: Vector2, duration: float = 0.3) -> Tween:
	var target_pos := cell.position
	cell.position = target_pos + offset
	var tween := cell.create_tween()
	tween.tween_property(cell, "position", target_pos, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return tween


static func slide_to(cell: Control, target_pos: Vector2, duration: float = 0.3) -> Tween:
	var tween := cell.create_tween()
	tween.tween_property(cell, "position", target_pos, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return tween


static func shake(cell: Control, intensity: float = 4.0, duration: float = 0.3) -> Tween:
	var original_pos := cell.position
	var tween := cell.create_tween()
	var steps := int(duration / 0.05)
	for i in steps:
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(cell, "position", original_pos + offset, 0.05)
	tween.tween_property(cell, "position", original_pos, 0.05)
	return tween


static func pulse_glow(cell: Control, color: Color, duration: float = 0.4, repeats: int = 2) -> Tween:
	var eff_overlay: ColorRect = cell.get_node_or_null("EffectOverlay")
	if not eff_overlay:
		return cell.create_tween()
	eff_overlay.visible = true
	eff_overlay.color = Color(color.r, color.g, color.b, 0.0)
	var tween := cell.create_tween()
	for i in repeats:
		tween.tween_property(eff_overlay, "color:a", color.a, duration / (repeats * 2))
		tween.tween_property(eff_overlay, "color:a", 0.0, duration / (repeats * 2))
	tween.tween_callback(func():
		eff_overlay.visible = false
	)
	return tween


static func fade_out(cell: Control, duration: float = 0.3) -> Tween:
	var tween := cell.create_tween()
	tween.tween_property(cell, "modulate:a", 0.0, duration)
	return tween


static func fade_in(cell: Control, duration: float = 0.3) -> Tween:
	cell.modulate.a = 0.0
	var tween := cell.create_tween()
	tween.tween_property(cell, "modulate:a", 1.0, duration)
	return tween


static func spin(cell: Control, degrees: float = 90.0, duration: float = 0.4) -> Tween:
	var tween := cell.create_tween()
	tween.tween_property(cell, "rotation", deg_to_rad(degrees), duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).as_relative()
	return tween


static func implode(cell: Control, duration: float = 0.2) -> Tween:
	var tween := cell.create_tween()
	tween.set_parallel(true)
	tween.tween_property(cell, "scale", Vector2(0.0, 0.0), duration).set_ease(Tween.EASE_IN)
	tween.tween_property(cell, "modulate:a", 0.0, duration)
	return tween


static func color_wave(cell: Control, color: Color, duration: float = 0.3) -> Tween:
	var eff_overlay: ColorRect = cell.get_node_or_null("EffectOverlay")
	if not eff_overlay:
		return cell.create_tween()
	eff_overlay.visible = true
	eff_overlay.color = Color(color.r, color.g, color.b, 0.6)
	var tween := cell.create_tween()
	tween.tween_property(eff_overlay, "color:a", 0.0, duration)
	tween.tween_callback(func():
		eff_overlay.visible = false
	)
	return tween
