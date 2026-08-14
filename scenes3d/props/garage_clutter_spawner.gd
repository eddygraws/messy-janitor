class_name GarageClutterSpawner
extends Node3D

## LevelData3D'den oda doldurur — 2D dirt tiplerinin 3D görsel karşılıkları.

const ClutterPropScript := preload("res://scenes3d/props/clutter_prop.gd")
const PROP_MASK := 4
const PATH_WET := "res://textures/stains/wet_stain.png"
const PATH_SLIME := "res://textures/stains/slime_stain.png"

signal objective_changed(remaining: int, total: int)
signal level_cleared
signal section_advanced(section_index: int, section_count: int, section: Dictionary)
signal prop_cleared

@export var spawn_on_ready: bool = false
## Menü zorluğu (DifficultyProfile3D.prop_count_mult) — load_level öncesi set edilir.
var prop_difficulty_mult: float = 1.0

var _objective_total: int = 0
var _cleared: bool = false
var _rng := RandomNumberGenerator.new()
var _level_spec: Dictionary = {}
var _level_index: int = 0
var _placed: Array[Vector3] = []
var _placed_clear: Array[float] = []
var _tempo: TempoPhaseDirector
var _sections: Array = []
var _section_index: int = 0
var _painting_spawn_i: int = 0
var _layout: RoomLayout3D


func _ready() -> void:
	_rng.randomize()
	if spawn_on_ready:
		load_level(0)


func bind_room_layout(layout: RoomLayout3D) -> void:
	_layout = layout


func bind_tempo(tempo: TempoPhaseDirector) -> void:
	# Tempo nabız (emir/hazard hızı) için bağlı kalır; ekstra kutu spawn yok.
	_tempo = tempo


## Endless takviye kapalı — sadece level/section props listesi spawn olur.
func start_pressure(_boss_mode: String = "", _soft: bool = false) -> void:
	pass


func stop_pressure() -> void:
	pass


func _process(_delta: float) -> void:
	pass


func load_level(index: int) -> Dictionary:
	_level_index = index
	var spec: Dictionary = LevelData3D.get_level(index)
	if not bool(spec.get("tutorial_level", false)):
		spec = LevelData3D.apply_runtime_prop_scale(spec, prop_difficulty_mult)
	populate_from_spec(spec)
	return spec


## Layout/footprint apply_spec'ten sonra çağır; index + scale burada.
func begin_level(index: int) -> Dictionary:
	_level_index = index
	var spec: Dictionary = LevelData3D.get_level(index)
	if not bool(spec.get("tutorial_level", false)):
		spec = LevelData3D.apply_runtime_prop_scale(spec, prop_difficulty_mult)
	return spec


func populate_from_spec(spec: Dictionary) -> void:
	_cleared = false
	_level_spec = spec.duplicate(true)
	_painting_spawn_i = 0
	_clear_children()
	_objective_total = 0
	_sections = (spec.get("sections", []) as Array).duplicate(true)
	_section_index = 0
	stop_pressure()

	var stations: Array = spec.get("stations", ["trash", "bucket"]) as Array
	if "trash" in stations:
		_add_trash_bin(_station_pos("trash"))
	if "bucket" in stations:
		_add_bucket_station(_station_pos("bucket"))
	if "drain" in stations:
		_add_drain(_station_pos("drain"))

	_reset_placed_anchors()
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
			var clear_r := _clearance_for(type)
			var pos: Vector3 = _free_pos(clear_r)
			_commit_placed(pos, clear_r)
			_spawn_prop(type, pos, fallen)


## Endless takviye kaldırıldı — API uyumu için no-op.
func spawn_reinforcement(_count: int = 1) -> int:
	return 0


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
	_reset_placed_anchors()
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


## Abur cubur power-up: sahnedeki tüm hedefleri süpür (elde taşınanlar hariç).
func sweep_all_objectives() -> int:
	var cleared := 0
	var batch: Array[ClutterProp] = []
	for c in get_children():
		if c is ClutterProp:
			var prop := c as ClutterProp
			if prop.is_junk() or prop.is_destroying() or prop.is_being_carried():
				continue
			if bool(prop.get_meta("objective", true)):
				batch.append(prop)
	for i in batch.size():
		var prop := batch[i]
		if not is_instance_valid(prop):
			continue
		# Hafif kademeli — görsel fırtına hissi
		if i == 0:
			prop.force_powerup_clear()
		else:
			var delay := 0.04 * float(i)
			get_tree().create_timer(delay).timeout.connect(func() -> void:
				if is_instance_valid(prop):
					prop.force_powerup_clear()
			)
		cleared += 1
	return cleared


