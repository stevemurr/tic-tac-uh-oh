shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.03, 0.03, 0.05, 1.0);
uniform vec4 grid_color : source_color = vec4(0.28, 0.34, 0.4, 0.08);
uniform vec4 glow_color : source_color = vec4(0.36, 0.46, 0.5, 0.12);
uniform vec4 beam_color : source_color = vec4(0.95, 0.76, 0.48, 0.1);
uniform vec4 mist_color : source_color = vec4(0.12, 0.11, 0.12, 0.2);
uniform float grid_spacing : hint_range(20.0, 100.0) = 72.0;
uniform float grid_thickness : hint_range(0.5, 3.0) = 1.0;
uniform float scroll_speed : hint_range(0.0, 50.0) = 4.0;
uniform float scanline_alpha : hint_range(0.0, 0.2) = 0.025;
uniform float scanline_spacing : hint_range(1.0, 8.0) = 3.0;
uniform float beam_width : hint_range(0.05, 0.4) = 0.22;

void fragment() {
	vec2 viewport = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 pixel = UV * viewport;

	float scroll_offset = TIME * scroll_speed;
	vec2 grid_uv = pixel + vec2(0.0, scroll_offset);
	float h_line = step(mod(grid_uv.y, grid_spacing), grid_thickness);
	float v_line = step(mod(grid_uv.x, grid_spacing * 1.05), grid_thickness);
	float grid = max(h_line, v_line);
	float scanline = step(mod(pixel.y, scanline_spacing), 1.0) * scanline_alpha;

	vec2 glow_center = UV - vec2(0.5, 0.16);
	float halo = 1.0 - smoothstep(0.08, 0.84, length(glow_center * vec2(1.0, 1.55)));
	float canopy = 1.0 - smoothstep(0.0, 0.88, UV.y);
	float arch = 1.0 - smoothstep(0.18, 0.84, abs(UV.x - 0.5) * 1.28 + UV.y * 0.86);
	float vignette = smoothstep(0.34, 1.02, length((UV - vec2(0.5)) * vec2(1.0, 1.15)));
	float beam_axis = dot(UV - vec2(0.54, 0.18), normalize(vec2(0.82, -0.58)));
	float beam_wave = sin(TIME * 0.13) * 0.06;
	float beam = exp(-pow((beam_axis + beam_wave) / max(beam_width, 0.001), 2.0));
	float mist_field = sin(UV.x * 7.0 + TIME * 0.12) + sin(UV.y * 10.0 - TIME * 0.09);
	float mist = smoothstep(-0.8, 1.4, mist_field) * (1.0 - smoothstep(0.0, 0.92, UV.y));
	float brass_haze = exp(-pow((UV.y - 0.24) / 0.24, 2.0)) * (0.35 + arch * 0.65);
	float grain = fract(sin(dot(pixel + vec2(TIME * 11.0, TIME * 7.0), vec2(12.9898, 78.233))) * 43758.5453);

	vec3 color = bg_color.rgb;
	color = mix(color, grid_color.rgb, grid * grid_color.a * (0.3 + canopy * 0.7));
	color += glow_color.rgb * halo * glow_color.a;
	color += glow_color.rgb * arch * canopy * glow_color.a * 0.35;
	color += beam_color.rgb * beam * beam_color.a;
	color += beam_color.rgb * brass_haze * beam_color.a * 0.45;
	color = mix(color, mist_color.rgb, mist * mist_color.a);
	color -= vec3(scanline);
	color += (grain - 0.5) * 0.014;
	color *= 1.0 - vignette * 0.22;

	COLOR = vec4(color, 1.0);
}
