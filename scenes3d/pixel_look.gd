class_name PixelLook
extends Node

## Oyun görsel mihenk taşı: 3D nearest pixelize.
## DemoForest: SubViewport 288×162 + stretch_shrink 4 + texture_filter nearest.
## Short Hike: düşük native çözünürlük, point upsample.
##
## Bizde compositor kullanıyoruz — UI (CanvasLayer) keskin kalır, kamera açısı değişmez.
## ASLA scaling_3d_scale < 1.0 yapma: Godot 3D'yi bilinear büyütür.

const PIXELIZE_SCRIPT := preload("res://shaders/post_processing/pixelize_compositor.gd")

## 1 = kapalı, 2/3/4 = piksel bloğu. 1080p'de 3 ≈ 640×360.
@export var pixel_size: int = 3
@export var outlines: bool = true
@export var cycle_key: Key = KEY_F9

static var _effect: PixelizeCompositor
static var _compositor: Compositor


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pixel_size = GameSettings.pixel_size
	outlines = GameSettings.outlines
	_ensure_shared()
	_apply_settings()
	_bind_parent_camera()
	var vp := get_viewport()
	if vp != null:
		vp.scaling_3d_scale = 1.0


func _exit_tree() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.keycode != cycle_key and k.physical_keycode != cycle_key:
		return
	var next := GameSettings.pixel_size + 1
	if next > 4:
		next = 1
	pixel_size = next
	GameSettings.set_pixel_size(next)
	get_viewport().set_input_as_handled()


static func bind_camera(cam: Camera3D) -> void:
	if cam == null:
		return
	_ensure_shared()
	cam.compositor = _compositor


static func set_pixel_size(size: int) -> void:
	_ensure_shared()
	if _effect != null:
		_effect.pixel_size = clampi(size, 1, 8)


static func set_outlines(on: bool) -> void:
	_ensure_shared()
	if _effect != null:
		_effect.outline_strength = 0.55 if on else 0.0


static func _ensure_shared() -> void:
	if _effect != null and _compositor != null:
		return
	_effect = PIXELIZE_SCRIPT.new() as PixelizeCompositor
	_effect.pixel_size = GameSettings.pixel_size
	_effect.outline_strength = 0.55 if GameSettings.outlines else 0.0
	_compositor = Compositor.new()
	_compositor.compositor_effects = [_effect]


func _bind_parent_camera() -> void:
	var cam := get_parent() as Camera3D
	if cam == null:
		cam = get_viewport().get_camera_3d()
	bind_camera(cam)


func _apply_settings() -> void:
	_ensure_shared()
	if _effect == null:
		return
	_effect.pixel_size = clampi(pixel_size, 1, 8)
	_effect.outline_strength = 0.55 if outlines else 0.0
