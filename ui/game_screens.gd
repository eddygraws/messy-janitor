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

@onready var _start_screen: Control = $StartScreen
@onready var _over_screen: Control = $GameOverScreen
@onready var _level_screen: Control = $LevelSelectScreen
@onready var _level_grid: GridContainer = $LevelSelectScreen/Center/Grid
@onready var _level_back: Button = $LevelSelectScreen/Center/BackButton
@onready var _adventure_button: Button = $StartScreen/Center/AdventureButton
@onready var _endless_button: Button = $StartScreen/Center/EndlessButton
@onready var _restart_button: Button = $GameOverScreen/Center/RestartButton
@onready var _over_info: Label = $GameOverScreen/Center/InfoLabel
var _over_title: WavyLabel
@onready var _records_label: Label = $StartScreen/Center/RecordsLabel
@onready var _pause_screen: Control = $PauseScreen
@onready var _pause_resume: Button = $PauseScreen/Center/ResumeButton
@onready var _pause_menu: Button = $PauseScreen/Center/MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_adventure_button.pressed.connect(func() -> void: mode_selected.emit(0))
	_endless_button.pressed.connect(func() -> void: mode_selected.emit(1))
	_restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	_level_back.pressed.connect(func() -> void: back_pressed.emit())
	_pause_resume.pressed.connect(func() -> void: pause_resume_pressed.emit())
	_pause_menu.pressed.connect(func() -> void: pause_main_menu_pressed.emit())
	_over_screen.visible = false
	_level_screen.visible = false
	_pause_screen.visible = false
	show_start()
	call_deferred("_setup_wavy_menu_titles")


func set_records_text(text: String) -> void:
	if _records_label != null:
		_records_label.text = text


func show_start() -> void:
	_level_screen.visible = false
	_over_screen.visible = false
	_pause_screen.visible = false
	_start_screen.visible = true
	_start_screen.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_start_screen, "modulate:a", 1.0, 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pop_button(_adventure_button)


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
	if _over_screen.visible or _start_screen.visible or _level_screen.visible:
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
	_build_level_buttons(unlocked, best_scores)
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

	for i in 10:
		var level_num := i + 1
		var is_unlocked := level_num <= unlocked
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 96)
		btn.add_theme_font_size_override("font_size", 22)
		btn.disabled = not is_unlocked
		btn.focus_mode = Control.FOCUS_NONE

		var best := 0
		if i < best_scores.size():
			best = int(best_scores[i])

		if is_unlocked:
			var best_line := ("En iyi: %d" % best) if best > 0 else "Yeni!"
			btn.text = "Seviye %d\n%s" % [level_num, best_line]
			var idx := i
			btn.pressed.connect(func() -> void: level_selected.emit(idx))
		else:
			btn.text = "🔒\nSeviye %d" % level_num

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
	button.pivot_offset = button.size * 0.5
	var tween := create_tween().set_loops()
	tween.tween_property(button, "scale", Vector2(1.06, 1.06), 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _setup_wavy_menu_titles() -> void:
	_swap_wavy(_start_screen.get_node_or_null("Center/TitleLabel"), 58, 3.2, true, false)
	_swap_wavy(_start_screen.get_node_or_null("Center/SubtitleLabel"), 22, 1.2, true, false)
	_swap_wavy(_level_screen.get_node_or_null("Center/TitleLabel"), 44, 2.0, true, false)
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
