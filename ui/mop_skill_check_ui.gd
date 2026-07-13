class_name MopSkillCheckUI
extends Control

signal attempt_pressed

const BAR_W := 380.0
const BAR_H := 34.0

## İbre hızı — temiz paspasta (charge≈0). Düşük = daha yavaş.
@export_group("İbre Hızı")
@export_range(0.3, 4.0, 0.05, "suffix:sn/s") var needle_speed_clean: float = 0.9
## İbre hızı — kirli paspasta (charge≈1). Düşük = daha yavaş.
@export_range(0.3, 5.0, 0.05, "suffix:sn/s") var needle_speed_dirty: float = 1.55

## Skill check süresi — temiz paspas (saniye). Yüksek = daha fazla tepki süresi.
@export_group("Süre Limiti")
@export_range(1.0, 8.0, 0.1, "suffix:s") var time_limit_clean: float = 3.4
## Skill check süresi — kirli paspas (saniye).
@export_range(0.8, 6.0, 0.1, "suffix:s") var time_limit_dirty: float = 2.5

## Yeşil bölge genişliği — temiz / kirli (0–1 bar oranı).
@export_group("Hedef Bölge")
@export_range(0.06, 0.4, 0.01) var zone_width_clean: float = 0.24
@export_range(0.04, 0.3, 0.01) var zone_width_dirty: float = 0.13
## Mükemmel vuruş alanı, iyi bölgenin yüzdesi.
@export_range(0.05, 0.4, 0.01) var great_zone_ratio: float = 0.18

var _active: bool = false
var _needle: float = 0.0
var _dir: float = 1.0
var _zone_start: float = 0.42
var _zone_end: float = 0.58
var _great_half: float = 0.045
var _time_left: float = 2.4
var _needle_speed: float = 1.0
var _speed_mult: float = 1.0
var _time_mult: float = 1.0


func _ready() -> void:
	visible = false
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func begin(charge: float, speed_multiplier: float = 1.0, time_multiplier: float = 1.0) -> void:
	_active = true
	visible = true
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_speed_mult = maxf(0.1, speed_multiplier)
	_time_mult = maxf(0.1, time_multiplier)

	_needle = randf_range(0.12, 0.88)
	_dir = -1.0 if randf() > 0.5 else 1.0

	var zone_width := lerpf(zone_width_clean, zone_width_dirty, charge)
	var center := randf_range(zone_width * 0.5, 1.0 - zone_width * 0.5)
	_zone_start = center - zone_width * 0.5
	_zone_end = center + zone_width * 0.5
	_great_half = zone_width * great_zone_ratio

	_time_left = lerpf(time_limit_clean, time_limit_dirty, charge) * _time_mult
	_needle_speed = lerpf(needle_speed_clean, needle_speed_dirty, charge) * _speed_mult
	queue_redraw()


func hide_check() -> void:
	_active = false
	visible = false
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func is_active() -> bool:
	return _active


func evaluate() -> int:
	if not _active:
		return 0
	if _needle >= _zone_start and _needle <= _zone_end:
		var center := (_zone_start + _zone_end) * 0.5
		if absf(_needle - center) <= _great_half:
			return 2
		return 1
	return 0


func _process(delta: float) -> void:
	if not _active:
		return
	_needle += _dir * _needle_speed * delta
	if _needle >= 1.0:
		_needle = 1.0
		_dir = -1.0
	elif _needle <= 0.0:
		_needle = 0.0
		_dir = 1.0
	_time_left -= delta
	if _time_left <= 0.0:
		attempt_pressed.emit()
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var cx := size.x * 0.5
	var cy := size.y * 0.5
	var bar_origin := Vector2(cx - BAR_W * 0.5, cy - BAR_H * 0.5)

	draw_rect(Rect2(bar_origin - Vector2(4, 4), Vector2(BAR_W + 8, BAR_H + 8)), Color(0.05, 0.05, 0.08, 0.92), true)
	draw_rect(Rect2(bar_origin, Vector2(BAR_W, BAR_H)), Color(0.15, 0.16, 0.22, 1.0), true)

	var great_center := (_zone_start + _zone_end) * 0.5
	var great_w := _great_half * 2.0 * BAR_W
	var great_x := bar_origin.x + great_center * BAR_W - great_w * 0.5
	draw_rect(Rect2(great_x, bar_origin.y + 2, great_w, BAR_H - 4), Color(0.35, 0.95, 0.55, 0.95), true)

	var good_x := bar_origin.x + _zone_start * BAR_W
	var good_w := (_zone_end - _zone_start) * BAR_W
	draw_rect(Rect2(good_x, bar_origin.y + 2, good_w, BAR_H - 4), Color(0.25, 0.75, 0.42, 0.55), true)

	var needle_x := bar_origin.x + _needle * BAR_W
	draw_line(Vector2(needle_x, bar_origin.y - 6), Vector2(needle_x, bar_origin.y + BAR_H + 6), Color(1, 0.92, 0.35, 1), 4.0)

	var hint := "DURULA — SPACE / TIKLA"
	var font := ThemeDB.fallback_font
	var fs := ThemeDB.fallback_font_size + 4
	draw_string(font, Vector2(cx - 110, bar_origin.y - 14), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.9, 0.88, 0.75, 0.95))


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_accept"):
		attempt_pressed.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_SPACE:
			attempt_pressed.emit()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			attempt_pressed.emit()
			get_viewport().set_input_as_handled()
