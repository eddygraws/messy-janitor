class_name JanitorVisual
extends Node3D

## Mixamo janitor mesh + anim kütüphanesi.
## Zorunlu: idle, run, carry, hit
## Opsiyonel dosyalar (ekleyince otomatik bağlanır):
##   anim_carry_walk.fbx  — kutu taşırken yürüme
##   anim_dance.fbx       — G dans
##   dash.fbx             — Shift dash

const HitWobbleMaterialScript := preload("res://scenes3d/props/hit_wobble_material.gd")
const CHAR_SCENE := preload("res://assets/characters/janitor/janitor-tpose.fbx")

## Zorunlu animler (preload)
const ANIM_REQUIRED := {
	&"idle": "res://assets/characters/janitor/anim_idle.fbx",
	&"run": "res://assets/characters/janitor/anim-run.fbx",
	&"carry": "res://assets/characters/janitor/anim-carry-idle.fbx",
	&"hit": "res://assets/characters/janitor/anim_hit.fbx",
}

## Opsiyonel — ilk bulunan path kullanılır
const ANIM_OPTIONAL := {
	&"carry_walk": [
		"res://assets/characters/janitor/anim_carry_walk.fbx",
		"res://assets/characters/janitor/anim-carry-walk.fbx",
	],
	&"dance": [
		"res://assets/characters/janitor/anim_dance.fbx",
		"res://assets/characters/janitor/anim-dance.fbx",
	],
	&"dash": [
		"res://assets/characters/janitor/dash.fbx",
		"res://assets/characters/janitor/anim_dash.fbx",
		"res://assets/characters/janitor/anim-dash.fbx",
	],
}

const LIB_NAME := &"janitor"

## Screenshot renkleri → sahne toon (hit_wobble) albedo
const MESH_COLORS := {
	"Cube_002": Color(0.96, 0.96, 0.98), # göz
	"Cube_005": Color(0.28, 0.16, 0.10), # saç
	"Cube_007": Color(0.28, 0.16, 0.10),
	"Cube_008": Color(0.28, 0.16, 0.10),
	"Cube_009": Color(0.22, 0.12, 0.08), # bıyık
	"Cube_001": Color(0.92, 0.72, 0.58), # ten
	"Cube_003": Color(0.92, 0.72, 0.58),
	"Cube_004": Color(0.48, 0.30, 0.68), # şapka
	"Cube_006": Color(0.48, 0.30, 0.68),
	"torso": Color(0.48, 0.30, 0.68),
	"torso_001": Color(0.48, 0.30, 0.68),
	"torso_002": Color(0.16, 0.10, 0.22), # koyu bel
	"torso_003": Color(0.16, 0.10, 0.22),
	"Cylinder": Color(0.48, 0.30, 0.68),
	"Cylinder_001": Color(0.42, 0.26, 0.62), # pantolon
	"Cylinder_002": Color(0.92, 0.72, 0.58),
}

@export var yaw_offset: float = 0.0
@export var apply_toon: bool = true
@export_range(0.25, 1.75, 0.01) var size_mult: float = 1.0
@export var manual_scale: float = 0.0

var _model: Node3D
var _ap: AnimationPlayer
var _skeleton: Skeleton3D
var _current: StringName = &""
var _oneshot: bool = false
var _oneshot_gen: int = 0
var _ready_ok: bool = false
var _base_model_y: float = 0.0
var _toon_mats: Array[ShaderMaterial] = []


func is_ready_visual() -> bool:
	return _ready_ok


func is_oneshot() -> bool:
	return _oneshot


func has_anim(anim_name: StringName) -> bool:
	return _ready_ok and _ap != null and _ap.has_animation(_anim_path(anim_name))


func setup() -> bool:
	if not _spawn_model():
		push_warning("JanitorVisual: model yüklenemedi")
		return false
	_import_animations()
	if apply_toon:
		_apply_scene_toon()
	_ready_ok = _ap != null and _ap.has_animation_library(LIB_NAME)
	if _ready_ok:
		play_loco(&"idle")
	return _ready_ok


func play_loco(anim_name: StringName, custom_speed: float = 1.0) -> void:
	if not _ready_ok or _oneshot:
		return
	# Fallback zinciri
	var pick := anim_name
	if not has_anim(pick):
		if pick == &"carry_walk" and has_anim(&"carry"):
			pick = &"carry"
		elif pick == &"dash" and has_anim(&"run"):
			pick = &"run"
		elif pick == &"dance" and has_anim(&"idle"):
			pick = &"idle"
		else:
			return
	if pick == _current and is_equal_approx(_ap.speed_scale, custom_speed):
		return
	_current = pick
	_ap.speed_scale = custom_speed
	_ap.play(_anim_path(pick))
	# Anim değişince kök kaymasını engelle
	_lock_model_xz()


