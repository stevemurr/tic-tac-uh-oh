shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform float glow_radius : hint_range(0.0, 5.0) = 2.0;
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.6;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 pixel_size = TEXTURE_PIXEL_SIZE;

	// Sample neighbors for glow (7x7 kernel)
	float glow = 0.0;
	int radius = int(glow_radius);
	float total_weight = 0.0;
	for (int x = -radius; x <= radius; x++) {
		for (int y = -radius; y <= radius; y++) {
			float dist = length(vec2(float(x), float(y)));
			if (dist > float(radius)) continue;
			float weight = 1.0 - dist / float(radius + 1);
			vec2 offset = vec2(float(x), float(y)) * pixel_size;
			glow += texture(TEXTURE, UV + offset).a * weight;
			total_weight += weight;
		}
	}
	glow /= total_weight;

	// Glow layer behind text
	vec3 final_color = mix(glow_color.rgb * glow * glow_intensity, tex.rgb, tex.a);
	float final_alpha = max(tex.a, glow * glow_intensity * glow_color.a);

	COLOR = vec4(final_color, final_alpha);
}
