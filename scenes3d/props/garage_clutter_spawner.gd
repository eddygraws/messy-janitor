class_name GarageClutterSpawner
extends Node3D

## LevelData3D'den oda doldurur — 2D dirt tiplerinin 3D görsel karşılıkları.

const ClutterPropScript := preload("res://scenes3d/props/clutter_prop.gd")
const PROP_MASK := 4

signal objective_changed(remaining: int, total: int)
signal level_cleared
signal reinforcement_spawned(count: int)
signal section_advanced(section_index: int, section_count: int, section: Dictionary)
signal prop_cleared

@export var spawn_on_ready: bool = false

var _objective_total: int = 0
var _cleared: bool = false
var _rng := RandomNumberGenerator.new()
var _level_spec: Dictionary = {}
var _level_index: int = 0
var _placed: Array[Vector3] = []
var _reinforce_cd: float = 0.0
var _tempo: TempoPhaseDirector
var _pressure_active: bool = false
var _boss_mode: String = ""
var _soft_pressure: bool = false
var _sections: Array = []
var _section_index: int = 0


func _ready() -> void:
	_rng.randomize()
	if spawn_on_ready:
		load_level(0)


func bind_tempo(tempo: TempoPhaseDirector) -> void:
	_tempo = tempo
	if _tempo != null and not _tempo.tempo_phase_changed.is_connected(_on_tempo_phase):
		_tempo.tempo_phase_changed.connect(_on_tempo_phase)


func start_pressure(boss_mode: String = "", soft: bool = false) -> void:
	_boss_mode = boss_mode
	_soft_pressure = soft
	_pressure_active = true
	if soft:
		_reinforce_cd = 12.0
		return
	if _boss_mode.is_empty():
		_reinforce_cd = 8.0
	elif _boss_mode == "mega_scrub":
		# L5: daha yavaş takviye
		_reinforce_cd = 5.5
		spawn_reinforcement(1)
	else:
		_reinforce_cd = 2.2
		spawn_reinforcement(2 if _boss_mode == "box_rain" else 1)


func stop_pressure() -> void:
	_pressure_active = false
	_reinforce_cd = 0.0
	_boss_mode = ""
	_soft_pressure = false


func _process(delta: float) -> void:
	if not _pressure_active or _cleared or _tempo == null:
		return
	var phase := _tempo.get_phase()
	# Soft tutorial: ısınma fazında da yavaş takviye
	if _soft_pressure:
		_reinforce_cd -= delta
		if _reinforce_cd > 0.0:
			return
		_reinforce_cd = randf_range(11.0, 15.0)
		if get_remaining_objectives() < 10:
			spawn_reinforcement(1)
		return
	# Boss: faz beklemeden takviye
	if _boss_mode.is_empty() and phase < TempoPhaseDirector.PHASE_RAMP:
		return
	_reinforce_cd -= delta
	if _reinforce_cd > 0.0:
		return
	var mult := _tempo.get_spawn_rate_mult()
	if not _boss_mode.is_empty():
		mult *= 1.15 if _boss_mode == "mega_scrub" else 1.35
	# Seviye ilerledikçe takviye / kutu yağmuru hızlanır
	var level_pace := lerpf(1.0, 0.52, clampf(float(_level_index) / 9.0, 0.0, 1.0))
	_reinforce_cd = (10.0 / mult) * randf_range(0.75, 1.05) * level_pace
	if _boss_mode == "box_rain":
		_reinforce_cd = maxf(1.35, _reinforce_cd * 0.48)
	elif _boss_mode == "mega_scrub":
		_reinforce_cd = maxf(6.0, _reinforce_cd * 1.25)
	var n := 1
	if phase >= TempoPhaseDirector.PHASE_FINALE or not _boss_mode.is_empty():
		n = 2
	if _boss_mode == "mega_scrub":
		n = 1
	if _boss_mode == "box_rain":
		n = 3 + (1 if _level_index >= 7 else 0)
	spawn_reinforcement(n)


