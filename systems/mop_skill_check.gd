class_name MopSkillCheckDirector
extends Node

signal check_started
signal check_resolved(tier: int)  # 0=miss 1=good 2=great

@export var mop_path: NodePath = ^"../MopComponent"
@export var stress_path: NodePath = ^"../StressComponent"
@export var run_timer_path: NodePath = ^"../RunTimer"
@export var ui_path: NodePath = ^"../UI/MopSkillCheckUI"

## İki skill check arası minimum bekleme (saniye).
@export_group("Skill Check Sıklığı")
@export_range(0.4, 6.0, 0.1, "suffix:s") var interval_min: float = 1.3
## İki skill check arası maksimum bekleme (saniye).
@export_range(0.4, 8.0, 0.1, "suffix:s") var interval_max: float = 2.4

## Genel ibre yavaşlatma/hızlandırma. 0.5 = yarı hız, 1.0 = normal, 2.0 = iki kat hız.
@export_group("Genel Zorluk")
@export_range(0.25, 2.5, 0.05) var needle_speed_multiplier: float = 0.85
## Süre limiti çarpanı. 1.25 = %25 daha fazla tepki süresi.
@export_range(0.5, 2.5, 0.05) var time_limit_multiplier: float = 1.2

@export_group("Ödül / Ceza")
@export var miss_stress: float = 10.0
@export var skill_great_time: float = 3.5
@export var skill_good_time: float = 2.0

var _mop: MopComponent
var _stress: StressComponent
var _timer: RunTimerComponent
var _ui: MopSkillCheckUI
var _active: bool = false
var _rinsing: bool = false
var _cooldown: float = 0.0


func _ready() -> void:
	_mop = get_node_or_null(mop_path) as MopComponent
	_stress = get_node_or_null(stress_path) as StressComponent
	_timer = get_node_or_null(run_timer_path) as RunTimerComponent
	_ui = get_node_or_null(ui_path) as MopSkillCheckUI
	if _ui != null:
		_ui.attempt_pressed.connect(_on_attempt)


func is_active() -> bool:
	return _active


func set_rinsing(value: bool) -> void:
	_rinsing = value
	if not value:
		_cancel()


func _process(delta: float) -> void:
	if not _rinsing or _mop == null or _mop.get_charge() <= 0.0:
		if _active:
			_cancel()
		return
	if _active:
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		_start_check()


func _start_check() -> void:
	if _ui == null or _mop == null:
		return
	_active = true
	check_started.emit()
	_ui.begin(_mop.get_charge(), needle_speed_multiplier, time_limit_multiplier)


func _on_attempt() -> void:
	if not _active or _ui == null:
		return
	var tier := _ui.evaluate()
	_resolve(tier)


func _resolve(tier: int) -> void:
	_active = false
	if _ui != null:
		_ui.hide_check()
	check_resolved.emit(tier)
	if _mop != null:
		_mop.apply_skill_result(tier)
	match tier:
		2:
			if _timer != null:
				_timer.add_time(skill_great_time)
		1:
			if _timer != null:
				_timer.add_time(skill_good_time)
		0:
			if _stress != null:
				_stress.add_stress(miss_stress)
			if _timer != null:
				_timer.on_skill_miss()
	_cooldown = randf_range(interval_min, interval_max)


func _cancel() -> void:
	_active = false
	_cooldown = 0.35
	if _ui != null:
		_ui.hide_check()
