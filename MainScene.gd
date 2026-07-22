extends Node2D

@onready var _stamina: StaminaComponent = $StaminaComponent
@onready var _stress: StressComponent = $StressComponent
@onready var _stamina_bar: ProgressBar = $UI/ProgressBar
@onready var _stress_label: Label = $UI/StersYuzdeLAbel
@onready var _room_counter: Label = $UI/RoomCounterLabel
@onready var _objective_label: Label = $UI/ObjectiveLabel
@onready var _room_manager: RoomManager = $RoomManager
@onready var _cursor: Node2D = $TiredCursor
@onready var _screens: GameScreens = $GameScreens
@onready var _mop: MopComponent = $MopComponent
@onready var _mop_charge_bar: ProgressBar = $UI/MopChargeBar
@onready var _mop_charge_label: Label = $UI/MopChargeLabel
@onready var _combo_label: Label = $UI/ComboLabel
@onready var _combo: ComboComponent = $ComboComponent
@onready var _equipment: EquipmentComponent = $EquipmentComponent
@onready var _equipment_bar: EquipmentBar = $UI/EquipmentBar
@onready var _tempo: TempoDirector = $TempoDirector
@onready var _risk: RiskModeComponent = $RiskModeComponent
@onready var _risk_label: Label = $UI/RiskLabel
@onready var _save: SaveManager = $SaveManager
@onready var _tutorial_label: Label = $UI/TutorialLabel
@onready var _run_timer: RunTimerComponent = $RunTimer
@onready var _time_label: Label = $UI/TimeLabel
@onready var _run_modifiers: RunModifierDirector = $RunModifierDirector
@onready var _post_process: PostProcessDirector = $PostProcessDirector
@onready var _powerups: ComboPowerupDirector = $ComboPowerupDirector
const UI_GLOW_SHADER: Shader = preload("res://shaders/ui_glow.gdshader")

@onready var _bucket_glow: Sprite2D = $WorldLayer/MopBucket/Glow

var _timer_started: bool = false
var _game_over_pending: bool = false
var _bucket_glow_mat: ShaderMaterial


func _ready() -> void:
	# PostFX (100) altında dünya; HUD ve menüler her zaman üstte kalsın.
	$UI.layer = 110
	_screens.layer = 120

	_stamina.stamina_changed.connect(_on_stamina_changed)
	_stress.stress_changed.connect(_on_stress_changed)
	_stress.stress_critical.connect(_on_stress_critical)
	_stress.stress_exploded.connect(_on_stress_exploded)
	_room_manager.room_transition_finished.connect(_on_room_transition_finished)
	_room_manager.objective_changed.connect(_on_objective_changed)
	_mop.charge_changed.connect(_on_mop_charge_changed)
	_mop.overheated.connect(_on_mop_overheated)
	_mop.rinsed.connect(_on_mop_rinsed)
	_combo.combo_changed.connect(_on_combo_changed)
	_combo.combo_milestone.connect(_on_combo_milestone)
	_on_combo_changed(0)
	if _powerups != null:
		_powerups.powerup_triggered.connect(_on_powerup_triggered)
	_tempo.climax_entered.connect(_on_climax_entered)
	_tempo.climax_exited.connect(_on_climax_exited)
	_risk.risk_changed.connect(_on_risk_changed)
	_on_risk_changed(_risk.is_active())
	# Eski HUD paspas barı / risk etiketi — bar artık alet yuvasında
	if _mop_charge_bar != null:
		_mop_charge_bar.visible = false
	if _mop_charge_label != null:
		_mop_charge_label.visible = false
	if _risk_label != null:
		_risk_label.visible = false

	_room_manager.level_completed.connect(_on_level_completed)
	_room_manager.tutorial_requested.connect(_show_tutorial)

	if _run_timer != null:
		_run_timer.time_changed.connect(_on_time_changed)
		_run_timer.time_expired.connect(_on_time_expired)
	if _run_modifiers != null:
		_run_modifiers.card_acquired.connect(_on_card_acquired)

	_screens.mode_selected.connect(_on_mode_selected)
	_screens.level_selected.connect(_on_level_selected)
	_screens.back_pressed.connect(_on_back_pressed)
	_screens.restart_pressed.connect(_on_restart_pressed)
	_screens.pause_resume_pressed.connect(_on_pause_resume)
	_screens.pause_main_menu_pressed.connect(_on_pause_main_menu)
	_screens.pause_shown.connect(_on_pause_shown)

	_on_stamina_changed(_stamina.current_stamina, _stamina.max_stamina)
	_on_stress_changed(_stress.current_stress, _stress.max_stress)
	_update_room_counter()
	_room_manager.emit_current_objective()
	_screens.set_records_text(_build_menu_records())

	# 3D prototip (geçici): F8 ile izometrik test sahnesi
	if not InputMap.has_action("debug_3d_prototype"):
		InputMap.add_action("debug_3d_prototype")
		var f8 := InputEventKey.new()
		f8.keycode = KEY_F8
		InputMap.action_add_event("debug_3d_prototype", f8)

	# Başlangıç ekranı açıkken oyunu duraklat ve donanım imlecini göster.
	_enter_menu_state()
	_setup_bucket_glow_shader()


