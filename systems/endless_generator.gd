class_name EndlessGenerator
extends RefCounted

# Endless Mode için prosedürel oda üretimi.
# Mevcut kir tiplerinden, o anki AÇIK ekipmanlara göre ağırlıklı bir havuzdan
# oda kurulumu üretir. Kilitli alet gerektiren kir asla üretilmez.

const DRAG_SCRIPT := preload("res://components/draggable_cleanable.gd")

const AREA_MIN := Vector2(520, 360)
const AREA_MAX := Vector2(1400, 760)
const MIN_DIST := 165.0

const BG_COLORS: Array[Color] = [
	Color(0.16, 0.18, 0.24), Color(0.24, 0.16, 0.2), Color(0.16, 0.22, 0.18),
	Color(0.26, 0.2, 0.14), Color(0.2, 0.16, 0.24), Color(0.14, 0.2, 0.22),
]


static func build_room(index: int, unlocked: int) -> Node2D:
	var room := Node2D.new()
	room.name = "EndlessRoom_%d" % index
	room.add_to_group("Room")

	var bg := Polygon2D.new()
	bg.color = BG_COLORS[index % BG_COLORS.size()]
	bg.polygon = PackedVector2Array([Vector2(0, 0), Vector2(1920, 0), Vector2(1920, 1080), Vector2(0, 1080)])
	room.add_child(bg)

	var label := Label.new()
	label.modulate = Color(1, 1, 1, 0.22)
	label.position = Vector2(660, 40)
	label.size = Vector2(600, 160)
	label.add_theme_font_size_override("font_size", 120)
	label.text = "TUR %d" % (index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room.add_child(label)

	var count := clampi(3 + index / 2, 3, 8)
	var placed: Array[Vector2] = []
	var need_trashbin := false
	var need_drain := false

	for _i in count:
		var type := _pick_type(unlocked, index)
		var pos := _free_pos(placed)
		placed.append(pos)
		var obj := _make_dirt(type, pos)
		room.add_child(obj)
		if type == "broom":
			need_trashbin = true
		elif type == "slime":
			need_drain = true

	if need_trashbin:
		room.add_child(_make_zone(&"TrashBin", Vector2(1620, 870), "ÇÖP KOVASI"))
	if need_drain:
		room.add_child(_make_zone(&"Drain", Vector2(320, 870), "GİDER"))

	return room


static func _pick_type(unlocked: int, index: int) -> String:
	var pool: Array = [["mop_stain", 4]]
	if index >= 2:
		pool.append(["mop_mold", 1])
	pool.append(["mop_fragile", 1])
	if unlocked >= 2:
		pool.append(["broom", 3])
	if unlocked >= 3:
		pool.append(["brush", 3])
	if unlocked >= 4:
		pool.append(["spray", 3])
	if unlocked >= 5:
		pool.append(["tweezers", 2])

	var total := 0
	for entry in pool:
		total += int(entry[1])
	var roll := randi() % total
	for entry in pool:
		roll -= int(entry[1])
		if roll < 0:
			return String(entry[0])
	return "mop_stain"


static func _free_pos(placed: Array[Vector2]) -> Vector2:
	for _try in 20:
		var p := Vector2(
			randf_range(AREA_MIN.x, AREA_MAX.x),
			randf_range(AREA_MIN.y, AREA_MAX.y)
		)
		var ok := true
		for q in placed:
			if p.distance_to(q) < MIN_DIST:
				ok = false
				break
		if ok:
			return p
	return Vector2(
		randf_range(AREA_MIN.x, AREA_MAX.x),
		randf_range(AREA_MIN.y, AREA_MAX.y)
	)


static func _make_dirt(type: String, pos: Vector2) -> Node2D:
	match type:
		"broom":
			var b: Node2D = DRAG_SCRIPT.new()
			b.set("hitbox_size", Vector2(76, 76))
			b.set("required_equipment", 1)
			b.set("target_group", &"TrashBin")
			b.modulate = Color(0.72, 0.6, 0.42)
			b.position = pos
			_add_visual(b, Color(0.6, 0.48, 0.3), PackedVector2Array([
				Vector2(-22, -14), Vector2(-6, -22), Vector2(14, -10),
				Vector2(24, 10), Vector2(4, 22), Vector2(-18, 14)]))
			return b
		"brush":
			var br := CleanableObject.new()
			br.hitbox_size = Vector2(110, 96)
			br.required_equipment = 2
			br.mash_per_hit = 0.2
			br.modulate = Color(0.42, 0.4, 0.36)
			br.position = pos
			_add_visual(br, Color(0.3, 0.28, 0.24), PackedVector2Array([
				Vector2(-50, -42), Vector2(-8, -48), Vector2(44, -38),
				Vector2(50, 2), Vector2(38, 46), Vector2(-20, 44), Vector2(-48, 12)]))
			return br
		"spray":
			var sp := CleanableObject.new()
			sp.hitbox_size = Vector2(140, 118)
			sp.requires_scrub = true
			sp.required_equipment = 3
			sp.modulate = Color(0.7, 0.85, 0.95)
			sp.position = pos
			_add_visual(sp, Color(0.55, 0.75, 0.9, 0.5), PackedVector2Array([
				Vector2(-64, -54), Vector2(64, -54), Vector2(64, 54), Vector2(-64, 54)]))
			_add_visual(sp, Color(0.75, 0.8, 0.7, 0.4), PackedVector2Array([
				Vector2(-40, -30), Vector2(20, -36), Vector2(44, 10), Vector2(10, 38), Vector2(-34, 28)]))
			return sp
		"tweezers":
			var tw := CleanableObject.new()
			tw.hitbox_size = Vector2(54, 54)
			tw.required_equipment = 4
			tw.modulate = Color(0.9, 0.95, 1.0)
			tw.position = pos
			_add_visual(tw, Color(0.85, 0.92, 1.0, 0.9), PackedVector2Array([
				Vector2(-22, -8), Vector2(6, -24), Vector2(18, 4), Vector2(2, 22), Vector2(-14, 14)]))
			return tw
		"mop_fragile":
			var fr := CleanableObject.new()
			fr.hitbox_size = Vector2(84, 120)
			fr.requires_scrub = true
			fr.is_fragile = true
			fr.fragile_threshold = 30.0
			fr.modulate = Color(0.55, 0.7, 0.95)
			fr.position = pos
			_add_visual(fr, Color(0.4, 0.55, 0.85, 0.95), PackedVector2Array([
				Vector2(-26, -60), Vector2(26, -60), Vector2(18, 0),
				Vector2(32, 42), Vector2(-32, 42), Vector2(-18, 0)]))
			return fr
		"mop_mold":
			var mo := CleanableObject.new()
			mo.hitbox_size = Vector2(118, 84)
			mo.requires_scrub = true
			mo.spreads = true
			mo.spread_time = 6.0
			mo.modulate = Color(0.4, 0.55, 0.3)
			mo.position = pos
			_add_visual(mo, Color(0.3, 0.42, 0.22, 0.9), PackedVector2Array([
				Vector2(-58, -36), Vector2(-12, -44), Vector2(40, -34),
				Vector2(60, 6), Vector2(36, 44), Vector2(-36, 40)]))
			return mo
		_:
			var st := CleanableObject.new()
			st.hitbox_size = Vector2(126, 92)
			st.requires_scrub = true
			st.modulate = Color(0.6, 0.45, 0.35)
			st.position = pos
			_add_visual(st, Color(0.45, 0.3, 0.2, 0.9), PackedVector2Array([
				Vector2(-58, -38), Vector2(58, -32), Vector2(50, 42), Vector2(-52, 36)]))
			return st


static func _make_zone(group: StringName, pos: Vector2, text: String) -> Node2D:
	var zone := DrainZone.new()
	zone.zone_group = group
	zone.hitbox_size = Vector2(180, 170)
	zone.position = pos

	var body := Polygon2D.new()
	body.color = Color(0.28, 0.3, 0.34) if group == &"TrashBin" else Color(0.09, 0.09, 0.12)
	body.polygon = PackedVector2Array([Vector2(-70, -60), Vector2(70, -60), Vector2(58, 80), Vector2(-58, 80)])
	zone.add_child(body)

	var rim := Polygon2D.new()
	rim.color = Color(0.42, 0.44, 0.5)
	rim.polygon = PackedVector2Array([Vector2(-82, -74), Vector2(82, -74), Vector2(82, -58), Vector2(-82, -58)])
	zone.add_child(rim)

	var label := Label.new()
	label.modulate = Color(1, 1, 1, 0.45)
	label.position = Vector2(-90, 86)
	label.size = Vector2(180, 26)
	label.add_theme_font_size_override("font_size", 18)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone.add_child(label)
	return zone


static func _add_visual(parent: Node2D, color: Color, poly: PackedVector2Array) -> void:
	var v := Polygon2D.new()
	v.color = color
	v.polygon = poly
	parent.add_child(v)
