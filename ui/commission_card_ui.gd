class_name CommissionCardUI
extends Control

# Oda başında gösterilen "Görev Kartı": NPC + absürt istek + twist kural.
# Tıklayınca (veya kısa süre sonra) kapanır. show() beklenebilir (await).

signal dismissed

@export var auto_dismiss_time: float = 7.0

var _panel: PanelContainer
var _icon: Label
var _npc: Label
var _title: Label
var _desc: Label
var _rule: Label
var _hint: Label
var _awaiting: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.07, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -380.0
	_panel.offset_top = -230.0
	_panel.offset_right = 380.0
	_panel.offset_bottom = 230.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 0.98)
	style.border_color = Color(0.7, 0.55, 0.35)
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(28)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vb)

	var header := Label.new()
	header.text = "📜 KOMİSYON"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	vb.add_child(header)

	_icon = Label.new()
	_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon.add_theme_font_size_override("font_size", 84)
	vb.add_child(_icon)

	_npc = Label.new()
	_npc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_npc.add_theme_font_size_override("font_size", 24)
	_npc.add_theme_color_override("font_color", Color(0.85, 0.82, 0.95))
	vb.add_child(_npc)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	vb.add_child(_title)

	_desc = Label.new()
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(660, 0)
	_desc.add_theme_font_size_override("font_size", 22)
	_desc.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	vb.add_child(_desc)

	_rule = Label.new()
	_rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rule.add_theme_font_size_override("font_size", 24)
	_rule.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	vb.add_child(_rule)

	_hint = Label.new()
	_hint.text = "▸ Devam etmek için tıkla"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vb.add_child(_hint)


func show_card(commission: Dictionary) -> void:
	_icon.text = String(commission.get("icon", "📜"))
	_npc.text = String(commission.get("npc", ""))
	_title.text = String(commission.get("title", ""))
	_desc.text = "\"%s\"" % String(commission.get("desc", ""))
	var rule_text := CommissionData.rule_label(int(commission.get("rule", 0)))
	_rule.text = rule_text
	_rule.visible = rule_text != ""

	visible = true
	modulate.a = 0.0
	_panel.pivot_offset = Vector2(380, 230)
	_panel.scale = Vector2(0.7, 0.7)
	var tin := create_tween().set_parallel(true)
	tin.tween_property(self, "modulate:a", 1.0, 0.2)
	tin.tween_property(_panel, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_awaiting = true
	var timer := get_tree().create_timer(auto_dismiss_time)
	timer.timeout.connect(_dismiss)
	await dismissed

	var tout := create_tween()
	tout.tween_property(self, "modulate:a", 0.0, 0.2)
	await tout.finished
	visible = false


func _input(event: InputEvent) -> void:
	if not _awaiting:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		get_viewport().set_input_as_handled()
		_dismiss()


func _dismiss() -> void:
	if not _awaiting:
		return
	_awaiting = false
	dismissed.emit()
