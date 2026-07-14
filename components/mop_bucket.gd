class_name MopBucket
extends Node2D

@export var hitbox_size: Vector2 = Vector2(170, 190)

@onready var _body: Sprite2D = get_node_or_null("Body")
@onready var _water: Sprite2D = get_node_or_null("Water")
@onready var _glow: Sprite2D = get_node_or_null("Glow")

var _glow_tween: Tween
var _clean_water_color := Color(0.35, 0.72, 1.0)
var _dirty_water_color := Color(0.28, 0.14, 0.06)


func _ready() -> void:
	add_to_group("MopBucket")
	_apply_default_textures()
	if _glow:
		_glow.modulate.a = 0.0
	set_dirty(0.0)


func _apply_default_textures() -> void:
	if _body != null and _body.texture == null:
		_body.texture = GameAssets.get_bucket_body()
		_body.centered = true
	if _water != null:
		if _water.texture == null:
			_water.texture = GameAssets.get_bucket_water()
		_water.centered = true
		_water.position = Vector2(0, -18)
	if _glow != null:
		if _glow.texture == null:
			_glow.texture = GameAssets.get_bucket_glow()
		_glow.centered = true


func get_hitbox() -> Rect2:
	return Rect2(global_position - hitbox_size * 0.5, hitbox_size)


func set_dirty(ratio: float) -> void:
	if _water == null:
		return
	var t := clampf(ratio, 0.0, 1.0)
	# Erken kirlenmede de net görünsün (eğri)
	t = pow(t, 0.65)
	_water.modulate = _clean_water_color.lerp(_dirty_water_color, t)
	_water.scale = Vector2(1.0 + t * 0.08, 1.0 - t * 0.05)


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
