class_name ClutterProp
extends Node3D

## Dağınık garaj objesi — Godot Tween / AnimationPlayer ile canlandırılabilir.
## GLB model gelince aynı node'a mesh swap + AnimationPlayer klipleri takılır.

enum IdleStyle { NONE, SWAY, FLICKER, BUZZ }

signal react_triggered
signal animation_finished(anim_name: String)
signal hit_received(strength: float)
signal destroyed
signal merged_into(host: ClutterProp)

@export var prop_id: String = "clutter"
@export var idle_style: IdleStyle = IdleStyle.SWAY
@export var hit_wobble_enabled: bool = false
@export var hits_to_destroy: int = 0
@export var can_carry: bool = false
@export var requires_scrub: bool = false
@export var scrub_radius: float = 1.35
@export var scrub_work_needed: float = 2.6
@export var max_hit_distance: float = 3.0
@export var sway_degrees: float = 1.4
@export var sway_speed: float = 1.1
@export var flicker_energy_min: float = 0.05
@export var flicker_energy_max: float = 0.55
@export var react_distance: float = 3.1
@export var react_once: bool = false
@export var player_group: StringName = &"Player"
## mop|broom|brush|spray|tweezers|"" — boş = herhangi
@export var required_tool: String = ""
@export var repair_taps_needed: int = 0 ## >0 ise smash yerine mash tamir/düzelt
@export var is_junk_food: bool = false
@export var is_painting: bool = false
@export var needs_spray_first: bool = false ## wet: önce sprey, sonra paspas

## Oda sınırı — duvardan biraz içeride (köşeye yığılmayı azaltır).
const ROOM_HALF_X := 7.7
const ROOM_HALF_Z := 5.5
const ROOM_CORNER_NUDGE := 0.55
const MAX_BOX_STACK := 5
const BOX_LAYER_H := 0.40

## Tween hedefi (genelde Pivot). Boşsa kendisi.
@export var anim_root_path: NodePath = ^"Pivot"

var _anim_root: Node3D
var _idle_tween: Tween
var _react_tween: Tween
var _player: Node3D
var _reacted: bool = false
var _flicker_targets: Array[GeometryInstance3D] = []
var _wobble_meshes: Array[MeshInstance3D] = []
var _wobble_materials: Array[ShaderMaterial] = []
var _base_rot: Vector3 = Vector3.ZERO
var _game_time: float = 0.0
var _hit_shake_tween: Tween
var _hit_count: int = 0
var _destroying: bool = false
var _in_react_range: bool = false
var _react_cooldown: float = 0.0
var _carried: bool = false
var _world_parent: Node
var _throwing: bool = false
var _throw_vel: Vector3 = Vector3.ZERO
var _throw_life: float = 0.0
var _scrub_progress: float = 0.0
var _scrub_base_scale: Vector3 = Vector3.ONE
var _scrub_ring: MeshInstance3D
var _scrub_ring_mat: StandardMaterial3D
var _repair_taps: int = 0
var _sprayed: bool = false
var _tilt_rest: Vector3 = Vector3.ZERO
var _repaired: bool = false


func _ready() -> void:
	add_to_group("ClutterProp")
	_anim_root = get_node_or_null(anim_root_path) as Node3D
	if _anim_root == null:
		_anim_root = self
	_base_rot = _anim_root.rotation
	_tilt_rest = _base_rot
	_scrub_base_scale = scale
	_cache_flicker_targets()
	_start_idle()
	if requires_scrub:
		call_deferred("_update_scrub_ring")
	call_deferred("_bind_player")
	if is_junk_food:
		add_to_group("JunkFood3D")
	if is_painting and repair_taps_needed <= 0:
		repair_taps_needed = 4


func _cache_painting_tilt() -> void:
	if _anim_root == null:
		return
	_tilt_rest = _anim_root.rotation
	_base_rot = _tilt_rest


func _bind_player() -> void:
	var nodes := get_tree().get_nodes_in_group(player_group)
	if not nodes.is_empty():
		_player = nodes[0] as Node3D


func _physics_process(delta: float) -> void:
	_game_time += delta
	if _throwing:
		_process_throw(delta)
		return
	if _carried or _destroying:
		return
	if _react_cooldown > 0.0:
		_react_cooldown = maxf(0.0, _react_cooldown - delta)
	if _player == null:
		return
	if react_once and _reacted:
		return
	var in_range := global_position.distance_to(_player.global_position) <= react_distance
	# Sadece menzile girince tetikle (her kare spam yok).
	if in_range and not _in_react_range and _react_cooldown <= 0.0:
		_play_react()
		_react_cooldown = 0.85
	_in_react_range = in_range


