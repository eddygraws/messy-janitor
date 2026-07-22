class_name GameScreens
extends CanvasLayer

signal mode_selected(mode: int)
signal level_selected(index: int)
signal back_pressed
signal restart_pressed
signal pause_resume_pressed
signal pause_main_menu_pressed
signal pause_shown
signal pause_hidden
signal intro_finished

@onready var _start_screen: Control = $StartScreen
@onready var _over_screen: Control = $GameOverScreen
@onready var _level_screen: Control = $LevelSelectScreen
@onready var _level_grid: GridContainer = $LevelSelectScreen/Center/Grid
@onready var _level_back: Button = $LevelSelectScreen/Center/BackButton
@onready var _adventure_button: Button = $StartScreen/Center/AdventureButton
@onready var _proto3d_button: Button = $StartScreen/Center/EndlessButton
@onready var _restart_button: Button = $GameOverScreen/Center/RestartButton
@onready var _over_info: Label = $GameOverScreen/Center/InfoLabel
var _over_title: WavyLabel
@onready var _records_label: Label = $StartScreen/Center/RecordsLabel
@onready var _pause_screen: Control = $PauseScreen
@onready var _pause_resume: Button = $PauseScreen/Center/ResumeButton
@onready var _pause_menu: Button = $PauseScreen/Center/MainMenuButton
var _intro: IntroSequence


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_adventure_button.pressed.connect(func() -> void: mode_selected.emit(0))
	# Endless yerine 3D Overcooked prototip
	if _proto3d_button != null:
		_proto3d_button.text = "🧹  3D GARAJ (Overcooked)"
		_proto3d_button.pressed.connect(func() -> void: mode_selected.emit(2))
	_restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	_level_back.pressed.connect(func() -> void: back_pressed.emit())
	_pause_resume.pressed.connect(func() -> void: pause_resume_pressed.emit())
	_pause_menu.pressed.connect(func() -> void: pause_main_menu_pressed.emit())
	_over_screen.visible = false
	_level_screen.visible = false
	_pause_screen.visible = false
	_intro = IntroSequence.new()
	_intro.name = "IntroSequence"
	add_child(_intro)
	_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_intro.grow_vertical = Control.GROW_DIRECTION_BOTH
	_style_comedy_menu()
	show_start()
	call_deferred("_setup_wavy_menu_titles")


func _style_comedy_menu() -> void:
	var bg := _start_screen.get_node_or_null("BG") as ColorRect
	if bg != null:
		bg.color = Color(0.12, 0.14, 0.16, 0.94)
	_style_menu_button(_adventure_button, Color(0.28, 0.55, 0.38))
	_style_menu_button(_proto3d_button, Color(0.55, 0.38, 0.22))
	_adventure_button.text = "🗺  MACERA — 4 seviye"
	if _proto3d_button != null:
		_proto3d_button.text = "🧹  3D GARAJ — dans & bump"


func _style_menu_button(button: Button, accent: Color) -> void:
	if button == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = accent.darkened(0.25)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = accent.lightened(0.25)
	button.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = accent.darkened(0.05)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.darkened(0.4)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.95, 0.96, 0.9))
	button.add_theme_font_size_override("font_size", 24)


func set_records_text(text: String) -> void:
	if _records_label != null:
		_records_label.text = text


func show_start() -> void:
	_level_screen.visible = false
	_over_screen.visible = false
	_pause_screen.visible = false
	if _intro != null:
		_intro.visible = false
	_start_screen.visible = true
	_start_screen.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_start_screen, "modulate:a", 1.0, 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pop_button(_adventure_button)
	_pop_button(_proto3d_button)


func play_intro() -> void:
	_start_screen.visible = false
	_level_screen.visible = false
	_over_screen.visible = false
	_pause_screen.visible = false
	if _intro == null:
		_intro = IntroSequence.new()
		_intro.name = "IntroSequence"
		add_child(_intro)
	_intro.process_mode = Node.PROCESS_MODE_ALWAYS
	_intro.visible = true
	_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro.z_as_relative = false
	_intro.z_index = 200
	_intro.move_to_front()
	await _intro.play()
	intro_finished.emit()


func is_intro_open() -> bool:
	return _intro != null and _intro.visible


func hide_start() -> void:
	var tween := create_tween()
	tween.tween_property(_start_screen, "modulate:a", 0.0, 0.25)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _start_screen.visible = false)


func is_in_active_game() -> bool:
	return (
		not _start_screen.visible
		and not _level_screen.visible
		and not _over_screen.visible
		and not _pause_screen.visible
		and not is_intro_open()
	)


func is_pause_open() -> bool:
	return _pause_screen.visible


