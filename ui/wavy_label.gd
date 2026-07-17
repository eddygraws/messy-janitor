class_name WavyLabel
extends Control

## Karakter bazlı dalga animasyonlu metin (Label yerine geçer).

var _text: String = ""
@export var text: String:
	get:
		return _text
	set(value):
		if _text == value:
			return
		_text = value
		queue_redraw()
@export var font_size: int = 28
@export var font_color: Color = Color(1, 1, 1, 1)
@export var wave_amplitude: float = 2.0
@export var wave_speed: float = 2.2
@export var wave_frequency: float = 0.38
@export var horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
@export var vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER
@export var enable_rainbow: bool = false
@export var enable_shimmer: bool = true
@export var glow_on_high_wave: bool = false

const UI_GLOW_SHADER: Shader = preload("res://shaders/ui_glow.gdshader")

var _time: float = 0.0
var _glow_material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if glow_on_high_wave and UI_GLOW_SHADER != null:
		_glow_material = ShaderMaterial.new()
		_glow_material.shader = UI_GLOW_SHADER
		_glow_material.set_shader_parameter("intensity", 0.35)
		material = _glow_material


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _text.is_empty():
		return

	var font := ThemeDB.fallback_font
	var fs := font_size if font_size > 0 else ThemeDB.fallback_font_size
	var total_w := _measure_width(font, fs)
	var start_x := _align_start_x(total_w)
	var base_y := _align_base_y(fs)

	var x := start_x
	var t := _time
	for i in _text.length():
		var ch := _text.substr(i, 1)
		if ch == "\n":
			x = start_x
			continue
		var wave := sin(t * wave_speed + float(i) * wave_frequency) * wave_amplitude
		var col := font_color
		if enable_rainbow:
			var hue := fmod(t * 0.12 + float(i) * 0.07, 1.0)
			col = col.lerp(Color.from_hsv(hue, 0.45, 1.0), 0.55)
		if enable_shimmer:
			var shimmer := sin(t * 3.2 + float(i) * 0.55) * 0.5 + 0.5
			col = col.lerp(Color(1.0, 0.95, 0.75), shimmer * 0.18)

		draw_string(font, Vector2(x, base_y + wave), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func _measure_width(font: Font, fs: int) -> float:
	var w := 0.0
	for i in _text.length():
		var ch := _text.substr(i, 1)
		if ch == "\n":
			continue
		w += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return w


func _align_start_x(total_w: float) -> float:
	match horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			return (size.x - total_w) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			return size.x - total_w
		_:
			return 0.0


func _align_base_y(fs: int) -> float:
	match vertical_alignment:
		VERTICAL_ALIGNMENT_TOP:
			return float(fs)
		VERTICAL_ALIGNMENT_BOTTOM:
			return size.y - fs * 0.25
		_:
			return size.y * 0.5 + fs * 0.32
