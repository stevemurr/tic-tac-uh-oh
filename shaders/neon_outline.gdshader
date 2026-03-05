shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.0, 0.4, 0.5, 0.3);
uniform float brightness : hint_range(0.0, 2.0) = 0.3;
uniform float pulse_speed : hint_range(0.0, 5.0) = 0.0;
uniform float border_width : hint_range(1.0, 10.0) = 3.0;
uniform float glow_spread : hint_range(0.0, 30.0) = 8.0;

void fragment() {
	vec2 pixel = UV * vec2(textureSize(TEXTURE, 0));
	vec2 size = vec2(textureSize(TEXTURE, 0));

	// Distance from edges
	float dist_left = pixel.x;
	float dist_right = size.x - pixel.x;
	float dist_top = pixel.y;
	float dist_bottom = size.y - pixel.y;
	float dist_edge = min(min(dist_left, dist_right), min(dist_top, dist_bottom));

	// Soft neon border glow
	float border = smoothstep(0.0, border_width, dist_edge) * (1.0 - smoothstep(border_width, border_width + glow_spread, dist_edge));

	// Outer glow falloff
	float outer_glow = 1.0 - smoothstep(0.0, glow_spread, dist_edge);

	float combined = max(border * 0.8, outer_glow * 0.3);

	// Optional pulse
	float pulse = 1.0;
	if (pulse_speed > 0.0) {
		pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);
	}

	float final_brightness = brightness * pulse;
	COLOR = vec4(glow_color.rgb * final_brightness, combined * final_brightness * glow_color.a);
}
