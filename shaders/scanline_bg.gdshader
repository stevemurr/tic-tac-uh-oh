shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.05, 0.05, 0.1, 1.0);
uniform vec4 grid_color : source_color = vec4(0.0, 0.3, 0.4, 0.15);
uniform vec4 glow_color : source_color = vec4(0.12, 0.65, 0.8, 0.12);
uniform float grid_spacing : hint_range(20.0, 100.0) = 50.0;
uniform float grid_thickness : hint_range(0.5, 3.0) = 1.0;
uniform float scroll_speed : hint_range(0.0, 50.0) = 10.0;
uniform float scanline_alpha : hint_range(0.0, 0.2) = 0.05;
uniform float scanline_spacing : hint_range(1.0, 8.0) = 3.0;

void fragment() {
	vec2 pixel = UV * vec2(textureSize(TEXTURE, 0));

	// Scrolling grid
	float scroll_offset = TIME * scroll_speed;
	vec2 grid_uv = pixel + vec2(0.0, scroll_offset);

	float h_line = step(mod(grid_uv.y, grid_spacing), grid_thickness);
	float v_line = step(mod(grid_uv.x, grid_spacing), grid_thickness);
	float grid = max(h_line, v_line);

	// Scanlines (static horizontal lines)
	float scanline = step(mod(pixel.y, scanline_spacing), 1.0) * scanline_alpha;

	vec2 centered = UV - vec2(0.5, 0.38);
	float radial = 1.0 - smoothstep(0.1, 0.88, length(centered * vec2(1.0, 1.35)));
	float top_falloff = 1.0 - smoothstep(0.15, 1.0, UV.y);
	float vignette = smoothstep(0.38, 1.0, length(UV - vec2(0.5)));

	// Combine
	vec3 color = bg_color.rgb;
	color = mix(color, grid_color.rgb, grid * grid_color.a);
	color += glow_color.rgb * radial * top_falloff * glow_color.a;
	color -= vec3(scanline);
	color *= 1.0 - vignette * 0.18;

	COLOR = vec4(color, 1.0);
}
