class_name JunkFoodSpawner
extends Node

@export var world_layer_path: NodePath = ^"../WorldLayer"
@export var room_manager_path: NodePath = ^"../RoomManager"

@export var spawn_interval_min: float = 2.2
@export var spawn_interval_max: float = 4.0
@export var junk_lifetime: float = 3.2
@export var max_concurrent: int = 2
@export var stress_penalty: float = 20.0
@export var stamina_reward: float = 32.0

# Ekranın (1920x1080) güvenli spawn alanı; kenarlardan içeride.
@export var area_min: Vector2 = Vector2(300, 240)
@export var area_max: Vector2 = Vector2(1600, 840)

@export var emojis: Array[String] = ["🍟", "🥤", "🍔", "🍩", "🍫", "🍰", "🌭", "🍦", "🍕"]

var _world: Node2D
var _room_manager: Node
var _timer: float = 0.0
var _next_spawn: float = 0.0


func _ready() -> void:
	_world = get_node(world_layer_path) as Node2D
	_room_manager = get_node_or_null(room_manager_path)
	_next_spawn = randf_range(spawn_interval_min, spawn_interval_max)

	if _room_manager != null and _room_manager.has_signal("room_transition_started"):
		_room_manager.room_transition_started.connect(_clear_all_junk)


func _process(delta: float) -> void:
	if _is_blocked():
		return

	_timer += delta
	if _timer < _next_spawn:
		return

	_timer = 0.0
	_next_spawn = randf_range(spawn_interval_min, spawn_interval_max)

	if _count_active() < max_concurrent:
		_spawn_one()


func _is_blocked() -> bool:
	if _world == null:
		return true
	if _room_manager != null and _room_manager.is_transitioning():
		return true
	return false


func _count_active() -> int:
	return get_tree().get_nodes_in_group("JunkFood").size()


func _spawn_one() -> void:
	var junk := JunkFoodObject.new()
	junk.lifetime = junk_lifetime
	junk.stress_penalty = stress_penalty
	junk.stamina_reward = stamina_reward

	var label := Label.new()
	label.text = str(emojis.pick_random())
	label.add_theme_font_size_override("font_size", 44)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(56, 56)
	label.position = Vector2(-28, -30)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	junk.add_child(label)

	junk.position = Vector2(
		randf_range(area_min.x, area_max.x),
		randf_range(area_min.y, area_max.y)
	)
	_world.add_child(junk)


func _clear_all_junk() -> void:
	for node in get_tree().get_nodes_in_group("JunkFood"):
		if node is JunkFoodObject and node.is_active():
			node.expire()
