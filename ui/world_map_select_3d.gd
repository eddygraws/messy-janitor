class_name WorldMapSelect3D
extends Control

## New Super Mario Bros. tarzı dünya haritası:
## Dünya seç (Bölüm) → path üzerinde node'lar → karakter yürür → Enter ile gir.

signal level_chosen(level_index: int)
signal world_changed(world_slot: int)

const NODE_R := 28.0
const PATH_W := 10.0

var _highest_unlocked: int = 1
var _world_slot: int = 0
var _cursor: int = 0 ## world içindeki node index
var _levels: Array[int] = []
var _node_pos: Array[Vector2] = []

var _title: Label
var _world_label: Label
var _hint: Label
var _info: Label
var _play_btn: Button
var _prev_btn: Button
var _next_btn: Button
var _map: Control
var _pawn: Control
var _pawn_bob: float = 0.0
var _move_tween: Tween
var _sfx: AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"Master"
	_sfx.volume_db = -6.0
	add_child(_sfx)
	_build()
	resized.connect(_relayout_nodes)
	call_deferred("_relayout_nodes")


func setup(highest_unlocked: int, prefer_level: int = -1) -> void:
	_highest_unlocked = maxi(1, highest_unlocked)
	if prefer_level >= 0:
		_world_slot = LevelData3D.world_slot_for_level(prefer_level)
	else:
		_world_slot = _default_world_for_progress()
	_load_world(_world_slot, prefer_level)
	_refresh_labels()


func set_highest_unlocked(n: int) -> void:
	_highest_unlocked = maxi(1, n)
	_refresh_nodes()
	_refresh_labels()


func _default_world_for_progress() -> int:
	var last_unlocked := clampi(_highest_unlocked - 1, 0, LevelData3D.level_count() - 1)
	return LevelData3D.world_slot_for_level(last_unlocked)


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.28, 0.18, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# NSMB-ish checker / hills vibe — soft overlays
	var hill := ColorRect.new()
	hill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hill.anchor_top = 0.55
	hill.offset_top = 0.0
	hill.color = Color(0.18, 0.42, 0.22, 0.85)
	hill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hill)

	var sky := ColorRect.new()
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.anchor_bottom = 0.55
	sky.offset_bottom = 0.0
	sky.color = Color(0.45, 0.72, 0.95, 0.55)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	_title = Label.new()
	_title.text = "DÜNYA HARİTASI"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.anchor_right = 1.0
	_title.offset_top = 8.0
	_title.offset_bottom = 40.0
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	_title.add_theme_color_override("font_outline_color", Color(0.1, 0.15, 0.1, 0.9))
	_title.add_theme_constant_override("outline_size", 6)
	add_child(_title)

	_prev_btn = Button.new()
	_prev_btn.text = "◀"
	_prev_btn.focus_mode = Control.FOCUS_NONE
	_prev_btn.custom_minimum_size = Vector2(48, 40)
	_prev_btn.anchor_left = 0.0
	_prev_btn.anchor_top = 0.0
	_prev_btn.offset_left = 16.0
	_prev_btn.offset_top = 44.0
	_prev_btn.offset_right = 64.0
	_prev_btn.offset_bottom = 84.0
	_prev_btn.pressed.connect(func() -> void: _shift_world(-1))
	add_child(_prev_btn)

	_next_btn = Button.new()
	_next_btn.text = "▶"
	_next_btn.focus_mode = Control.FOCUS_NONE
	_next_btn.custom_minimum_size = Vector2(48, 40)
	_next_btn.anchor_left = 1.0
	_next_btn.anchor_right = 1.0
	_next_btn.offset_left = -64.0
	_next_btn.offset_right = -16.0
	_next_btn.offset_top = 44.0
	_next_btn.offset_bottom = 84.0
	_next_btn.pressed.connect(func() -> void: _shift_world(1))
	add_child(_next_btn)

	_world_label = Label.new()
	_world_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world_label.anchor_right = 1.0
	_world_label.offset_top = 48.0
	_world_label.offset_bottom = 88.0
	_world_label.add_theme_font_size_override("font_size", 28)
	_world_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	_world_label.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.05, 0.95))
	_world_label.add_theme_constant_override("outline_size", 8)
	add_child(_world_label)

	_map = Control.new()
	_map.name = "MapCanvas"
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.offset_top = 96.0
	_map.offset_bottom = -110.0
	_map.offset_left = 24.0
	_map.offset_right = -24.0
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_map.draw.connect(_on_map_draw)
	_map.gui_input.connect(_on_map_gui_input)
	add_child(_map)

	_pawn = Control.new()
	_pawn.custom_minimum_size = Vector2(44, 52)
	_pawn.size = Vector2(44, 52)
	_pawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pawn.z_index = 5
	_pawn.draw.connect(_on_pawn_draw)
	_map.add_child(_pawn)

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.anchor_left = 0.0
	_info.anchor_right = 1.0
	_info.anchor_top = 1.0
	_info.anchor_bottom = 1.0
	_info.offset_top = -100.0
	_info.offset_bottom = -52.0
	_info.offset_left = 40.0
	_info.offset_right = -40.0
	_info.add_theme_font_size_override("font_size", 18)
	_info.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_info.add_theme_constant_override("outline_size", 5)
	add_child(_info)

	_play_btn = Button.new()
	_play_btn.text = "Gir  ·  Space / Enter"
	_play_btn.focus_mode = Control.FOCUS_NONE
	_play_btn.anchor_left = 0.5
	_play_btn.anchor_right = 0.5
	_play_btn.anchor_top = 1.0
	_play_btn.anchor_bottom = 1.0
	_play_btn.offset_left = -160.0
	_play_btn.offset_right = 160.0
	_play_btn.offset_top = -46.0
	_play_btn.offset_bottom = -10.0
	_play_btn.pressed.connect(_try_enter_level)
	add_child(_play_btn)

	_hint = Label.new()
	_hint.text = "A/D seviye  ·  W/S dünya  ·  Space gir"

	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -128.0
	_hint.offset_bottom = -104.0
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.85, 0.9, 0.8, 0.9))
	add_child(_hint)


