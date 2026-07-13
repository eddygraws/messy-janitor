class_name RoomSpawnBounds
extends RefCounted

## 1920×1080 izometrik oda: kirler yalnızca zemin + duvar yüzeylerinde.

const VIEWPORT := Vector2i(1920, 1080)
const MIN_DIST := 165.0
const DRAIN_POS := Vector2(430, 748)
const TRASH_POS := Vector2(1450, 748)


static func random_point(placed: Array[Vector2], min_dist: float = MIN_DIST, max_tries: int = 28) -> Vector2:
	for _try in max_tries:
		var p := _random_on_surface()
		if _is_clear(p, placed, min_dist):
			return p
	return _random_on_surface()


static func random_near(
	origin: Vector2,
	radius: Vector2,
	placed: Array[Vector2],
	min_dist: float = 120.0,
	max_tries: int = 14,
) -> Vector2:
	for _try in max_tries:
		var offset := Vector2(randf_range(-radius.x, radius.x), randf_range(-radius.y, radius.y))
		var p := origin + offset
		if is_on_surface(p) and _is_clear(p, placed, min_dist):
			return p
	return Vector2.INF


static func is_on_surface(p: Vector2) -> bool:
	for entry in _surfaces():
		if Geometry2D.is_point_in_polygon(p, entry["poly"]):
			return true
	return false


static func depth_z(y: float) -> int:
	return clampi(int(y), 1, 900)


static func add_isometric_shell(room: Node2D, floor_color: Color = Color(0.58, 0.64, 0.62)) -> void:
	var void_bg := Polygon2D.new()
	void_bg.color = Color(0.02, 0.02, 0.03)
	void_bg.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(VIEWPORT.x, 0),
		Vector2(VIEWPORT), Vector2(0, VIEWPORT.y),
	])
	void_bg.z_index = -20
	room.add_child(void_bg)

	var left_wall := Polygon2D.new()
	left_wall.color = Color(0.76, 0.8, 0.86)
	left_wall.polygon = _left_wall_poly()
	left_wall.z_index = -8
	room.add_child(left_wall)

	var right_wall := Polygon2D.new()
	right_wall.color = Color(0.72, 0.76, 0.84)
	right_wall.polygon = _right_wall_poly()
	right_wall.z_index = -7
	room.add_child(right_wall)

	var floor_poly := Polygon2D.new()
	floor_poly.color = floor_color
	floor_poly.polygon = _floor_poly()
	floor_poly.z_index = -6
	room.add_child(floor_poly)

	_add_room_props(room)


static func _floor_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(512, 448),
		Vector2(1408, 448),
		Vector2(1568, 836),
		Vector2(352, 836),
	])


static func _left_wall_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(960, 248),
		Vector2(488, 372),
		Vector2(352, 836),
		Vector2(512, 448),
	])


static func _right_wall_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(960, 248),
		Vector2(1432, 372),
		Vector2(1568, 836),
		Vector2(1408, 448),
	])


static func _surfaces() -> Array:
	return [
		{"poly": _floor_poly(), "weight": 0.74},
		{"poly": _left_wall_poly(), "weight": 0.13},
		{"poly": _right_wall_poly(), "weight": 0.13},
	]


static func _add_room_props(room: Node2D) -> void:
	var shelf := Polygon2D.new()
	shelf.color = Color(0.62, 0.22, 0.18)
	shelf.polygon = PackedVector2Array([
		Vector2(548, 468), Vector2(612, 448), Vector2(618, 760), Vector2(554, 780),
	])
	shelf.z_index = 40
	room.add_child(shelf)

	for y in [500, 580, 660, 740]:
		var plank := Polygon2D.new()
		plank.color = Color(0.52, 0.18, 0.14)
		plank.polygon = PackedVector2Array([
			Vector2(548, y), Vector2(612, y - 14), Vector2(612, y - 4), Vector2(548, y + 10),
		])
		plank.z_index = 41
		room.add_child(plank)

	var door := Polygon2D.new()
	door.color = Color(0.18, 0.28, 0.48)
	door.polygon = PackedVector2Array([
		Vector2(1180, 468), Vector2(1360, 420), Vector2(1360, 760), Vector2(1180, 808),
	])
	door.z_index = 40
	room.add_child(door)

	for i in 6:
		var slat_y := 500 + i * 42
		var slat := Polygon2D.new()
		slat.color = Color(0.14, 0.22, 0.4)
		slat.polygon = PackedVector2Array([
			Vector2(1190, slat_y), Vector2(1350, slat_y - 10),
			Vector2(1350, slat_y + 6), Vector2(1190, slat_y + 16),
		])
		slat.z_index = 41
		room.add_child(slat)


static func _random_on_surface() -> Vector2:
	var roll := randf()
	var acc := 0.0
	for entry in _surfaces():
		acc += float(entry["weight"])
		if roll <= acc:
			return _random_in_polygon(entry["poly"])
	return _random_in_polygon(_floor_poly())


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
	return _polygon_centroid(poly)


static func _polygon_centroid(poly: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / float(poly.size())


static func _is_clear(p: Vector2, placed: Array[Vector2], min_dist: float) -> bool:
	for q in placed:
		if p.distance_to(q) < min_dist:
			return false
	return true