func is_being_carried() -> bool:
	return _carried


func is_destroying() -> bool:
	return _destroying


func set_micro_task_highlight(on: bool, style: String = "correct") -> void:
	var mark := get_node_or_null("Pivot/TaskMark") as Label3D
	if mark == null:
		mark = get_node_or_null("TaskMark") as Label3D
	var ring := get_node_or_null("TaskRing") as MeshInstance3D
	if not on:
		if mark != null:
			var tw: Variant = mark.get_meta("pulse_tween", null)
			if tw is Tween and (tw as Tween).is_valid():
				(tw as Tween).kill()
			mark.queue_free()
		if ring != null:
			ring.queue_free()
		return
	if mark != null:
		mark.queue_free()
	if ring != null:
		ring.queue_free()
	mark = Label3D.new()
	mark.name = "TaskMark"
	var col := Color(1.0, 0.85, 0.15)
	if style == "wrong":
		mark.text = "✕"
		col = Color(1.0, 0.35, 0.35)
		mark.modulate = col
	else:
		mark.text = "★"
		mark.modulate = col
	mark.font_size = 96
	mark.outline_modulate = Color(0, 0, 0, 0.95)
	mark.outline_size = 14
	# Kutunun hemen üstü — kamerada net, erişim hissi doğru
	var top_y := get_stack_top_y() if has_method("get_stack_top_y") else 0.7
	mark.position = Vector3(0.0, maxf(top_y + 0.35, 0.95), 0.0)
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.no_depth_test = true
	var pivot := get_node_or_null("Pivot")
	if pivot != null:
		pivot.add_child(mark)
	else:
		add_child(mark)
	# Yer halkası — hangi kutunun hedef olduğu net
	ring = MeshInstance3D.new()
	ring.name = "TaskRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.55
	torus.rings = 16
	torus.ring_segments = 24
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(col.r, col.g, col.b, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	ring.material_override = mat
	ring.position = Vector3(0.0, 0.04, 0.0)
	add_child(ring)
	var pulse := create_tween().set_loops()
	pulse.tween_property(mark, "scale", Vector3(1.2, 1.2, 1.2), 0.35)
	pulse.parallel().tween_property(ring, "scale", Vector3(1.12, 1.0, 1.12), 0.35)
	pulse.tween_property(mark, "scale", Vector3.ONE, 0.35)
	pulse.parallel().tween_property(ring, "scale", Vector3.ONE, 0.35)
	mark.set_meta("pulse_tween", pulse)


func is_scrub_target() -> bool:
	if needs_spray_first and not _sprayed:
		return false
	return requires_scrub and not _destroying and not _carried and not _throwing


func is_repair_target() -> bool:
	return repair_taps_needed > 0 and not _destroying and not is_junk_food and not _repaired


func is_junk() -> bool:
	return is_junk_food and not _destroying


func needs_spray() -> bool:
	return needs_spray_first and not _sprayed and not _destroying


func can_interact_with(tool_name: String) -> bool:
	if required_tool.is_empty():
		return true
	if needs_spray_first and not _sprayed:
		return tool_name == "spray"
	if needs_spray_first and _sprayed and requires_scrub:
		return tool_name == "mop"
	return tool_name == required_tool


func apply_spray() -> bool:
	if _destroying or not needs_spray_first or _sprayed:
		return false
	_sprayed = true
	requires_scrub = true
	required_tool = "mop"
	_play_react()
	_update_scrub_ring()
	var mark := Label3D.new()
	mark.text = "PASPAS"
	mark.font_size = 40
	mark.modulate = Color(0.55, 0.9, 1.0)
	mark.position = Vector3(0.0, 0.7, 0.0)
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(mark)
	var tw := create_tween()
	tw.tween_property(mark, "modulate:a", 0.0, 0.8)
	tw.tween_callback(mark.queue_free)
	return true


## Tamir / tablo düzelt — tamamlanınca true.
func apply_repair_tap() -> bool:
	if not is_repair_target():
		return false
	_repair_taps += 1
	var t := clampf(float(_repair_taps) / float(maxi(1, repair_taps_needed)), 0.0, 1.0)
	if is_painting and _anim_root != null:
		_anim_root.rotation = _tilt_rest.lerp(Vector3.ZERO, t)
		_base_rot = _anim_root.rotation
	else:
		_play_hit_shake(Vector3(1, 0, 0), 0.6 + t)
	if _repair_taps >= repair_taps_needed:
		_finish_repair()
		return true
	return false


func apply_straighten_tap() -> bool:
	return apply_repair_tap()


func consume_junk() -> void:
	if not is_junk_food or _destroying:
		return
	_destroying = true
	_kill_idle()
	_disable_collisions()
	destroyed.emit()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _finish_repair() -> void:
	if _destroying or _repaired:
		return
	# Tablo: duvarda kalsın — sadece düzelsin + objective kapansın
	if is_painting:
		_repaired = true
		if _anim_root != null:
			_anim_root.rotation = Vector3.ZERO
			_base_rot = Vector3.ZERO
			_tilt_rest = Vector3.ZERO
		set_meta("objective", false)
		_remove_yamuk_label()
		var base_s := scale
		var tw := create_tween()
		tw.tween_property(self, "scale", base_s * 1.06, 0.1)
		tw.tween_property(self, "scale", base_s, 0.18)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# Objective sayımı için (queue_free yok)
		destroyed.emit()
		return
	# TV tamir vb. — eski davranış: temizlenip kaybolur
	_destroying = true
	_kill_idle()
	_disable_collisions()
	destroyed.emit()
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(self, "scale", scale * 1.08, 0.12)
	tw2.chain().tween_property(self, "scale", Vector3(0.02, 0.02, 0.02), 0.28)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw2.chain().tween_callback(queue_free)


func _remove_yamuk_label() -> void:
	for n in get_children():
		_strip_yamuk_labels(n)


func _strip_yamuk_labels(node: Node) -> void:
	if node is Label3D:
		var lab := node as Label3D
		if lab.text == "YAMUK" or lab.text == "TAMİR":
			lab.queue_free()
			return
	for c in node.get_children():
		_strip_yamuk_labels(c)


func get_scrub_progress() -> float:
	return _scrub_progress


## Paspasla ovalama — hareket (basılı tut) veya mash tık.
## Temizlendiyse true döner.
func apply_scrub(motion_meters: float, effectiveness: float = 1.0) -> bool:
	if not is_scrub_target():
		return false
	if motion_meters < 0.004:
		return false
	var gain := motion_meters * clampf(effectiveness, 0.2, 1.5) / maxf(scrub_work_needed, 0.2)
	return _add_scrub_progress(gain)


## Sol tık / Space mash — her basışta ilerleme.
func apply_scrub_tap(effectiveness: float = 1.0) -> bool:
	if not is_scrub_target():
		return false
	# scrub_work_needed ~2.8 → ~7 tık; boss ~7.5 → ~16 tık
	var taps := clampf(scrub_work_needed / 0.42, 4.0, 20.0)
	var gain := (1.0 / taps) * clampf(effectiveness, 0.25, 1.35)
	return _add_scrub_progress(gain)


func _add_scrub_progress(gain: float) -> bool:
	_scrub_progress = minf(1.0, _scrub_progress + gain)
	_update_scrub_visual()
	if _scrub_progress >= 1.0:
		_destroy_from_hits()
		return true
	return false


func _update_scrub_visual() -> void:
	var remain := 1.0 - _scrub_progress
	scale = _scrub_base_scale * Vector3(
		lerpf(0.35, 1.0, remain),
		lerpf(0.2, 1.0, remain),
		lerpf(0.35, 1.0, remain)
	)
	for mesh in _wobble_meshes:
		if mesh == null:
			continue
		mesh.transparency = lerpf(0.0, 0.72, _scrub_progress)
	_update_scrub_ring()


func _ensure_scrub_ring() -> void:
	if _scrub_ring != null and is_instance_valid(_scrub_ring):
		return
	_scrub_ring = MeshInstance3D.new()
	_scrub_ring.name = "ScrubProgressRing"
	var torus := TorusMesh.new()
	var r := maxf(scrub_radius * 0.55, 0.55)
	torus.inner_radius = r * 0.78
	torus.outer_radius = r
	torus.rings = 14
	torus.ring_segments = 28
	_scrub_ring.mesh = torus
	_scrub_ring_mat = StandardMaterial3D.new()
	_scrub_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_scrub_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_scrub_ring_mat.no_depth_test = true
	_scrub_ring_mat.albedo_color = Color(1.0, 0.55, 0.25, 0.75)
	_scrub_ring.material_override = _scrub_ring_mat
	_scrub_ring.position = Vector3(0.0, 0.05, 0.0)
	add_child(_scrub_ring)


func _update_scrub_ring() -> void:
	if not requires_scrub:
		return
	_ensure_scrub_ring()
	if _scrub_ring == null or _scrub_ring_mat == null:
		return
	var t := clampf(_scrub_progress, 0.0, 1.0)
	var col := Color(1.0, 0.5, 0.2, 0.7).lerp(Color(0.4, 1.0, 0.55, 0.9), t)
	_scrub_ring_mat.albedo_color = col
	# Parent scale küçülürken halka dünya boyutunda kalsın
	var inv_x := _scrub_base_scale.x / maxf(scale.x, 0.05)
	var inv_y := _scrub_base_scale.y / maxf(scale.y, 0.05)
	var s := lerpf(0.88, 1.18, t)
	_scrub_ring.scale = Vector3(s * inv_x, inv_y, s * inv_x)
	_scrub_ring.visible = t < 0.98


func get_home_parent() -> Node:
	return _world_parent


func is_carryable() -> bool:
	return can_carry and not _destroying and not _carried and not _throwing


func is_box_stackable(allow_transfer: bool = false) -> bool:
	if not can_carry or requires_scrub or _destroying:
		return false
	if bool(get_meta("forbidden", false)):
		return false
	if (_throwing or _carried) and not allow_transfer:
		return false
	return String(get_meta("deliver_to", "")) == "trash"


func get_stack_units() -> int:
	return maxi(1, int(get_meta("stack_units", 1)))


func get_stack_top_y() -> float:
	return BOX_LAYER_H * float(get_stack_units())


## other bu prop'un üstüne biner; other yok edilir, birimler buraya taşınır.
func accept_stack_from(other: ClutterProp) -> bool:
	if other == null or other == self:
		return false
	if bool(get_meta("forbidden", false)) or bool(other.get_meta("forbidden", false)):
		return false
	if not is_box_stackable() or not other.is_box_stackable(true):
		return false
	if other.is_destroying() or _destroying:
		return false
	var add := other.get_stack_units()
	if get_stack_units() + add > MAX_BOX_STACK:
		return false

	var start_y := get_stack_top_y()
	_append_box_layers(add, start_y)
	set_meta("stack_units", get_stack_units() + add)
	_refresh_stack_collider()
	other.merged_into.emit(self)
	other.consume_into_stack()
	return true


func _append_box_layers(count: int, start_y: float) -> void:
	var pivot := get_node_or_null("Pivot") as Node3D
	if pivot == null:
		pivot = self
	var base_mat: Material = null
	for child in pivot.get_children():
		if child is MeshInstance3D:
			base_mat = (child as MeshInstance3D).material_override
			break
	for i in count:
		var mesh_inst := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.72, BOX_LAYER_H, 0.72)
		mesh_inst.mesh = mesh
		if base_mat != null:
			mesh_inst.material_override = base_mat.duplicate() if base_mat is ShaderMaterial else base_mat
		else:
			mesh_inst.material_override = HitWobbleMaterial.create(
				Color(0.62, 0.5, 0.34), 0.95, Color.BLACK, 0.0, 0.07)
		mesh_inst.position = Vector3(
			randf_range(-0.05, 0.05),
			start_y + BOX_LAYER_H * 0.5 + float(i) * (BOX_LAYER_H * 0.92),
			randf_range(-0.05, 0.05)
		)
		mesh_inst.rotation.y = randf_range(-0.1, 0.1)
		pivot.add_child(mesh_inst)
		register_wobble_mesh(mesh_inst)


