class_name EndlessGenerator
extends RefCounted

# Endless Mode için prosedürel oda üretimi.

const MIN_DIST := RoomSpawnBounds.MIN_DIST

const BG_COLORS: Array[Color] = [
	Color(0.58, 0.64, 0.62), Color(0.56, 0.58, 0.66), Color(0.54, 0.62, 0.58),
	Color(0.6, 0.58, 0.52), Color(0.58, 0.54, 0.62), Color(0.52, 0.6, 0.64),
]


static func build_room(index: int, unlocked: int) -> Node2D:
	var room := Node2D.new()
	room.name = "EndlessRoom_%d" % index
	room.add_to_group("Room")

	RoomSpawnBounds.add_isometric_shell(room, BG_COLORS[index % BG_COLORS.size()])

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
		obj.z_index = RoomSpawnBounds.depth_z(pos.y)
		room.add_child(obj)
		if type == "broom":
			need_trashbin = true
		elif type == "slime":
			need_drain = true

	if need_trashbin:
		room.add_child(RoomFactory.make_zone(&"TrashBin", RoomSpawnBounds.TRASH_POS, "ÇÖP KOVASI"))
	if need_drain:
		room.add_child(RoomFactory.make_zone(&"Drain", RoomSpawnBounds.DRAIN_POS, "GİDER"))

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
	return RoomSpawnBounds.random_point(placed, MIN_DIST)


static func _make_dirt(type: String, pos: Vector2) -> Node2D:
	match type:
		"mop_fragile":
			return RoomFactory.make_dirt("fragile", pos)
		"mop_mold":
			return RoomFactory.make_dirt("mold", pos)
		"mop_stain":
			return RoomFactory.make_dirt("scrub", pos)
		_:
			return RoomFactory.make_dirt(type, pos)
