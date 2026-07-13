class_name MopBucket
extends Node2D

@export var hitbox_size: Vector2 = Vector2(170, 190)

@onready var _water: Polygon2D = get_node_or_null("Water")
@onready var _glow: Node2D = get_node_or_null("Glow")

var _glow_tween: Tween


func _ready() -> void:
	add_to_group("MopBucket")
	if _glow:
		_glow.modulate.a = 0.0
	set_dirty(0.0)


func get_hitbox() -> Rect2:
	return Rect2(global_position - hitbox_size * 0.5, hitbox_size)


# Paspas kiri arttıkça kovadaki suyu kirli göster (temiz mavi -> kirli kahve).
func set_dirty(ratio: float) -> void:
	if _water:
		_water.color = Color(0.35, 0.62, 0.9).lerp(Color(0.42, 0.32, 0.2), clampf(ratio, 0.0, 1.0))


# Paspas aşırı ısındığında (durulama gerekli) kovayı parlat.
func set_ready_glow(on: bool) -> void:
	if _glow == null:
		return
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	if on:
		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_property(_glow, "modulate:a", 0.85, 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_glow_tween.tween_property(_glow, "modulate:a", 0.25, 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_glow.modulate.a = 0.0


func splash() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.12, 0.9), 0.06)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
