class_name RoomFactory
extends RefCounted

# Hem Adventure (LevelData) hem Endless (EndlessGenerator) için ortak
# oda/kir üretim fabrikası. Kir tiplerini tek yerde tanımlar.

const DRAG_SCRIPT := preload("res://components/draggable_cleanable.gd")
const ROAM_SLIME_SCRIPT := preload("res://components/roaming_slime.gd")

const MIN_DIST := RoomSpawnBounds.MIN_DIST

const DEFAULT_BG := Color(0.58, 0.64, 0.62)


# spec: {
#   "name": String, "label": String, "bg": Color,
#   "dirt": Array[ {"type": String, "count": int, "pos": Vector2(optional)} veya String ],
#   "tutorial": String (opsiyonel), "commission": Dictionary (opsiyonel)
# }
static func build_room(spec: Dictionary, index: int) -> Node2D:
	var room := Node2D.new()
	room.name = String(spec.get("name", "Room_%d" % index))
	room.add_to_group("Room")

	var bg_color: Color = spec.get("bg", DEFAULT_BG)
	RoomSpawnBounds.add_isometric_shell(room, bg_color)

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
			var dirt := make_dirt(type, pos)
			dirt.set_meta("dirt_type", type)
			if "dirt_kind" in dirt:
				dirt.set("dirt_kind", type)
			dirt.z_index = RoomSpawnBounds.depth_z(pos.y)
			room.add_child(dirt)
			if type == "broom":
				need_trashbin = true
			elif type == "slime" or type == "slime_boss":
				need_drain = true

	if need_trashbin:
		room.add_child(make_zone(&"TrashBin", RoomSpawnBounds.TRASH_POS, "ÇÖP KOVASI"))
	if need_drain:
		room.add_child(make_zone(&"Drain", RoomSpawnBounds.DRAIN_POS, "GİDER"))

	room.set_meta("tutorial", String(spec.get("tutorial", "")))
	room.set_meta("commission", spec.get("commission", {}))
	return room


static func free_pos(placed: Array[Vector2]) -> Vector2:
	return RoomSpawnBounds.random_point(placed, MIN_DIST)


