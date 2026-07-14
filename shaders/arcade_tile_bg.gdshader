shader_type canvas_item;
render_mode unshaded;

/// Çapraz ilerleyen arcade karo void — oda sprite'ının arkasında.
uniform vec4 color_a : source_color = vec4(0.10, 0.07, 0.16, 1.0);
uniform vec4 color_b : source_color = vec4(0.18, 0.10, 0.24, 1.0);
uniform vec4 color_line : source_color = vec4(0.04, 0.03, 0.07, 1.0);
uniform vec4 color_accent : source_color = vec4(0.55, 0.28, 0.72, 1.0);
uniform float tile_size : hint_range(16.0, 120.0) = 52.0;
uniform float scroll_speed : hint_range(0.0, 1.5) = 0.12;
uniform float diagonal_angle : hint_range(0.0, 1.5708) = 0.785398;
uniform float line_width : hint_range(0.01, 0.25) = 0.07;
uniform float vignette : hint_range(0.0, 1.0) = 0.55;
uniform float pulse_amount : hint_range(0.0, 0.2) = 0.035;
uniform float accent_chance : hint_range(0.0, 0.4) = 0.08;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.35;
uniform vec2 viewport_size = vec2(1920.0, 1080.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * scroll_speed;

	float ca = cos(diagonal_angle);
	float sa = sin(diagonal_angle);
	vec2 world = uv * viewport_size;
	vec2 rp = vec2(ca * world.x - sa * world.y, sa * world.x + ca * world.y);
	rp /= max(tile_size, 1.0);
	rp += vec2(t * 1.15, t * 0.72);

	vec2 cell = floor(rp);
	vec2 f = fract(rp);
	float checker = mod(cell.x + cell.y, 2.0);

	vec3 col = mix(color_a.rgb, color_b.rgb, checker);

	// Seyrek accent karolar (arcade sparkle)
	float h = hash21(cell);
	if (h < accent_chance) {
		float twinkle = 0.55 + 0.45 * sin(TIME * 2.4 + h * 40.0);
		col = mix(col, color_accent.rgb, 0.55 * twinkle);
	}

	// Derz çizgileri
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	col = mix(color_line.rgb, col, smoothstep(0.0, line_width, edge));

	// Merkezde hafif ışıma — oda "sahne" gibi otursun
	vec2 centered = uv - vec2(0.5, 0.52);
	float radial = exp(-dot(centered, centered) * 4.2);
	col += color_accent.rgb * radial * glow_strength * 0.18;

	// Kenar vignette
	float vig = 1.0 - dot(centered, centered) * (2.2 * vignette);
	col *= mix(0.42, 1.0, clamp(vig, 0.0, 1.0));

	col *= 1.0 + sin(TIME * 1.15 + uv.x * 3.0) * pulse_amount;

	COLOR = vec4(col, 1.0);
}
