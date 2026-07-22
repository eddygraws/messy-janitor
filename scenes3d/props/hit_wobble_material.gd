class_name HitWobbleMaterial
extends RefCounted

const WOBBLE_SHADER := preload("res://shaders/hit_wobble.gdshader")
const OUTLINE_SHADER := preload("res://shaders/mesh_outline.gdshader")

static var _shared_outline: ShaderMaterial


static func create(
	albedo: Color,
	roughness: float = 0.88,
	emission: Color = Color.BLACK,
	emission_energy: float = 0.0,
	wobble_scale: float = 0.09,
	with_outline: bool = true,
	outline_width: float = 0.03,
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WOBBLE_SHADER
	mat.set_shader_parameter("albedo_color", albedo)
	mat.set_shader_parameter("roughness", roughness)
	mat.set_shader_parameter("emission_color", Vector3(emission.r, emission.g, emission.b))
	mat.set_shader_parameter("emission_energy", emission_energy)
	mat.set_shader_parameter("wobble_scale", wobble_scale)
	mat.set_shader_parameter("hit_impulse", 0.0)
	mat.set_shader_parameter("hit_time", -1000.0)
	mat.set_shader_parameter("hit_dir", Vector3.FORWARD)
	mat.set_shader_parameter("shade_bands", 3)
	mat.set_shader_parameter("shadow_tint", Vector3(0.35, 0.32, 0.55))
	mat.set_shader_parameter("shadow_strength", 0.55)
	mat.set_shader_parameter("rim_strength", 0.32)
	mat.set_shader_parameter("rim_color", Vector3(1.0, 0.95, 0.85))
	mat.set_shader_parameter("ambient_boost", 0.2)
	if with_outline:
		mat.next_pass = _make_outline(outline_width)
	return mat


## Zemin / duvar — toon, outline yok (düz yüzeylerde hull çirkin).
static func create_flat(
	albedo: Color,
	roughness: float = 0.92,
	rim: float = 0.12,
) -> ShaderMaterial:
	var mat := create(albedo, roughness, Color.BLACK, 0.0, 0.0, false)
	mat.set_shader_parameter("rim_strength", rim)
	mat.set_shader_parameter("ambient_boost", 0.28)
	mat.set_shader_parameter("shadow_strength", 0.4)
	return mat


static func _make_outline(width: float) -> ShaderMaterial:
	# Ortak outline; width farklıysa kopya
	if _shared_outline != null and is_equal_approx(float(_shared_outline.get_shader_parameter("outline_width")), width):
		return _shared_outline
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter("outline_color", Color(0.07, 0.05, 0.1, 1.0))
	outline.set_shader_parameter("outline_width", width)
	if is_equal_approx(width, 0.03):
		_shared_outline = outline
	return outline


static func apply_hit(mat: ShaderMaterial, hit_dir: Vector3, _game_time: float = 0.0, strength: float = 1.0) -> void:
	if mat == null or mat.shader == null:
		return
	var prev: float = float(mat.get_shader_parameter("hit_impulse"))
	mat.set_shader_parameter("hit_impulse", minf(prev + strength * 0.45, 1.85))
	# Shader TIME = motor başlangıcından beri sn; prop lokal _game_time ile uyumsuzdu.
	mat.set_shader_parameter("hit_time", Time.get_ticks_msec() * 0.001)
	var dir := hit_dir
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	mat.set_shader_parameter("hit_dir", dir.normalized())
