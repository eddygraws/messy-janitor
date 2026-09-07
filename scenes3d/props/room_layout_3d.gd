class_name RoomLayout3D
extends Node3D

## Seviye başına harita boyutu / şekil çeşitliliği (tezgâh labirenti değil).
## Ana yapı: dikdörtgen zemin + istasyonlar önde; tema skin + footprint değişir.

const PerfBudget := preload("res://systems/perf_budget_3d.gd")

signal layout_applied(theme_id: String)
signal footprint_changed(half_x: float, half_z: float)

const WALL_MASK := 1

## theme_id → footprint
const FOOTPRINTS: Dictionary = {
	"garage": {"half_x": 8.5, "half_z": 6.0, "shape": "rect"},
	"liquids": {"half_x": 9.5, "half_z": 5.4, "shape": "wide"},
	"mold": {"half_x": 7.4, "half_z": 7.2, "shape": "deep"},
	"broom": {"half_x": 10.2, "half_z": 5.2, "shape": "wide"},
	"slime": {"half_x": 8.0, "half_z": 6.6, "shape": "rect"},
	"brush": {"half_x": 7.8, "half_z": 6.0, "shape": "compact"},
	"spray": {"half_x": 9.0, "half_z": 6.8, "shape": "rect"},
	"alien": {"half_x": 9.2, "half_z": 6.4, "shape": "rect"},
	"tweezers": {"half_x": 8.2, "half_z": 5.8, "shape": "rect"},
	"dark": {"half_x": 7.0, "half_z": 5.5, "shape": "compact"},
	"ritual": {"half_x": 8.8, "half_z": 7.0, "shape": "deep"},
	"finale": {"half_x": 11.0, "half_z": 7.6, "shape": "arena"},
}

var _decor_root: Node3D
var _obstacle_root: Node3D
var _outside_ground: MeshInstance3D
var _theme_id: String = "garage"
var _palette: Dictionary = {}
var _half_x: float = 8.5
var _half_z: float = 6.0
var _shape: String = "rect"
var _spawn_zones: Array[Rect2] = []
var _outdoor: bool = false


func _ready() -> void:
	name = "RoomLayout"
	_obstacle_root = Node3D.new()
	_obstacle_root.name = "MapObstacles"
	add_child(_obstacle_root)
	_decor_root = Node3D.new()
	_decor_root.name = "ThemeDecor"
	add_child(_decor_root)
	_outside_ground = MeshInstance3D.new()
	_outside_ground.name = "OutsideGround"
	add_child(_outside_ground)
	_apply_footprint_defaults("garage")


func half_x() -> float:
	return _half_x


func half_z() -> float:
	return _half_z


func station_trash() -> Vector3:
	return Vector3(0.0, 0.0, _half_z - 0.55)


func station_bucket() -> Vector3:
	return Vector3(-_half_x * 0.48, 0.0, _half_z - 0.7)


func station_drain() -> Vector3:
	return Vector3(_half_x * 0.48, 0.0, _half_z - 0.7)


func player_spawn() -> Vector3:
	return Vector3(0.0, 0.9, _half_z * 0.28)


## Geriye uyumluluk — static çağrılar eski sabitleri kullanmasın diye instance tercih edilir.
static func station_trash_default() -> Vector3:
	return Vector3(0.0, 0.0, 5.45)


static func station_bucket_default() -> Vector3:
	return Vector3(-4.35, 0.0, 5.25)


static func station_drain_default() -> Vector3:
	return Vector3(4.35, 0.0, 5.25)


static func player_spawn_default() -> Vector3:
	return Vector3(0.0, 0.9, 2.35)


