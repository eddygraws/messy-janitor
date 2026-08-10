class_name RunResultUI
extends Control

## Run / seviye sonu — skor vs kendi rekoru + kutlama juice.

signal closed

var _panel: PanelContainer
var _title: Label
var _score_label: Label
var _grade_label: Label
var _grade_wave: WavyLabel
var _compare: Label
var _detail: Label
var _btn: Button
var _tween: Tween
var _sfx: AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 80
	visible = false

	_sfx = AudioStreamPlayer.new()
	_sfx.name = "ResultSfx"
	_sfx.bus = &"Master"
	_sfx.volume_db = -3.0
	add_child(_sfx)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.05, 0.07, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -280.0
	_panel.offset_right = 280.0
	_panel.offset_top = -230.0
	_panel.offset_bottom = 230.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.96)
	style.set_corner_radius_all(16)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(v)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	v.add_child(_title)

	# Görünür Label yedek; WavyLabel üzerine bind
	_grade_label = Label.new()
	_grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade_label.add_theme_font_size_override("font_size", 64)
	_grade_label.visible = false
	v.add_child(_grade_label)

	_grade_wave = WavyLabel.new()
	_grade_wave.custom_minimum_size = Vector2(200, 78)
	_grade_wave.font_size = 72
	_grade_wave.wave_amplitude = 5.0
	_grade_wave.wave_speed = 3.2
	_grade_wave.enable_shimmer = true
	_grade_wave.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade_wave.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(_grade_wave)

	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 36)
	_score_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	v.add_child(_score_label)

	_compare = Label.new()
	_compare.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compare.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_compare.add_theme_font_size_override("font_size", 20)
	v.add_child(_compare)

	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_size_override("font_size", 16)
	_detail.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
	v.add_child(_detail)

	_btn = Button.new()
	_btn.text = "Devam"
	_btn.custom_minimum_size = Vector2(200, 48)
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.pressed.connect(_on_close)
	var center := CenterContainer.new()
	center.add_child(_btn)
	v.add_child(center)


func present(result: Dictionary, compare: Dictionary, daily: bool = false) -> void:
	visible = true
	modulate = Color(1, 1, 1, 0)
	var score := int(result.get("score", 0))
	var grade := String(result.get("grade", "C"))
	var gcol: Color = result.get("grade_color", Color.WHITE)
	_title.text = "GÜNLÜK SONUÇ" if daily else "SEVİYE SONUÇ"
	_grade_label.text = grade
	_grade_label.add_theme_color_override("font_color", gcol)
	if _grade_wave != null:
		_grade_wave.text = grade
		_grade_wave.font_color = gcol
		_grade_wave.scale = Vector2(0.4, 0.4)
	var coins_earned := int(result.get("coins_earned", 0))
	var wallet_total := int(result.get("wallet_total", 0))
	if coins_earned > 0:
		_score_label.text = "Skor: %d   ·   +%d🪙" % [score, coins_earned]
	else:
		_score_label.text = "Skor: %d" % score

	var lines: PackedStringArray = []
	var prev_best := int(compare.get("prev_best", compare.get("best", 0)))
	var last := int(compare.get("last", 0))
	var is_new_best := bool(compare.get("is_new_best", false)) or bool(compare.get("beat_best", false))
	if is_new_best:
		if prev_best > 0:
			lines.append("🏆 YENİ REKOR!  (eski: %d  →  +%d)" % [prev_best, score - prev_best])
		else:
			lines.append("🏆 İlk rekor: %d" % score)
		_compare.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	elif bool(compare.get("beat_last", false)):
		lines.append("▲ Kendini geçtin!  Geçen: %d  →  +%d" % [last, score - last])
		_compare.add_theme_color_override("font_color", Color(0.45, 1.0, 0.6))
	elif last > 0:
		lines.append("▼ Geçen run: %d  (fark %d)" % [last, score - last])
		_compare.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	else:
		lines.append("İlk kayıt — rekor: %d" % score)
		_compare.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))

	if daily:
		var prev_db := int(compare.get("prev_daily_best", 0))
		var db := int(compare.get("daily_best", 0))
		if bool(compare.get("beat_daily_best", false)):
			if prev_db > 0:
				lines.append("📅 Günlük rekor kırıldı! (eski: %d)" % prev_db)
			else:
				lines.append("📅 Günlük ilk rekor: %d" % score)
		elif db > 0:
			lines.append("📅 Günlük en iyi: %d" % db)

	if coins_earned > 0 or wallet_total > 0:
		lines.append("🪙 +%d coin  →  cüzdan: %d" % [coins_earned, wallet_total])

	_compare.text = "\n".join(lines)
	_detail.text = "Combo x%d  ·  Temizlik %d  ·  Hata %d  ·  %.0fs" % [
		int(result.get("max_combo", 0)),
		int(result.get("disposed", 0)),
		int(result.get("mistakes", 0)),
		float(result.get("elapsed", 0.0)),
	]
	_btn.text = "Menü" if daily else "Devam"

	PrototypeSfx.play(_sfx, PrototypeSfx.Kind.TASK_OK, 1.15)
	if is_new_best:
		PrototypeSfx.play(_sfx, PrototypeSfx.Kind.PHASE, 1.2)

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	_panel.scale = Vector2(0.92, 0.92)
	_panel.pivot_offset = Vector2(280, 210)
	_tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _grade_wave != null:
		_tween.parallel().tween_property(_grade_wave, "scale", Vector2(1.15, 1.15), 0.28)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_grade_wave, "scale", Vector2.ONE, 0.18)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_on_close()
		get_viewport().set_input_as_handled()
