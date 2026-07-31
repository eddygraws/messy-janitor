class_name RoomToonMaterial
extends RefCounted

## Floor/wall ShaderMaterial helpers for res://shaders/toon_shader.gdshader

const FLOOR_TEMPLATE := preload("res://materials/floor_toon_mat.tres")
const WALL_TEMPLATE := preload("res://materials/wall_toon_mat.tres")

## Optional generated albedo (tools/generate_tile_texture.py --batch)
const FLOOR_TEX_DEFAULT := "res://textures/generated/floor_kitchen_clay.png"
const WALL_TEX_DEFAULT := "res://textures/generated/wall_plaster_warm.png"


static func make_floor(
	albedo: Color,
	dark_room: bool = false,
	texture_path: String = FLOOR_TEX_DEFAULT,
) -> ShaderMaterial:
	var mat := FLOOR_TEMPLATE.duplicate() as ShaderMaterial
	mat.set_shader_parameter("albedo_color", albedo)
	_try_set_albedo_texture(mat, texture_path)
	if dark_room:
		mat.set_shader_parameter("ambient_boost", 0.04)
		mat.set_shader_parameter("shadow_strength", 0.85)
		mat.set_shader_parameter("enable_rim", false)
		mat.set_shader_parameter("rim_strength", 0.0)
	return mat


static func make_wall(
	albedo: Color,
	dark_room: bool = false,
	texture_path: String = WALL_TEX_DEFAULT,
) -> ShaderMaterial:
	var mat := WALL_TEMPLATE.duplicate() as ShaderMaterial
	mat.set_shader_parameter("albedo_color", albedo)
	_try_set_albedo_texture(mat, texture_path)
	if dark_room:
		mat.set_shader_parameter("ambient_boost", 0.05)
		mat.set_shader_parameter("shadow_strength", 0.8)
		mat.set_shader_parameter("rim_strength", 0.12)
	return mat


static func _try_set_albedo_texture(mat: ShaderMaterial, path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var tex := load(path)
	if tex != null:
		mat.set_shader_parameter("albedo_texture", tex)