func _refresh_stack_collider() -> void:
	for body in _find_static_bodies(self):
		for child in body.get_children():
			var shape_node := child as CollisionShape3D
			if shape_node == null:
				continue
			var h := maxf(0.45, get_stack_top_y() * 0.92)
			if shape_node.shape is CylinderShape3D:
				var cyl := shape_node.shape as CylinderShape3D
				cyl.height = h
				shape_node.position = Vector3(0.0, h * 0.5, 0.0)
			elif shape_node.shape is BoxShape3D:
				var box := shape_node.shape as BoxShape3D
				box.size = Vector3(box.size.x, h * 0.85, box.size.z)
				shape_node.position = Vector3(0.0, h * 0.42, 0.0)


## Stack birleşiminde: objective sayımını bozmadan yok et (destroyed yok).
func consume_into_stack() -> void:
	if _destroying:
		return
	_destroying = true
	_carried = false
	_throwing = false
	set_meta("objective", false)
	_kill_idle()
	_disable_collisions()
	queue_free()


func begin_carry(holder: Node3D) -> bool:
	if not is_carryable() or holder == null:
		return false
	_carried = true
	_throwing = false
	_kill_idle()
	if _hit_shake_tween != null and _hit_shake_tween.is_valid():
		_hit_shake_tween.kill()
	_disable_collisions()
	_world_parent = get_parent()
	reparent(holder, false)
	# Origin kutu tabanı — eller üstte, hold point'e yapışık
	var hold_y := -get_stack_top_y() * 0.82
	if hold_y > -0.2:
		hold_y = -0.35
	position = Vector3(0.0, hold_y, 0.0)
	rotation = Vector3.ZERO
	if _anim_root != null:
		_anim_root.rotation = _base_rot
	return true


