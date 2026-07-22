class_name RunCombo3D
extends Node

## 3D için hafif combo — 2D ComboComponent'e bağımlı değil.

signal combo_changed(combo: int)
signal combo_milestone(combo: int)

@export var milestone_step: int = 3

var _combo: int = 0


func get_combo() -> int:
	return _combo


func reset() -> void:
	_combo = 0
	combo_changed.emit(0)


func register_success() -> void:
	_combo += 1
	combo_changed.emit(_combo)
	if milestone_step > 0 and _combo % milestone_step == 0:
		combo_milestone.emit(_combo)


func register_fail() -> void:
	_combo = 0
	combo_changed.emit(0)