## Oneshot'ı kesip loco oynat (scrap reveal / zorla pose).
func force_loco(anim_name: StringName, custom_speed: float = 1.0) -> void:
	_oneshot_gen += 1
	_oneshot = false
	play_loco(anim_name, custom_speed)


## Dash — oneshot: hareket bitsa bile anim bitene kadar kesilmez.
## custom_speed < 0 → uzunluğu doğal / hafif sıkıştırılmış oynat.
func play_dash(custom_speed: float = -1.0) -> void:
	if not _ready_ok:
		return
	if not has_anim(&"dash"):
		_oneshot = false
		play_loco(&"run", 1.85)
		return
	var path := _anim_path(&"dash")
	var anim := _ap.get_animation(path)
	var length := anim.length if anim != null else 0.45
	var spd := custom_speed
	if spd < 0.0:
		# Hareket kısa (~0.16s); anim doğal bitsin. Çok uzunsa max ~0.55s'e sığdır.
		var target_sec := clampf(length, 0.32, 0.55)
		spd = length / maxf(target_sec, 0.05)
	_play_oneshot(&"dash", maxf(0.85, spd))


## speed: 1.0 = normal · bump için ~2.3 (yarı süre)
func play_hit(speed: float = 1.15) -> void:
	if not _ready_ok or not has_anim(&"hit"):
		return
	_play_oneshot(&"hit", maxf(0.5, speed))


func _play_oneshot(anim_key: StringName, speed: float) -> void:
	_oneshot_gen += 1
	var gen := _oneshot_gen
	_oneshot = true
	_current = anim_key
	_ap.speed_scale = speed
	_ap.play(_anim_path(anim_key))
	_lock_model_xz()
	var cb := func(_finished_name: StringName) -> void:
		if gen != _oneshot_gen:
			return
		_oneshot = false
		if _current == anim_key:
			_current = &""
		_lock_model_xz()
	_ap.animation_finished.connect(cb, CONNECT_ONE_SHOT)


func _anim_path(anim_name: StringName) -> StringName:
	return StringName("%s/%s" % [LIB_NAME, anim_name])


func _spawn_model() -> bool:
	var inst := CHAR_SCENE.instantiate()
	if inst == null:
		return false
	_model = inst as Node3D
	if _model == null:
		inst.queue_free()
		return false
	_model.name = "JanitorModel"
	add_child(_model)
	_model.rotation = Vector3(0.0, yaw_offset, 0.0)
	_strip_imported_lights_and_cameras(_model)
	_strip_orphan_world_meshes(_model)

	_skeleton = _find_skeleton(_model)
	_ensure_anim_player()
	if _skeleton != null:
		_skeleton.force_update_all_bone_transforms()
	_fit_scale_and_feet()
	_lock_model_xz()
	return true


func _strip_imported_lights_and_cameras(root: Node) -> void:
	var to_free: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Light3D or n is Camera3D:
			to_free.append(n)
			continue
		for c in n.get_children():
			stack.append(c)
	for n in to_free:
		n.get_parent().remove_child(n)
		n.free()


## Skin'siz / skeleton dışı Cube mesh'ler dünya orijininde gri kutu olarak kalır.
func _strip_orphan_world_meshes(root: Node) -> void:
	var to_free: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var under_skel := _is_descendant_of_skeleton(mi)
			var skinned := mi.skin != null or not mi.skeleton.is_empty()
			if not under_skel and not skinned:
				to_free.append(mi)
		for c in n.get_children():
			stack.append(c)
	for n in to_free:
		if is_instance_valid(n) and n.get_parent() != null:
			n.get_parent().remove_child(n)
			n.free()


func _is_descendant_of_skeleton(node: Node) -> bool:
	var walk := node.get_parent()
	while walk != null:
		if walk is Skeleton3D:
			return true
		walk = walk.get_parent()
	return false


func _ensure_anim_player() -> void:
	if _skeleton == null:
		return
	var host: Node = _skeleton.get_parent()
	if host == null:
		host = _model
	_ap = null
	for c in host.get_children():
		if c is AnimationPlayer:
			_ap = c as AnimationPlayer
			break
	if _ap == null:
		_ap = AnimationPlayer.new()
		_ap.name = "JanitorAnimPlayer"
		host.add_child(_ap)
	_ap.root_node = NodePath("..")
	if _ap.get_parent() != host:
		_ap.reparent(host)
	# Root motion kapalı — CharacterBody hareketi yönetir
	_ap.root_motion_track = NodePath()


