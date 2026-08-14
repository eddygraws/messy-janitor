class_name ScrapRevealUI
extends Control

## Eldeki item büyüyüp dönerken ekranda uçar; ışınlanmadan UI yuvasına oturur.

signal closed
signal seated ## Item pencereye oturdu; el görseli kaldırılabilir
signal flight_started ## Uçuş kopyası ekranda — el gizlenebilir

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _name_label: Label
var _hint_label: Label
var _progress: Label
var _btn: Button
var _viewport: SubViewport
var _vp_host: SubViewportContainer
var _seat: Control
var _spin_root: Node3D
var _icon_3d: Label3D
var _box_mesh: MeshInstance3D
var _tween: Tween
var _spinning: bool = false
var _awaiting_close: bool = false
var _idle_spin: bool = false
var _flight_spin: bool = false
var _sfx: AudioStreamPlayer
var _content: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_as_relative = false
	z_index = 120
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"Master"
	_sfx.volume_db = -4.0
	add_child(_sfx)

	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.03, 0.05, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -260.0
	_panel.offset_right = 260.0
	_panel.offset_top = -250.0
	_panel.offset_bottom = 250.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, 0.97)
	style.set_corner_radius_all(18)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	style.border_color = Color(0.55, 0.72, 0.95, 0.65)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(_content)

	_title = Label.new()
	_title.text = "KAYIP EŞYA BULUNDU!"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	_content.add_child(_title)

	_seat = Control.new()
	_seat.name = "ItemSeat"
	_seat.custom_minimum_size = Vector2(280, 200)
	_seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_seat)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 32)
	_name_label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	_content.add_child(_name_label)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.88))
	_content.add_child(_hint_label)

	_progress = Label.new()
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress.add_theme_font_size_override("font_size", 28)
	_progress.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	_progress.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_progress.add_theme_constant_override("outline_size", 6)
	_content.add_child(_progress)

	_btn = Button.new()
	_btn.text = "Devam  ·  Space"
	_btn.custom_minimum_size = Vector2(200, 44)
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.pressed.connect(_on_close)
	var center := CenterContainer.new()
	center.add_child(_btn)
	_content.add_child(center)

	# Uçan item — panel dışında serbest Control; oturunca seat'e girer
	_vp_host = SubViewportContainer.new()
	_vp_host.name = "FlyHost"
	_vp_host.stretch = true
	_vp_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp_host.custom_minimum_size = Vector2(96, 96)
	_vp_host.size = Vector2(96, 96)
	add_child(_vp_host)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(280, 200)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp_host.add_child(_viewport)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.35, 2.4)
	cam.current = true
	_viewport.add_child(cam)

	var light := OmniLight3D.new()
	light.light_energy = 1.4
	light.position = Vector3(0.6, 1.2, 1.4)
	_viewport.add_child(light)

	_spin_root = Node3D.new()
	_spin_root.name = "SpinRoot"
	_viewport.add_child(_spin_root)

	_box_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.36, 0.65)
	_box_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.52, 0.6)
	mat.roughness = 0.7
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.55, 0.75)
	mat.emission_energy_multiplier = 0.45
	_box_mesh.material_override = mat
	_spin_root.add_child(_box_mesh)

	var tape := MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3(0.58, 0.08, 0.14)
	tape.mesh = strip
	tape.position = Vector3(0, 0.05, 0)
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.78, 0.58, 0.28)
	tape.material_override = tmat
	_spin_root.add_child(tape)

	_icon_3d = Label3D.new()
	_icon_3d.font_size = 96
	_icon_3d.pixel_size = 0.012
	_icon_3d.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_icon_3d.position = Vector3(0, 0.55, 0)
	_icon_3d.modulate = Color(1, 1, 1, 0.95)
	_spin_root.add_child(_icon_3d)


