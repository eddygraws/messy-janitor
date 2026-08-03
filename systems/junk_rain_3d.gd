class_name JunkRain3D
extends Node

## Gökten abur cubur yağmuru — Space ile ye: puan + şişme + 3'te power-up.

signal junk_landed(world_pos: Vector3)
signal junk_spawned(node: Node3D)

const ClutterPropScript := preload("res://scenes3d/props/clutter_prop.gd")

@export var spawn_interval_min: float = 9.5
@export var spawn_interval_max: float = 15.0
@export var max_concurrent: int = 1
@export var drop_height: float = 6.5
@export var warn_time: float = 0.85
@export var drop_time: float = 0.28
@export var junk_lifetime: float = 11.0

var _world: Node3D
var _tempo: TempoPhaseDirector
var _active: bool = false
var _timer: float = 0.0
var _next: float = 6.0
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
	_next = _rng.randf_range(spawn_interval_min * 0.7, spawn_interval_max * 0.85)


func stop_session() -> void:
	_active = false
	_clear_all()


## Tutorial: hemen birkaç abur cubur düşür.
func spawn_guaranteed(count: int = 3) -> void:
	if _world == null:
		return
	for i in count:
		var delay := 0.35 + float(i) * 0.55
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if _active:
				_begin_drop()
		)


func _process(delta: float) -> void:
	if not _active or _world == null:
		return
	_timer += delta
	var intensity := 0.0
	if _tempo != null and _tempo.is_running():
		var ph: int = _tempo.get_phase()
		if ph >= TempoPhaseDirector.PHASE_FINALE:
			intensity = 0.45
		elif ph >= TempoPhaseDirector.PHASE_RAMP:
			intensity = 0.25
		else:
			intensity = 0.05
	var wait := _next * lerpf(1.0, 0.78, intensity)
	if _timer < wait:
		return
	_timer = 0.0
	_next = _rng.randf_range(spawn_interval_min, spawn_interval_max)
	var cap := max_concurrent + (1 if intensity > 0.4 else 0)
	if _count_active() >= cap:
		return
	_begin_drop()


func _count_active() -> int:
	return get_tree().get_nodes_in_group("JunkFood3D").size()


func _clear_all() -> void:
	for n in get_tree().get_nodes_in_group("JunkFood3D"):
		if is_instance_valid(n):
			n.queue_free()


func _begin_drop() -> void:
	if _world == null:
		return
	var idx := _rng.randi() % EMOJIS.size()
	var emoji: String = EMOJIS[idx]
	var color: Color = COLORS[idx]
	var center := Vector3(
		_rng.randf_range(-5.5, 5.5),
		0.0,
		_rng.randf_range(-3.2, 2.8)
	)
	var zone := Node3D.new()
	zone.name = "JunkWarn"
	zone.position = center
	_world.add_child(zone)
	var shadow := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.55
	cyl.height = 0.04
	shadow.mesh = cyl
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(color.r, color.g, color.b, 0.35)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = smat
	shadow.position = Vector3(0, 0.03, 0)
	zone.add_child(shadow)
	var label := Label3D.new()
	label.text = emoji
	label.font_size = 96
	label.position = Vector3(0, drop_height, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	zone.add_child(label)
	var tw := zone.create_tween()
	tw.tween_interval(warn_time)
	tw.tween_property(label, "position:y", 0.4, drop_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if is_instance_valid(zone):
			zone.queue_free()
		_spawn_junk_at(center, emoji)
	)


func _spawn_junk_at(center: Vector3, emoji: String) -> void:
	if _world == null:
		return
	var root: ClutterProp = ClutterPropScript.new()
	root.name = "JunkFood"
	root.prop_id = "junk"
	root.is_junk_food = true
	root.can_carry = false
	root.hits_to_destroy = 0
	root.hit_wobble_enabled = true
	root.max_hit_distance = 2.4
	root.react_distance = 2.2
	root.position = center
	root.set_meta("objective", false)
	_world.add_child(root)

	var pivot := Node3D.new()
	pivot.name = "Pivot"
	root.add_child(pivot)

	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	pivot.add_child(body)

	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.38
	sphere.height = 0.7
	mesh_inst.mesh = sphere
	var col_i := 0
	for i in EMOJIS.size():
		if EMOJIS[i] == emoji:
			col_i = i
			break
	mesh_inst.material_override = HitWobbleMaterial.create(
		COLORS[col_i], 0.9, COLORS[col_i].lightened(0.25), 0.25, 0.14
	)
	mesh_inst.position = Vector3(0, 0.35, 0)
	pivot.add_child(mesh_inst)
	root.register_wobble_mesh(mesh_inst)

	var tag := Label3D.new()
	tag.text = emoji
	tag.font_size = 72
	tag.position = Vector3(0, 0.95, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pivot.add_child(tag)

	var hint := Label3D.new()
	hint.text = "YE"
	hint.font_size = 36
	hint.modulate = Color(1.0, 0.9, 0.4)
	hint.position = Vector3(0, 1.25, 0)
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pivot.add_child(hint)

	junk_landed.emit(root.global_position)
	var life := root.create_tween()
	life.tween_interval(junk_lifetime)
	life.tween_callback(func() -> void:
		if is_instance_valid(root) and not root.is_destroying():
			root.queue_free()
	)
	junk_spawned.emit(root)