func apply_spec(spec: Dictionary) -> void:
	_theme_id = _theme_key(spec)
	_outdoor = _outdoor_from_spec(spec)
	_palette = _palette_for(_theme_id, spec)
	_apply_footprint_defaults(_theme_id)
	# LevelData override
	if spec.has("map_half_x"):
		_half_x = float(spec.get("map_half_x"))
	if spec.has("map_half_z"):
		_half_z = float(spec.get("map_half_z"))
	if spec.has("map_shape"):
		_shape = String(spec.get("map_shape"))
	_rebuild_spawn_zones()
	_rebuild_light_obstacles()
	_rebuild_theme_decor()
	footprint_changed.emit(_half_x, _half_z)
	layout_applied.emit(_theme_id)


func is_outdoor() -> bool:
	return _outdoor


func _outdoor_from_spec(spec: Dictionary) -> bool:
	if bool(spec.get("tutorial_level", false)):
		return false
	if spec.has("outdoor"):
		return bool(spec.get("outdoor"))
	return _theme_id == "slime"


func get_theme_id() -> String:
	return _theme_id


func get_blocked_anchors() -> Array:
	var out: Array = []
	out.append({"pos": station_trash(), "clear": 1.5})
	out.append({"pos": station_bucket(), "clear": 1.45})
	out.append({"pos": station_drain(), "clear": 1.45})
	out.append({"pos": player_spawn() * Vector3(1, 0, 1), "clear": 1.5})
	return out


func random_spawn_point(rng: RandomNumberGenerator) -> Vector3:
	if _spawn_zones.is_empty():
		return Vector3(
			rng.randf_range(-_half_x * 0.7, _half_x * 0.7),
			0.0,
			rng.randf_range(-_half_z * 0.55, _half_z * 0.35)
		)
	var zone: Rect2 = _spawn_zones[rng.randi() % _spawn_zones.size()]
	return Vector3(
		rng.randf_range(zone.position.x, zone.position.x + zone.size.x),
		0.0,
		rng.randf_range(zone.position.y, zone.position.y + zone.size.y)
	)


func is_in_spawn_zone(p: Vector3) -> bool:
	var xz := Vector2(p.x, p.z)
	for z in _spawn_zones:
		if z.has_point(xz):
			return true
	return false


func _apply_footprint_defaults(theme_id: String) -> void:
	var fp: Dictionary = FOOTPRINTS.get(theme_id, FOOTPRINTS["garage"]) as Dictionary
	_half_x = float(fp.get("half_x", 8.5))
	_half_z = float(fp.get("half_z", 6.0))
	_shape = String(fp.get("shape", "rect"))


func _rebuild_spawn_zones() -> void:
	_spawn_zones.clear()
	var mx := _half_x * 0.78
	var mz := _half_z * 0.72
	match _shape:
		"wide":
			_spawn_zones.append(Rect2(-mx, -mz * 0.35, mx * 2.0, mz * 0.85))
			_spawn_zones.append(Rect2(-mx, mz * 0.15, mx * 0.55, mz * 0.45))
			_spawn_zones.append(Rect2(mx * 0.35, mz * 0.15, mx * 0.55, mz * 0.45))
		"deep":
			_spawn_zones.append(Rect2(-mx * 0.7, -mz, mx * 1.4, mz * 1.55))
			_spawn_zones.append(Rect2(-mx, -mz * 0.2, mx * 0.5, mz * 0.7))
			_spawn_zones.append(Rect2(mx * 0.4, -mz * 0.2, mx * 0.5, mz * 0.7))
		"compact":
			_spawn_zones.append(Rect2(-mx * 0.85, -mz * 0.7, mx * 1.7, mz * 1.2))
		"arena":
			_spawn_zones.append(Rect2(-mx * 0.9, -mz * 0.85, mx * 1.8, mz * 1.4))
			_spawn_zones.append(Rect2(-mx, mz * 0.2, mx * 0.45, mz * 0.4))
			_spawn_zones.append(Rect2(mx * 0.45, mz * 0.2, mx * 0.45, mz * 0.4))
		_:
			_spawn_zones.append(Rect2(-mx * 0.55, -mz * 0.5, mx * 1.1, mz * 1.05))
			_spawn_zones.append(Rect2(-mx, mz * 0.05, mx * 0.5, mz * 0.5))
			_spawn_zones.append(Rect2(mx * 0.4, mz * 0.05, mx * 0.5, mz * 0.5))
			_spawn_zones.append(Rect2(-mx * 0.9, -mz, mx * 0.45, mz * 0.55))
			_spawn_zones.append(Rect2(mx * 0.4, -mz, mx * 0.45, mz * 0.55))


