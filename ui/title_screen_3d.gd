class_name TitleScreen3D
extends Control

## Açılış ekranı — Oyna / Ayarlar / Dil.

signal continued

const SettingsPanelScript := preload("res://ui/settings_panel_3d.gd")
const CreditsScreenScript := preload("res://ui/credits_screen_3d.gd")
const HudIcons := preload("res://ui/hud_icons.gd")

var _active: bool = false
var _closing: bool = false
var _prompt: Button
var _settings_btn: Button
var _quit_btn: Button
var _credits_btn: Button
var _tag: Label
var _hint: Label
var _lang_label: Label
var _lang_tr: Button
var _lang_en: Button
var _prompt_tween: Tween
var _sfx: AudioStreamPlayer
var _settings
var _credits
var _menu_col: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_as_relative = false
	z_index = 220
	_apply_full_rect()
	_build()
	GameSettings.locale_changed.connect(func(_c: String) -> void: _refresh_texts())


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_RESIZED \
			or what == NOTIFICATION_VISIBILITY_CHANGED:
		_apply_full_rect()


func _apply_full_rect() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2.ZERO
	set_deferred("position", Vector2.ZERO)


func _build() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = GameSettings.BUS_SFX
	_sfx.volume_db = -4.0
	add_child(_sfx)

	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0.05, 0.07, 0.09, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var top_wash := ColorRect.new()
	top_wash.color = Color(0.18, 0.22, 0.16, 0.35)
	top_wash.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_wash.offset_bottom = 220.0
	top_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_wash)

	var bottom_wash := ColorRect.new()
	bottom_wash.color = Color(0.08, 0.1, 0.14, 0.55)
	bottom_wash.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_wash.offset_top = -180.0
	bottom_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_wash)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_menu_col = VBoxContainer.new()
	_menu_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_col.add_theme_constant_override("separation", 14)
	_menu_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_menu_col)

	var broom := TextureRect.new()
	broom.texture = HudIcons.tex("mop")
	broom.custom_minimum_size = Vector2(96, 96)
	broom.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	broom.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	broom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_col.add_child(broom)

	var brand := WavyLabel.new()
	brand.text = "MESSY JANITOR"
	brand.font_size = 64
	brand.font_color = Color(0.95, 0.88, 0.55)
	brand.wave_amplitude = 4.0
	brand.wave_speed = 2.4
	brand.enable_shimmer = true
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.custom_minimum_size = Vector2(720, 78)
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_col.add_child(brand)

	_tag = Label.new()
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.add_theme_font_size_override("font_size", 22)
	_tag.add_theme_color_override("font_color", Color(0.72, 0.82, 0.78))
	_tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_tag.add_theme_constant_override("outline_size", 4)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_col.add_child(_tag)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_col.add_child(spacer)

	_prompt = _menu_button("", Color(0.28, 0.55, 0.38), Vector2(360, 56), 26)
	_prompt.pressed.connect(_continue)
	_menu_col.add_child(_prompt)

	_settings_btn = _menu_button("", Color(0.38, 0.42, 0.5), Vector2(360, 50), 22)
	_settings_btn.pressed.connect(_open_settings)
	_menu_col.add_child(_settings_btn)

	_credits_btn = _menu_button("", Color(0.35, 0.36, 0.32), Vector2(360, 46), 20)
	_credits_btn.pressed.connect(_open_credits)
	_menu_col.add_child(_credits_btn)

	_lang_label = Label.new()
	_lang_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lang_label.add_theme_font_size_override("font_size", 15)
	_lang_label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.66))
	_lang_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_col.add_child(_lang_label)

	var lang_row := HBoxContainer.new()
	lang_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lang_row.add_theme_constant_override("separation", 12)
	_menu_col.add_child(lang_row)
	_lang_tr = _menu_button("Türkçe", Color(0.28, 0.55, 0.38), Vector2(150, 40), 16)
	_lang_en = _menu_button("English", Color(0.32, 0.48, 0.7), Vector2(150, 40), 16)
	_lang_tr.pressed.connect(func() -> void: GameSettings.set_locale("tr"))
	_lang_en.pressed.connect(func() -> void: GameSettings.set_locale("en"))
	lang_row.add_child(_lang_tr)
	lang_row.add_child(_lang_en)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.58))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_col.add_child(_hint)

	_quit_btn = _menu_button("", Color(0.28, 0.22, 0.22), Vector2(200, 40), 16)
	_quit_btn.pressed.connect(func() -> void: get_tree().quit())
	var quit_wrap := HBoxContainer.new()
	quit_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	quit_wrap.add_child(_quit_btn)
	_menu_col.add_child(quit_wrap)

	_settings = SettingsPanelScript.new()
	_settings.name = "SettingsPanel"
	_settings.closed.connect(_on_settings_closed)
	add_child(_settings)

	_credits = CreditsScreenScript.new()
	_credits.name = "CreditsScreen"
	_credits.closed.connect(_on_credits_closed)
	add_child(_credits)

	_refresh_texts()


