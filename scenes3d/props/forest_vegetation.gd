class_name ForestVegetation
extends RefCounted

## Tutorial DemoForest ile aynı materyal / ölçek / yoğunluk.
## Yaprak billboard'u model scale'e bağlı; ağacı küçültmek görünümü bozar.

const PerfBudget := preload("res://systems/perf_budget_3d.gd")

const TREE_A_PATH := "res://assets/vegetation/meshes/tree.glb"
const TREE_B_PATH := "res://assets/vegetation/meshes/tree3.glb"
const TREE_A_LEAVES_MESH := "res://assets/vegetation/meshes/tree_leaves_cluster.res"
const TREE_B_LEAVES_MESH := "res://assets/vegetation/meshes/tree3_leaves_cluster.res"
const GRASS_MESH_PATH := "res://assets/vegetation/meshes/grass_plane_mesh.res"
const TALL_GRASS_MESH_PATH := "res://assets/vegetation/meshes/grass_tall_mesh.res"
const FLOWER_MESH_PATH := "res://assets/vegetation/meshes/flower.res"
const NOISE_PATH := "res://assets/vegetation/textures/noise.tres"
const PLANE_TREE_TEX_PATH := "res://assets/props/foliage/tree_plane_a_treetrunl.png"
const LEAF_ALPHA_PATH := "res://assets/vegetation/textures/leaf_alpha.png"
const TREE_BARK_PATH := "res://assets/vegetation/textures/tree_bark.png"
const GRASS_ROUND_PATH := "res://assets/vegetation/textures/grass_round.png"
const GRASS_THIN_PATH := "res://assets/vegetation/textures/grass_thin.png"
const FLOWER_TEX_PATH := "res://assets/vegetation/textures/flower.png"
const LEAF_PARTICLE_PATH := "res://assets/vegetation/textures/leaf_particle.png"

## Tutorial DemoForest mesh/doku lisanslı değil — ship'te kullanma.
const USE_UNLICENSED_TUTORIAL_MESHES := false

const GRASS_SHADER := preload("res://shaders/vegetation/grass_billboard.gdshader")
const LEAVES_SHADER := preload("res://shaders/vegetation/tree_leaves.gdshader")
const TRUNK_SHADER := preload("res://shaders/vegetation/trunk_shader.gdshader")
const FLOWER_SHADER := preload("res://shaders/vegetation/flower.gdshader")
const PLANE_TREE_SHADER := preload("res://shaders/vegetation/plane_tree.gdshader")

const LEAF_COLOR := Color(0.3647059, 0.65882355, 0.1764706)
const GRASS_COLOR := Color(0.101960786, 0.6901961, 0.21176471)
const TALL_GRASS_COLOR := Color(0.20546173, 0.77, 0.13090001)
const BERM_COLOR := Color(0.18, 0.38, 0.16)

const TREE_A_ROOT_SCALE := 1.285
const TREE_B_TRUNK_SCALE := Vector3(1.5337995, 1.0, 1.4856852)
const TREE_B_TRUNK_POS := Vector3(0.0, 1.0084579, 0.0)
const TREE_A_CLUSTER_XFORM := Transform3D(
	Vector3(0.93, 0.0, 0.0),
	Vector3(0.0, 0.93, 0.0),
	Vector3(0.0, 0.0, 0.93),
	Vector3(0.003285408, 4.9916096, -0.81776524)
)
const TREE_B_CLUSTER_XFORM := Transform3D(Basis.IDENTITY, Vector3(0.0, 5.4666224, 0.0))

const FLOWER_SC_MIN := 0.88
const FLOWER_SC_MAX := 1.08

static var _wind_ready: bool = false
static var _trunk_mat_a: ShaderMaterial
static var _trunk_mat_b: ShaderMaterial
static var _leaves_mat_a: ShaderMaterial
static var _leaves_mat_b: ShaderMaterial
static var _grass_mat: ShaderMaterial
static var _tall_grass_mat: ShaderMaterial
static var _flower_mat: ShaderMaterial
static var _plane_tree_mat: ShaderMaterial
static var _plane_tree_mesh: QuadMesh
static var _plane_tree_tex: Texture2D