func _setup_bucket_glow_shader() -> void:
	if _bucket_glow == null or UI_GLOW_SHADER == null:
		return
	_bucket_glow_mat = ShaderMaterial.new()
	_bucket_glow_mat.shader = UI_GLOW_SHADER
	_bucket_glow_mat.set_shader_parameter("intensity", 0.0)


func _enter_menu_state() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _cursor:
		_cursor.visible = false
	if _post_process:
		_post_process.set_menu_open(true)


func _enter_playing_state() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if _cursor:
		_cursor.visible = true
	if _post_process:
		_post_process.set_menu_open(false)
	if _run_timer != null and _timer_started and not _game_over_pending:
		_run_timer.resume_after_menu()


func _on_mode_selected(mode: int) -> void:
	_reset_run_timer_state()
	if mode == 0:
		# Intro await'i pause / inherit process altında kilitlenmesin.
		if _should_play_intro():
			var prev_mode := process_mode
			process_mode = Node.PROCESS_MODE_ALWAYS
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if _cursor != null:
				_cursor.visible = false
			_screens.hide_start()
			await _screens.play_intro()
			if _save != null:
				_save.mark_intro_seen()
			process_mode = prev_mode
			_screens.hide_level_select()
			_enter_playing_state()
			await _room_manager.start_adventure_level(0)
			_update_room_counter()
			return
		_screens.show_level_select(_save.get_highest_unlocked(), _level_best_array())
	elif mode == 2:
		# 3D garaj prototipi (Overcooked kontrol)
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes3d/main_3d.tscn")
	else:
		# Sonsuz mod menüden kaldırıldı — maceraya yönlendir
		_screens.show_level_select(_save.get_highest_unlocked(), _level_best_array())


func _should_play_intro() -> bool:
	if _save == null:
		return true
	# L1 bitmeden her Macera girişinde VN göster (save bayrağı takılı kalsa bile).
	if _save.get_level_best(0) <= 0 and _save.get_highest_unlocked() <= 1:
		return true
	return not _save.has_seen_intro()


func _on_level_selected(idx: int) -> void:
	_reset_run_timer_state()
	_screens.hide_level_select()
	_enter_playing_state()
	await _room_manager.start_adventure_level(idx)
	_update_room_counter()


func _on_back_pressed() -> void:
	_reset_run_timer_state()
	if _run_modifiers != null:
		_run_modifiers.reset_run()
	_screens.hide_pause()
	_enter_menu_state()
	_screens.set_records_text(_build_menu_records())
	_screens.show_start()


