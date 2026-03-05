shader_type canvas_item;

uniform float shimmer_speed : hint_range(0.5, 5.0) = 1.5;
uniform vec4 color_a : source_color = vec4(1.0, 0.95, 0.0, 0.4);
uniform vec4 color_b : source_color = vec4(0.6, 0.2, 1.0, 0.4);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float t = (sin(TIME * shimmer_speed + UV.x * 6.28) + 1.0) * 0.5;
	vec4 shimmer = mix(color_a, color_b, t);
	COLOR = tex_color + shimmer * 0.5;
	COLOR.a = tex_color.a;
}
