class_name GameScreens
extends CanvasLayer

signal mode_selected(mode: int)
signal level_selected(index: int)
signal back_pressed
signal restart_pressed

@onready var _start_screen: Control = $StartScreen
@onready var _over_screen: Control = $GameOverScreen
@onready var _level_screen: Control = $LevelSelectScreen
@onready var _level_grid: GridContainer = $LevelSelectScreen/Center/Grid
@onready var _level_back: Button = $LevelSelectScreen/Center/BackButton
@onready var _adventure_button: Button = $StartScreen/Center/AdventureButton
@onready var _endless_button: Button = $StartScreen/Center/EndlessButton
@onready var _restart_button: Button = $GameOverScreen/Center/RestartButton
@onready var _over_info: Label = $GameOverScreen/Center/InfoLabel
@onready var _over_title: Label = $GameOverScreen/Center/TitleLabel
@onready var _records_label: Label = $StartScreen/Center/RecordsLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_adventure_button.pressed.connect(func() -> void: mode_selected.emit(0))
	_endless_button.pressed.connect(func() -> void: mode_selected.emit(1))
	_restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	_level_back.pressed.connect(func() -> void: back_pressed.emit())
	_over_screen.visible = false
	_level_screen.visible = false
	show_start()


func set_records_text(text: String) -> void:
	if _records_label != null:
		_records_label.text = text


func show_start() -> void:
	_level_screen.visible = false
	_over_screen.visible = false
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
