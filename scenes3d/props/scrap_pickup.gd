class_name ScrapPickup3D
extends Area3D

## Sessiz easter egg pickup — coin kadar bağırmaz.

signal collected(scrap_id: String, world_pos: Vector3)

@export var scrap_id: String = ""
@export var bob_amp: float = 0.06
@export var bob_speed: float = 2.1
@export var magnet_range: float = 1.35

var _taken: bool = false
var _visual: Node3D
var _icon_label: Label3D
var _t: float = 0.0
var _player: Node3D
var _icon: String = "📦"
var _accent: Color = Color(0.55, 0.62, 0.7)


func setup(id: String, icon: String = "📦", accent: Color = Color(0.55, 0.62, 0.7)) -> void:
	scrap_id = id
	_icon = icon
	_accent = accent
	if _icon_label != null:
		_icon_label.text = _icon
	if _visual != null:
		_tint_meshes()


func _ready() -> void:
	add_to_group("ScrapPickup")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	_build_visual()
	_t = randf() * TAU
	call_deferred("_bind_player")


func _bind_player() -> void:
	var nodes := get_tree().get_nodes_in_group("Player")
	if not nodes.is_empty():
		_player = nodes[0] as Node3D


func _physics_process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	# Yer görseli yok — sadece magnet / çarpışma ile alınır; kutu elde scrap hold’da çıkar.
	if _player != null and is_instance_valid(_player):
		var flat := _player.global_position - global_position
		flat.y = 0.0
		if flat.length() <= magnet_range:
			collect()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		collect()


func collect() -> void:
	if _taken:
		return
	_taken = true
	monitoring = false
	set_physics_process(false)
	var pos := global_position
	collected.emit(scrap_id, pos)
	# Map'ten hemen kaybolur — elde / UI devam eder
	queue_free()


func _build_visual() -> void:
	## Görünmez hitbox — gri kutu sadece play_scrap_hold sırasında elde.
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.42
	shape.shape = sph
	shape.position = Vector3(0, 0.28, 0)
	add_child(shape)
	_visual = null
	_icon_label = null


func _tint_meshes() -> void:
	if _visual == null:
		return
	for c in _visual.get_children():
		var mi := c as MeshInstance3D
		if mi != null and mi.name != "Tape":
			mi.material_override = _mat(_accent.darkened(0.25), 0.15)


func _mat(albedo: Color, emission_e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = 0.85
	if emission_e > 0.0:
		m.emission_enabled = true
		m.emission = albedo.lightened(0.2)
		m.emission_energy_multiplier = emission_e
	return m