func _on_tempo_phase(phase: int) -> void:
	if not _pressure_active or _cleared:
		return
	match phase:
		TempoPhaseDirector.PHASE_RAMP:
			spawn_reinforcement(1 if _boss_mode == "mega_scrub" else 2)
			_reinforce_cd = 7.0 if _boss_mode == "mega_scrub" else 5.5
		TempoPhaseDirector.PHASE_FINALE:
			spawn_reinforcement(1 if _boss_mode == "mega_scrub" else 3)
			_reinforce_cd = 5.0 if _boss_mode == "mega_scrub" else 3.5


func load_level(index: int) -> Dictionary:
	_level_index = index
	var spec: Dictionary = LevelData3D.get_level(index)
	populate_from_spec(spec)
	return spec


func populate_from_spec(spec: Dictionary) -> void:
	_cleared = false
	_level_spec = spec.duplicate(true)
	_clear_children()
	_objective_total = 0
	_sections = (spec.get("sections", []) as Array).duplicate(true)
	_section_index = 0
	stop_pressure()

	var stations: Array = spec.get("stations", ["trash", "bucket"]) as Array
	if "trash" in stations:
		_add_trash_bin(Vector3(0.0, 0.0, 5.8))
	if "bucket" in stations:
		_add_bucket_station(Vector3(-3.6, 0.0, 5.6))
	if "drain" in stations:
		_add_drain(Vector3(3.6, 0.0, 5.8))

	_placed = [
		Vector3(0, 0, 5.8), Vector3(-3.6, 0, 5.6), Vector3(3.6, 0, 5.8), Vector3(0, 0, 2.0)
	]
	var props: Array = _props_for_current_section()
	_spawn_prop_entries(props)
	call_deferred("_recount_objectives")


func get_section_count() -> int:
	return _sections.size()


func get_section_index() -> int:
	return _section_index


func get_current_section() -> Dictionary:
	if _section_index < 0 or _section_index >= _sections.size():
		return {}
	return _sections[_section_index] as Dictionary


func has_sections() -> bool:
	return not _sections.is_empty()


func _props_for_current_section() -> Array:
	if not _sections.is_empty():
		var sec: Dictionary = _sections[_section_index] as Dictionary
		return sec.get("props", []) as Array
	return _level_spec.get("props", []) as Array


func _spawn_prop_entries(props: Array) -> void:
	for entry_variant in props:
		var entry: Dictionary = entry_variant as Dictionary
		var type: String = String(entry.get("type", "box"))
		var count: int = int(entry.get("count", 1))
		var fallen: bool = bool(entry.get("fallen", false))
		for _i in count:
			var pos: Vector3 = _free_pos(_placed)
			_placed.append(pos)
			_spawn_prop(type, pos, fallen)


## Faz baskısı: ekstra kir/koli düşürür (2D MoldSpawner hızlanmasının 3D karşılığı).
func spawn_reinforcement(count: int = 1) -> int:
	if _cleared or _level_spec.is_empty():
		return 0
	var types := _reinforcement_types()
	if types.is_empty():
		return 0
	var spawned := 0
	for _i in count:
		if get_remaining_objectives() >= 18:
			break
		var t: String = types[_rng.randi() % types.size()]
		var pos := _free_pos(_placed)
		_placed.append(pos)
		_spawn_prop(t, pos, t == "box" and _rng.randf() > 0.7)
		spawned += 1
	if spawned > 0:
		for c in get_children():
			if c is ClutterProp:
				var prop := c as ClutterProp
				if not prop.destroyed.is_connected(_on_prop_destroyed):
					prop.destroyed.connect(_on_prop_destroyed)
		_objective_total += spawned
		objective_changed.emit(get_remaining_objectives(), _objective_total)
		reinforcement_spawned.emit(spawned)
	return spawned


func _reinforcement_types() -> Array[String]:
	if _boss_mode == "box_rain":
		return ["box", "box", "box", "crumb", "box"]
	if _boss_mode == "mega_scrub":
		return ["crumb", "slime", "potion"]
	if _soft_pressure:
		return ["box", "box"]
	var out: Array[String] = []
	var props: Array = _props_for_current_section()
	if props.is_empty():
		props = _level_spec.get("props", []) as Array
	for entry_variant in props:
		var entry: Dictionary = entry_variant as Dictionary
		var t := String(entry.get("type", "box"))
		# TV/boss gibi ağır objeleri sürekli çoğaltma
		if t in ["tv", "boss_slime", "hidden", "crust"]:
			continue
		out.append(t)
	if out.is_empty():
		out.append("box")
	return out


