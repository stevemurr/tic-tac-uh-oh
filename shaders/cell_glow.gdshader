shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.2, 0.6, 1.0, 0.3);
uniform float glow_speed : hint_range(0.5, 3.0) = 1.0;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float glow = (sin(TIME * glow_speed) + 1.0) * 0.5 * glow_intensity;
	COLOR = tex_color + glow_color * glow;
	COLOR.a = tex_color.a;
}