static func _tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func ensure_wind() -> void:
	if _wind_ready:
		return
	_wind_ready = true
	RenderingServer.global_shader_parameter_set("wind_direction", Vector3(0, 0, 1))
	RenderingServer.global_shader_parameter_set("wind_scale", 0.025)
	RenderingServer.global_shader_parameter_set("wind_speed", 0.075)
	RenderingServer.global_shader_parameter_set("wind_strength", 0.4)
	if USE_UNLICENSED_TUTORIAL_MESHES:
		var noise := load(NOISE_PATH)
		if noise != null:
			RenderingServer.global_shader_parameter_set("wind_noise", noise)


static func fill_world_map(
	parent: Node3D,
	ground_y: float,
	leaf_tint: Color,
	grass_tint: Color,
	rng: RandomNumberGenerator,
	flower_tint: Color = Color(0.95, 0.85, 0.4),
) -> void:
	ensure_wind()
	# Dünya paletinden türetilen biome renk seti + yoğunluk (yeşillik → gürlük)
	var biome := _biome_colors(leaf_tint, grass_tint, flower_tint)
	var crown_tint: Color = biome["crown"]
	var plane_mat := _make_plane_tree_mat_tinted(Color(1, 1, 1).lerp(crown_tint, 0.4))

	var tree_spots: Array[Vector3] = [
		Vector3(-11.5, 0, 5.5), Vector3(-13.0, 0, 2.0), Vector3(-12.2, 0, -3.5),
		Vector3(11.8, 0, 4.8), Vector3(13.2, 0, 0.5), Vector3(12.0, 0, -4.0),
		Vector3(-8.5, 0, -7.5), Vector3(7.5, 0, -8.0), Vector3(0.0, 0, -9.0),
		Vector3(-15.0, 0, -6.0), Vector3(15.0, 0, -5.5),
	]
	var plane_xfs: Array[Transform3D] = []
	for i in tree_spots.size():
		var p := tree_spots[i]
		p.y = ground_y
		if USE_UNLICENSED_TUTORIAL_MESHES and i % 3 != 0:
			spawn_tree(parent, p, rng.randf() * TAU, i % 2, crown_tint)
		else:
			plane_xfs.append(plane_tree_xform(p, rng.randf_range(4.6, 6.2)))
	spawn_plane_tree_batch(parent, plane_xfs, plane_mat)

	if not USE_UNLICENSED_TUTORIAL_MESHES:
		return

	var lush := clampf((clampf(grass_tint.g, 0.05, 0.85) - 0.12) / 0.5, 0.0, 1.0)
	var sp_mul := lerpf(1.35, 0.88, lush)
	var grass_mat := _make_grass_mat_tinted(biome["grass"], false)
	var tall_mat := _make_grass_mat_tinted(biome["tall"], true)
	var flower_mat := _make_flower_mat_tinted(biome["flower"])
	var grass_pts := _jitter_grid(rng, 22.0, 16.0, 0.42 * sp_mul, ground_y, 2.15, 9.0)
	_spawn_multimesh(parent, _grass_mesh(), grass_mat, grass_pts, rng, 0.9, 1.06 + lush * 0.12, Vector3.ONE)

	var tall_pts := _jitter_grid(rng, 18.0, 13.0, 1.35 * sp_mul, ground_y, 2.4, 8.0)
	_spawn_multimesh(parent, _tall_grass_mesh(), tall_mat, tall_pts, rng, 0.95, 1.1 + lush * 0.15, Vector3.ONE)

	# Çiçekler yalnızca yeterince yeşil/gür biome'larda
	if lush > 0.35:
		var flower_pts := _jitter_grid(rng, 10.0, 8.0, 2.4 * sp_mul, ground_y, 2.6, 6.0)
		_spawn_multimesh(parent, _flower_mesh(), flower_mat, flower_pts, rng, FLOWER_SC_MIN, FLOWER_SC_MAX, Vector3.ONE)


