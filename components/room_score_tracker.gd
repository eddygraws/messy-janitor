class_name RoomScoreTracker
extends Node

signal room_finalized(result: Dictionary)
signal combo_changed(combo: int)

@export var stress_path: NodePath = ^"../StressComponent"
@export var router_path: NodePath = ^"../CursorClickerRouter"

var _stress: StressComponent
var _router: CursorClickRouter

var _cleans: int = 0
var _mistakes: int = 0
var _junk_eaten: int = 0
var _panic_events: int = 0            # stres kritiğe kaç kez girdi
var _combo: int = 0
var _max_combo: int = 0
var _combo_points: int = 0
var _mistake_penalty: int = 0
var _mistake_streak: int = 0
var _room_start_ms: int = 0


func _ready() -> void:
	_stress = get_node(stress_path) as StressComponent
	_router = get_node(router_path) as CursorClickRouter
	_stress.mistake_registered.connect(_on_mistake)
	_stress.stress_critical.connect(_on_panic)
	_router.object_cleaned.connect(_on_cleaned)
	_router.junk_food_tempted.connect(_on_junk_food)
	begin_room()


func begin_room() -> void:
	_cleans = 0
	_mistakes = 0
	_junk_eaten = 0
	_panic_events = 0
	_combo = 0
	_max_combo = 0
	_combo_points = 0
	_mistake_penalty = 0
	_mistake_streak = 0
	_room_start_ms = Time.get_ticks_msec()
	combo_changed.emit(0)


func get_combo() -> int:
	return _combo


func finalize_room() -> Dictionary:
	var elapsed := (Time.get_ticks_msec() - _room_start_ms) / 1000.0
	var stress_ratio := _stress.get_stress_ratio()

	var breakdown := RoomRating.calculate_score(
		_combo_points, _mistake_penalty, _junk_eaten,
		_panic_events, stress_ratio, elapsed,
		_mistakes == 0 and _junk_eaten == 0
	)
	var score: int = breakdown.total
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
		"breakdown": breakdown,
	}
	room_finalized.emit(result)
	return result


func _on_cleaned(_pos: Vector2) -> void:
	_cleans += 1
	_combo += 1
	_max_combo = maxi(_max_combo, _combo)
	_mistake_streak = 0
	# Combo büyüdükçe artan bonus (kademeli, tavanlı)
	_combo_points += mini(_combo, 8) * 25
	combo_changed.emit(_combo)


func _on_mistake() -> void:
	_mistakes += 1
	# Artan ceza: peş peşe hatalar giderek daha çok yakar
	_mistake_penalty += 60 + _mistake_streak * 25
	_mistake_streak += 1
	# Combo kırılır (kaybetme hissi)
	_combo = 0
	combo_changed.emit(0)


func _on_junk_food(_world_pos: Vector2) -> void:
	_junk_eaten += 1
	_combo = 0
	combo_changed.emit(0)


func _on_panic() -> void:
	_panic_events += 1
