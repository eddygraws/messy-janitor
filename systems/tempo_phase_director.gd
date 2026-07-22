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


func start_room(duration: float = -1.0, start_phase: int = PHASE_WARMUP) -> void:
	if duration > 0.0:
		room_duration = duration
	_elapsed = 0.0
	_running = true
	var phase := clampi(start_phase, PHASE_WARMUP, PHASE_FINALE)
	# Boss/set-piece: doğrudan Son Patlama yoğunluğunda başla
	match phase:
		PHASE_FINALE:
			_elapsed = room_duration * phase3_at
		PHASE_RAMP:
			_elapsed = room_duration * phase2_at
		_:
			_elapsed = 0.0
	var prev := _phase
	_phase = phase
	tempo_phase_changed.emit(_phase)
	if _phase != PHASE_WARMUP and prev != _phase:
		phase_flash.emit(_phase)


func start_boss_room(duration: float = -1.0) -> void:
	start_room(duration, PHASE_FINALE)


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
			return 1.7
		PHASE_FINALE:
			return 2.25
		_:
			return 1.15


func get_task_interval_mult() -> float:
	## Emir sıklığı: yüksek fazda daha sık (interval daha kısa).
	match _phase:
		PHASE_RAMP:
			return 0.62
		PHASE_FINALE:
			return 0.42
		_:
			return 0.85