func _process(delta: float) -> void:
	if not visible:
		return
	_pawn_bob += delta * 4.5
	if _pawn != null:
		_pawn.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode
		if key == KEY_NONE:
			key = event.keycode
		match key:
			KEY_A:
				_move_cursor(-1)
				get_viewport().set_input_as_handled()
			KEY_D:
				_move_cursor(1)
				get_viewport().set_input_as_handled()
			KEY_W:
				_shift_world(-1)
				get_viewport().set_input_as_handled()
			KEY_S:
				_shift_world(1)
				get_viewport().set_input_as_handled()
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				_try_enter_level()
				get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_try_enter_level()
		get_viewport().set_input_as_handled()


func _shift_world(dir: int) -> void:
	var max_w := LevelData3D.world_count() - 1
	var next := _world_slot + dir
	if next < 0 or next > max_w:
		PrototypeSfx.play(_sfx, PrototypeSfx.Kind.SWITCH, 0.8)
		return
	if not _world_has_unlocked(next) and next != 0:
		PrototypeSfx.play(_sfx, PrototypeSfx.Kind.TASK_FAIL, 1.3)
		return
	_load_world(next)
	world_changed.emit(_world_slot)
	PrototypeSfx.play(_sfx, PrototypeSfx.Kind.SWITCH, 1.0)


func _world_has_unlocked(slot: int) -> bool:
	for li in LevelData3D.level_indices_for_world(slot):
		if LevelData3D.is_level_unlocked(li, _highest_unlocked):
			return true
	return false


func _load_world(slot: int, prefer_level: int = -1) -> void:
	_world_slot = clampi(slot, 0, LevelData3D.world_count() - 1)
	_levels = LevelData3D.level_indices_for_world(_world_slot)
	_cursor = 0
	if prefer_level >= 0:
		for i in _levels.size():
			if _levels[i] == prefer_level:
				_cursor = i
				break
	else:
		# En ilerideki açık node
		for i in range(_levels.size() - 1, -1, -1):
			if LevelData3D.is_level_unlocked(_levels[i], _highest_unlocked):
				_cursor = i
				break
	_relayout_nodes()
	_snap_pawn(false)
	_refresh_labels()
	_refresh_nodes()


