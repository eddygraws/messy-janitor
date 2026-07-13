class_name StaminaComponent
extends Node

signal stamina_changed(current: float, maximum: float)
signal stamina_depleted
signal stamina_recovered

@export var max_stamina: float = 100.0
@export var drain_rate: float = 18.0
@export var passive_regen: float = 6.0
@export var min_control_stamina: float = 25.0

var current_stamina: float = 100.0
var _was_depleted: bool = false


func _ready() -> void:
	current_stamina = max_stamina
	stamina_changed.emit(current_stamina, max_stamina)


func _process(delta: float) -> void:
	if current_stamina < max_stamina:
		restore(passive_regen * delta)


func get_ratio() -> float:
	return current_stamina / max_stamina if max_stamina > 0.0 else 0.0


func get_control_factor() -> float:
	if current_stamina >= min_control_stamina:
		return 1.0
	return clampf(current_stamina / min_control_stamina, 0.05, 1.0)


func drain_instant(amount: float) -> void:
	var before := current_stamina
	current_stamina = maxf(0.0, current_stamina - amount)
	if current_stamina == before:
		return

	stamina_changed.emit(current_stamina, max_stamina)
	if current_stamina <= 0.0 and not _was_depleted:
		_was_depleted = true
		stamina_depleted.emit()


func drain(delta: float, rate_multiplier: float = 1.0) -> void:
	var before := current_stamina
	current_stamina = maxf(0.0, current_stamina - drain_rate * rate_multiplier * delta)
	if current_stamina == before:
		return

	stamina_changed.emit(current_stamina, max_stamina)
	if current_stamina <= 0.0 and not _was_depleted:
		_was_depleted = true
		stamina_depleted.emit()


func restore(amount: float) -> void:
	var before := current_stamina
	current_stamina = minf(max_stamina, current_stamina + amount)
	if current_stamina == before:
		return

	stamina_changed.emit(current_stamina, max_stamina)
	if _was_depleted and current_stamina > min_control_stamina * 0.5:
		_was_depleted = false
		stamina_recovered.emit()


func reset_stamina() -> void:
	current_stamina = max_stamina
	_was_depleted = false
	stamina_changed.emit(current_stamina, max_stamina)