func _on_pause_shown() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _cursor:
		_cursor.visible = false
	if _run_timer != null and _timer_started:
		_run_timer.pause_for_menu()


func _on_pause_resume() -> void:
	if not _screens.is_pause_open():
		return
	_screens.hide_pause()
	_enter_playing_state()


func _on_pause_main_menu() -> void:
	_on_back_pressed()


func _level_best_array() -> Array:
	var arr: Array = []
	for i in LevelData.level_count():
		arr.append(_save.get_level_best(i) if _save != null else 0)
	return arr


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_card_acquired(card: CardData) -> void:
	_show_tutorial("Kart alındı: %s %s" % [card.icon, card.title])


func _show_tutorial(text: String) -> void:
	if _tutorial_label == null or text == "":
		return
	_tutorial_label.text = "💡 " + text
	_tutorial_label.modulate = Color(1, 0.95, 0.6, 0.0)
	_tutorial_label.pivot_offset = _tutorial_label.size * 0.5
	_tutorial_label.scale = Vector2(0.85, 0.85)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_tutorial_label, "modulate:a", 1.0, 0.25)
	tween.tween_property(_tutorial_label, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(3.2)
	tween.chain().tween_property(_tutorial_label, "modulate:a", 0.0, 0.6)


func _on_stamina_changed(current: float, maximum: float) -> void:
	_stamina_bar.max_value = maximum
	_stamina_bar.value = current


func _on_stress_changed(current: float, maximum: float) -> void:
	var ratio := current / maximum
	_stress_label.text = "%d%%" % int(ratio * 100.0)


func _on_stress_critical() -> void:
	pass


func _on_stress_exploded() -> void:
	if _game_over_pending:
		return
	_game_over_pending = true
	if _run_timer != null:
		_run_timer.stop()
	print("GAME OVER — Remzi patladı!")
	var records := _record_current_run(false)
	# Patlama partikülü ve sarsıntısının oynaması için pause'u kısa geciktir.
	await get_tree().create_timer(0.9).timeout
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _cursor:
		_cursor.visible = false
	_screens.show_game_over(_build_over_title(), _build_over_info(records))


func _on_level_completed(total: int, _average: int) -> void:
	if _run_timer != null:
		_run_timer.stop()
	var lvl := _room_manager.get_level_index()
	var records: Array[String] = []
	if _save != null:
		records = _save.record_level_complete(lvl, total, _room_manager.get_run_max_combo())

	if lvl >= LevelData.level_count() - 1:
		# Tüm oyun tamamlandı.
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if _cursor:
			_cursor.visible = false
		_screens.show_game_over("🏆 TEMİZLİK USTASI!", _build_all_clear_info(total, records))
	else:
		# Seviye tamamlandı → seviye seçim ekranına dön (sonraki seviye açıldı).
		_enter_menu_state()
		_screens.set_records_text(_build_menu_records())
		_screens.show_level_select(_save.get_highest_unlocked(), _level_best_array())


func _record_current_run(completed: bool) -> Array[String]:
	if _save == null:
		return []
	return _save.record_run(
		_room_manager.get_mode(),
		_room_manager.get_rooms_cleared(),
		_room_manager.get_level_score(),
		_room_manager.get_run_max_combo(),
		completed
	)


func _build_over_title() -> String:
	return "PATLADI GİTTİ!"


func _build_over_info(records: Array[String]) -> String:
	var run_time := int(_room_manager.get_run_time())
	var line: String
	if _room_manager.get_mode() == RoomManager.Mode.ENDLESS:
		var survived := _room_manager.get_rooms_cleared()
		line = "Remzi strese dayanamayıp patladı!\n%d tur temizlendi · %ds dayandın" % [survived, run_time]
		line += "\nEn yüksek combo: x%d · %d puan" % [_room_manager.get_run_max_combo(), _room_manager.get_level_score()]
	else:
		line = "Ana karakter patladı gitti!\nSeviye %d · Oda %d/%d · %d puan" % [
			_room_manager.get_level_index() + 1,
			_room_manager.current_room_index + 1,
			_room_manager.total_rooms,
			_room_manager.get_level_score()
		]
	return line + _records_or_best(records)


func _build_all_clear_info(total: int, records: Array[String]) -> String:
	var line := "TÜM %d SEVİYE TAMAMLANDI!\nSon seviye: %d puan · En yüksek combo x%d" % [
		LevelData.level_count(),
		total, _room_manager.get_run_max_combo()
	]
	return line + _records_or_best(records)


func _records_or_best(records: Array[String]) -> String:
	if not records.is_empty():
		return "\n\n" + "\n".join(records)
	if _save == null:
		return ""
	return "\n\nEn iyi: ♾ %d tur · 🗺 %d puan" % [
		_save.get_endless_best_rooms(), _save.get_adventure_best_score()
	]


func _build_menu_records() -> String:
	if _save == null or not _save.has_any_record():
		return "İlk koşunu yap ve rekor kır!"
	var endless_line := "♾ Sonsuz en iyi: %d tur · %d puan" % [
		_save.get_endless_best_rooms(), _save.get_endless_best_score()
	]
	var adv_line := "🗺 Macera en iyi: %d puan" % _save.get_adventure_best_score()
	if _save.is_adventure_cleared():
		adv_line += "  ✓"
	return endless_line + "\n" + adv_line


func _on_mop_charge_changed(ratio: float) -> void:
	if _equipment_bar != null:
		_equipment_bar.set_mop_charge(ratio)


func _on_mop_overheated() -> void:
	if _equipment_bar != null:
		_equipment_bar.set_mop_overheated(true)
	if _bucket_glow == null:
		return
	if _bucket_glow.texture == null:
		_bucket_glow.texture = GameAssets.get_bucket_glow()
	_bucket_glow.modulate = Color(1.0, 0.7, 0.3, 1.0)
	if _bucket_glow_mat != null and _bucket_glow_mat.shader != null:
		_bucket_glow_mat.set_shader_parameter("intensity", 1.6)
		_bucket_glow_mat.set_shader_parameter("glow_color", Color(1.0, 0.45, 0.15))
		_bucket_glow.material = _bucket_glow_mat
	else:
		_bucket_glow.material = null


func _on_mop_rinsed() -> void:
	if _equipment_bar != null:
		_equipment_bar.set_mop_rinsed()
	if _bucket_glow != null:
		_bucket_glow.material = null
		_bucket_glow.modulate.a = 0.0


func _on_combo_changed(combo: int) -> void:
	if _combo_label == null:
		return
	if combo < 2:
		_combo_label.text = ""
		return
	_combo_label.text = "COMBO x%d" % combo
	_combo_label.modulate = Color(1.0, 0.85, 0.3)
	_combo_label.scale = Vector2(1.3, 1.3)
	_combo_label.pivot_offset = _combo_label.size * 0.5
	var tween := create_tween()
	tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_combo_milestone(combo: int) -> void:
	if _combo_label == null:
		return
	_combo_label.text = "COMBO x%d  +SÜRE +ENERJİ!" % combo
	_combo_label.modulate = Color(0.5, 1.0, 0.6)
	_combo_label.scale = Vector2(1.6, 1.6)
	_combo_label.pivot_offset = _combo_label.size * 0.5
	var tween := create_tween()
	tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.28)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_powerup_triggered(_kind: StringName, title: String) -> void:
	if _combo_label == null:
		return
	_combo_label.text = title
	_combo_label.modulate = Color(0.55, 0.95, 1.0)
	_combo_label.scale = Vector2(1.55, 1.55)
	_combo_label.pivot_offset = _combo_label.size * 0.5
	var tween := create_tween()
	tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