func _relayout_nodes() -> void:
	_node_pos.clear()
	if _map == null:
		return
	var n := _levels.size()
	if n <= 0:
		_map.queue_redraw()
		return
	var size := _map.size
	if size.x < 8.0 or size.y < 8.0:
		return
	var pad_x := 56.0
	var mid_y := size.y * 0.52
	for i in n:
		var t := 0.0 if n == 1 else float(i) / float(n - 1)
		var x := lerpf(pad_x, size.x - pad_x, t)
		# NSMB benzeri hafif zikzak path
		var y := mid_y + sin(t * PI * 1.15 + float(_world_slot) * 0.35) * minf(70.0, size.y * 0.22)
		if i == n - 1 and n >= 4:
			y -= 18.0 # doruk / kale biraz yukarı
		_node_pos.append(Vector2(x, y))
	_map.queue_redraw()
	_snap_pawn(false)


func _refresh_nodes() -> void:
	if _map != null:
		_map.queue_redraw()
	_update_play_enabled()


func _refresh_labels() -> void:
	if _world_label != null:
		_world_label.text = "%s  %s" % [LevelData3D.world_icon(_world_slot), LevelData3D.world_title(_world_slot)]
	_update_info()
	_update_play_enabled()
	if _prev_btn != null:
		_prev_btn.disabled = _world_slot <= 0
	if _next_btn != null:
		_next_btn.disabled = _world_slot >= LevelData3D.world_count() - 1


func _current_level_index() -> int:
	if _cursor < 0 or _cursor >= _levels.size():
		return -1
	return _levels[_cursor]


func _update_info() -> void:
	if _info == null:
		return
	var li := _current_level_index()
	if li < 0:
		_info.text = ""
		return
	var info := LevelData3D.get_level(li)
	var unlocked := LevelData3D.is_level_unlocked(li, _highest_unlocked)
	var cleared := LevelData3D.is_level_cleared(li, _highest_unlocked)
	var status := "🔒 Kilitli"
	if unlocked:
		status = "✅ Temizlendi" if cleared else "▶ Hazır"
	_info.text = "%s\n%s\n%s" % [
		String(info.get("name", "Seviye")),
		String(info.get("subtitle", "")),
		status,
	]


func _update_play_enabled() -> void:
	var li := _current_level_index()
	var ok := li >= 0 and LevelData3D.is_level_unlocked(li, _highest_unlocked)
	if _play_btn != null:
		_play_btn.disabled = not ok
		_play_btn.modulate = Color(1, 1, 1, 1) if ok else Color(0.6, 0.6, 0.65, 0.85)


func _move_cursor(dir: int) -> void:
	if _levels.is_empty():
		return
	var next := _cursor + dir
	if next < 0 or next >= _levels.size():
		PrototypeSfx.play(_sfx, PrototypeSfx.Kind.SWITCH, 0.85)
		return
	var li: int = _levels[next]
	if not LevelData3D.is_level_unlocked(li, _highest_unlocked):
		PrototypeSfx.play(_sfx, PrototypeSfx.Kind.TASK_FAIL, 1.35)
		return
	_cursor = next
	_snap_pawn(true)
	_update_info()
	_update_play_enabled()
	PrototypeSfx.play(_sfx, PrototypeSfx.Kind.SWITCH, 1.15)


func _snap_pawn(animate: bool) -> void:
	if _pawn == null or _cursor < 0 or _cursor >= _node_pos.size():
		return
	var target: Vector2 = _node_pos[_cursor] - Vector2(22, 58)
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	if animate:
		_move_tween = create_tween()
		_move_tween.tween_property(_pawn, "position", target, 0.22)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_pawn.position = target


