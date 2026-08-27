shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_disabled, shadows_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float cut : hint_range(0.0, 1.0) = 0.08;

void vertex() {
	vec4 mv_origin = VIEW_MATRIX * MODEL_MATRIX[3];
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	float sz = length(MODEL_MATRIX[2].xyz);
	vec3 cam_fwd = INV_VIEW_MATRIX[2].xyz;
	vec3 right = cross(vec3(0.0, 1.0, 0.0), cam_fwd);
	if (length(right) < 0.001) {
		right = vec3(1.0, 0.0, 0.0);
	} else {
		right = normalize(right);
	}
	vec3 fwd = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
	MODELVIEW_MATRIX = mat4(
		vec4(right * sx, 0.0),
		vec4(0.0, sy, 0.0, 0.0),
		vec4(fwd * sz, 0.0),
		mv_origin
	);
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	float lum = max(c.r, max(c.g, c.b));
	float a = max(c.a, lum);
	if (a < cut) {
		discard;
	}
	ALBEDO = c.rgb * tint.rgb;
	ALPHA = 1.0;
	ROUGHNESS = 0.9;
	SPECULAR = 0.0;
}
