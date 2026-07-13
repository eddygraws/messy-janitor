class_name StressComponent
extends Node

signal stress_changed(current: float, maximum: float)
signal mistake_registered
signal stress_critical
signal stress_exploded

@export var max_stress: float = 100.0
@export var mistake_stress: float = 12.0
@export var critical_threshold: float = 0.85

var current_stress: float = 0.0
var _exploded: bool = false


func register_mistake() -> void:
	if _exploded:
		return
	mistake_registered.emit()
	add_stress(mistake_stress)


func add_stress(amount: float) -> void:
	if _exploded:
		return

	var before := current_stress
	current_stress = minf(max_stress, current_stress + amount)
	stress_changed.emit(current_stress, max_stress)

	var critical_level := max_stress * critical_threshold
	if before < critical_level and current_stress >= critical_level:
		stress_critical.emit()
	if current_stress >= max_stress and not _exploded:
		_exploded = true
		stress_exploded.emit()


func reduce_stress(amount: float) -> void:
	current_stress = maxf(0.0, current_stress - amount)
	stress_changed.emit(current_stress, max_stress)


func get_stress_ratio() -> float:
	return current_stress / max_stress


func reset_stress() -> void:
	current_stress = 0.0
	_exploded = false
	stress_changed.emit(current_stress, max_stress)
