shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Animal Crossing style world-curve — flat mesh, far Y drops.
// Horizon is a separate layer; this is only playable ground/decor.

uniform vec3 curve_cam_pos = vec3(0.0, 0.0, 0.0);
uniform float curve_strength : hint_range(0.0, 0.08, 0.001) = 0.018;
uniform float curve_max_drop : hint_range(0.0, 40.0, 0.1) = 18.0;
uniform vec4 albedo_color : source_color = vec4(0.25, 0.48, 0.28, 1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform float roughness : hint_range(0.0, 1.0) = 0.92;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float uv_scale = 6.0;
uniform bool use_texture = false;

varying vec3 world_pos_v;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 d = world.xz - curve_cam_pos.xz;
	float dist2 = dot(d, d);
	float drop = min(dist2 * curve_strength, curve_max_drop);
	world.y -= drop;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	world_pos_v = world;
}

void fragment() {
	vec4 alb = albedo_color;
	if (use_texture) {
		vec4 tex_s = texture(albedo_tex, UV * uv_scale);
		alb.rgb *= tex_s.rgb;
		// Alpha’yı texture’dan alma — props’ta görünmezlik yapıyordu
	}
	ALBEDO = alb.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
