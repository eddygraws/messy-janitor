class_name HazardDirector
extends Node

## Oda tehlikeleri — kaygan zemin, düşen eşya, mobilya kayması.
## MicroTaskDirector ile aynı dil: timer + görsel uyarı + stress cezası.

signal slippery_spawned(world_pos: Vector3)
signal fall_impact(hit_player: bool, world_pos: Vector3)
signal furniture_shifted

@export var room_half_extents: Vector2 = Vector2(5.8, 3.8)
@export var slippery_duration: float = 5.8
@export var slippery_radius: float = 1.35
@export var slippery_strength: float = 1.0
@export var fall_base_interval: float = 11.0
@export var fall_warn_time: float = 1.35
@export var fall_radius: float = 1.55
@export var fall_stress: float = 16.0
## Mobilya — yumuşak tempo, her uyarı görünür
@export var furniture_count: int = 2
@export var furniture_interval: float = 10.0 ## Uyarılar arası bekleme
@export var furniture_warn_time: float = 2.0 ## Kırmızı çizgi süresi
@export var furniture_warn_min: float = 0.85 ## En az bu kadar uyarı göster (erken tetik yok)
@export var furniture_slide_time: float = 0.48 ## Kayma süresi
@export var furniture_shove_power: float = 7.5
@export var furniture_touch_pad: float = 0.55 ## Çizgiye basma yarıçapı
@export var furniture_line_width: float = 0.32
@export var furniture_travel: float = 3.2 ## Max kayma mesafesi
@export var furniture_min_sep: float = 3.2

var _player: PlayerCharacter3D
var _stress: StressComponent
var _spawner: Node3D
var _world: Node3D
var _tempo: TempoPhaseDirector
var _active: bool = false
var _allow_mop: bool = true
var _level_index: int = 0
var _curse_fall_mult: float = 1.0
var _curse_slip_mult: float = 1.0
var _base_fall_interval: float = -1.0
var _base_slip_duration: float = -1.0

var _slip_zones: Array[Dictionary] = [] # {node, center, radius, time}
var _fall_cd: float = 0.0
var _fall_warn: Node3D
var _fall_center: Vector3 = Vector3.ZERO
var _fall_timer: float = -1.0

## Mobilya state machine: IDLE → WARN → SLIDE → IDLE
enum FurnPhase { IDLE, WARN, SLIDE }
var _furn_phase: FurnPhase = FurnPhase.IDLE
var _furniture: Array[Node3D] = []
var _furn_cd: float = 0.0
var _furn_piece: Node3D
var _furn_warn: Node3D
var _furn_from: Vector3 = Vector3.ZERO
var _furn_to: Vector3 = Vector3.ZERO
var _furn_target: Vector3 = Vector3.ZERO
var _furn_timer: float = 0.0 ## WARN: kalan süre | SLIDE: geçen süre
var _furn_start: Vector3 = Vector3.ZERO
var _furn_start_rot: float = 0.0
var _furn_end_rot: float = 0.0
var _furn_last: Vector3 = Vector3.ZERO
var _furn_shove_cd: float = 0.0
var _furn_pulse: float = 0.0
var _rng := RandomNumberGenerator.new()


func setup(
	player: PlayerCharacter3D,
	stress: StressComponent,
	spawner: Node3D,
	world: Node3D,
	tempo: TempoPhaseDirector
) -> void:
	_player = player
	_stress = stress
	_spawner = spawner
	_world = world
	_tempo = tempo
	_rng.randomize()


func start_session(level_index: int, allow_mop: bool = true) -> void:
	stop_session()
	_level_index = level_index
	_allow_mop = allow_mop
	_active = true
	# İlk düşme / mobilya biraz geciksin
	_fall_cd = fall_base_interval * randf_range(0.55, 0.9)
	_furn_cd = furniture_interval * randf_range(0.55, 0.85)
	_furn_phase = FurnPhase.IDLE
	_spawn_furniture()


func stop_session() -> void:
	_active = false
	if _player != null:
		_player.set_floor_slip(0.0)
	_clear_slip_zones()
	_clear_fall_warn()
	_furn_reset(true)
	_clear_furniture()
	_fall_timer = -1.0
	_fall_cd = 0.0
	_furn_cd = 0.0
	_furn_phase = FurnPhase.IDLE


