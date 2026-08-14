shader_type spatial;
render_mode cull_disabled, unshaded, specular_disabled;

// Path ribbon — vertex color + world curve

uniform vec3 curve_cam_pos = vec3(0.0, 0.0, 0.0);
uniform float curve_strength : hint_range(0.0, 0.08, 0.001) = 0.018;
uniform float curve_max_drop : hint_range(0.0, 40.0, 0.1) = 18.0;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 d = world.xz - curve_cam_pos.xz;
	float dist2 = dot(d, d);
	float drop = min(dist2 * curve_strength, curve_max_drop);
	world.y -= drop;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
