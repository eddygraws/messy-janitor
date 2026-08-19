class_name WorldClearUI
extends Control

## Dünya / bölüm sonu — Moving Out tarzı koşu sahnesi + sertifika.

signal closed

const WorldClearSceneScript := preload("res://ui/world_clear_scene.gd")

var _root: Control
var _viewport_host: SubViewportContainer
var _viewport: SubViewport
var _scene: WorldClearScene
var _cert: PanelContainer
var _cert_inner: VBoxContainer
var _title: Label
var _subtitle: Label
var _stat_box: VBoxContainer
var _compare: Label
var _footer: Label
var _btn: Button
var _caption: Label
var _tween: Tween
var _sfx: AudioStreamPlayer
var _ready_close: bool = false
var _stat_rows: Array[Label] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 85
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"Master"
	_sfx.volume_db = -3.0
	add_child(_sfx)

	# Soft sky dim (sol sahne zaten mavi; hafif overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.08, 0.12, 0.18, 0.22)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_viewport()
	_build_certificate()
	_build_bottom()


func _build_viewport() -> void:
	_viewport_host = SubViewportContainer.new()
	_viewport_host.stretch = true
	_viewport_host.anchor_left = 0.0
	_viewport_host.anchor_right = 0.58
	_viewport_host.anchor_top = 0.0
	_viewport_host.anchor_bottom = 1.0
	_viewport_host.offset_right = 0.0
	_viewport_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_viewport_host)

	_viewport = SubViewport.new()
	_viewport.transparent_bg = false
	_viewport.handle_input_locally = false
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.size = Vector2i(960, 720)
	_viewport_host.add_child(_viewport)

	_scene = WorldClearSceneScript.new()
	_scene.name = "WorldClearScene"
	_viewport.add_child(_scene)
	_scene.set_process(false)


func _build_certificate() -> void:
	_cert = PanelContainer.new()
	_cert.anchor_left = 0.55
	_cert.anchor_right = 0.96
	_cert.anchor_top = 0.12
	_cert.anchor_bottom = 0.78
	_cert.rotation_degrees = 2.5
	_cert.pivot_offset = Vector2(200, 220)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.94, 0.9, 0.82, 0.98)
	style.set_corner_radius_all(6)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	style.border_color = Color(0.55, 0.42, 0.28, 0.75)
	style.set_border_width_all(3)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 12
	style.shadow_offset = Vector2(4, 6)
	_cert.add_theme_stylebox_override("panel", style)
	_root.add_child(_cert)

	_cert_inner = VBoxContainer.new()
	_cert_inner.add_theme_constant_override("separation", 10)
	_cert.add_child(_cert_inner)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(0.28, 0.2, 0.12))
	_cert_inner.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 15)
	_subtitle.add_theme_color_override("font_color", Color(0.45, 0.38, 0.28))
	_subtitle.text = "TEMİZLİK SERTİFİKASI"
	_cert_inner.add_child(_subtitle)

	var rule := HSeparator.new()
	_cert_inner.add_child(rule)

	_stat_box = VBoxContainer.new()
	_stat_box.add_theme_constant_override("separation", 8)
	_cert_inner.add_child(_stat_box)

	_compare = Label.new()
	_compare.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compare.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_compare.add_theme_font_size_override("font_size", 16)
	_cert_inner.add_child(_compare)

	_footer = Label.new()
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.add_theme_font_size_override("font_size", 13)
	_footer.add_theme_color_override("font_color", Color(0.42, 0.38, 0.32))
	_cert_inner.add_child(_footer)


func _build_bottom() -> void:
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.anchor_left = 0.05
	_caption.anchor_right = 0.55
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_top = -78.0
	_caption.offset_bottom = -42.0
	_caption.add_theme_font_size_override("font_size", 18)
	_caption.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_caption.add_theme_constant_override("outline_size", 6)
	_caption.text = "Bölüm bitti — tepeden koşmaya devam!"
	_root.add_child(_caption)

	_btn = Button.new()
	_btn.text = "Devam  ·  Space"
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.anchor_left = 1.0
	_btn.anchor_right = 1.0
	_btn.anchor_top = 1.0
	_btn.anchor_bottom = 1.0
	_btn.offset_left = -240.0
	_btn.offset_right = -36.0
	_btn.offset_top = -72.0
	_btn.offset_bottom = -28.0
	_btn.pressed.connect(_on_close)
	_root.add_child(_btn)


func _clear_stat_rows() -> void:
	for c in _stat_box.get_children():
		c.queue_free()
	_stat_rows.clear()


func _add_stat_row(label: String, value: String, accent: Color = Color(0.22, 0.18, 0.14)) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var left := Label.new()
	left.text = label
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_font_size_override("font_size", 18)
	left.add_theme_color_override("font_color", Color(0.4, 0.34, 0.26))
	row.add_child(left)
	var right := Label.new()
	right.text = value
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_theme_font_size_override("font_size", 26)
	right.add_theme_color_override("font_color", accent)
	row.add_child(right)
	_stat_box.add_child(row)
	_stat_rows.append(right)


