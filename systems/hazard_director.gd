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
@export var furniture_interval: float = 5.5
@export var furniture_count: int = 3
@export var furniture_warn_timeout: float = 2.4
@export var furniture_shove_power: float = 16.0
@export var furniture_line_width: float = 0.38 ## Görsel çizgi kalınlığı
@export var furniture_touch_pad: float = 0.9 ## Çizgiye yaklaşınca tetik payı (oyuncu yarıçapı+)
@export var furniture_slide_time: float = 0.16 ## Kayma süresi (çok hızlı)
@export var furniture_min_sep: float = 2.9 ## Spawn / hedef min mesafe

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
var _furniture: Array[Node3D] = []
var _furniture_cd: float = 0.0
## {piece, target, warn, time_left, moving, last_pos}
var _furniture_job: Dictionary = {}
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
	# İlk düşme biraz geciksin
	_fall_cd = fall_base_interval * randf_range(0.55, 0.9)
	_furniture_cd = furniture_interval * randf_range(0.4, 0.7)
	_spawn_furniture()


func stop_session() -> void:
	_active = false
	if _player != null:
		_player.set_floor_slip(0.0)
	_clear_slip_zones()
	_clear_fall_warn()
	_clear_furniture_job()
	_clear_furniture()
	_fall_timer = -1.0
	_fall_cd = 0.0
	_furniture_cd = 0.0


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
	_tick_furniture_schedule(delta)
	_apply_slip_to_player()


func _physics_process(_delta: float) -> void:
	if not _active:
		return
	# Fizik karesinde tetik — daha responsive
	_tick_furniture_reactive()


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


func _tick_furniture_schedule(delta: float) -> void:
	if _furniture.is_empty():
		return
	if not _furniture_job.is_empty():
		if bool(_furniture_job.get("moving", false)):
			return
		_furniture_job["time_left"] = float(_furniture_job.get("time_left", 0.0)) - delta
		_pulse_furniture_line(delta)
		if float(_furniture_job.get("time_left", 0.0)) <= 0.0:
			_execute_furniture_slide()
		return
	_furniture_cd -= delta
	if _furniture_cd > 0.0:
		return
	_furniture_cd = furniture_interval * randf_range(0.65, 0.95)
	_arm_furniture_slide()


func _tick_furniture_reactive() -> void:
	if _furniture.is_empty() or _furniture_job.is_empty():
		return
	var delta := get_physics_process_delta_time()
	if bool(_furniture_job.get("moving", false)):
		_update_furniture_slide_motion(delta)
		_update_furniture_shove()
		return
	if _player_touches_furniture_line():
		_execute_furniture_slide()


func _spawn_furniture() -> void:
	_clear_furniture()
	var n := clampi(furniture_count, 1, 4)
	if _level_index <= 0:
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
	while spawned < n and guard < 24:
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
		Vector3(-hx * 0.55, y, -hz * 0.88),
		Vector3(hx * 0.55, y, hz * 0.88),
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
	# Node3D kök — AnimatableBody tween ile kaymıyordu; kökü lerp'liyoruz.
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
	box.size = Vector3(1.1, 1.1, 0.55) if index % 2 == 0 else Vector3(0.7, 1.4, 0.7)
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


func _arm_furniture_slide() -> void:
	if _furniture.is_empty() or _player == null:
		return
	var piece: Node3D = _furniture[_rng.randi_range(0, _furniture.size() - 1)]
	if piece == null or not is_instance_valid(piece):
		return
	var origin := piece.global_position
	var player_pos := _player.global_position
	var toward := player_pos - origin
	toward.y = 0.0
	if toward.length_squared() < 0.25:
		toward = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
	toward = toward.normalized()
	var past := player_pos + toward * _rng.randf_range(1.8, 3.2)
	past = _resolve_furniture_target(past, piece, origin.y)
	var from_flat := Vector3(origin.x, 0.0, origin.z)
	var to_flat := Vector3(past.x, 0.0, past.z)
	var warn := _spawn_furniture_line(from_flat, to_flat)
	_furniture_job = {
		"piece": piece,
		"target": past,
		"from": from_flat,
		"to": to_flat,
		"warn": warn,
		"time_left": furniture_warn_timeout,
		"moving": false,
		"last_pos": origin,
		"shove_cd": 0.0,
		"pulse_t": 0.0,
	}
	# Oyuncu çizgideyse anında kay
	if _player_touches_furniture_line():
		_execute_furniture_slide()
		return
	var shake := piece.create_tween()
	piece.set_meta("warn_tween", shake)
	var base_y := piece.rotation.y
	shake.tween_property(piece, "rotation:y", base_y + 0.12, 0.03)
	shake.tween_property(piece, "rotation:y", base_y - 0.12, 0.03)
	shake.tween_property(piece, "rotation:y", base_y, 0.03)


