class_name JunkFoodObject
extends Node2D

signal tempted(position: Vector2)
signal expired

@export var hitbox_size: Vector2 = Vector2(64, 64)
# Cazibe / tuzak dengesi: stamina ÖDÜLÜ verir ama stres CEZASI ekler.
# Böylece yorgun oyuncu "enerji" için tıklamaya heveslenir, stresini artırır.
@export var stress_penalty: float = 20.0
@export var stamina_reward: float = 32.0
@export var lifetime: float = 3.5
@export var crash_delay: float = 3.5   # sugar crash: gecikmeli stres süresi

var _consumed: bool = false
var _expired: bool = false
var _pulse_tween: Tween


func _ready() -> void:
	add_to_group("JunkFood")
	scale = Vector2(0.85, 0.85)
	_start_pulse()
	if lifetime > 0.0:
		_start_lifetime()


func _start_pulse() -> void:
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2(0.85, 0.85), 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_lifetime() -> void:
	await get_tree().create_timer(lifetime).timeout
	if not _consumed and not _expired:
		expire()


func get_hitbox() -> Rect2:
	return Rect2(global_position - hitbox_size * 0.5, hitbox_size)


func is_active() -> bool:
	return not _consumed and not _expired and is_inside_tree()


func trigger_temptation() -> void:
	if _consumed or _expired:
		return
	_consumed = true
	tempted.emit(global_position)
	_kill_pulse()

	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2(1.5, 1.5), 0.07)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(self, "modulate:a", 0.0, 0.18)
	pop.tween_callback(queue_free)


func expire() -> void:
	if _consumed or _expired:
		return
	_expired = true
	expired.emit()
	_kill_pulse()

	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade.tween_callback(queue_free)


func _kill_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
