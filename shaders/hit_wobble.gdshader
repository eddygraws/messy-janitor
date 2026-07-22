shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Toon lighting + hit wobble. Outline ayrı next_pass (mesh_outline.gdshader).

uniform vec4 albedo_color : source_color = vec4(0.22, 0.21, 0.2, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.88;
uniform vec3 emission_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float emission_energy : hint_range(0.0, 3.0) = 0.0;

uniform float hit_impulse : hint_range(0.0, 2.0) = 0.0;
uniform float hit_time = -1000.0;
uniform vec3 hit_dir = vec3(0.0, 0.0, 1.0);
uniform float wobble_scale : hint_range(0.0, 0.25) = 0.09;

// Toon
uniform int shade_bands : hint_range(2, 4) = 3;
uniform vec3 shadow_tint : source_color = vec3(0.35, 0.32, 0.55);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.55;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.35;
uniform vec3 rim_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float ambient_boost : hint_range(0.0, 1.0) = 0.22;

void vertex() {
	float age = TIME - hit_time;
	if (age > 0.0 && hit_impulse > 0.001) {
		float decay = exp(-age * 7.0) * hit_impulse;
		float freq = 26.0 + hit_impulse * 12.0;
		float w1 = sin(age * freq + VERTEX.x * 13.0 + VERTEX.y * 9.0);
		float w2 = cos(age * (freq * 0.85) + VERTEX.z * 15.0);
		vec3 dir = normalize(hit_dir + vec3(0.001));
		vec3 disp = NORMAL * w1 * wobble_scale * decay;
		disp += dir * w2 * wobble_scale * 0.55 * decay;
		disp += vec3(0.0, sin(age * freq * 1.3) * wobble_scale * 0.25 * decay, 0.0);
		VERTEX += disp;
	}
}

void fragment() {
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	// Ambient fill — toon'da düz alanlar boğulmasın
	EMISSION = albedo_color.rgb * ambient_boost;
	if (emission_energy > 0.001) {
		EMISSION += emission_color * emission_energy;
	}
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.8);
	EMISSION += rim_color * fresnel * rim_strength;
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	// Soft half-Lambert → band
	float hl = ndotl * 0.5 + 0.5;
	float bands = float(max(shade_bands, 2));
	float stepped = floor(hl * bands) / max(bands - 1.0, 1.0);
	stepped = clamp(stepped, 0.0, 1.0);

	vec3 shade = mix(shadow_tint, vec3(1.0), mix(1.0 - shadow_strength, 1.0, stepped));
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * shade;
}