func notify_scrub_cleaned(world_pos: Vector3) -> void:
	if not _active or not _allow_mop:
		return
	_spawn_slippery(world_pos)


func apply_curse_mods(fall_rate_mult: float, slip_duration_mult: float) -> void:
	if _base_fall_interval < 0.0:
		_base_fall_interval = fall_base_interval
		_base_slip_duration = slippery_duration
	_curse_fall_mult = fall_rate_mult
	_curse_slip_mult = slip_duration_mult
	fall_base_interval = maxf(5.0, _base_fall_interval / maxf(0.5, fall_rate_mult))
	slippery_duration = _base_slip_duration * slip_duration_mult


func clear_curse_mods() -> void:
	if _base_fall_interval >= 0.0:
		fall_base_interval = _base_fall_interval
		slippery_duration = _base_slip_duration
	_base_fall_interval = -1.0
	_base_slip_duration = -1.0
	_curse_fall_mult = 1.0
	_curse_slip_mult = 1.0


func _process(delta: float) -> void:
	if not _active:
		return
	_tick_slippery(delta)
	_tick_falling(delta)
	_tick_furniture(delta)
	_apply_slip_to_player()


func _physics_process(_delta: float) -> void:
	pass

func _apply_slip_to_player() -> void:
	if _player == null:
		return
	var best := 0.0
	var p := _player.global_position
	for z in _slip_zones:
		var c: Vector3 = z["center"]
		var r: float = z["radius"]
		var flat := Vector3(p.x - c.x, 0.0, p.z - c.z)
		if flat.length() <= r:
			best = maxf(best, slippery_strength)
	# Temizlenmemiş paspas sıvıları — hitbox yok ama üzerinde kay
	if _allow_mop:
		for n in get_tree().get_nodes_in_group("ClutterProp"):
			var prop := n as ClutterProp
			if prop == null or not prop.is_scrub_target():
				continue
			var flat_p := Vector3(p.x - prop.global_position.x, 0.0, p.z - prop.global_position.z)
			if flat_p.length() <= prop.scrub_radius + 0.2:
				best = maxf(best, slippery_strength)
	_player.set_floor_slip(best)


func _tick_slippery(delta: float) -> void:
	var i := 0
	while i < _slip_zones.size():
		var z: Dictionary = _slip_zones[i]
		z["time"] = float(z["time"]) - delta
		var node: Node3D = z["node"] as Node3D
		if float(z["time"]) <= 0.0 or node == null or not is_instance_valid(node):
			if node != null and is_instance_valid(node):
				node.queue_free()
			_slip_zones.remove_at(i)
			continue
		# Son saniyede soluklaş
		var t: float = float(z["time"])
		if t < 1.2 and node.get_child_count() > 0:
			var mesh := node.get_child(0) as MeshInstance3D
			if mesh != null and mesh.material_override is StandardMaterial3D:
				var mat := mesh.material_override as StandardMaterial3D
				mat.albedo_color.a = lerpf(0.05, 0.4, t / 1.2)
		_slip_zones[i] = z
		i += 1


