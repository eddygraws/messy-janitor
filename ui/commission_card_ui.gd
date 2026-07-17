class_name CommissionCardUI
extends Control

# Oda başında gösterilen "Görev Kartı": NPC + absürt istek + twist kural.
# Tıklayınca (veya süre dolunca) kapanır. show_card() await edilebilir.

signal dismissed

@export var auto_dismiss_time: float = 7.0
## Hikâye diyalogları için varsayılan süre (0 = sadece tıkla)
@export var story_dismiss_time: float = 0.0

var _panel: PanelContainer
var _header: Label
var _icon: Label
var _npc: Label
var _title: Label
var _desc: Label
var _rule: Label
var _hint: Label
var _awaiting: bool = false
var _timer: SceneTreeTimer = null
var _timer_gen: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_as_relative = false
	z_index = 50
	_build()
	visible = false


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.07, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
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

	_header = Label.new()
	_header.text = "📜 KOMİSYON"
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_theme_font_size_override("font_size", 22)
	_header.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	vb.add_child(_header)

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


## auto_secs: < 0 → varsayılan auto_dismiss_time; 0 → sadece tıkla; >0 → o süre
func show_card(commission: Dictionary, auto_secs: float = -1.0, story: bool = false) -> void:
	_cancel_timer()
	_icon.text = String(commission.get("icon", "📜"))
	_npc.text = String(commission.get("npc", ""))
	_title.text = String(commission.get("title", ""))
	_desc.text = "\"%s\"" % String(commission.get("desc", ""))
	var rule_text := CommissionData.rule_label(int(commission.get("rule", 0)))
	_rule.text = rule_text
	_rule.visible = rule_text != ""

	if story:
		_header.text = "📖 HİKÂYE"
		_hint.text = "▸ Okuduktan sonra tıkla"
	else:
		_header.text = "📜 KOMİSYON"
		_hint.text = "▸ Devam etmek için tıkla"

	var wait := auto_secs
	if wait < 0.0:
		wait = story_dismiss_time if story else auto_dismiss_time

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	_panel.pivot_offset = Vector2(380, 230)
	_panel.scale = Vector2(0.7, 0.7)
	var tin := create_tween().set_parallel(true)
	tin.tween_property(self, "modulate:a", 1.0, 0.25)
	tin.tween_property(_panel, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_awaiting = true
	if wait > 0.0:
		_timer_gen += 1
		var gen := _timer_gen
		# Pause altında da saysın (menüden dönüş / hikâye)
		_timer = get_tree().create_timer(wait, true, false, true)
		_timer.timeout.connect(func() -> void:
			if gen == _timer_gen:
				_dismiss()
		)
	await dismissed

	_cancel_timer()
	var tout := create_tween()
	tout.tween_property(self, "modulate:a", 0.0, 0.25)
	await tout.finished
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _cancel_timer() -> void:
	_timer_gen += 1
	_timer = null


func _on_dim_input(event: InputEvent) -> void:
	if not _awaiting:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		_dismiss()


func _unhandled_input(event: InputEvent) -> void:
	if not _awaiting or not visible:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_SPACE or key == KEY_ENTER:
			get_viewport().set_input_as_handled()
			_dismiss()


func _dismiss() -> void:
	if not _awaiting:
		return
	_awaiting = false
	_cancel_timer()
	dismissed.emit()
