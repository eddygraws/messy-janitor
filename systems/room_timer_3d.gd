class_name RoomTimer3D
extends Node

## Seviye hard clock — combo/temizlikle uzar, hatayla kısalır; 0 = fail.

signal time_changed(seconds_left: float)
signal time_expired
signal time_delta(amount: float)

@export var clean_bonus: float = 1.5
@export var combo_milestone_bonus: float = 4.0
@export var mistake_penalty: float = 4.0
@export var max_multiplier: float = 1.6

var _seconds_left: float = 0.0
var _base_seconds: float = 0.0
var _running: bool = false
var _paused: bool = false
var _expired: bool = false


func _process(delta: float) -> void:
	if not _running or _paused or _expired:
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


func start(seconds: float) -> void:
	_base_seconds = maxf(1.0, seconds)
	_seconds_left = _base_seconds
	_running = true
	_paused = false
	_expired = false
	time_changed.emit(_seconds_left)


func stop() -> void:
	_running = false
	_paused = false


func pause() -> void:
	if _running and not _expired:
		_paused = true


func resume() -> void:
	if not _expired and _seconds_left > 0.0:
		_paused = false
		_running = true


func is_running() -> bool:
	return _running and not _paused and not _expired


func is_expired() -> bool:
	return _expired


func is_active() -> bool:
	return (_running or _paused) and not _expired and _seconds_left > 0.0


func get_seconds_left() -> float:
	return _seconds_left


func get_base_seconds() -> float:
	return _base_seconds


func add_time(seconds: float) -> void:
	if _expired or seconds == 0.0:
		return
	if not _running and not _paused:
		return
	var cap := _base_seconds * max_multiplier
	var before := _seconds_left
	_seconds_left = clampf(_seconds_left + seconds, 0.0, cap)
	if is_equal_approx(before, _seconds_left):
		return
	time_changed.emit(_seconds_left)
	time_delta.emit(_seconds_left - before)
	if _seconds_left <= 0.0:
		_seconds_left = 0.0
		_running = false
		_expired = true
		time_expired.emit()


func on_clean() -> void:
	add_time(clean_bonus)


func on_combo_milestone() -> void:
	add_time(combo_milestone_bonus)


func on_mistake() -> void:
	add_time(-mistake_penalty)
