shader_type canvas_item;

uniform vec4 fill_color : source_color = vec4(0.56, 0.43, 0.25, 0.07);
uniform vec4 rim_color : source_color = vec4(0.9, 0.76, 0.54, 0.08);
uniform float radius : hint_range(0.1, 0.5) = 0.47;
uniform float feather : hint_range(0.001, 0.08) = 0.018;
uniform float rim_width : hint_range(0.001, 0.12) = 0.03;
uniform float core_falloff : hint_range(0.1, 4.0) = 1.25;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	float disc = 1.0 - smoothstep(radius - feather, radius + feather, dist);
	float inner_disc = 1.0 - smoothstep(radius - rim_width - feather, radius - rim_width + feather, dist);
	float rim = clamp(disc - inner_disc, 0.0, 1.0);
	float radial = clamp(1.0 - dist / max(radius, 0.0001), 0.0, 1.0);
	float body = disc * pow(radial, core_falloff);
	float alpha = body * fill_color.a + rim * rim_color.a;
	vec3 color = fill_color.rgb;
	if (alpha > 0.0001) {
		color = (fill_color.rgb * body * fill_color.a + rim_color.rgb * rim * rim_color.a) / alpha;
	}
	COLOR = vec4(color, alpha);
}