var _climax_active: bool = false


func _on_climax_entered() -> void:
	_climax_active = true
	if _objective_label:
		_objective_label.pivot_offset = _objective_label.size * 0.5
		_objective_label.scale = Vector2(1.4, 1.4)
		var tween := create_tween()
		tween.tween_property(_objective_label, "scale", Vector2.ONE, 0.3)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_room_manager.emit_current_objective()


func _on_climax_exited() -> void:
	_climax_active = false
	_room_manager.emit_current_objective()


func _on_risk_changed(_active: bool) -> void:
	# Riskli Temizlik (R) rafa kalktı
	if _risk_label != null:
		_risk_label.visible = false


func _on_room_transition_finished() -> void:
	_update_room_counter()
	if not _timer_started and _run_timer != null:
		_run_timer.start_run(_room_manager.get_mode())
		_timer_started = true


func _on_time_changed(seconds_left: float) -> void:
	if _time_label == null:
		return
	var total := int(ceilf(seconds_left))
	var mins := total / 60
	var secs := total % 60
	_time_label.text = "⏱ %d:%02d" % [mins, secs]
	if seconds_left <= 30.0:
		_time_label.modulate = Color(1.0, 0.35, 0.3)
	elif seconds_left <= 60.0:
		_time_label.modulate = Color(1.0, 0.75, 0.35)
	else:
		_time_label.modulate = Color(0.85, 0.9, 1.0)