## El ekran konumundan pencere yuvasına kesintisiz uçuş.
func present_seamless(
	scrap_id: String,
	found: int,
	total: int,
	is_new: bool,
	from_screen: Vector2,
	start_yaw: float = 0.0
) -> void:
	var info := ScrapCatalog.by_id(scrap_id)
	_icon_3d.text = String(info.get("icon", "📦"))
	_name_label.text = String(info.get("name", scrap_id))
	var hint := String(info.get("hint", ""))
	_hint_label.text = hint if not hint.is_empty() else "Kayıp & bulunanlar koleksiyonuna eklendi."
	_progress.text = "%d / %d" % [found, total]
	_title.text = "YENİ KAYIT!" if is_new else "TEKRAR BULUNDU"
	_awaiting_close = false
	_idle_spin = false
	_flight_spin = true
	_spinning = true
	visible = true
	move_to_front()
	modulate = Color.WHITE

	# Panel sabit ortada — yumuşak fade; item ayrı uçar
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -260.0
	_panel.offset_right = 260.0
	_panel.offset_top = -250.0
	_panel.offset_bottom = 250.0
	_panel.modulate = Color(1, 1, 1, 0.0)
	_dim.color.a = 0.0
	_title.modulate.a = 0.0
	_name_label.modulate.a = 0.0
	_hint_label.modulate.a = 0.0
	_progress.modulate.a = 0.0
	_btn.modulate.a = 0.0

	# Fly host: elden bağımsız root çocuğu
	if _vp_host.get_parent() != self:
		_vp_host.reparent(self)
	_vp_host.visible = true
	_vp_host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var start_size := Vector2(110, 110)
	_vp_host.size = start_size
	_vp_host.custom_minimum_size = start_size
	_vp_host.position = from_screen - start_size * 0.5
	_vp_host.scale = Vector2.ONE
	_vp_host.modulate = Color.WHITE
	_vp_host.pivot_offset = start_size * 0.5

	_spin_root.rotation = Vector3(0.15, start_yaw, 0.08)
	_spin_root.scale = Vector3(0.85, 0.85, 0.85)

	await get_tree().process_frame
	await get_tree().process_frame
	flight_started.emit()

	# Hedef: seat global rect
	var end_size := Vector2(280, 200)
	var end_pos := size * 0.5 - end_size * 0.5 + Vector2(0, -40)
	if _seat != null:
		var seat_r := _seat.get_global_rect()
		if seat_r.size.x > 20.0:
			end_pos = seat_r.position
			end_size = seat_r.size

	PrototypeSfx.play(_sfx, PrototypeSfx.Kind.PHASE, 1.05)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)

	# Dim + panel soft
	_tween.tween_property(_dim, "color:a", 0.72, 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(0.12)

	# Item: pozisyon + boyut + büyüme + dönüş — ışın yok
	_tween.tween_property(_vp_host, "position", end_pos, 0.95)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_vp_host, "size", end_size, 0.95)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_vp_host, "custom_minimum_size", end_size, 0.95)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_spin_root, "scale", Vector3(1.35, 1.35, 1.35), 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_spin_root, "rotation:y", start_yaw + TAU * 1.35, 0.95)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_spin_root, "rotation:x", 0.35, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_spin_root, "rotation:x", 0.08, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.45)

	_tween.set_parallel(false)
	_tween.tween_callback(_seat_item)
	_tween.set_parallel(true)
	_tween.tween_property(_spin_root, "scale", Vector3.ONE, 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_title, "modulate:a", 1.0, 0.28)
	_tween.tween_property(_name_label, "modulate:a", 1.0, 0.28)
	_tween.tween_property(_hint_label, "modulate:a", 1.0, 0.32).set_delay(0.05)
	_tween.tween_property(_progress, "modulate:a", 1.0, 0.32).set_delay(0.08)
	_tween.tween_property(_btn, "modulate:a", 1.0, 0.28).set_delay(0.12)
	_tween.set_parallel(false)
	_tween.tween_callback(func() -> void:
		_awaiting_close = true
		_idle_spin = true
		_flight_spin = false
		PrototypeSfx.play(_sfx, PrototypeSfx.Kind.TASK_OK, 1.05)
	)


func _seat_item() -> void:
	_flight_spin = false
	if _seat == null or _vp_host == null:
		seated.emit()
		return
	var end_yaw := _spin_root.rotation.y
	_vp_host.reparent(_seat)
	_vp_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vp_host.offset_left = 0.0
	_vp_host.offset_top = 0.0
	_vp_host.offset_right = 0.0
	_vp_host.offset_bottom = 0.0
	_vp_host.custom_minimum_size = Vector2(280, 200)
	_vp_host.size = _seat.size if _seat.size.x > 10.0 else Vector2(280, 200)
	_spin_root.rotation.y = end_yaw
	_spin_root.rotation.x = 0.08
	_spin_root.rotation.z = 0.0
	seated.emit()


func present(scrap_id: String, found: int, total: int, is_new: bool = true) -> void:
	present_seamless(scrap_id, found, total, is_new, size * 0.5, 0.0)


func _process(delta: float) -> void:
	if not visible or not _spinning or _spin_root == null:
		return
	if _idle_spin and _awaiting_close:
		_spin_root.rotation.y += delta * 0.85
	elif _flight_spin:
		# Tween yaw üzerine hafif ekstra canlılık
		_spin_root.rotation.z = sin(Time.get_ticks_msec() * 0.006) * 0.06


func _on_close() -> void:
	if not visible:
		return
	if not _awaiting_close:
		return
	_spinning = false
	_idle_spin = false
	_flight_spin = false
	visible = false
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	if not visible or not _awaiting_close:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		_on_close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _awaiting_close:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_on_close()
