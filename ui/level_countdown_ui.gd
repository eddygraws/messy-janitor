class_name LevelCountdownUI
extends Control

## Seviye başı 3 → 2 → 1 → BAŞLA

signal finished

var _label: Label
var _sfx: AudioStreamPlayer
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 90
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"Master"
	_sfx.volume_db = -2.0
	add_child(_sfx)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_font_size_override("font_size", 140)
	_label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.12, 0.85))
	_label.add_theme_constant_override("outline_size", 14)
	add_child(_label)


func play() -> void:
	if _busy:
		return
	_busy = true
	visible = true
	move_to_front()
	modulate = Color.WHITE
	for n in [3, 2, 1]:
		await _beat(str(n), Color(0.95, 0.96, 1.0), 1.0 + (3 - n) * 0.06)
	await _beat("BAŞLA!", Color(0.45, 1.0, 0.65), 1.18)
	visible = false
	_busy = false
	finished.emit()


func _beat(beat_text: String, color: Color, pitch: float) -> void:
	_label.text = beat_text
	_label.add_theme_color_override("font_color", color)
	var vp := get_viewport_rect().size
	_label.pivot_offset = vp * 0.5
	_label.scale = Vector2(0.45, 0.45)
	_label.modulate.a = 1.0
	PrototypeSfx.play(_sfx, PrototypeSfx.Kind.PHASE, pitch)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_label, "scale", Vector2(1.15, 1.15), 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_label, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.28)
	tw.tween_property(_label, "modulate:a", 0.0, 0.12)
	await tw.finished
	_label.modulate.a = 1.0
