class_name UfoAbductionDirector
extends Node

## Alien bölümü: UFO iner, ışın konisi açar; oyuncu ışında kalırsa kaçırtılır → level fail.

signal player_abducted
signal ufo_warn(world_pos: Vector3)

@export var room_half_extents: Vector2 = Vector2(5.8, 3.8)
@export var spawn_interval: float = 9.5
@export var max_active: int = 2
@export var warn_time: float = 1.4
@export var hover_height: float = 4.6
@export var beam_radius: float = 1.35
@export var beam_pull_time: float = 1.55 ## Işında bu süre = kaçırılma
@export var escape_grace: float = 0.22 ## Işından çıkınca sayaç bu kadar düşer/sn yerine sıfırlanır
@export var move_speed: float = 2.8

var _player: Node3D
var _world: Node3D
var _active: bool = false
var _spawn_cd: float = 0.0
var _ufos: Array[Dictionary] = [] # {root, beam, phase, timer, target, pull}
var _rng := RandomNumberGenerator.new()
var _abducting: bool = false
var _lift_from: Vector3 = Vector3.ZERO
var _lift_to: Vector3 = Vector3.ZERO


func setup(player: Node3D, world: Node3D, half_x: float = 5.8, half_z: float = 3.8) -> void:
	_player = player
	_world = world
	room_half_extents = Vector2(half_x, half_z)
	_rng.randomize()


func start_session(intensity: float = 1.0) -> void:
	stop_session()
	_active = true
	_abducting = false
	_spawn_cd = lerpf(4.2, 2.4, clampf(intensity, 0.0, 1.0))
	spawn_interval = lerpf(10.5, 7.2, clampf(intensity, 0.0, 1.0))
	max_active = 2 if intensity < 0.75 else 3
	beam_pull_time = lerpf(1.75, 1.25, clampf(intensity, 0.0, 1.0))


func stop_session() -> void:
	_active = false
	_abducting = false
	for u in _ufos:
		var root: Node3D = u.get("root")
		if root != null and is_instance_valid(root):
			root.queue_free()
	_ufos.clear()
	if _player != null and _player.has_method("set_control_locked"):
		_player.call("set_control_locked", false)


func _process(delta: float) -> void:
	if not _active or _abducting:
		return
	if _player == null or not is_instance_valid(_player):
		return
	_spawn_cd -= delta
	if _spawn_cd <= 0.0 and _ufos.size() < max_active:
		_spawn_ufo()
		_spawn_cd = spawn_interval * _rng.randf_range(0.85, 1.2)
	_tick_ufos(delta)


func _spawn_ufo() -> void:
	if _world == null:
		return
	var target := _pick_landing()
	ufo_warn.emit(target)

	var root := Node3D.new()
	root.name = "UFO"
	_world.add_child(root)
	root.global_position = target + Vector3(0.0, hover_height + 7.0, 0.0)

	var saucer := MeshInstance3D.new()
	saucer.name = "Saucer"
	var disk := CylinderMesh.new()
	disk.top_radius = 0.55
	disk.bottom_radius = 1.15
	disk.height = 0.35
	disk.radial_segments = 20
	saucer.mesh = disk
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.55, 0.7, 0.45)
	smat.metallic = 0.65
	smat.roughness = 0.28
	smat.emission_enabled = true
	smat.emission = Color(0.35, 1.0, 0.45)
	smat.emission_energy_multiplier = 1.4
	saucer.material_override = smat
	root.add_child(saucer)

	var dome := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.42
	sph.height = 0.55
	dome.mesh = sph
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.55, 1.0, 0.75, 0.55)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.emission_enabled = true
	dmat.emission = Color(0.4, 1.0, 0.7)
	dmat.emission_energy_multiplier = 2.2
	dome.material_override = dmat
	dome.position = Vector3(0.0, 0.38, 0.0)
	root.add_child(dome)

	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.12
	cone.bottom_radius = beam_radius
	cone.height = hover_height
	cone.radial_segments = 18
	beam.mesh = cone
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bmat.albedo_color = Color(0.45, 1.0, 0.55, 0.22)
	bmat.emission_enabled = true
	bmat.emission = Color(0.5, 1.0, 0.55)
	bmat.emission_energy_multiplier = 2.0
	beam.material_override = bmat
	beam.position = Vector3(0.0, -hover_height * 0.5, 0.0)
	beam.visible = false
	root.add_child(beam)

	# Uyarı halkası (zeminde)
	var ring := MeshInstance3D.new()
	ring.name = "WarnRing"
	var tor := TorusMesh.new()
	tor.inner_radius = beam_radius * 0.72
	tor.outer_radius = beam_radius * 1.05
	tor.rings = 12
	tor.ring_segments = 24
	ring.mesh = tor
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(0.4, 1.0, 0.45, 0.85)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.emission_enabled = true
	rmat.emission = Color(0.5, 1.0, 0.4)
	rmat.emission_energy_multiplier = 2.5
	ring.material_override = rmat
	ring.position = target + Vector3(0.0, 0.06, 0.0)
	_world.add_child(ring)

	_ufos.append({
		"root": root,
		"beam": beam,
		"ring": ring,
		"phase": 0, # 0 descend, 1 hover/beam, 2 leave
		"timer": warn_time,
		"target": target,
		"pull": 0.0,
	})


