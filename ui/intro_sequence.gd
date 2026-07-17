class_name IntroSequence
extends Control

## Görsel novel tarzı karakter girişi. Tıkla / boşluk ile ilerler.

signal finished

const CHAR_NAME := "Remzi"
const PANELS: Array[Dictionary] = [
	{
		"title": "Temizlikçi",
		"emoji": "🧹",
		"mood": Color(0.55, 0.72, 0.95),
		"text": "Ben %s. Görevim basit: insanların gözden kaçırdığı, canavarların yuvalandığı, tozun büyüye dönüştüğü yerleri temizlemek." % CHAR_NAME,
	},
	{
		"title": "Kimse istemiyor",
		"emoji": "🏠",
		"mood": Color(0.45, 0.55, 0.7),
		"text": "Kimse bu işi yapmak istemiyor. Ama biri gargoyle'ların tükürdüğü küfü, hayaletlerin bıraktığı toz izini temizlemeli. O ben oluyorum.",
	},
	{
		"title": "Zaaf",
		"emoji": "🍟",
		"mood": Color(0.85, 0.55, 0.35),
		"text": "Zayıf noktam mı? Junk food. Stresli anda bir paket cips her şeyi çözer... geçici olarak. Sonrası hep daha kötü oluyor.",
	},
	{
		"title": "Küçük bir sır",
		"emoji": "😰",
		"mood": Color(0.7, 0.4, 0.75),
		"text": "Küçük bir sır: bu işte çok fazla hata yaparsam... şişerim. Gerçekten şişerim. Kimse bunun tam olarak neden olduğunu bilmiyor — belki eski bir lanet, belki fazla abur cuburun bedeli. Ama bir şey kesin: stresim çok artarsa, iş kötüye gidiyor.",
	},
	{
		"title": "Başlayalım",
		"emoji": "📞",
		"mood": Color(0.6, 0.75, 0.5),
		"text": "Neyse, dırdır etmeyi bırakayım. Kuzenim bugün beni aradı, garajı berbat halde. Başlayalım.",
	},
]

var _panel_idx: int = 0
var _busy: bool = false
var _awaiting_input: bool = false
var _playing: bool = false

var _mood: ColorRect
var _emoji: Label
var _title: Label
var _body: Label
var _counter: Label
var _name_tag: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_as_relative = false
	z_index = 200
	_apply_full_rect()
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_RESIZED \
			or what == NOTIFICATION_VISIBILITY_CHANGED:
		_apply_full_rect()


func _apply_full_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var vp := get_viewport()
	if vp != null:
		var r := vp.get_visible_rect().size
		custom_minimum_size = r
		size = r
		position = Vector2.ZERO


func _build() -> void:
	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0.05, 0.04, 0.08, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(920, 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	_counter = Label.new()
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.add_theme_font_size_override("font_size", 18)
	_counter.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62))
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_counter)

	_mood = ColorRect.new()
	_mood.custom_minimum_size = Vector2(520, 280)
	_mood.color = Color(0.2, 0.25, 0.4, 0.55)
	_mood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_mood)

	_emoji = Label.new()
	_emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_emoji.add_theme_font_size_override("font_size", 140)
	_emoji.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mood.add_child(_emoji)

	_name_tag = Label.new()
	_name_tag.text = CHAR_NAME
	_name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_tag.add_theme_font_size_override("font_size", 28)
	_name_tag.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	_name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_name_tag)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(920, 180)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.14, 0.96)
	style.border_color = Color(0.55, 0.45, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(28)
	box.add_theme_stylebox_override("panel", style)
	col.add_child(box)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.add_theme_font_size_override("font_size", 26)
	_body.add_theme_color_override("font_color", Color(0.92, 0.9, 0.95))
	_body.custom_minimum_size = Vector2(860, 120)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_body)

	var hint := Label.new()
	hint.text = "▸ Devam etmek için tıkla / Space  ·  Esc ile atla"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.65, 0.62, 0.7))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hint)


func play() -> void:
	_playing = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color.WHITE
	_apply_full_rect()
	_panel_idx = 0
	visible = true
	move_to_front()

	# Layout otursun (CanvasLayer altında ilk karede size 0 olabiliyor)
	for _i in 3:
		await get_tree().process_frame
		_apply_full_rect()

	modulate.a = 0.0
	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(self, "modulate:a", 1.0, 0.35)
	await fade.finished

	for i in PANELS.size():
		if not _playing or not is_inside_tree():
			_finish()
			return
		_panel_idx = i
		await _show_panel(i)
		if not _playing:
			_finish()
			return
		await _wait_advance()
		if not _playing:
			_finish()
			return

	var out := create_tween()
	out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	out.tween_property(self, "modulate:a", 0.0, 0.3)
	await out.finished
	_finish()


func _finish() -> void:
	_playing = false
	_awaiting_input = false
	_busy = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	finished.emit()


func _show_panel(idx: int) -> void:
	_busy = true
	_awaiting_input = false
	_apply_full_rect()
	var p: Dictionary = PANELS[idx]
	_emoji.text = String(p["emoji"])
	_title.text = String(p["title"])
	_body.text = "\"%s\"" % String(p["text"])
	_counter.text = "%d / %d" % [idx + 1, PANELS.size()]
	_mood.color = Color(p["mood"].r, p["mood"].g, p["mood"].b, 0.55)

	modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.28)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	_busy = false
	_awaiting_input = true


func _wait_advance() -> void:
	while _awaiting_input and _playing and visible:
		await get_tree().process_frame


func _advance() -> void:
	if not _playing or _busy or not _awaiting_input:
		return
	_awaiting_input = false


func _skip_all() -> void:
	_awaiting_input = false
	_busy = false
	_playing = false
	visible = false


func _gui_input(event: InputEvent) -> void:
	if not _playing or not visible:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		_advance()


func _input(event: InputEvent) -> void:
	if not _playing or not visible:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_skip_all()
		elif key == KEY_SPACE or key == KEY_ENTER:
			get_viewport().set_input_as_handled()
			_advance()
