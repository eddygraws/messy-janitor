shader_type spatial;
render_mode cull_disabled, specular_disabled;


global uniform float wind_scale;
global uniform float wind_speed;
global uniform float wind_strength;
global uniform vec3 wind_direction;
global uniform sampler2D wind_noise : filter_linear_mipmap;

uniform sampler2D flower_texture : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flower_bendiness = 1.0;
uniform float sway_back : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float light_steps = 3.0;

varying vec3 node_pos_view;
varying vec3 node_pos_world;
varying vec4 world_pos;

vec4 CalculateWind(vec4 position, float speed, vec3 rotate_direction, float bend, float uv_scale, float mip_level){

	// Scrolling Wind Noise
	vec3 noise_texture = textureLod(wind_noise, (position.xz * uv_scale) + (speed * -wind_direction.xz), mip_level).rgb;
	noise_texture = noise_texture * (1. + sway_back) - sway_back;

	// Vertex Displacement
	vec4 displace = vec4((noise_texture * rotate_direction - noise_texture * noise_texture * vec3(0.0, 1.0, 0.0) * bend) , 0.0);
	return displace;
}

void vertex() {
	// Parameters
	world_pos = MODEL_MATRIX * vec4(VERTEX, 1.0);
	node_pos_view = NODE_POSITION_VIEW;
	node_pos_world = NODE_POSITION_WORLD;

	// Wind Animation
	float speed = TIME * wind_speed;
	float uv_scale = wind_scale;
	float wind_intensity = wind_strength * flower_bendiness;

	vec4 direction = inverse(MODEL_MATRIX) * vec4(wind_direction, 0.0);

	vec4 displace = CalculateWind(world_pos, speed, direction.xyz, flower_bendiness, uv_scale, 4.0);
	displace *= wind_intensity;

	VERTEX += displace.rgb;
}

void fragment() {

	vec4 color = texture(flower_texture, UV);

	ALBEDO = color.rgb * tint.rgb;
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.75;

	SPECULAR = 0.0;
	ROUGHNESS = 0.0;
	LIGHT_VERTEX = node_pos_view;
}

void light(){
	float light = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	light = round(light * light_steps) / light_steps;

	DIFFUSE_LIGHT += light * (LIGHT_COLOR / PI) * ATTENUATION;
}
