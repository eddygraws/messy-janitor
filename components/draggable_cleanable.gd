extends "res://components/cleanable_object.gd"

# Sürüklenebilir kir: tıklanınca silinmez, imleçle sürüklenip hedef bölgeye
# (Drain = gider / TrashBin = çöp kovası) itilince temizlenir.
# Slime -> Drain (paspasla it), Süpürülen çöp -> TrashBin (süpürgeyle it).

@export var drag_lag: float = 16.0                       # imleci takip hızı
@export var target_group: StringName = &"Drain"          # teslim edilecek bölge grubu


func _ready() -> void:
	super._ready()
	add_to_group("Draggable")


func scrub_rub(_pos: Vector2, _motion: Vector2, _effectiveness: float = 1.0) -> bool:
	return false


func try_clean(_click_pos: Vector2) -> bool:
	return false


func drag_toward(target: Vector2, delta: float) -> void:
	if is_cleaned():
		return
	global_position = global_position.lerp(target, clampf(drag_lag * delta, 0.0, 1.0))


func is_over_target() -> bool:
	for node in get_tree().get_nodes_in_group(target_group):
		if node.has_method("get_hitbox") and node.get_hitbox().has_point(global_position):
			return true
	return false


func deliver() -> void:
	if is_cleaned():
		return
	# _finish_clean zaten fade + queue_free yapar.
	_finish_clean()