## Opsiyonel yan ödül coin'leri — objective değil, seviye kilidi yok.
func spawn_bonus_coins(count: int = 3, parent_override: Node3D = null) -> int:
	var CoinScript := preload("res://scenes3d/props/coin_pickup.gd")
	var parent: Node3D = parent_override if parent_override != null else self
	var spawned := 0
	for _i in maxi(0, count):
		var pos := _free_pos(0.85)
		_commit_placed(pos, 0.85)
		var coin: CoinPickup3D = CoinScript.new()
		coin.name = "BonusCoin"
		coin.value = 1
		coin.position = pos
		parent.add_child(coin)
		spawned += 1
	return spawned


## Nadir can pickup — şans dışarıdan verilir (0/1).
func spawn_heart_pickup(parent_override: Node3D = null) -> bool:
	var HeartScript := preload("res://scenes3d/props/heart_pickup.gd")
	var parent: Node3D = parent_override if parent_override != null else self
	var pos := _free_pos(0.9)
	_commit_placed(pos, 0.9)
	var heart: HeartPickup3D = HeartScript.new()
	heart.name = "HeartPickup"
	heart.position = pos
	parent.add_child(heart)
	return true


func _clear_children() -> void:
	for c in get_children():
		c.queue_free()


func _station_pos(kind: String) -> Vector3:
	if _layout != null:
		match kind:
			"trash":
				return _layout.station_trash()
			"bucket":
				return _layout.station_bucket()
			"drain":
				return _layout.station_drain()
	match kind:
		"trash":
			return RoomLayout3D.station_trash_default()
		"bucket":
			return RoomLayout3D.station_bucket_default()
		"drain":
			return RoomLayout3D.station_drain_default()
	return Vector3.ZERO


func _reset_placed_anchors() -> void:
	_placed.clear()
	_placed_clear.clear()
	if _layout != null:
		for a in _layout.get_blocked_anchors():
			_placed.append(a.get("pos", Vector3.ZERO) as Vector3)
			_placed_clear.append(float(a.get("clear", 1.2)))
	else:
		_placed = [
			RoomLayout3D.station_trash_default(),
			RoomLayout3D.station_bucket_default(),
			RoomLayout3D.station_drain_default(),
			Vector3(0, 0, 2.0),
		]
		_placed_clear = [1.5, 1.45, 1.45, 1.7]


func _clearance_for(type: String) -> float:
	match type:
		"wet":
			return 2.6
		"slime":
			return 2.7
		"potion":
			return 2.55
		"boss_slime":
			return 3.4
		"box":
			return 1.05
		"tv", "tv_repair":
			return 1.35
		"painting":
			return 0.85
		"crumb", "tiny", "mold", "hidden", "crust", "dust":
			return 0.7
		_:
			return 1.0


func _commit_placed(pos: Vector3, clear_r: float) -> void:
	_placed.append(pos)
	_placed_clear.append(clear_r)


func _free_pos(clear_r: float = 1.05) -> Vector3:
	var best := Vector3(999.0, 0.0, 999.0)
	var best_pen := INF
	for _try in 100:
		var p: Vector3
		if _layout != null:
			p = _layout.random_spawn_point(_rng)
		else:
			p = Vector3(_rng.randf_range(-6.6, 6.6), 0.0, _rng.randf_range(-4.2, 3.4))
		# Oyuncu spawn / merkez koridor çekirdeği
		if Vector2(p.x, p.z - 2.0).length() < 1.15:
			continue
		var pen := 0.0
		var ok := true
		for i in _placed.size():
			var need := clear_r + _placed_clear[i]
			var d := Vector2(p.x, p.z).distance_to(Vector2(_placed[i].x, _placed[i].z))
			if d < need:
				ok = false
				pen += need - d
		if ok:
			return p
		if pen < best_pen:
			best_pen = pen
			best = p
	if best_pen < INF and best.length_squared() > 0.5:
		return best
	if _layout != null:
		return _layout.random_spawn_point(_rng)
	return Vector3(_rng.randf_range(-4.5, 4.5), 0.0, _rng.randf_range(-2.5, 2.0))


