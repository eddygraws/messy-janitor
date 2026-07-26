shader_type spatial;
// ambient_light_disabled: motor AMBIENT + bizim band üstüne binmesin (beyaz patlama)
render_mode diffuse_lambert, specular_disabled, ambient_light_disabled, cull_back;

// Blender: Principled → Shader to RGB → Color Ramp (Constant)

uniform vec4 mid_color : source_color = vec4(0.48, 0.30, 0.68, 1.0);
uniform vec3 shadow_color : source_color = vec3(0.14, 0.09, 0.24);
uniform vec3 highlight_color : source_color = vec3(0.78, 0.66, 0.92);

uniform float shadow_stop : hint_range(0.0, 1.0) = 0.42;
uniform float highlight_stop : hint_range(0.0, 1.0) = 0.73;

uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform float use_texture : hint_range(0.0, 1.0) = 0.0;

uniform float rim_strength : hint_range(0.0, 1.0) = 0.12;
uniform vec3 rim_color : source_color = vec3(1.0, 0.93, 0.88);
uniform float ambient_fill : hint_range(0.0, 0.4) = 0.08;
uniform float wrap : hint_range(0.0, 1.0) = 0.45;
// İkinci ışık (fill) patlatmasın
uniform float light_gain : hint_range(0.1, 1.5) = 0.55;

varying vec3 v_mid;

void fragment() {
	vec3 tex = texture(albedo_texture, UV).rgb;
	v_mid = mix(mid_color.rgb, mid_color.rgb * tex, use_texture);

	// ALBEDO düşük tut — light() band rengi basacak; çift aydınlatma olmasın
	ALBEDO = vec3(0.0);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	EMISSION = shadow_color * ambient_fill;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.2);
	EMISSION += rim_color * fresnel * rim_strength * 0.25;
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float fac = ndotl * (1.0 - wrap * 0.5) + wrap * 0.5;
	fac = clamp(fac, 0.0, 1.0);

	vec3 band = shadow_color;
	if (fac >= shadow_stop) {
		band = v_mid;
	}
	if (fac >= highlight_stop) {
		band = highlight_color;
	}

	// ATTENUATION + gain — Sun+Fill toplamı beyaza kaçmasın
	DIFFUSE_LIGHT += band * LIGHT_COLOR * ATTENUATION * light_gain;
}
