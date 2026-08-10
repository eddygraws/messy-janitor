class_name ScoreTracker3D
extends Node

## Seviye skoru — combo / temizlik / hata / süre / heat.
## Coin ayrı: run içi toplama + bitiş payout (skor ≠ cüzdan).

signal score_changed(score: int)
signal level_scored(result: Dictionary)
signal run_coins_changed(run_coins: int)

var _score: int = 0
var _max_combo: int = 0
var _mistakes: int = 0
var _disposed: int = 0
var _tasks_ok: int = 0
var _tasks_fail: int = 0
var _junk_eaten: int = 0
var _pickup_coins: int = 0
var _star_bonus_coins: int = 0
var _start_ms: int = 0
var _active: bool = false


func begin_level() -> void:
	_score = 0
	_max_combo = 0
	_mistakes = 0
	_disposed = 0
	_tasks_ok = 0
	_tasks_fail = 0
	_junk_eaten = 0
	_pickup_coins = 0
	_star_bonus_coins = 0
	_start_ms = Time.get_ticks_msec()
	_active = true
	score_changed.emit(0)
	run_coins_changed.emit(0)


func stop() -> void:
	_active = false


func is_active() -> bool:
	return _active


func get_score() -> int:
	return _score


func get_run_bonus_coins() -> int:
	return _pickup_coins + _star_bonus_coins + _junk_eaten


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
	_junk_eaten += 1
	_add(80)
	run_coins_changed.emit(get_run_bonus_coins())


func on_coin_pickup(amount: int = 1) -> void:
	if not _active:
		return
	_pickup_coins += maxi(1, amount)
	run_coins_changed.emit(get_run_bonus_coins())


## Yıldızlı emir tamamlanınca — stack yıldızları kadar bonus coin.
func on_star_task(star_units: int) -> void:
	if not _active:
		return
	var bonus := maxi(0, star_units - 1)  # ★ = 0, ★★ = 1, ★★★ = 2
	if bonus <= 0:
		return
	_star_bonus_coins += bonus
	run_coins_changed.emit(get_run_bonus_coins())


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
	var time_bonus := int(clampf((90.0 - elapsed) * 4.0, 0.0, 280.0))
	var heat_bonus := int((1.0 - clampf(stress_ratio, 0.0, 1.0)) * 120.0)
	var clean_bonus := 150 if _mistakes == 0 else 0
	_score = maxi(0, _score + time_bonus + heat_bonus + clean_bonus)
	var grade := _grade_for(_score)
	var coin_payout := _compute_coin_payout()
	var result := {
		"score": _score,
		"grade": grade["label"],
		"grade_color": grade["color"],
		"max_combo": _max_combo,
		"mistakes": _mistakes,
		"disposed": _disposed,
		"tasks_ok": _tasks_ok,
		"tasks_fail": _tasks_fail,
		"junk_eaten": _junk_eaten,
		"elapsed": elapsed,
		"time_bonus": time_bonus,
		"heat_bonus": heat_bonus,
		"clean_bonus": clean_bonus,
		"daily": daily,
		"level_index": level_index,
		"coins_earned": coin_payout["total"],
		"coins_base": coin_payout["base"],
		"coins_pickup": coin_payout["pickup"],
		"coins_star": coin_payout["star"],
		"coins_junk": coin_payout["junk"],
		"coins_clean": coin_payout["clean"],
		"coins_combo": coin_payout["combo"],
	}
	level_scored.emit(result)
	return result


## Skordan türetilmiş + yan ödüller. Skor cüzdana yazılmaz.
func _compute_coin_payout() -> Dictionary:
	var base := 6 + int(_score / 140.0)
	base = clampi(base, 4, 28)
	var combo_c := mini(_max_combo, 12)
	var clean_c := 5 if _mistakes == 0 else 0
	var pickup := _pickup_coins
	var star := _star_bonus_coins
	var junk := _junk_eaten
	var total := base + combo_c + clean_c + pickup + star + junk
	total = maxi(4, total)
	return {
		"total": total,
		"base": base,
		"combo": combo_c,
		"clean": clean_c,
		"pickup": pickup,
		"star": star,
		"junk": junk,
	}


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
