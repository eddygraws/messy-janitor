class_name RoomSpawnBounds
extends RefCounted

## Oda arkaplanı + alpha mask: kirler yalnızca opak yüzeylerde spawn olur.
## Katman: arcade karo shader (en arka) → contact shadow → custom oda sprite.

const VIEWPORT := Vector2i(1920, 1080)
const MIN_DIST := 280.0
const DRAIN_POS := Vector2(720, 740)
const TRASH_POS := Vector2(1180, 740)
const BACKGROUND_PATH := "res://assets/potion-shop.png"
const GARAGE_BACKGROUND_PATH := "res://assets/garage-background.png"
const ARCADE_SHADER := preload("res://shaders/arcade_tile_bg.gdshader")
const SHADOW_SHADER := preload("res://shaders/room_contact_shadow.gdshader")
const ALPHA_THRESHOLD := 0.35
const VOID_LUMA_MAX := 0.12

## HUD altında leke spawn olmasın (ekran uzayı, 1920x1080).
const UI_BLOCK_ZONES: Array[Rect2] = [
	Rect2(0, 0, 360, 170),
	Rect2(600, 0, 720, 100),
	Rect2(1540, 0, 380, 110),
	Rect2(0, 740, 360, 340),
	Rect2(540, 940, 840, 140),
]

## path -> { "mask": Image, "size": Vector2i, "cache": PackedVector2Array }
static var _mask_bank: Dictionary = {}
static var _active_path: String = ""
static var _mask: Image = null
static var _mask_size: Vector2i = Vector2i.ZERO
static var _opaque_cache: PackedVector2Array = PackedVector2Array()


static func random_point(placed: Array[Vector2], min_dist: float = MIN_DIST, max_tries: int = 40) -> Vector2:
	_ensure_mask(_active_path if _active_path != "" else BACKGROUND_PATH)
	for _try in max_tries:
		var p := _random_opaque_point()
		if _is_clear(p, placed, min_dist) and is_on_surface(p):
			return p
	for _try2 in 24:
		var p2 := _random_opaque_point()
		if is_on_surface(p2):
			return p2
	return Vector2(VIEWPORT) * 0.5


static func random_near(
	origin: Vector2,
	radius: Vector2,
	placed: Array[Vector2],
	min_dist: float = 140.0,
	max_tries: int = 18,
) -> Vector2:
	_ensure_mask(_active_path if _active_path != "" else BACKGROUND_PATH)
	for _try in max_tries:
		var offset := Vector2(randf_range(-radius.x, radius.x), randf_range(-radius.y, radius.y))
		var p := origin + offset
		if is_on_surface(p) and _is_clear(p, placed, min_dist):
			return p
	return Vector2.INF


static func is_on_surface(p: Vector2) -> bool:
	_ensure_mask(_active_path if _active_path != "" else BACKGROUND_PATH)
	if p.x < 0.0 or p.y < 0.0 or p.x >= VIEWPORT.x or p.y >= VIEWPORT.y:
		return false
	if _is_in_ui_zone(p):
		return false
	if _mask == null:
		return _legacy_polygon_surface(p)
	var px := _world_to_mask(p)
	if px.x < 0 or px.y < 0 or px.x >= _mask_size.x or px.y >= _mask_size.y:
		return false
	var c := _mask.get_pixel(px.x, px.y)
	if c.a < ALPHA_THRESHOLD:
		return false
	var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	return luma > VOID_LUMA_MAX


static func snap_to_surface(preferred: Vector2) -> Vector2:
	_ensure_mask(_active_path if _active_path != "" else BACKGROUND_PATH)
	if is_on_surface(preferred):
		return preferred
	if _opaque_cache.is_empty():
		return preferred
	var best := preferred
	var best_d := INF
	for p in _opaque_cache:
		if not is_on_surface(p):
			continue
		var d := preferred.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = p
	return best


static func depth_z(y: float) -> int:
	return clampi(int((y / 1080.0) * 7.0) + 4, 4, 12)


