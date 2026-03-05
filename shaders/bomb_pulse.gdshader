shader_type canvas_item;

uniform float pulse_speed : hint_range(0.5, 5.0) = 2.0;
uniform vec4 pulse_color : source_color = vec4(1.0, 0.3, 0.0, 0.5);
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float pulse = (sin(TIME * pulse_speed) + 1.0) * 0.5;
	vec4 glow = pulse_color * pulse * pulse_intensity;
	COLOR = tex_color + glow;
	COLOR.a = tex_color.a;
}
