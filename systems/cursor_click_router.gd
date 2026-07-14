class_name CursorClickRouter
extends Node

signal scrub_tick(position: Vector2)
signal reload_tick(position: Vector2)
signal junk_food_tempted(position: Vector2)
signal object_cleaned(position: Vector2)
signal on_drag_start(position: Vector2)
signal on_drag_end(position: Vector2)
signal object_disposed(position: Vector2)
signal wrong_tool(position: Vector2)

@export var cursor_path: NodePath = ^"../TiredCursor"
@export var stamina_path: NodePath = ^"../StaminaComponent"
@export var stress_path: NodePath = ^"../StressComponent"
@export var mop_path: NodePath = ^"../MopComponent"
@export var equipment_path: NodePath = ^"../EquipmentComponent"
@export var risk_path: NodePath = ^"../RiskModeComponent"
@export var room_manager_path: NodePath = ^"../RoomManager"
@export var skill_check_path: NodePath = ^"../MopSkillCheckDirector"
@export var modifier_path: NodePath = ^"../RunModifierDirector"
@export var combo_path: NodePath = ^"../ComboComponent"
@export var panic_hitbox_scale: float = 0.68   # panikte hitbox daralır (yanlış tıklama artar)
@export var wrong_tool_stress: float = 4.0     # yanlış alet: hafif ceza
@export var dangerous_wrong_stress: float = 14.0  # cımbız objesine yanlış alet: sert ceza
@export var forbidden_stress: float = 22.0     # "SAKIN dokunma" objesine dokunmak

var room_risk_multiplier: float = 1.0          # Commission "yüksek risk" kuralı bunu yükseltir

var _cursor: Node2D
var _stamina: StaminaComponent
var _stress: StressComponent
var _mop: MopComponent
var _equipment: EquipmentComponent
var _risk: RiskModeComponent
# NOT: Döngüsel class bağımlılığını kırmak için RoomManager tipini kullanmıyoruz.
var _room_manager: Node
var _skill_check: MopSkillCheckDirector
var _modifiers: RunModifierDirector
var _combo: ComboComponent

var _is_scrubbing: bool = false
var _scrubbing_active: bool = false
var _reloading: bool = false
# Kayan leke (DraggableCleanable) sınıf-adı bağımlılığından kaçınmak için
# duck-typing kullanıyoruz (yükleme sırası kaynaklı çözüm hatalarını önler).
var _dragging: Node2D = null
var _hitbox_scale: float = 1.0
var _last_click_pos: Vector2 = Vector2.ZERO
var _last_mouse_screen: Vector2 = Vector2.ZERO


func _ready() -> void:
	_cursor = get_node(cursor_path) as Node2D
	_stamina = get_node(stamina_path) as StaminaComponent
	_stress = get_node(stress_path) as StressComponent
	_mop = get_node_or_null(mop_path) as MopComponent
	_equipment = get_node_or_null(equipment_path) as EquipmentComponent
	_risk = get_node_or_null(risk_path) as RiskModeComponent
	_room_manager = get_node_or_null(room_manager_path)
	_skill_check = get_node_or_null(skill_check_path) as MopSkillCheckDirector
	_modifiers = get_node_or_null(modifier_path) as RunModifierDirector
	_combo = get_node_or_null(combo_path) as ComboComponent
	_last_mouse_screen = get_viewport().get_mouse_position()
	if _stress != null:
		_stress.panic_mode_entered.connect(_on_panic_entered)
		_stress.panic_mode_exited.connect(_on_panic_exited)
	if _equipment != null:
		_equipment.equipment_changed.connect(_on_equipment_changed)


func _can_interact() -> bool:
	if _room_manager == null:
		return true
	return not _room_manager.is_transitioning()


func is_actively_scrubbing() -> bool:
	return _scrubbing_active


func get_last_click_pos() -> Vector2:
	return _last_click_pos


func _get_aim_pos() -> Vector2:
	if _cursor != null:
		return _cursor.global_position
	return _get_world_mouse_pos()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_interact():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_last_click_pos = _get_aim_pos()
			_handle_press(_last_click_pos)
		else:
			_is_scrubbing = false
			_reloading = false
			if _skill_check != null:
				_skill_check.set_rinsing(false)
			if _dragging != null:
				on_drag_end.emit(_get_aim_pos())
				_dragging = null


