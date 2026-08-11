class_name HeartPickup3D
extends Area3D

## Seviye içi can pickup — nadir yan ödül.

signal collected(world_pos: Vector3)

@export var bob_amp: float = 0.14
@export var bob_speed: float = 2.8
@export var magnet_range: float = 1.7

var _taken: bool = false
var _visual: Node3D
var _base_y: float = 0.4
var _t: float = 0.0
var _player: Node3D


func _ready() -> void:
	add_to_group("HeartPickup")
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
	if _visual != null:
		_visual.position.y = _base_y + sin(_t * bob_speed) * bob_amp
		_visual.rotation.y += delta * 2.0
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
	var pos := global_position
	collected.emit(pos)
	var tw := create_tween().set_parallel(true)
	if _visual != null:
		tw.tween_property(_visual, "scale", Vector3(1.5, 1.5, 1.5), 0.08)
		tw.tween_property(_visual, "position:y", _base_y + 0.9, 0.2)
		tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.22)\
			.set_delay(0.05)
	tw.chain().tween_callback(queue_free)


func _build_visual() -> void:
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.42
	shape.shape = sph
	shape.position = Vector3(0, 0.4, 0)
	add_child(shape)

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	core.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.25, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.4)
	mat.emission_energy_multiplier = 1.8
	core.material_override = mat
	_visual.add_child(core)

	var glow := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.3
	ring.outer_radius = 0.36
	glow.mesh = ring
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.albedo_color = Color(1.0, 0.45, 0.55, 0.4)
	gmat.emission_enabled = true
	gmat.emission = Color(1.0, 0.4, 0.5)
	gmat.emission_energy_multiplier = 1.4
	glow.material_override = gmat
	_visual.add_child(glow)

	var tag := Label3D.new()
	tag.text = "❤️"
	tag.font_size = 56
	tag.position = Vector3(0, 0.55, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visual.add_child(tag)

	_visual.position.y = _base_y
