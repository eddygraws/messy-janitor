extends Node2D
class_name RoomManager

signal room_cleared(room_index: int, result: Dictionary)
signal room_transition_started
signal room_transition_finished
signal level_completed(total_score: int, average_score: int)
signal objective_changed(remaining: int, total: int)

@export var feedback_ui_path: NodePath = ^"../UI/RoomFeedbackUI"
@export var score_tracker_path: NodePath = ^"../RoomScoreTracker"
@export var screen_shake_path: NodePath = ^"../ScreenShake"
@export var camera_path: NodePath = ^"../Camera2D"
@export var stress_path: NodePath = ^"../StressComponent"
@export var stamina_path: NodePath = ^"../StaminaComponent"
@export var equipment_path: NodePath = ^"../EquipmentComponent"

@export var viewport_height: float = 1080.0
@export_range(3, 10, 1) var rooms_per_level: int = 10
@export var slide_duration: float = 1.15

var current_room_index: int = 0
var total_rooms: int = 0
var _rooms: Array[Node2D] = []
var _transitioning: bool = false
var _level_total_score: int = 0
var _rooms_cleared: int = 0

var _feedback_ui: RoomFeedbackUI
var _score_tracker: RoomScoreTracker
var _shake: ScreenShake
var _camera: Camera2D
var _stress: StressComponent
var _stamina: StaminaComponent
var _equipment: EquipmentComponent


func _ready() -> void:
	_feedback_ui = get_node(feedback_ui_path) as RoomFeedbackUI
	_score_tracker = get_node(score_tracker_path) as RoomScoreTracker
	_shake = get_node(screen_shake_path) as ScreenShake
	_camera = get_node(camera_path) as Camera2D
	_stress = get_node(stress_path) as StressComponent
	_stamina = get_node(stamina_path) as StaminaComponent
	_equipment = get_node_or_null(equipment_path) as EquipmentComponent

	_collect_rooms()
	_apply_equipment_unlock()


# Level ilerledikçe ekipman açılır:
# Oda 1-3: Paspas | 4-6: +Süpürge | 7-9: +Fırça | 10+: +Sprey+Bez & Cımbız
func _apply_equipment_unlock() -> void:
	if _equipment == null:
		return
	var level := current_room_index + 1
	var unlocked := 1
	if level >= 10:
		unlocked = 5
	elif level >= 7:
		unlocked = 3
	elif level >= 4:
		unlocked = 2
	_equipment.set_unlocked_count(unlocked)


func is_transitioning() -> bool:
	return _transitioning


func get_level_score() -> int:
	return _level_total_score


func get_current_room() -> Node2D:
	if current_room_index >= _rooms.size():
		return null
	return _rooms[current_room_index]


func check_room_cleared() -> void:
	if _transitioning:
		return

	var room := get_current_room()
	if room == null:
		return

	var counts := _count_dirt(room)
	objective_changed.emit(counts.x, counts.y)

	if counts.x == 0:
		_start_room_transition()


# counts.x = kalan kir, counts.y = toplam kir
func _count_dirt(room: Node2D) -> Vector2i:
	var total := 0
	var remaining := 0
	for child in room.get_children():
		if child.is_in_group("Cleanable") and child.has_method("is_cleaned"):
			total += 1
			if not child.is_cleaned():
				remaining += 1
	return Vector2i(remaining, total)


func emit_current_objective() -> void:
	var room := get_current_room()
	if room == null:
		return
	var counts := _count_dirt(room)
	objective_changed.emit(counts.x, counts.y)


func _collect_rooms() -> void:
	var all_rooms: Array[Node2D] = []
	for child in get_children():
		if child is Node2D and child.is_in_group("Room"):
			all_rooms.append(child)

	total_rooms = mini(all_rooms.size(), rooms_per_level)
	_rooms.clear()

	for i in all_rooms.size():
		var is_active := i < total_rooms
		all_rooms[i].visible = is_active
		all_rooms[i].position.y = -i * viewport_height
		if is_active:
			_rooms.append(all_rooms[i])

	if total_rooms == 0:
		push_error("RoomManager: 'Room' grubunda hiç oda yok!")


func _start_room_transition() -> void:
	_transitioning = true
	room_transition_started.emit()

	var result: Dictionary = _score_tracker.finalize_room()
	_level_total_score += result.score
	_rooms_cleared += 1
	room_cleared.emit(current_room_index, result)

	_shake.shake(0.18)
	await _feedback_ui.show_rating(result)

	var is_last_room := current_room_index >= total_rooms - 1
	if is_last_room:
		await _finish_level(result)
		return

	await _animate_to_next_room()
	current_room_index += 1
	_prepare_next_room()
	_transitioning = false
	room_transition_finished.emit()


func _finish_level(result: Dictionary) -> void:
	var average := _level_total_score / maxi(_rooms_cleared, 1)
	level_completed.emit(_level_total_score, average)
	await _feedback_ui.show_level_summary(_level_total_score, average, _rooms_cleared)
	_transitioning = false
	room_transition_finished.emit()
	print("LEVEL COMPLETED! Total: %d | Avg: %d" % [_level_total_score, average])


func _animate_to_next_room() -> void:
	await _feedback_ui.flash_transition()
	_shake.add_trauma(0.28)

	var target_y := position.y + viewport_height
	var slide := create_tween()
	slide.tween_property(self, "position:y", target_y, slide_duration)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	if _camera:
		var cam_tween := create_tween()
		cam_tween.tween_property(_camera, "zoom", Vector2(1.06, 1.06), slide_duration * 0.28)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		cam_tween.tween_property(_camera, "zoom", Vector2.ONE, slide_duration * 0.55)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	await slide.finished
	if _camera:
		_camera.zoom = Vector2.ONE


func _prepare_next_room() -> void:
	_stress.reduce_stress(_stress.current_stress * 0.5)
	_stamina.restore(_stamina.max_stamina * 0.25)
	_apply_equipment_unlock()
	_score_tracker.begin_room()
	emit_current_objective()
