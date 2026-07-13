class_name GrimeShaderHelper
extends RefCounted

const GRIME_SHADER := preload("res://shaders/grime_dissolve.gdshader")


static func apply_to_canvas_item(item: CanvasItem) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GRIME_SHADER
	mat.set_shader_parameter("dissolve", 0.0)
	mat.set_shader_parameter("pulse", 0.0)
	item.material = mat
	return mat


static func apply_to_polygon(poly: Polygon2D) -> ShaderMaterial:
	return apply_to_canvas_item(poly)


static func set_dissolve(mat: ShaderMaterial, progress: float, pulse: float = 0.0) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("dissolve", clampf(progress, 0.0, 1.0))
	mat.set_shader_parameter("pulse", pulse)
