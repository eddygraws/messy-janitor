extends Node2D

signal cursor_moved(position: Vector2)
signal cursor_clicked(position: Vector2)

const MOP_SCRUB_SHADER := preload("res://shaders/mop_scrub.gdshader")

@export var stamina_path: NodePath = ^"../StaminaComponent"
@export var stress_path: NodePath = ^"../StressComponent"
@export var mop_path: NodePath = ^"../MopComponent"
@export var equipment_path: NodePath = ^"../EquipmentComponent"
@export var router_path: NodePath = ^"../CursorClickerRouter"
@export var dirty_control_penalty: float = 0.38
@export var follow_speed: float = 14.0
@export var max_shake: float = 6.0
@export var noise_frequency: float = 3.0
@export var panic_shake_multiplier: float = 2.4
@export var panic_freq_multiplier: float = 1.8
@export var drunk_decay: float = 0.22
@export var max_drunk: float = 1.0
@export var scrub_fade_speed: float = 10.0

var _stamina: StaminaComponent
var _stress: StressComponent
var _mop: MopComponent
var _equipment: EquipmentComponent
var _router: CursorClickRouter
var _tool_sprite: Sprite2D
var _crosshair: Sprite2D
var _mop_scrub_mat: ShaderMaterial
var _scrub_intensity: float = 0.0
var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _panic: bool = false
var _drunk: float = 0.0
var _antidote_timer: float = 0.0


func add_drunk(amount: float) -> void:
	if _antidote_timer > 0.0:
		return
	_drunk = minf(max_drunk, _drunk + amount)
	if _tool_sprite != null:
		_tool_sprite.modulate = Color(0.75, 0.55, 1.0).lerp(Color.WHITE, 1.0 - _drunk)


func clear_drunk() -> void:
	_drunk = 0.0
	if _tool_sprite != null:
		_tool_sprite.modulate = Color.WHITE
		_tool_sprite.rotation = 0.0


func grant_antidote(seconds: float) -> void:
	_antidote_timer = maxf(_antidote_timer, seconds)
	clear_drunk()


func _ready() -> void:
	_stamina = get_node(stamina_path) as StaminaComponent
	_stress = get_node_or_null(stress_path) as StressComponent
	_mop = get_node_or_null(mop_path) as MopComponent
	_equipment = get_node_or_null(equipment_path) as EquipmentComponent
	_router = get_node_or_null(router_path) as CursorClickRouter
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

	z_as_relative = false
	z_index = 20

	_tool_sprite = Sprite2D.new()
	_tool_sprite.name = "ToolSprite"
	_tool_sprite.centered = true
	_tool_sprite.z_as_relative = true
	_tool_sprite.z_index = 0
	_mop_scrub_mat = ShaderMaterial.new()
	_mop_scrub_mat.shader = MOP_SCRUB_SHADER
	_mop_scrub_mat.set_shader_parameter("intensity", 0.0)
	_tool_sprite.material = _mop_scrub_mat
	add_child(_tool_sprite)

	_crosshair = Sprite2D.new()
	_crosshair.name = "Crosshair"
	_crosshair.centered = true
	_crosshair.texture = GameAssets.get_crosshair()
	_crosshair.z_as_relative = true
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
	if _antidote_timer > 0.0:
		_antidote_timer = maxf(0.0, _antidote_timer - delta)
	if _drunk > 0.0:
		_drunk = maxf(0.0, _drunk - drunk_decay * delta)
		if _tool_sprite != null:
			_tool_sprite.modulate = Color(0.75, 0.55, 1.0).lerp(Color.WHITE, 1.0 - _drunk)

	var target := _get_world_mouse_pos()
	var control := _stamina.get_control_factor() if _stamina else 1.0
	if _mop != null:
		var charge := _mop.get_charge()
		control *= lerpf(1.0, dirty_control_penalty, pow(charge, 1.45))
	# İksir sarhoşluğu: takip gecikir, kontrol bozulur
	control *= lerpf(1.0, 0.28, _drunk)
	var lag := lerpf(3.0, 20.0, 1.0 - control)

	# Sarhoşken hedef kayar (dalgalı ofset)
	if _drunk > 0.05:
		var sway := Vector2(
			sin(_time * 2.8 + _drunk * 4.0) * (18.0 + _drunk * 42.0),
			cos(_time * 2.1) * (12.0 + _drunk * 28.0)
		)
		target += sway

	global_position = global_position.lerp(target, lag * delta)

	var shake_strength := lerpf(0.8, max_shake * 1.35, 1.0 - control)
	var freq := noise_frequency
	if _panic:
		shake_strength *= panic_shake_multiplier
		freq *= panic_freq_multiplier
	shake_strength *= 1.0 + _drunk * 1.8
	freq *= 1.0 + _drunk * 1.4

	var shake := Vector2(
		_noise.get_noise_2d(_time * freq, 0.0),
		_noise.get_noise_2d(0.0, _time * freq)
	) * shake_strength

	global_position += shake

	_update_mop_scrub_fx(delta)

	if _tool_sprite != null and _drunk > 0.05:
		_tool_sprite.rotation = sin(_time * 5.0) * _drunk * 0.35
		_tool_sprite.modulate = Color(0.75, 0.55, 1.0).lerp(Color.WHITE, 1.0 - _drunk)
	elif _tool_sprite != null:
		var scrub_wobble := sin(_time * 28.0) * 0.12 * _scrub_intensity
		_tool_sprite.rotation = scrub_wobble
		# Paspas kirliliği imleçte de görünsün
		if _mop != null and _equipment != null and _equipment.get_current() == 0:
			var ch := _mop.get_charge()
			_tool_sprite.modulate = Color.WHITE.lerp(Color(0.38, 0.2, 0.08), pow(ch, 0.55))
		else:
			_tool_sprite.modulate = Color.WHITE

	cursor_moved.emit(global_position)


func _update_mop_scrub_fx(delta: float) -> void:
	if _mop_scrub_mat == null or _tool_sprite == null:
		return
	var mop_out := _equipment != null and _equipment.get_current() == 0
	var scrubbing := mop_out and _router != null and _router.is_actively_scrubbing()
	var target := 1.0 if scrubbing else 0.0
	_scrub_intensity = move_toward(_scrub_intensity, target, scrub_fade_speed * delta)
	_mop_scrub_mat.set_shader_parameter("intensity", _scrub_intensity)
	var dirt := _mop.get_charge() if (_mop != null and mop_out) else 0.0
	_mop_scrub_mat.set_shader_parameter("dirt", dirt)
	# Scrub yokken ve başka alette material etkisiz kalsın (intensity 0)
	if not mop_out and _scrub_intensity < 0.01:
		_scrub_intensity = 0.0
		_mop_scrub_mat.set_shader_parameter("intensity", 0.0)


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