func _menu_button(text: String, accent: Color, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent.darkened(0.22)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = accent.lightened(0.28)
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = accent.darkened(0.05)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.darkened(0.4)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", Color(0.96, 0.97, 0.92))
	b.add_theme_font_size_override("font_size", font_size)
	b.set_meta("accent", accent)
	return b


func _paint_lang(b: Button, on: bool) -> void:
	var accent: Color = b.get_meta("accent")
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent.lightened(0.06) if on else accent.darkened(0.28)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = accent.lightened(0.35) if on else accent.darkened(0.05)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)


func _refresh_texts() -> void:
	_tag.text = GameSettings.t("tag")
	_prompt.text = GameSettings.t("play")
	_settings_btn.text = GameSettings.t("settings")
	_credits_btn.text = GameSettings.t("credits")
	_quit_btn.text = GameSettings.t("quit")
	_hint.text = GameSettings.t("hint")
	_lang_label.text = GameSettings.t("lang")
	_paint_lang(_lang_tr, GameSettings.locale == "tr")
	_paint_lang(_lang_en, GameSettings.locale == "en")


func present() -> void:
	_active = true
	_closing = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_full_rect()
	visible = true
	move_to_front()
	if _settings != null:
		_settings.visible = false
	if _credits != null:
		_credits.visible = false
	_refresh_texts()
	modulate = Color(1, 1, 1, 0)
	for _i in 2:
		await get_tree().process_frame
		_apply_full_rect()
	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(self, "modulate:a", 1.0, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade.finished
	_start_prompt_pulse()


func _start_prompt_pulse() -> void:
	if _prompt == null:
		return
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt.modulate.a = 1.0
	_prompt_tween = create_tween()
	_prompt_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_prompt_tween.set_loops()
	_prompt_tween.tween_property(_prompt, "modulate:a", 0.55, 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_prompt_tween.tween_property(_prompt, "modulate:a", 1.0, 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _open_settings() -> void:
	if not _active or _closing:
		return
	if _sfx != null:
		PrototypeSfx.play(_sfx, PrototypeSfx.Kind.TASK_OK, 1.12)
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt.modulate.a = 1.0
	_settings.present()


func _on_settings_closed() -> void:
	if _active and not _closing:
		_start_prompt_pulse()


func _open_credits() -> void:
	if not _active or _closing:
		return
	if _sfx != null:
		PrototypeSfx.play(_sfx, PrototypeSfx.Kind.TASK_OK, 1.08)
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt.modulate.a = 1.0
	_credits.present()


func _on_credits_closed() -> void:
	if _active and not _closing:
		_start_prompt_pulse()


func _continue() -> void:
	if not _active or _closing:
		return
	if _settings != null and _settings.visible:
		return
	if _credits != null and _credits.visible:
		return
	_closing = true
	_active = false
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	if _sfx != null:
		PrototypeSfx.play(_sfx, PrototypeSfx.Kind.TASK_OK, 1.05)
	var out := create_tween()
	out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	out.tween_property(self, "modulate:a", 0.0, 0.28)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await out.finished
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_closing = false
	continued.emit()


func _input(event: InputEvent) -> void:
	if not _active or _closing:
		return
	if _settings != null and _settings.visible:
		return
	if _credits != null and _credits.visible:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_open_settings()
			return
		if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_continue()
			return
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		if (event as InputEventJoypadButton).button_index == 0:
			get_viewport().set_input_as_handled()
			_continue()