func _spawn_prop(type: String, pos: Vector3, fallen: bool) -> void:
	match type:
		"box":
			if fallen:
				_add_single_box(pos, Vector3(0.3, 0.2, 0.4), true)
			else:
				# Ara sıra tek yıkık koli (asset varsa katalog da tercih eder)
				if _rng.randf() < 0.14:
					_add_single_box(pos, Vector3.ZERO, true)
				else:
					var mn := int(_level_spec.get("box_stack_min", 1))
					var mx := int(_level_spec.get("box_stack_max", 3))
					mx = maxi(mn, mx)
					_add_box_stack(pos, _rng.randi_range(mn, mx), _rng.randf_range(-PI, PI))
		"tv":
			_add_broken_tv(pos, _rng.randf_range(-1.0, 1.0), _rng.randf() > 0.65)
		"tv_repair":
			_add_repair_tv(pos, _rng.randf_range(-0.6, 0.6))
		"painting":
			var wall := "back" if (_painting_spawn_i % 2) == 0 else "left"
			_painting_spawn_i += 1
			_add_crooked_painting(wall)
		"mold":
			# Küf: paspasla vur VEYA süpürgeyle em (broom chapter)
			_add_blob(pos, "mold", Color(0.35, 0.7, 0.3), 3, true, "", 1.0, false, "mop", true, 1.15)
		"crumb":
			_add_vacuum_debris(pos, "crumb", Color(0.72, 0.58, 0.35), 0.9, 0.85)
		"dust":
			_add_vacuum_debris(pos, "dust", Color(0.62, 0.58, 0.5), 0.75, 0.7)
		"slime":
			_add_scrub_puddle(pos, "slime", Color(0.35, 0.95, 0.55), 2.45, 3.2, 1.28)
		"potion":
			_add_scrub_puddle(pos, "potion", Color(0.75, 0.35, 0.95), 2.3, 4.0, 1.22)
		"crust":
			_add_blob(pos, "crust", Color(0.42, 0.32, 0.22), 7, false, "", 1.0, false, "brush")
		"wet":
			_add_wet_stain(pos)
		"tiny":
			_add_blob(pos, "tiny", Color(0.9, 0.95, 1.0), 2, true, "trash", 0.35, false, "tweezers")
		"hidden":
			_add_blob(pos, "hidden", Color(0.15, 0.15, 0.2), 3, true, "", 0.7, true, "mop")
		"boss_slime":
			_add_scrub_puddle(pos, "boss_slime", Color(0.25, 1.0, 0.45), 3.35, 7.0, 1.42)
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
	root.idle_style = ClutterProp.IdleStyle.NONE
	root.hit_wobble_enabled = false
	root.hits_to_destroy = 0
	root.can_carry = false
	root.requires_scrub = true
	root.required_tool = "mop"
	root.liquid_wipe = true
	root.scrub_radius = radius * scale_mul + 1.15
	root.scrub_work_needed = work
	root.max_hit_distance = radius * scale_mul + 1.6
	root.react_distance = radius * scale_mul + 1.7
	root.position = pos
	root.scale = Vector3.ONE * scale_mul
	root.set_meta("objective", true)
	root.set_meta("deliver_to", "")
	if prop_id == "potion":
		root.set_meta("causes_drunk", true)
	add_child(root)

	var pivot := Node3D.new()
	pivot.name = "Pivot"
	root.add_child(pivot)

	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	pivot.add_child(body)

	var half := radius * 1.05
	var puddle := MeshInstance3D.new()
	puddle.name = "WipePuddle"
	var plane := PlaneMesh.new()
	plane.size = Vector2(half * 2.0, half * 2.0)
	puddle.mesh = plane
	puddle.position = Vector3(0.0, 0.035, 0.0)
	pivot.add_child(puddle)

	var tex: Texture2D = _load_stain_tex(PATH_SLIME)
	var tint := Color(1, 1, 1, 1)
	match prop_id:
		"wet":
			tex = _load_stain_tex(PATH_WET)
			tint = Color(0.85, 0.95, 1.0, 1.0)
		"slime", "boss_slime":
			tex = _load_stain_tex(PATH_SLIME)
			tint = Color(0.9, 1.0, 0.85, 1.0)
		"potion":
			tex = _load_stain_tex(PATH_SLIME)
			tint = Color(0.95, 0.55, 1.0, 1.0)
		_:
			tex = _load_stain_tex(PATH_WET)
			tint = color
	if tex == null:
		# Geçici düz renk fallback — import bitmeden parse kırılmasın
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(color.r, color.g, color.b, 0.75)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puddle.material_override = mat
		root.liquid_wipe = false
		root.requires_scrub = true
	else:
		root.setup_liquid_wipe(puddle, tex, half, tint)

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
	req_tool: String = "",
	vacuumable: bool = false,
	vacuum_resist: float = 1.0,
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
	root.required_tool = req_tool
	root.vacuumable = vacuumable
	root.vacuum_resist = vacuum_resist
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
	var use_sphere := prop_id.find("slime") >= 0 or prop_id == "mold" or prop_id == "wet" or prop_id == "dust"
	var mesh: Mesh
	if use_sphere:
		var sphere := SphereMesh.new()
		sphere.radius = 0.32 if prop_id != "dust" else 0.26
		sphere.height = 0.55 if prop_id != "dust" else 0.42
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
		sph.radius = 0.30 if prop_id != "dust" else 0.24
		shape.shape = sph
	else:
		var box := BoxShape3D.new()
		var mesh_size: Vector3 = (mesh as BoxMesh).size
		box.size = mesh_size * 0.9
		shape.shape = box
	shape.position = mesh_inst.position
	body.add_child(shape)

	if hidden:
		root.react_triggered.connect(func() -> void:
			if is_instance_valid(mesh_inst):
				mesh_inst.transparency = 0.0
		)

	if vacuumable:
		var tag := Label3D.new()
		tag.text = "EM"
		tag.font_size = 36
		tag.modulate = Color(0.55, 0.9, 1.0)
		tag.position = Vector3(0.0, 0.62, 0.0)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pivot.add_child(tag)