func _fit_scale_and_feet() -> void:
	if _model == null:
		return
	_model.scale = Vector3.ONE
	_model.position = Vector3.ZERO
	if _skeleton != null:
		_skeleton.force_update_all_bone_transforms()

	var height := _skeleton_height_y()
	var foot_y := _skeleton_foot_y()
	if height < 0.001:
		var aabb := _mesh_aabb(_model)
		height = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		foot_y = aabb.position.y

	var s: float
	if manual_scale > 0.001:
		s = manual_scale
	else:
		const REF_HEIGHT := 1.05
		s = (REF_HEIGHT / maxf(height, 0.001)) * clampf(size_mult, 0.25, 1.75)

	_model.scale = Vector3(s, s, s)
	_base_model_y = -foot_y * s
	_model.position = Vector3(0.0, _base_model_y, 0.0)


func _lock_model_xz() -> void:
	if _model == null:
		return
	_model.position.x = 0.0
	_model.position.z = 0.0
	_model.position.y = _base_model_y


func _skeleton_height_y() -> float:
	if _skeleton == null:
		return 0.0
	var y_min := INF
	var y_max := -INF
	for i in _skeleton.get_bone_count():
		var y := _skeleton.get_bone_global_pose(i).origin.y
		y_min = minf(y_min, y)
		y_max = maxf(y_max, y)
	if y_min > y_max:
		return 0.0
	return y_max - y_min


func _skeleton_foot_y() -> float:
	if _skeleton == null:
		return 0.0
	var foot_bones := [
		"mixamorig_LeftFoot", "mixamorig_RightFoot",
		"mixamorig_LeftToeBase", "mixamorig_RightToeBase",
	]
	var y_min := INF
	for bn in foot_bones:
		var i := _skeleton.find_bone(bn)
		if i < 0:
			continue
		y_min = minf(y_min, _skeleton.get_bone_global_pose(i).origin.y)
	if y_min < INF:
		return y_min
	for i in _skeleton.get_bone_count():
		y_min = minf(y_min, _skeleton.get_bone_global_pose(i).origin.y)
	return y_min if y_min < INF else 0.0


func _mesh_aabb(root: Node) -> AABB:
	var first := true
	var merged := AABB()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				var local := mi.get_aabb()
				var xf := mi.global_transform
				if root is Node3D:
					xf = (root as Node3D).global_transform.affine_inverse() * mi.global_transform
				var world_aabb := _xform_aabb(xf, local)
				if first:
					merged = world_aabb
					first = false
				else:
					merged = merged.merge(world_aabb)
		for c in n.get_children():
			stack.append(c)
	return merged


func _xform_aabb(xf: Transform3D, aabb: AABB) -> AABB:
	var pts: Array[Vector3] = []
	for i in 8:
		pts.append(xf * aabb.get_endpoint(i))
	var out := AABB(pts[0], Vector3.ZERO)
	for i in range(1, 8):
		out = out.expand(pts[i])
	return out


func _import_animations() -> void:
	if _ap == null or _skeleton == null:
		return
	if _ap.has_animation_library(LIB_NAME):
		_ap.remove_animation_library(LIB_NAME)
	var lib := AnimationLibrary.new()

	for key in ANIM_REQUIRED.keys():
		_add_anim_from_path(lib, StringName(key), String(ANIM_REQUIRED[key]))

	for key in ANIM_OPTIONAL.keys():
		var paths: Array = ANIM_OPTIONAL[key] as Array
		for anim_path in paths:
			if ResourceLoader.exists(String(anim_path)):
				_add_anim_from_path(lib, StringName(key), String(anim_path))
				break

	_ap.add_animation_library(LIB_NAME, lib)


