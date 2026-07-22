class_name HitWobbleMaterial
extends RefCounted

const WOBBLE_SHADER := preload("res://shaders/hit_wobble.gdshader")


static func create(
	albedo: Color,
	roughness: float = 0.88,
	emission: Color = Color.BLACK,
	emission_energy: float = 0.0,
	wobble_scale: float = 0.09,
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
	return mat


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
