#[compute]
#version 450
// Nearest pixelize. Kopya tampon yok — her blok yalnız kendi merkez texelini okur,
// başka blok o texele yazmaz, bu yüzden in-place imageLoad güvenli.
// texture_copy framebuffer'da CAN_COPY_FROM olmadığı için siyaha gidiyordu.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) readonly buffer Params {
	vec2 raster_size;
	float pixel_size;
	float outline_strength;
	mat4 inv_proj_mat;
} params;

layout(rgba16f, set = 0, binding = 1) uniform image2D color_image;
layout(set = 0, binding = 2) uniform sampler2D depth_texture;

float linear_depth(vec2 uv) {
	float raw = texture(depth_texture, uv).r;
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw);
	vec4 view = params.inv_proj_mat * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

void main() {
	ivec2 dest = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (dest.x >= size.x || dest.y >= size.y) {
		return;
	}

	int ps = max(int(params.pixel_size + 0.5), 1);
	ivec2 block = dest / ps;
	ivec2 sample_at = block * ps + ivec2(ps / 2);
	sample_at = clamp(sample_at, ivec2(0), size - ivec2(1));

	vec4 color = imageLoad(color_image, sample_at);

	if (params.outline_strength > 0.001 && ps > 1) {
		vec2 texel = 1.0 / params.raster_size;
		vec2 uv = (vec2(sample_at) + 0.5) * texel;
		float d = linear_depth(uv);
		float diff = 0.0;
		vec2 offs[4];
		offs[0] = vec2(0.0, -1.0);
		offs[1] = vec2(0.0, 1.0);
		offs[2] = vec2(1.0, 0.0);
		offs[3] = vec2(-1.0, 0.0);
		for (int i = 0; i < 4; i++) {
			float n = linear_depth(uv + offs[i] * texel * float(ps));
			diff += clamp(n - d, 0.0, 1.0);
		}
		float edge = smoothstep(0.45, 0.5, diff);
		color.rgb = mix(color.rgb, color.rgb * 0.45, edge * params.outline_strength);
	}

	imageStore(color_image, dest, color);
}
