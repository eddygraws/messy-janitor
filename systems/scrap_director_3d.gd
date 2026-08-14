class_name ScrapDirector3D
extends Node

## Clean-drop + secret-condition scrap'leri yönetir.

signal scrap_found(scrap_id: String, is_new: bool, world_pos: Vector3)

const DROP_COOLDOWN := 2.8
const MAX_DROPS_PER_LEVEL := 2

var _collection: ScrapCollection3D
var _player: Node
var _world: Node3D
var _level_drops: int = 0
var _drop_cd: float = 0.0
var _pending_secret: Dictionary = {} ## secret_id -> true (bu run'da tetiklendi, pickup bekliyor)


func setup(collection: ScrapCollection3D, player: Node, world: Node3D) -> void:
	_collection = collection
	_player = player
	_world = world


func reset_level() -> void:
	_level_drops = 0
	_drop_cd = 0.0
	_pending_secret.clear()
	_clear_pickups()


func _process(delta: float) -> void:
	_drop_cd = maxf(0.0, _drop_cd - delta)


func _clear_pickups() -> void:
	if _world == null:
		return
	for n in get_tree().get_nodes_in_group("ScrapPickup"):
		if n is Node and (n as Node).is_inside_tree():
			(n as Node).queue_free()


## Tip 1: kir temizlenince nadir kutu
func on_prop_cleaned(prop_id: String, world_pos: Vector3) -> void:
	if _collection == null or _drop_cd > 0.0 or _level_drops >= MAX_DROPS_PER_LEVEL:
		return
	var candidates := ScrapCatalog.clean_candidates_for(prop_id)
	candidates = candidates.filter(func(s: Dictionary) -> bool:
		return not _collection.has_scrap(String(s.get("id", "")))
	)
	if candidates.is_empty():
		return
	# Ağırlıklı roll
	var best: Dictionary = {}
	var best_roll := 0.0
	for s in candidates:
		var ch := float(s.get("chance", 0.05))
		var roll := randf()
		if roll <= ch and (best.is_empty() or roll > best_roll):
			best = s
			best_roll = roll
	if best.is_empty():
		return
	_spawn_pickup(String(best.get("id", "")), world_pos, true)


## Tip 2: gizli koşul
func try_secret(secret_id: String, world_pos: Vector3) -> void:
	if _collection == null or secret_id.is_empty():
		return
	var scrap := ScrapCatalog.secret_scrap(secret_id)
	if scrap.is_empty():
		return
	var sid := String(scrap.get("id", ""))
	if _collection.has_scrap(sid):
		return
	if bool(_pending_secret.get(secret_id, false)):
		return
	_pending_secret[secret_id] = true
	_spawn_pickup(sid, world_pos, false)


func _spawn_pickup(scrap_id: String, world_pos: Vector3, counts_toward_level_cap: bool = true) -> void:
	if scrap_id.is_empty() or _world == null:
		return
	var info := ScrapCatalog.by_id(scrap_id)
	if info.is_empty():
		return
	var ScrapScript := preload("res://scenes3d/props/scrap_pickup.gd")
	var pickup: ScrapPickup3D = ScrapScript.new()
	pickup.name = "Scrap_%s" % scrap_id
	pickup.setup(scrap_id, String(info.get("icon", "📦")), Color(0.5, 0.58, 0.68))
	var pos := world_pos
	pos.y = 0.05
	# Hafif saçılma — drop noktası net belli olmasın
	pos.x += randf_range(-0.35, 0.35)
	pos.z += randf_range(-0.35, 0.35)
	pickup.position = pos
	_world.add_child(pickup)
	pickup.collected.connect(_on_pickup_collected)
	if counts_toward_level_cap:
		_level_drops += 1
		_drop_cd = DROP_COOLDOWN


func _on_pickup_collected(scrap_id: String, world_pos: Vector3) -> void:
	if _collection == null:
		return
	var is_new := _collection.unlock(scrap_id)
	scrap_found.emit(scrap_id, is_new, world_pos)
