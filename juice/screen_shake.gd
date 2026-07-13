class_name ScreenShake
extends Node

@export var camera_path: NodePath = ^"../Camera2D"

@export var max_offset: float = 14.0
@export var max_rotation: float = 2.5
@export var trauma_decay: float = 1.8

var _camera: Camera2D
var _trauma: float = 0.0
var _base_offset: Vector2


func _ready() -> void:
	_camera = get_node(camera_path) as Camera2D
	if _camera:
		_base_offset = _camera.offset


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func shake(strength: float = 0.35, _duration: float = 0.0) -> void:
	add_trauma(strength)


func _process(delta: float) -> void:
	if _camera == null:
		return

	_trauma = maxf(0.0, _trauma - trauma_decay * delta)
	var shake_amount := _trauma * _trauma

	if shake_amount <= 0.001:
		_camera.offset = _base_offset
		_camera.rotation_degrees = 0.0
		return

	_camera.offset = _base_offset + Vector2(
		randf_range(-1.0, 1.0) * max_offset * shake_amount,
		randf_range(-1.0, 1.0) * max_offset * shake_amount
	)
	_camera.rotation_degrees = randf_range(-1.0, 1.0) * max_rotation * shake_amount
