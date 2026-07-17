class_name MopBucket
extends Node2D

## Paspas kovası: gövde + su katmanı.
## assets/bucket-body.png + assets/bucket-water.png (veya tools/ altı).

@export var hitbox_size: Vector2 = Vector2(170, 190)
@export var display_height: float = 168.0

@onready var _body: Sprite2D = get_node_or_null("Body")
@onready var _water: Sprite2D = get_node_or_null("Water")
@onready var _glow: Sprite2D = get_node_or_null("Glow")
@onready var _label: Label = get_node_or_null("Label")

var _glow_tween: Tween
var _clean_water_color := Color(0.45, 0.82, 1.0, 1.0)
var _dirty_water_color := Color(0.32, 0.16, 0.07, 1.0)
var _water_is_full_sprite: bool = false
var _base_water_scale: Vector2 = Vector2.ONE
var _dirt_ratio: float = 0.0


func _ready() -> void:
	add_to_group("MopBucket")
	_apply_default_textures()
	if _glow:
		_glow.modulate.a = 0.0
	set_dirty(0.0)


func _apply_default_textures() -> void:
	var body_tex := GameAssets.get_bucket_body()
	var water_tex := GameAssets.get_bucket_water()
	var glow_tex := GameAssets.get_bucket_glow()

	if _body != null:
		_body.texture = body_tex
		_body.centered = true
		_fit_sprite(_body, display_height)

	if _water != null:
		_water.texture = water_tex
		_water.centered = true
		var body_h := float(body_tex.get_height()) if body_tex != null else 1.0
		var water_h := float(water_tex.get_height()) if water_tex != null else 1.0
		# Su dosyası neredeyse kova boyundaysa "dolu kova" varyantı sayılır.
		_water_is_full_sprite = water_h >= body_h * 0.7
		if _water_is_full_sprite:
			_fit_sprite(_water, display_height)
			_water.position = Vector2.ZERO
			_base_water_scale = _water.scale
		else:
			_fit_sprite(_water, display_height * 0.42)
			_water.position = Vector2(0.0, -display_height * 0.22)
			_base_water_scale = _water.scale

	if _glow != null:
		_glow.texture = glow_tex
		_glow.centered = true
		_fit_sprite(_glow, display_height * 1.25)

	if _label != null:
		_label.position = Vector2(-80.0, display_height * 0.52)
		_label.size = Vector2(160.0, 30.0)


func _fit_sprite(sprite: Sprite2D, target_h: float) -> void:
	if sprite == null or sprite.texture == null:
		return
	var h := float(sprite.texture.get_height())
	if h <= 1.0:
		return
	var s := target_h / h
	sprite.scale = Vector2(s, s)


func get_hitbox() -> Rect2:
	return Rect2(global_position - hitbox_size * 0.5, hitbox_size)


func set_dirty(ratio: float) -> void:
	_dirt_ratio = clampf(ratio, 0.0, 1.0)
	if _water == null:
		return
	var t := pow(_dirt_ratio, 0.65)
	if _water_is_full_sprite:
		# Boş gövde + dolu kova: kirlendikçe dolu sprite belirir ve kahverengileşir.
		var fill_a := lerpf(0.35, 1.0, t)
		var col := _clean_water_color.lerp(_dirty_water_color, t)
		_water.modulate = Color(col.r, col.g, col.b, fill_a)
		_water.scale = _base_water_scale * Vector2(1.0 + t * 0.04, 1.0 - t * 0.03)
		if _body != null:
			_body.modulate = Color.WHITE.lerp(Color(0.75, 0.65, 0.55), t * 0.35)
	else:
		_water.modulate = _clean_water_color.lerp(_dirty_water_color, t)
		_water.scale = _base_water_scale * Vector2(1.0 + t * 0.08, 1.0 - t * 0.05)
		if _body != null:
			_body.modulate = Color.WHITE


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
