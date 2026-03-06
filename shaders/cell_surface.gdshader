shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.1, 0.1, 0.12, 0.98);
uniform vec4 glow_color : source_color = vec4(0.58, 0.7, 0.76, 0.12);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.97, 0.92, 0.12);
uniform vec4 sheen_color : source_color = vec4(0.96, 0.78, 0.54, 0.14);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.38;
uniform float sheen_strength : hint_range(0.0, 1.5) = 0.7;
uniform float depth_shadow_strength : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float radius = length(centered * vec2(1.06, 1.0));
	float vignette = smoothstep(0.14, 0.76, radius);
	float top_gloss = (1.0 - smoothstep(0.14, 0.72, UV.y)) * 0.58;
	float center_bloom = 1.0 - smoothstep(0.05, 0.74, length((UV - vec2(0.5, 0.38)) * vec2(1.0, 1.25)));
	float lower_shadow = smoothstep(0.24, 1.0, UV.y) * depth_shadow_strength;
	float diagonal = dot(UV - vec2(0.48, 0.24), normalize(vec2(0.78, -1.0)));
	float sheen = exp(-pow(diagonal / 0.28, 2.0) * 5.0) * (0.45 + 0.55 * (1.0 - smoothstep(0.3, 1.0, UV.y)));
	float edge = min(min(UV.x, UV.y), min(1.0 - UV.x, 1.0 - UV.y));
	float rim = 1.0 - smoothstep(0.0, 0.08, edge);

	vec3 color = base_color.rgb;
	color = mix(color, color * 0.75, vignette * vignette_strength);
	color = mix(color, highlight_color.rgb, top_gloss * highlight_color.a * 0.35);
	color += glow_color.rgb * center_bloom * glow_color.a;
	color += sheen_color.rgb * sheen * sheen_color.a * sheen_strength;
	color *= 1.0 - lower_shadow * 0.24;
	color += highlight_color.rgb * pow(rim, 1.8) * 0.06;
	color += glow_color.rgb * rim * 0.05;

	COLOR = vec4(color, base_color.a);
}
