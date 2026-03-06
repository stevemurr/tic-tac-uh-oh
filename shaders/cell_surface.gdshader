shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.08, 0.11, 0.18, 0.98);
uniform vec4 glow_color : source_color = vec4(0.14, 0.64, 0.82, 0.20);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 0.08);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.38;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float radius = length(centered * vec2(1.05, 1.0));
	float vignette = smoothstep(0.15, 0.72, radius);

	float top_gloss = (1.0 - smoothstep(0.18, 0.78, UV.y)) * 0.55;
	float inner_glow = (1.0 - smoothstep(0.18, 0.95, radius)) * 0.5;

	vec3 color = base_color.rgb;
	color = mix(color, color * 0.75, vignette * vignette_strength);
	color += glow_color.rgb * inner_glow * glow_color.a;
	color += highlight_color.rgb * top_gloss * highlight_color.a;

	float edge = min(min(UV.x, UV.y), min(1.0 - UV.x, 1.0 - UV.y));
	float edge_light = smoothstep(0.0, 0.08, edge);
	color += glow_color.rgb * (1.0 - edge_light) * 0.06;

	COLOR = vec4(color, base_color.a);
}
