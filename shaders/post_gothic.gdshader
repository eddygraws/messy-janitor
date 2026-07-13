shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float stress : hint_range(0.0, 1.0) = 0.0;
uniform float time_speed = 1.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.035;
uniform float chroma_strength : hint_range(0.0, 0.02) = 0.001;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - 0.5;

	float stress_boost = stress * 0.85;
	vec2 aberr = centered * chroma_strength * (1.0 + stress_boost * 1.1);

	vec3 col;
	col.r = texture(screen_texture, uv + aberr).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - aberr).b;

	// Gothic warm grade
	vec3 grade = vec3(1.04, 0.94, 0.86);
	col = mix(col, col * grade, 0.28 + stress * 0.12);

	// Vignette
	float vig = 1.0 - dot(centered, centered) * (1.35 + stress * 0.4);
	col *= smoothstep(0.15, 1.0, mix(vig, 1.0, 1.0 - vignette_strength));

	// Film grain
	float t = TIME * time_speed;
	float grain = hash(uv * vec2(1920.0, 1080.0) + t) - 0.5;
	col += grain * (grain_strength + stress * 0.05);

	// Subtle scanline
	float scan = sin(uv.y * 1080.0 * 3.14159) * 0.015;
	col -= scan * (0.35 + stress * 0.25);

	COLOR = vec4(col, 1.0);
}