func _spawn_slippery(at: Vector3) -> void:
	var center := at
	center.y = 0.0
	var zone := Node3D.new()
	zone.name = "SlipperyZone"
	zone.position = center
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = slippery_radius
	cyl.bottom_radius = slippery_radius
	cyl.height = 0.06
	mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.75, 1.0, 0.42)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.7, 1.0)
	mat.emission_energy_multiplier = 1.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mesh.material_override = mat
	mesh.position = Vector3(0.0, 0.04, 0.0)
	zone.add_child(mesh)
	var label := Label3D.new()
	label.text = "KAYGAN"
	label.font_size = 42
	label.modulate = Color(0.55, 0.9, 1.0)
	label.outline_size = 6
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.position = Vector3(0.0, 0.55, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	zone.add_child(label)
	var parent: Node = _world if _world != null else get_tree().current_scene
	parent.add_child(zone)
	_slip_zones.append({
		"node": zone,
		"center": center,
		"radius": slippery_radius,
		"time": slippery_duration,
	})
	var pulse := zone.create_tween().set_loops()
	pulse.tween_property(mat, "albedo_color:a", 0.22, 0.4)
	pulse.tween_property(mat, "albedo_color:a", 0.48, 0.4)
	slippery_spawned.emit(center)


func _clear_slip_zones() -> void:
	for z in _slip_zones:
		var node: Node3D = z.get("node") as Node3D
		if node != null and is_instance_valid(node):
			node.queue_free()
	_slip_zones.clear()


func _tick_falling(delta: float) -> void:
	# Uyarı devam ediyorsa
	if _fall_timer >= 0.0:
		_fall_timer -= delta
		if _fall_warn != null and is_instance_valid(_fall_warn):
			_fall_warn.rotation.y += delta * 4.0
			var shake := sin(Time.get_ticks_msec() * 0.04) * 0.04
			_fall_warn.position.x = _fall_center.x + shake
			_fall_warn.position.z = _fall_center.z - shake * 0.5
		if _fall_timer <= 0.0:
			_resolve_fall()
		return

	_fall_cd -= delta
	if _fall_cd > 0.0:
		return
	var mult := 1.0
	if _tempo != null and _tempo.is_running():
		mult = _tempo.get_spawn_rate_mult()
	# Seviye ilerledikçe biraz daha sık
	var level_scale := lerpf(1.0, 0.72, clampf(float(_level_index) / 9.0, 0.0, 1.0))
	_fall_cd = (fall_base_interval * level_scale / maxf(0.75, mult)) * randf_range(0.85, 1.2)
	_begin_fall_warn()


func _begin_fall_warn() -> void:
	_clear_fall_warn()
	_fall_center = _random_floor_point(true)
	_fall_timer = fall_warn_time
	var zone := Node3D.new()
	zone.name = "FallDangerZone"
	zone.position = _fall_center
	# Gölge diski
	var shadow := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = fall_radius
	cyl.bottom_radius = fall_radius
	cyl.height = 0.05
	shadow.mesh = cyl
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.05, 0.02, 0.02, 0.55)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.no_depth_test = true
	shadow.material_override = smat
	shadow.position = Vector3(0.0, 0.03, 0.0)
	zone.add_child(shadow)
	# Halka
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = fall_radius - 0.1
	torus.outer_radius = fall_radius + 0.05
	ring.mesh = torus
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(1.0, 0.55, 0.15, 0.9)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.emission_enabled = true
	rmat.emission = Color(1.0, 0.45, 0.1)
	rmat.emission_energy_multiplier = 2.5
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rmat
	ring.position = Vector3(0.0, 0.1, 0.0)
	zone.add_child(ring)
	var label := Label3D.new()
	label.text = "DÜŞÜYOR!"
	label.font_size = 56
	label.modulate = Color(1.0, 0.7, 0.3)
	label.outline_size = 8
	label.position = Vector3(0.0, 1.4, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	zone.add_child(label)
	# Yukarıdaki titreyen kutu (uyarı)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.55, 0.7)
	box.mesh = bm
	box.material_override = HitWobbleMaterial.create(
		Color(0.55, 0.42, 0.28), 0.8, Color(1.0, 0.6, 0.2), 0.2, 0.08, true, 0.03
	)
	box.position = Vector3(0.0, 3.2, 0.0)
	zone.add_child(box)
	var tw := zone.create_tween().set_loops()
	tw.tween_property(box, "position:y", 3.05, 0.12)
	tw.tween_property(box, "position:y", 3.35, 0.12)
	var parent: Node = _world if _world != null else get_tree().current_scene
	parent.add_child(zone)
	_fall_warn = zone


func _resolve_fall() -> void:
	var hit := false
	if _player != null:
		var flat := _player.global_position - _fall_center
		flat.y = 0.0
		hit = flat.length() <= fall_radius + 0.2
	if hit and _stress != null:
		_stress.add_stress(fall_stress)
	# Düşen kutu görseli — kısa squash sonra yok (veya spawner'a bırak)
	if _fall_warn != null and is_instance_valid(_fall_warn):
		var impact := _fall_warn
		_fall_warn = null
		for c in impact.get_children():
			if c is Label3D or (c is MeshInstance3D and c.position.y < 0.5):
				c.queue_free()
		var falling: MeshInstance3D = null
		for c in impact.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).position.y > 1.0:
				falling = c as MeshInstance3D
				break
		if falling != null:
			var land := impact.create_tween()
			land.tween_property(falling, "position:y", 0.35, 0.18)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			land.tween_callback(func() -> void:
				if is_instance_valid(impact):
					impact.queue_free()
			)
		else:
			impact.queue_free()
	else:
		_clear_fall_warn()
	fall_impact.emit(hit, _fall_center)
	_fall_timer = -1.0


