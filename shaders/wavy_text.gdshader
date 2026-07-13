shader_type canvas_item;

uniform float wave_amp : hint_range(0.0, 12.0) = 2.5;
uniform float wave_speed = 2.8;
uniform float wave_freq : hint_range(0.0, 2.0) = 0.45;
uniform float rainbow : hint_range(0.0, 1.0) = 0.0;
uniform float shimmer : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec2 uv = UV;
	float wave = sin(TIME * wave_speed + uv.x * 18.0 * wave_freq) * wave_amp * 0.004;
	vec4 col = texture(TEXTURE, vec2(uv.x, uv.y + wave));

	if (rainbow > 0.01) {
		float hue = fract(uv.x * 0.6 + TIME * 0.08);
		vec3 tint = mix(vec3(1.0), vec3(
			0.6 + 0.4 * sin(hue * 6.28318),
			0.6 + 0.4 * sin(hue * 6.28318 + 2.094),
			0.6 + 0.4 * sin(hue * 6.28318 + 4.188)
		), rainbow * col.a);
		col.rgb *= tint;
	}

	col.rgb += shimmer * sin(TIME * 3.5 + uv.x * 12.0) * col.a * 0.15;
	COLOR = col;
}
