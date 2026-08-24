class_name ForestVegetation
extends RefCounted

## Tutorial DemoForest ile aynı materyal / ölçek / yoğunluk.
## Yaprak billboard'u model scale'e bağlı; ağacı küçültmek görünümü bozar.

const TREE_A_PATH := "res://assets/vegetation/meshes/tree.glb"
const TREE_B_PATH := "res://assets/vegetation/meshes/tree3.glb"
const GRASS_MESH_PATH := "res://assets/vegetation/meshes/grass_plane_mesh.res"
const TALL_GRASS_MESH_PATH := "res://assets/vegetation/meshes/grass_tall_mesh.res"
const FLOWER_MESH_PATH := "res://assets/vegetation/meshes/flower.res"
const NOISE_PATH := "res://assets/vegetation/textures/noise.tres"

const GRASS_SHADER := preload("res://shaders/vegetation/grass_billboard.gdshader")
const LEAVES_SHADER := preload("res://shaders/vegetation/tree_leaves.gdshader")
const TRUNK_SHADER := preload("res://shaders/vegetation/trunk_shader.gdshader")
const FLOWER_SHADER := preload("res://shaders/vegetation/flower.gdshader")
const LEAF_ALPHA := preload("res://assets/vegetation/textures/leaf_alpha.png")
const TREE_BARK := preload("res://assets/vegetation/textures/tree_bark.png")
const GRASS_ROUND := preload("res://assets/vegetation/textures/grass_round.png")
const GRASS_THIN := preload("res://assets/vegetation/textures/grass_thin.png")
const FLOWER_TEX := preload("res://assets/vegetation/textures/flower.png")

const LEAF_COLOR := Color(0.3647059, 0.65882355, 0.1764706)
const GRASS_COLOR := Color(0.101960786, 0.6901961, 0.21176471)
const TALL_GRASS_COLOR := Color(0.20546173, 0.77, 0.13090001)

const TREE_A_ROOT_SCALE := 1.285
const TREE_B_TRUNK_SCALE := Vector3(1.5337995, 1.0, 1.4856852)
const TREE_B_TRUNK_POS := Vector3(0.0, 1.0084579, 0.0)

static var _wind_ready: bool = false
static var _trunk_mat_a: ShaderMaterial
static var _trunk_mat_b: ShaderMaterial
static var _leaves_mat_a: ShaderMaterial
static var _leaves_mat_b: ShaderMaterial
static var _grass_mat: ShaderMaterial
static var _tall_grass_mat: ShaderMaterial
static var _flower_mat: ShaderMaterial


static func ensure_wind() -> void:
	if _wind_ready:
		return
	_wind_ready = true
	RenderingServer.global_shader_parameter_set("wind_direction", Vector3(0, 0, 1))
	RenderingServer.global_shader_parameter_set("wind_scale", 0.025)
	RenderingServer.global_shader_parameter_set("wind_speed", 0.075)
	RenderingServer.global_shader_parameter_set("wind_strength", 0.4)
	var noise := load(NOISE_PATH)
	if noise != null:
		RenderingServer.global_shader_parameter_set("wind_noise", noise)


static func fill_world_map(parent: Node3D, ground_y: float, _leaf_tint: Color, _grass_tint: Color, rng: RandomNumberGenerator) -> void:
	ensure_wind()
	var tree_spots: Array[Vector3] = [
		Vector3(-11.5, 0, 5.5), Vector3(-13.0, 0, 2.0), Vector3(-12.2, 0, -3.5),
		Vector3(11.8, 0, 4.8), Vector3(13.2, 0, 0.5), Vector3(12.0, 0, -4.0),
		Vector3(-8.5, 0, -7.5), Vector3(7.5, 0, -8.0), Vector3(0.0, 0, -9.0),
		Vector3(-15.0, 0, -6.0), Vector3(15.0, 0, -5.5),
	]
	for i in tree_spots.size():
		var p := tree_spots[i]
		p.y = ground_y
		var yaw := rng.randf() * TAU
		spawn_tree(parent, p, yaw, i % 2)

	var grass_pts := _jitter_grid(rng, 22.0, 16.0, 0.42, ground_y, 2.15, 9.0)
	_spawn_multimesh(parent, _grass_mesh(), _get_grass_mat(false), grass_pts, rng, 0.92, 1.08, Vector3.ONE)

	var tall_pts := _jitter_grid(rng, 18.0, 13.0, 1.35, ground_y, 2.4, 8.0)
	_spawn_multimesh(parent, _tall_grass_mesh(), _get_grass_mat(true), tall_pts, rng, 0.95, 1.1, Vector3.ONE)

	var flower_pts := _jitter_grid(rng, 10.0, 8.0, 2.4, ground_y, 2.6, 6.0)
	_spawn_multimesh(parent, _flower_mesh(), _get_flower_mat(), flower_pts, rng, 2.85, 3.15, Vector3.ONE)


