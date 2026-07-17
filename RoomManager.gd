extends Node2D
class_name RoomManager

signal room_cleared(room_index: int, result: Dictionary)
signal room_transition_started
signal room_transition_finished
signal level_completed(total_score: int, average_score: int)
signal objective_changed(remaining: int, total: int)
signal tutorial_requested(text: String)

enum Mode { ADVENTURE, ENDLESS }

@export var feedback_ui_path: NodePath = ^"../UI/RoomFeedbackUI"
@export var score_tracker_path: NodePath = ^"../RoomScoreTracker"
@export var screen_shake_path: NodePath = ^"../ScreenShake"
@export var camera_path: NodePath = ^"../Camera2D"
@export var stress_path: NodePath = ^"../StressComponent"
@export var stamina_path: NodePath = ^"../StaminaComponent"
@export var equipment_path: NodePath = ^"../EquipmentComponent"
@export var tempo_path: NodePath = ^"../TempoDirector"
@export var commission_path: NodePath = ^"../CommissionDirector"
@export var run_modifier_path: NodePath = ^"../RunModifierDirector"
@export var mop_path: NodePath = ^"../MopComponent"

@export var viewport_height: float = 1080.0
@export var slide_duration: float = 1.15

var mode: int = Mode.ADVENTURE
var current_level_index: int = 0
var current_room_index: int = 0
var total_rooms: int = 0
var _rooms: Array[Node2D] = []
var _level_node: Node = null           # Adventure: yüklenen seviye sahnesinin kökü
var _current_room_node: Node2D         # Endless: aktif prosedürel oda
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
var _commission: CommissionDirector
var _run_modifiers: RunModifierDirector
var _mop: MopComponent


func _ready() -> void:
	_feedback_ui = get_node(feedback_ui_path) as RoomFeedbackUI
	_score_tracker = get_node(score_tracker_path) as RoomScoreTracker
	_shake = get_node(screen_shake_path) as ScreenShake
	_camera = get_node(camera_path) as Camera2D
	_stress = get_node(stress_path) as StressComponent
	_stamina = get_node(stamina_path) as StaminaComponent
	_equipment = get_node_or_null(equipment_path) as EquipmentComponent
	_tempo = get_node_or_null(tempo_path) as TempoDirector
	_commission = get_node_or_null(commission_path) as CommissionDirector
	_run_modifiers = get_node_or_null(run_modifier_path) as RunModifierDirector
	_mop = get_node_or_null(mop_path) as MopComponent

	# Güvenlik: RoomManager altına yanlışlıkla eklenmiş "Room" çocuklarını temizle.
	# Odalar seviye sahnelerinden (Adventure) veya EndlessGenerator'dan gelir.
	for child in get_children():
		if child is Node2D and child.is_in_group("Room"):
			child.queue_free()


# ---------------------------------------------------------------------------
# Koşu başlangıcı
# ---------------------------------------------------------------------------

func start_run(selected_mode: int) -> void:
	mode = selected_mode
	_reset_run_stats()
	position = Vector2.ZERO
	if _commission != null:
		_commission.clear()
	if mode == Mode.ENDLESS and _run_modifiers != null:
		_run_modifiers.reset_run()
	if mode == Mode.ENDLESS:
		_begin_endless()
	else:
		start_adventure_level(0)


func start_adventure_level(level_index: int) -> void:
	mode = Mode.ADVENTURE
	current_level_index = level_index
	_reset_run_stats()
	position = Vector2.ZERO
	if _commission != null:
		_commission.clear()
	await _begin_adventure()


func _reset_run_stats() -> void:
	current_room_index = 0
	_level_total_score = 0
	_rooms_cleared = 0
	_run_max_combo = 0
	_run_start_ms = Time.get_ticks_msec()


# ---------------------------------------------------------------------------
# Adventure
# ---------------------------------------------------------------------------

func _begin_adventure() -> void:
	_load_level(current_level_index)
	_apply_level_equipment()
	_apply_survival_tuning()
	_current_room_node = get_current_room()

	_transitioning = true
	# Tutorial L1: seviye kartı atlanır — Kuzen komisyonu oda 1'de gelir.
	if _commission != null and not LevelData.is_tutorial_level(current_level_index):
		await _commission.present_level_intro(_level_info())
	await _enter_room_present()
	_transitioning = false
	_score_tracker.begin_room()
	emit_current_objective()
	room_transition_finished.emit()


func _load_level(level_index: int) -> void:
	if _level_node != null and is_instance_valid(_level_node):
		_level_node.queue_free()
		_level_node = null

	var path := "res://levels/level_%02d.tscn" % (level_index + 1)
	var scene: PackedScene = load(path)
	if scene == null:
		push_error("RoomManager: seviye sahnesi yüklenemedi: %s" % path)
		return
	_level_node = scene.instantiate()
	add_child(_level_node)

	if _level_node.has_method("build_rooms"):
		_rooms = _level_node.build_rooms(viewport_height)
	else:
		_rooms = []
		for child in _level_node.get_children():
			if child is Node2D and child.is_in_group("Room"):
				_rooms.append(child)
	total_rooms = _rooms.size()


func _apply_level_equipment() -> void:
	if _equipment != null:
		_equipment.set_unlocked_count(LevelData.unlocked_equipment(current_level_index))


func _level_info() -> Dictionary:
	if _level_node != null and _level_node.has_method("get_level_info"):
		return _level_node.get_level_info()
	return LevelData.get_level(current_level_index)