func show_pause() -> void:
	if not is_in_active_game():
		return
	pause_shown.emit()
	_pause_screen.visible = true
	_pause_screen.modulate.a = 0.0
	var center: Control = _pause_screen.get_node("Center")
	center.pivot_offset = center.size * 0.5
	center.scale = Vector2(0.92, 0.92)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_pause_screen, "modulate:a", 1.0, 0.2)
	tween.tween_property(center, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func hide_pause() -> void:
	if not _pause_screen.visible:
		return
	_pause_screen.visible = false
	pause_hidden.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_ESCAPE and key.keycode != KEY_PAUSE:
		return
	if _over_screen.visible or _start_screen.visible or _level_screen.visible or is_intro_open():
		return
	if is_pause_open():
		pause_resume_pressed.emit()
	else:
		show_pause()
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Seviye Seçim
# ---------------------------------------------------------------------------

func show_level_select(unlocked: int, best_scores: Array) -> void:
	_start_screen.visible = false
	_over_screen.visible = false
	var capped := mini(unlocked, LevelData.level_count())
	_build_level_buttons(maxi(1, capped), best_scores)
	_level_screen.visible = true
	_level_screen.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_level_screen, "modulate:a", 1.0, 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func hide_level_select() -> void:
	_level_screen.visible = false


func _build_level_buttons(unlocked: int, best_scores: Array) -> void:
	for child in _level_grid.get_children():
		child.queue_free()

	for i in LevelData.level_count():
		var info := LevelData.get_level(i)
		var level_num := i + 1
		var is_unlocked := level_num <= unlocked
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 110)
		btn.add_theme_font_size_override("font_size", 18)
		btn.disabled = not is_unlocked
		btn.focus_mode = Control.FOCUS_NONE

		var best := 0
		if i < best_scores.size():
			best = int(best_scores[i])

		if is_unlocked:
			var best_line := ("En iyi: %d" % best) if best > 0 else "Yeni!"
			var subtitle := String(info.get("subtitle", ""))
			btn.text = "%s\n%s\n%s" % [String(info.get("name", "Seviye %d" % level_num)), subtitle, best_line]
			var idx := i
			btn.pressed.connect(func() -> void: level_selected.emit(idx))
			_style_menu_button(btn, Color(0.32, 0.48, 0.58) if i > 0 else Color(0.45, 0.42, 0.28))
		else:
			btn.text = "🔒\n%s" % String(info.get("name", "Seviye %d" % level_num))

		_level_grid.add_child(btn)


# ---------------------------------------------------------------------------
# Oyun Sonu / Zafer
# ---------------------------------------------------------------------------

func show_game_over(title: String, info: String) -> void:
	_start_screen.visible = false
	_level_screen.visible = false
	_pause_screen.visible = false
	if _over_title == null or not is_instance_valid(_over_title):
		_over_title = _over_screen.get_node_or_null("Center/TitleLabel") as WavyLabel
	if _over_title != null:
		_over_title.text = title
	_over_info.text = info

	_over_screen.visible = true
	_over_screen.modulate.a = 0.0
	var center: Control = _over_screen.get_node("Center")
	center.pivot_offset = center.size * 0.5
	center.scale = Vector2(0.6, 0.6)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_over_screen, "modulate:a", 1.0, 0.3)
	tween.tween_property(center, "scale", Vector2.ONE, 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	_pop_button(_restart_button)


func _pop_button(button: Button) -> void:
	if button == null:
		return
	button.pivot_offset = button.size * 0.5
	# Komik squash: hafif şiş-sön
	var tween := create_tween().set_loops()
	tween.tween_property(button, "scale", Vector2(1.07, 0.94), 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(button, "scale", Vector2(0.97, 1.06), 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _setup_wavy_menu_titles() -> void:
	var title := _swap_wavy(_start_screen.get_node_or_null("Center/TitleLabel"), 58, 4.2, true, false)
	if title != null:
		title.text = "MESSY JANITOR"
		title.font_color = Color(0.95, 0.88, 0.55)
	var sub := _swap_wavy(_start_screen.get_node_or_null("Center/SubtitleLabel"), 22, 1.6, true, false)
	if sub != null:
		sub.text = "Remzi temizliyor · sen kaos çıkarıyorsun"
		sub.font_color = Color(0.75, 0.85, 0.95)
	_swap_wavy(_level_screen.get_node_or_null("Center/TitleLabel"), 44, 2.4, true, false)
	_over_title = _swap_wavy(_over_screen.get_node_or_null("Center/TitleLabel"), 72, 3.5, true, true)
	_swap_wavy(_pause_screen.get_node_or_null("Center/TitleLabel"), 48, 2.2, true, false)


func _swap_wavy(label: Label, font_size: int, amplitude: float, shimmer: bool, rainbow: bool) -> WavyLabel:
	if label == null:
		return null
	var parent := label.get_parent()
	var idx := label.get_index()
	var w := WavyLabel.new()
	w.name = label.name
	w.text = label.text
	w.font_size = font_size
	w.font_color = label.get_theme_color("font_color") if label.has_theme_color_override("font_color") else Color(0.9, 0.88, 0.95)
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	w.wave_amplitude = amplitude
	w.enable_shimmer = shimmer
	w.enable_rainbow = rainbow
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.layout_mode = label.layout_mode
	w.anchor_left = label.anchor_left
	w.anchor_top = label.anchor_top
	w.anchor_right = label.anchor_right
	w.anchor_bottom = label.anchor_bottom
	w.offset_left = label.offset_left
	w.offset_top = label.offset_top
	w.offset_right = label.offset_right
	w.offset_bottom = label.offset_bottom
	w.grow_horizontal = Control.GROW_DIRECTION_BOTH if label.anchor_right - label.anchor_left >= 0.99 else label.grow_horizontal
	w.grow_vertical = label.grow_vertical
	parent.add_child(w)
	parent.move_child(w, idx)
	label.queue_free()
	return w
