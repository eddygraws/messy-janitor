class_name CreditsScreen3D
extends Control

signal closed

const Product := preload("res://systems/product_identity.gd")

var _title: Label
var _body: RichTextLabel
var _back: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 230
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	GameSettings.locale_changed.connect(func(_c: String) -> void: _refresh())


func present() -> void:
	_refresh()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	move_to_front()


func dismiss() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.13, 0.97)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.95, 0.88, 0.55, 0.45)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	col.add_child(_title)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = true
	_body.custom_minimum_size = Vector2(0, 360)
	_body.add_theme_color_override("default_color", Color(0.86, 0.88, 0.84))
	_body.mouse_filter = Control.MOUSE_FILTER_STOP
	col.add_child(_body)

	_back = Button.new()
	_back.focus_mode = Control.FOCUS_NONE
	_back.custom_minimum_size = Vector2(200, 44)
	_back.pressed.connect(dismiss)
	var wrap := HBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(_back)
	col.add_child(wrap)


func _refresh() -> void:
	_title.text = GameSettings.t("credits")
	_back.text = GameSettings.t("back")
	var tracks := ", ".join(Product.MUSIC_TRACKS)
	if GameSettings.locale == "en":
		_body.text = "\n".join([
			"[center][b]%s[/b]  v%s[/center]" % [Product.APP_NAME, Product.VERSION],
			"",
			Product.SHORT_EN,
			"",
			"[b]Engine[/b]",
			Product.ENGINE_CREDIT,
			"",
			"[b]Character animation[/b]",
			Product.MIXAMO_CREDIT,
			"",
			"[b]Music[/b]",
			tracks,
			"Original beds — unlicensed tracks are not played",
			"",
			"[b]Sound[/b]",
			"Original SFX bank (res://audio/sfx) — drop-in WAV/OGG welcome",
			"",
			"© %s %s" % [Product.COPYRIGHT_YEAR, Product.APP_NAME],
		])
	else:
		_body.text = "\n".join([
			"[center][b]%s[/b]  v%s[/center]" % [Product.APP_NAME, Product.VERSION],
			"",
			Product.SHORT_TR,
			"",
			"[b]Motor[/b]",
			Product.ENGINE_CREDIT,
			"",
			"[b]Karakter animasyonu[/b]",
			Product.MIXAMO_CREDIT,
			"",
			"[b]Müzik[/b]",
			tracks,
			"Orijinal bed — lisanssız parçalar çalınmıyor",
			"",
			"[b]Ses[/b]",
			"Orijinal SFX bankası (res://audio/sfx) — WAV/OGG üzerine yazılabilir",
			"",
			"© %s %s" % [Product.COPYRIGHT_YEAR, Product.APP_NAME],
		])


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			dismiss()