# Aktif odanın twist kuralını + tutorial'ını sun (await edilebilir).
func _enter_room_present() -> void:
	var room := get_current_room()
	if room == null:
		return
	if bool(room.get_meta("force_mop_dirty", false)) and _mop != null:
		_mop.force_dirty(1.0)
	var tutorial := ""
	if room.has_meta("tutorial"):
		tutorial = String(room.get_meta("tutorial"))
	if tutorial != "":
		tutorial_requested.emit(tutorial)
	if _commission != null:
		var commission: Dictionary = {}
		if room.has_meta("commission"):
			commission = room.get_meta("commission")
		await _commission.present(commission, room)


# ---------------------------------------------------------------------------
# Endless
# ---------------------------------------------------------------------------

func _begin_endless() -> void:
	_apply_survival_tuning()
	total_rooms = -1
	if _level_node != null and is_instance_valid(_level_node):
		_level_node.queue_free()
		_level_node = null
	_rooms.clear()
	_current_room_node = _generate_endless_room(0)
	_apply_endless_difficulty(0)
	_score_tracker.begin_room()
	emit_current_objective()
	room_transition_finished.emit()


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


func _advance_endless() -> void:
	var next_index := current_room_index + 1
	var next_room := _generate_endless_room(next_index)

	await _animate_to_next_room()

	var old_room := _current_room_node
	current_room_index = next_index
	_current_room_node = next_room
	_stress.reduce_stress(_stress.current_stress * 0.5)
	_stamina.restore(_stamina.max_stamina * 0.25)
	_apply_endless_difficulty(current_room_index)
	_score_tracker.begin_room()
	emit_current_objective()
	if old_room != null:
		old_room.queue_free()

	_transitioning = false
	room_transition_finished.emit()


# ---------------------------------------------------------------------------
# Ortak akış
# ---------------------------------------------------------------------------

func is_transitioning() -> bool:
	return _transitioning


func get_mode() -> int:
	return mode


func get_level_index() -> int:
	return current_level_index


func get_level_score() -> int:
	return _level_total_score


func get_rooms_cleared() -> int:
	return _rooms_cleared


func get_run_time() -> float:
	return (Time.get_ticks_msec() - _run_start_ms) / 1000.0


func get_run_max_combo() -> int:
	return _run_max_combo


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


func _count_dirt(room: Node2D) -> Vector2i:
	var total := 0
	var remaining := 0
	for child in room.get_children():
		if child.is_in_group("Cleanable") and child.has_method("is_cleaned"):
			if child.get("is_forbidden"):
				continue
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


func _start_room_transition() -> void:
	_transitioning = true
	room_transition_started.emit()
	if _commission != null:
		_commission.clear()

	var result: Dictionary = _score_tracker.finalize_room()
	_level_total_score += result.score
	_rooms_cleared += 1
	_run_max_combo = maxi(_run_max_combo, int(result.get("max_combo", 0)))
	room_cleared.emit(current_room_index, result)

	_shake.shake(0.18)
	await _feedback_ui.show_rating(result)

	if mode == Mode.ENDLESS:
		if _run_modifiers != null:
			var room_combo := int(result.get("max_combo", 0))
			await _run_modifiers.present_draft(room_combo)
		await _advance_endless()
		return

	var is_last_room := current_room_index >= total_rooms - 1
	if is_last_room:
		await _finish_level()
		return

	await _animate_to_next_room()
	current_room_index += 1
	_stress.reduce_stress(_stress.current_stress * 0.5)
	_stamina.restore(_stamina.max_stamina * 0.25)
	await _enter_room_present()
	_transitioning = false
	_score_tracker.begin_room()
	emit_current_objective()
	room_transition_finished.emit()


func _finish_level() -> void:
	var average := _level_total_score / maxi(_rooms_cleared, 1)
	# Hikâye önce — skor kartı diyalogu ezmesin
	if _commission != null:
		await _present_level_outro()
	await _feedback_ui.show_level_summary(_level_total_score, average, _rooms_cleared)
	_apply_survival_tuning(true)
	_transitioning = false
	level_completed.emit(_level_total_score, average)


func _present_level_outro() -> void:
	var info := _level_info()
	var outro: Array = info.get("outro", [])
	if not outro.is_empty():
		await _commission.present_outro(outro)
		return
	# Eski tutorial fallback
	if LevelData.is_tutorial_level(current_level_index):
		await _commission.present_dialogue(
			"Kuzen Marv", "🧰", "Teşekkürler!",
			"Vay be, süpersin! Garaj pırıl pırıl — abur cubur stokumu da... ehem, görmedin diyelim. Bak, arkadaşım bir gargoyle tanıyor, onun da yardıma ihtiyacı varmış."
		)
		await _commission.present_dialogue(
			"Remzi", "🧹", "(iç ses)",
			"Paspası durulamayı öğrendim, cipse hayır demeyi... henüz öğrenmedim. Gargoyle'lar mı? Tamam. Asıl iş başlıyor."
		)


func _apply_survival_tuning(force_normal: bool = false) -> void:
	var soft := (not force_normal) and mode == Mode.ADVENTURE and LevelData.is_tutorial_level(current_level_index)
	if _stress != null:
		_stress.gain_scale = 0.18 if soft else 1.0
	if _stamina != null:
		_stamina.drain_scale = 0.28 if soft else 1.0
		_stamina.regen_scale = 1.8 if soft else 1.0


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
