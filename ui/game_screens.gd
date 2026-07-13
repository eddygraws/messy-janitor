class_name GameScreens
extends CanvasLayer

signal mode_selected(mode: int)
signal restart_pressed

@onready var _start_screen: Control = $StartScreen
@onready var _over_screen: Control = $GameOverScreen
@onready var _adventure_button: Button = $StartScreen/Center/AdventureButton
@onready var _endless_button: Button = $StartScreen/Center/EndlessButton
@onready var _restart_button: Button = $GameOverScreen/Center/RestartButton
@onready var _over_info: Label = $GameOverScreen/Center/InfoLabel
@onready var _over_title: Label = $GameOverScreen/Center/TitleLabel


func _ready() -> void:
	# Oyun duraklatıldığında (pause) bile menü çalışsın.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_adventure_button.pressed.connect(func() -> void: mode_selected.emit(0))
	_endless_button.pressed.connect(func() -> void: mode_selected.emit(1))
	_restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	_over_screen.visible = false
	show_start()


func show_start() -> void:
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


func show_game_over(title: String, info: String) -> void:
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
