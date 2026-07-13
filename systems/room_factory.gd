class_name RoomFactory
extends RefCounted

# Hem Adventure (LevelData) hem Endless (EndlessGenerator) için ortak
# oda/kir üretim fabrikası. Kir tiplerini tek yerde tanımlar.

const DRAG_SCRIPT := preload("res://components/draggable_cleanable.gd")

const AREA_MIN := Vector2(520, 360)
const AREA_MAX := Vector2(1400, 760)
const MIN_DIST := 165.0

const DEFAULT_BG := Color(0.16, 0.18, 0.24)


# spec: {
#   "name": String, "label": String, "bg": Color,
#   "dirt": Array[ {"type": String, "count": int, "pos": Vector2(optional)} veya String ],
#   "tutorial": String (opsiyonel), "commission": Dictionary (opsiyonel)
# }
static func build_room(spec: Dictionary, index: int) -> Node2D:
	var room := Node2D.new()
	room.name = String(spec.get("name", "Room_%d" % index))
	room.add_to_group("Room")

	var bg := Polygon2D.new()
	bg.color = spec.get("bg", DEFAULT_BG)
	bg.polygon = PackedVector2Array([Vector2(0, 0), Vector2(1920, 0), Vector2(1920, 1080), Vector2(0, 1080)])
	room.add_child(bg)

	var label_text := String(spec.get("label", ""))
	if label_text != "":
		var label := Label.new()
		label.modulate = Color(1, 1, 1, 0.22)
		label.position = Vector2(560, 40)
		label.size = Vector2(800, 160)
		label.add_theme_font_size_override("font_size", 110)
		label.text = label_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		room.add_child(label)

	var placed: Array[Vector2] = []
	var need_trashbin := false
	var need_drain := false

	for entry in spec.get("dirt", []):
		var type := ""
		var count := 1
		var fixed_pos: Variant = null
		if entry is String:
			type = String(entry)
		elif entry is Dictionary:
			type = String((entry as Dictionary).get("type", "scrub"))
			count = int((entry as Dictionary).get("count", 1))
			if (entry as Dictionary).has("pos"):
				fixed_pos = (entry as Dictionary)["pos"]
		for _i in count:
			var pos: Vector2 = fixed_pos if fixed_pos != null else free_pos(placed)
			placed.append(pos)
			room.add_child(make_dirt(type, pos))
			if type == "broom":
				need_trashbin = true
			elif type == "slime":
				need_drain = true

	if need_trashbin:
		room.add_child(make_zone(&"TrashBin", Vector2(1620, 880), "ÇÖP KOVASI"))
	if need_drain:
		room.add_child(make_zone(&"Drain", Vector2(320, 880), "GİDER"))

	room.set_meta("tutorial", String(spec.get("tutorial", "")))
	room.set_meta("commission", spec.get("commission", {}))
	return room


static func free_pos(placed: Array[Vector2]) -> Vector2:
	for _try in 24:
		var p := Vector2(randf_range(AREA_MIN.x, AREA_MAX.x), randf_range(AREA_MIN.y, AREA_MAX.y))
		var ok := true
		for q in placed:
			if p.distance_to(q) < MIN_DIST:
				ok = false
				break
		if ok:
			return p
	return Vector2(randf_range(AREA_MIN.x, AREA_MAX.x), randf_range(AREA_MIN.y, AREA_MAX.y))


static func make_dirt(type: String, pos: Vector2) -> Node2D:
	match type:
		"stain":  # tek tıkla temizlenen basit leke (paspas)
			var cl := CleanableObject.new()
			cl.hitbox_size = Vector2(84, 84)
			cl.required_equipment = 0
			cl.modulate = Color(0.5, 0.4, 0.32)
			cl.position = pos
			_add_visual(cl, Color(0.4, 0.32, 0.24), PackedVector2Array([
				Vector2(-34, -30), Vector2(30, -34), Vector2(38, 26), Vector2(-30, 34)]))
			return cl
		"scrub":  # ovalayarak temizlenen leke (paspas)
			var st := CleanableObject.new()
			st.hitbox_size = Vector2(126, 92)
			st.requires_scrub = true
			st.modulate = Color(0.6, 0.45, 0.35)
			st.position = pos
			_add_visual(st, Color(0.45, 0.3, 0.2, 0.9), PackedVector2Array([
				Vector2(-58, -38), Vector2(58, -32), Vector2(50, 42), Vector2(-52, 36)]))
			return st
		"hidden":  # gizli kir (imleç aydınlatır) — paspas ovalama
			var hd := CleanableObject.new()
			hd.hitbox_size = Vector2(120, 90)
			hd.requires_scrub = true
			hd.is_hidden = true
			hd.reveal_radius = 150.0
			hd.modulate = Color(0.7, 0.5, 0.75)
			hd.position = pos
			_add_visual(hd, Color(0.5, 0.35, 0.6, 0.85), PackedVector2Array([
				Vector2(-54, -40), Vector2(54, -34), Vector2(46, 42), Vector2(-50, 38)]))
			return hd
		"slime":  # paspasla gidere it (draggable, equipment 0)
			var sl: Node2D = DRAG_SCRIPT.new()
			sl.set("hitbox_size", Vector2(82, 82))
			sl.set("required_equipment", 0)
			sl.set("target_group", &"Drain")
			sl.modulate = Color(0.45, 0.85, 0.55)
			sl.position = pos
			_add_visual(sl, Color(0.35, 0.7, 0.42), PackedVector2Array([
				Vector2(-30, -18), Vector2(-8, -28), Vector2(20, -18),
				Vector2(30, 10), Vector2(6, 28), Vector2(-26, 18)]))
			return sl
		"broom":  # süpürgeyle çöp kovasına it (draggable, equipment 1)
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
		"brush":  # fırçayla hızlı tıkla (equipment 2)
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
		"spray":  # sprey sık, sonra ovala (equipment 3)
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
		"tweezers":  # cımbızla tek hassas tıkla (equipment 4)
			var tw := CleanableObject.new()
			tw.hitbox_size = Vector2(54, 54)
			tw.required_equipment = 4
			tw.modulate = Color(0.9, 0.95, 1.0)
			tw.position = pos
			_add_visual(tw, Color(0.85, 0.92, 1.0, 0.9), PackedVector2Array([
				Vector2(-22, -8), Vector2(6, -24), Vector2(18, 4), Vector2(2, 22), Vector2(-14, 14)]))
			return tw
		"fragile":  # kırılgan — sert ovalama kırar (paspas)
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
		"mold":  # yayılan küf (paspas ovala) — hızlı ol
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
			return make_dirt("scrub", pos)


static func make_zone(group: StringName, pos: Vector2, text: String) -> Node2D:
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
