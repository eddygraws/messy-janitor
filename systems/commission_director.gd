class_name CommissionDirector
extends Node

# Adventure Mode: oda başında görev kartını gösterir ve komisyonun
# "twist kuralını" uygular; süre sınırı gibi süreklilik gerektiren
# kuralları da yönetir. Endless modda kullanılmaz.

@export var card_path: NodePath = ^"../UI/CommissionCardUI"
@export var info_label_path: NodePath = ^"../UI/CommissionInfoLabel"
@export var stress_path: NodePath = ^"../StressComponent"
@export var shake_path: NodePath = ^"../ScreenShake"
@export var router_path: NodePath = ^"../CursorClickerRouter"
@export var room_manager_path: NodePath = ^"../RoomManager"

@export var time_up_stress: float = 30.0
@export var high_risk_multiplier_cap: float = 3.0

var _card: CommissionCardUI
var _info: Label
var _stress: StressComponent
var _shake: ScreenShake
var _router: CursorClickRouter
var _room_manager: Node

var _current: Dictionary = {}
var _time_active: bool = false
var _time_left: float = 0.0


func _ready() -> void:
	_card = get_node_or_null(card_path) as CommissionCardUI
	_info = get_node_or_null(info_label_path) as Label
	_stress = get_node_or_null(stress_path) as StressComponent
	_shake = get_node_or_null(shake_path) as ScreenShake
	_router = get_node_or_null(router_path) as CursorClickRouter
	_room_manager = get_node_or_null(room_manager_path)
	if _info != null:
		_info.text = ""


func _process(delta: float) -> void:
	if not _time_active:
		return
	if _room_manager != null and _room_manager.has_method("is_transitioning") and _room_manager.is_transitioning():
		return

	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		_time_active = false
		_on_time_up()
	_update_info()


# RoomManager oda başında çağırır (await edilebilir).
func present(index: int, room: Node) -> void:
	clear()
	_current = CommissionData.get_commission(index)
	if _card != null:
		await _card.show_card(_current)
	_apply_rule(room)
	_update_info()


func clear() -> void:
	_time_active = false
	if _router != null:
		_router.room_risk_multiplier = 1.0
	if _info != null:
		_info.text = ""


func _apply_rule(room: Node) -> void:
	if room == null:
		return
	var rule := int(_current.get("rule", 0))
	var param := float(_current.get("param", 0.0))

	match rule:
		CommissionData.Rule.FORBIDDEN:
			_mark_a_forbidden(room)
			if _room_manager != null and _room_manager.has_method("emit_current_objective"):
				_room_manager.emit_current_objective()
		CommissionData.Rule.TIME_LIMIT:
			_time_left = param
			_time_active = true
		CommissionData.Rule.LOW_VISIBILITY:
			for obj in _cleanables(room):
				if not obj.is_forbidden:
					obj.enable_hidden(param)
		CommissionData.Rule.HIGH_RISK:
			if _router != null:
				_router.room_risk_multiplier = minf(param, high_risk_multiplier_cap)


func _mark_a_forbidden(room: Node) -> void:
	# Temizlenebilir, mop ile uyumlu bir objeyi tercihen yasak işaretle.
	var candidates := _cleanables(room)
	var chosen: CleanableObject = null
	for obj in candidates:
		if not obj.is_forbidden and not obj.is_in_group("Draggable") and obj.required_equipment == 0:
			chosen = obj
			break
	if chosen == null:
		for obj in candidates:
			if not obj.is_forbidden and not obj.is_in_group("Draggable"):
				chosen = obj
				break
	if chosen != null:
		chosen.mark_forbidden()


func _cleanables(room: Node) -> Array:
	var out: Array = []
	for child in room.get_children():
		if child is CleanableObject:
			out.append(child)
	return out


func _on_time_up() -> void:
	if _stress != null:
		_stress.add_stress(time_up_stress)
	if _shake != null:
		_shake.shake(0.7)
	if _info != null:
		_info.text = "🤮 SÜRE DOLDU!"
		_info.modulate = Color(1.0, 0.4, 0.35)


func _update_info() -> void:
	if _info == null:
		return
	var rule := int(_current.get("rule", 0))
	if rule == CommissionData.Rule.TIME_LIMIT and _time_active:
		_info.modulate = Color(1.0, 0.55, 0.4) if _time_left > 10.0 else Color(1.0, 0.3, 0.3)
		_info.text = "⏱ %d sn  ·  %s" % [ceili(_time_left), String(_current.get("title", ""))]
	elif rule != CommissionData.Rule.NONE and rule != CommissionData.Rule.TIME_LIMIT:
		_info.modulate = Color(0.9, 0.75, 0.6)
		_info.text = CommissionData.rule_label(rule)
	else:
		_info.text = ""
