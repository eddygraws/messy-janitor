class_name ComedyParticles
extends Node3D

## Komik abartılı partikül patlamaları (CPUParticles3D).

var _pool: Array[CPUParticles3D] = []


func burst(kind: StringName, world_pos: Vector3, strength: float = 1.0) -> void:
	var p := _acquire()
	p.global_position = world_pos + Vector3(0.0, 0.6, 0.0)
	match kind:
		&"hit":
			_configure(p, Color(1.0, 0.85, 0.4), 18, 4.5 * strength, 0.35)
		&"scrub":
			_configure(p, Color(0.55, 0.38, 0.22), 14, 2.8 * strength, 0.42)
			p.gravity = Vector3(0, -6.0, 0)
			p.spread = 70.0
			p.scale_amount_min = 0.05
			p.scale_amount_max = 0.14
		&"clean":
			_configure(p, Color(0.55, 1.0, 0.65), 28, 6.5 * strength, 0.48)
			p.gravity = Vector3(0, -4.0, 0)
			# İkinci kısa altın kıvılcım
			_burst_extra(world_pos, Color(1.0, 0.88, 0.35), 12, 5.0 * strength, 0.35)
		&"dash":
			_configure(p, Color(0.45, 0.95, 1.0), 36, 9.0, 0.38)
		&"bump":
			_configure(p, Color(1.0, 0.55, 0.95), 34, 9.5 * strength, 0.5)
		&"dance":
			_configure(p, Color(1.0, 0.45, 0.85), 30, 5.5, 0.55)
		&"dispose":
			_configure(p, Color(0.45, 1.0, 0.55), 24, 5.0, 0.4)
		&"rinse":
			_configure(p, Color(0.4, 0.75, 1.0), 20, 3.5, 0.5)
		&"throw":
			_configure(p, Color(1.0, 0.7, 0.35), 16, 5.5, 0.35)
		&"suck":
			# Luigi emme akışı — nozule doğru çekilen toz
			_configure(p, Color(0.75, 0.9, 1.0), 22, 3.2 * strength, 0.28)
			p.direction = Vector3(0, 0.35, -1)
			p.spread = 28.0
			p.gravity = Vector3(0, 1.5, 0)
			p.initial_velocity_min = 1.5 * strength
			p.initial_velocity_max = 4.0 * strength
			p.scale_amount_min = 0.04
			p.scale_amount_max = 0.11
			_burst_extra(world_pos, Color(0.95, 0.85, 0.35), 8, 2.5 * strength, 0.22)
		_:
			_configure(p, Color(1, 1, 1), 12, 3.0, 0.3)
	p.restart()
	p.emitting = true


func _burst_extra(world_pos: Vector3, color: Color, amount: int, speed: float, lifetime: float) -> void:
	var p := _acquire()
	p.global_position = world_pos + Vector3(0.0, 0.75, 0.0)
	_configure(p, color, amount, speed, lifetime)
	p.gravity = Vector3(0, -3.5, 0)
	p.restart()
	p.emitting = true


func _acquire() -> CPUParticles3D:
	for p in _pool:
		if p != null and not p.emitting:
			return p
	var p := CPUParticles3D.new()
	p.name = "ComedyBurst"
	p.one_shot = true
	p.explosiveness = 0.92
	p.local_coords = false
	p.emitting = false
	add_child(p)
	_pool.append(p)
	return p


func _configure(p: CPUParticles3D, color: Color, amount: int, speed: float, lifetime: float) -> void:
	p.amount = amount
	p.lifetime = lifetime
	p.direction = Vector3(0, 1, 0)
	p.spread = 55.0
	p.initial_velocity_min = speed * 0.55
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -14.0, 0)
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.22
	p.color = color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.mesh = SphereMesh.new()
	(p.mesh as SphereMesh).radius = 0.08
	(p.mesh as SphereMesh).height = 0.16
	p.material_override = mat
