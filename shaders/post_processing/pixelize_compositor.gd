@tool
class_name PixelizeCompositor
extends CompositorEffect

## 3D buffer'ı tamsayı piksel ızgarasına nearest snap eder.
## scaling_3d_scale KULLANMA — Godot onu bilinear büyütür, pikseli eritir.

const SHADER_PATH := "res://shaders/post_processing/pixelize_shader.glsl"

@export var pixel_size: int = 3
@export var outline_strength: float = 0.55

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var parameter_storage_buffer := RID()
var texture_sampler := RID()


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	access_resolved_depth = true
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_initialize_compute)


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE or rd == null:
		return
	if shader.is_valid():
		rd.free_rid(shader)
	if parameter_storage_buffer.is_valid():
		rd.free_rid(parameter_storage_buffer)
	if texture_sampler.is_valid():
		rd.free_rid(texture_sampler)


func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		return
	if not parameter_storage_buffer.is_valid():
		var data := PackedFloat32Array()
		data.resize(20)
		data.fill(0)
		parameter_storage_buffer = rd.storage_buffer_create(data.to_byte_array().size(), data.to_byte_array())
	var shader_file := load(SHADER_PATH) as RDShaderFile
	if shader_file == null:
		push_error("PixelizeCompositor: shader yok: %s" % SHADER_PATH)
		return
	var spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(spirv)
	if shader.is_valid():
		pipeline = rd.compute_pipeline_create(shader)
	if not texture_sampler.is_valid():
		var st := RDSamplerState.new()
		st.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
		st.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
		texture_sampler = rd.sampler_create(st)


func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if not rd or p_effect_callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		return
	if not pipeline.is_valid() or not texture_sampler.is_valid() or not parameter_storage_buffer.is_valid():
		return
	var ps := maxi(pixel_size, 1)
	if ps <= 1:
		return

	var buffers := p_render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	var size: Vector2i = buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return

	@warning_ignore("integer_division")
	var x_groups: int = (size.x - 1) / 8 + 1
	@warning_ignore("integer_division")
	var y_groups: int = (size.y - 1) / 8 + 1

	var inv_proj: Projection = p_render_data.get_render_scene_data().get_cam_projection().inverse()
	var parameters := PackedFloat32Array([
		float(size.x), float(size.y), float(ps), outline_strength
	])
	var parameter_data := parameters.to_byte_array()
	parameter_data.append_array(PackedVector4Array([
		inv_proj.x, inv_proj.y, inv_proj.z, inv_proj.w
	]).to_byte_array())

	for view in buffers.get_view_count():
		var color_image: RID = buffers.get_color_layer(view)
		var depth_image: RID = buffers.get_depth_layer(view)
		if not color_image.is_valid() or not depth_image.is_valid():
			continue
		rd.buffer_update(parameter_storage_buffer, 0, parameter_data.size(), parameter_data)

		var u_params := RDUniform.new()
		u_params.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		u_params.binding = 0
		u_params.add_id(parameter_storage_buffer)

		var u_color := RDUniform.new()
		u_color.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u_color.binding = 1
		u_color.add_id(color_image)

		var u_depth := RDUniform.new()
		u_depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u_depth.binding = 2
		u_depth.add_id(texture_sampler)
		u_depth.add_id(depth_image)

		var uniform_set := UniformSetCacheRD.get_cache(shader, 0, [u_params, u_color, u_depth])
		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
		rd.compute_list_end()
