class_name TempoPhaseDirector
extends Node

## Oda süresi üzerinden 3 ani tempo fazı (Isınma → Hızlan → Son Patlama).
## ratio: 0..1 — elapsed / room_duration

signal tempo_phase_changed(phase: int)
signal phase_flash(phase: int)

const PHASE_WARMUP := 1
const PHASE_RAMP := 2
const PHASE_FINALE := 3

@export var room_duration: float = 75.0
@export var phase2_at: float = 0.40
@export var phase3_at: float = 0.80
@export var active: bool = true

var _elapsed: float = 0.0
var _phase: int = PHASE_WARMUP
var _running: bool = false


func start_room(duration: float = -1.0) -> void:
	if duration > 0.0:
		room_duration = duration
	_elapsed = 0.0
	_running = true
	var prev := _phase
	_phase = PHASE_WARMUP
	if prev != _phase:
		tempo_phase_changed.emit(_phase)
	else:
		# Seviye başında faz 1'i dinleyicilere net bildir
		tempo_phase_changed.emit(_phase)


func stop_room() -> void:
	_running = false


func is_running() -> bool:
	return _running


func _process(delta: float) -> void:
	if not active or not _running:
		return
	_elapsed += delta
	var ratio := get_elapsed_ratio()
	var next := PHASE_WARMUP
	if ratio >= phase3_at:
		next = PHASE_FINALE
	elif ratio >= phase2_at:
		next = PHASE_RAMP
	if next != _phase:
		_phase = next
		tempo_phase_changed.emit(_phase)
		phase_flash.emit(_phase)


func get_elapsed_ratio() -> float:
	return clampf(_elapsed / maxf(room_duration, 1.0), 0.0, 1.0)


func get_phase() -> int:
	return _phase


func get_spawn_rate_mult() -> float:
	match _phase:
		PHASE_RAMP:
			return 1.45
		PHASE_FINALE:
			return 1.9
		_:
			return 1.0


func get_task_interval_mult() -> float:
	## Emir sıklığı: yüksek fazda daha sık (interval daha kısa).
	match _phase:
		PHASE_RAMP:
			return 0.75
		PHASE_FINALE:
			return 0.55
		_:
			return 1.0