func _clear_fall_warn() -> void:
	if _fall_warn != null and is_instance_valid(_fall_warn):
		_fall_warn.queue_free()
	_fall_warn = null


func _tick_furniture(delta: float) -> void:
	if _furniture.is_empty():
		return
	match _furn_phase:
		FurnPhase.IDLE:
			_furn_cd -= delta
			if _furn_cd <= 0.0:
				_furn_begin_warn()
		FurnPhase.WARN:
			_furn_tick_warn(delta)
		FurnPhase.SLIDE:
			_furn_tick_slide(delta)


func _furn_begin_warn() -> void:
	_furn_reset(false)
	if _player == null or _furniture.is_empty():
		_furn_cd = furniture_interval
		return
	# Geçerli parça seç
	var candidates: Array[Node3D] = []
	for f in _furniture:
		if f != null and is_instance_valid(f):
			candidates.append(f)
	if candidates.is_empty():
		_furn_cd = furniture_interval
		return
	_furn_piece = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var origin := _furn_piece.global_position
	var path := _furn_compute_path(origin)
	_furn_from = path["from"]
	_furn_to = path["to"]
	_furn_target = path["target"]
	# Yol çok kısaysa atla — sonraki turda tekrar dene
	if _furn_from.distance_to(_furn_to) < 1.0:
		_furn_cd = 1.2
		_furn_piece = null
		return
	_furn_warn = _furn_spawn_line(_furn_from, _furn_to)
	if _furn_warn == null:
		_furn_cd = 1.5
		_furn_piece = null
		return
	_furn_timer = furniture_warn_time
	_furn_pulse = 0.0
	_furn_phase = FurnPhase.WARN
	# Hafif uyarı sarsıntısı
	_furn_piece.rotation.y += _rng.randf_range(-0.04, 0.04)


func _furn_compute_path(origin: Vector3) -> Dictionary:
	var y := origin.y
	var from := Vector3(origin.x, 0.0, origin.z)
	var toward := Vector3.ZERO
	if _player != null:
		toward = _player.global_position - origin
		toward.y = 0.0
	if toward.length_squared() < 0.2:
		toward = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
	toward = toward.normalized()
	# Oyuncunun biraz ötesine — agresif chase yok
	var travel := furniture_travel * _rng.randf_range(0.75, 1.0)
	var target := origin + toward * travel
	if _player != null:
		var past := _player.global_position + toward * _rng.randf_range(0.8, 1.4)
		past.y = y
		# origin → past yönünde ama travel ile sınırlı
		var to_past := past - origin
		to_past.y = 0.0
		if to_past.length() > 0.1:
			target = origin + to_past.normalized() * minf(to_past.length(), travel)
	target = _furn_clamp_target(target, _furn_piece, y)
	var to := Vector3(target.x, 0.0, target.z)
	return {"from": from, "to": to, "target": target}


func _furn_clamp_target(desired: Vector3, self_piece: Node3D, y: float) -> Vector3:
	var target := desired
	target.x = clampf(target.x, -room_half_extents.x * 0.86, room_half_extents.x * 0.86)
	target.z = clampf(target.z, -room_half_extents.y * 0.86, room_half_extents.y * 0.86)
	target.y = y
	for _i in 6:
		var ok := true
		for f in _furniture:
			if f == null or not is_instance_valid(f) or f == self_piece:
				continue
			var d := Vector3(target.x - f.global_position.x, 0.0, target.z - f.global_position.z)
			if d.length() < furniture_min_sep:
				ok = false
				if d.length_squared() < 0.001:
					d = Vector3(1.0, 0.0, 0.0)
				target += d.normalized() * furniture_min_sep * 0.85
				target.x = clampf(target.x, -room_half_extents.x * 0.86, room_half_extents.x * 0.86)
				target.z = clampf(target.z, -room_half_extents.y * 0.86, room_half_extents.y * 0.86)
				break
		if ok:
			break
	target.y = y
	return target