static func make_dirt(type: String, pos: Vector2) -> Node2D:
	match type:
		"stain":
			var cl := CleanableObject.new()
			cl.hitbox_size = Vector2(84, 84)
			cl.required_equipment = 0
			cl.modulate = Color(0.5, 0.4, 0.32)
			cl.position = pos
			_add_dirt_visual(cl, "stain")
			return cl
		"scrub":
			var st := CleanableObject.new()
			st.hitbox_size = Vector2(126, 92)
			st.requires_scrub = true
			st.modulate = Color(0.6, 0.45, 0.35)
			st.position = pos
			_add_dirt_visual(st, "scrub")
			return st
		"hidden":
			var hd := CleanableObject.new()
			hd.hitbox_size = Vector2(120, 90)
			hd.requires_scrub = true
			hd.is_hidden = true
			hd.reveal_radius = 150.0
			hd.modulate = Color(0.7, 0.5, 0.75)
			hd.position = pos
			_add_dirt_visual(hd, "hidden")
			return hd
		"slime":
			var sl: Node2D = DRAG_SCRIPT.new()
			sl.set("hitbox_size", Vector2(82, 82))
			sl.set("required_equipment", 0)
			sl.set("target_group", &"Drain")
			sl.modulate = Color(0.45, 0.85, 0.55)
			sl.position = pos
			_add_dirt_visual(sl, "slime")
			return sl
		"slime_boss":
			var boss: Node2D = ROAM_SLIME_SCRIPT.new()
			boss.set("hitbox_size", Vector2(110, 96))
			boss.set("required_equipment", 0)
			boss.set("target_group", &"Drain")
			boss.modulate = Color(0.35, 0.95, 0.55)
			boss.position = pos
			_add_dirt_visual(boss, "slime", Color(0.45, 1.0, 0.6))
			return boss
		"slime_trail":
			var trail := CleanableObject.new()
			trail.hitbox_size = Vector2(72, 56)
			trail.requires_scrub = true
			trail.scrub_move_factor = 0.0011
			trail.modulate = Color(0.4, 0.8, 0.5, 0.9)
			trail.position = pos
			trail.add_to_group("SlimeTrail")
			_add_dirt_visual(trail, "slime", Color(0.5, 0.9, 0.55, 0.85))
			return trail
		"potion":
			var pot := CleanableObject.new()
			pot.hitbox_size = Vector2(118, 100)
			pot.requires_scrub = true
			pot.scrub_move_factor = 0.00042
			pot.reversal_bonus = 0.035
			pot.applies_drunk = true
			pot.drunk_on_scrub = 0.32
			pot.modulate = Color(0.75, 0.35, 0.95)
			pot.position = pos
			_add_dirt_visual(pot, "potion", Color(0.85, 0.4, 1.0))
			return pot
		"broom":
			var b: Node2D = DRAG_SCRIPT.new()
			b.set("hitbox_size", Vector2(76, 76))
			b.set("required_equipment", 1)
			b.set("target_group", &"TrashBin")
			b.modulate = Color(0.72, 0.6, 0.42)
			b.position = pos
			_add_dirt_visual(b, "broom")
			return b
		"brush":
			var br := CleanableObject.new()
			br.hitbox_size = Vector2(110, 96)
			br.required_equipment = 2
			br.mash_per_hit = 0.2
			br.modulate = Color(0.42, 0.4, 0.36)
			br.position = pos
			_add_dirt_visual(br, "brush")
			return br
		"spray":
			var sp := CleanableObject.new()
			sp.hitbox_size = Vector2(140, 118)
			sp.requires_scrub = true
			sp.required_equipment = 3
			sp.modulate = Color(0.7, 0.85, 0.95)
			sp.position = pos
			_add_dirt_visual(sp, "spray", Color(0.55, 0.75, 0.9, 0.85))
			var overlay := SpriteVisualHelper.make_sprite(
				GameAssets.get_dirt_texture("scrub"), Color(0.75, 0.8, 0.7, 0.55), 0.72)
			sp.add_child(overlay)
			return sp
		"tweezers":
			var tw := CleanableObject.new()
			tw.hitbox_size = Vector2(54, 54)
			tw.required_equipment = 4
			tw.modulate = Color(0.9, 0.95, 1.0)
			tw.position = pos
			_add_dirt_visual(tw, "tweezers")
			return tw
		"fragile":
			var fr := CleanableObject.new()
			fr.hitbox_size = Vector2(84, 120)
			fr.requires_scrub = true
			fr.is_fragile = true
			fr.fragile_threshold = 30.0
			fr.modulate = Color(0.55, 0.7, 0.95)
			fr.position = pos
			_add_dirt_visual(fr, "fragile")
			return fr
		"mold":
			var mo := CleanableObject.new()
			mo.hitbox_size = Vector2(118, 84)
			mo.requires_scrub = true
			mo.spreads = true
			mo.spread_time = 6.0
			mo.modulate = Color(0.4, 0.55, 0.3)
			mo.position = pos
			_add_dirt_visual(mo, "mold")
			return mo
		_:
			return make_dirt("scrub", pos)


static func make_zone(group: StringName, pos: Vector2, text: String) -> Node2D:
	var zone := DrainZone.new()
	zone.zone_group = group
	zone.hitbox_size = Vector2(180, 170)
	zone.position = pos
	zone.z_index = RoomSpawnBounds.depth_z(pos.y)
	SpriteVisualHelper.add_zone_sprite(zone, group)
	var label := Label.new()
	label.modulate = Color(1, 1, 1, 0.45)
	label.position = Vector2(-90, 86)
	label.size = Vector2(180, 26)
	label.add_theme_font_size_override("font_size", 18)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone.add_child(label)
	return zone


static func _add_dirt_visual(parent: Node2D, dirt_type: String, tint: Color = Color.WHITE) -> void:
	SpriteVisualHelper.add_dirt_sprite(parent, dirt_type, tint)
