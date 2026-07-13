class_name PostProcessDirector
extends CanvasLayer

@export var stress_path: NodePath = ^"../StressComponent"
@export var enabled_in_menu: bool = false

var _stress: StressComponent
var _material: ShaderMaterial
var _menu_open: bool = true


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stress = get_node_or_null(stress_path) as StressComponent
	if _stress != null:
		_stress.stress_changed.connect(_on_stress_changed)

	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/post_gothic.gdshader")
	_material.set_shader_parameter("stress", 0.0)

	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)

	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _material
	add_child(rect)

	if _stress != null:
		_on_stress_changed(_stress.current_stress, _stress.max_stress)


func set_menu_open(open: bool) -> void:
	_menu_open = open
	visible = enabled_in_menu or not open


func _on_stress_changed(current: float, maximum: float) -> void:
	if _material == null:
		return
	var ratio := current / maximum if maximum > 0.0 else 0.0
	_material.set_shader_parameter("stress", ratio)