static func fill_level_outskirts(
	parent: Node3D,
	half_x: float,
	half_z: float,
	ground_y: float,
	rng: RandomNumberGenerator,
	_leaf_tint: Color,
	_grass_tint: Color,
) -> void:
	ensure_wind()
	var tree_n := 10
	for i in tree_n:
		var ang := float(i) / float(tree_n) * TAU + rng.randf_range(-0.12, 0.12)
		var dist := maxf(half_x, half_z) + rng.randf_range(4.2, 8.0)
		var p := Vector3(cos(ang) * dist, ground_y, sin(ang) * dist)
		if absf(p.x) < half_x + 2.4 and absf(p.z) < half_z + 2.4:
			p *= 1.35
		spawn_tree(parent, p, rng.randf() * TAU, i % 2)

	var grass_pts := _outside_band_points(rng, half_x, half_z, 0.55, 9.5, 2800, ground_y)
	_spawn_multimesh(parent, _grass_mesh(), _get_grass_mat(false), grass_pts, rng, 0.92, 1.08, Vector3.ONE)

	var tall_pts := _outside_band_points(rng, half_x, half_z, 1.2, 8.0, 160, ground_y)
	_spawn_multimesh(parent, _tall_grass_mesh(), _get_grass_mat(true), tall_pts, rng, 0.95, 1.12, Vector3.ONE)

	var flower_pts := _outside_band_points(rng, half_x, half_z, 1.0, 6.0, 36, ground_y)
	_spawn_multimesh(parent, _flower_mesh(), _get_flower_mat(), flower_pts, rng, 2.85, 3.15, Vector3.ONE)


static func spawn_tree(parent: Node3D, pos: Vector3, yaw: float, variant: int) -> Node3D:
	var path := TREE_B_PATH if variant == 1 else TREE_A_PATH
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return null
	var root_sc := 1.0 if variant == 1 else TREE_A_ROOT_SCALE
	inst.transform = Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(Vector3.ONE * root_sc), pos)
	parent.add_child(inst)
	_apply_tree_materials(inst, variant)
	return inst


static func _apply_tree_materials(n: Node, variant: int) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var nm := mi.name.to_lower().replace(".", "_")
		if nm.contains("leaf"):
			mi.set_surface_override_material(0, _get_leaves_mat(variant))
			mi.material_override = null
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif nm.contains("trunk"):
			if variant == 1:
				mi.position = TREE_B_TRUNK_POS
				mi.scale = TREE_B_TRUNK_SCALE
			mi.set_surface_override_material(0, _get_trunk_mat(variant))
			mi.material_override = null
	for c in n.get_children():
		_apply_tree_materials(c, variant)


static func _get_leaves_mat(variant: int) -> ShaderMaterial:
	if variant == 1:
		if _leaves_mat_b == null:
			_leaves_mat_b = _make_leaves_mat(0.6)
		return _leaves_mat_b
	if _leaves_mat_a == null:
		_leaves_mat_a = _make_leaves_mat(1.0)
	return _leaves_mat_a