func _rebuild_light_obstacles() -> void:
	## Oyun alanı İÇİNDE engel yok — karışıklık yaratmasın
	for c in _obstacle_root.get_children():
		c.queue_free()


func _add_block(pos: Vector3, size: Vector3, col: Color, clear_r: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = WALL_MASK
	body.collision_mask = 0
	body.position = pos
	body.set_meta("clear_r", clear_r)
	_obstacle_root.add_child(body)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = HitWobbleMaterial.create(col, 0.9, Color.BLACK, 0.0, 0.02, true, 0.024)
	mi.position.y = size.y * 0.5
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = size
	shape.shape = cs
	shape.position.y = size.y * 0.5
	body.add_child(shape)


func _theme_key(spec: Dictionary) -> String:
	if spec.has("room_theme") and String(spec.get("room_theme")) != "":
		return String(spec.get("room_theme"))
	var id := String(spec.get("id", ""))
	var t_at := id.find("_t")
	if t_at > 0:
		id = id.substr(0, t_at)
	if id.is_empty() or bool(spec.get("tutorial_level", false)):
		return "garage"
	return id


func _palette_for(theme_id: String, spec: Dictionary) -> Dictionary:
	var accent: Color = spec.get("accent", Color(0.7, 0.55, 0.35)) as Color
	var base := {
		"prop_a": Color(0.5, 0.42, 0.32),
		"prop_b": Color(0.35, 0.32, 0.28),
		"trim": accent,
	}
	match theme_id:
		"liquids", "garage":
			base["prop_a"] = Color(0.45, 0.5, 0.55)
		"mold":
			base["prop_a"] = Color(0.35, 0.55, 0.32)
			base["prop_b"] = Color(0.22, 0.3, 0.2)
		"broom":
			base["prop_a"] = Color(0.55, 0.4, 0.25)
		"slime":
			base["prop_a"] = Color(0.3, 0.7, 0.55)
		"brush":
			base["prop_a"] = Color(0.65, 0.4, 0.75)
		"spray":
			base["prop_a"] = Color(0.45, 0.7, 0.95)
		"alien":
			base["prop_a"] = Color(0.35, 0.75, 0.4)
			base["prop_b"] = Color(0.2, 0.35, 0.25)
		"tweezers":
			base["prop_a"] = Color(0.85, 0.75, 0.45)
		"dark":
			base["prop_a"] = Color(0.35, 0.4, 0.55)
		"ritual":
			base["prop_a"] = Color(0.7, 0.35, 0.45)
		"finale":
			base["prop_a"] = Color(0.9, 0.4, 0.25)
	return base


func _rebuild_theme_decor() -> void:
	for c in _decor_root.get_children():
		c.queue_free()
	var a: Color = _palette.get("prop_a", Color(0.5, 0.4, 0.3))
	var b: Color = _palette.get("prop_b", Color(0.35, 0.32, 0.28))
	_rebuild_outside_ground(a)
	# Sadece OYUN ALANI DIŞI — içerisi temiz kalsın
	_fill_outside_void(a, b)


func _rebuild_outside_ground(col: Color) -> void:
	## Kamera frustum’unu kaplayan apron — gökyüzü sızmasın
	if _outside_ground == null:
		return
	var pad := 28.0
	var gw := (_half_x + pad) * 2.0
	var gd := (_half_z + pad) * 2.0
	var box := BoxMesh.new()
	box.size = Vector3(gw, 0.14, gd)
	_outside_ground.mesh = box
	_outside_ground.position = Vector3(0.0, -0.18, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _outside_ground_color(col)
	mat.roughness = 0.96
	_outside_ground.material_override = mat
	_outside_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func outside_ground_color() -> Color:
	var a: Color = _palette.get("prop_a", Color(0.45, 0.4, 0.35))
	return _outside_ground_color(a)


func _outside_ground_color(col: Color) -> Color:
	if _outdoor:
		return col.darkened(0.28).lerp(Color(0.14, 0.28, 0.12), 0.72)
	return col.darkened(0.42).lerp(Color(0.16, 0.15, 0.14), 0.55)


func _fill_outside_void(col_a: Color, col_b: Color) -> void:
	## Optimize: Multimesh + az sayıda unique prop. Gökyüzü görünmesin.
	PropCatalog3D.refresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_theme_id) * 7919 + roundi(_half_x * 10.0) + roundi(_half_z * 17.0)

	var pad_near := 0.85
	var pad_far := 22.0
	var spot_n := PerfBudget.OUTDOOR_SCATTER_SPOTS if _outdoor else 72
	var rock_n := PerfBudget.MAX_OUTSKIRT_ROCKS if _outdoor else 38
	var spots := _scatter_outside_spots(rng, pad_near, pad_far, spot_n)
	_spawn_outskirt_multimesh_rocks(spots, rng, rock_n)
	if _outdoor:
		var leaf_tint: Color = Color(0.32, 0.58, 0.18).lerp(col_a, 0.28)
		var grass_tint: Color = Color(0.14, 0.58, 0.20).lerp(col_a, 0.22)
		ForestVegetation.fill_level_outskirts(_decor_root, _half_x, _half_z, 0.0, rng, leaf_tint, grass_tint)
		return
	_spawn_outskirt_multimesh_boxes(spots, rng, 28, col_a)
	var near_spots := _scatter_outside_spots(rng, pad_near, 3.8, 14)
	for i in near_spots.size():
		var p: Vector3 = near_spots[i]
		var col := col_a if (i % 2) == 0 else col_b
		if i % 3 == 0:
			_spawn_barrel(p, col)
		else:
			_spawn_crate(p, col)


func _scatter_outside_spots(
	rng: RandomNumberGenerator,
	pad_near: float,
	pad_far: float,
	count: int,
) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var tries := 0
	while out.size() < count and tries < count * 8:
		tries += 1
		# Ring örnekleme: açı + yarıçap
		var ang := rng.randf() * TAU
		# Daha çok yakın halkaya yığ (görünür alan), dışa seyrek
		var t := rng.randf()
		t = t * t ## bias yakın
		var dist := lerpf(pad_near, pad_far, t)
		# Dikdörtgen oda dışına projekte et
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		# Oda kenarına kadar git, sonra dist kadar dışarı
		var edge := _point_on_rect_edge(dir)
		var p := edge + dir * dist
		p.x += rng.randf_range(-0.35, 0.35)
		p.z += rng.randf_range(-0.35, 0.35)
		if absf(p.x) <= _half_x + pad_near * 0.5 and absf(p.z) <= _half_z + pad_near * 0.5:
			continue
		out.append(p)
	return out


func _point_on_rect_edge(dir: Vector3) -> Vector3:
	var d := dir
	d.y = 0.0
	if d.length_squared() < 0.0001:
		d = Vector3(1, 0, 0)
	d = d.normalized()
	var tx := INF if absf(d.x) < 0.001 else _half_x / absf(d.x)
	var tz := INF if absf(d.z) < 0.001 else _half_z / absf(d.z)
	var t := minf(tx, tz)
	return d * t


func _spawn_outskirt_multimesh_rocks(spots: Array[Vector3], rng: RandomNumberGenerator, max_n: int) -> void:
	var pick: Dictionary = PropCatalog3D.pick_rock(rng)
	var mesh: Mesh = pick.get("mesh") as Mesh
	var tex: Texture2D = pick.get("texture") as Texture2D
	if mesh == null:
		return
	var n := mini(max_n, spots.size())
	if n <= 0:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = n
	var aabb := mesh.get_aabb()
	var base := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var uni0 := 0.7 / maxf(base, 0.001)
	for i in n:
		var p: Vector3 = spots[i % spots.size()]
		# Spot’ları kaydır — aynı noktaya yığılma azalsın
		if i >= spots.size():
			p += Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
		var sc := uni0 * rng.randf_range(0.75, 1.45)
		var xf := Transform3D.IDENTITY
		xf = xf.scaled(Vector3(sc * rng.randf_range(0.9, 1.25), sc * rng.randf_range(0.55, 0.9), sc * rng.randf_range(0.9, 1.25)))
		xf = xf.rotated(Vector3.UP, rng.randf() * TAU)
		xf = xf.rotated(Vector3.RIGHT, rng.randf_range(-0.15, 0.15))
		xf.origin = Vector3(p.x, 0.02, p.z)
		mm.set_instance_transform(i, xf)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _mat_tex(Color.WHITE, tex) if tex != null else _mat(Color(0.45, 0.43, 0.4))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_decor_root.add_child(mi)


func _spawn_outskirt_multimesh_boxes(
	spots: Array[Vector3],
	rng: RandomNumberGenerator,
	max_n: int,
	col: Color,
) -> void:
	var pick: Dictionary = PropCatalog3D.pick_box(rng, false)
	var mesh: Mesh = pick.get("mesh") as Mesh
	var tex: Texture2D = pick.get("texture") as Texture2D
	if mesh == null:
		return
	var flip := true
	var n := mini(max_n, maxi(1, spots.size() - 8))
	if n <= 0:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = n
	var aabb := mesh.get_aabb()
	var base := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var uni0 := 0.72 / maxf(base, 0.001)
	var start := mini(8, spots.size())
	for i in n:
		var idx := (start + i * 2) % spots.size()
		var p: Vector3 = spots[idx]
		p += Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		var sc := uni0 * rng.randf_range(0.85, 1.2)
		var xf := Transform3D.IDENTITY
		xf = xf.scaled(Vector3(sc, sc, sc))
		if flip:
			xf = xf.rotated(Vector3.RIGHT, PI)
		xf = xf.rotated(Vector3.UP, rng.randf() * TAU)
		xf.origin = Vector3(p.x, aabb.size.y * sc * 0.5, p.z)
		mm.set_instance_transform(i, xf)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _mat_tex(Color.WHITE, tex) if tex != null else _mat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_decor_root.add_child(mi)


func _outside_depth(p: Vector3) -> float:
	var dx := maxf(0.0, absf(p.x) - _half_x)
	var dz := maxf(0.0, absf(p.z) - _half_z)
	return maxf(dx, dz)


func _mat(col: Color) -> ShaderMaterial:
	return PixelArtMaterial.create_color(col)


func _mat_tex(col: Color, tex: Texture2D) -> ShaderMaterial:
	return PixelArtMaterial.create_textured(tex, col)


func _spawn_barrel(pos: Vector3, col: Color, _unused: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.38
	cyl.bottom_radius = 0.42
	cyl.height = 0.85
	cyl.radial_segments = 10
	mi.mesh = cyl
	mi.material_override = _mat(col)
	mi.position = pos + Vector3(0, 0.42, 0)
	mi.rotation.y = randf_range(-0.4, 0.4)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_decor_root.add_child(mi)


func _spawn_crate(pos: Vector3, col: Color, _unused: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.55, 0.7)
	mi.mesh = box
	mi.material_override = _mat(col)
	mi.position = pos + Vector3(0, 0.28, 0)
	mi.rotation.y = deg_to_rad(randf_range(-25.0, 25.0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_decor_root.add_child(mi)