func _recount_objectives() -> void:
	_objective_total = 0
	for c in get_children():
		if c is ClutterProp and bool(c.get_meta("objective", true)):
			var prop := c as ClutterProp
			_objective_total += prop.get_stack_units()
			if not prop.destroyed.is_connected(_on_prop_destroyed):
				prop.destroyed.connect(_on_prop_destroyed)
	objective_changed.emit(_objective_total, _objective_total)


func _on_prop_destroyed() -> void:
	prop_cleared.emit()
	call_deferred("_emit_objective_state")


func _emit_objective_state() -> void:
	var left := get_remaining_objectives()
	objective_changed.emit(left, _objective_total)
	if left <= 0 and not _cleared:
		if _try_advance_section():
			return
		_cleared = true
		level_cleared.emit()


func _try_advance_section() -> bool:
	if _sections.is_empty():
		return false
	if _section_index + 1 >= _sections.size():
		return false
	_section_index += 1
	# Eski takviye / props temiz; istasyonları koru
	_clear_clutter_only()
	_placed = [
		Vector3(0, 0, 5.8), Vector3(-3.6, 0, 5.6), Vector3(3.6, 0, 5.8), Vector3(0, 0, 2.0)
	]
	_spawn_prop_entries(_props_for_current_section())
	_recount_objectives()
	section_advanced.emit(_section_index, _sections.size(), get_current_section())
	return true


func _clear_clutter_only() -> void:
	var to_free: Array[Node] = []
	for c in get_children():
		if c is ClutterProp:
			to_free.append(c)
	for c in to_free:
		var prop := c as ClutterProp
		if prop.destroyed.is_connected(_on_prop_destroyed):
			prop.destroyed.disconnect(_on_prop_destroyed)
		remove_child(c)
		c.free()


func get_remaining_objectives() -> int:
	var left := 0
	# Spawner çocukları
	for c in get_children():
		if c is ClutterProp and is_instance_valid(c):
			var prop := c as ClutterProp
			if prop.is_destroying():
				continue
			if bool(prop.get_meta("objective", true)):
				left += prop.get_stack_units()
	# Oyuncunun elinde taşınanlar (reparent edilmiş)
	for node in get_tree().get_nodes_in_group("ClutterProp"):
		var prop := node as ClutterProp
		if prop == null or not is_instance_valid(prop):
			continue
		if not prop.is_being_carried() or prop.is_destroying():
			continue
		if prop.get_parent() == self:
			continue
		if bool(prop.get_meta("objective", true)):
			left += prop.get_stack_units()
	return left


func _clear_children() -> void:
	for c in get_children():
		c.queue_free()


func _free_pos(placed: Array[Vector3]) -> Vector3:
	for _try in 40:
		var p := Vector3(_rng.randf_range(-7.2, 7.2), 0.0, _rng.randf_range(-4.8, 4.0))
		var ok := true
		for q in placed:
			if Vector2(p.x, p.z).distance_to(Vector2(q.x, q.z)) < 1.35:
				ok = false
				break
		if ok:
			return p
	return Vector3(_rng.randf_range(-5.0, 5.0), 0.0, _rng.randf_range(-3.0, 2.5))


