class_name CharacterPortraitUI
extends Sprite2D

# Pre-rendered portre katmanı.
# Atlas düzeni (yatay şerit, soldan sağa):
#   0 Nötr | 1 Stresli | 2 Panik | 3 Kritik | 4 Mutlu | 5 Patlama
# Gerçek sprite hazır olunca @export portrait_atlas'a PNG ataman yeterli.

enum Emotion { NEUTRAL, STRESSED, PANIC, CRITICAL, HAPPY, EXPLODED }

const FRAME_COUNT := 6
const FRAME_W := 128
const FRAME_H := 128

@export var stress_path: NodePath = ^"../../StressComponent"
@export var combo_path: NodePath = ^"../../ComboComponent"
@export var room_manager_path: NodePath = ^"../../RoomManager"

@export var portrait_atlas: Texture2D          # opsiyonel: kendi PNG atlasın
@export var use_placeholder: bool = true         # atlas yoksa kodla üret
@export var max_swell: float = 1.35              # %100 stres scale
@export var happy_hold: float = 1.35             # mutlu ifade süresi
@export var swell_speed: float = 8.0

# Her duygu için baz renk tonu (flash sonrası geri döner).
const EMOTION_TINTS := {
	Emotion.NEUTRAL: Color(0.92, 0.94, 0.98),
	Emotion.STRESSED: Color(1.0, 0.92, 0.78),
	Emotion.PANIC: Color(1.0, 0.78, 0.62),
	Emotion.CRITICAL: Color(1.0, 0.55, 0.5),
	Emotion.HAPPY: Color(0.75, 1.0, 0.82),
	Emotion.EXPLODED: Color(0.55, 0.2, 0.22),
}

var _stress: StressComponent
var _atlas_tex: AtlasTexture
var _base_scale: Vector2 = Vector2.ONE
var _target_swell: float = 1.0
var _current_swell: float = 1.0
var _emotion: Emotion = Emotion.NEUTRAL
var _happy_until: float = 0.0
var _exploded: bool = false


func _ready() -> void:
	_base_scale = scale
	_setup_texture()
	_set_emotion(Emotion.NEUTRAL, true)

	_stress = get_node_or_null(stress_path) as StressComponent
	if _stress != null:
		_stress.stress_changed.connect(_on_stress_changed)
		_stress.panic_mode_entered.connect(_on_panic_entered)
		_stress.panic_mode_exited.connect(_on_panic_exited)
		_stress.stress_critical.connect(_on_critical)
		_stress.stress_exploded.connect(_on_exploded)
		_on_stress_changed(_stress.current_stress, _stress.max_stress)

	var combo := get_node_or_null(combo_path) as ComboComponent
	if combo != null:
		combo.combo_milestone.connect(_on_happy_burst)

	var room_manager := get_node_or_null(room_manager_path)
	if room_manager != null and room_manager.has_signal("room_cleared"):
		room_manager.room_cleared.connect(func(_i: int, _r: Dictionary) -> void: _on_happy_burst(0))


func _process(delta: float) -> void:
	if _exploded:
		return

	_current_swell = lerpf(_current_swell, _target_swell, clampf(delta * swell_speed, 0.0, 1.0))
	scale = _base_scale * _current_swell

	if _happy_until > 0.0:
		_happy_until -= delta
		if _happy_until <= 0.0 and not _exploded:
			_refresh_emotion_from_stress()


func _setup_texture() -> void:
	var source: Texture2D = portrait_atlas
	if source == null and use_placeholder:
		source = _build_placeholder_atlas()
	if source == null:
		push_warning("CharacterPortraitUI: atlas yok, placeholder kapalı.")
		return

	_atlas_tex = AtlasTexture.new()
	_atlas_tex.atlas = source
	_atlas_tex.region = _frame_rect(Emotion.NEUTRAL)
	texture = _atlas_tex


func _frame_rect(emotion: Emotion) -> Rect2:
	return Rect2(int(emotion) * FRAME_W, 0, FRAME_W, FRAME_H)


func _set_emotion(emotion: Emotion, instant: bool = false) -> void:
	if _exploded and emotion != Emotion.EXPLODED:
		return
	_emotion = emotion
	if _atlas_tex != null:
		_atlas_tex.region = _frame_rect(emotion)
	var tint: Color = EMOTION_TINTS.get(emotion, Color.WHITE)
	if instant:
		modulate = tint
	else:
		var tween := create_tween()
		tween.tween_property(self, "modulate", tint, 0.18)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if emotion == Emotion.PANIC or emotion == Emotion.CRITICAL:
		_nudge_pop()


func _refresh_emotion_from_stress() -> void:
	if _exploded or _stress == null:
		return
	var ratio := _stress.get_stress_ratio()
	if _stress.is_in_panic():
		_set_emotion(Emotion.PANIC)
	elif ratio >= _stress.critical_threshold:
		_set_emotion(Emotion.CRITICAL)
	elif ratio >= 0.35:
		_set_emotion(Emotion.STRESSED)
	else:
		_set_emotion(Emotion.NEUTRAL)


func _on_stress_changed(current: float, maximum: float) -> void:
	if _exploded:
		return
	var ratio := current / maximum if maximum > 0.0 else 0.0
	_target_swell = lerpf(1.0, max_swell, ratio)
	if _happy_until <= 0.0:
		_refresh_emotion_from_stress()


func _on_panic_entered() -> void:
	if _happy_until <= 0.0:
		_set_emotion(Emotion.PANIC)


func _on_panic_exited() -> void:
	if _happy_until <= 0.0:
		_refresh_emotion_from_stress()


func _on_critical() -> void:
	_set_emotion(Emotion.CRITICAL)
	_nudge_pop(1.25)


