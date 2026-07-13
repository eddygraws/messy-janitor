class_name ComboComponent
extends Node

signal combo_changed(combo: int)
signal combo_milestone(combo: int)

@export var stamina_path: NodePath = ^"../StaminaComponent"
@export var stress_path: NodePath = ^"../StressComponent"
@export var router_path: NodePath = ^"../CursorClickerRouter"

@export var milestone_step: int = 5
@export var milestone_stamina: float = 14.0
@export var break_min_combo: int = 3       # bu combodan sonra kırılırsa ekstra stres
@export var break_extra_stress: float = 8.0

var _combo: int = 0
var _stamina: StaminaComponent
var _stress: StressComponent
var _router: CursorClickRouter


func _ready() -> void:
	_stamina = get_node_or_null(stamina_path) as StaminaComponent
	_stress = get_node_or_null(stress_path) as StressComponent
	_router = get_node_or_null(router_path) as CursorClickRouter
	if _router != null:
		_router.object_cleaned.connect(_on_correct)
		_router.junk_food_tempted.connect(_on_junk_break)
	if _stress != null:
		_stress.mistake_registered.connect(_on_mistake_break)
	combo_changed.emit(0)


func get_combo() -> int:
	return _combo


func reset() -> void:
	_combo = 0
	combo_changed.emit(0)


func _on_correct(_pos: Vector2) -> void:
	_combo += 1
	combo_changed.emit(_combo)
	if milestone_step > 0 and _combo % milestone_step == 0:
		if _stamina != null:
			_stamina.restore(milestone_stamina)
		combo_milestone.emit(_combo)


func _on_mistake_break() -> void:
	# Yüksek combodayken hata yapmak fazladan stres yükler (sert ceza).
	if _combo >= break_min_combo and _stress != null:
		_stress.add_stress(break_extra_stress)
	_break()


func _on_junk_break(_pos: Vector2) -> void:
	_break()


func _break() -> void:
	if _combo == 0:
		return
	_combo = 0
	combo_changed.emit(0)
