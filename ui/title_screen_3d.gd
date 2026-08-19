class_name TitleScreen3D
extends Control

## Açılış ekranı — herhangi bir tuş / tık → level seçimine.

signal continued

var _active: bool = false
var _closing: bool = false
var _prompt: Label
var _prompt_tween: Tween
var _sfx: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_as_relative = false
	z_index = 220
	_apply_full_rect()
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_RESIZED \
			or what == NOTIFICATION_VISIBILITY_CHANGED:
		_apply_full_rect()


func _apply_full_rect() -> void:
	## Tam ekran: sadece anchor; size set etme (karşıt anchor uyarısı)
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
	_sfx.bus = &"Master"
	_sfx.volume_db = -4.0
	add_child(_sfx)

	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0.05, 0.07, 0.09, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 0.0
	bg.offset_top = 0.0
	bg.offset_right = 0.0
	bg.offset_bottom = 0.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Hafif üst–alt gradient hissi
	var top_wash := ColorRect.new()
	top_wash.color = Color(0.18, 0.22, 0.16, 0.35)
	top_wash.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_wash.offset_left = 0.0
	top_wash.offset_right = 0.0
	top_wash.offset_top = 0.0
	top_wash.offset_bottom = 220.0
	top_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_wash)

	var bottom_wash := ColorRect.new()
	bottom_wash.color = Color(0.08, 0.1, 0.14, 0.55)
	bottom_wash.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_wash.offset_left = 0.0
	bottom_wash.offset_right = 0.0
	bottom_wash.offset_top = -180.0
	bottom_wash.offset_bottom = 0.0
	bottom_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_wash)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 0.0
	center.offset_top = 0.0
	center.offset_right = 0.0
	center.offset_bottom = 0.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	var broom := Label.new()
	broom.text = "🧹"
	broom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	broom.add_theme_font_size_override("font_size", 72)
	broom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(broom)

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
	col.add_child(brand)

	var tag := Label.new()
	tag.text = "3D · Temizlik kaosuna hoş geldin"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", Color(0.72, 0.82, 0.78))
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	tag.add_theme_constant_override("outline_size", 4)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tag)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 36)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)

	_prompt = Label.new()
	_prompt.text = "▶  Herhangi bir tuşa bas"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 26)
	_prompt.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_prompt)

	var hint := Label.new()
	hint.text = "klavye · fare · gamepad"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.58))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hint)


func present() -> void:
	_active = true
	_closing = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_full_rect()
	visible = true
	move_to_front()
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
	_prompt_tween.tween_property(_prompt, "modulate:a", 0.35, 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_prompt_tween.tween_property(_prompt, "modulate:a", 1.0, 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _continue() -> void:
	if not _active or _closing:
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


func _gui_input(event: InputEvent) -> void:
	if not _active or _closing:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		_continue()


func _input(event: InputEvent) -> void:
	if not _active or _closing:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		get_viewport().set_input_as_handled()
		_continue()
		return
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		get_viewport().set_input_as_handled()
		_continue()
		return
	if event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		if absf(m.axis_value) > 0.55:
			get_viewport().set_input_as_handled()
			_continue()