func end_carry(world_pos: Vector3, world_yaw: float) -> void:
	if not _carried:
		return
	_carried = false
	var dest_parent := _world_parent
	if dest_parent == null or not is_instance_valid(dest_parent):
		dest_parent = get_tree().current_scene
	reparent(dest_parent, true)
	global_position = world_pos
	global_position.y = 0.0
	_clamp_in_room()
	rotation = Vector3(0.0, world_yaw, 0.0)
	_enable_collisions()
	_start_idle()
	_in_react_range = false


func _clamp_in_room() -> void:
	global_position.x = clampf(global_position.x, -ROOM_HALF_X, ROOM_HALF_X)
	global_position.z = clampf(global_position.z, -ROOM_HALF_Z, ROOM_HALF_Z)
	# Köşede sıkışmayı aç — merkeze doğru hafif it
	var ax := absf(global_position.x)
	var az := absf(global_position.z)
	if ax > ROOM_HALF_X - ROOM_CORNER_NUDGE and az > ROOM_HALF_Z - ROOM_CORNER_NUDGE:
		global_position.x = move_toward(global_position.x, 0.0, ROOM_CORNER_NUDGE * 0.65)
		global_position.z = move_toward(global_position.z, 0.0, ROOM_CORNER_NUDGE * 0.65)


