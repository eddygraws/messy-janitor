class_name ActiveCardsStrip
extends Control

@export var room_manager_path: NodePath = ^"../../RoomManager"

var _label: Label
var _room_manager: Node


func _ready() -> void:
	_room_manager = get_node_or_null(room_manager_path)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -420.0
	offset_top = -148.0
	offset_right = -16.0
	offset_bottom = -108.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.88, 0.9))
	add_child(_label)
	visible = false


func set_cards(cards: Array[CardData]) -> void:
	if _room_manager != null and _room_manager.has_method("get_mode"):
		if int(_room_manager.get_mode()) != 1:  # ENDLESS
			visible = false
			return
	if cards.is_empty():
		visible = false
		return
	var parts: PackedStringArray = []
	for card in cards:
		parts.append("%s %s" % [card.icon, card.title])
	_label.text = "Kartlar: " + " · ".join(parts)
	visible = true