static func _make_leaves_mat(leaves_scale: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LEAVES_SHADER
	m.set_shader_parameter("color", LEAF_COLOR)
	m.set_shader_parameter("alpha", LEAF_ALPHA)
	m.set_shader_parameter("leaves_scale", leaves_scale)
	m.set_shader_parameter("leaf_bend_amount", 0.7)
	m.set_shader_parameter("light_steps", 5.0)
	return m


static func _get_trunk_mat(variant: int) -> ShaderMaterial:
	if variant == 1:
		if _trunk_mat_b == null:
			_trunk_mat_b = _make_trunk_mat(Vector2(8.0, 2.0))
		return _trunk_mat_b
	if _trunk_mat_a == null:
		_trunk_mat_a = _make_trunk_mat(Vector2(4.5, 3.0))
	return _trunk_mat_a


static func _make_trunk_mat(uv_scale: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TRUNK_SHADER
	m.set_shader_parameter("color_texture", TREE_BARK)
	m.set_shader_parameter("light_steps", 3.0)
	m.set_shader_parameter("uv_scale", uv_scale)
	m.set_shader_parameter("outline_mask", 1.0)
	return m


static func _get_grass_mat(tall: bool) -> ShaderMaterial:
	if tall:
		if _tall_grass_mat == null:
			_tall_grass_mat = _make_grass_mat(TALL_GRASS_COLOR, true)
		return _tall_grass_mat
	if _grass_mat == null:
		_grass_mat = _make_grass_mat(GRASS_COLOR, false)
	return _grass_mat


static func _make_grass_mat(col: Color, tall: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GRASS_SHADER
	m.set_shader_parameter("grass_color", col)
	m.set_shader_parameter("grass_alpha", GRASS_THIN if tall else GRASS_ROUND)
	m.set_shader_parameter("grass_bend_amount", 1.0)
	m.set_shader_parameter("sway_back", 0.5 if tall else 1.0)
	m.set_shader_parameter("light_steps", 3.0)
	return m


static func _get_flower_mat() -> ShaderMaterial:
	if _flower_mat == null:
		_flower_mat = ShaderMaterial.new()
		_flower_mat.shader = FLOWER_SHADER
		_flower_mat.set_shader_parameter("flower_texture", FLOWER_TEX)
		_flower_mat.set_shader_parameter("flower_bendiness", 1.2)
		_flower_mat.set_shader_parameter("sway_back", 0.5)
		_flower_mat.set_shader_parameter("light_steps", 3.0)
	return _flower_mat


static func _grass_mesh() -> Mesh:
	var mesh := load(GRASS_MESH_PATH) as Mesh
	return mesh if mesh != null else _fallback_quad(Vector2(0.55, 0.7))


static func _tall_grass_mesh() -> Mesh:
	var mesh := load(TALL_GRASS_MESH_PATH) as Mesh
	return mesh if mesh != null else _fallback_quad(Vector2(0.45, 1.05))


static func _flower_mesh() -> Mesh:
	var mesh := load(FLOWER_MESH_PATH) as Mesh
	return mesh if mesh != null else _fallback_quad(Vector2(0.35, 0.55))


static func _fallback_quad(size: Vector2) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	q.center_offset = Vector3(0.0, size.y * 0.5, 0.0)
	return q


static func _spawn_multimesh(
	parent: Node3D,
	mesh: Mesh,
	mat: Material,
	points: Array[Vector3],
	rng: RandomNumberGenerator,
	sc_min: float,
	sc_max: float,
	root_scale: Vector3,
) -> void:
	if mesh == null or points.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = points.size()
	for i in points.size():
		var sc := rng.randf_range(sc_min, sc_max)
		var xf := Transform3D.IDENTITY
		xf = xf.scaled(Vector3(sc, sc, sc))
		xf = xf.rotated(Vector3.UP, rng.randf() * TAU)
		xf.origin = points[i]
		mm.set_instance_transform(i, xf)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.scale = root_scale
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func _jitter_grid(
	rng: RandomNumberGenerator,
	half_x: float,
	half_z: float,
	spacing: float,
	ground_y: float,
	path_half_x: float,
	path_half_z: float,
) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var x := -half_x
	while x <= half_x:
		var z := -half_z
		while z <= half_z:
			var px := x + rng.randf_range(-spacing * 0.4, spacing * 0.4)
			var pz := z + rng.randf_range(-spacing * 0.4, spacing * 0.4)
			if absf(px) < path_half_x and absf(pz) < path_half_z:
				z += spacing
				continue
			out.append(Vector3(px, ground_y, pz))
			z += spacing
		x += spacing
	return out


static func _outside_band_points(
	rng: RandomNumberGenerator,
	half_x: float,
	half_z: float,
	pad_near: float,
	pad_far: float,
	count: int,
	ground_y: float,
) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var tries := 0
	while out.size() < count and tries < count * 12:
		tries += 1
		var ang := rng.randf() * TAU
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var tx := INF if absf(dir.x) < 0.001 else half_x / absf(dir.x)
		var tz := INF if absf(dir.z) < 0.001 else half_z / absf(dir.z)
		var edge := dir * minf(tx, tz)
		var dist := lerpf(pad_near, pad_far, rng.randf() * rng.randf())
		var p := edge + dir * dist
		p.x += rng.randf_range(-0.25, 0.25)
		p.z += rng.randf_range(-0.25, 0.25)
		p.y = ground_y
		if absf(p.x) <= half_x + pad_near * 0.25 and absf(p.z) <= half_z + pad_near * 0.25:
			continue
		out.append(p)
	return out