## Kırıntı / toz — sadece süpürge ile Luigi tarzı emme.
func _add_vacuum_debris(
	pos: Vector3,
	prop_id: String,
	color: Color,
	scale_mul: float = 0.85,
	resist: float = 0.85,
) -> void:
	_add_blob(pos, prop_id, color, 0, false, "", scale_mul, false, "broom", true, resist)
	# Küçük kutu / top görseli crumb için box — dust sphere zaten use_sphere


func _load_stain_tex(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _add_box_stack(pos: Vector3, count: int, yaw: float, mesh_scale: Vector3 = Vector3.ONE) -> void:
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
	root.scale = mesh_scale
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

	var box_h := ClutterProp.BOX_LAYER_H
	var max_extent := 0.36
	for i in count:
		var pick: Dictionary = PropCatalog3D.pick_box(_rng, false)
		var xform: Dictionary = PropCatalog3D.roll_box_xform(_rng)
		var mesh_inst := MeshInstance3D.new()
		var layer_mesh := _make_box_layer_mesh(pick, xform, box_h)
		mesh_inst.mesh = layer_mesh
		mesh_inst.material_override = _make_box_material(pick, xform)
		_fit_prop_mesh(mesh_inst, Vector3(0.72, box_h, 0.72), pick.get("mesh") != null)
		var sj: Vector3 = xform.get("size_jitter", Vector3.ONE)
		var off: Vector3 = xform.get("offset", Vector3.ZERO)
		mesh_inst.position = Vector3(
			off.x + _rng.randf_range(-0.03, 0.03),
			box_h * 0.5 * sj.y + i * (box_h * 0.92),
			off.z + _rng.randf_range(-0.03, 0.03)
		)
		# GLB/OBJ kutular Blender’dan ters geliyor — stack’te 180° düzelt
		var flip_x := PI if pick.get("mesh") != null else 0.0
		mesh_inst.rotation = Vector3(
			flip_x + float(xform.get("tilt_x", 0.0)),
			float(xform.get("yaw", 0.0)) * 0.15 + _rng.randf_range(-0.1, 0.1),
			float(xform.get("tilt_z", 0.0))
		)
		var s := float(xform.get("scale", 1.0))
		mesh_inst.scale *= Vector3(s * sj.x, s * sj.y, s * sj.z)
		max_extent = maxf(max_extent, 0.36 * mesh_inst.scale.x)
		pivot.add_child(mesh_inst)
		root.register_wobble_mesh(mesh_inst)

	# Tek ayak izi — mesh tabanına yakın (görsel ↔ bump)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = max_extent
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

	var pick: Dictionary = PropCatalog3D.pick_box(_rng, fallen)
	var xform: Dictionary = PropCatalog3D.roll_box_xform(_rng)
	var mesh_inst := MeshInstance3D.new()
	var box_h := 0.48 if fallen else ClutterProp.BOX_LAYER_H
	mesh_inst.mesh = _make_box_layer_mesh(pick, xform, box_h, 0.78)
	mesh_inst.material_override = _make_box_material(pick, xform, fallen)
	_fit_prop_mesh(mesh_inst, Vector3(0.78, box_h, 0.78), pick.get("mesh") != null)
	var s := float(xform.get("scale", 1.0))
	var sj: Vector3 = xform.get("size_jitter", Vector3.ONE)
	mesh_inst.position = Vector3(0, (0.2 if fallen else 0.24) * sj.y, 0)
	mesh_inst.scale *= Vector3(s * sj.x, s * sj.y, s * sj.z)
	if pick.get("mesh") != null and not fallen and not bool(pick.get("fallen", false)):
		mesh_inst.rotation.x += PI
	pivot.add_child(mesh_inst)
	root.register_wobble_mesh(mesh_inst)

	if fallen or bool(pick.get("fallen", false)):
		pivot.rotation = Vector3(
			deg_to_rad(_rng.randf_range(70.0, 95.0)),
			float(xform.get("yaw", 0.0)),
			deg_to_rad(_rng.randf_range(-18.0, 18.0))
		)
	else:
		pivot.rotation = rot
		pivot.rotation.y += float(xform.get("yaw", 0.0)) * 0.35

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.72, box_h, 0.72) * mesh_inst.scale * 0.9
	shape.shape = box_shape
	shape.position = mesh_inst.position
	body.add_child(shape)


