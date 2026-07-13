class_name EquipmentComponent
extends Node

signal equipment_changed(type: int)
signal unlocked_changed(count: int)

# Sıra CleanableObject.EQ_* sabitleriyle AYNI olmalı.
enum Type { MOP, BROOM, BRUSH, SPRAY, TWEEZERS }

const LABELS: Array[String] = ["Paspas", "Süpürge", "Fırça", "Sprey+Bez", "Cımbız"]
const ICONS: Array[String] = ["🧹", "🧺", "🪥", "🧴", "🔬"]
const COLORS: Array[Color] = [
	Color(0.85, 0.82, 0.7),
	Color(0.75, 0.6, 0.4),
	Color(0.6, 0.85, 0.95),
	Color(0.6, 0.9, 0.8),
	Color(0.95, 0.75, 0.8),
]

@export var switch_lock_time: float = 0.16   # alet değişiminde kısa "geçiş" donması

var current: int = 0
var unlocked_count: int = 1
var _switch_lock: float = 0.0


func _ready() -> void:
	equipment_changed.emit(current)
	unlocked_changed.emit(unlocked_count)


func _process(delta: float) -> void:
	if _switch_lock > 0.0:
		_switch_lock = maxf(0.0, _switch_lock - delta)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return

	var idx := -1
	match key.keycode:
		KEY_1: idx = 0
		KEY_2: idx = 1
		KEY_3: idx = 2
		KEY_4: idx = 3
		KEY_5: idx = 4
	if idx >= 0 and idx < unlocked_count:
		set_current(idx)


func set_current(idx: int) -> void:
	if idx == current or idx < 0 or idx >= unlocked_count:
		return
	current = idx
	_switch_lock = switch_lock_time
	equipment_changed.emit(current)


func is_switching() -> bool:
	return _switch_lock > 0.0


func get_current() -> int:
	return current


func set_unlocked_count(count: int) -> void:
	var clamped := clampi(count, 1, Type.size())
	if clamped == unlocked_count:
		return
	unlocked_count = clamped
	unlocked_changed.emit(unlocked_count)
	if current >= unlocked_count:
		set_current(0)


func is_unlocked(idx: int) -> bool:
	return idx < unlocked_count