func _furn_tick_warn(delta: float) -> void:
	if _furn_piece == null or not is_instance_valid(_furn_piece):
		_furn_reset(true)
		_furn_cd = furniture_interval * 0.5
		_furn_phase = FurnPhase.IDLE
		return
	if _furn_warn == null or not is_instance_valid(_furn_warn):
		# Belirteç kaybolduysa yeniden oluştur — asla sessiz kayma
		_furn_warn = _furn_spawn_line(_furn_from, _furn_to)
		if _furn_warn == null:
			_furn_reset(true)
			_furn_cd = 2.0
			_furn_phase = FurnPhase.IDLE
			return
	_furn_timer -= delta
	_furn_pulse += delta
	_furn_pulse_line()
	var elapsed := furniture_warn_time - _furn_timer
	var can_early := elapsed >= furniture_warn_min
	var crossed := can_early and _furn_player_on_line()
	if _furn_timer <= 0.0 or crossed:
		_furn_start_slide()


func _furn_pulse_line() -> void:
	if _furn_warn == null or not is_instance_valid(_furn_warn):
		return
	var line := _furn_warn.get_node_or_null("Line") as MeshInstance3D
	if line == null:
		return
	var urgency := 1.0 - clampf(_furn_timer / maxf(furniture_warn_time, 0.1), 0.0, 1.0)
	var s := 1.0 + 0.1 * sin(_furn_pulse * (6.0 + urgency * 8.0))
	line.scale = Vector3(s, 1.0, 1.0)


func _furn_player_on_line() -> bool:
	if _player == null:
		return false
	var p := _player.global_position
	p.y = 0.0
	var closest := _closest_point_on_segment(p, _furn_from, _furn_to)
	return p.distance_to(closest) <= furniture_touch_pad


func _furn_start_slide() -> void:
	if _furn_piece == null or not is_instance_valid(_furn_piece):
		_furn_reset(true)
		_furn_phase = FurnPhase.IDLE
		_furn_cd = furniture_interval
		return
	# Belirteçi kaldır, kaymaya başla
	if _furn_warn != null and is_instance_valid(_furn_warn):
		_furn_warn.queue_free()
	_furn_warn = null
	_furn_target = _furn_clamp_target(_furn_target, _furn_piece, _furn_piece.global_position.y)
	var flat := Vector3(_furn_target.x - _furn_piece.global_position.x, 0.0, _furn_target.z - _furn_piece.global_position.z)
	if flat.length() < 0.5:
		if flat.length_squared() > 0.01:
			_furn_target = _furn_piece.global_position + flat.normalized() * 2.0
		else:
			_furn_target = _furn_piece.global_position + Vector3(2.0, 0.0, 0.0)
		_furn_target = _furn_clamp_target(_furn_target, _furn_piece, _furn_piece.global_position.y)
	_furn_start = _furn_piece.global_position
	_furn_start_rot = _furn_piece.rotation.y
	_furn_end_rot = _furn_start_rot + _rng.randf_range(-0.35, 0.35)
	_furn_last = _furn_start
	_furn_timer = 0.0
	_furn_shove_cd = 0.0
	_furn_phase = FurnPhase.SLIDE


func _furn_tick_slide(delta: float) -> void:
	if _furn_piece == null or not is_instance_valid(_furn_piece):
		_furn_reset(true)
		_furn_phase = FurnPhase.IDLE
		_furn_cd = furniture_interval
		return
	_furn_timer += delta
	var t := clampf(_furn_timer / maxf(furniture_slide_time, 0.05), 0.0, 1.0)
	# Smoothstep — ani teleport hissi yok
	var s := t * t * (3.0 - 2.0 * t)
	_furn_piece.global_position = _furn_start.lerp(_furn_target, s)
	_furn_piece.rotation.y = lerpf(_furn_start_rot, _furn_end_rot, s)
	_furn_try_shove(delta)
	if t >= 1.0:
		_furn_piece.global_position = _furn_target
		_furn_reset(false)
		_furn_cd = furniture_interval * _rng.randf_range(0.85, 1.15)
		_furn_phase = FurnPhase.IDLE
		furniture_shifted.emit()