func _make_box_layer_mesh(
	pick: Dictionary,
	xform: Dictionary,
	box_h: float,
	base_xz: float = 0.72,
) -> Mesh:
	var custom: Mesh = pick.get("mesh") as Mesh
	if custom != null:
		return custom
	var mesh := BoxMesh.new()
	var sj: Vector3 = xform.get("size_jitter", Vector3.ONE)
	mesh.size = Vector3(base_xz * sj.x, box_h * sj.y, base_xz * sj.z)
	return mesh


func _make_box_material(
	pick: Dictionary,
	xform: Dictionary,
	fallen: bool = false,
) -> ShaderMaterial:
	var tex: Texture2D = pick.get("texture") as Texture2D
	var tint: Color = xform.get("tint", Color.WHITE)
	if fallen:
		tint = tint.darkened(0.08)
	if tex != null:
		return HitWobbleMaterial.create_textured(tex, tint, 0.94, 0.07)
	var base := Color(0.52, 0.42, 0.3) if fallen else Color(0.62, 0.5, 0.34)
	return HitWobbleMaterial.create(base * tint, 0.95, Color.BLACK, 0.0, 0.07)


## Blender OBJ/GLB ölçüleri oyun kutusu AABB’sine sığdır (sadece scale).
func _fit_prop_mesh(mi: MeshInstance3D, target: Vector3, is_custom: bool) -> void:
	if mi == null or mi.mesh == null or not is_custom:
		return
	var aabb := mi.mesh.get_aabb()
	var sz := aabb.size
	if sz.x < 0.001 or sz.y < 0.001 or sz.z < 0.001:
		return
	var uni := minf(target.x / sz.x, minf(target.y / sz.y, target.z / sz.z))
	mi.scale = Vector3.ONE * uni


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
	# Tutorial: herhangi / güçlü vuruş; sonra fırça
	if not bool(_level_spec.get("tutorial_level", false)):
		root.required_tool = "brush"
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
	box_shape.size = cab_mesh.size * Vector3(0.92, 0.92, 0.92)
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


func _add_wet_stain(pos: Vector3) -> void:
	_add_scrub_puddle(pos, "wet", Color(0.4, 0.7, 0.95), 2.4, 3.3, 1.28)


