class_name EquipmentBar
extends Control

@export var equipment_path: NodePath = ^"../../EquipmentComponent"

var _equipment: EquipmentComponent
var _hbox: HBoxContainer
var _slots: Array[PanelContainer] = []
var _icons: Array[TextureRect] = []
var _labels: Array[Label] = []
var _mop_bar: ProgressBar
var _mop_hint: Label
var _blink_tween: Tween
var _mop_ratio: float = 0.0
var _mop_overheated: bool = false


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
		pc.custom_minimum_size = Vector2(120, 92 if i == 0 else 78)
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 2)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.add_child(vb)

		# Paspas: küçük kir barı aletin üstünde
		if i == 0:
			_mop_hint = Label.new()
			_mop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_mop_hint.add_theme_font_size_override("font_size", 10)
			_mop_hint.add_theme_color_override("font_color", Color(1.0, 0.55, 0.25))
			_mop_hint.text = ""
			_mop_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(_mop_hint)
			_mop_bar = ProgressBar.new()
			_mop_bar.custom_minimum_size = Vector2(72, 8)
			_mop_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_mop_bar.show_percentage = false
			_mop_bar.max_value = 100.0
			_mop_bar.value = 0.0
			_mop_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(_mop_bar)
			_apply_mop_bar_style(Color(0.95, 0.7, 0.2))

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
		lbl.custom_minimum_size = Vector2(110, 18)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.text = "%d  %s" % [i + 1, EquipmentComponent.LABELS[i]]
		vb.add_child(lbl)

		_hbox.add_child(pc)
		_slots.append(pc)
		_icons.append(icon)
		_labels.append(lbl)


func set_mop_charge(ratio: float) -> void:
	_mop_ratio = clampf(ratio, 0.0, 1.0)
	if _mop_bar == null:
		return
	_mop_bar.value = _mop_ratio * 100.0
	var fill := Color(0.95, 0.75, 0.25).lerp(Color(1.0, 0.22, 0.12), _mop_ratio)
	_apply_mop_bar_style(fill)
	if _mop_overheated:
		_mop_hint.text = "⚠ KOVADA DURULA"
		_start_blink()
	elif _mop_ratio > 0.12:
		_mop_hint.text = "KİR %d%%" % int(_mop_ratio * 100.0)
		if _mop_ratio > 0.45:
			_start_blink()
		else:
			_stop_blink()
	else:
		_mop_hint.text = ""
		_stop_blink()
		_mop_bar.modulate = Color(1, 1, 1, 0.5)


func set_mop_overheated(on: bool) -> void:
	_mop_overheated = on
	if on:
		_mop_hint.text = "⚠ KOVADA DURULA"
		_apply_mop_bar_style(Color(1.0, 0.2, 0.12))
		_start_blink()
	else:
		set_mop_charge(_mop_ratio)


func set_mop_rinsed() -> void:
	_mop_overheated = false
	_mop_ratio = 0.0
	if _mop_bar != null:
		_mop_bar.value = 0.0
	if _mop_hint != null:
		_mop_hint.text = "TEMİZ"
		_mop_hint.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6))
	_stop_blink()
	if _mop_bar != null:
		_mop_bar.modulate = Color(1, 1, 1, 0.4)


func _apply_mop_bar_style(fill: Color) -> void:
	if _mop_bar == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(3)
	_mop_bar.add_theme_stylebox_override("fill", sb)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.1, 0.14, 0.9)
	bg.set_corner_radius_all(3)
	_mop_bar.add_theme_stylebox_override("background", bg)


func _start_blink() -> void:
	if _mop_bar == null:
		return
	if _blink_tween != null and _blink_tween.is_valid():
		return
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_mop_bar, "modulate", Color(1.6, 1.35, 0.7, 1.0), 0.18)\
		.set_trans(Tween.TRANS_SINE)
	_blink_tween.tween_property(_mop_bar, "modulate", Color(1.0, 0.25, 0.15, 1.0), 0.18)\
		.set_trans(Tween.TRANS_SINE)
	if _mop_hint != null:
		var ht := create_tween().set_loops()
		ht.tween_property(_mop_hint, "modulate:a", 1.0, 0.18)
		ht.tween_property(_mop_hint, "modulate:a", 0.2, 0.18)
		_mop_hint.set_meta("blink_tween", ht)
	# Paspas yuvası da hafif nabız atsın
	if not _slots.is_empty():
		var slot := _slots[0]
		var st := create_tween().set_loops()
		st.tween_property(slot, "modulate", Color(1.25, 0.95, 0.75, 1.0), 0.22)
		st.tween_property(slot, "modulate", Color(1.0, 0.7, 0.55, 1.0), 0.22)
		slot.set_meta("slot_blink", st)


func _stop_blink() -> void:
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = null
	if _mop_bar != null:
		_mop_bar.modulate = Color.WHITE
	if _mop_hint != null:
		var ht: Variant = _mop_hint.get_meta("blink_tween", null)
		if ht is Tween and (ht as Tween).is_valid():
			(ht as Tween).kill()
		_mop_hint.modulate.a = 1.0
		_mop_hint.add_theme_color_override("font_color", Color(1.0, 0.55, 0.25))
	if not _slots.is_empty():
		var slot := _slots[0]
		if slot.has_meta("slot_blink"):
			var st: Variant = slot.get_meta("slot_blink")
			if st is Tween and (st as Tween).is_valid():
				(st as Tween).kill()
			slot.remove_meta("slot_blink")
		if _equipment == null or _equipment.get_current() != 0:
			slot.modulate = Color(1, 1, 1, 0.65)
		else:
			slot.modulate = Color.WHITE


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
		slot.visible = unlocked
		if not unlocked:
			continue
		var active := _equipment.get_current() == i
		_icons[i].texture = GameAssets.get_equipment_icon(i)
		if active:
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