func _spawn_prop(type: String, pos: Vector3, fallen: bool) -> void:
	match type:
		"box":
			if fallen:
				_add_single_box(pos, Vector3(0.3, 0.2, 0.4), true)
			else:
				_add_box_stack(pos, _rng.randi_range(1, 3), _rng.randf_range(-0.4, 0.4))
		"tv":
			_add_broken_tv(pos, _rng.randf_range(-1.0, 1.0), _rng.randf() > 0.65)
		"mold":
			_add_blob(pos, "mold", Color(0.35, 0.7, 0.3), 3, true, "")
		"crumb":
			_add_blob(pos, "crumb", Color(0.72, 0.58, 0.35), 0, true, "trash")
		"slime":
			_add_scrub_puddle(pos, "slime", Color(0.35, 0.95, 0.55), 1.15, 2.4, 1.0)
		"potion":
			_add_scrub_puddle(pos, "potion", Color(0.75, 0.35, 0.95), 1.05, 3.4, 0.95)
		"crust":
			_add_blob(pos, "crust", Color(0.42, 0.32, 0.22), 7, false, "")
		"wet":
			_add_blob(pos, "wet", Color(0.4, 0.7, 0.95), 3, false, "")
		"tiny":
			_add_blob(pos, "tiny", Color(0.9, 0.95, 1.0), 2, true, "trash", 0.35)
		"hidden":
			_add_blob(pos, "hidden", Color(0.15, 0.15, 0.2), 3, true, "", 0.7, true)
		"boss_slime":
			_add_scrub_puddle(pos, "boss_slime", Color(0.25, 1.0, 0.45), 1.85, 5.5, 1.55)
		_:
			_add_box_stack(pos, 1, 0.0)


