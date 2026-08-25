class_name PixelArtMaterial
extends RefCounted

## DemoForest trunk shader + A Short Hike mesh look.
## MeshInstance3D.material_override = PixelArtMaterial.create_textured(tex)

const SHADER := preload("res://shaders/pixel_art_mesh.gdshader")
const OUTLINE_SHADER := preload("res://shaders/mesh_outline.gdshader")


static func create_color(albedo: Color, with_outline: bool = true) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("albedo_color", albedo)
	mat.set_shader_parameter("use_texture", false)
	mat.set_shader_parameter("light_steps", 3.0)
	mat.set_shader_parameter("pivot_shade", true)
	mat.set_shader_parameter("outline_mask", 1.0)
	if with_outline:
		mat.next_pass = _outline(0.022)
	return mat


static func create_textured(
	tex: Texture2D,
	tint: Color = Color.WHITE,
	uv_scale: Vector2 = Vector2.ONE,
	with_outline: bool = true,
) -> ShaderMaterial:
	var mat := create_color(tint, with_outline)
	if tex != null:
		mat.set_shader_parameter("color_texture", tex)
		mat.set_shader_parameter("use_texture", true)
	mat.set_shader_parameter("uv_scale", uv_scale)
	return mat


static func _outline(width: float) -> ShaderMaterial:
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter("outline_color", Color(0.06, 0.04, 0.09, 1.0))
	outline.set_shader_parameter("outline_width", width)
	return outline
