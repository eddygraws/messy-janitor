shader_type canvas_item;

// Paspas ovalama: islak parilti + kopuk.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float dirt : hint_range(0.0, 1.0) = 0.0;
uniform vec4 foam_color : source_color = vec4(0.92, 0.97, 1.0, 1.0);
uniform vec4 wet_tint : source_color = vec4(0.55, 0.78, 0.95, 1.0);
uniform float wobble_amount : hint_range(0.0, 0.12) = 0.045;
uniform float sparkle_density : hint_range(2.0, 24.0) = 11.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	float i = clamp(intensity, 0.0, 1.0);
	vec2 uv = UV;

	if (i > 0.001) {
		float wave = sin(TIME * 22.0 + uv.y * 18.0) * wobble_amount * i;
		float squash = 1.0 + sin(TIME * 16.0) * 0.04 * i;
		uv.x = (uv.x - 0.5) / squash + 0.5 + wave;
		uv.y += cos(TIME * 19.0 + uv.x * 14.0) * wobble_amount * 0.65 * i;
	}

	vec4 tex = texture(TEXTURE, uv);
	vec3 rgb = tex.rgb;

	if (tex.a >= 0.01 && i > 0.001) {
		float sheen = pow(max(0.0, sin((uv.x + uv.y) * 9.0 - TIME * 7.0)), 3.0);
		rgb = mix(rgb, wet_tint.rgb, sheen * 0.55 * i);

		vec2 cell = floor(uv * sparkle_density);
		float n = hash21(cell + floor(TIME * 8.0));
		float spark = step(0.72, n) * step(0.08, fract(uv.x * sparkle_density))
			* step(0.08, fract(uv.y * sparkle_density));
		rgb = mix(rgb, foam_color.rgb, spark * 0.85 * i);

		vec3 dirty_foam = mix(foam_color.rgb, vec3(0.55, 0.38, 0.22), dirt);
		rgb = mix(rgb, dirty_foam, spark * 0.35 * dirt * i);

		float edge = smoothstep(0.15, 0.55, tex.a) * (1.0 - smoothstep(0.55, 0.95, tex.a));
		rgb += wet_tint.rgb * edge * 0.35 * i;
	}

	COLOR = vec4(rgb, tex.a);
}
