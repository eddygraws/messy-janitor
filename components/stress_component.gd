class_name StressComponent
extends Node

signal stress_changed(current: float, maximum: float)
signal mistake_registered
signal stress_critical
signal stress_exploded
signal panic_mode_entered
signal panic_mode_exited

@export var max_stress: float = 100.0
@export var mistake_stress: float = 12.0
@export var panic_threshold: float = 0.7
@export var critical_threshold: float = 0.85

var current_stress: float = 0.0
var _exploded: bool = false
var _in_panic: bool = false
var mistake_multiplier: float = 1.0   # Riskli Temizlik modu bunu yükseltir
## Tutorial L1: 0.2 gibi düşük tut — sistem var ama cezalandırmaz
var gain_scale: float = 1.0


func register_mistake() -> void:
	if _exploded:
		return
	mistake_registered.emit()
	add_stress(mistake_stress * mistake_multiplier)


func add_stress(amount: float) -> void:
	if _exploded:
		return

	var before := current_stress
	current_stress = minf(max_stress, current_stress + amount * gain_scale)
	stress_changed.emit(current_stress, max_stress)
	_update_panic()

	var critical_level := max_stress * critical_threshold
	if before < critical_level and current_stress >= critical_level:
		stress_critical.emit()
	if current_stress >= max_stress and not _exploded:
		_exploded = true
		stress_exploded.emit()


# Sugar crash: junk food'un gecikmeli stres cezası.
func add_delayed_stress(amount: float, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not _exploded and is_inside_tree():
		add_stress(amount)


func reduce_stress(amount: float) -> void:
	current_stress = maxf(0.0, current_stress - amount)
	stress_changed.emit(current_stress, max_stress)
	_update_panic()


func get_stress_ratio() -> float:
	return current_stress / max_stress


func is_in_panic() -> bool:
	return _in_panic


func reset_stress() -> void:
	current_stress = 0.0
	_exploded = false
	stress_changed.emit(current_stress, max_stress)
	_update_panic()


func _update_panic() -> void:
	var ratio := current_stress / max_stress
	if not _in_panic and ratio >= panic_threshold:
		_in_panic = true
		panic_mode_entered.emit()
	elif _in_panic and ratio < panic_threshold:
		_in_panic = false
		panic_mode_exited.emit()