## Palet tint'lerinden tutarlı bir biome renk seti üretir (çim / uzun çim / çiçek / ağaç tacı).
static func _biome_colors(leaf_tint: Color, grass_tint: Color, flower_tint: Color) -> Dictionary:
	var grass := grass_tint
	grass.s = clampf(grass.s * 1.15 + 0.05, 0.0, 1.0)
	grass.v = clampf(grass.v * 1.05 + 0.03, 0.05, 1.0)
	var tall := grass.lightened(0.06)
	tall.s = clampf(tall.s * 1.05, 0.0, 1.0)
	var flower := flower_tint
	flower.s = clampf(flower.s * 1.1 + 0.1, 0.0, 1.0)
	flower.v = clampf(flower.v + 0.08, 0.0, 1.0)
	var crown := leaf_tint.lerp(LEAF_COLOR, 0.35)
	crown.s = clampf(crown.s * 1.1, 0.0, 1.0)
	crown.v = clampf(crown.v * 1.05, 0.05, 1.0)
	return {"grass": grass, "tall": tall, "flower": flower, "crown": crown}


static func _make_grass_mat_tinted(col: Color, tall: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GRASS_SHADER
	m.set_shader_parameter("grass_color", col)
	m.set_shader_parameter("grass_alpha", _tex(GRASS_THIN_PATH) if tall else _tex(GRASS_ROUND_PATH))
	m.set_shader_parameter("grass_bend_amount", 1.0)
	m.set_shader_parameter("sway_back", 0.5 if tall else 1.0)
	m.set_shader_parameter("light_steps", 3.0)
	return m


static func _make_flower_mat_tinted(col: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLOWER_SHADER
	m.set_shader_parameter("flower_texture", _tex(FLOWER_TEX_PATH))
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("flower_bendiness", 1.2)
	m.set_shader_parameter("sway_back", 0.5)
	m.set_shader_parameter("light_steps", 3.0)
	return m


static func _make_plane_tree_mat_tinted(tint: Color) -> ShaderMaterial:
	var tex := _get_plane_tree_tex()
	if tex == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = PLANE_TREE_SHADER
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("cut", 0.08)
	m.set_shader_parameter("tint", tint)
	return m


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
	_spawn_edge_berms(parent, half_x, half_z, ground_y)
	var plane_xfs := _collect_play_boundary_trees(rng, half_x, half_z, ground_y)
	var tree_n := PerfBudget.MAX_RING_TREES
	for i in tree_n:
		var ang := float(i) / float(tree_n) * TAU + rng.randf_range(-0.12, 0.12)
		var dist := maxf(half_x, half_z) + rng.randf_range(6.5, 10.5)
		var p := Vector3(cos(ang) * dist, ground_y, sin(ang) * dist)
		if absf(p.x) < half_x + 2.4 and absf(p.z) < half_z + 2.4:
			p *= 1.35
		if USE_UNLICENSED_TUTORIAL_MESHES and i % 2 != 0:
			spawn_tree(parent, p, rng.randf() * TAU, i % 2)
		else:
			plane_xfs.append(plane_tree_xform(p, rng.randf_range(5.4, 7.4)))
	spawn_plane_tree_batch(parent, plane_xfs)

	if not USE_UNLICENSED_TUTORIAL_MESHES:
		return

	var grass_pts := _outside_band_points(rng, half_x, half_z, 0.55, 9.5, 2800, ground_y)
	_spawn_multimesh(parent, _grass_mesh(), _get_grass_mat(false), grass_pts, rng, 0.92, 1.08, Vector3.ONE)

	var tall_pts := _outside_band_points(rng, half_x, half_z, 1.2, 8.0, 160, ground_y)
	_spawn_multimesh(parent, _tall_grass_mesh(), _get_grass_mat(true), tall_pts, rng, 0.95, 1.12, Vector3.ONE)

	var flower_pts := _outside_band_points(rng, half_x, half_z, 1.0, 6.0, 36, ground_y)
	_spawn_multimesh(parent, _flower_mesh(), _get_flower_mat(), flower_pts, rng, FLOWER_SC_MIN, FLOWER_SC_MAX, Vector3.ONE)


static func fill_play_boundary(
	parent: Node3D,
	half_x: float,
	half_z: float,
	ground_y: float,
	rng: RandomNumberGenerator,
) -> void:
	_spawn_edge_berms(parent, half_x, half_z, ground_y)
	spawn_plane_tree_batch(parent, _collect_play_boundary_trees(rng, half_x, half_z, ground_y))
	if USE_UNLICENSED_TUTORIAL_MESHES:
		var hedge_grass := _rect_edge_points(rng, half_x, half_z, 0.35, 1.65, 0.38, ground_y)
		_spawn_multimesh(parent, _tall_grass_mesh(), _get_grass_mat(true), hedge_grass, rng, 1.05, 1.28, Vector3.ONE)


static func spawn_tree(parent: Node3D, pos: Vector3, yaw: float, variant: int, crown_col: Color = LEAF_COLOR) -> Node3D:
	if not USE_UNLICENSED_TUTORIAL_MESHES:
		return spawn_plane_tree(parent, pos, 5.4)
	var path := TREE_B_PATH if variant == 1 else TREE_A_PATH
	var packed := load(path) as PackedScene
	if packed == null:
		return spawn_plane_tree(parent, pos, 5.4)
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return null
	var root_sc := 1.0 if variant == 1 else TREE_A_ROOT_SCALE
	inst.transform = Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(Vector3.ONE * root_sc), pos)
	parent.add_child(inst)
	_apply_tree_materials(inst, variant)
	_add_leaf_cluster(inst, variant, crown_col)
	_add_falling_leaves(inst, crown_col)
	return inst


static func plane_tree_xform(pos: Vector3, height: float) -> Transform3D:
	var sc := height / 5.6
	return Transform3D(Basis.from_scale(Vector3(sc, sc, sc)), pos)


static func spawn_plane_tree_batch(parent: Node3D, xforms: Array[Transform3D], mat_override: Material = null) -> void:
	var mesh := _get_plane_tree_mesh()
	var mat: Material = mat_override if mat_override != null else _get_plane_tree_mat()
	if parent == null or mesh == null or mat == null:
		return
	var kept := _cap_xforms(xforms, PerfBudget.MAX_PLANE_TREES)
	if kept.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = kept.size()
	for i in kept.size():
		mm.set_instance_transform(i, kept[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "PlaneTrees"
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func spawn_plane_tree(parent: Node3D, pos: Vector3, height: float, mat_override: Material = null) -> Node3D:
	var mesh := _get_plane_tree_mesh()
	var mat: Material = mat_override if mat_override != null else _get_plane_tree_mat()
	if mesh == null or mat == null:
		return null
	var root := Node3D.new()
	root.name = "PlaneTree"
	root.position = pos
	var sc := height / 5.6
	root.scale = Vector3(sc, sc, sc)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	parent.add_child(root)
	return root


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


static func _add_leaf_cluster(tree: Node3D, variant: int, crown_col: Color = LEAF_COLOR) -> void:
	var mesh := load(TREE_B_LEAVES_MESH if variant == 1 else TREE_A_LEAVES_MESH) as Mesh
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.name = "leaves_cluster"
	mi.mesh = mesh
	## DemoForest leaves2/leaves4 — sadece gölge hacmi; görünür taç billboard shader.
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = crown_col
	mi.material_override = shadow_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	mi.transform = TREE_B_CLUSTER_XFORM if variant == 1 else TREE_A_CLUSTER_XFORM
	tree.add_child(mi)


static func _add_falling_leaves(tree: Node3D, crown_col: Color = LEAF_COLOR) -> void:
	if not USE_UNLICENSED_TUTORIAL_MESHES:
		return
	var particles := GPUParticles3D.new()
	particles.name = "FallingLeaves"
	particles.amount = 5
	particles.lifetime = 10.0
	particles.preprocess = 5.0
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.position = Vector3(0.0, 5.85, 0.0)
	var proc := ParticleProcessMaterial.new()
	proc.particle_flag_rotate_y = true
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 1.0
	proc.emission_shape_scale = Vector3(3.0, 3.0, 3.0)
	proc.direction = Vector3(0.0, 0.0, 1.0)
	proc.spread = 10.0
	proc.initial_velocity_min = 0.5
	proc.initial_velocity_max = 1.5
	proc.angular_velocity_min = 150.0
	proc.angular_velocity_max = 200.0
	proc.gravity = Vector3(0.0, -0.3, 0.0)
	proc.scale_min = 0.5
	proc.scale_max = 0.65
	particles.process_material = proc
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45, 0.45)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = crown_col
	mat.albedo_texture = _tex(LEAF_PARTICLE_PATH)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	quad.material = mat
	particles.draw_pass_1 = quad
	tree.add_child(particles)


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
	m.set_shader_parameter("alpha", _tex(LEAF_ALPHA_PATH))
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
	m.set_shader_parameter("color_texture", _tex(TREE_BARK_PATH))
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
	m.set_shader_parameter("grass_alpha", _tex(GRASS_THIN_PATH) if tall else _tex(GRASS_ROUND_PATH))
	m.set_shader_parameter("grass_bend_amount", 1.0)
	m.set_shader_parameter("sway_back", 0.5 if tall else 1.0)
	m.set_shader_parameter("light_steps", 3.0)
	return m


static func _get_flower_mat() -> ShaderMaterial:
	if _flower_mat == null:
		_flower_mat = ShaderMaterial.new()
		_flower_mat.shader = FLOWER_SHADER
		_flower_mat.set_shader_parameter("flower_texture", _tex(FLOWER_TEX_PATH))
		_flower_mat.set_shader_parameter("flower_bendiness", 1.2)
		_flower_mat.set_shader_parameter("sway_back", 0.5)
		_flower_mat.set_shader_parameter("light_steps", 3.0)
	return _flower_mat


static func _get_plane_tree_tex() -> Texture2D:
	if _plane_tree_tex == null and ResourceLoader.exists(PLANE_TREE_TEX_PATH):
		_plane_tree_tex = load(PLANE_TREE_TEX_PATH) as Texture2D
	return _plane_tree_tex


static func _get_plane_tree_mat() -> ShaderMaterial:
	if _plane_tree_mat == null:
		var tex := _get_plane_tree_tex()
		if tex == null:
			return null
		_plane_tree_mat = ShaderMaterial.new()
		_plane_tree_mat.shader = PLANE_TREE_SHADER
		_plane_tree_mat.set_shader_parameter("albedo_tex", tex)
		_plane_tree_mat.set_shader_parameter("cut", 0.08)
	return _plane_tree_mat


static func _get_plane_tree_mesh() -> QuadMesh:
	if _plane_tree_mesh == null:
		_plane_tree_mesh = QuadMesh.new()
		_plane_tree_mesh.size = Vector2(4.2, 5.6)
		_plane_tree_mesh.center_offset = Vector3(0.0, 2.8, 0.0)
	return _plane_tree_mesh


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


static func _collect_play_boundary_trees(
	rng: RandomNumberGenerator,
	half_x: float,
	half_z: float,
	ground_y: float,
) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	## Arka kenar (kamera uzağı) — eski duvarın yerine çam sırası
	_collect_plane_line(
		out, rng, ground_y,
		Vector3(-half_x, 0.0, -half_z - 1.2),
		Vector3(half_x, 0.0, -half_z - 1.2),
		1.28, 5.2, 6.8, 0.22
	)
	## Sol / sağ
	_collect_plane_line(
		out, rng, ground_y,
		Vector3(-half_x - 1.15, 0.0, -half_z),
		Vector3(-half_x - 1.15, 0.0, half_z),
		1.55, 4.6, 6.2, 0.18
	)
	_collect_plane_line(
		out, rng, ground_y,
		Vector3(half_x + 1.15, 0.0, -half_z),
		Vector3(half_x + 1.15, 0.0, half_z),
		1.55, 4.6, 6.2, 0.18
	)
	## Ön kenar — kamerayı kapatmasın, alçak çalı hissi
	_collect_plane_line(
		out, rng, ground_y,
		Vector3(-half_x * 0.72, 0.0, half_z + 1.35),
		Vector3(half_x * 0.72, 0.0, half_z + 1.35),
		2.15, 2.8, 3.8, 0.12
	)
	return out


static func _collect_plane_line(
	out: Array[Transform3D],
	rng: RandomNumberGenerator,
	ground_y: float,
	a: Vector3,
	b: Vector3,
	spacing: float,
	h_min: float,
	h_max: float,
	jitter: float,
) -> void:
	spacing *= PerfBudget.PLANE_SPACING_MUL
	var delta := b - a
	var length := delta.length()
	if length < 0.01:
		return
	var dir := delta / length
	var n := maxi(2, int(round(length / spacing)))
	for i in n + 1:
		var t := float(i) / float(n)
		var p := a.lerp(b, t)
		p.x += rng.randf_range(-jitter, jitter)
		p.z += rng.randf_range(-jitter, jitter)
		p.y = ground_y
		out.append(plane_tree_xform(p, rng.randf_range(h_min, h_max)))
		if rng.randf() < PerfBudget.PLANE_EXTRA_CHANCE:
			var side := Vector3(-dir.z, 0.0, dir.x) * rng.randf_range(0.55, 1.15)
			if rng.randf() < 0.5:
				side = -side
			out.append(plane_tree_xform(p + side, rng.randf_range(h_min * 0.78, h_max * 0.92)))


static func _cap_xforms(xforms: Array[Transform3D], max_n: int) -> Array[Transform3D]:
	if max_n <= 0:
		return []
	if xforms.size() <= max_n:
		return xforms
	var out: Array[Transform3D] = []
	var step := float(xforms.size()) / float(max_n)
	var acc := 0.0
	while out.size() < max_n:
		var idx := clampi(int(acc), 0, xforms.size() - 1)
		out.append(xforms[idx])
		acc += step
	return out


static func _spawn_edge_berms(parent: Node3D, half_x: float, half_z: float, ground_y: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BERM_COLOR
	mat.roughness = 0.95
	var sizes: Array[Vector3] = [
		Vector3(half_x * 2.15, 0.22, 0.55),
		Vector3(half_x * 2.15, 0.22, 0.55),
		Vector3(0.55, 0.22, half_z * 2.15),
		Vector3(0.55, 0.22, half_z * 2.15),
	]
	var positions: Array[Vector3] = [
		Vector3(0.0, ground_y + 0.02, -half_z - 0.28),
		Vector3(0.0, ground_y + 0.02, half_z + 0.28),
		Vector3(-half_x - 0.28, ground_y + 0.02, 0.0),
		Vector3(half_x + 0.28, ground_y + 0.02, 0.0),
	]
	for i in sizes.size():
		var box := BoxMesh.new()
		box.size = sizes[i]
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.position = positions[i]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


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


static func _rect_edge_points(
	rng: RandomNumberGenerator,
	half_x: float,
	half_z: float,
	pad_near: float,
	pad_far: float,
	spacing: float,
	ground_y: float,
) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var x := -half_x - pad_far
	while x <= half_x + pad_far:
		var z_back := -1.0 * (half_z + rng.randf_range(pad_near, pad_far))
		var z_front := 1.0 * (half_z + rng.randf_range(pad_near, pad_far))
		out.append(Vector3(x + rng.randf_range(-0.18, 0.18), ground_y, z_back))
		out.append(Vector3(x + rng.randf_range(-0.18, 0.18), ground_y, z_front))
		x += spacing
	var z := -half_z - pad_far
	while z <= half_z + pad_far:
		var x_left := -1.0 * (half_x + rng.randf_range(pad_near, pad_far))
		var x_right := 1.0 * (half_x + rng.randf_range(pad_near, pad_far))
		out.append(Vector3(x_left, ground_y, z + rng.randf_range(-0.18, 0.18)))
		out.append(Vector3(x_right, ground_y, z + rng.randf_range(-0.18, 0.18)))
		z += spacing
	return out
