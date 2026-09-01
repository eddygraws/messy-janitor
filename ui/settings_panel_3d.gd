class_name SettingsPanel3D
extends Control

## Dil / grafik / ses paneli — başlık ekranının üstünde.

signal closed

var _title: Label
var _lang_label: Label
var _gfx_label: Label
var _audio_label: Label
var _full_btn: Button
var _vsync_btn: Button
var _outline_btn: Button
var _pixel_btns: Array[Button] = []
var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _master_val: Label
var _music_val: Label
var _sfx_val: Label
var _master_lab: Label
var _music_lab: Label
var _sfx_lab: Label
var _full_lab: Label
var _vsync_lab: Label
var _pixel_lab: Label
var _outline_lab: Label
var _back_btn: Button
var _lang_tr: Button
var _lang_en: Button
var _syncing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	_build()
	GameSettings.locale_changed.connect(func(_c: String) -> void: _refresh_texts())


func present() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	move_to_front()
	_sync_from_settings()
	_refresh_texts()


func dismiss() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			accept_event()
	)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.13, 0.97)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.95, 0.88, 0.55, 0.45)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	col.add_child(_title)

	_lang_label = _section_label()
	col.add_child(_lang_label)
	var lang_row := HBoxContainer.new()
	lang_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lang_row.add_theme_constant_override("separation", 12)
	col.add_child(lang_row)
	_lang_tr = _make_toggle("Türkçe", Color(0.28, 0.55, 0.38))
	_lang_en = _make_toggle("English", Color(0.32, 0.48, 0.7))
	_lang_tr.pressed.connect(func() -> void: GameSettings.set_locale("tr"))
	_lang_en.pressed.connect(func() -> void: GameSettings.set_locale("en"))
	lang_row.add_child(_lang_tr)
	lang_row.add_child(_lang_en)

	_gfx_label = _section_label()
	col.add_child(_gfx_label)

	var full_row := _labeled_row()
	_full_lab = full_row[0]
	_full_btn = _make_toggle("", Color(0.4, 0.5, 0.42))
	_full_btn.custom_minimum_size = Vector2(120, 36)
	_full_btn.pressed.connect(func() -> void:
		GameSettings.set_fullscreen(not GameSettings.fullscreen)
		_sync_from_settings()
	)
	full_row[1].add_child(_full_btn)
	col.add_child(full_row[2])

	var vs_row := _labeled_row()
	_vsync_lab = vs_row[0]
	_vsync_btn = _make_toggle("", Color(0.4, 0.5, 0.42))
	_vsync_btn.custom_minimum_size = Vector2(120, 36)
	_vsync_btn.pressed.connect(func() -> void:
		GameSettings.set_vsync(not GameSettings.vsync)
		_sync_from_settings()
	)
	vs_row[1].add_child(_vsync_btn)
	col.add_child(vs_row[2])

	_pixel_lab = _section_label()
	col.add_child(_pixel_lab)
	var px_box := HBoxContainer.new()
	px_box.alignment = BoxContainer.ALIGNMENT_CENTER
	px_box.add_theme_constant_override("separation", 6)
	col.add_child(px_box)
	var sizes: Array[int] = [1, 2, 3, 4]
	for size in sizes:
		var b := _make_toggle("", Color(0.45, 0.4, 0.28))
		b.custom_minimum_size = Vector2(118, 36)
		var captured: int = size
		b.pressed.connect(func() -> void:
			GameSettings.set_pixel_size(captured)
			_sync_from_settings()
		)
		px_box.add_child(b)
		_pixel_btns.append(b)

	var ol_row := _labeled_row()
	_outline_lab = ol_row[0]
	_outline_btn = _make_toggle("", Color(0.4, 0.5, 0.42))
	_outline_btn.custom_minimum_size = Vector2(120, 36)
	_outline_btn.pressed.connect(func() -> void:
		GameSettings.set_outlines(not GameSettings.outlines)
		_sync_from_settings()
	)
	ol_row[1].add_child(_outline_btn)
	col.add_child(ol_row[2])

	_audio_label = _section_label()
	col.add_child(_audio_label)

	var m := _slider_row()
	_master_lab = m[0]
	_master_slider = m[1]
	_master_val = m[2]
	_master_slider.value_changed.connect(func(v: float) -> void:
		if _syncing:
			return
		GameSettings.set_master_volume(v)
		_master_val.text = _pct(v)
	)
	col.add_child(m[3])

	var mu := _slider_row()
	_music_lab = mu[0]
	_music_slider = mu[1]
	_music_val = mu[2]
	_music_slider.value_changed.connect(func(v: float) -> void:
		if _syncing:
			return
		GameSettings.set_music_volume(v)
		_music_val.text = _pct(v)
	)
	col.add_child(mu[3])

	var sx := _slider_row()
	_sfx_lab = sx[0]
	_sfx_slider = sx[1]
	_sfx_val = sx[2]
	_sfx_slider.value_changed.connect(func(v: float) -> void:
		if _syncing:
			return
		GameSettings.set_sfx_volume(v)
		_sfx_val.text = _pct(v)
	)
	col.add_child(sx[3])

	_back_btn = _make_toggle("", Color(0.35, 0.32, 0.28))
	_back_btn.custom_minimum_size = Vector2(200, 44)
	_back_btn.pressed.connect(dismiss)
	var back_wrap := HBoxContainer.new()
	back_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	back_wrap.add_child(_back_btn)
	col.add_child(back_wrap)


