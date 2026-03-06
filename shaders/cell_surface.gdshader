shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.08, 0.11, 0.18, 0.98);
uniform vec4 glow_color : source_color = vec4(0.14, 0.64, 0.82, 0.20);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 0.08);
uniform vec4 sheen_color : source_color = vec4(1.0, 0.92, 0.76, 0.1);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.38;
uniform float sheen_strength : hint_range(0.0, 1.5) = 0.7;
uniform float depth_shadow_strength : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float radius = length(centered * vec2(1.05, 1.0));
	float vignette = smoothstep(0.15, 0.72, radius);

	float top_gloss = (1.0 - smoothstep(0.18, 0.78, UV.y)) * 0.55;
	float inner_glow = (1.0 - smoothstep(0.18, 0.95, radius)) * 0.5;
	float lower_shadow = smoothstep(0.16, 0.96, UV.y) * depth_shadow_strength;
	float diagonal = dot(UV - vec2(0.52, 0.28), normalize(vec2(0.74, -1.0)));
	float sheen = exp(-pow(diagonal / 0.24, 2.0) * 5.5) * (1.0 - smoothstep(0.35, 1.0, UV.y));

	vec3 color = base_color.rgb;
	color = mix(color, color * 0.75, vignette * vignette_strength);
	color *= 1.0 - lower_shadow * 0.22;
	color += glow_color.rgb * inner_glow * glow_color.a;
	color += highlight_color.rgb * top_gloss * highlight_color.a;
	color += sheen_color.rgb * sheen * sheen_color.a * sheen_strength;

	float edge = min(min(UV.x, UV.y), min(1.0 - UV.x, 1.0 - UV.y));
	float edge_light = smoothstep(0.0, 0.08, edge);
	float rim = 1.0 - edge_light;
	color += glow_color.rgb * rim * 0.08;
	color += highlight_color.rgb * pow(rim, 1.8) * 0.05;

	COLOR = vec4(color, base_color.a);
}