func _process(delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	var motion := mouse - _last_mouse_screen
	_last_mouse_screen = mouse

	if not _can_interact():
		_is_scrubbing = false
		_scrubbing_active = false
		_reloading = false
		if _skill_check != null:
			_skill_check.set_rinsing(false)
		_dragging = null
		return

	var aim := _get_aim_pos()

	# 1) Kovada durulama + skill check (sadece paspas)
	if _reloading:
		if _current_eq() != CleanableObject.EQ_MOP:
			_reloading = false
			if _skill_check != null:
				_skill_check.set_rinsing(false)
			return
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _is_over_bucket(aim):
			if _skill_check != null:
				_skill_check.set_rinsing(true)
			if _mop != null and (_skill_check == null or not _skill_check.is_active()):
				_mop.reload(delta * _mop.passive_reload_scale)
			reload_tick.emit(aim)
		else:
			_reloading = false
			if _skill_check != null:
				_skill_check.set_rinsing(false)
		return

	# 2) Sürükleme (slime -> gider / süpürülen çöp -> çöp kovası) (duck-typing)
	if _dragging != null:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and is_instance_valid(_dragging) and not bool(_dragging.call("is_cleaned")):
			_dragging.call("drag_toward", aim, delta)
			scrub_tick.emit(_dragging.global_position)
			# Stamina düşükse sürüklerken obje elden kayabilir.
			if _stamina != null and _stamina.get_ratio() < 0.18 and randf() < 0.9 * delta:
				on_drag_end.emit(_dragging.global_position)
				_dragging = null
				return
			if bool(_dragging.call("is_over_target")):
				var drop := _dragging.global_position
				_dragging.call("deliver")
				object_disposed.emit(drop)
				object_cleaned.emit(drop)
				_dragging = null
		else:
			on_drag_end.emit(aim)
			_dragging = null
		return

	# 3) Ovalama ile temizlik (Paspas ve Sprey-sonrası Bez)
	if not _is_scrubbing or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_scrubbing_active = false
		return

	var eq := _current_eq()
	var effort := motion.length()
	var effectiveness := _mop.get_effectiveness() if (_mop != null and eq == CleanableObject.EQ_MOP) else 1.0
	if _modifiers != null and _combo != null:
		effectiveness *= _modifiers.get_scrub_speed_multiplier(_combo.get_combo())
	if _risk != null:
		effectiveness *= _risk.get_clean_speed_multiplier()
	var over_stain := false

	for obj in _query_cleanables(aim):
		if obj.requires_scrub and obj.required_equipment == eq:
			over_stain = true
			if obj.scrub_rub(aim, motion, effectiveness) and not obj.is_broken():
				object_cleaned.emit(aim)

	_scrubbing_active = over_stain and effort > 1.5
	if _scrubbing_active:
		var drain_mult := 1.0
		if _mop != null and eq == CleanableObject.EQ_MOP:
			drain_mult = _mop.get_stamina_drain_multiplier()
		_stamina.drain(delta, drain_mult)
		if _mop != null and eq == CleanableObject.EQ_MOP:
			_mop.add_heat(effort)
		scrub_tick.emit(aim)


func _current_eq() -> int:
	return _equipment.get_current() if _equipment != null else CleanableObject.EQ_MOP


func _handle_press(pos: Vector2) -> void:
	# Ekipman değişim donması: kısa süre etkileşim yok (ceza da yok).
	if _equipment != null and _equipment.is_switching():
		return

	# Kovada durulama — yalnızca paspas ekipmanı ve kir varken
	if _is_over_bucket(pos):
		if _current_eq() == CleanableObject.EQ_MOP and _mop != null and _mop.get_charge() > 0.001:
			_reloading = true
		return

	var eq := _current_eq()

	# Junk food (cazibe) - her aletle tıklanır
	var junk_hits := _query_junk_food(pos)
	if not junk_hits.is_empty():
		for junk in junk_hits:
			_apply_junk_food_effect(junk)
		return

	# Sürüklenebilir: slime (paspas) / süpürülen çöp (süpürge)
	var drag := _query_draggable(pos)
	if drag != null:
		# Miniboss henüz küçülmediyse sürüklenemez
		if drag.has_method("is_capturable") and not bool(drag.call("is_capturable")):
			return
		if int(drag.get("required_equipment")) == eq:
			_dragging = drag
			on_drag_start.emit(drag.global_position)
		else:
			_apply_wrong_tool(pos, int(drag.get("required_equipment")))
		return

	# Diğer temizlenebilirler
	var hits := _query_cleanables(pos)
	if hits.is_empty():
		_stress.register_mistake()
		return

	# Yasak obje ("SAKIN dokunma"): dokunmak ceza, temizlenmez.
	for h in hits:
		if h.is_forbidden:
			_apply_forbidden(pos)
			return

	# Aktif ekipmana uygun ilk objeyi seç
	var obj: CleanableObject = null
	for h in hits:
		if h.required_equipment == eq:
			obj = h
			break
	if obj == null:
		_apply_wrong_tool(pos, hits[0].required_equipment)
		return

	match eq:
		CleanableObject.EQ_MOP:
			if obj.try_clean(pos):
				object_cleaned.emit(pos)
			elif obj.requires_scrub and not obj.is_cleaned():
				_is_scrubbing = true
			else:
				_stress.register_mistake()
		CleanableObject.EQ_BRUSH:
			scrub_tick.emit(pos)
			var mash_mult := _risk.get_clean_speed_multiplier() if _risk != null else 1.0
			if _modifiers != null:
				mash_mult *= _modifiers.get_mult(&"mash_mult", 1.0)
			if obj.mash(mash_mult):
				object_cleaned.emit(pos)
		CleanableObject.EQ_SPRAY:
			if not obj.is_sprayed():
				obj.spray()
				scrub_tick.emit(pos)
			elif obj.requires_scrub and not obj.is_cleaned():
				_is_scrubbing = true
		CleanableObject.EQ_TWEEZERS:
			if obj.pluck():
				object_cleaned.emit(pos)


func _apply_wrong_tool(pos: Vector2, required: int) -> void:
	var penalty := wrong_tool_stress
	if required == CleanableObject.EQ_TWEEZERS:
		penalty = dangerous_wrong_stress   # tehlikeli obje + yanlış alet = sert ceza
	if _risk != null and _risk.is_active():
		penalty *= _risk.stress_multiplier
	penalty *= room_risk_multiplier
	_stress.add_stress(penalty)
	wrong_tool.emit(pos)


func _apply_forbidden(pos: Vector2) -> void:
	_stress.add_stress(forbidden_stress * room_risk_multiplier)
	wrong_tool.emit(pos)


func _apply_junk_food_effect(junk: JunkFoodObject) -> void:
	junk.trigger_temptation()
	# STRATEJİK KARAR: junk food artık sadece ceza değil, bağlama bağlı bir bahis.
	# - Stamina ne kadar düşükse ödül o kadar değerli (çaresizlik primi).
	# - Stres ne kadar yüksekse "sugar crash" o kadar sert (stresliyken yemek riskli).
	var stamina_ratio := _stamina.get_ratio()
	var stress_ratio := _stress.get_stress_ratio()

	var reward := junk.stamina_reward * lerpf(1.0, 1.5, 1.0 - stamina_ratio)
	_stamina.restore(reward)

	_stress.add_stress(junk.stress_penalty * 0.4)
	var crash := junk.stress_penalty * 0.85 * (1.0 + stress_ratio)
	_stress.add_delayed_stress(crash, junk.crash_delay)
	junk_food_tempted.emit(junk.global_position)


func _is_over_bucket(pos: Vector2) -> bool:
	var bucket := get_tree().get_first_node_in_group("MopBucket")
	if bucket == null or not bucket.has_method("get_hitbox"):
		return false
	return bucket.get_hitbox().has_point(pos)


func _query_draggable(pos: Vector2) -> Node2D:
	for node in get_tree().get_nodes_in_group("Draggable"):
		if not (node is Node2D):
			continue
		if bool(node.call("is_cleaned")) or not bool(node.call("is_revealed")):
			continue
		var rect: Rect2 = node.call("get_hitbox")
		if rect.has_point(pos):
			return node as Node2D
	return null


func _query_junk_food(pos: Vector2) -> Array[JunkFoodObject]:
	var results: Array[JunkFoodObject] = []
	for node in get_tree().get_nodes_in_group("JunkFood"):
		if node is JunkFoodObject and node.is_active() and node.get_hitbox().has_point(pos):
			results.append(node)
	return results


func _query_cleanables(pos: Vector2) -> Array[CleanableObject]:
	var results: Array[CleanableObject] = []
	for node in get_tree().get_nodes_in_group("Cleanable"):
		if node.is_in_group("Draggable"):
			continue
		if node is CleanableObject and not node.is_cleaned() and node.is_revealed():
			if _scaled_hitbox(node.get_hitbox()).has_point(pos):
				results.append(node)
	return results


# Panik VE Riskli Temizlik modunda hitbox merkeze doğru daralır -> isabet zorlaşır.
func _scaled_hitbox(rect: Rect2) -> Rect2:
	var scale := _hitbox_scale
	if _risk != null:
		scale = minf(scale, _risk.get_hitbox_scale())
	if scale >= 0.999:
		return rect
	var center := rect.get_center()
	var size := rect.size * scale
	return Rect2(center - size * 0.5, size)


func _on_panic_entered() -> void:
	_hitbox_scale = panic_hitbox_scale


func _on_panic_exited() -> void:
	_hitbox_scale = 1.0


func _on_equipment_changed(_type: int) -> void:
	if _reloading:
		_reloading = false
	if _skill_check != null:
		_skill_check.set_rinsing(false)
	_is_scrubbing = false
	_scrubbing_active = false


func _get_world_mouse_pos() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()
