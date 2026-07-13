class_name CleanableObject
extends Node2D

signal cleaned
signal scrub_progress_changed(progress: float)

@export var hitbox_size: Vector2 = Vector2(80, 80)
@export var requires_scrub: bool = false

# Ovalama (rubbing) dengesi:
@export var scrub_move_factor: float = 0.0016   # her piksel hareket başına ilerleme
@export var reversal_bonus: float = 0.07        # sağ<->sol yön değişimi başına bonus

var _is_clean: bool = false
var _scrub_progress: float = 0.0
var _last_dir_x: int = 0


func _ready() -> void:
	add_to_group("Cleanable")


func get_hitbox() -> Rect2:
	return Rect2(global_position - hitbox_size * 0.5, hitbox_size)


func is_cleaned() -> bool:
	return _is_clean


func get_scrub_progress() -> float:
	return _scrub_progress


func try_clean(click_pos: Vector2) -> bool:
	if _is_clean or not get_hitbox().has_point(click_pos):
		return false
	if requires_scrub:
		return false
	_finish_clean()
	return true


# Ovalama hareketiyle temizlik. motion = farenin bu karedeki gerçek hareketi.
# Sabit tutmak ilerletmez; sağ-sol ovalamak (yön değiştirmek) en hızlısıdır.
func scrub_rub(pos: Vector2, motion: Vector2, effectiveness: float = 1.0) -> bool:
	if _is_clean or not get_hitbox().has_point(pos):
		_last_dir_x = 0
		return false

	# Yatay hareket ağırlıklı efor (sağ-sol ovalama teşvik edilir)
	var effort := absf(motion.x) + absf(motion.y) * 0.4
	if effort <= 0.5:
		return false

	var gain := effort * scrub_move_factor * effectiveness

	# Yön değişimi bonusu (klasik ovalama hissi)
	var dir := 0
	if motion.x > 1.5:
		dir = 1
	elif motion.x < -1.5:
		dir = -1
	if dir != 0 and _last_dir_x != 0 and dir != _last_dir_x:
		gain += reversal_bonus * effectiveness
	if dir != 0:
		_last_dir_x = dir

	_scrub_progress = minf(1.0, _scrub_progress + gain)
	scrub_progress_changed.emit(_scrub_progress)
	_update_scrub_visual()

	if _scrub_progress >= 1.0:
		_finish_clean()
		return true
	return false


func _finish_clean() -> void:
	if _is_clean:
		return

	_is_clean = true
	_scrub_progress = 1.0
	modulate.a = 0.35
	cleaned.emit()

	var room_manager := get_tree().get_first_node_in_group("RoomManagerGroup")
	if room_manager != null:
		room_manager.check_room_cleared()


func _update_scrub_visual() -> void:
	modulate.a = lerpf(1.0, 0.35, _scrub_progress)
