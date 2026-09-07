class_name RoomToonMaterial
extends RefCounted

## Floor/wall ShaderMaterial helpers for res://shaders/toon_shader.gdshader

const FLOOR_TEMPLATE := preload("res://materials/floor_toon_mat.tres")
const WALL_FALLBACK := preload("res://materials/wall_toon_mat.tres")

const FLOOR_TEX_DEFAULT := "res://textures/generated/floor_kitchen_clay.png"

## Named wall kits: primary + sibling (Back vs Left vary).
const WALL_STYLES := {
	"plaster": [
		"res://materials/walls/wall_plaster_warm.tres",
		"res://materials/walls/wall_plaster_warm_b.tres",
	],
	"garage": [
		"res://materials/walls/wall_brick_garage.tres",
		"res://materials/walls/wall_brick_peach.tres",
	],
	"mold": [
		"res://materials/walls/wall_brick_mold.tres",
		"res://materials/walls/wall_plaster_warm_b.tres",
	],
	"cool": [
		"res://materials/walls/wall_brick_cool.tres",
		"res://materials/walls/wall_plaster_warm.tres",
	],
	"ritual": [
		"res://materials/walls/wall_brick_ritual.tres",
		"res://materials/walls/wall_brick_cool.tres",
	],
	"peach": [
		"res://materials/walls/wall_brick_peach.tres",
		"res://materials/walls/wall_brick_garage.tres",
	],
}

## Chapter / room id → wall style
const STYLE_BY_ID := {
	"garage": "garage",
	"liquids": "garage",
	"mold": "mold",
	"broom": "peach",
	"slime": "cool",
	"brush": "ritual",
	"spray": "cool",
	"alien": "cool",
	"tweezers": "plaster",
	"dark": "cool",
	"ritual": "ritual",
	"finale": "garage",
}


static func make_floor(
	albedo: Color,
	dark_room: bool = false,
	texture_path: String = "",
) -> ShaderMaterial:
	if texture_path.is_empty():
		texture_path = FLOOR_TEX_DEFAULT
	var mat := FLOOR_TEMPLATE.duplicate() as ShaderMaterial
	mat.set_shader_parameter("albedo_color", albedo)
	mat.set_shader_parameter("specular_size", 0.0)
	mat.set_shader_parameter("specular_color", Vector3.ZERO)
	_try_set_albedo_texture(mat, texture_path)
	if dark_room:
		mat.set_shader_parameter("ambient_boost", 0.04)
		mat.set_shader_parameter("shadow_strength", 0.85)
		mat.set_shader_parameter("enable_rim", false)
		mat.set_shader_parameter("rim_strength", 0.0)
	return mat


## wall_index: 0 = WallBack, 1 = WallLeft (sibling material + slight tint/UV shift)
static func make_wall(
	albedo: Color,
	dark_room: bool = false,
	style: String = "plaster",
	wall_index: int = 0,
) -> ShaderMaterial:
	var mat := _load_wall_template(style, wall_index)
	# Level color tints the baked brick albedo (keep near-white base on .tres)
	var tint := albedo
	tint.s = clampf(tint.s * 0.35, 0.0, 0.55)
	tint.v = clampf(lerpf(0.85, tint.v, 0.55), 0.55, 1.0)
	# Per-wall micro variation
	if wall_index == 1:
		tint = tint.lightened(0.04)
	else:
		tint = tint.darkened(0.03)
	mat.set_shader_parameter("albedo_color", tint)

	var base_off := Vector2.ZERO
	var raw_off = mat.get_shader_parameter("uv_offset")
	if raw_off is Vector2:
		base_off = raw_off as Vector2
	mat.set_shader_parameter(
		"uv_offset",
		base_off + Vector2(0.11 * float(wall_index), 0.07 * float(wall_index % 2))
	)

	if dark_room:
		mat.set_shader_parameter("ambient_boost", 0.05)
		mat.set_shader_parameter("shadow_strength", 0.8)
		mat.set_shader_parameter("rim_strength", 0.12)
		mat.set_shader_parameter("specular_size", 0.02)
	return mat


static func wall_style_for_spec(spec: Dictionary) -> String:
	if spec.has("wall_style"):
		return String(spec.get("wall_style", "plaster"))
	var id := String(spec.get("id", ""))
	# Expanded chapter ids look like mold_t0 — take prefix before _t
	var key := id
	var t_at := id.find("_t")
	if t_at > 0:
		key = id.substr(0, t_at)
	if STYLE_BY_ID.has(key):
		return String(STYLE_BY_ID[key])
	# Tutorial sections / garage
	if bool(spec.get("tutorial_level", false)):
		return "garage"
	return "plaster"


static func _load_wall_template(style: String, wall_index: int) -> ShaderMaterial:
	var paths: Array = WALL_STYLES.get(style, WALL_STYLES["plaster"]) as Array
	var idx := clampi(wall_index, 0, paths.size() - 1)
	var path := String(paths[idx])
	if ResourceLoader.exists(path):
		var loaded := load(path) as ShaderMaterial
		if loaded != null:
			return loaded.duplicate(true) as ShaderMaterial
	return WALL_FALLBACK.duplicate(true) as ShaderMaterial


static func _try_set_albedo_texture(mat: ShaderMaterial, path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var tex := load(path)
	if tex != null:
		mat.set_shader_parameter("albedo_texture", tex)
