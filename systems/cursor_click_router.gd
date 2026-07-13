class_name CursorClickRouter
extends Node

signal scrub_tick(position: Vector2)
signal reload_tick(position: Vector2)
signal junk_food_tempted(position: Vector2)
signal object_cleaned(position: Vector2)

@export var cursor_path: NodePath = ^"../TiredCursor"
@export var stamina_path: NodePath = ^"../StaminaComponent"
@export var stress_path: NodePath = ^"../StressComponent"
@export var mop_path: NodePath = ^"../MopComponent"
@export var room_manager_path: NodePath = ^"../RoomManager"

var _cursor: Node2D
var _stamina: StaminaComponent
var _stress: StressComponent
var _mop: MopComponent
# NOT: Döngüsel class bağımlılığını kırmak için RoomManager tipini kullanmıyoruz.
var _room_manager: Node

var _is_scrubbing: bool = false
var _scrubbing_active: bool = false
var _reloading: bool = false
var _last_click_pos: Vector2 = Vector2.ZERO
var _last_mouse_screen: Vector2 = Vector2.ZERO


func _ready() -> void:
	_cursor = get_node(cursor_path) as Node2D
	_stamina = get_node(stamina_path) as StaminaComponent
	_stress = get_node(stress_path) as StressComponent
	_mop = get_node_or_null(mop_path) as MopComponent
	_room_manager = get_node_or_null(room_manager_path)
	_last_mouse_screen = get_viewport().get_mouse_position()


func _can_interact() -> bool:
	if _room_manager == null:
		return true
	return not _room_manager.is_transitioning()


func is_actively_scrubbing() -> bool:
	return _scrubbing_active


func get_last_click_pos() -> Vector2:
	return _last_click_pos


# İmlecin (paspasın) drift eden gerçek konumu nişan noktasıdır.
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


func _process(delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	var motion := mouse - _last_mouse_screen
	_last_mouse_screen = mouse

	if not _can_interact():
		_is_scrubbing = false
		_scrubbing_active = false
		_reloading = false
		return

	var aim := _get_aim_pos()

	# 1) Kovada durulama (basılı tut)
	if _reloading:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _is_over_bucket(aim):
			if _mop != null:
				_mop.reload(delta)
			reload_tick.emit(aim)
		else:
			_reloading = false
		return

	# 2) Ovalama (rubbing) ile temizlik
	if not _is_scrubbing or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_scrubbing_active = false
		return

	var effort := motion.length()
	var effectiveness := _mop.get_effectiveness() if _mop != null else 1.0
	var over_stain := false

	for obj in _query_cleanables(aim):
		if obj.requires_scrub:
			over_stain = true
			if obj.scrub_rub(aim, motion, effectiveness):
				object_cleaned.emit(aim)

	_scrubbing_active = over_stain and effort > 1.5
	if _scrubbing_active:
		_stamina.drain(delta)
		if _mop != null:
			_mop.add_heat(effort)
		scrub_tick.emit(aim)


func _handle_press(pos: Vector2) -> void:
	# Önce kova: durulama moduna gir (hata sayılmaz)
	if _is_over_bucket(pos):
		_reloading = true
		return

	# Junk food (cazibe)
	var junk_hits := _query_junk_food(pos)
	if not junk_hits.is_empty():
		for junk in junk_hits:
			_apply_junk_food_effect(junk)
		return

	# Temizlenebilir objeler
	var hits := _query_cleanables(pos)
	if hits.is_empty():
		_stress.register_mistake()
		return

	var instant_clean := false
	for obj in hits:
		if obj.try_clean(pos):
			instant_clean = true
			object_cleaned.emit(pos)
		elif obj.requires_scrub and not obj.is_cleaned():
			_is_scrubbing = true

	if not instant_clean and not _is_scrubbing:
		_stress.register_mistake()


func _apply_junk_food_effect(junk: JunkFoodObject) -> void:
	junk.trigger_temptation()
	# Ödül: stamina geri gelir. Tuzak: stres artar + combo kırılır.
	_stamina.restore(junk.stamina_reward)
	_stress.add_stress(junk.stress_penalty)
	junk_food_tempted.emit(junk.global_position)


func _is_over_bucket(pos: Vector2) -> bool:
	var bucket := get_tree().get_first_node_in_group("MopBucket")
	if bucket == null or not bucket.has_method("get_hitbox"):
		return false
	return bucket.get_hitbox().has_point(pos)


func _query_junk_food(pos: Vector2) -> Array[JunkFoodObject]:
	var results: Array[JunkFoodObject] = []
	for node in get_tree().get_nodes_in_group("JunkFood"):
		if node is JunkFoodObject and node.is_active() and node.get_hitbox().has_point(pos):
			results.append(node)
	return results


func _query_cleanables(pos: Vector2) -> Array[CleanableObject]:
	var results: Array[CleanableObject] = []
	for node in get_tree().get_nodes_in_group("Cleanable"):
		if node is CleanableObject and not node.is_cleaned() and node.get_hitbox().has_point(pos):
			results.append(node)
	return results


func _get_world_mouse_pos() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()
