class_name TaskBanner
extends Control

## WarioWare tarzı emirler — üst şerit, gameplay ortası açık.

signal flash_done

var _label: Label
var _sub: Label
var _timer_bar: ColorRect
var _timer_fill: ColorRect
var _flash: ColorRect
var _vignette: ColorRect
var _phase_label: Label
var _panel: PanelContainer
var _tween: Tween
var _time_ratio: float = 0.0
var _bar_color: Color = Color(1, 0.55, 0.2)
var _bar_width: float = 420.0
var _vignette_heat: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	z_index = 50

	_vignette = ColorRect.new()
	_vignette.name = "PhaseVignette"
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.color = Color(0.7, 0.05, 0.08, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.z_index = -1
	add_child(_vignette)

	_flash = ColorRect.new()
	_flash.name = "PhaseFlash"
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.z_index = 0
	add_child(_flash)

	# Emir paneli — üstte, gameplay'i kapatmasın
	_panel = PanelContainer.new()
	_panel.name = "CommandPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = -260.0
	_panel.offset_right = 260.0
	_panel.offset_top = 18.0
	_panel.offset_bottom = 150.0
	_panel.modulate = Color(1, 1, 1, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.78)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)

	_label = Label.new()
	_label.name = "TaskLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 56)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 12)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_label)

	_sub = Label.new()
	_sub.name = "TaskSub"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", 18)
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_sub.add_theme_constant_override("outline_size", 6)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_sub)

	_timer_bar = ColorRect.new()
	_timer_bar.name = "TimerBarBg"
	_timer_bar.color = Color(0.1, 0.1, 0.12, 0.85)
	_timer_bar.custom_minimum_size = Vector2(_bar_width, 10)
	_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_bar.visible = false
	vbox.add_child(_timer_bar)

	_timer_fill = ColorRect.new()
	_timer_fill.name = "TimerBarFill"
	_timer_fill.position = Vector2.ZERO
	_timer_fill.size = Vector2(_bar_width, 10)
	_timer_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_bar.add_child(_timer_fill)

	# Faz yazısı — üst şerit, ortayı kapatmaz
	_phase_label = Label.new()
	_phase_label.name = "PhaseLabel"
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_label.anchor_left = 0.5
	_phase_label.anchor_right = 0.5
	_phase_label.anchor_top = 0.0
	_phase_label.anchor_bottom = 0.0
	_phase_label.offset_left = -280.0
	_phase_label.offset_right = 280.0
	_phase_label.offset_top = 8.0
	_phase_label.offset_bottom = 64.0
	_phase_label.add_theme_font_size_override("font_size", 42)
	_phase_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_phase_label.add_theme_constant_override("outline_size", 10)
	_phase_label.modulate = Color(1, 1, 1, 0)
	_phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_label.z_index = 60
	add_child(_phase_label)


func show_task(text: String, color: Color, subtitle: String = "", special: String = "") -> void:
	_bar_color = color
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_sub.text = subtitle
	_sub.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	_timer_bar.visible = true
	_timer_fill.color = color
	_timer_fill.size = Vector2(_bar_width, 10)
	var style := _panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style = style.duplicate() as StyleBoxFlat
		if special == "stop":
			style.bg_color = Color(0.55, 0.04, 0.08, 0.88)
			_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.95))
			_sub.add_theme_color_override("font_color", Color(1.0, 0.75, 0.75))
		else:
			style.bg_color = Color(0.05, 0.06, 0.08, 0.72)
		_panel.add_theme_stylebox_override("panel", style)
	_bar_width = 360.0
	_panel.modulate = Color(1, 1, 1, 0)
	_panel.scale = Vector2(1.12 if special == "stop" else 1.08, 1.12 if special == "stop" else 1.08)
	_panel.pivot_offset = Vector2(260, 66)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.1)
	_tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if special == "stop":
		_flash.color = Color(0.85, 0.05, 0.1, 0.0)
		_tween.parallel().tween_property(_flash, "color:a", 0.18, 0.08)
		_tween.tween_property(_flash, "color:a", 0.0, 0.28)