func _resolve_furniture_target(desired: Vector3, self_piece: Node3D, y: float) -> Vector3:
	var target := desired
	target.x = clampf(target.x, -room_half_extents.x * 0.88, room_half_extents.x * 0.88)
	target.z = clampf(target.z, -room_half_extents.y * 0.88, room_half_extents.y * 0.88)
	target.y = y
	for _attempt in 8:
		var ok := true
		for f in _furniture:
			if f == null or not is_instance_valid(f) or f == self_piece:
				continue
			var d := Vector3(target.x - f.global_position.x, 0.0, target.z - f.global_position.z)
			if d.length() < furniture_min_sep:
				ok = false
				if d.length_squared() < 0.001:
					d = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
				target += d.normalized() * furniture_min_sep
				target.x = clampf(target.x, -room_half_extents.x * 0.88, room_half_extents.x * 0.88)
				target.z = clampf(target.z, -room_half_extents.y * 0.88, room_half_extents.y * 0.88)
				break
		if ok:
			break
	target.y = y
	return target


## İnce kırmızı çizgi — mesafe tetik (physics)
func _spawn_furniture_line(from_pos: Vector3, to_pos: Vector3) -> Node3D:
	var from := Vector3(from_pos.x, 0.0, from_pos.z)
	var to := Vector3(to_pos.x, 0.0, to_pos.z)
	var mid := from.lerp(to, 0.5)
	var dist := maxf(0.8, from.distance_to(to))
	var zone := Node3D.new()
	zone.name = "FurnitureLineTrigger"
	zone.position = mid
	var line := MeshInstance3D.new()
	line.name = "Line"
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(furniture_line_width * 0.45, 0.04, dist)
	line.mesh = line_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.12, 0.1, 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.18, 0.1)
	mat.emission_energy_multiplier = 5.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	line.material_override = mat
	line.position = Vector3(0.0, 0.07, 0.0)
	zone.add_child(line)
	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	var glow_mesh := BoxMesh.new()
	glow_mesh.size = Vector3(furniture_line_width, 0.02, dist)
	glow.mesh = glow_mesh
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(1.0, 0.2, 0.12, 0.32)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.emission_enabled = true
	gmat.emission = Color(1.0, 0.25, 0.1)
	gmat.emission_energy_multiplier = 2.4
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.no_depth_test = true
	glow.material_override = gmat
	glow.position = Vector3(0.0, 0.045, 0.0)
	zone.add_child(glow)
	for end_z in [-dist * 0.5, dist * 0.5]:
		var tick := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(furniture_line_width * 1.2, 0.055, 0.07)
		tick.mesh = tm
		tick.material_override = mat
		tick.position = Vector3(0.0, 0.08, end_z)
		zone.add_child(tick)
	var parent: Node = _world if _world != null else get_tree().current_scene
	parent.add_child(zone)
	if from.distance_squared_to(to) > 0.01:
		zone.look_at(Vector3(to.x, zone.global_position.y, to.z), Vector3.UP)
	var pulse := zone.create_tween().set_loops()
	pulse.tween_property(mat, "emission_energy_multiplier", 8.5, 0.08)
	pulse.tween_property(mat, "emission_energy_multiplier", 3.5, 0.08)
	return zone


func _pulse_furniture_line(delta: float) -> void:
	_furniture_job["pulse_t"] = float(_furniture_job.get("pulse_t", 0.0)) + delta
	var warn: Node3D = _furniture_job.get("warn") as Node3D
	if warn == null or not is_instance_valid(warn):
		return
	# Zaman daraldıkça çizgi daha agresif yanıp söner
	var urgency := 1.0 - clampf(float(_furniture_job.get("time_left", 1.0)) / furniture_warn_timeout, 0.0, 1.0)
	var line := warn.get_node_or_null("Line") as MeshInstance3D
	if line != null:
		var s := 1.0 + 0.15 * sin(_furniture_job["pulse_t"] * (10.0 + urgency * 14.0))
		line.scale = Vector3(s, 1.0, 1.0)


func _player_touches_furniture_line() -> bool:
	if _player == null or _furniture_job.is_empty():
		return false
	var from: Vector3 = _furniture_job.get("from", Vector3.ZERO)
	var to: Vector3 = _furniture_job.get("to", Vector3.ZERO)
	var p := _player.global_position
	p.y = 0.0
	var closest := _closest_point_on_segment(p, from, to)
	return p.distance_to(closest) <= furniture_touch_pad


