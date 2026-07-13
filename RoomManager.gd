extends Node2D
class_name RoomManager

signal room_cleared(room_index: int, result: Dictionary)
signal room_transition_started
signal room_transition_finished
signal level_completed(total_score: int, average_score: int)
signal objective_changed(remaining: int, total: int)

enum Mode { ADVENTURE, ENDLESS }

@export var feedback_ui_path: NodePath = ^"../UI/RoomFeedbackUI"
@export var score_tracker_path: NodePath = ^"../RoomScoreTracker"
@export var screen_shake_path: NodePath = ^"../ScreenShake"
@export var camera_path: NodePath = ^"../Camera2D"
@export var stress_path: NodePath = ^"../StressComponent"
@export var stamina_path: NodePath = ^"../StaminaComponent"
@export var equipment_path: NodePath = ^"../EquipmentComponent"
@export var tempo_path: NodePath = ^"../TempoDirector"

@export var viewport_height: float = 1080.0
@export_range(3, 10, 1) var rooms_per_level: int = 10
@export var slide_duration: float = 1.15

var mode: int = Mode.ADVENTURE
var current_room_index: int = 0
var total_rooms: int = 0
var _rooms: Array[Node2D] = []
var _current_room_node: Node2D
var _transitioning: bool = false
var _level_total_score: int = 0
var _rooms_cleared: int = 0
var _run_start_ms: int = 0
var _run_max_combo: int = 0

var _feedback_ui: RoomFeedbackUI
var _score_tracker: RoomScoreTracker
var _shake: ScreenShake
var _camera: Camera2D
var _stress: StressComponent
var _stamina: StaminaComponent
var _equipment: EquipmentComponent
var _tempo: TempoDirector


func _ready() -> void:
	_feedback_ui = get_node(feedback_ui_path) as RoomFeedbackUI
	_score_tracker = get_node(score_tracker_path) as RoomScoreTracker
	_shake = get_node(screen_shake_path) as ScreenShake
	_camera = get_node(camera_path) as Camera2D
	_stress = get_node(stress_path) as StressComponent
	_stamina = get_node(stamina_path) as StaminaComponent
	_equipment = get_node_or_null(equipment_path) as EquipmentComponent
	_tempo = get_node_or_null(tempo_path) as TempoDirector

	_collect_rooms()
	_apply_equipment_unlock()


# MainScene mod seçildikten sonra çağırır.
func start_run(selected_mode: int) -> void:
	mode = selected_mode
	current_room_index = 0
	_level_total_score = 0
	_rooms_cleared = 0
	_run_max_combo = 0
	_run_start_ms = Time.get_ticks_msec()
	position = Vector2.ZERO
	if mode == Mode.ENDLESS:
		_begin_endless()
	else:
		_begin_adventure()


func _begin_adventure() -> void:
	_apply_equipment_unlock()
	_current_room_node = get_current_room()
	_score_tracker.begin_room()
	emit_current_objective()


func _begin_endless() -> void:
	total_rooms = -1
	# Sahnedeki elle tasarlanmış odaları gizle.
	for child in get_children():
		if child is Node2D and child.is_in_group("Room"):
			child.visible = false
	_rooms.clear()
	_current_room_node = _generate_endless_room(0)
	_apply_endless_difficulty(0)
	_score_tracker.begin_room()
	emit_current_objective()


func _generate_endless_room(index: int) -> Node2D:
	var room := EndlessGenerator.build_room(index, _endless_unlocked(index))
	add_child(room)
	room.position = Vector2(0, -index * viewport_height)
	return room


func _endless_unlocked(index: int) -> int:
	return clampi(1 + index / 2, 1, 5)


func _apply_endless_difficulty(index: int) -> void:
	if _equipment != null:
		_equipment.set_unlocked_count(_endless_unlocked(index))
	if _tempo != null:
		_tempo.set_base_intensity(minf(0.55, index * 0.045))


func _apply_progression() -> void:
	if mode == Mode.ENDLESS:
		_apply_endless_difficulty(current_room_index)
	else:
		_apply_equipment_unlock()


func get_rooms_cleared() -> int:
	return _rooms_cleared


func get_run_time() -> float:
	return (Time.get_ticks_msec() - _run_start_ms) / 1000.0


func get_run_max_combo() -> int:
	return _run_max_combo


func get_mode() -> int:
	return mode


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
	if mode == Mode.ENDLESS:
		return _current_room_node
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
	_run_max_combo = maxi(_run_max_combo, int(result.get("max_combo", 0)))
	room_cleared.emit(current_room_index, result)

	_shake.shake(0.18)
	await _feedback_ui.show_rating(result)

	if mode == Mode.ENDLESS:
		await _advance_endless()
		return

	var is_last_room := current_room_index >= total_rooms - 1
	if is_last_room:
		await _finish_level(result)
		return

	await _animate_to_next_room()
	current_room_index += 1
	_prepare_next_room()
	_transitioning = false
	room_transition_finished.emit()


func _advance_endless() -> void:
	var next_index := current_room_index + 1
	var next_room := _generate_endless_room(next_index)

	await _animate_to_next_room()

	var old_room := _current_room_node
	current_room_index = next_index
	_current_room_node = next_room
	_prepare_next_room()
	if old_room != null:
		old_room.queue_free()

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
	_apply_progression()
	_score_tracker.begin_room()
	emit_current_objective()
