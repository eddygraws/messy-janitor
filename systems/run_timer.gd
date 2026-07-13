class_name RunTimerComponent
extends Node

signal time_changed(seconds_left: float)
signal time_expired

@export var stress_path: NodePath = ^"../StressComponent"
@export var router_path: NodePath = ^"../CursorClickerRouter"
@export var combo_path: NodePath = ^"../ComboComponent"
@export var room_manager_path: NodePath = ^"../RoomManager"
@export var modifier_path: NodePath = ^"../RunModifierDirector"

@export var adventure_start: float = 240.0
@export var endless_start: float = 300.0
@export var clean_bonus: float = 2.5
@export var combo_milestone_bonus: float = 6.0
@export var mistake_penalty: float = 5.0
@export var wrong_tool_penalty: float = 3.5
@export var skill_miss_penalty: float = 4.0

var _seconds_left: float = 0.0
var _running: bool = false
var _expired: bool = false
var _stress: StressComponent
var _modifiers: RunModifierDirector


func _ready() -> void:
	_stress = get_node_or_null(stress_path) as StressComponent
	_modifiers = get_node_or_null(modifier_path) as RunModifierDirector
	var router := get_node_or_null(router_path) as CursorClickRouter
	if router != null:
		router.object_cleaned.connect(_on_clean)
		router.wrong_tool.connect(func(_p: Vector2) -> void: _add_time(-wrong_tool_penalty))
	var combo := get_node_or_null(combo_path) as ComboComponent
	if combo != null:
		combo.combo_milestone.connect(_on_combo_milestone)
	if _stress != null:
		_stress.mistake_registered.connect(_on_mistake)
	var rm := get_node_or_null(room_manager_path)
	if rm != null:
		if rm.has_signal("room_transition_started"):
			rm.room_transition_started.connect(_pause)
		if rm.has_signal("room_transition_finished"):
			rm.room_transition_finished.connect(_resume)


func _process(delta: float) -> void:
	if not _running or _expired:
		return
	_seconds_left -= delta
	if _seconds_left <= 0.0:
		_seconds_left = 0.0
		_running = false
		_expired = true
		time_changed.emit(0.0)
		time_expired.emit()
		return
	time_changed.emit(_seconds_left)


func start_run(mode: int) -> void:
	_expired = false
	_running = true
	if mode == 1:  # Endless
		_seconds_left = endless_start
	else:
		_seconds_left = adventure_start
	time_changed.emit(_seconds_left)


func stop() -> void:
	_running = false


func is_expired() -> bool:
	return _expired


func get_seconds_left() -> float:
	return _seconds_left


func add_time(seconds: float) -> void:
	if _expired:
		return
	_seconds_left = maxf(0.0, _seconds_left + seconds)
	time_changed.emit(_seconds_left)


func _add_time(seconds: float) -> void:
	add_time(seconds)


func _on_clean(_pos: Vector2) -> void:
	var bonus := clean_bonus
	if _modifiers != null:
		bonus += _modifiers.get_add(&"clean_time_add", 0.0)
	add_time(bonus)


func _on_combo_milestone(_combo: int) -> void:
	var bonus := combo_milestone_bonus
	if _modifiers != null:
		bonus += _modifiers.get_add(&"milestone_time_add", 0.0)
	add_time(bonus)


func _on_mistake() -> void:
	add_time(-mistake_penalty)


func on_skill_miss() -> void:
	add_time(-skill_miss_penalty)


func _pause() -> void:
	if not _expired:
		_running = false


func _resume() -> void:
	if not _expired and _seconds_left > 0.0:
		_running = true


func pause_for_menu() -> void:
	_pause()


func resume_after_menu() -> void:
	_resume()
