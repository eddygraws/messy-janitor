class_name ComedyParticles
extends Node3D

## Komik abartılı partikül patlamaları (CPUParticles3D).

var _pool: Array[CPUParticles3D] = []


func burst(kind: StringName, world_pos: Vector3, strength: float = 1.0) -> void:
	var fx := _acquire()
	fx.global_position = world_pos + Vector3(0.0, 0.6, 0.0)
	if kind == &"hit":
		_configure(fx, Color(1.0, 0.85, 0.4), 18, 4.5 * strength, 0.35)
	elif kind == &"scrub":
		_configure(fx, Color(0.55, 0.38, 0.22), 14, 2.8 * strength, 0.42)
		fx.gravity = Vector3(0, -6.0, 0)
		fx.spread = 70.0
		fx.scale_amount_min = 0.05
		fx.scale_amount_max = 0.14
	elif kind == &"clean":
		_configure(fx, Color(0.55, 1.0, 0.65), 28, 6.5 * strength, 0.48)
		fx.gravity = Vector3(0, -4.0, 0)
		_burst_extra(world_pos, Color(1.0, 0.88, 0.35), 12, 5.0 * strength, 0.35)
	elif kind == &"dash":
		_configure(fx, Color(0.45, 0.95, 1.0), 36, 9.0, 0.38)
	elif kind == &"bump":
		_configure(fx, Color(1.0, 0.55, 0.95), 34, 9.5 * strength, 0.5)
	elif kind == &"dance":
		_configure(fx, Color(1.0, 0.45, 0.85), 30, 5.5, 0.55)
	elif kind == &"dispose":
		_configure(fx, Color(0.45, 1.0, 0.55), 24, 5.0, 0.4)
	elif kind == &"rinse":
		_configure(fx, Color(0.4, 0.75, 1.0), 20, 3.5, 0.5)
	elif kind == &"throw":
		_configure(fx, Color(1.0, 0.7, 0.35), 16, 5.5, 0.35)
	elif kind == &"suck":
		_configure(fx, Color(0.7, 0.92, 1.0), 28, 4.2 * strength, 0.32)
		fx.direction = Vector3(0, 0.2, -1)
		fx.spread = 42.0
		fx.gravity = Vector3(0, 0.6, 0)
		fx.initial_velocity_min = 2.0 * strength
		fx.initial_velocity_max = 5.5 * strength
		fx.scale_amount_min = 0.035
		fx.scale_amount_max = 0.1
		_burst_extra(world_pos, Color(1.0, 0.95, 0.55), 10, 3.0 * strength, 0.2)
		_burst_extra(world_pos + Vector3(0, 0.2, 0), Color(0.55, 0.9, 1.0), 12, 2.2 * strength, 0.28)
	else:
		_configure(fx, Color(1, 1, 1), 12, 3.0, 0.3)
	fx.restart()
	fx.emitting = true


func _burst_extra(world_pos: Vector3, color: Color, amount: int, speed: float, lifetime: float) -> void:
	var fx := _acquire()
	fx.global_position = world_pos + Vector3(0.0, 0.75, 0.0)
	_configure(fx, color, amount, speed, lifetime)
	fx.gravity = Vector3(0, -3.5, 0)
	fx.restart()
	fx.emitting = true


func _acquire() -> CPUParticles3D:
	for existing in _pool:
		if existing != null and not existing.emitting:
			return existing
	var spawned := CPUParticles3D.new()
	spawned.name = "ComedyBurst"
	spawned.one_shot = true
	spawned.explosiveness = 0.92
	spawned.local_coords = false
	spawned.emitting = false
	add_child(spawned)
	_pool.append(spawned)
	return spawned


func _configure(fx: CPUParticles3D, color: Color, amount: int, speed: float, lifetime: float) -> void:
	fx.amount = amount
	fx.lifetime = lifetime
	fx.direction = Vector3(0, 1, 0)
	fx.spread = 55.0
	fx.initial_velocity_min = speed * 0.55
	fx.initial_velocity_max = speed
	fx.gravity = Vector3(0, -14.0, 0)
	fx.scale_amount_min = 0.08
	fx.scale_amount_max = 0.22
	fx.color = color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fx.mesh = SphereMesh.new()
	(fx.mesh as SphereMesh).radius = 0.08
	(fx.mesh as SphereMesh).height = 0.16
	fx.material_override = mat