## summary: score, coins, max_combo, disposed, boxes_carried, mop_scrubs, mistakes, elapsed, levels_cleared
## compare: world_best, prev_best, is_new_best
func present(world_slot: int, summary: Dictionary, compare: Dictionary) -> void:
	_ready_close = false
	visible = true
	move_to_front()
	modulate = Color(1, 1, 1, 0)

	if _viewport != null:
		# stretch=true iken SubViewport.size elle değiştirilmez — container boyutlandırır
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	if _scene != null:
		_scene.set_process(true)
		_scene.play_run()

	var icon := LevelData3D.world_icon(world_slot)
	var title := LevelData3D.world_title(world_slot)
	_title.text = "%s  %s\nTAMAMLANDI" % [icon, title.to_upper()]

	_clear_stat_rows()
	var score := int(summary.get("score", 0))
	var coins := int(summary.get("coins", 0))
	var boxes := int(summary.get("boxes_carried", 0))
	if boxes <= 0:
		boxes = int(summary.get("disposed", 0))
	var mop := int(summary.get("mop_scrubs", 0))
	var combo := int(summary.get("max_combo", 0))
	var elapsed := float(summary.get("elapsed", 0.0))
	var levels := int(summary.get("levels_cleared", 0))

	_add_stat_row("Puan", str(score), Color(0.55, 0.28, 0.12))
	_add_stat_row("Kazanılan coin", "+%d 🪙" % coins, Color(0.75, 0.55, 0.12))
	# Bölüm bölüm rozetler
	var badge_rows: Array = summary.get("badges", []) as Array
	if not badge_rows.is_empty():
		_add_stat_row("— Rozetler —", "", Color(0.45, 0.38, 0.3))
		for entry_v in badge_rows:
			var entry: Dictionary = entry_v as Dictionary
			var tier_n := int(entry.get("tier", 0)) + 1
			var nm := String(entry.get("name", "Seviye"))
			# Kısa isim: "Giriş" kısmını tut
			var short_n := nm
			var parts := nm.split(" · ")
			if parts.size() >= 3:
				short_n = "%d · %s" % [tier_n, parts[parts.size() - 1]]
			elif parts.size() == 2:
				short_n = parts[1]
			var bic := String(entry.get("icon", "🥉"))
			var blab := String(entry.get("label", "BRONZ"))
			var el := float(entry.get("elapsed", 0.0))
			_add_stat_row(
				short_n,
				"%s %s  (%.0fs)" % [bic, blab, el],
				BadgeRating3D.color(int(entry.get("badge", 1)))
			)
	else:
		var g := int(summary.get("gold", 0))
		var s := int(summary.get("silver", 0))
		var b := int(summary.get("bronze", 0))
		_add_stat_row("Rozetler", "🥇%d  🥈%d  🥉%d" % [g, s, b], Color(0.75, 0.55, 0.15))
	_add_stat_row("Taşınan koli", str(boxes), Color(0.35, 0.45, 0.55))
	_add_stat_row("Paspaslanan", str(mop), Color(0.25, 0.5, 0.65))
	_add_stat_row("Max combo", "x%d" % combo, Color(0.55, 0.35, 0.55))

	var g2 := int(summary.get("gold", 0))
	var s2 := int(summary.get("silver", 0))
	var b2 := int(summary.get("bronze", 0))
	var prev := int(compare.get("prev_best", 0))
	var best := int(compare.get("world_best", score))
	if bool(compare.get("is_new_best", false)):
		if prev > 0:
			_compare.text = "Dünya rekoru!  %d → %d" % [prev, score]
		else:
			_compare.text = "İlk dünya rekoru: %d" % score
		_compare.add_theme_color_override("font_color", Color(0.75, 0.45, 0.1))
	else:
		_compare.text = "Rekor: %d   ·   🥇%d 🥈%d 🥉%d" % [best, g2, s2, b2]
		_compare.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55))

	_footer.text = "%d seviye  ·  %.0fs  ·  hata %d" % [
		levels, elapsed, int(summary.get("mistakes", 0))
	]
	if g2 >= levels and levels > 0:
		_caption.text = "Tam altın tur! Bir sonraki dünyaya hazırsın."
	elif g2 + s2 >= levels and levels > 0:
		_caption.text = "Gümüş üstü tur — altın için biraz daha hızlı."
	else:
		_caption.text = "Becerilerin bir sonraki odaya yetiyor. Devam!"

	PrototypeSfx.play(_sfx, PrototypeSfx.Kind.TASK_OK, 1.1)
	if bool(compare.get("is_new_best", false)):
		PrototypeSfx.play(_sfx, PrototypeSfx.Kind.PHASE, 1.15)

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_cert.scale = Vector2(0.88, 0.88)
	_tween.tween_property(self, "modulate:a", 1.0, 0.28)
	_tween.parallel().tween_property(_cert, "scale", Vector2.ONE, 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void:
		_ready_close = true
	)


func _on_close() -> void:
	if not visible or not _ready_close:
		return
	visible = false
	_ready_close = false
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _scene != null:
		_scene.set_process(false)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _ready_close:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_on_close()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_on_close()
