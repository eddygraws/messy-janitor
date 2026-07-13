extends Node2D

signal cursor_moved(position: Vector2)
signal cursor_clicked(position: Vector2)

@export var stamina_path: NodePath = ^"../StaminaComponent"
@export var stress_path: NodePath = ^"../StressComponent"
@export var mop_path: NodePath = ^"../MopComponent"
@export var equipment_path: NodePath = ^"../EquipmentComponent"
@export var dirty_control_penalty: float = 0.38
@export var follow_speed: float = 14.0
@export var max_shake: float = 6.0
@export var noise_frequency: float = 3.0
@export var panic_shake_multiplier: float = 2.4
@export var panic_freq_multiplier: float = 1.8

var _stamina: StaminaComponent
var _stress: StressComponent
var _mop: MopComponent
var _equipment: EquipmentComponent
var _tool_sprite: Sprite2D
var _crosshair: Sprite2D
var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _panic: bool = false


func _ready() -> void:
	_stamina = get_node(stamina_path) as StaminaComponent
	_stress = get_node_or_null(stress_path) as StressComponent
	_mop = get_node_or_null(mop_path) as MopComponent
	_equipment = get_node_or_null(equipment_path) as EquipmentComponent
	if _stress != null:
		_stress.panic_mode_entered.connect(_on_panic_entered)
		_stress.panic_mode_exited.connect(_on_panic_exited)
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.seed = randi()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_setup_sprites()
	if _equipment != null:
		_equipment.equipment_changed.connect(_on_equipment_changed)
		_on_equipment_changed(_equipment.get_current())


func _setup_sprites() -> void:
	for child in get_children():
		child.queue_free()

	_tool_sprite = Sprite2D.new()
	_tool_sprite.name = "ToolSprite"
	_tool_sprite.centered = true
	_tool_sprite.z_index = 0
	add_child(_tool_sprite)

	_crosshair = Sprite2D.new()
	_crosshair.name = "Crosshair"
	_crosshair.centered = true
	_crosshair.texture = GameAssets.get_crosshair()
	_crosshair.z_index = 1
	add_child(_crosshair)


func set_equipment(type: int) -> void:
	if _tool_sprite == null:
		return
	_tool_sprite.texture = GameAssets.get_cursor_texture(type)
	_tool_sprite.offset = GameAssets.get_cursor_offset(type)
	_tool_sprite.scale = Vector2.ONE * GameAssets.get_cursor_scale(type)
	modulate = Color.WHITE


func _on_equipment_changed(type: int) -> void:
	set_equipment(type)


func _process(delta: float) -> void:
	_time += delta

	var target := _get_world_mouse_pos()
	var control := _stamina.get_control_factor() if _stamina else 1.0
	if _mop != null:
		var charge := _mop.get_charge()
		control *= lerpf(1.0, dirty_control_penalty, pow(charge, 1.45))
	var lag := lerpf(3.0, 20.0, 1.0 - control)

	global_position = global_position.lerp(target, lag * delta)

	var shake_strength := lerpf(0.8, max_shake * 1.35, 1.0 - control)
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