func _closest_point_on_segment(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return a
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return a + ab * t


func _execute_furniture_slide() -> void:
	if _furniture_job.is_empty() or bool(_furniture_job.get("moving", false)):
		return
	var piece: Node3D = _furniture_job.get("piece") as Node3D
	var target: Vector3 = _furniture_job.get("target", Vector3.ZERO)
	var warn: Node3D = _furniture_job.get("warn") as Node3D
	if warn != null and is_instance_valid(warn):
		warn.queue_free()
	_furniture_job["warn"] = null
	if piece == null or not is_instance_valid(piece):
		_furniture_job.clear()
		return
	var old_tw: Variant = piece.get_meta("warn_tween", null)
	if old_tw is Tween and (old_tw as Tween).is_valid():
		(old_tw as Tween).kill()
	target = _resolve_furniture_target(target, piece, piece.global_position.y)
	var flat := Vector3(target.x - piece.global_position.x, 0.0, target.z - piece.global_position.z)
	if flat.length() < 0.35:
		var push := flat
		if push.length_squared() < 0.01:
			push = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
		target = piece.global_position + push.normalized() * _rng.randf_range(2.2, 3.4)
		target = _resolve_furniture_target(target, piece, piece.global_position.y)
	_furniture_job["target"] = target
	_furniture_job["start_pos"] = piece.global_position
	_furniture_job["start_rot"] = piece.rotation.y
	_furniture_job["end_rot"] = piece.rotation.y + _rng.randf_range(-PI * 0.2, PI * 0.2)
	_furniture_job["move_elapsed"] = 0.0
	_furniture_job["move_dur"] = maxf(furniture_slide_time, 0.08)
	_furniture_job["moving"] = true
	_furniture_job["last_pos"] = piece.global_position
	_furniture_job["time_left"] = 0.0
	_furniture_job["shove_cd"] = 0.0


func _update_furniture_slide_motion(delta: float) -> void:
	var piece: Node3D = _furniture_job.get("piece") as Node3D
	if piece == null or not is_instance_valid(piece):
		_furniture_job.clear()
		return
	var dur: float = float(_furniture_job.get("move_dur", furniture_slide_time))
	var elapsed: float = float(_furniture_job.get("move_elapsed", 0.0)) + delta
	_furniture_job["move_elapsed"] = elapsed
	var t := clampf(elapsed / maxf(dur, 0.001), 0.0, 1.0)
	var start: Vector3 = _furniture_job.get("start_pos", piece.global_position)
	var target: Vector3 = _furniture_job.get("target", piece.global_position)
	piece.global_position = start.lerp(target, t)
	piece.rotation.y = lerpf(
		float(_furniture_job.get("start_rot", 0.0)),
		float(_furniture_job.get("end_rot", 0.0)),
		t
	)
	if t >= 1.0:
		piece.global_position = target
		_furniture_job.clear()
		_furniture_cd = furniture_interval * randf_range(0.45, 0.7)
		furniture_shifted.emit()


func _update_furniture_shove() -> void:
	if _furniture_job.is_empty() or _player == null:
		return
	var piece: Node3D = _furniture_job.get("piece") as Node3D
	if piece == null or not is_instance_valid(piece):
		_furniture_job.clear()
		return
	var last: Vector3 = _furniture_job.get("last_pos", piece.global_position)
	var cur := piece.global_position
	var move_dir := cur - last
	move_dir.y = 0.0
	_furniture_job["last_pos"] = cur
	_furniture_job["shove_cd"] = maxf(0.0, float(_furniture_job.get("shove_cd", 0.0)) - get_physics_process_delta_time())
	var half: Vector3 = piece.get_meta("half_size", Vector3(0.55, 0.55, 0.35))
	var reach := maxf(half.x, half.z) + 0.85
	var to_player := _player.global_position - cur
	to_player.y = 0.0
	if to_player.length() > reach:
		return
	if float(_furniture_job.get("shove_cd", 0.0)) > 0.0:
		return
	var shove: Vector3
	if move_dir.length_squared() > 0.00005:
		shove = move_dir.normalized()
		if to_player.length_squared() > 0.01:
			shove = (shove * 0.7 + to_player.normalized() * 0.5).normalized()
	elif to_player.length_squared() > 0.01:
		shove = to_player.normalized()
	else:
		return
	_player.apply_hazard_shove(shove, furniture_shove_power)
	_furniture_job["shove_cd"] = 0.05


func _clear_furniture_job() -> void:
	if not _furniture_job.is_empty():
		var warn: Node3D = _furniture_job.get("warn") as Node3D
		if warn != null and is_instance_valid(warn):
			warn.queue_free()
	_furniture_job.clear()


func _clear_furniture() -> void:
	_clear_furniture_job()
	for f in _furniture:
		if f != null and is_instance_valid(f):
			f.queue_free()
	_furniture.clear()


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
