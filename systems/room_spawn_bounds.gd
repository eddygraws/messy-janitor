class_name RoomSpawnBounds
extends RefCounted

## Oda arkaplanı + alpha mask: kirler yalnızca opak yüzeylerde spawn olur.

const VIEWPORT := Vector2i(1920, 1080)
const MIN_DIST := 165.0
const DRAIN_POS := Vector2(720, 740)
const TRASH_POS := Vector2(1180, 740)
const BACKGROUND_PATH := "res://assets/potion-shop.png"
const ALPHA_THRESHOLD := 0.35
## Siyah void (alpha yoksa bile) — stain yok.
const VOID_LUMA_MAX := 0.12

static var _mask: Image = null
static var _mask_size: Vector2i = Vector2i.ZERO
static var _opaque_cache: PackedVector2Array = PackedVector2Array()


static func random_point(placed: Array[Vector2], min_dist: float = MIN_DIST, max_tries: int = 40) -> Vector2:
	_ensure_mask()
	for _try in max_tries:
		var p := _random_opaque_point()
		if _is_clear(p, placed, min_dist) and is_on_surface(p):
			return p
	return _random_opaque_point()


static func random_near(
	origin: Vector2,
	radius: Vector2,
	placed: Array[Vector2],
	min_dist: float = 120.0,
	max_tries: int = 18,
) -> Vector2:
	_ensure_mask()
	for _try in max_tries:
		var offset := Vector2(randf_range(-radius.x, radius.x), randf_range(-radius.y, radius.y))
		var p := origin + offset
		if is_on_surface(p) and _is_clear(p, placed, min_dist):
			return p
	return Vector2.INF


static func is_on_surface(p: Vector2) -> bool:
	_ensure_mask()
	if p.x < 0.0 or p.y < 0.0 or p.x >= VIEWPORT.x or p.y >= VIEWPORT.y:
		return false
	if _mask == null:
		return _legacy_polygon_surface(p)
	var px := _world_to_mask(p)
	if px.x < 0 or px.y < 0 or px.x >= _mask_size.x or px.y >= _mask_size.y:
		return false
	var c := _mask.get_pixel(px.x, px.y)
	# Şeffaf veya siyah void — stain yok
	if c.a < ALPHA_THRESHOLD:
		return false
	var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	return luma > VOID_LUMA_MAX


static func snap_to_surface(preferred: Vector2) -> Vector2:
	_ensure_mask()
	if is_on_surface(preferred):
		return preferred
	if _opaque_cache.is_empty():
		return preferred
	var best := preferred
	var best_d := INF
	for p in _opaque_cache:
		var d := preferred.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = p
	return best


static func depth_z(y: float) -> int:
	return clampi(int((y / 1080.0) * 7.0) + 1, 1, 8)


static func add_isometric_shell(room: Node2D, _floor_color: Color = Color(0.58, 0.64, 0.62)) -> void:
	_ensure_mask()

	var void_bg := Polygon2D.new()
	void_bg.color = Color(0.0, 0.0, 0.0)
	void_bg.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(VIEWPORT.x, 0),
		Vector2(VIEWPORT), Vector2(0, VIEWPORT.y),
	])
	void_bg.z_index = -20
	room.add_child(void_bg)

	if ResourceLoader.exists(BACKGROUND_PATH):
		var tex := load(BACKGROUND_PATH) as Texture2D
		if tex != null:
			var spr := Sprite2D.new()
			spr.name = "RoomBackground"
			spr.texture = tex
			spr.centered = false
			spr.position = Vector2.ZERO
			# Viewport'a sığdır
			var tex_size := tex.get_size()
			if tex_size.x > 0.0 and tex_size.y > 0.0:
				spr.scale = Vector2(VIEWPORT.x / tex_size.x, VIEWPORT.y / tex_size.y)
			spr.z_index = -10
			room.add_child(spr)
			return

	# Fallback: eski izometrik poligon kabuk
	_add_legacy_shell(room, _floor_color)


