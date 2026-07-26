class_name CommissionDirector3D
extends Node

## 3D seviye başı komisyon kartı + twist kurallar.

signal commission_ready
signal time_up

@export var time_up_stress: float = 28.0

var _card: CommissionCardUI
var _info: Label
var _stress: StressComponent
var _spawner: Node
var _player: Node
var _camera: Node

var _current: Dictionary = {}
var _time_active: bool = false
var _time_left: float = 0.0
var _forbidden: ClutterProp
var _paused_for_card: bool = false


func setup(card: CommissionCardUI, info: Label, stress: StressComponent, spawner: Node, player: Node, camera: Node = null) -> void:
	_card = card
	_info = info
	_stress = stress
	_spawner = spawner
	_player = player
	_camera = camera


func clear() -> void:
	_time_active = false
	_time_left = 0.0
	_current = {}
	if _forbidden != null and is_instance_valid(_forbidden):
		_forbidden.set_meta("forbidden", false)
		_forbidden.set_micro_task_highlight(false)
	_forbidden = null
	if _stress != null:
		_stress.mistake_multiplier = 1.0
	if _info != null:
		_info.text = ""
	_restore_visibility()


func _process(delta: float) -> void:
	if _paused_for_card:
		return
	# LOW_VISIBILITY her kare güncellenir (süre kuralından bağımsız — eski bug: hiç güncellenmiyordu)
	if int(_current.get("rule", 0)) == CommissionData.Rule.LOW_VISIBILITY:
		_update_low_visibility()
	if not _time_active:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		_time_active = false
		_on_time_up()
	_update_info()


## Seviye başında kart göster, kural uygula (await).
func present_for_level(spec: Dictionary) -> void:
	clear()
	var commission: Dictionary = spec.get("commission", {}) as Dictionary
	if commission.is_empty():
		# intro alanından kart üret
		commission = {
			"npc": String(spec.get("npc", "Remzi")),
			"icon": String(spec.get("icon", "🧹")),
			"title": String(spec.get("name", "Seviye")),
			"desc": String(spec.get("intro", "Odayı temizle.")),
			"rule": CommissionData.Rule.NONE,
			"param": 0.0,
		}
	_current = commission
	if _card != null:
		_paused_for_card = true
		await _card.show_card(_current, 0.0, false)
		_paused_for_card = false
	_apply_rule()
	_update_info()
	commission_ready.emit()


func get_current() -> Dictionary:
	return _current


func is_showing_card() -> bool:
	return _paused_for_card


func _apply_rule() -> void:
	var rule := int(_current.get("rule", CommissionData.Rule.NONE))
	var param := float(_current.get("param", 0.0))
	match rule:
		CommissionData.Rule.TIME_LIMIT:
			_time_left = maxf(25.0, param if param > 0.0 else 45.0)
			_time_active = true
		CommissionData.Rule.HIGH_RISK:
			if _stress != null:
				_stress.mistake_multiplier = clampf(param if param > 1.0 else 2.0, 1.4, 3.0)
		CommissionData.Rule.FORBIDDEN:
			_mark_forbidden_prop()
		CommissionData.Rule.LOW_VISIBILITY:
			_apply_low_visibility(param if param > 0.0 else 3.2)
		_:
			pass


func _mark_forbidden_prop() -> void:
	if _spawner == null:
		return
	var candidates: Array[ClutterProp] = []
	for c in _spawner.get_children():
		var p := c as ClutterProp
		if p == null or p.is_destroying():
			continue
		if p.can_carry and String(p.get_meta("deliver_to", "")) == "trash":
			candidates.append(p)
	if candidates.is_empty():
		return
	_forbidden = candidates[randi() % candidates.size()]
	_forbidden.set_meta("forbidden", true)
	_forbidden.set_meta("objective", false)
	_forbidden.set_micro_task_highlight(true, "wrong")
	if _spawner.has_method("_emit_objective_state"):
		_spawner.call("_emit_objective_state")