func _on_exploded() -> void:
	_exploded = true
	_target_swell = 1.55
	_set_emotion(Emotion.EXPLODED)
	var tween := create_tween()
	tween.tween_property(self, "scale", _base_scale * 1.7, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.35, 0.55)


func _on_happy_burst(_combo: int = 0) -> void:
	if _exploded:
		return
	_happy_until = happy_hold
	_set_emotion(Emotion.HAPPY)
	_nudge_pop(1.12)


func _nudge_pop(mult: float = 1.08) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", _base_scale * _current_swell * mult, 0.07)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", _base_scale * _current_swell, 0.16)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# JuiceDirector kısa flash sonrası duygu rengine geri dönsün.
func restore_tint_after_flash() -> void:
	if _atlas_tex == null:
		return
	var tint: Color = EMOTION_TINTS.get(_emotion, Color.WHITE)
	modulate = tint


func _build_placeholder_atlas() -> ImageTexture:
	var img := Image.create(FRAME_W * FRAME_COUNT, FRAME_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	_paint_frame(img, Emotion.NEUTRAL, Color(0.55, 0.62, 0.58), Color(0.38, 0.44, 0.4))
	_paint_frame(img, Emotion.STRESSED, Color(0.72, 0.58, 0.42), Color(0.55, 0.42, 0.28))
	_paint_frame(img, Emotion.PANIC, Color(0.85, 0.55, 0.38), Color(0.65, 0.38, 0.25))
	_paint_frame(img, Emotion.CRITICAL, Color(0.82, 0.32, 0.28), Color(0.58, 0.18, 0.16))
	_paint_frame(img, Emotion.HAPPY, Color(0.45, 0.72, 0.52), Color(0.28, 0.55, 0.38))
	_paint_frame(img, Emotion.EXPLODED, Color(0.35, 0.12, 0.14), Color(0.18, 0.06, 0.08))

	var tex := ImageTexture.create_from_image(img)
	return tex


func _paint_frame(img: Image, emotion: Emotion, body: Color, shadow: Color) -> void:
	var ox := int(emotion) * FRAME_W
	var cx := ox + FRAME_W / 2
	var cy := FRAME_H / 2

	# Gövde (gargoyle silueti — low-poly his).
	for y in FRAME_H:
		for x in FRAME_W:
			var px := ox + x
			var dx := float(x) - FRAME_W * 0.5
			var dy := float(y) - cy
			if dx * dx + dy * dy < 46 * 46:
				img.set_pixel(px, y, body)
			elif dx * dx + dy * dy < 52 * 52:
				img.set_pixel(px, y, shadow)

	# Boynuzlar.
	_fill_tri(img, Vector2i(cx - 28, cy - 38), Vector2i(cx - 14, cy - 58), Vector2i(cx - 6, cy - 36), shadow)
	_fill_tri(img, Vector2i(cx + 28, cy - 38), Vector2i(cx + 14, cy - 58), Vector2i(cx + 6, cy - 36), shadow)

	# Gözler.
	var eye_y := cy - 8
	var eye_col := Color(0.12, 0.14, 0.18)
	match emotion:
		Emotion.PANIC, Emotion.CRITICAL:
			_fill_rect(img, Rect2i(cx - 22, eye_y - 6, 14, 14), Color(1.0, 0.95, 0.4))
			_fill_rect(img, Rect2i(cx + 8, eye_y - 6, 14, 14), Color(1.0, 0.95, 0.4))
		Emotion.HAPPY:
			_fill_rect(img, Rect2i(cx - 20, eye_y - 2, 12, 6), eye_col)
			_fill_rect(img, Rect2i(cx + 8, eye_y - 2, 12, 6), eye_col)
		Emotion.EXPLODED:
			pass
		_:
			_fill_rect(img, Rect2i(cx - 20, eye_y - 3, 12, 8), eye_col)
			_fill_rect(img, Rect2i(cx + 8, eye_y - 3, 12, 8), eye_col)

	# Ağız.
	match emotion:
		Emotion.HAPPY:
			_fill_rect(img, Rect2i(cx - 16, cy + 18, 32, 6), Color(0.15, 0.12, 0.1))
		Emotion.PANIC, Emotion.CRITICAL:
			_fill_rect(img, Rect2i(cx - 10, cy + 20, 20, 12), Color(0.12, 0.08, 0.08))
		Emotion.EXPLODED:
			for i in 12:
				img.set_pixel(cx + i - 6, cy + 10 + i, Color(1.0, 0.5, 0.2))
				img.set_pixel(cx + i - 8, cy + 14 + i, Color(0.9, 0.3, 0.15))
		Emotion.STRESSED:
			_fill_rect(img, Rect2i(cx - 14, cy + 22, 28, 4), Color(0.15, 0.1, 0.08))
		_:
			_fill_rect(img, Rect2i(cx - 12, cy + 22, 24, 3), Color(0.15, 0.1, 0.08))


func _fill_rect(img: Image, rect: Rect2i, col: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, col)


func _fill_tri(img: Image, a: Vector2i, b: Vector2i, c: Vector2i, col: Color) -> void:
	var min_x := mini(a.x, mini(b.x, c.x))
	var max_x := maxi(a.x, maxi(b.x, c.x))
	var min_y := mini(a.y, mini(b.y, c.y))
	var max_y := maxi(a.y, maxi(b.y, c.y))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if _point_in_tri(Vector2(x, y), Vector2(a), Vector2(b), Vector2(c)):
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
					img.set_pixel(x, y, col)


func _point_in_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := _sign(p, a, b)
	var d2 := _sign(p, b, c)
	var d3 := _sign(p, c, a)
	var has_neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var has_pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (has_neg and has_pos)


func _sign(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)