func _add_repair_tv(pos: Vector3, yaw: float) -> void:
	var root := ClutterPropScript.new()
	root.name = "RepairTV"
	root.prop_id = "tv_repair"
	root.idle_style = ClutterProp.IdleStyle.FLICKER
	root.hit_wobble_enabled = true
	root.hits_to_destroy = 0
	root.can_carry = false
	root.repair_taps_needed = 6
	root.required_tool = ""
	root.max_hit_distance = 3.6
	root.react_distance = 3.4
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
	cab_mesh.size = Vector3(1.05, 0.72, 0.42)
	cabinet.mesh = cab_mesh
	cabinet.material_override = HitWobbleMaterial.create(Color(0.28, 0.18, 0.14), 0.88, Color.BLACK, 0.0, 0.1)
	cabinet.position = Vector3(0, 0.36, 0)
	pivot.add_child(cabinet)
	root.register_wobble_mesh(cabinet)

	var screen := MeshInstance3D.new()
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.88, 0.52, 0.04)
	screen.mesh = screen_mesh
	screen.material_override = HitWobbleMaterial.create(
		Color(0.45, 0.12, 0.1), 0.4, Color(0.9, 0.35, 0.2), 0.35, 0.12)
	screen.position = Vector3(0, 0.36, 0.24)
	pivot.add_child(screen)
	root.register_wobble_mesh(screen)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.05, 0.72, 0.5)
	shape.shape = box
	shape.position = Vector3(0, 0.36, 0)
	body.add_child(shape)

	var tag := Label3D.new()
	tag.text = "TAMİR"
	tag.font_size = 48
	tag.modulate = Color(1.0, 0.75, 0.35)
	tag.position = Vector3(0.0, 1.15, 0.0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pivot.add_child(tag)


func _add_crooked_painting(force_wall: String = "") -> void:
	var on_back: bool
	if force_wall == "back":
		on_back = true
	elif force_wall == "left":
		on_back = false
	else:
		on_back = _rng.randf() > 0.45

	var root := ClutterPropScript.new()
	root.name = "Painting"
	root.prop_id = "painting"
	root.is_painting = true
	root.idle_style = ClutterProp.IdleStyle.NONE
	root.hit_wobble_enabled = false
	root.hits_to_destroy = 0
	root.can_carry = false
	root.repair_taps_needed = 4
	root.required_tool = ""
	root.max_hit_distance = 5.5
	root.react_distance = 4.5
	root.set_meta("objective", true)

	var pivot := Node3D.new()
	pivot.name = "Pivot"
	root.add_child(pivot)

	var body := StaticBody3D.new()
	body.collision_layer = PROP_MASK
	body.collision_mask = 0
	pivot.add_child(body)

	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(1.6, 1.15, 0.1)
	frame.mesh = frame_mesh
	frame.material_override = HitWobbleMaterial.create(
		Color(0.55, 0.32, 0.14), 0.9, Color(0.9, 0.55, 0.2), 0.35, 0.02, true, 0.025
	)
	pivot.add_child(frame)

	var canvas := MeshInstance3D.new()
	var canvas_mesh := BoxMesh.new()
	canvas_mesh.size = Vector3(1.35, 0.95, 0.05)
	canvas.mesh = canvas_mesh
	var hues := [
		Color(0.95, 0.45, 0.35), Color(0.35, 0.7, 0.95), Color(0.55, 0.9, 0.4), Color(0.9, 0.55, 0.95)
	]
	var col: Color = hues[_rng.randi_range(0, hues.size() - 1)]
	canvas.material_override = HitWobbleMaterial.create(
		col, 0.85, col.lightened(0.2), 0.55, 0.02, true, 0.02
	)
	canvas.position = Vector3(0, 0, 0.08)
	pivot.add_child(canvas)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.15, 0.35)
	shape.shape = box
	body.add_child(shape)

	var tilt := deg_to_rad(_rng.randf_range(14.0, 28.0) * (1.0 if _rng.randf() > 0.5 else -1.0))
	pivot.rotation.z = tilt

	var tag := Label3D.new()
	tag.text = "YAMUK"
	tag.font_size = 72
	tag.modulate = Color(1.0, 0.9, 0.25)
	tag.outline_size = 10
	tag.outline_modulate = Color(0, 0, 0, 0.95)
	tag.position = Vector3(0.0, 0.85, 0.2)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	pivot.add_child(tag)

	# Odaya doğru yerleştir (duvarın iç yüzü)
	var hx := _layout.half_x() if _layout != null else 8.5
	var hz := _layout.half_z() if _layout != null else 6.0
	if on_back:
		root.position = Vector3(_rng.randf_range(-hx * 0.55, hx * 0.55), 1.85, -hz + 0.35)
		root.rotation.y = 0.0
	else:
		root.position = Vector3(-hx + 0.35, 1.85, _rng.randf_range(-hz * 0.55, hz * 0.55))
		root.rotation.y = deg_to_rad(-90.0)

	add_child(root)
	root.call_deferred("_cache_painting_tilt")