func _furn_try_shove(delta: float) -> void:
	if _player == null or _furn_piece == null:
		return
	_furn_shove_cd = maxf(0.0, _furn_shove_cd - delta)
	var cur := _furn_piece.global_position
	var move_dir := cur - _furn_last
	move_dir.y = 0.0
	_furn_last = cur
	var half: Vector3 = _furn_piece.get_meta("half_size", Vector3(0.55, 0.55, 0.35))
	var reach := maxf(half.x, half.z) + 0.65
	var to_player := _player.global_position - cur
	to_player.y = 0.0
	if to_player.length() > reach or _furn_shove_cd > 0.0:
		return
	var shove: Vector3
	if move_dir.length_squared() > 0.00008:
		shove = move_dir.normalized()
		if to_player.length_squared() > 0.01:
			shove = (shove * 0.75 + to_player.normalized() * 0.35).normalized()
	elif to_player.length_squared() > 0.01:
		shove = to_player.normalized()
	else:
		return
	_player.apply_hazard_shove(shove, furniture_shove_power)
	_furn_shove_cd = 0.12


func _furn_spawn_line(from_pos: Vector3, to_pos: Vector3) -> Node3D:
	var from := Vector3(from_pos.x, 0.0, from_pos.z)
	var to := Vector3(to_pos.x, 0.0, to_pos.z)
	var dist := from.distance_to(to)
	if dist < 0.4:
		return null
	var mid := from.lerp(to, 0.5)
	var dir := (to - from) / dist
	var parent: Node = _world if _world != null else get_tree().current_scene
	if parent == null:
		return null

	var zone := Node3D.new()
	zone.name = "FurnitureWarnLine"
	parent.add_child(zone)
	zone.global_position = Vector3(mid.x, 0.0, mid.z)
	# Yaw — look_at yerine güvenilir atan2
	zone.rotation = Vector3(0.0, atan2(dir.x, dir.z), 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.12, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.12)
	mat.emission_energy_multiplier = 4.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true

	var line := MeshInstance3D.new()
	line.name = "Line"
	var lm := BoxMesh.new()
	lm.size = Vector3(furniture_line_width * 0.5, 0.05, dist)
	line.mesh = lm
	line.material_override = mat
	line.position = Vector3(0.0, 0.08, 0.0)
	zone.add_child(line)

	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	var gm := BoxMesh.new()
	gm.size = Vector3(furniture_line_width, 0.025, dist)
	glow.mesh = gm
	var gmat := mat.duplicate() as StandardMaterial3D
	gmat.albedo_color = Color(1.0, 0.25, 0.15, 0.28)
	gmat.emission_energy_multiplier = 2.0
	glow.material_override = gmat
	glow.position = Vector3(0.0, 0.05, 0.0)
	zone.add_child(glow)

	# Uç kapakları
	for end_z in [-dist * 0.5, dist * 0.5]:
		var cap := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(furniture_line_width * 1.15, 0.06, 0.08)
		cap.mesh = cm
		cap.material_override = mat
		cap.position = Vector3(0.0, 0.09, end_z)
		zone.add_child(cap)

	return zone


func _furn_reset(free_warn: bool) -> void:
	if free_warn and _furn_warn != null and is_instance_valid(_furn_warn):
		_furn_warn.queue_free()
	_furn_warn = null
	_furn_piece = null
	_furn_timer = 0.0
	_furn_pulse = 0.0
	_furn_shove_cd = 0.0


