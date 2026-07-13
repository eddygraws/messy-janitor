class_name EquipmentBar
extends Control

@export var equipment_path: NodePath = ^"../../EquipmentComponent"

var _equipment: EquipmentComponent
var _hbox: HBoxContainer
var _slots: Array[PanelContainer] = []
var _icons: Array[TextureRect] = []
var _labels: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipment = get_node_or_null(equipment_path) as EquipmentComponent
	_build()
	if _equipment != null:
		_equipment.equipment_changed.connect(_on_equipment_changed)
		_equipment.unlocked_changed.connect(_on_unlocked_changed)
		_refresh()


func _build() -> void:
	_hbox = HBoxContainer.new()
	_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_hbox.add_theme_constant_override("separation", 12)
	_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hbox)

	for i in EquipmentComponent.Type.size():
		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(128, 72)
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 4)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.add_child(vb)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = GameAssets.get_equipment_icon(i)
		icon.scale = Vector2.ONE * GameAssets.EQUIPMENT_ICON_SCALE
		icon.pivot_offset = Vector2(16, 16)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(icon)

		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(120, 24)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.text = "%d  %s" % [i + 1, EquipmentComponent.LABELS[i]]
		vb.add_child(lbl)

		_hbox.add_child(pc)
		_slots.append(pc)
		_icons.append(icon)
		_labels.append(lbl)


func _on_equipment_changed(_type: int) -> void:
	_refresh()


func _on_unlocked_changed(_count: int) -> void:
	_refresh()


func _refresh() -> void:
	if _equipment == null:
		return
	for i in _slots.size():
		var slot := _slots[i]
		var unlocked := _equipment.is_unlocked(i)
		var active := _equipment.get_current() == i
		_icons[i].texture = GameAssets.get_equipment_icon(i)
		if not unlocked:
			slot.modulate = Color(1, 1, 1, 0.18)
			_labels[i].add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			slot.scale = Vector2.ONE
		elif active:
			slot.modulate = Color(1, 1, 1, 1)
			_labels[i].add_theme_color_override("font_color", EquipmentComponent.COLORS[i])
			slot.pivot_offset = slot.size * 0.5
			var tween := create_tween()
			tween.tween_property(slot, "scale", Vector2(1.12, 1.12), 0.14)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			slot.modulate = Color(1, 1, 1, 0.65)
			_labels[i].add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
			slot.scale = Vector2.ONE