func _bounce_throw_in_room() -> void:
	var bounced := false
	if global_position.x <= -ROOM_HALF_X or global_position.x >= ROOM_HALF_X:
		_throw_vel.x *= -0.48
		bounced = true
	if global_position.z <= -ROOM_HALF_Z or global_position.z >= ROOM_HALF_Z:
		_throw_vel.z *= -0.48
		bounced = true
	_clamp_in_room()
	if bounced:
		_throw_vel.x *= 0.85
		_throw_vel.z *= 0.85
		_throw_vel.y = maxf(_throw_vel.y, 1.2)


## Elde taşırken fırlat — balistik yay + inişte hasar / çöp.
func launch_throw(world_parent: Node, origin: Vector3, direction: Vector3, speed: float = 9.5, loft: float = 4.2) -> void:
	_carried = false
	_throwing = true
	_throw_life = 1.6
	_kill_idle()
	_disable_collisions()
	var dest := world_parent
	if dest == null or not is_instance_valid(dest):
		dest = get_tree().current_scene
	_world_parent = dest
	reparent(dest, true)
	global_position = origin
	var dir := direction
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = Vector3(0, 0, -1)
	dir = dir.normalized()
	_throw_vel = dir * speed + Vector3(0.0, loft, 0.0)
	rotation.y = atan2(dir.x, dir.z)


