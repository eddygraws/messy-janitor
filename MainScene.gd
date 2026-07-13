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
@onready var _score_tracker: RoomScoreTracker = $RoomScoreTracker


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
	_score_tracker.combo_changed.connect(_on_combo_changed)
	_on_combo_changed(0)

	_screens.start_pressed.connect(_on_start_pressed)
	_screens.restart_pressed.connect(_on_restart_pressed)

	_on_stamina_changed(_stamina.current_stamina, _stamina.max_stamina)
	_on_stress_changed(_stress.current_stress, _stress.max_stress)
	_update_room_counter()
	_room_manager.emit_current_objective()

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


func _on_start_pressed() -> void:
	_screens.hide_start()
	_enter_playing_state()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


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
	# Patlama partikülü ve sarsıntısının oynaması için pause'u kısa geciktir.
	await get_tree().create_timer(0.9).timeout
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _cursor:
		_cursor.visible = false
	_screens.show_game_over(
		_room_manager.current_room_index,
		_room_manager.total_rooms,
		_room_manager.get_level_score()
	)


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


func _on_room_transition_finished() -> void:
	_update_room_counter()


func _on_objective_changed(remaining: int, total: int) -> void:
	if _objective_label == null:
		return
	if remaining <= 0:
		_objective_label.text = "✓ ODA TEMİZ!"
		_objective_label.modulate = Color(0.5, 1.0, 0.6)
	else:
		_objective_label.text = "HEDEF: %d / %d kir temizlendi" % [total - remaining, total]
		_objective_label.modulate = Color(1, 1, 1)


func _update_room_counter() -> void:
	if _room_counter:
		_room_counter.text = "Room %d / %d" % [
			_room_manager.current_room_index + 1,
			_room_manager.total_rooms
		]
