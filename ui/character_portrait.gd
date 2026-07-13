class_name CharacterPortraitUI
extends Sprite2D

# Pre-rendered portre — sağ üst köşede (PortraitDock içinde).
# facial-features-complete.png atlas sırası (768×128, 6 kare):
#   0 Nötr | 1 Mutlu | 2 Şaşkın | 3 Endişeli | 4 Şişmiş | 5 Max şişmiş

enum Emotion { NEUTRAL, STRESSED, PANIC, CRITICAL, HAPPY, EXPLODED }

const FRAME_COUNT := 6

# Duygu → atlas kare indeksi (senin render sıran).
const ATLAS_FRAMES := {
	Emotion.NEUTRAL: 0,
	Emotion.HAPPY: 1,
	Emotion.PANIC: 2,
	Emotion.STRESSED: 3,
	Emotion.CRITICAL: 4,
	Emotion.EXPLODED: 5,
}

@export var stress_path: NodePath = ^"../../../StressComponent"
@export var combo_path: NodePath = ^"../../../ComboComponent"
@export var room_manager_path: NodePath = ^"../../../RoomManager"

@export var portrait_atlas: Texture2D
@export var use_placeholder: bool = true
@export var apply_tint: bool = false          # gerçek PNG'de genelde kapalı
@export var max_swell: float = 1.28
@export var happy_hold: float = 1.35
@export var swell_speed: float = 8.0

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
var _frame_w: int = 128
var _frame_h: int = 128
var _base_scale: Vector2 = Vector2.ONE
var _target_swell: float = 1.0
var _current_swell: float = 1.0
var _emotion: Emotion = Emotion.NEUTRAL
var _happy_until: float = 0.0
var _exploded: bool = false


func _ready() -> void:
	z_index = 1
	_base_scale = scale
	_setup_texture()
	_center_in_parent()
	_set_emotion(Emotion.NEUTRAL, true)

	_stress = get_node_or_null(stress_path) as StressComponent
	if _stress != null:
		_stress.stress_changed.connect(_on_stress_changed)
		_stress.panic_mode_entered.connect(_on_panic_entered)
		_stress.panic_mode_exited.connect(_on_panic_exited)
		_stress.stress_critical.connect(_on_critical)
		_stress.stress_exploded.connect(_on_exploded)
		_on_stress_changed(_stress.current_stress, _stress.max_stress)
	else:
		push_warning("CharacterPortraitUI: StressComponent bulunamadı: %s" % stress_path)

	var combo := get_node_or_null(combo_path) as ComboComponent
	if combo != null:
		combo.combo_milestone.connect(_on_happy_burst)

	var room_manager := get_node_or_null(room_manager_path)
	if room_manager != null and room_manager.has_signal("room_cleared"):
		room_manager.room_cleared.connect(func(_i: int, _r: Dictionary) -> void: _on_happy_burst(0))


func _center_in_parent() -> void:
	var dock := get_parent() as Control
	if dock == null:
		return
	position = dock.size * 0.5


func _process(delta: float) -> void:
	if _exploded:
		return
	_current_swell = lerpf(_current_swell, _target_swell, clampf(delta * swell_speed, 0.0, 1.0))
	scale = _base_scale * _current_swell
	if _happy_until > 0.0:
		_happy_until -= delta
		if _happy_until <= 0.0:
			_refresh_emotion_from_stress()


func _setup_texture() -> void:
	var source: Texture2D = portrait_atlas
	if source == null and use_placeholder:
		source = _build_placeholder_atlas()
	if source == null:
		push_warning("CharacterPortraitUI: atlas yok.")
		return

	_frame_w = maxi(1, source.get_width() / FRAME_COUNT)
	_frame_h = source.get_height()

	_atlas_tex = AtlasTexture.new()
	_atlas_tex.atlas = source
	_atlas_tex.region = _frame_rect(Emotion.NEUTRAL)
	texture = _atlas_tex


func _frame_rect(emotion: Emotion) -> Rect2:
	var idx: int = ATLAS_FRAMES.get(emotion, 0)
	return Rect2(idx * _frame_w, 0, _frame_w, _frame_h)


func _set_emotion(emotion: Emotion, instant: bool = false) -> void:
	if _exploded and emotion != Emotion.EXPLODED:
		return
	_emotion = emotion
	if _atlas_tex != null:
		_atlas_tex.region = _frame_rect(emotion)
	var tint: Color = EMOTION_TINTS.get(emotion, Color.WHITE) if apply_tint else Color.WHITE
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
	if _stress.is_in_panic():
		_set_emotion(Emotion.PANIC)
	elif _stress.get_stress_ratio() >= _stress.critical_threshold:
		_set_emotion(Emotion.CRITICAL)
	elif _stress.get_stress_ratio() >= 0.35:
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
	_nudge_pop(1.22)


func _on_exploded() -> void:
	_exploded = true
	_target_swell = 1.5
	_set_emotion(Emotion.EXPLODED)
	var tween := create_tween()
	tween.tween_property(self, "scale", _base_scale * 1.65, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.35, 0.55)


func _on_happy_burst(_combo: int = 0) -> void:
	if _exploded:
		return
	_happy_until = happy_hold
	_set_emotion(Emotion.HAPPY)
	_nudge_pop(1.1)


func _nudge_pop(mult: float = 1.08) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", _base_scale * _current_swell * mult, 0.07)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", _base_scale * _current_swell, 0.16)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func restore_tint_after_flash() -> void:
	modulate = EMOTION_TINTS.get(_emotion, Color.WHITE) if apply_tint else Color.WHITE


func _build_placeholder_atlas() -> ImageTexture:
	var fw := 128
	var img := Image.create(fw * FRAME_COUNT, fw, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for e in ATLAS_FRAMES.keys():
		_paint_placeholder_frame(img, e, ATLAS_FRAMES[e], fw)
	return ImageTexture.create_from_image(img)


func _paint_placeholder_frame(img: Image, _emotion: Emotion, index: int, fw: int) -> void:
	var ox := index * fw
	for y in fw:
		for x in fw:
			var dx := float(x) - fw * 0.5
			var dy := float(y) - fw * 0.5
			if dx * dx + dy * dy < 40 * 40:
				img.set_pixel(ox + x, y, Color(0.5, 0.55, 0.5))