func _add_scrub_puddle(
	pos: Vector3,
	prop_id: String,
	color: Color,
	radius: float,
	work: float,
	scale_mul: float = 1.0,
) -> void:
	var root := ClutterPropScript.new()
	root.name = prop_id.capitalize()
	root.prop_id = prop_id
	root.idle_style = ClutterProp.IdleStyle.BUZZ
	root.hit_wobble_enabled = true
	root.hits_to_destroy = 0
	root.can_carry = false
	root.requires_scrub = true
	root.scrub_radius = radius * scale_mul
	root.scrub_work_needed = work
	root.max_hit_distance = radius * scale_mul + 1.0
	root.react_distance = radius * scale_mul + 1.15
	root.scrub_radius = maxf(root.scrub_radius, radius * scale_mul + 0.55)
	root.position = pos
	root.scale = Vector3.ONE * scale_mul
	root.set_meta("objective", true)
	root.set_meta("deliver_to", "")
	# Mor iksir: üzerindeyken sarhoş dans
	if prop_id == "potion":
		root.set_meta("causes_drunk", true)
	add_child(root)

	var pivot := Node3D.new()
	pivot.name = "Pivot"
	root.add_child(pivot)

	# Sıvı lekeler fiziksel engel değil — oyuncu içinden geçer; kayganlık HazardDirector'da.
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	pivot.add_child(body)

	# Yerde yayılmış sıvı leke
	var puddle := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.06
	puddle.mesh = disc
	puddle.material_override = HitWobbleMaterial.create(
		color, 0.55, color.lightened(0.25), 0.35, 0.14, true, 0.018
	)
	puddle.position = Vector3(0.0, 0.04, 0.0)
	pivot.add_child(puddle)
	root.register_wobble_mesh(puddle)

	var blob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius * 0.38
	sphere.height = radius * 0.55
	blob.mesh = sphere
	blob.material_override = HitWobbleMaterial.create(
		color.lightened(0.1), 0.4, color, 0.45, 0.18, true, 0.022
	)
	blob.position = Vector3(0.0, 0.12, 0.0)
	pivot.add_child(blob)
	root.register_wobble_mesh(blob)

	# Şekil sadece referans / gelecek raycast için; layer=0 → player'a çarpmaz
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius * 0.62
	cyl.height = 0.28
	shape.shape = cyl
	shape.position = Vector3(0.0, 0.12, 0.0)
	shape.disabled = true
	body.add_child(shape)

	var label := Label3D.new()
	label.text = "PASPAS"
	label.font_size = 42
	label.modulate = color.lightened(0.35)
	label.position = Vector3(0.0, 0.55, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pivot.add_child(label)


func _add_blob(
	pos: Vector3,
	prop_id: String,
	color: Color,
	hits: int,
	carry: bool,
	deliver: String,
	scale_mul: float = 1.0,
	hidden: bool = false,
) -> void:
	var root := ClutterPropScript.new()
	root.name = prop_id.capitalize()
	root.prop_id = prop_id
	root.idle_style = ClutterProp.IdleStyle.BUZZ if prop_id.find("slime") >= 0 else ClutterProp.IdleStyle.SWAY
	root.hit_wobble_enabled = true
	root.hits_to_destroy = hits
	root.can_carry = carry
	root.max_hit_distance = 3.2
	root.react_distance = 2.9 if not hidden else 2.0
	root.position = pos
	root.scale = Vector3.ONE * scale_mul
	root.set_meta("objective", true)
	root.set_meta("deliver_to", deliver)
	root.set_meta("hidden_prop", hidden)
	add_child(root)

	var pivot := Node3D.new()
	pivot.name = "Pivot"
	root.add_child(pivot)

	var body := StaticBody3D.new()
	body.collision_layer = PROP_MASK
	body.collision_mask = 0
	pivot.add_child(body)

	var mesh_inst := MeshInstance3D.new()
	var use_sphere := prop_id.find("slime") >= 0 or prop_id == "mold" or prop_id == "wet"
	var mesh: Mesh
	if use_sphere:
		var sphere := SphereMesh.new()
		sphere.radius = 0.32
		sphere.height = 0.55
		mesh = sphere
	else:
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(0.45, 0.45, 0.45) if prop_id != "tiny" else Vector3(0.22, 0.22, 0.22)
		mesh = box_mesh
	mesh_inst.mesh = mesh
	var wobble: float = 0.12 if prop_id.find("slime") >= 0 else 0.08
	mesh_inst.material_override = HitWobbleMaterial.create(color, 0.75, color.lightened(0.2), 0.15 if not hidden else 0.02, wobble)
	mesh_inst.position = Vector3(0, 0.28, 0)
	if hidden:
		mesh_inst.transparency = 0.85
	pivot.add_child(mesh_inst)
	root.register_wobble_mesh(mesh_inst)

	var shape := CollisionShape3D.new()
	if use_sphere:
		var sph := SphereShape3D.new()
		sph.radius = 0.22
		shape.shape = sph
	else:
		var box := BoxShape3D.new()
		var mesh_size: Vector3 = (mesh as BoxMesh).size
		box.size = mesh_size * 0.68
		shape.shape = box
	shape.position = mesh_inst.position
	body.add_child(shape)

	if hidden:
		root.react_triggered.connect(func() -> void:
			if is_instance_valid(mesh_inst):
				mesh_inst.transparency = 0.0
		)


func _add_box_stack(pos: Vector3, count: int, yaw: float, scale: Vector3 = Vector3.ONE) -> void:
	var root := ClutterPropScript.new()
	root.name = "BoxStack"
	root.prop_id = "box_stack"
	root.idle_style = ClutterProp.IdleStyle.SWAY
	root.sway_degrees = 0.9
	# Kutular paspas/kürekle yok olmaz — sadece çöpe taşınır.
	root.hits_to_destroy = 0
	root.hit_wobble_enabled = true
	root.can_carry = true
	root.max_hit_distance = 3.0
	root.react_distance = 2.8
	root.position = pos
	root.rotation.y = yaw
	root.scale = scale
	root.set_meta("objective", true)
	root.set_meta("deliver_to", "trash")
	root.set_meta("immune_mop", true)
	root.set_meta("stack_units", maxi(1, count))
	add_child(root)

	var pivot := Node3D.new()
	pivot.name = "Pivot"
	root.add_child(pivot)

	var body := StaticBody3D.new()
	body.collision_layer = PROP_MASK
	body.collision_mask = 0
	pivot.add_child(body)

	var mat: ShaderMaterial = HitWobbleMaterial.create(Color(0.62, 0.5, 0.34), 0.95, Color.BLACK, 0.0, 0.07)
	var box_h := ClutterProp.BOX_LAYER_H
	for i in count:
		var mesh_inst := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.72, box_h, 0.72)
		mesh_inst.mesh = mesh
		mesh_inst.material_override = mat.duplicate() as ShaderMaterial
		mesh_inst.position = Vector3(
			_rng.randf_range(-0.04, 0.04),
			box_h * 0.5 + i * (box_h * 0.92),
			_rng.randf_range(-0.04, 0.04)
		)
		mesh_inst.rotation.y = _rng.randf_range(-0.08, 0.08)
		pivot.add_child(mesh_inst)
		root.register_wobble_mesh(mesh_inst)

	# Tek dar ayak izi — üst üste kutu collider kaosunu önler
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.28
	cyl.height = maxf(0.45, box_h * float(count) * 0.85)
	shape.shape = cyl
	shape.position = Vector3(0.0, cyl.height * 0.5, 0.0)
	body.add_child(shape)


