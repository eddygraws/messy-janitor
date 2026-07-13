class_name DraftCardUI
extends Control

signal card_picked(card: CardData)

@export var pick_timeout: float = 45.0

var _offers: Array[CardData] = []
var _awaiting: bool = false
var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _card_row: HBoxContainer
var _hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.1, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -560.0
	_panel.offset_top = -250.0
	_panel.offset_right = 560.0
	_panel.offset_bottom = 250.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.15, 0.98)
	style.border_color = Color(0.55, 0.45, 0.75)
	style.set_border_width_all(3)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(24)
	style.shadow_size = 16
	style.shadow_color = Color(0, 0, 0, 0.45)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vb)

	_title = Label.new()
	_title.text = "🃏 GÜÇ KARTI SEÇ"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0))
	vb.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 20)
	_subtitle.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	vb.add_child(_subtitle)

	_card_row = HBoxContainer.new()
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_row.add_theme_constant_override("separation", 18)
	_card_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_card_row)

	_hint = Label.new()
	_hint.text = "Bir kart seç — run boyunca kalıcı"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 17)
	_hint.add_theme_color_override("font_color", Color(0.55, 0.58, 0.68))
	vb.add_child(_hint)


func present(offers: Array[CardData], room_combo: int) -> CardData:
	_offers = offers
	_subtitle.text = "Oda combo: x%d  ·  %d kart seçeneği" % [room_combo, offers.size()]
	_clear_row()
	for card in offers:
		_card_row.add_child(_make_card_button(card))

	visible = true
	modulate.a = 0.0
	_panel.scale = Vector2(0.88, 0.88)
	_panel.pivot_offset = Vector2(560, 250)
	var tin := create_tween().set_parallel(true)
	tin.tween_property(self, "modulate:a", 1.0, 0.22)
	tin.tween_property(_panel, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_awaiting = true
	var picked: CardData = await card_picked
	_awaiting = false

	var tout := create_tween()
	tout.tween_property(self, "modulate:a", 0.0, 0.18)
	await tout.finished
	visible = false
	_clear_row()
	return picked


func _make_card_button(card: CardData) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(320, 280)
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = "%s\n\n%s\n\n[%s]\n%s" % [
		card.icon, card.title, card.get_rarity_label(), card.description
	]
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", card.get_rarity_color())

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.13, 0.2, 1.0)
	normal.border_color = card.get_rarity_color().lerp(Color.WHITE, 0.25)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(14)
	normal.set_content_margin_all(16)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.2, 0.18, 0.28, 1.0)
	hover.border_color = card.get_rarity_color()
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	btn.pressed.connect(func() -> void:
		if not _awaiting:
			return
		_awaiting = false
		card_picked.emit(card)
	)
	return btn


func _clear_row() -> void:
	for child in _card_row.get_children():
		child.queue_free()


func _input(event: InputEvent) -> void:
	if not _awaiting or _offers.is_empty():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		var idx := -1
		match key.keycode:
			KEY_1, KEY_KP_1:
				idx = 0
			KEY_2, KEY_KP_2:
				idx = 1
			KEY_3, KEY_KP_3:
				idx = 2
		if idx >= 0 and idx < _offers.size():
			_awaiting = false
			card_picked.emit(_offers[idx])
			get_viewport().set_input_as_handled()
