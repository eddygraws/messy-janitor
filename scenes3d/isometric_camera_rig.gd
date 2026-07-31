class_name IsometricCameraRig
extends Node3D

## Sabit açı; yalnızca hedefi takip eder, dönmez.
##
## TEST: `use_overcooked_topdown_test = true` → Overcooked tarzı dikey kamera.
## Geri almak için export'u false yap (veya Inspector'dan kapat).

## TEST FLAG — false = eski izometrik açı
@export var use_overcooked_topdown_test: bool = true

@export var follow_target: Node3D
@export var follow_smoothing: float = 8.0
## Gerçek izometrik ~35.26°; oyun hissi için hafif ayarlı. (izometrik mod)
@export var pitch_degrees: float = -38.0
@export var yaw_degrees: float = 45.0
@export var distance: float = 23.5
@export var look_height: float = 0.85

## Overcooked test preset (pitch dikey, yaw dünya eksenine hizalı)
@export var topdown_pitch_degrees: float = -62.0
@export var topdown_yaw_degrees: float = 0.0
@export var topdown_distance: float = 20.0
@export var topdown_look_height: float = 0.55
@export var topdown_fov: float = 46.0

@onready var _camera: Camera3D = $Camera3D

var _offset: Vector3 = Vector3.ZERO
var _base_fov: float = 42.0
var _fov_punch: float = 0.0
var _shake: float = 0.0
var _finale_zoom: bool = false

# İzometrik varsayılanlar (geri alma / finale zoom için)
const _ISO_DISTANCE := 23.5
const _ISO_FOV := 42.0
const _ISO_DISTANCE_FINALE := 21.5
const _ISO_FOV_FINALE := 46.0
const _TD_DISTANCE_FINALE := 17.5
const _TD_FOV_FINALE := 50.0


func _ready() -> void:
	_apply_view_mode()
	if _camera != null:
		_camera.current = true
		_base_fov = _camera.fov


func _physics_process(delta: float) -> void:
	if follow_target == null:
		return
	var focus := follow_target.global_position + Vector3(0.0, _active_look_height(), 0.0)
	var desired := focus + _offset
	if _shake > 0.01:
		_shake = move_toward(_shake, 0.0, delta * 9.0)
		desired += Vector3(
			randf_range(-1.0, 1.0) * _shake * 0.12,
			randf_range(-0.5, 0.5) * _shake * 0.08,
			randf_range(-1.0, 1.0) * _shake * 0.12
		)
	global_position = global_position.lerp(desired, clampf(follow_smoothing * delta, 0.0, 1.0))
	look_at(focus, Vector3.UP)
	if _camera != null and _fov_punch > 0.01:
		_fov_punch = move_toward(_fov_punch, 0.0, delta * 28.0)
		_camera.fov = _base_fov + _fov_punch


func punch_fov(amount: float = 6.0) -> void:
	_fov_punch = maxf(_fov_punch, amount)
	if _camera != null:
		_camera.fov = _base_fov + _fov_punch


func shake(amount: float = 1.0) -> void:
	_shake = maxf(_shake, amount)


func set_finale_zoom(on: bool) -> void:
	_finale_zoom = on
	_apply_view_mode()


func set_follow(target: Node3D) -> void:
	follow_target = target
	if is_inside_tree():
		_recompute_offset()
		if follow_target != null:
			var focus := follow_target.global_position + Vector3(0.0, _active_look_height(), 0.0)
			global_position = focus + _offset
			look_at(focus, Vector3.UP)


func get_camera() -> Camera3D:
	return _camera


## Kamera yönüne göre XZ düzleminde ileri/sağ vektörleri (WASD).
func get_movement_axes() -> Dictionary:
	var forward := Vector3.ZERO
	var right := Vector3.ZERO
	var yaw := deg_to_rad(_active_yaw())
	if _camera != null:
		forward = -_camera.global_transform.basis.z
		right = _camera.global_transform.basis.x
	else:
		forward = Vector3(-sin(yaw), 0.0, -cos(yaw))
		right = Vector3(cos(yaw), 0.0, -sin(yaw))
	forward.y = 0.0
	right.y = 0.0
	# Dik top-down'da basis.z neredeyse dikey → XZ projeksiyonu çöker; yaw'a düş.
	if forward.length_squared() < 0.0001:
		forward = Vector3(-sin(yaw), 0.0, -cos(yaw))
	if right.length_squared() < 0.0001:
		right = Vector3(cos(yaw), 0.0, -sin(yaw))
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	if right.length_squared() > 0.0001:
		right = right.normalized()
	return {"forward": forward, "right": right}


func _apply_view_mode() -> void:
	if use_overcooked_topdown_test:
		if _finale_zoom:
			distance = _TD_DISTANCE_FINALE
			_base_fov = _TD_FOV_FINALE
		else:
			distance = topdown_distance
			_base_fov = topdown_fov
	else:
		if _finale_zoom:
			distance = _ISO_DISTANCE_FINALE
			_base_fov = _ISO_FOV_FINALE
		else:
			distance = _ISO_DISTANCE
			_base_fov = _ISO_FOV
	_recompute_offset()
	if _camera != null:
		_camera.fov = _base_fov + _fov_punch


func _active_pitch() -> float:
	return topdown_pitch_degrees if use_overcooked_topdown_test else pitch_degrees


func _active_yaw() -> float:
	return topdown_yaw_degrees if use_overcooked_topdown_test else yaw_degrees


func _active_look_height() -> float:
	return topdown_look_height if use_overcooked_topdown_test else look_height


func _recompute_offset() -> void:
	var pitch := deg_to_rad(_active_pitch())
	var yaw := deg_to_rad(_active_yaw())
	var horiz := distance * cos(pitch)
	_offset = Vector3(
		horiz * sin(yaw),
		distance * sin(-pitch),
		horiz * cos(yaw)
	)