static func add_isometric_shell(
	room: Node2D,
	floor_color: Color = Color(0.58, 0.64, 0.62),
	background_path: String = "",
) -> void:
	var path := background_path
	if path == "":
		path = BACKGROUND_PATH
	_ensure_mask(path)
	_add_arcade_tile_backdrop(room, floor_color)

	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			_add_room_contact_shadow(room)
			var spr := Sprite2D.new()
			spr.name = "RoomBackground"
			spr.texture = tex
			spr.centered = false
			spr.position = Vector2.ZERO
			var tex_size := tex.get_size()
			if tex_size.x > 0.0 and tex_size.y > 0.0:
				spr.scale = Vector2(VIEWPORT.x / tex_size.x, VIEWPORT.y / tex_size.y)
			spr.z_index = -10
			room.add_child(spr)
			return

	_add_legacy_shell(room, floor_color)


static func _add_arcade_tile_backdrop(room: Node2D, theme: Color) -> void:
	var pal: Dictionary = LevelData.arcade_palette(theme)
	var mat := ShaderMaterial.new()
	mat.shader = ARCADE_SHADER
	mat.set_shader_parameter("color_a", pal["color_a"])
	mat.set_shader_parameter("color_b", pal["color_b"])
	mat.set_shader_parameter("color_line", pal["color_line"])
	mat.set_shader_parameter("color_accent", pal["color_accent"])
	mat.set_shader_parameter("tile_size", 52.0)
	mat.set_shader_parameter("scroll_speed", float(pal.get("scroll_speed", 0.11)))
	mat.set_shader_parameter("diagonal_angle", 0.785398)
	mat.set_shader_parameter("line_width", 0.07)
	mat.set_shader_parameter("vignette", 0.58)
	mat.set_shader_parameter("pulse_amount", 0.03)
	mat.set_shader_parameter("accent_chance", float(pal.get("accent_chance", 0.08)))
	mat.set_shader_parameter("glow_strength", 0.42)
	mat.set_shader_parameter("viewport_size", Vector2(VIEWPORT))

	var rect := ColorRect.new()
	rect.name = "ArcadeTileBackdrop"
	rect.size = Vector2(VIEWPORT)
	rect.position = Vector2.ZERO
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = mat
	rect.z_index = -30
	room.add_child(rect)


static func _add_room_contact_shadow(room: Node2D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADOW_SHADER
	mat.set_shader_parameter("shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	mat.set_shader_parameter("softness", 0.4)

	var shadow := ColorRect.new()
	shadow.name = "RoomContactShadow"
	shadow.size = Vector2(980, 420)
	shadow.position = Vector2(470, 520)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.material = mat
	shadow.z_index = -12
	room.add_child(shadow)


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


static func _ensure_mask(path: String) -> void:
	if path == "":
		path = BACKGROUND_PATH
	if _active_path == path and _mask != null:
		return
	if _mask_bank.has(path):
		var entry: Dictionary = _mask_bank[path]
		_mask = entry["mask"]
		_mask_size = entry["size"]
		_opaque_cache = entry["cache"]
		_active_path = path
		return
	if not ResourceLoader.exists(path):
		push_warning("RoomSpawnBounds: arkaplan yok: %s" % path)
		_mask = null
		_mask_size = Vector2i.ZERO
		_opaque_cache = PackedVector2Array()
		_active_path = path
		return
	var tex := load(path) as Texture2D
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		img = Image.new()
		if img.load(path) != OK:
			push_warning("RoomSpawnBounds: mask yüklenemedi: %s" % path)
			return
	if img.is_compressed():
		img.decompress()
	_mask = img.duplicate()
	_mask_size = Vector2i(_mask.get_width(), _mask.get_height())
	_active_path = path
	_build_opaque_cache()
	_mask_bank[path] = {
		"mask": _mask,
		"size": _mask_size,
		"cache": _opaque_cache,
	}


static func _build_opaque_cache() -> void:
	_opaque_cache = PackedVector2Array()
	if _mask == null:
		return
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
			if _is_in_ui_zone(world):
				continue
			_opaque_cache.append(world)


static func _random_opaque_point() -> Vector2:
	if _opaque_cache.size() > 0:
		var base: Vector2 = _opaque_cache[randi() % _opaque_cache.size()]
		for _j in 6:
			var jittered := base + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
			if is_on_surface(jittered):
				return jittered
		return base
	return _random_in_polygon(_floor_poly())


static func _is_in_ui_zone(p: Vector2) -> bool:
	for r in UI_BLOCK_ZONES:
		if r.has_point(p):
			return true
	return false


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
