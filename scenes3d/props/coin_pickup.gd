class_name CoinPickup3D
extends Area3D

## Opsiyonel yan ödül — seviyeyi kilitlemez, Space veya yaklaşınca alınır.

signal collected(amount: int, world_pos: Vector3)

@export var value: int = 1
@export var bob_amp: float = 0.12
@export var bob_speed: float = 3.2
@export var magnet_range: float = 1.55

var _taken: bool = false
var _visual: Node3D
var _base_y: float = 0.35
var _t: float = 0.0
var _player: Node3D


func _ready() -> void:
	add_to_group("CoinPickup")
	collision_layer = 0
	collision_mask = 2  # Player
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
	if _visual != null:
		_visual.position.y = _base_y + sin(_t * bob_speed) * bob_amp
		_visual.rotation.y += delta * 2.4
	# Yakın magnet — otomatik topla
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
	var amt := maxi(1, value)
	var pos := global_position
	collected.emit(amt, pos)
	var tw := create_tween().set_parallel(true)
	if _visual != null:
		tw.tween_property(_visual, "scale", Vector3(1.4, 1.4, 1.4), 0.08)
		tw.tween_property(_visual, "position:y", _base_y + 0.8, 0.18)
		tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.2)\
			.set_delay(0.06)
	tw.chain().tween_callback(queue_free)


func _build_visual() -> void:
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.45
	shape.shape = sph
	shape.position = Vector3(0, 0.35, 0)
	add_child(shape)

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var coin := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.22
	cyl.height = 0.06
	coin.mesh = cyl
	coin.rotation_degrees = Vector3(90, 0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.2)
	mat.emission_energy_multiplier = 2.2
	mat.metallic = 0.85
	mat.roughness = 0.35
	coin.material_override = mat
	_visual.add_child(coin)

	var glow := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.28
	ring.outer_radius = 0.34
	glow.mesh = ring
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.albedo_color = Color(1.0, 0.9, 0.4, 0.35)
	gmat.emission_enabled = true
	gmat.emission = Color(1.0, 0.85, 0.3)
	gmat.emission_energy_multiplier = 1.6
	glow.material_override = gmat
	glow.position = Vector3(0, 0.02, 0)
	_visual.add_child(glow)

	var tag := Label3D.new()
	tag.text = "🪙"
	tag.font_size = 48
	tag.position = Vector3(0, 0.55, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visual.add_child(tag)

	_visual.position.y = _base_y
