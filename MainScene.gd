extends Node2D

@onready var _stamina: StaminaComponent = $StaminaComponent
@onready var _stress: StressComponent = $StressComponent
@onready var _stamina_bar: ProgressBar = $UI/ProgressBar
@onready var _stress_label: Label = $UI/StersYuzdeLAbel
@onready var _portrait: Sprite2D = $UI/KarakterPortresi
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
@onready var _tempo: TempoDirector = $TempoDirector
@onready var _risk: RiskModeComponent = $RiskModeComponent
@onready var _risk_label: Label = $UI/RiskLabel
@onready var _save: SaveManager = $SaveManager
@onready var _tutorial_label: Label = $UI/TutorialLabel


func _ready() -> void:
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
	_equipment.equipment_changed.connect(_on_equipment_changed)
	_on_equipment_changed(_equipment.get_current())
	_tempo.climax_entered.connect(_on_climax_entered)
	_tempo.climax_exited.connect(_on_climax_exited)
	_risk.risk_changed.connect(_on_risk_changed)
	_on_risk_changed(_risk.is_active())

	_room_manager.level_completed.connect(_on_level_completed)
	_room_manager.tutorial_requested.connect(_show_tutorial)

	_screens.mode_selected.connect(_on_mode_selected)
	_screens.level_selected.connect(_on_level_selected)
	_screens.back_pressed.connect(_on_back_pressed)
	_screens.restart_pressed.connect(_on_restart_pressed)

	_on_stamina_changed(_stamina.current_stamina, _stamina.max_stamina)
	_on_stress_changed(_stress.current_stress, _stress.max_stress)
	_update_room_counter()
	_room_manager.emit_current_objective()
	_screens.set_records_text(_build_menu_records())

	# Başlangıç ekranı açıkken oyunu duraklat ve donanım imlecini göster.
	_enter_menu_state()


func _enter_menu_state() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _cursor:
		_cursor.visible = false


func _enter_playing_state() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if _cursor:
		_cursor.visible = true


func _on_mode_selected(mode: int) -> void:
	if mode == 0:
		# Macera: seviye seçim ekranını aç.
		_screens.show_level_select(_save.get_highest_unlocked(), _level_best_array())
	else:
		_screens.hide_start()
		_room_manager.start_run(1)
		_update_room_counter()
		_enter_playing_state()


func _on_level_selected(idx: int) -> void:
	_screens.hide_level_select()
	_enter_playing_state()
	_room_manager.start_adventure_level(idx)
	_update_room_counter()


func _on_back_pressed() -> void:
	_enter_menu_state()
	_screens.set_records_text(_build_menu_records())
	_screens.show_start()


func _level_best_array() -> Array:
	var arr: Array = []
	for i in 10:
		arr.append(_save.get_level_best(i) if _save != null else 0)
	return arr


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


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
	if _portrait:
		var swell := lerpf(1.0, 1.35, ratio)
		_portrait.scale = Vector2(swell, swell)


func _on_stress_critical() -> void:
	pass


func _on_stress_exploded() -> void:
	print("GAME OVER — Gargoyle patladı!")
	var records := _record_current_run(false)
	# Patlama partikülü ve sarsıntısının oynaması için pause'u kısa geciktir.
	await get_tree().create_timer(0.9).timeout
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _cursor:
		_cursor.visible = false
	_screens.show_game_over(_build_over_title(), _build_over_info(records))


func _on_level_completed(total: int, _average: int) -> void:
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
	return "SPLAT!"


func _build_over_info(records: Array[String]) -> String:
	var run_time := int(_room_manager.get_run_time())
	var line: String
	if _room_manager.get_mode() == RoomManager.Mode.ENDLESS:
		var survived := _room_manager.get_rooms_cleared()
		line = "Gargoyle patladı!\n%d tur temizlendi · %ds dayandın" % [survived, run_time]
		line += "\nEn yüksek combo: x%d · %d puan" % [_room_manager.get_run_max_combo(), _room_manager.get_level_score()]
	else:
		line = "Gargoyle patladı!\nSeviye %d · Oda %d/%d · %d puan" % [
			_room_manager.get_level_index() + 1,
			_room_manager.current_room_index + 1,
			_room_manager.total_rooms,
			_room_manager.get_level_score()
		]
	return line + _records_or_best(records)


func _build_all_clear_info(total: int, records: Array[String]) -> String:
	var line := "TÜM 10 SEVİYE TAMAMLANDI!\nSon seviye: %d puan · En yüksek combo x%d" % [
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
	if _mop_charge_bar:
		_mop_charge_bar.value = ratio * 100.0


func _on_mop_overheated() -> void:
	if _mop_charge_label:
		_mop_charge_label.text = "PASPAS KİRLİ! → KOVADA DURULA"
		_mop_charge_label.modulate = Color(1.0, 0.4, 0.35)


func _on_mop_rinsed() -> void:
	if _mop_charge_label:
		_mop_charge_label.text = "PASPAS KİRİ"
		_mop_charge_label.modulate = Color(1.0, 0.7, 0.35)


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
	_combo_label.text = "COMBO x%d  +ENERJİ!" % combo
	_combo_label.modulate = Color(0.5, 1.0, 0.6)
	_combo_label.scale = Vector2(1.6, 1.6)
	_combo_label.pivot_offset = _combo_label.size * 0.5
	var tween := create_tween()
	tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.28)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


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


func _on_risk_changed(active: bool) -> void:
	if _risk_label == null:
		return
	if active:
		_risk_label.text = "⚡ RİSKLİ TEMİZLİK AÇIK  ×%.1f PUAN" % _risk.score_multiplier
		_risk_label.modulate = Color(1.0, 0.4, 0.35)
		_risk_label.pivot_offset = _risk_label.size * 0.5
		_risk_label.scale = Vector2(1.3, 1.3)
		var tween := create_tween()
		tween.tween_property(_risk_label, "scale", Vector2.ONE, 0.25)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_risk_label.text = "⚡ Riskli Temizlik: R"
		_risk_label.modulate = Color(0.7, 0.7, 0.72, 0.55)


func _on_equipment_changed(type: int) -> void:
	# İmleci aktif ekipmanın rengiyle boya (görsel ipucu).
	if _cursor and type >= 0 and type < EquipmentComponent.COLORS.size():
		var col: Color = EquipmentComponent.COLORS[type]
		var tween := create_tween()
		tween.tween_property(_cursor, "modulate", col, 0.12)


func _on_room_transition_finished() -> void:
	_update_room_counter()


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
