class_name ComboPowerupDirector
extends Node

signal powerup_triggered(kind: StringName, title: String)

@export var combo_path: NodePath = ^"../ComboComponent"
@export var room_manager_path: NodePath = ^"../RoomManager"
@export var mop_path: NodePath = ^"../MopComponent"
@export var cursor_path: NodePath = ^"../TiredCursor"
@export var timer_path: NodePath = ^"../RunTimer"
@export var shake_path: NodePath = ^"../ScreenShake"

@export var bomb_partial_ratio: float = 0.62
@export var bomb_partial_cap: float = 0.92
@export var boss_stun_seconds: float = 2.4
@export var antidote_seconds: float = 8.0
@export var time_capsule_seconds: float = 9.0
@export var magnet_pull_seconds: float = 1.1
@export var magnet_strength: float = 520.0

var _combo: ComboComponent
var _room_manager: Node
var _mop: MopComponent
var _cursor: Node2D
var _timer: RunTimerComponent
var _shake: Node
var _magnet_timer: float = 0.0


func _ready() -> void:
	_combo = get_node_or_null(combo_path) as ComboComponent
	_room_manager = get_node_or_null(room_manager_path)
	_mop = get_node_or_null(mop_path) as MopComponent
	_cursor = get_node_or_null(cursor_path) as Node2D
	_timer = get_node_or_null(timer_path) as RunTimerComponent
	_shake = get_node_or_null(shake_path)
	if _combo != null:
		_combo.combo_changed.connect(_on_combo_changed)


func _process(delta: float) -> void:
	if _magnet_timer <= 0.0:
		return
	_magnet_timer -= delta
	if _cursor == null:
		return
	var aim := _cursor.global_position
	for node in get_tree().get_nodes_in_group("Draggable"):
		if not is_instance_valid(node) or not node.has_method("is_cleaned"):
			continue
		if bool(node.call("is_cleaned")):
			continue
		if not _is_in_active_room(node):
			continue
		var n2 := node as Node2D
		var dir := (aim - n2.global_position)
		var dist := dir.length()
		if dist < 8.0:
			continue
		n2.global_position += dir.normalized() * minf(magnet_strength * delta, dist * 0.35)


func _on_combo_changed(combo: int) -> void:
	if combo <= 0:
		return
	# Eşikler: 10 bomba, 15 soğuk su+mıknatıs, 20 antidot+zaman
	if combo % 10 == 0:
		_trigger_clean_bomb()
	if combo % 15 == 0:
		_trigger_cold_water()
		_trigger_magnet()
	if combo % 20 == 0:
		_trigger_antidote()
		_trigger_time_capsule()


func _trigger_clean_bomb() -> void:
	var cleaned := 0
	var weakened := 0
	for node in _active_cleanables():
		var kind := _dirt_kind(node)
		match kind:
			"stain", "scrub", "slime_trail", "mop_stain":
				if node.has_method("force_clean"):
					if bool(node.call("force_clean")):
						cleaned += 1
			"potion", "brush", "spray", "mold", "hidden", "fragile":
				var amount := bomb_partial_ratio
				if kind == "fragile":
					amount = 0.28
				if node.has_method("apply_clean_progress"):
					node.call("apply_clean_progress", amount, false, bomb_partial_cap)
					weakened += 1
			"slime_boss":
				if node.has_method("stun"):
					node.call("stun", boss_stun_seconds)
					weakened += 1
			_:
				if node is CleanableObject and (node as CleanableObject).requires_scrub:
					if node.has_method("apply_clean_progress"):
						node.call("apply_clean_progress", bomb_partial_ratio, false, bomb_partial_cap)
						weakened += 1
	_juice(0.22)
	_emit_banner(&"clean_bomb", "💥 TEMİZLİK BOMBASI!  %d temiz · %d zayıflatıldı" % [cleaned, weakened])
	if _room_manager != null and _room_manager.has_method("emit_current_objective"):
		_room_manager.emit_current_objective()
	if _room_manager != null and _room_manager.has_method("check_room_cleared"):
		_room_manager.check_room_cleared()


func _trigger_cold_water() -> void:
	if _mop != null and _mop.has_method("force_rinse"):
		_mop.call("force_rinse")
	_juice(0.12)
	_emit_banner(&"cold_water", "💧 SOĞUK SU! Paspas tertemiz")


func _trigger_magnet() -> void:
	_magnet_timer = magnet_pull_seconds
	_juice(0.1)
	_emit_banner(&"magnet", "🧲 MIKNATIS! Balçıklar çekiliyor")


func _trigger_antidote() -> void:
	if _cursor != null and _cursor.has_method("clear_drunk"):
		_cursor.call("clear_drunk")
	if _cursor != null and _cursor.has_method("grant_antidote"):
		_cursor.call("grant_antidote", antidote_seconds)
	_juice(0.14)
	_emit_banner(&"antidote", "🧪 ANTİDOT! %ds iksir bağışıklığı" % int(antidote_seconds))


func _trigger_time_capsule() -> void:
	if _timer != null:
		_timer.add_time(time_capsule_seconds)
	_juice(0.1)
	_emit_banner(&"time_capsule", "⏳ ZAMAN KAPSÜLÜ! +%d sn" % int(time_capsule_seconds))


func _active_cleanables() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("Cleanable"):
		if not is_instance_valid(node):
			continue
		if not node.has_method("is_cleaned") or bool(node.call("is_cleaned")):
			continue
		if bool(node.get("is_forbidden")):
			continue
		if not _is_in_active_room(node):
			continue
		out.append(node)
	return out


func _is_in_active_room(node: Node) -> bool:
	if _room_manager == null or not _room_manager.has_method("get_current_room"):
		return true
	var room: Node = _room_manager.get_current_room()
	if room == null:
		return false
	var p := node.get_parent()
	while p != null:
		if p == room:
			return true
		p = p.get_parent()
	return false


func _dirt_kind(node: Node) -> String:
	if node.has_meta("dirt_type"):
		return String(node.get_meta("dirt_type"))
	if "dirt_kind" in node:
		return String(node.get("dirt_kind"))
	if node.is_in_group("SlimeBoss"):
		return "slime_boss"
	if node.is_in_group("SlimeTrail"):
		return "slime_trail"
	return ""


func _juice(amount: float) -> void:
	if _shake != null and _shake.has_method("shake"):
		_shake.call("shake", amount)


func _emit_banner(kind: StringName, title: String) -> void:
	powerup_triggered.emit(kind, title)
