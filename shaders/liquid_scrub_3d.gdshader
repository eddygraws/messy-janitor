shader_type spatial;
// Viscera-style wipe trail only — no smear. Mask white = wiped away.
render_mode blend_mix, depth_prepass_alpha, cull_disabled, unshaded, shadows_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D scrub_mask : hint_default_black, filter_linear, repeat_disable;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.92;
uniform float wet_rim : hint_range(0.0, 2.5) = 1.15;
uniform float wipe_softness : hint_range(0.01, 0.6) = 0.38;

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	if (tex.a < 0.02) {
		discard;
	}

	float wiped = texture(scrub_mask, UV).r;
	float remain = 1.0 - smoothstep(0.02, wipe_softness, wiped);
	float a = tex.a * remain * opacity;
	if (a < 0.02) {
		discard;
	}

	vec3 col = tex.rgb * tint_color.rgb;
	// Silme kenarında ince ıslak parıltı (sadece iz feedback)
	float edge = max(abs(dFdx(wiped)), abs(dFdy(wiped)));
	col = mix(col, col * vec3(0.65, 0.85, 1.08) + vec3(0.06, 0.1, 0.14), clamp(edge * 10.0 * wet_rim, 0.0, 0.85));

	ALBEDO = col;
	ALPHA = a;
	ROUGHNESS = 0.35;
	METALLIC = 0.0;
}
