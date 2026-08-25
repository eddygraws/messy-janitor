shader_type spatial;
render_mode specular_disabled;

/// A Short Hike / DemoForest mesh look:
/// nearest texture + quantized light + optional pivot shading.
/// Apply as ShaderMaterial on MeshInstance3D.material_override.

uniform float light_steps = 3.0;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D color_texture : source_color, hint_default_white, filter_nearest;
uniform bool use_texture = true;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform float outline_mask = 1.0;
uniform bool pivot_shade = true;

varying float occlusion;
varying vec3 node_pos_view;

void vertex() {
	node_pos_view = NODE_POSITION_VIEW;
}

void fragment() {
	occlusion = round(COLOR.r * light_steps) / light_steps;
	vec4 color = albedo_color;
	if (use_texture) {
		color *= texture(color_texture, UV * uv_scale);
	}
	ALBEDO = color.rgb;
	SPECULAR = 0.0;
	ROUGHNESS = outline_mask;
	if (pivot_shade) {
		LIGHT_VERTEX = node_pos_view;
	}
}

void light() {
	float light = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	light = ceil(light * light_steps) / light_steps;
	DIFFUSE_LIGHT += light * ATTENUATION * occlusion * LIGHT_COLOR / PI;
}
