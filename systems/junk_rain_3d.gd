class_name JunkRain3D
extends Node

## Gökten abur cubur yağmuru — Space ile ye: puan + şişme + sugar crash.

signal junk_landed(world_pos: Vector3)
signal junk_spawned(node: Node3D)

const ClutterPropScript := preload("res://scenes3d/props/clutter_prop.gd")

@export var spawn_interval_min: float = 5.5
@export var spawn_interval_max: float = 9.0
@export var max_concurrent: int = 2
@export var drop_height: float = 6.5
@export var warn_time: float = 0.85
@export var drop_time: float = 0.28
@export var junk_lifetime: float = 9.0

var _world: Node3D
var _tempo: TempoPhaseDirector
var _active: bool = false
var _timer: float = 0.0
var _next: float = 4.0
var _rng := RandomNumberGenerator.new()

const EMOJIS: Array[String] = ["🍔", "🍟", "🍩", "🥤", "🌭", "🍕"]
const COLORS: Array[Color] = [
	Color(0.85, 0.45, 0.2),
	Color(0.95, 0.75, 0.25),
	Color(0.9, 0.55, 0.65),
	Color(0.35, 0.65, 0.95),
	Color(0.8, 0.35, 0.25),
	Color(0.95, 0.35, 0.3),
]


func setup(world: Node3D, tempo: TempoPhaseDirector = null) -> void:
	_world = world
	_tempo = tempo
	_rng.randomize()


func start_session() -> void:
	_active = true
	_timer = 0.0
	_next = _rng.randf_range(spawn_interval_min * 0.6, spawn_interval_max * 0.75)


func stop_session() -> void:
	_active = false
	_clear_all()


func _process(delta: float) -> void:
	if not _active or _world == null:
		return
	_timer += delta
	var intensity := 0.0
	if _tempo != null and _tempo.is_running():
		var ph: int = _tempo.get_phase()
		if ph >= TempoPhaseDirector.PHASE_FINALE:
			intensity = 0.85
		elif ph >= TempoPhaseDirector.PHASE_RAMP:
			intensity = 0.5
		else:
			intensity = 0.15
	var wait := _next * lerpf(1.0, 0.55, intensity)
	if _timer < wait:
		return
	_timer = 0.0
	_next = _rng.randf_range(spawn_interval_min, spawn_interval_max)
	var cap := max_concurrent + (1 if intensity > 0.7 else 0)
	if _count_active() >= cap:
		return
	_begin_drop()


func _count_active() -> int:
	return get_tree().get_nodes_in_group("JunkFood3D").size()


func _clear_all() -> void:
	for n in get_tree().get_nodes_in_group("JunkFood3D"):
		if n is Node and is_instance_valid(n):
			(n as Node).queue_free()
	if _world == null:
		return
	for c in _world.get_children():
		if String(c.name).begins_with("JunkWarn"):
			c.queue_free()


func _begin_drop() -> void:
	var center := Vector3(
		_rng.randf_range(-5.5, 5.5),
		0.0,
		_rng.randf_range(-3.8, 3.2)
	)
	var warn := Node3D.new()
	warn.name = "JunkWarn"
	warn.position = center
	_world.add_child(warn)

	var shadow := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.55
	cyl.height = 0.04
	shadow.mesh = cyl
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.9, 0.55, 0.15, 0.45)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = smat
	shadow.position = Vector3(0, 0.03, 0)
	warn.add_child(shadow)

	var emoji := EMOJIS[_rng.randi_range(0, EMOJIS.size() - 1)]
	var label := Label3D.new()
	label.text = emoji
	label.font_size = 64
	label.position = Vector3(0, 1.2, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	warn.add_child(label)

	var tw := warn.create_tween()
	tw.tween_interval(warn_time)
	tw.tween_callback(func() -> void:
		if is_instance_valid(warn):
			warn.queue_free()
		_spawn_junk_at(center, emoji)
	)


func _spawn_junk_at(center: Vector3, emoji: String) -> void:
	if _world == null or not _active:
		return
	var idx := EMOJIS.find(emoji)
	if idx < 0:
		idx = 0
	var root: ClutterProp = ClutterPropScript.new()
	root.name = "JunkFood"
	root.prop_id = "junk"
	root.is_junk_food = true
	root.can_carry = false
	root.hits_to_destroy = 0
	root.hit_wobble_enabled = true
	root.max_hit_distance = 2.8
	root.react_distance = 2.5
	root.set_meta("objective", false)
	root.position = center + Vector3(0, drop_height, 0)
	_world.add_child(root)

	var pivot := Node3D.new()
	pivot.name = "Pivot"
	root.add_child(pivot)

	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	pivot.add_child(body)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.35, 0.55)
	mesh.mesh = box
	mesh.material_override = HitWobbleMaterial.create(
		COLORS[idx % COLORS.size()], 0.9, Color.BLACK, 0.0, 0.08
	)
	mesh.position = Vector3(0, 0.2, 0)
	pivot.add_child(mesh)
	root.register_wobble_mesh(mesh)

	var shape := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.55, 0.4, 0.55)
	shape.shape = sh
	shape.position = Vector3(0, 0.2, 0)
	body.add_child(shape)

	var tag := Label3D.new()
	tag.text = emoji
	tag.font_size = 56
	tag.position = Vector3(0, 0.65, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pivot.add_child(tag)

	var land := root.create_tween()
	land.tween_property(root, "position:y", 0.05, drop_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	land.tween_callback(func() -> void:
		junk_landed.emit(root.global_position)
	)
	# Ömür — yenmezse kaybolur
	var life := root.create_tween()
	life.tween_interval(junk_lifetime)
	life.tween_callback(func() -> void:
		if is_instance_valid(root) and not root.is_destroying():
			root.queue_free()
	)
	junk_spawned.emit(root)