func _apply_low_visibility(reveal_radius: float) -> void:
	if _spawner == null:
		return
	for c in _spawner.get_children():
		var p := c as ClutterProp
		if p == null:
			continue
		p.set_meta("low_vis", true)
		p.set_meta("reveal_radius", reveal_radius)
		if p.has_method("set_vis_mask_revealed"):
			p.call("set_vis_mask_revealed", false)
		else:
			p.visible = false
	# İlk karede maskeyi uygula
	call_deferred("_update_low_visibility")


func _update_low_visibility() -> void:
	if _player == null or _spawner == null:
		return
	if int(_current.get("rule", 0)) != CommissionData.Rule.LOW_VISIBILITY:
		return
	var origin: Vector3 = (_player as Node3D).global_position
	var facing := Vector3(0.0, 0.0, -1.0)
	if _player.has_method("get_facing_direction"):
		facing = (_player.call("get_facing_direction") as Vector3)
	facing.y = 0.0
	if facing.length_squared() < 0.0001:
		facing = Vector3(0.0, 0.0, -1.0)
	facing = facing.normalized()

	# Mask: yakın daire + bakış konisi (gerçek SpotLight yok)
	var foot_r := 2.6
	var beam_range := 11.0
	var beam_cos := cos(deg_to_rad(48.0))
	if _player.has_method("is_flashlight_on") and bool(_player.call("is_flashlight_on")):
		if _player.has_method("get_flashlight_range"):
			beam_range = float(_player.call("get_flashlight_range"))
		if _player.has_method("get_flashlight_half_angle_deg"):
			beam_cos = cos(deg_to_rad(float(_player.call("get_flashlight_half_angle_deg"))))

	for c in _spawner.get_children():
		var p := c as ClutterProp
		if p == null or not bool(p.get_meta("low_vis", false)):
			continue
		var near_r := maxf(float(p.get_meta("reveal_radius", 3.2)), foot_r)
		var flat := p.global_position - origin
		flat.y = 0.0
		var dist := flat.length()
		var revealed := dist <= near_r
		if not revealed and dist > 0.05 and dist <= beam_range:
			revealed = flat.normalized().dot(facing) >= beam_cos
		if p.has_method("set_vis_mask_revealed"):
			p.call("set_vis_mask_revealed", revealed)
		else:
			p.visible = revealed


func _restore_visibility() -> void:
	if _spawner == null:
		return
	for c in _spawner.get_children():
		var p := c as ClutterProp
		if p == null:
			continue
		if bool(p.get_meta("low_vis", false)):
			p.remove_meta("low_vis")
			if p.has_method("clear_vis_mask"):
				p.call("clear_vis_mask")
			else:
				p.visible = true


func _on_time_up() -> void:
	if _stress != null:
		_stress.add_stress(time_up_stress)
	if _camera != null and _camera.has_method("shake"):
		_camera.shake(2.2)
	time_up.emit()
	_update_info()


func _update_info() -> void:
	if _info == null:
		return
	var rule := int(_current.get("rule", CommissionData.Rule.NONE))
	if rule == CommissionData.Rule.TIME_LIMIT and (_time_active or _time_left > 0.0):
		_info.text = "⏱ KOMİSYON SÜRESİ: %d" % int(ceil(_time_left))
		_info.modulate = Color(1.0, 0.55, 0.4) if _time_left < 10.0 else Color(1.0, 0.85, 0.55)
	elif rule != CommissionData.Rule.NONE:
		_info.text = CommissionData.rule_label(rule)
		_info.modulate = Color(1.0, 0.7, 0.55)
	else:
		var npc := String(_current.get("npc", ""))
		_info.text = ("📜 %s" % npc) if npc != "" else ""
		_info.modulate = Color(0.85, 0.8, 0.7)


## Yasak prop dokunulursa / atılırsa çağır.
func notify_forbidden_touched() -> void:
	if _forbidden == null or not is_instance_valid(_forbidden):
		return
	if _stress != null:
		_stress.register_mistake()
		_stress.add_stress(18.0)
	if _camera != null and _camera.has_method("shake"):
		_camera.shake(1.6)
