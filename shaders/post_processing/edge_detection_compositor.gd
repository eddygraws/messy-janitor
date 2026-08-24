@tool
class_name EdgeDetectionCompositor
extends CompositorEffect

## Vegetation tutorial'daki depth outline compute shader'ı.
## Janitor 3D kamerasına EdgeDetectionLook ile bağlanır.

const SHADER_PATH := "res://shaders/post_processing/edge_detection_shader.glsl"

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var parameter_storage_buffer := RID()
var texture_sampler := RID()


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_OPAQUE
	needs_normal_roughness = true
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_initialize_compute)

	var data := PackedFloat32Array()
	data.resize(20)
	data.fill(0)
	var parameter_data := data.to_byte_array()
	parameter_storage_buffer = rd.storage_buffer_create(parameter_data.size(), parameter_data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if rd == null:
			return
		if shader.is_valid():
			rd.free_rid(shader)
		if parameter_storage_buffer.is_valid():
			rd.free_rid(parameter_storage_buffer)
		if texture_sampler.is_valid():
			rd.free_rid(texture_sampler)


func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return

	var shader_file := load(SHADER_PATH) as RDShaderFile
	if shader_file == null:
		push_error("EdgeDetectionCompositor: shader yüklenemedi: %s" % SHADER_PATH)
		return

	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	if shader.is_valid():
		pipeline = rd.compute_pipeline_create(shader)

	if not texture_sampler.is_valid():
		var sampler_state := RDSamplerState.new()
		texture_sampler = rd.sampler_create(sampler_state)


func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if not rd or p_effect_callback_type != EFFECT_CALLBACK_TYPE_POST_OPAQUE:
		return
	if not pipeline.is_valid() or not texture_sampler.is_valid():
		return

	var render_scene_buffers := p_render_data.get_render_scene_buffers()
	if render_scene_buffers == null:
		return

	var size: Vector2i = render_scene_buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return

	@warning_ignore("integer_division")
	var x_groups: int = (size.x - 1) / 8 + 1
	@warning_ignore("integer_division")
	var y_groups: int = (size.y - 1) / 8 + 1
	var z_groups := 1

	var view_count: int = render_scene_buffers.get_view_count()
	for view in view_count:
		var input_image: RID = render_scene_buffers.get_color_layer(view)
		var input_depth: RID = render_scene_buffers.get_depth_layer(view)
		var input_normal: RID = render_scene_buffers.get_texture("forward_clustered", "normal_roughness")
		if not input_image.is_valid() or not input_depth.is_valid() or not input_normal.is_valid():
			continue

		var parameters := PackedFloat32Array([float(size.x), float(size.y), 0.0, 0.0])
		var inv_proj_mat: Projection = p_render_data.get_render_scene_data().get_cam_projection().inverse()
		var inv_proj_mat_array := PackedVector4Array([inv_proj_mat.x, inv_proj_mat.y, inv_proj_mat.z, inv_proj_mat.w])

		var parameter_data := parameters.to_byte_array()
		parameter_data.append_array(inv_proj_mat_array.to_byte_array())
		rd.buffer_update(parameter_storage_buffer, 0, parameter_data.size(), parameter_data)

		var uniform_parameter := RDUniform.new()
		uniform_parameter.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		uniform_parameter.binding = 0
		uniform_parameter.add_id(parameter_storage_buffer)

		var uniform_color := RDUniform.new()
		uniform_color.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform_color.binding = 1
		uniform_color.add_id(input_image)

		var uniform_depth := RDUniform.new()
		uniform_depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		uniform_depth.binding = 2
		uniform_depth.add_id(texture_sampler)
		uniform_depth.add_id(input_depth)

		var uniform_normal := RDUniform.new()
		uniform_normal.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		uniform_normal.binding = 3
		uniform_normal.add_id(texture_sampler)
		uniform_normal.add_id(input_normal)

		var uniform_set := UniformSetCacheRD.get_cache(shader, 0, [
			uniform_parameter, uniform_color, uniform_depth, uniform_normal
		])

		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
		rd.compute_list_end()
