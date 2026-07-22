shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, shadows_disabled;

/// Vektörel dikdörtgen karolar — diyagonal loop; derz/outline yok. Sadece duvar mesh'i.
uniform vec4 color_a : source_color = vec4(0.35, 0.22, 0.48, 1.0);
uniform vec4 color_b : source_color = vec4(0.55, 0.32, 0.62, 1.0);
uniform vec4 color_accent : source_color = vec4(0.85, 0.45, 1.0, 1.0);
uniform float tile_world_size : hint_range(0.5, 12.0) = 2.8;
uniform float scroll_speed : hint_range(0.0, 2.0) = 0.22;
uniform float diagonal_angle : hint_range(0.0, 1.5708) = 0.785398;
uniform float accent_chance : hint_range(0.0, 0.4) = 0.07;
uniform float pulse_amount : hint_range(0.0, 0.15) = 0.02;

varying vec3 v_world;
varying vec3 v_wnormal;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec3 sample_rects(vec2 uv, float t, float ca, float sa) {
	vec2 rp = vec2(ca * uv.x - sa * uv.y, sa * uv.x + ca * uv.y);
	rp /= max(tile_world_size, 0.05);
	rp += vec2(t, t);

	vec2 cell = floor(rp);
	float checker = mod(cell.x + cell.y, 2.0);
	vec3 fill = mix(color_a.rgb, color_b.rgb, checker);

	float h = hash21(cell);
	if (h < accent_chance) {
		float twinkle = 0.85 + 0.15 * sin(TIME * 2.0 + h * 30.0);
		fill = mix(fill, color_accent.rgb, 0.55 * twinkle);
	}
	return fill;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float t = TIME * scroll_speed;
	float ca = cos(diagonal_angle);
	float sa = sin(diagonal_angle);

	vec3 n = abs(normalize(v_wnormal));
	n = pow(n, vec3(4.0));
	n /= max(n.x + n.y + n.z, 0.0001);

	vec3 cx = sample_rects(v_world.zy, t, ca, sa);
	vec3 cy = sample_rects(v_world.xz, t, ca, sa);
	vec3 cz = sample_rects(v_world.xy, t, ca, sa);
	vec3 col = cx * n.x + cy * n.y + cz * n.z;

	col *= 1.0 + sin(TIME * 0.9) * pulse_amount;

	ALBEDO = col;
	EMISSION = col * 0.75;
}
