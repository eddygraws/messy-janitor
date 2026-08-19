class_name RoomTimer3D
extends Node

## Seviye kronometresi — yukarı sayar; fail yok.
## par_seconds = eski time_limit; rozet eşikleri için referans.

signal time_changed(elapsed: float)

var _elapsed: float = 0.0
var _par_seconds: float = 0.0
var _running: bool = false
var _paused: bool = false


func _process(delta: float) -> void:
	if not _running or _paused:
		return
	_elapsed += delta
	time_changed.emit(_elapsed)


## seconds = rozet par süresi (eski hard clock limiti)
func start(seconds: float) -> void:
	_par_seconds = maxf(0.0, seconds)
	_elapsed = 0.0
	_running = true
	_paused = false
	time_changed.emit(_elapsed)


func stop() -> void:
	_running = false
	_paused = false


func pause() -> void:
	if _running:
		_paused = true


func resume() -> void:
	if _paused:
		_paused = false
		_running = true


func is_running() -> bool:
	return _running and not _paused


func is_expired() -> bool:
	return false


func is_active() -> bool:
	return _running or _paused


func get_seconds_left() -> float:
	## Eski API: kalan süre yok — elapsed döner (HUD uyarlandı)
	return _elapsed


func get_elapsed() -> float:
	return _elapsed


func get_base_seconds() -> float:
	return _par_seconds


func get_par_seconds() -> float:
	return _par_seconds


func add_time(_seconds: float) -> void:
	## Rozet modunda süre kazan/kaybet yok
	pass


func on_clean() -> void:
	pass


func on_combo_milestone() -> void:
	pass


func on_mistake() -> void:
	pass
