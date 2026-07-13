class_name MoldSpawner
extends Node

@export var room_manager_path: NodePath = ^"../RoomManager"
@export var tempo_path: NodePath = ^"../TempoDirector"
@export var max_spread_per_room: int = 6
@export var mold_hitbox: Vector2 = Vector2(95, 80)
@export var child_spread_time: float = 6.5      # yayılan küfün tekrar yayılma süresi
@export var min_gap: float = 120.0              # diğer objelerle min mesafe

# Climax (son sprint): küf daha hızlı yayılır, tavan yükselir.
@export var climax_spread_mult: float = 2.4
@export var climax_extra_spread: int = 3

# İzometrik oda yüzeyleri (RoomSpawnBounds ile aynı).
@export var spread_radius: Vector2 = Vector2(180, 150)

@export var mold_color: Color = Color(0.4, 0.55, 0.3, 1.0)

var _room_manager: Node
var _tempo: TempoDirector
var _spread_count: int = 0


func _ready() -> void:
	_room_manager = get_node_or_null(room_manager_path)
	_tempo = get_node_or_null(tempo_path) as TempoDirector
	if _room_manager != null and _room_manager.has_signal("room_transition_finished"):
		_room_manager.room_transition_finished.connect(_on_room_changed)
	call_deferred("_connect_existing")


func _process(_delta: float) -> void:
	# Climax'ta aktif küflerin yayılma hızını yükselt.
	if _tempo == null:
		return
	var scale := lerpf(1.0, climax_spread_mult, _tempo.get_intensity())
	for node in get_tree().get_nodes_in_group("Cleanable"):
		if node is CleanableObject and node.spreads and not node.is_cleaned():
			node.spread_speed_scale = scale


func _connect_existing() -> void:
	for node in get_tree().get_nodes_in_group("Cleanable"):
		_try_connect(node)


func _try_connect(node: Node) -> void:
	if node is CleanableObject and node.spreads:
		if not node.spread_triggered.is_connected(_on_spread):
			node.spread_triggered.connect(_on_spread)


func _on_room_changed() -> void:
	_spread_count = 0


func _on_spread(origin: Vector2) -> void:
	if _room_manager == null:
		return
	if _room_manager.has_method("is_transitioning") and _room_manager.is_transitioning():
		return
	# Sadece ekranda görünen (aktif odadaki) küfler yayılabilir.
	if origin.y < 0.0 or origin.y > 1080.0 or origin.x < 0.0 or origin.x > 1920.0:
		return
	var cap := max_spread_per_room
	if _tempo != null:
		cap += int(round(_tempo.get_intensity() * climax_extra_spread))
	if _spread_count >= cap:
		return

	var room := _room_manager.get_current_room() as Node2D
	if room == null:
		return

	var spot := _find_free_spot(origin)
	if spot == Vector2.INF:
		return

	_spawn_mold(room, spot)
	_spread_count += 1

	if _room_manager.has_method("emit_current_objective"):
		_room_manager.emit_current_objective()


func _find_free_spot(origin: Vector2) -> Vector2:
	var placed: Array[Vector2] = []
	for node in get_tree().get_nodes_in_group("Cleanable"):
		if node is CleanableObject and not node.is_cleaned():
			placed.append(node.global_position)
	return RoomSpawnBounds.random_near(origin, spread_radius, placed, min_gap, 14)


func _spawn_mold(room: Node2D, world_pos: Vector2) -> void:
	var mold := CleanableObject.new()
	mold.requires_scrub = true
	mold.spreads = true
	mold.spread_time = child_spread_time
	mold.hitbox_size = mold_hitbox
	mold.modulate = mold_color

	SpriteVisualHelper.add_dirt_sprite(mold, "mold", mold_color)

	room.add_child(mold)
	mold.global_position = world_pos
	mold.z_index = RoomSpawnBounds.depth_z(world_pos.y)
	mold.spread_triggered.connect(_on_spread)

	# Doğuş animasyonu
	mold.scale = Vector2(0.1, 0.1)
	var tween := mold.create_tween()
	tween.tween_property(mold, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
