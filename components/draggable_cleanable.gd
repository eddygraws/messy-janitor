class_name DraggableCleanable
extends CleanableObject

# Kayan leke: tıklanınca silinmez, imleçle sürüklenip gider deliğine
# (DrainZone) itilince temizlenir.

@export var drag_lag: float = 16.0   # imleci takip hızı


func _ready() -> void:
	super._ready()
	add_to_group("Draggable")


# Sürüklenerek temizlenir; ovalama/tıklama işe yaramaz.
func scrub_rub(_pos: Vector2, _motion: Vector2, _effectiveness: float = 1.0) -> bool:
	return false


func try_clean(_click_pos: Vector2) -> bool:
	return false


# Router her karede imlece doğru çeker.
func drag_toward(target: Vector2, delta: float) -> void:
	if is_cleaned():
		return
	global_position = global_position.lerp(target, clampf(drag_lag * delta, 0.0, 1.0))


func is_over_drain() -> bool:
	for node in get_tree().get_nodes_in_group("Drain"):
		if node.has_method("get_hitbox") and node.get_hitbox().has_point(global_position):
			return true
	return false


func deliver_to_drain() -> void:
	if is_cleaned():
		return
	_finish_clean()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.2, 0.2), 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)
