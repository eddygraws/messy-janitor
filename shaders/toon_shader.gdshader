shader_type spatial;
// Cel/toon shading for room surfaces (floor / walls).
// Lights stay untouched — this only changes how the mesh receives light.
render_mode diffuse_toon, specular_toon, cull_back;

uniform vec4 albedo_color : source_color = vec4(0.34, 0.36, 0.38, 1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_nearest, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_normal_map = false;
uniform vec2 uv_tiling = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

uniform int shade_bands : hint_range(2, 6) = 3;
uniform vec3 shadow_color : source_color = vec3(0.22, 0.20, 0.32);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.55;

uniform bool enable_rim = false;
uniform vec3 rim_color : source_color = vec3(1.0, 0.95, 0.88);
uniform float rim_power : hint_range(0.5, 8.0) = 3.2;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.3;

uniform float specular_size : hint_range(0.0, 1.0) = 0.12;
uniform float specular_smoothness : hint_range(0.001, 0.5) = 0.04;
uniform vec3 specular_color : source_color = vec3(1.0, 0.98, 0.94);

uniform float ambient_boost : hint_range(0.0, 0.5) = 0.08;

varying vec2 v_uv;

void vertex() {
	v_uv = UV * uv_tiling + uv_offset;
}

void fragment() {
	vec3 tex = texture(albedo_texture, v_uv).rgb;
	ALBEDO = albedo_color.rgb * tex;
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
	EMISSION = ALBEDO * ambient_boost;

	if (use_normal_map) {
		NORMAL_MAP = texture(normal_texture, v_uv).rgb;
	}

	if (enable_rim) {
		float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
		EMISSION += rim_color * fresnel * rim_strength;
	}
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	// Soft wrap → discrete bands (hard-edged toon shadow)
	float hl = ndotl * 0.5 + 0.5;
	float bands = float(max(shade_bands, 2));
	float stepped = floor(hl * bands) / max(bands - 1.0, 1.0);
	stepped = clamp(stepped, 0.0, 1.0);

	vec3 shade = mix(shadow_color, vec3(1.0), mix(1.0 - shadow_strength, 1.0, stepped));
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * shade;

	// Hard-cutoff specular highlight (cel style)
	vec3 half_v = normalize(VIEW + LIGHT);
	float ndoth = clamp(dot(NORMAL, half_v), 0.0, 1.0);
	float edge0 = 1.0 - specular_size - specular_smoothness;
	float edge1 = 1.0 - specular_size;
	float spec = smoothstep(edge0, edge1, ndoth) * step(0.02, ndotl);
	SPECULAR_LIGHT += specular_color * LIGHT_COLOR * ATTENUATION * spec;
}
