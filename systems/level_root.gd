class_name LevelRoot
extends Node2D

# Her Adventure seviyesi ayrı bir sahnedir (level_XX.tscn). Kök düğüm bu script'i
# taşır. Odalar RoomManager tarafından istendiğinde kurulur:
#  - Sahnede elle yazılmış "Room" grubu çocukları varsa onlar kullanılır,
#  - yoksa LevelData'dan RoomFactory ile üretilir.
# Böylece dosyalar gerçek/açılabilir kalır ve istenirse elle özelleştirilebilir.

@export var level_index: int = 0

var _rooms: Array[Node2D] = []


func build_rooms(viewport_height: float) -> Array[Node2D]:
	_rooms.clear()

	for child in get_children():
		if child is Node2D and child.is_in_group("Room"):
			_rooms.append(child)

	if _rooms.is_empty():
		var specs: Array = get_level_info().get("rooms", [])
		for i in specs.size():
			var room := RoomFactory.build_room(specs[i], i)
			add_child(room)
			_rooms.append(room)

	for i in _rooms.size():
		_rooms[i].position.y = -i * viewport_height
		_rooms[i].visible = true

	return _rooms


func get_level_info() -> Dictionary:
	return LevelData.get_level(level_index)