func _try_enter_level() -> void:
	var li := _current_level_index()
	if li < 0:
		return
	if not LevelData3D.is_level_unlocked(li, _highest_unlocked):
		PrototypeSfx.play(_sfx, PrototypeSfx.Kind.TASK_FAIL, 1.2)
		return
	PrototypeSfx.play(_sfx, PrototypeSfx.Kind.TASK_OK, 1.1)
	level_chosen.emit(li)


func _on_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = event.position
		var best := -1
		var best_d := 40.0
		for i in _node_pos.size():
			var d := local.distance_to(_node_pos[i])
			if d < best_d:
				best_d = d
				best = i
		if best >= 0:
			var li: int = _levels[best]
			if LevelData3D.is_level_unlocked(li, _highest_unlocked):
				if best == _cursor:
					_try_enter_level()
				else:
					_cursor = best
					_snap_pawn(true)
					_update_info()
					_update_play_enabled()
					PrototypeSfx.play(_sfx, PrototypeSfx.Kind.SWITCH, 1.1)
			else:
				PrototypeSfx.play(_sfx, PrototypeSfx.Kind.TASK_FAIL, 1.3)


func _on_map_draw() -> void:
	if _map == null:
		return
	# Path
	if _node_pos.size() >= 2:
		for i in range(_node_pos.size() - 1):
			var a: Vector2 = _node_pos[i]
			var b: Vector2 = _node_pos[i + 1]
			var unlocked_edge := LevelData3D.is_level_unlocked(_levels[i + 1], _highest_unlocked)
			var col := Color(0.92, 0.82, 0.45, 0.95) if unlocked_edge else Color(0.35, 0.4, 0.38, 0.7)
			_map.draw_line(a, b, col.darkened(0.35), PATH_W + 4.0, true)
			_map.draw_line(a, b, col, PATH_W, true)
	# Nodes
	for i in _node_pos.size():
		var p: Vector2 = _node_pos[i]
		var li: int = _levels[i]
		var unlocked := LevelData3D.is_level_unlocked(li, _highest_unlocked)
		var cleared := LevelData3D.is_level_cleared(li, _highest_unlocked)
		var info := LevelData3D.get_level(li)
		var is_boss := bool(info.get("is_boss_room", false))
		var selected := i == _cursor
		var fill := Color(0.55, 0.55, 0.58)
		if unlocked:
			fill = Color(0.95, 0.55, 0.35) if is_boss else Color(0.95, 0.35, 0.32)
			if cleared:
				fill = Color(0.35, 0.85, 0.45)
		var ring := Color(1, 1, 1, 0.95) if selected else Color(0.1, 0.1, 0.12, 0.85)
		var r := NODE_R + (4.0 if selected else 0.0)
		_map.draw_circle(p + Vector2(2, 3), r + 2.0, Color(0, 0, 0, 0.35))
		_map.draw_circle(p, r + 3.0, ring)
		_map.draw_circle(p, r, fill)
		# Label
		var label := "🔒"
		if unlocked:
			if is_boss:
				label = "🏰"
			elif bool(info.get("tutorial_level", false)):
				label = String(info.get("icon", "📘"))
			else:
				var tier := int(info.get("tier", i))
				label = str(tier + 1)
			if cleared:
				label = "★"
		var font := ThemeDB.fallback_font
		var fsize := 18 if label.length() <= 2 else 16
		var sz := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		_map.draw_string(font, p - sz * 0.5 + Vector2(0, fsize * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(1, 1, 1, 1))


func _on_pawn_draw() -> void:
	if _pawn == null:
		return
	var bob := sin(_pawn_bob) * 3.0
	var c := Vector2(_pawn.size.x * 0.5, _pawn.size.y * 0.55 + bob)
	_pawn.draw_circle(c + Vector2(2, 2), 16.0, Color(0, 0, 0, 0.3))
	_pawn.draw_circle(c, 15.0, Color(0.95, 0.88, 0.45))
	_pawn.draw_circle(c, 12.0, Color(0.35, 0.65, 0.95))
	var font := ThemeDB.fallback_font
	var face := "🧹"
	var fsize := 18
	var sz := font.get_string_size(face, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	_pawn.draw_string(font, c - sz * 0.5 + Vector2(0, 6), face, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.WHITE)