func _process_throw(delta: float) -> void:
	_throw_life -= delta
	_throw_vel.y -= 22.0 * delta
	global_position += _throw_vel * delta
	# Önce çöp/gider — duvar sekmesinden önce yutulsun
	if _try_dispose_in_flight():
		return
	if not _is_over_drop_zone():
		_bounce_throw_in_room()
	if _anim_root != null:
		_anim_root.rotation.x += delta * 12.0
		_anim_root.rotation.z += delta * 9.0
		_anim_root.rotation.y += delta * 7.0

	# Havada başka prop'a çarpma — kutuya isabet = stack dene
	for node in get_tree().get_nodes_in_group("ClutterProp"):
		var other := node as ClutterProp
		if other == null or other == self or other.is_being_carried() or other.is_destroying():
			continue
		var flat := global_position - other.global_position
		flat.y = 0.0
		if flat.length() > 1.05:
			continue
		if is_box_stackable() and other.is_box_stackable() and global_position.y > 0.35:
			if other.accept_stack_from(self):
				return
		other.apply_impact(_throw_vel, 1.35)
		_finish_throw(true)
		return

	if global_position.y <= 0.02 or _throw_life <= 0.0:
		_finish_throw(false)


func _drop_groups_for_self() -> Array[StringName]:
	var deliver: String = String(get_meta("deliver_to", ""))
	if deliver == "drain":
		return [&"DrainDrop"]
	if deliver == "trash":
		return [&"TrashDrop"]
	return [&"TrashDrop", &"DrainDrop"]


func _is_over_drop_zone() -> bool:
	for group_name in _drop_groups_for_self():
		for node in get_tree().get_nodes_in_group(group_name):
			var zone := node as Node3D
			if zone == null:
				continue
			var flat := global_position - zone.global_position
			flat.y = 0.0
			var radius := float(zone.get_meta("interact_radius", 1.15))
			if flat.length() < radius:
				return true
	return false


func _try_dispose_in_flight() -> bool:
	for group_name in _drop_groups_for_self():
		for node in get_tree().get_nodes_in_group(group_name):
			var zone := node as Node3D
			if zone == null:
				continue
			var flat := global_position - zone.global_position
			flat.y = 0.0
			var radius := float(zone.get_meta("interact_radius", 1.15))
			var max_y := float(zone.get_meta("interact_height", 1.5))
			if flat.length() < radius and global_position.y < max_y and global_position.y > -0.2:
				dispose_at_trash()
				return true
	return false


func _finish_throw(hit_prop: bool) -> void:
	_throwing = false
	_throw_vel = Vector3.ZERO
	global_position.y = 0.0
	_clamp_in_room()
	if _anim_root != null:
		_anim_root.rotation = _base_rot
	_enable_collisions()
	_start_idle()
	_in_react_range = false
	if hit_prop:
		apply_impact(Vector3(0, 0, 1), 0.85)


func dispose_at_trash() -> void:
	if _destroying:
		return
	_destroying = true
	_carried = false
	_throwing = false
	_kill_idle()
	_disable_collisions()
	destroyed.emit()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _enable_collisions() -> void:
	for body in _find_static_bodies(self):
		# Paspas sıvıları katı engel değil
		body.collision_layer = 0 if requires_scrub else 4
		body.collision_mask = 0


func register_flicker_surface(node: GeometryInstance3D) -> void:
	if node != null and node not in _flicker_targets:
		_flicker_targets.append(node)


func register_wobble_mesh(node: MeshInstance3D) -> void:
	if node == null or node in _wobble_meshes:
		return
	_wobble_meshes.append(node)
	var mat: ShaderMaterial = node.material_override as ShaderMaterial
	if mat != null and mat.shader != null:
		_wobble_materials.append(mat)


## Karanlık seviye: maske içinde emission glow ile görünür kıl.
func set_vis_mask_revealed(revealed: bool) -> void:
	visible = revealed
	for mesh in _wobble_meshes:
		if mesh == null or not is_instance_valid(mesh):
			continue
		mesh.transparency = 0.0 if revealed else 1.0
	for mat in _wobble_materials:
		if mat == null:
			continue
		if revealed:
			mat.set_shader_parameter("emission_energy", 0.85)
			mat.set_shader_parameter("emission_color", Vector3(0.55, 0.85, 1.0))
			mat.set_shader_parameter("ambient_boost", 0.35)
		else:
			mat.set_shader_parameter("emission_energy", 0.0)
			mat.set_shader_parameter("emission_color", Vector3(0.0, 0.0, 0.0))
			mat.set_shader_parameter("ambient_boost", 0.12)


func clear_vis_mask() -> void:
	visible = true
	for mesh in _wobble_meshes:
		if mesh == null or not is_instance_valid(mesh):
			continue
		mesh.transparency = 0.0
	for mat in _wobble_materials:
		if mat == null:
			continue
		mat.set_shader_parameter("emission_energy", 0.0)
		mat.set_shader_parameter("emission_color", Vector3(0.0, 0.0, 0.0))
		mat.set_shader_parameter("ambient_boost", 0.2)


