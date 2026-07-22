class_name CurseDirector3D
extends Node

## Günlük / seans lanetleri — mevcut export değerlerine çarpan enjekte eder.
## Roguelite kimlik: her gün aynı seed → aynı lanet(ler).

signal curses_rolled(curses: Array)
signal curses_cleared

const SAVE_PATH := "user://messy3d_curses.cfg"

## mods anahtarları:
## stress_gain, carry_speed, stack_falloff, stop_freq, task_interval,
## task_duration, fall_rate, slip_duration, scrub_cooldown

var _active: Array[Dictionary] = []
var _applied: bool = false
var _hard_mode: bool = false # 2 lanet


func set_hard_mode(on: bool) -> void:
	_hard_mode = on


func is_hard_mode() -> bool:
	return _hard_mode


func get_active() -> Array[Dictionary]:
	return _active.duplicate(true)


func has_curses() -> bool:
	return not _active.is_empty()


func describe_active() -> String:
	if _active.is_empty():
		return ""
	var parts: PackedStringArray = []
	for c in _active:
		parts.append("%s %s" % [String(c.get("icon", "☠")), String(c.get("title", "?"))])
	return " · ".join(parts)


func day_key() -> int:
	var d := Time.get_datetime_dict_from_system()
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)


## Günlük seed ile 1–2 lanet seç (aynı gün herkese aynı).
func roll_daily(force_reroll: bool = false) -> Array[Dictionary]:
	if not force_reroll and not _active.is_empty():
		return _active
	var pool := _pool()
	var rng := RandomNumberGenerator.new()
	var indices: Array[int] = []
	for i in pool.size():
		indices.append(i)
	# Fisher-Yates — günlük seed
	rng.seed = hash("messy_janitor_curse_%d" % day_key())
	for i in range(indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	var count := 2 if _hard_mode else 1
	_active.clear()
	for n in mini(count, indices.size()):
		_active.append(pool[indices[n]].duplicate(true))
	curses_rolled.emit(_active)
	return _active


func clear() -> void:
	_active.clear()
	_applied = false
	curses_cleared.emit()


func combined_mods() -> Dictionary:
	var out := {
		"stress_gain": 1.0,
		"carry_speed": 1.0,
		"stack_falloff": 1.0,
		"stop_freq": 1.0,
		"task_interval": 1.0,
		"task_duration": 1.0,
		"fall_rate": 1.0,
		"slip_duration": 1.0,
		"scrub_cooldown": 1.0,
	}
	for c in _active:
		var mods: Dictionary = c.get("mods", {}) as Dictionary
		for k in mods:
			if out.has(k):
				out[k] = float(out[k]) * float(mods[k])
	return out


func apply_to(
	stress: StressComponent,
	player: PlayerCharacter3D,
	micro: MicroTaskDirector,
	hazards: HazardDirector
) -> void:
	if _active.is_empty():
		roll_daily()
	var m := combined_mods()
	if stress != null:
		stress.gain_scale = 0.85 * float(m.get("stress_gain", 1.0))
	if player != null:
		player.apply_curse_mods(
			float(m.get("carry_speed", 1.0)),
			float(m.get("stack_falloff", 1.0)),
			float(m.get("scrub_cooldown", 1.0))
		)
	if micro != null:
		micro.apply_curse_mods(
			float(m.get("task_interval", 1.0)),
			float(m.get("task_duration", 1.0)),
			float(m.get("stop_freq", 1.0))
		)
	if hazards != null:
		hazards.apply_curse_mods(
			float(m.get("fall_rate", 1.0)),
			float(m.get("slip_duration", 1.0))
		)
	_applied = true


func revert_defaults(
	stress: StressComponent,
	player: PlayerCharacter3D,
	micro: MicroTaskDirector,
	hazards: HazardDirector
) -> void:
	if stress != null:
		stress.gain_scale = 0.85
	if player != null:
		player.clear_curse_mods()
	if micro != null:
		micro.clear_curse_mods()
	if hazards != null:
		hazards.clear_curse_mods()
	_applied = false


func _pool() -> Array[Dictionary]:
	return [
		{
			"id": "heavy_boxes",
			"title": "Ağır Kolliler",
			"desc": "Kutular %30 daha ağır — taşımak yavaşlar.",
			"icon": "📦",
			"mods": {"carry_speed": 0.70, "stack_falloff": 0.85},
		},
		{
			"id": "stop_spam",
			"title": "DUR! Yağmuru",
			"desc": "DUR! emri ~2× daha sık geliyor.",
			"icon": "🛑",
			"mods": {"stop_freq": 2.0, "task_interval": 0.85},
		},
		{
			"id": "stress_spike",
			"title": "Sinirli Gün",
			"desc": "Stres birikimi %25 daha hızlı.",
			"icon": "💢",
			"mods": {"stress_gain": 1.25},
		},
		{
			"id": "short_fuse",
			"title": "Kısa Fitil",
			"desc": "Emir süreleri %20 daha kısa.",
			"icon": "⏳",
			"mods": {"task_duration": 0.80},
		},
		{
			"id": "falling_sky",
			"title": "Düşen Tavan",
			"desc": "Raftan düşen eşya daha sık.",
			"icon": "💥",
			"mods": {"fall_rate": 1.55},
		},
		{
			"id": "eternal_ice",
			"title": "Sonsuz Buz",
			"desc": "Kaygan zemin daha uzun sürer.",
			"icon": "🧊",
			"mods": {"slip_duration": 1.45},
		},
		{
			"id": "sticky_mop",
			"title": "Yapışkan Paspas",
			"desc": "Ovalama mash’i biraz daha yavaş.",
			"icon": "🧽",
			"mods": {"scrub_cooldown": 1.35},
		},
		{
			"id": "tower_tax",
			"title": "Kule Vergisi",
			"desc": "Stack’li taşıma çok daha ağır.",
			"icon": "🏗",
			"mods": {"stack_falloff": 0.72, "carry_speed": 0.88},
		},
	]