static func _add_legacy_shell(room: Node2D, floor_color: Color) -> void:
	var left_wall := Polygon2D.new()
	left_wall.color = Color(0.76, 0.8, 0.86)
	left_wall.polygon = PackedVector2Array([
		Vector2(960, 248), Vector2(488, 372), Vector2(352, 836), Vector2(512, 448),
	])
	left_wall.z_index = -8
	room.add_child(left_wall)

	var right_wall := Polygon2D.new()
	right_wall.color = Color(0.72, 0.76, 0.84)
	right_wall.polygon = PackedVector2Array([
		Vector2(960, 248), Vector2(1432, 372), Vector2(1568, 836), Vector2(1408, 448),
	])
	right_wall.z_index = -7
	room.add_child(right_wall)

	var floor_poly := Polygon2D.new()
	floor_poly.color = floor_color
	floor_poly.polygon = _floor_poly()
	floor_poly.z_index = -6
	room.add_child(floor_poly)


static func _ensure_mask() -> void:
	if _mask != null:
		return
	if not ResourceLoader.exists(BACKGROUND_PATH):
		return
	var tex := load(BACKGROUND_PATH) as Texture2D
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		img = Image.new()
		if img.load(BACKGROUND_PATH) != OK:
			push_warning("RoomSpawnBounds: potion-shop mask yüklenemedi")
			return
	if img.is_compressed():
		img.decompress()
	_mask = img.duplicate()
	_mask_size = Vector2i(_mask.get_width(), _mask.get_height())
	_build_opaque_cache()


static func _build_opaque_cache() -> void:
	_opaque_cache = PackedVector2Array()
	if _mask == null:
		return
	# Her 8 px örnekle — spawn havuzu
	var step := 8
	for y in range(0, _mask_size.y, step):
		for x in range(0, _mask_size.x, step):
			var c := _mask.get_pixel(x, y)
			if c.a < ALPHA_THRESHOLD:
				continue
			var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			if luma <= VOID_LUMA_MAX:
				continue
			var world := _mask_to_world(Vector2i(x, y))
			_opaque_cache.append(world)


static func _random_opaque_point() -> Vector2:
	if _opaque_cache.size() > 0:
		var base: Vector2 = _opaque_cache[randi() % _opaque_cache.size()]
		# Küçük jitter; alpha kontrolünden geçerse kalsın
		for _j in 6:
			var jittered := base + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
			if is_on_surface(jittered):
				return jittered
		return base
	# Fallback polygon
	return _random_in_polygon(_floor_poly())


static func _world_to_mask(p: Vector2) -> Vector2i:
	if _mask_size.x <= 0 or _mask_size.y <= 0:
		return Vector2i(-1, -1)
	return Vector2i(
		clampi(int(p.x / float(VIEWPORT.x) * _mask_size.x), 0, _mask_size.x - 1),
		clampi(int(p.y / float(VIEWPORT.y) * _mask_size.y), 0, _mask_size.y - 1)
	)


static func _mask_to_world(px: Vector2i) -> Vector2:
	return Vector2(
		(float(px.x) + 0.5) / float(_mask_size.x) * VIEWPORT.x,
		(float(px.y) + 0.5) / float(_mask_size.y) * VIEWPORT.y
	)


static func _legacy_polygon_surface(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, _floor_poly()) \
		or Geometry2D.is_point_in_polygon(p, PackedVector2Array([
			Vector2(960, 248), Vector2(488, 372), Vector2(352, 836), Vector2(512, 448),
		])) \
		or Geometry2D.is_point_in_polygon(p, PackedVector2Array([
			Vector2(960, 248), Vector2(1432, 372), Vector2(1568, 836), Vector2(1408, 448),
		]))


static func _floor_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(512, 448),
		Vector2(1408, 448),
		Vector2(1568, 836),
		Vector2(352, 836),
	])


static func _random_in_polygon(poly: PackedVector2Array) -> Vector2:
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for p in poly:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	for _i in 48:
		var candidate := Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
		if Geometry2D.is_point_in_polygon(candidate, poly):
			return candidate
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / float(poly.size())


static func _is_clear(p: Vector2, placed: Array[Vector2], min_dist: float) -> bool:
	for q in placed:
		if p.distance_to(q) < min_dist:
			return false
	return true