## Kürek / paspas vuruşu — shader vertex wobble + kısa sarsıntı.
func apply_hit(hit_pos: Vector3, hit_dir: Vector3, strength: float = 1.0, tool: String = "mop") -> void:
	if _destroying or _carried or _throwing:
		return
	if is_junk_food or repair_taps_needed > 0:
		_play_react()
		return
	if needs_spray_first and not _sprayed:
		_play_react()
		return
	# Scrub lekeleri tek vuruşla bitmez.
	if requires_scrub:
		_play_react()
		return
	if not required_tool.is_empty() and tool != required_tool:
		_play_react()
		return
	# Yatay mesafe — yükseklik farkı vuruşu bozmasın; biraz cömert tolerans
	if _player != null:
		var flat := global_position - _player.global_position
		flat.y = 0.0
		if flat.length() > max_hit_distance + 0.35:
			return
	# Kutular paspasla temizlenemez (sadece taşı/çöp).
	if tool == "mop" and bool(get_meta("immune_mop", false)):
		_play_react()
		return
	_apply_hit_fx(hit_dir, strength)


## Fırlatma / çarpışma — mesafe kontrolü yok.
func apply_impact(hit_dir: Vector3, strength: float = 1.2) -> void:
	if _destroying or _carried or _throwing:
		return
	_apply_hit_fx(hit_dir, strength)


func _apply_hit_fx(hit_dir: Vector3, strength: float) -> void:
	if not hit_wobble_enabled and hits_to_destroy <= 0:
		_play_react()
		return

	hit_received.emit(strength)

	if hit_wobble_enabled:
		for mat in _wobble_materials:
			HitWobbleMaterial.apply_hit(mat, hit_dir, _game_time, strength)
		_play_hit_shake(hit_dir, strength)
		if idle_style == IdleStyle.FLICKER or idle_style == IdleStyle.BUZZ:
			_set_flicker_energy(minf(flicker_energy_max * 2.5, 1.4))
			if _idle_tween != null and _idle_tween.is_valid():
				_idle_tween.kill()
			var t := create_tween()
			t.tween_method(_set_flicker_energy, flicker_energy_max * 2.0, flicker_energy_min, 0.45)

	_register_hit(strength)


func get_hits_remaining() -> int:
	if hits_to_destroy <= 0:
		return -1
	return maxi(hits_to_destroy - _hit_count, 0)


func _register_hit(strength: float) -> void:
	if hits_to_destroy <= 0:
		return
	var damage := 1 if strength < 1.25 else 2
	_hit_count += damage
	if _hit_count >= hits_to_destroy:
		_destroy_from_hits()


func _destroy_from_hits() -> void:
	if _destroying:
		return
	_destroying = true
	_kill_idle()
	if _hit_shake_tween != null and _hit_shake_tween.is_valid():
		_hit_shake_tween.kill()
	_disable_collisions()
	destroyed.emit()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_anim_root, "scale", Vector3(0.01, 0.01, 0.01), 0.32)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(_anim_root, "rotation", _anim_root.rotation + Vector3(0.3, 0.6, 0.2), 0.28)
	tw.chain().tween_callback(queue_free)


func _disable_collisions() -> void:
	for body in _find_static_bodies(self):
		body.collision_layer = 0
		body.collision_mask = 0


func _find_static_bodies(root: Node) -> Array[StaticBody3D]:
	var out: Array[StaticBody3D] = []
	if root is StaticBody3D:
		out.append(root)
	for child in root.get_children():
		out.append_array(_find_static_bodies(child))
	return out


