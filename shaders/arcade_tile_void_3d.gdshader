shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, shadows_disabled;

/// Oda etrafındaki arcade void — yumuşak pastel checker, derz/outline yok.
uniform vec4 color_a : source_color = vec4(0.35, 0.22, 0.48, 1.0);
uniform vec4 color_b : source_color = vec4(0.55, 0.32, 0.62, 1.0);
uniform vec4 color_accent : source_color = vec4(0.85, 0.45, 1.0, 1.0);
uniform float tile_world_size : hint_range(0.5, 8.0) = 2.6;
uniform float scroll_speed : hint_range(0.0, 1.5) = 0.08;
uniform float diagonal_angle : hint_range(0.0, 1.5708) = 0.785398;
uniform float pulse_amount : hint_range(0.0, 0.15) = 0.018;
uniform float accent_chance : hint_range(0.0, 0.4) = 0.06;
uniform float vignette : hint_range(0.0, 1.0) = 0.4;

varying vec3 v_world;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * scroll_speed;
	float ca = cos(diagonal_angle);
	float sa = sin(diagonal_angle);

	vec2 world = vec2(v_world.x * 0.65 + v_world.y * 0.35, v_world.z * 0.65 - v_world.y * 0.25);
	vec2 rp = vec2(ca * world.x - sa * world.y, sa * world.x + ca * world.y);
	rp /= max(tile_world_size, 0.05);
	rp += vec2(t * 1.05, t * 0.68);

	vec2 cell = floor(rp);
	float checker = mod(cell.x + cell.y, 2.0);
	vec3 col = mix(color_a.rgb, color_b.rgb, checker);

	float h = hash21(cell);
	if (h < accent_chance) {
		float twinkle = 0.7 + 0.3 * sin(TIME * 1.6 + h * 28.0);
		col = mix(col, color_accent.rgb, 0.45 * twinkle);
	}

	float dist = length(v_world.xz) * 0.016 + abs(v_world.y) * 0.01;
	col *= mix(1.0, 0.78, clamp(dist * vignette, 0.0, 1.0));
	col *= 1.0 + sin(TIME * 0.85 + v_world.x * 0.07) * pulse_amount;

	ALBEDO = col;
	EMISSION = col * 0.5;
}
