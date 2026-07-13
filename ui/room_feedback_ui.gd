class_name RoomFeedbackUI
extends Control

@onready var _panel: Control = $Panel
@onready var _grade_label: Label = $Panel/GradeLabel
@onready var _score_label: Label = $Panel/ScoreLabel
@onready var _subtitle_label: Label = $Panel/SubtitleLabel
@onready var _flash: ColorRect = $Flash


func _ready() -> void:
	visible = false
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.3, 0.3)
	_flash.modulate.a = 0.0


func show_rating(result: Dictionary, is_level_complete: bool = false) -> void:
	visible = true
	_grade_label.text = "LEVEL CLEAR!" if is_level_complete else result.grade
	_grade_label.modulate = result.grade_color if not is_level_complete else Color(1.0, 0.85, 0.3)
	_score_label.text = "%d PTS" % result.score
	_subtitle_label.text = result.subtitle

	_panel.scale = Vector2(0.2, 0.2)
	_panel.modulate.a = 0.0
	_panel.rotation_degrees = -8.0

	var enter := create_tween().set_parallel(true)
	enter.tween_property(_panel, "scale", Vector2(1.15, 1.15), 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter.tween_property(_panel, "modulate:a", 1.0, 0.12)
	enter.tween_property(_panel, "rotation_degrees", 0.0, 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await enter.finished

	var pulse := create_tween()
	pulse.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await pulse.finished

	await get_tree().create_timer(1.1).timeout
	await _hide_panel()


func show_level_summary(total_score: int, average_score: int, rooms_cleared: int) -> void:
	var grade_data := RoomRating.get_grade_data(average_score)
	var result := {
		"score": total_score,
		"grade": grade_data.label,
		"grade_color": grade_data.color,
		"subtitle": "%d rooms · avg %d pts" % [rooms_cleared, average_score],
	}
	await show_rating(result, true)


func flash_transition() -> void:
	_flash.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_flash, "modulate:a", 0.75, 0.1)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.35)
	await tween.finished


func _hide_panel() -> void:
	var exit := create_tween().set_parallel(true)
	exit.tween_property(_panel, "scale", Vector2(1.6, 1.6), 0.18)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	exit.tween_property(_panel, "modulate:a", 0.0, 0.15)
	exit.tween_property(_panel, "rotation_degrees", 6.0, 0.18)
	await exit.finished
	visible = false
