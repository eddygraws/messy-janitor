extends Node2D

signal cursor_moved(position: Vector2)
signal cursor_clicked(position: Vector2)

@export var stamina_path: NodePath = ^"../StaminaComponent"
@export var stress_path: NodePath = ^"../StressComponent"
@export var follow_speed: float = 14.0
@export var max_shake: float = 6.0
@export var noise_frequency: float = 3.0
@export var panic_shake_multiplier: float = 2.4
@export var panic_freq_multiplier: float = 1.8

var _stamina: StaminaComponent
var _stress: StressComponent
var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _panic: bool = false


func _ready() -> void:
	_stamina = get_node(stamina_path) as StaminaComponent
	_stress = get_node_or_null(stress_path) as StressComponent
	if _stress != null:
		_stress.panic_mode_entered.connect(_on_panic_entered)
		_stress.panic_mode_exited.connect(_on_panic_exited)
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.seed = randi()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _process(delta: float) -> void:
	_time += delta

	var target := _get_world_mouse_pos()
	var control := _stamina.get_control_factor() if _stamina else 1.0
	var lag := lerpf(4.0, 18.0, 1.0 - control)

	global_position = global_position.lerp(target, lag * delta)

	var shake_strength := lerpf(0.5, max_shake, 1.0 - control)
	var freq := noise_frequency
	if _panic:
		shake_strength *= panic_shake_multiplier
		freq *= panic_freq_multiplier

	var shake := Vector2(
		_noise.get_noise_2d(_time * freq, 0.0),
		_noise.get_noise_2d(0.0, _time * freq)
	) * shake_strength

	global_position += shake
	cursor_moved.emit(global_position)


func _on_panic_entered() -> void:
	_panic = true


func _on_panic_exited() -> void:
	_panic = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			cursor_clicked.emit(global_position)


func _get_world_mouse_pos() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()
