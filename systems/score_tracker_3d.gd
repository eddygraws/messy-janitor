class_name ScoreTracker3D
extends Node

## Seviye skoru — combo / temizlik / hata / süre / heat.

signal score_changed(score: int)
signal level_scored(result: Dictionary)

var _score: int = 0
var _max_combo: int = 0
var _mistakes: int = 0
var _disposed: int = 0
var _tasks_ok: int = 0
var _tasks_fail: int = 0
var _start_ms: int = 0
var _active: bool = false


func begin_level() -> void:
	_score = 0
	_max_combo = 0
	_mistakes = 0
	_disposed = 0
	_tasks_ok = 0
	_tasks_fail = 0
	_start_ms = Time.get_ticks_msec()
	_active = true
	score_changed.emit(0)


func stop() -> void:
	_active = false


func is_active() -> bool:
	return _active


func get_score() -> int:
	return _score


func on_combo(combo: int) -> void:
	if not _active:
		return
	_max_combo = maxi(_max_combo, combo)
	if combo > 0:
		_add(mini(combo, 10) * 15)


func on_dispose() -> void:
	if not _active:
		return
	_disposed += 1
	_add(40)


func on_junk() -> void:
	if not _active:
		return
	_add(80)


func on_task_ok(combo: int) -> void:
	if not _active:
		return
	_tasks_ok += 1
	_add(80 + mini(combo, 8) * 12)


func on_task_fail() -> void:
	if not _active:
		return
	_tasks_fail += 1
	_mistakes += 1
	_add(-55)


func on_mistake() -> void:
	if not _active:
		return
	_mistakes += 1
	_add(-40)


func finalize(stress_ratio: float = 0.0, daily: bool = false, level_index: int = 0) -> Dictionary:
	_active = false
	var elapsed := (Time.get_ticks_msec() - _start_ms) / 1000.0
	# Hız bonusu: 90 sn altı
	var time_bonus := int(clampf((90.0 - elapsed) * 4.0, 0.0, 280.0))
	# Düşük heat bonusu
	var heat_bonus := int((1.0 - clampf(stress_ratio, 0.0, 1.0)) * 120.0)
	var clean_bonus := 150 if _mistakes == 0 else 0
	_score = maxi(0, _score + time_bonus + heat_bonus + clean_bonus)
	var grade := _grade_for(_score)
	var result := {
		"score": _score,
		"grade": grade["label"],
		"grade_color": grade["color"],
		"max_combo": _max_combo,
		"mistakes": _mistakes,
		"disposed": _disposed,
		"tasks_ok": _tasks_ok,
		"tasks_fail": _tasks_fail,
		"elapsed": elapsed,
		"time_bonus": time_bonus,
		"heat_bonus": heat_bonus,
		"clean_bonus": clean_bonus,
		"daily": daily,
		"level_index": level_index,
	}
	level_scored.emit(result)
	return result


func _add(amount: int) -> void:
	_score = maxi(0, _score + amount)
	score_changed.emit(_score)


func _grade_for(score: int) -> Dictionary:
	if score >= 2200:
		return {"label": "S", "color": Color(1.0, 0.85, 0.3)}
	if score >= 1600:
		return {"label": "A", "color": Color(0.45, 1.0, 0.55)}
	if score >= 1100:
		return {"label": "B", "color": Color(0.5, 0.85, 1.0)}
	if score >= 700:
		return {"label": "C", "color": Color(0.85, 0.85, 0.9)}
	return {"label": "D", "color": Color(1.0, 0.45, 0.4)}