func _add_anim_from_path(lib: AnimationLibrary, key: StringName, path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("JanitorVisual: anim yok: %s" % path)
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var temp := packed.instantiate()
	var src_ap := _find_anim_player(temp)
	if src_ap == null or src_ap.get_animation_list().is_empty():
		temp.queue_free()
		return
	var src_anim := src_ap.get_animation(src_ap.get_animation_list()[0])
	if src_anim == null:
		temp.queue_free()
		return
	var anim := src_anim.duplicate(true) as Animation
	_retarget_tracks(anim)
	_strip_hips_translation(anim)
	if key == &"hit" or key == &"dash":
		anim.loop_mode = Animation.LOOP_NONE
	else:
		anim.loop_mode = Animation.LOOP_LINEAR
	lib.add_animation(key, anim)
	temp.queue_free()


func _retarget_tracks(anim: Animation) -> void:
	if _ap == null or _skeleton == null:
		return
	var skel_str := String(_skeleton.name)
	for i in anim.get_track_count():
		var ttype := anim.track_get_type(i)
		if ttype != Animation.TYPE_POSITION_3D \
			and ttype != Animation.TYPE_ROTATION_3D \
			and ttype != Animation.TYPE_SCALE_3D \
			and ttype != Animation.TYPE_BLEND_SHAPE:
			continue
		var path := anim.track_get_path(i)
		var bone := String(path.get_concatenated_subnames())
		if bone.is_empty():
			continue
		bone = _resolve_bone_name(bone)
		if bone.is_empty():
			continue
		anim.track_set_path(i, NodePath("%s:%s" % [skel_str, bone]))


## Mixamo Hips position = root motion → ışınlanma / kayma. Sadece rotasyon kalsın.
func _strip_hips_translation(anim: Animation) -> void:
	var to_remove: Array[int] = []
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var bone := String(anim.track_get_path(i).get_concatenated_subnames())
		var b := bone.to_lower()
		if b.contains("hips") or b.contains("root") or b.ends_with("pelvis"):
			to_remove.append(i)
	to_remove.reverse()
	for i in to_remove:
		anim.remove_track(i)


func _resolve_bone_name(bone: String) -> String:
	if _skeleton.find_bone(bone) >= 0:
		return bone
	var alt := bone.replace(":", "_")
	if _skeleton.find_bone(alt) >= 0:
		return alt
	alt = bone.replace("_", ":")
	if _skeleton.find_bone(alt) >= 0:
		return alt
	return ""


## Sahne prop'larıyla aynı hit_wobble toon + outline
func _apply_scene_toon() -> void:
	if _model == null:
		return
	_toon_mats.clear()
	_apply_toon_recursive(_model)


func _apply_toon_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var col := _color_for_mesh(mi)
		# Model ~0.1 scale → outline lokalde kalın olmalı (dünya ~0.015)
		var outline_w := 0.11
		var mat := HitWobbleMaterialScript.create(
			col,
			0.88,
			Color.BLACK,
			0.0,
			0.22,
			true,
			outline_w
		)
		# Prop'larla aynı band / gölge
		mat.set_shader_parameter("shade_bands", 3)
		mat.set_shader_parameter("shadow_tint", Vector3(0.28, 0.22, 0.45))
		mat.set_shader_parameter("shadow_strength", 0.5)
		mat.set_shader_parameter("rim_strength", 0.22)
		mat.set_shader_parameter("ambient_boost", 0.16)
		# Outline next_pass'i paylaşılmasın — karaktere özel kalınlık
		if mat.next_pass is ShaderMaterial:
			var ol := (mat.next_pass as ShaderMaterial).duplicate() as ShaderMaterial
			ol.set_shader_parameter("outline_width", outline_w)
			ol.set_shader_parameter("outline_color", Color(0.05, 0.03, 0.08, 1.0))
			mat.next_pass = ol
		_set_mesh_mats(mi, mat)
	for c in node.get_children():
		_apply_toon_recursive(c)


func apply_hit_wobble(hit_dir: Vector3, strength: float = 1.0) -> void:
	for mat in _toon_mats:
		HitWobbleMaterialScript.apply_hit(mat, hit_dir, 0.0, strength)


func _set_mesh_mats(mi: MeshInstance3D, mat: ShaderMaterial) -> void:
	if mat != null and _toon_mats.find(mat) < 0:
		_toon_mats.append(mat)
	if mi.mesh == null or mi.mesh.get_surface_count() <= 0:
		mi.material_override = mat
		return
	mi.material_override = null
	for i in mi.mesh.get_surface_count():
		mi.set_surface_override_material(i, mat)


func _color_for_mesh(mi: MeshInstance3D) -> Color:
	var mesh_name := String(mi.name)
	if MESH_COLORS.has(mesh_name):
		return MESH_COLORS[mesh_name] as Color
	if mi.mesh != null and mi.mesh.get_surface_count() > 0:
		var mat_name := String(mi.mesh.surface_get_name(0)).to_lower()
		if mat_name.contains("001"):
			return Color(0.96, 0.96, 0.98)
		if mat_name.contains("004"):
			return Color(0.28, 0.16, 0.10)
		if mat_name.contains("005") or mat_name.contains("006"):
			return Color(0.16, 0.10, 0.22)
	return Color(0.48, 0.30, 0.68)


func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for c in root.get_children():
		var found := _find_skeleton(c)
		if found != null:
			return found
	return null


func _find_anim_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for c in root.get_children():
		var found := _find_anim_player(c)
		if found != null:
			return found
	return null


func _process(_delta: float) -> void:
	# Anim oynarken XZ kaymasını her frame kilitle
	if _ready_ok:
		_lock_model_xz()