func _add_single_box(pos: Vector3, rot: Vector3, fallen: bool = false) -> void:
	var root := ClutterPropScript.new()
	root.name = "BoxSingle"
	root.prop_id = "box_fallen" if fallen else "box_single"
	root.idle_style = ClutterProp.IdleStyle.SWAY
	root.sway_degrees = 1.2 if fallen else 0.7
	root.hits_to_destroy = 0
	root.hit_wobble_enabled = true
	root.can_carry = true
	root.max_hit_distance = 2.95
	root.react_distance = 2.75
	root.position = pos
	root.set_meta("objective", true)
	root.set_meta("deliver_to", "trash")
	root.set_meta("immune_mop", true)
	root.set_meta("stack_units", 1)
	add_child(root)

	var pivot := Node3D.new()
	pivot.name = "Pivot"
	root.add_child(pivot)

	var body := StaticBody3D.new()
	body.collision_layer = PROP_MASK
	body.collision_mask = 0
	pivot.add_child(body)

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.78, 0.48, 0.78)
	mesh_inst.mesh = mesh
	mesh_inst.material_override = HitWobbleMaterial.create(
		Color(0.52, 0.42, 0.3) if fallen else Color(0.62, 0.5, 0.34), 0.95, Color.BLACK, 0.0, 0.08)
	mesh_inst.position = Vector3(0, 0.24 if not fallen else 0.2, 0)
	pivot.add_child(mesh_inst)
	root.register_wobble_mesh(mesh_inst)
	pivot.rotation = rot

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = mesh.size * 0.62
	shape.shape = box_shape
	shape.position = mesh_inst.position
	body.add_child(shape)


func _add_broken_tv(pos: Vector3, yaw: float, on_side: bool = false) -> void:
	var root := ClutterPropScript.new()
	root.name = "BrokenTV"
	root.prop_id = "broken_tv"
	root.idle_style = ClutterProp.IdleStyle.FLICKER if not on_side else ClutterProp.IdleStyle.BUZZ
	root.hit_wobble_enabled = true
	root.hits_to_destroy = 3 if bool(_level_spec.get("tutorial_level", false)) else 6
	root.max_hit_distance = 3.6
	root.sway_degrees = 1.0
	root.react_distance = 3.5
	root.can_carry = false
	root.position = pos
	root.rotation.y = yaw
	root.set_meta("objective", true)
	add_child(root)

	var pivot := Node3D.new()
	pivot.name = "Pivot"
	root.add_child(pivot)

	var body := StaticBody3D.new()
	body.collision_layer = PROP_MASK
	body.collision_mask = 0
	pivot.add_child(body)

	var cabinet := MeshInstance3D.new()
	var cab_mesh := BoxMesh.new()
	cab_mesh.size = Vector3(1.05, 0.72, 0.42) if not on_side else Vector3(0.42, 1.05, 0.72)
	cabinet.mesh = cab_mesh
	cabinet.material_override = HitWobbleMaterial.create(Color(0.22, 0.21, 0.2), 0.88, Color.BLACK, 0.0, 0.1)
	cabinet.position = Vector3(0, cab_mesh.size.y * 0.5, 0)
	if on_side:
		pivot.rotation.z = deg_to_rad(90)
	pivot.add_child(cabinet)
	root.register_wobble_mesh(cabinet)

	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	screen.add_to_group("FlickerSurface")
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.88, 0.52, 0.04) if not on_side else Vector3(0.04, 0.88, 0.52)
	screen.mesh = screen_mesh
	screen.material_override = HitWobbleMaterial.create(
		Color(0.08, 0.1, 0.12), 0.35, Color(0.35, 0.55, 0.42), 0.15, 0.12)
	screen.position = cabinet.position + Vector3(0, 0, cab_mesh.size.z * 0.5 + 0.02)
	if on_side:
		screen.position = cabinet.position + Vector3(cab_mesh.size.x * 0.5 + 0.02, 0, 0)
	pivot.add_child(screen)
	root.register_flicker_surface(screen)
	root.register_wobble_mesh(screen)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = cab_mesh.size * Vector3(0.72, 0.85, 0.72)
	shape.shape = box_shape
	shape.position = cabinet.position
	body.add_child(shape)