func _section_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.72, 0.82, 0.78))
	return l


func _labeled_row() -> Array:
	var wrap := HBoxContainer.new()
	wrap.add_theme_constant_override("separation", 12)
	var lab := Label.new()
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.add_theme_font_size_override("font_size", 16)
	lab.add_theme_color_override("font_color", Color(0.88, 0.9, 0.86))
	var right := HBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	wrap.add_child(lab)
	wrap.add_child(right)
	return [lab, right, wrap]


func _slider_row() -> Array:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	var lab := Label.new()
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.add_theme_font_size_override("font_size", 16)
	lab.add_theme_color_override("font_color", Color(0.88, 0.9, 0.86))
	var val := Label.new()
	val.custom_minimum_size = Vector2(48, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 16)
	val.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	head.add_child(lab)
	head.add_child(val)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.custom_minimum_size = Vector2(0, 22)
	wrap.add_child(head)
	wrap.add_child(sl)
	return [lab, sl, val, wrap]


func _make_toggle(text: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(140, 40)
	_paint_btn(b, accent, false)
	b.set_meta("accent", accent)
	return b


func _paint_btn(b: Button, accent: Color, on: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent.lightened(0.08) if on else accent.darkened(0.28)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = accent.lightened(0.35) if on else accent.darkened(0.05)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.96, 0.97, 0.92))
	b.add_theme_font_size_override("font_size", 16)


func _sync_from_settings() -> void:
	_syncing = true
	_master_slider.value = GameSettings.master_volume
	_music_slider.value = GameSettings.music_volume
	_sfx_slider.value = GameSettings.sfx_volume
	_master_val.text = _pct(GameSettings.master_volume)
	_music_val.text = _pct(GameSettings.music_volume)
	_sfx_val.text = _pct(GameSettings.sfx_volume)
	_syncing = false
	_refresh_texts()


func _refresh_texts() -> void:
	_title.text = GameSettings.t("settings_title")
	_lang_label.text = GameSettings.t("lang")
	_gfx_label.text = GameSettings.t("graphics")
	_audio_label.text = GameSettings.t("audio")
	_full_lab.text = GameSettings.t("fullscreen")
	_vsync_lab.text = GameSettings.t("vsync")
	_pixel_lab.text = GameSettings.t("pixel")
	_outline_lab.text = GameSettings.t("outlines")
	_master_lab.text = GameSettings.t("master")
	_music_lab.text = GameSettings.t("music")
	_sfx_lab.text = GameSettings.t("sfx")
	_back_btn.text = GameSettings.t("back")
	_full_btn.text = GameSettings.t("on") if GameSettings.fullscreen else GameSettings.t("off")
	_vsync_btn.text = GameSettings.t("on") if GameSettings.vsync else GameSettings.t("off")
	_outline_btn.text = GameSettings.t("on") if GameSettings.outlines else GameSettings.t("off")
	var px_labels := ["pixel_off", "pixel_2", "pixel_3", "pixel_4"]
	var px_vals := [1, 2, 3, 4]
	for i in _pixel_btns.size():
		_pixel_btns[i].text = GameSettings.t(px_labels[i])
		_paint_btn(_pixel_btns[i], _pixel_btns[i].get_meta("accent"), GameSettings.pixel_size == px_vals[i])
	_paint_btn(_full_btn, _full_btn.get_meta("accent"), GameSettings.fullscreen)
	_paint_btn(_vsync_btn, _vsync_btn.get_meta("accent"), GameSettings.vsync)
	_paint_btn(_outline_btn, _outline_btn.get_meta("accent"), GameSettings.outlines)
	_paint_btn(_lang_tr, _lang_tr.get_meta("accent"), GameSettings.locale == "tr")
	_paint_btn(_lang_en, _lang_en.get_meta("accent"), GameSettings.locale == "en")


func _pct(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			dismiss()