func _pick_landing() -> Vector3:
	var hx := room_half_extents.x * 0.72
	var hz := room_half_extents.y * 0.72
	var near_player := _rng.randf() < 0.55 and _player != null
	if near_player:
		var p: Vector3 = _player.global_position
		var offset := Vector3(_rng.randf_range(-2.2, 2.2), 0.0, _rng.randf_range(-2.2, 2.2))
		var t := p + offset
		t.x = clampf(t.x, -hx, hx)
		t.z = clampf(t.z, -hz, hz)
		t.y = 0.0
		return t
	return Vector3(_rng.randf_range(-hx, hx), 0.0, _rng.randf_range(-hz, hz))


func _tick_ufos(delta: float) -> void:
	var i := 0
	while i < _ufos.size():
		var u: Dictionary = _ufos[i]
		var root: Node3D = u.get("root")
		var beam: MeshInstance3D = u.get("beam")
		var ring: Node3D = u.get("ring")
		if root == null or not is_instance_valid(root):
			if ring != null and is_instance_valid(ring):
				ring.queue_free()
			_ufos.remove_at(i)
			continue
		var phase: int = int(u.get("phase", 0))
		var timer: float = float(u.get("timer", 0.0))
		var target: Vector3 = u.get("target", Vector3.ZERO)
		match phase:
			0:
				# İniş
				var dest := target + Vector3(0.0, hover_height, 0.0)
				root.global_position = root.global_position.lerp(dest, 1.0 - exp(-3.2 * delta))
				root.rotate_y(delta * 1.8)
				if ring != null and is_instance_valid(ring):
					ring.rotate_y(delta * 2.5)
					var pulse := 0.9 + 0.15 * sin(Time.get_ticks_msec() * 0.012)
					ring.scale = Vector3(pulse, 1.0, pulse)
				if root.global_position.distance_to(dest) < 0.35:
					u["phase"] = 1
					u["timer"] = _rng.randf_range(5.5, 8.0)
					if beam != null:
						beam.visible = true
					if ring != null and is_instance_valid(ring):
						ring.queue_free()
						u["ring"] = null
			1:
				# Hover + takip + ışın
				root.rotate_y(delta * 2.4)
				var chase := _player.global_position
				chase.y = 0.0
				var desired := chase + Vector3(0.0, hover_height, 0.0)
				# Sınır içinde kal
				desired.x = clampf(desired.x, -room_half_extents.x * 0.85, room_half_extents.x * 0.85)
				desired.z = clampf(desired.z, -room_half_extents.y * 0.85, room_half_extents.y * 0.85)
				root.global_position = root.global_position.move_toward(desired, move_speed * delta)
				if beam != null:
					var pulse_a := 0.16 + 0.08 * sin(Time.get_ticks_msec() * 0.01)
					var mat := beam.material_override as StandardMaterial3D
					if mat != null:
						mat.albedo_color.a = pulse_a
				_update_pull(u, delta)
				timer -= delta
				u["timer"] = timer
				if timer <= 0.0:
					u["phase"] = 2
					u["timer"] = 1.6
					if beam != null:
						beam.visible = false
			2:
				# Kalkış
				root.global_position += Vector3(0.0, 6.0 * delta, 0.0)
				root.rotate_y(delta * 3.0)
				timer -= delta
				u["timer"] = timer
				if timer <= 0.0 or root.global_position.y > hover_height + 10.0:
					root.queue_free()
					if ring != null and is_instance_valid(ring):
						ring.queue_free()
					_ufos.remove_at(i)
					continue
		_ufos[i] = u
		i += 1


func _update_pull(u: Dictionary, delta: float) -> void:
	if _abducting or _player == null:
		return
	var root: Node3D = u.get("root")
	if root == null:
		return
	var flat := _player.global_position - root.global_position
	flat.y = 0.0
	var in_beam := flat.length() <= beam_radius * 1.05
	var pull: float = float(u.get("pull", 0.0))
	if in_beam:
		pull += delta
		# Hafif yukarı çekiş hissi
		if _player.has_method("apply_hazard_shove") == false:
			pass
		if _player is CharacterBody3D:
			var body := _player as CharacterBody3D
			body.velocity.y = maxf(body.velocity.y, 1.8)
		if pull >= beam_pull_time:
			u["pull"] = pull
			_begin_abduction(root)
			return
	else:
		pull = maxf(0.0, pull - delta / maxf(escape_grace, 0.05))
	u["pull"] = pull


func _begin_abduction(ufo_root: Node3D) -> void:
	if _abducting:
		return
	_abducting = true
	_active = false
	if _player != null and _player.has_method("set_control_locked"):
		_player.call("set_control_locked", true)
	_lift_from = _player.global_position
	_lift_to = ufo_root.global_position + Vector3(0.0, -0.4, 0.0)
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_method(_lift_player, 0.0, 1.0, 0.85)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		player_abducted.emit()
	)


func _lift_player(t: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var p := _lift_from.lerp(_lift_to, t)
	_player.global_position = p
	_player.rotation.y += 0.35
	var s := lerpf(1.0, 0.15, t)
	_player.scale = Vector3(s, s, s)
