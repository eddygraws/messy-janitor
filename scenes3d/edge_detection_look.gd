extends Node
## Vegetation kenar shader'ını janitor 3D kamerasında test etmek için.
## F8: outline aç/kapa  ·  F9: 3D pixel ölçek (1.0 → 0.5 → 0.25)

const EffectScript := preload("res://shaders/post_processing/edge_detection_compositor.gd")
const PIXEL_SCALES: Array[float] = [1.0, 0.5, 0.25]

@export var start_enabled: bool = true
@export var start_pixel_index: int = 0

var _effect: CompositorEffect
var _compositor: Compositor
var _enabled: bool = true
var _pixel_index: int = 0
var _hint: Label
var _hint_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enabled = start_enabled
	_pixel_index = clampi(start_pixel_index, 0, PIXEL_SCALES.size() - 1)
	_effect = EffectScript.new()
	_compositor = Compositor.new()
	_apply_to_camera()
	_apply_pixel_scale()
	_build_hint()
	_flash_hint()


func _exit_tree() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.scaling_3d_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F8:
			_enabled = not _enabled
			_apply_to_camera()
			_flash_hint()
			get_viewport().set_input_as_handled()
		KEY_F9:
			_pixel_index = (_pixel_index + 1) % PIXEL_SCALES.size()
			_apply_pixel_scale()
			_flash_hint()
			get_viewport().set_input_as_handled()


func _apply_to_camera() -> void:
	var cam := _camera()
	if cam == null:
		return
	if _enabled:
		if _compositor.compositor_effects.is_empty():
			_compositor.compositor_effects = [_effect]
		cam.compositor = _compositor
	else:
		cam.compositor = null
	if _effect != null:
		_effect.enabled = _enabled


func _apply_pixel_scale() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	vp.scaling_3d_scale = PIXEL_SCALES[_pixel_index]
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false


func _camera() -> Camera3D:
	var parent := get_parent()
	if parent is Camera3D:
		return parent
	return null


func _build_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	layer.name = "EdgeDetectionHint"
	add_child(layer)
	_hint = Label.new()
	_hint.position = Vector2(18, 16)
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06, 0.9))
	_hint.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hint)


func _refresh_hint() -> void:
	if _hint == null:
		return
	var edge := "AÇIK" if _enabled else "KAPALI"
	var scale := PIXEL_SCALES[_pixel_index]
	_hint.text = "Kenar [F8]: %s    Pixel [F9]: ×%.2f" % [edge, scale]


func _flash_hint() -> void:
	_refresh_hint()
	if _hint == null:
		return
	_hint.modulate = Color(1, 1, 1, 1)
	if _hint_tween != null:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_interval(2.4)
	_hint_tween.tween_property(_hint, "modulate:a", 0.35, 0.4)