func _play_hit_shake(hit_dir: Vector3, strength: float) -> void:
	if _hit_shake_tween != null and _hit_shake_tween.is_valid():
		_hit_shake_tween.kill()
	var dir := hit_dir
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		dir = Vector3(1, 0, 0)
	dir = dir.normalized()
	var tilt := deg_to_rad(5.0 * strength)
	var axis_tilt := Vector3(-dir.z, 0.0, dir.x) * tilt
	_hit_shake_tween = create_tween()
	_hit_shake_tween.tween_property(_anim_root, "rotation", _base_rot + axis_tilt, 0.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hit_shake_tween.tween_property(_anim_root, "rotation", _base_rot, 0.28)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func play_custom_animation(anim_name: String) -> void:
	var player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player == null or not player.has_animation(anim_name):
		return
	player.play(anim_name)
	if not player.animation_finished.is_connected(_on_custom_anim_finished):
		player.animation_finished.connect(_on_custom_anim_finished)


func _on_custom_anim_finished(anim_name: StringName) -> void:
	animation_finished.emit(String(anim_name))


func _start_idle() -> void:
	_kill_idle()
	match idle_style:
		IdleStyle.SWAY:
			_idle_sway()
		IdleStyle.FLICKER:
			_idle_flicker()
		IdleStyle.BUZZ:
			_idle_buzz()
		_:
			pass


func _idle_sway() -> void:
	_idle_tween = create_tween().set_loops()
	var rad := deg_to_rad(sway_degrees)
	_idle_tween.tween_property(_anim_root, "rotation:z", _base_rot.z + rad, 1.1 / sway_speed)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(_anim_root, "rotation:z", _base_rot.z - rad, 1.1 / sway_speed)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _idle_buzz() -> void:
	_idle_tween = create_tween().set_loops()
	var rad := deg_to_rad(sway_degrees * 0.35)
	_idle_tween.tween_property(_anim_root, "rotation:y", _base_rot.y + rad, 0.06)\
		.set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(_anim_root, "rotation:y", _base_rot.y - rad, 0.06)\
		.set_trans(Tween.TRANS_SINE)


func _idle_flicker() -> void:
	if _flicker_targets.is_empty():
		return
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_method(_set_flicker_energy, flicker_energy_min, flicker_energy_max, randf_range(0.07, 0.16))
	_idle_tween.tween_method(_set_flicker_energy, flicker_energy_max, flicker_energy_min, randf_range(0.05, 0.14))


func _set_flicker_energy(energy: float) -> void:
	for surf in _flicker_targets:
		var mat: Material = surf.get_active_material(0)
		if mat is ShaderMaterial:
			(mat as ShaderMaterial).set_shader_parameter("emission_energy", energy)
		elif mat is StandardMaterial3D:
			(mat as StandardMaterial3D).emission_energy_multiplier = energy


func _play_react() -> void:
	if react_once and _reacted:
		return
	_reacted = true
	react_triggered.emit()
	if _react_tween != null and _react_tween.is_valid():
		_react_tween.kill()
	_react_tween = create_tween().set_parallel(true)
	match idle_style:
		IdleStyle.SWAY, IdleStyle.NONE:
			_react_tween.tween_property(_anim_root, "rotation:z", _base_rot.z + deg_to_rad(4.0), 0.08)
			_react_tween.chain().tween_property(_anim_root, "rotation:z", _base_rot.z, 0.22)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		IdleStyle.FLICKER:
			for surf in _flicker_targets:
				var mat: Material = surf.get_active_material(0)
				if mat is ShaderMaterial:
					var sm := mat as ShaderMaterial
					_react_tween.tween_method(
						func(v: float) -> void: sm.set_shader_parameter("emission_energy", v),
						flicker_energy_min, flicker_energy_max * 2.2, 0.08)
					_react_tween.tween_method(
						func(v: float) -> void: sm.set_shader_parameter("emission_energy", v),
						flicker_energy_max * 2.2, flicker_energy_min, 0.35)
				elif mat is StandardMaterial3D:
					var std := mat as StandardMaterial3D
					_react_tween.tween_property(std, "emission_energy_multiplier", 1.2, 0.05)
					_react_tween.tween_property(std, "emission_energy_multiplier", flicker_energy_min, 0.35)
		IdleStyle.BUZZ:
			_react_tween.tween_property(_anim_root, "rotation:x", _base_rot.x + deg_to_rad(6.0), 0.04)
			_react_tween.chain().tween_property(_anim_root, "rotation:x", _base_rot.x, 0.18)\
				.set_trans(Tween.TRANS_BOUNCE)


func _cache_flicker_targets() -> void:
	if not _flicker_targets.is_empty():
		return
	for node in _find_children(_anim_root, "FlickerSurface"):
		if node is GeometryInstance3D:
			register_flicker_surface(node)


func _find_children(root: Node, group_name: String) -> Array:
	var out: Array = []
	if root.is_in_group(group_name):
		out.append(root)
	for c in root.get_children():
		out.append_array(_find_children(c, group_name))
	return out


func _kill_idle() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null
