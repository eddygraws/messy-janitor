class_name RoomScoreTracker
extends Node

signal room_finalized(result: Dictionary)

@export var stress_path: NodePath = ^"../StressComponent"
@export var router_path: NodePath = ^"../CursorClickerRouter"
@export var combo_path: NodePath = ^"../ComboComponent"
@export var risk_path: NodePath = ^"../RiskModeComponent"
@export var modifier_path: NodePath = ^"../RunModifierDirector"

var _stress: StressComponent
var _router: CursorClickRouter
var _combo: ComboComponent
var _risk: RiskModeComponent
var _modifiers: RunModifierDirector
var _risk_used: bool = false

var _mistakes: int = 0
var _junk_eaten: int = 0
var _panic_events: int = 0
var _max_combo: int = 0
var _combo_points: int = 0
var _mistake_penalty: int = 0
var _mistake_streak: int = 0
var _prev_combo: int = 0
var _room_start_ms: int = 0


func _ready() -> void:
	_stress = get_node(stress_path) as StressComponent
	_router = get_node(router_path) as CursorClickRouter
	_combo = get_node_or_null(combo_path) as ComboComponent
	_stress.mistake_registered.connect(_on_mistake)
	_stress.stress_critical.connect(_on_panic)
	_router.junk_food_tempted.connect(_on_junk_food)
	if _combo != null:
		_combo.combo_changed.connect(_on_combo_changed)
	_risk = get_node_or_null(risk_path) as RiskModeComponent
	_modifiers = get_node_or_null(modifier_path) as RunModifierDirector
	if _risk != null:
		_risk.risk_changed.connect(_on_risk_changed)
	begin_room()


func _on_risk_changed(active: bool) -> void:
	if active:
		_risk_used = true


func begin_room() -> void:
	_mistakes = 0
	_junk_eaten = 0
	_panic_events = 0
	_max_combo = 0
	_combo_points = 0
	_mistake_penalty = 0
	_mistake_streak = 0
	_prev_combo = _combo.get_combo() if _combo != null else 0
	_room_start_ms = Time.get_ticks_msec()
	_risk_used = _risk != null and _risk.is_active()


func finalize_room() -> Dictionary:
	var elapsed := (Time.get_ticks_msec() - _room_start_ms) / 1000.0
	var stress_ratio := _stress.get_stress_ratio()

	var breakdown := RoomRating.calculate_score(
		_combo_points, _mistake_penalty, _junk_eaten,
		_panic_events, stress_ratio, elapsed,
		_mistakes == 0 and _junk_eaten == 0
	)
	var base_score: int = breakdown.total
	var risk_mult := _risk.get_score_multiplier() if (_risk != null and _risk_used) else 1.0
	var score := int(round(base_score * risk_mult))
	var grade_data := RoomRating.get_grade_data(score)

	var result := {
		"score": score,
		"grade": grade_data.label,
		"grade_color": grade_data.color,
		"subtitle": RoomRating.build_subtitle(_max_combo, _mistakes, _junk_eaten),
		"mistakes": _mistakes,
		"junk_eaten": _junk_eaten,
		"max_combo": _max_combo,
		"elapsed": elapsed,
		"stress_ratio": stress_ratio,
		"risk_used": _risk_used,
		"risk_multiplier": risk_mult,
		"breakdown": breakdown,
	}
	room_finalized.emit(result)
	return result


# Combo yükseldiğinde (yani doğru temizlik olduğunda) puan biriktir.
func _on_combo_changed(combo: int) -> void:
	if combo > _prev_combo:
		var pts := mini(combo, 8) * 25
		if _modifiers != null:
			pts = int(round(float(pts) * _modifiers.get_mult(&"score_combo_mult", 1.0)))
		_combo_points += pts
		_max_combo = maxi(_max_combo, combo)
	_prev_combo = combo


func _on_mistake() -> void:
	_mistakes += 1
	_mistake_penalty += 60 + _mistake_streak * 25
	_mistake_streak += 1


func _on_junk_food(_world_pos: Vector2) -> void:
	_junk_eaten += 1


func _on_panic() -> void:
	_panic_events += 1