func _on_time_expired() -> void:
	if _game_over_pending:
		return
	_game_over_pending = true
	if _run_timer != null:
		_run_timer.stop()
	await get_tree().create_timer(0.35).timeout
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _cursor:
		_cursor.visible = false
	var records := _record_current_run(false)
	_screens.show_game_over("SÜRE DOLDU!", _build_time_up_info(records))


func _build_time_up_info(records: Array[String]) -> String:
	var line: String
	if _room_manager.get_mode() == RoomManager.Mode.ENDLESS:
		line = "Süre bitti!\n%d tur temizlendi · En yüksek combo x%d" % [
			_room_manager.get_rooms_cleared(), _room_manager.get_run_max_combo()
		]
	else:
		line = "Süre bitti!\nSeviye %d · Oda %d/%d · %d puan" % [
			_room_manager.get_level_index() + 1,
			_room_manager.current_room_index + 1,
			_room_manager.total_rooms,
			_room_manager.get_level_score()
		]
	return line + _records_or_best(records)


func _reset_run_timer_state() -> void:
	_timer_started = false
	_game_over_pending = false
	if _run_timer != null:
		_run_timer.stop()
	if _time_label != null:
		_time_label.text = "⏱ --:--"
		_time_label.modulate = Color(0.85, 0.9, 1.0)


func _on_objective_changed(remaining: int, total: int) -> void:
	if _objective_label == null:
		return
	if remaining <= 0:
		_objective_label.text = "✓ ODA TEMİZ!"
		_objective_label.modulate = Color(0.5, 1.0, 0.6)
	elif _climax_active:
		_objective_label.text = "⏱ ACELE ET!  %d / %d" % [total - remaining, total]
		_objective_label.modulate = Color(1.0, 0.5, 0.4)
	else:
		_objective_label.text = "HEDEF: %d / %d kir temizlendi" % [total - remaining, total]
		_objective_label.modulate = Color(1, 1, 1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_3d_prototype"):
		get_tree().change_scene_to_file("res://scenes3d/main_3d.tscn")


func _update_room_counter() -> void:
	if _room_counter == null:
		return
	if _room_manager.get_mode() == RoomManager.Mode.ENDLESS:
		_room_counter.text = "Tur %d  ♾" % (_room_manager.current_room_index + 1)
	else:
		_room_counter.text = "S%d · Oda %d / %d" % [
			_room_manager.get_level_index() + 1,
			_room_manager.current_room_index + 1,
			_room_manager.total_rooms
		]
