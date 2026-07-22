shader_type canvas_item;

// VCD / Crime Scene Cleaner tarzı: paspasın geçtiği yer maskede silinir.
uniform sampler2D scrub_mask : filter_linear;
uniform float wet_rim : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.01) {
		discard;
	}

	float wiped = texture(scrub_mask, UV).r;
	float remain = 1.0 - smoothstep(0.02, 0.42, wiped);
	if (remain < 0.015) {
		discard;
	}

	vec3 col = tex.rgb;

	// Temizlik kenarında ıslak parıltı
	float edge = max(abs(dFdx(wiped)), abs(dFdy(wiped)));
	col = mix(col, col * vec3(0.62, 0.82, 1.05) + vec3(0.08, 0.12, 0.18), edge * 9.0 * wet_rim);

	// Hafif viskoz parlaklık (sıvı hissi)
	float sheen = pow(max(0.0, sin((UV.x + UV.y) * 14.0 + TIME * 2.5)), 4.0);
	col += vec3(0.06, 0.08, 0.12) * sheen * remain;

	COLOR = vec4(col, tex.a * remain);
}