func hide_task(success: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	var flash_col := Color(0.45, 1.0, 0.55) if success else Color(1.0, 0.35, 0.35)
	_tween.tween_property(_panel, "modulate", Color(flash_col.r, flash_col.g, flash_col.b, 1.0), 0.08)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.22)
	_tween.tween_callback(func() -> void:
		_timer_bar.visible = false
		_label.text = ""
		_sub.text = ""
	)


func set_time_ratio(ratio: float) -> void:
	_time_ratio = clampf(ratio, 0.0, 1.0)
	if _timer_fill == null or not _timer_bar.visible:
		return
	_timer_fill.size = Vector2(_bar_width * _time_ratio, 10)
	_timer_fill.color = _bar_color.lerp(Color(1.0, 0.2, 0.25), 1.0 - _time_ratio)


func flash_fail() -> void:
	_timer_bar.visible = false
	_label.text = "KAÇIRDIN!"
	_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.28))
	_sub.text = "Çok yavaştın!"
	_sub.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
	_panel.modulate = Color(1, 0.2, 0.22, 1)
	_phase_label.text = "KAÇIRDIN!"
	_phase_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.2))
	_phase_label.modulate = Color(1, 1, 1, 0)
	_phase_label.scale = Vector2(1.15, 1.15)
	_phase_label.pivot_offset = Vector2(280, 28)
	_flash.color = Color(0.9, 0.02, 0.05, 0.0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_flash, "color:a", 0.28, 0.05)
	_tween.parallel().tween_property(_phase_label, "modulate:a", 1.0, 0.08)
	_tween.parallel().tween_property(_phase_label, "scale", Vector2.ONE, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_panel, "scale", Vector2(1.04, 1.04), 0.08)
	_tween.tween_interval(0.45)
	_tween.tween_property(_flash, "color:a", 0.0, 0.3)
	_tween.parallel().tween_property(_phase_label, "modulate:a", 0.0, 0.25)
	_tween.parallel().tween_property(_panel, "modulate:a", 0.0, 0.22)
	_tween.tween_callback(func() -> void:
		_label.text = ""
		_sub.text = ""
		_panel.scale = Vector2.ONE
	)


func set_vignette_heat(amount: float) -> void:
	_vignette_heat = clampf(amount, 0.0, 1.0)
	if _vignette == null:
		return
	_vignette.color = Color(0.72, 0.05, 0.1, _vignette_heat * 0.28)


func flash_phase(phase: int) -> void:
	var text := ""
	var col := Color(1, 1, 1)
	match phase:
		2:
			text = "HIZLAN!"
			col = Color(1.0, 0.75, 0.2)
		3:
			text = "SON PATLAMA!"
			col = Color(1.0, 0.25, 0.35)
		_:
			return
	# Üst şerit + çok hafif flaş — ortadaki gameplay açık kalsın
	_phase_label.text = text
	_phase_label.add_theme_color_override("font_color", col)
	_phase_label.modulate = Color(1, 1, 1, 0)
	_phase_label.scale = Vector2(1.12, 1.12)
	_phase_label.pivot_offset = Vector2(280, 28)
	_flash.color = Color(col.r, col.g, col.b, 0.0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_flash, "color:a", 0.12, 0.06)
	_tween.parallel().tween_property(_phase_label, "modulate:a", 1.0, 0.08)
	_tween.parallel().tween_property(_phase_label, "scale", Vector2.ONE, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.55)
	_tween.tween_property(_flash, "color:a", 0.0, 0.22)
	_tween.parallel().tween_property(_phase_label, "modulate:a", 0.0, 0.28)
	flash_done.emit()


func flash_boss(title: String = "SET-PIECE") -> void:
	_phase_label.text = title if not title.is_empty() else "BOSS!"
	_phase_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.35))
	_phase_label.modulate = Color(1, 1, 1, 0)
	_phase_label.scale = Vector2(1.1, 1.1)
	_phase_label.pivot_offset = Vector2(280, 28)
	_flash.color = Color(0.9, 0.1, 0.15, 0.0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_flash, "color:a", 0.16, 0.07)
	_tween.parallel().tween_property(_phase_label, "modulate:a", 1.0, 0.1)
	_tween.parallel().tween_property(_phase_label, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.75)
	_tween.tween_property(_flash, "color:a", 0.0, 0.28)
	_tween.parallel().tween_property(_phase_label, "modulate:a", 0.0, 0.3)
	flash_done.emit()