func _add_trash_bin(pos: Vector3) -> void:
	var zone := Node3D.new()
	zone.name = "TrashBin"
	zone.add_to_group("TrashDrop")
	zone.position = pos
	# Mesh aynı kalır; kabul hacmi daha yüksek / geniş (fırlatılan yığınlar için)
	zone.set_meta("interact_radius", 2.45)
	zone.set_meta("interact_height", 3.6)
	add_child(zone)
	_station_mesh(zone, Color(0.18, 0.22, 0.2), Color(0.35, 0.55, 0.4), "ÇÖP", false, Vector3(1.25, 1.05, 1.0))


func _add_bucket_station(pos: Vector3) -> void:
	var zone := Node3D.new()
	zone.name = "BucketStation"
	zone.add_to_group("BucketStation")
	zone.position = pos
	zone.set_meta("interact_radius", 2.35)
	add_child(zone)

	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.38
	body_mesh.bottom_radius = 0.42
	body_mesh.height = 0.72
	body.mesh = body_mesh
	var body_mat := HitWobbleMaterial.create(
		Color(0.35, 0.38, 0.42), 0.88, Color.BLACK, 0.0, 0.05, true, 0.028
	)
	body.material_override = body_mat
	body.position = Vector3(0.0, 0.36, 0.0)
	zone.add_child(body)

	var water := MeshInstance3D.new()
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 0.32
	water_mesh.bottom_radius = 0.32
	water_mesh.height = 0.12
	water.mesh = water_mesh
	# Şeffaf su — toon outline'sız
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.35, 0.65, 0.85, 0.85)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = water_mat
	water.position = Vector3(0.0, 0.58, 0.0)
	zone.add_child(water)

	var label := Label3D.new()
	label.text = "KOVA"
	label.font_size = 56
	label.modulate = Color(0.7, 0.88, 1.0)
	label.position = Vector3(0.0, 1.15, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	zone.add_child(label)


func _add_drain(pos: Vector3) -> void:
	var zone := Node3D.new()
	zone.name = "Drain"
	zone.add_to_group("DrainDrop")
	zone.position = pos
	zone.set_meta("interact_radius", 2.3)
	zone.set_meta("interact_height", 3.2)
	add_child(zone)
	_station_mesh(zone, Color(0.12, 0.2, 0.18), Color(0.3, 0.9, 0.7), "GİDER", true)


func _station_mesh(
	zone: Node3D,
	body_col: Color,
	rim_col: Color,
	title: String,
	flat: bool = false,
	size: Vector3 = Vector3.ZERO,
) -> void:
	var body_size := size
	if body_size == Vector3.ZERO:
		body_size = Vector3(1.1, 0.25 if flat else 1.05, 0.85)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = body_size
	mesh.mesh = box
	mesh.material_override = HitWobbleMaterial.create(body_col, 0.88, Color.BLACK, 0.0, 0.04, true, 0.026)
	mesh.position = Vector3(0.0, body_size.y * 0.5 if not flat else 0.12, 0.0)
	zone.add_child(mesh)

	var rim := MeshInstance3D.new()
	var rim_mesh := BoxMesh.new()
	rim_mesh.size = Vector3(body_size.x + 0.08, 0.08, body_size.z + 0.08)
	rim.mesh = rim_mesh
	rim.material_override = HitWobbleMaterial.create(
		rim_col, 0.7, rim_col.lightened(0.2), 0.25, 0.02, true, 0.02
	)
	rim.position = Vector3(0.0, (0.28 if flat else body_size.y + 0.04), 0.0)
	zone.add_child(rim)

	var label := Label3D.new()
	label.text = title
	label.font_size = 64
	label.modulate = rim_col.lightened(0.3)
	label.position = Vector3(0.0, 0.55 if flat else body_size.y + 0.3, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	zone.add_child(label)