func _spawn_furniture() -> void:
	_clear_furniture()
	var n := clampi(furniture_count, 1, 3)
	if _level_index <= 1:
		n = mini(n, 2)
	var slots := _furniture_spawn_slots()
	slots.shuffle()
	var used: Array[Vector3] = []
	var parent: Node = _world if _world != null else get_tree().current_scene
	var spawned := 0
	for slot in slots:
		if spawned >= n:
			break
		var pos: Vector3 = slot
		if not _is_far_from_all(pos, used, furniture_min_sep):
			continue
		var piece := _make_furniture_piece(spawned)
		parent.add_child(piece)
		piece.global_position = pos
		used.append(pos)
		_furniture.append(piece)
		spawned += 1
	var guard := 0
	while spawned < n and guard < 20:
		guard += 1
		var pos2 := _random_edge_point()
		if not _is_far_from_all(pos2, used, furniture_min_sep):
			continue
		var piece2 := _make_furniture_piece(spawned)
		parent.add_child(piece2)
		piece2.global_position = pos2
		used.append(pos2)
		_furniture.append(piece2)
		spawned += 1


func _furniture_spawn_slots() -> Array[Vector3]:
	var hx := room_half_extents.x
	var hz := room_half_extents.y
	var y := 0.55
	return [
		Vector3(-hx * 0.82, y, -hz * 0.78),
		Vector3(hx * 0.82, y, -hz * 0.78),
		Vector3(-hx * 0.82, y, hz * 0.78),
		Vector3(hx * 0.82, y, hz * 0.78),
		Vector3(0.0, y, -hz * 0.88),
		Vector3(0.0, y, hz * 0.88),
		Vector3(-hx * 0.92, y, 0.0),
		Vector3(hx * 0.92, y, 0.0),
	]


func _random_edge_point() -> Vector3:
	var side := _rng.randi_range(0, 3)
	var hx := room_half_extents.x * 0.85
	var hz := room_half_extents.y * 0.85
	match side:
		0:
			return Vector3(_rng.randf_range(-hx, hx), 0.55, -hz)
		1:
			return Vector3(_rng.randf_range(-hx, hx), 0.55, hz)
		2:
			return Vector3(-hx, 0.55, _rng.randf_range(-hz, hz))
		_:
			return Vector3(hx, 0.55, _rng.randf_range(-hz, hz))


func _is_far_from_all(pos: Vector3, others: Array[Vector3], min_sep: float) -> bool:
	var min_sq := min_sep * min_sep
	for o in others:
		var d := Vector3(pos.x - o.x, 0.0, pos.z - o.z)
		if d.length_squared() < min_sq:
			return false
	return true


func _make_furniture_piece(index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "HazardFurniture_%d" % index
	root.add_to_group(&"HazardFurniture")
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.05, 1.05, 0.5) if index % 2 == 0 else Vector3(0.65, 1.3, 0.65)
	mesh.mesh = box
	var col_a := Color(0.42, 0.28, 0.18) if index % 2 == 0 else Color(0.32, 0.34, 0.38)
	mesh.material_override = HitWobbleMaterial.create(col_a, 0.85, Color.BLACK, 0.0, 0.05, true, 0.028)
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	body.add_child(col)
	var tag := Label3D.new()
	tag.text = "RAF" if index % 2 == 0 else "DOLAP"
	tag.font_size = 28
	tag.modulate = Color(0.9, 0.85, 0.7, 0.7)
	tag.position = Vector3(0.0, box.size.y * 0.55 + 0.15, 0.0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(tag)
	root.set_meta("half_size", box.size * 0.5)
	return root


func _closest_point_on_segment(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return a
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return a + ab * t


func _clear_furniture() -> void:
	_furn_reset(true)
	for f in _furniture:
		if f != null and is_instance_valid(f):
			f.queue_free()
	_furniture.clear()
	_furn_phase = FurnPhase.IDLE


func _random_floor_point(prefer_near_player: bool) -> Vector3:
	var x := _rng.randf_range(-room_half_extents.x, room_half_extents.x)
	var z := _rng.randf_range(-room_half_extents.y, room_half_extents.y)
	if prefer_near_player and _player != null:
		if _rng.randf() < 0.55:
			x = _player.global_position.x + _rng.randf_range(-2.4, 2.4)
			z = _player.global_position.z + _rng.randf_range(-2.0, 2.0)
			x = clampf(x, -room_half_extents.x, room_half_extents.x)
			z = clampf(z, -room_half_extents.y, room_half_extents.y)
	return Vector3(x, 0.0, z)
