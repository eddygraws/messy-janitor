class_name WorldMapHub3D
extends Node3D

## 3D dünya haritası (NSMB tarzı path + node + pawn).
## Q/E veya A/D: seviye  ·  W/S: dünya  ·  Space: gir

signal level_chosen(level_index: int)
signal world_changed(world_slot: int)
signal advance_finished(level_index: int)

const JanitorVisualScript := preload("res://scenes3d/player/janitor_visual.gd")
const CURVE_SHADER := preload("res://shaders/map_world_curve.gdshader")
const HudIcons := preload("res://ui/hud_icons.gd")
const PATH_CURVE_SHADER := preload("res://shaders/map_path_curve.gdshader")
const OUTLINE_SHADER := preload("res://shaders/mesh_outline.gdshader")

const PATH_SPACING := 3.2
const WALK_SPEED := 5.2 ## birimler / sn — node arası yürüyüş
const NODE_PEDESTAL_R := 0.28
const NODE_GEM_R := 0.20
const CURVE_STRENGTH := 0.016
const CURVE_MAX_DROP := 16.0
## Kamera ~11 birim geride; düz alan tüm ön alanı kapsamalı (ayak altında çukur olmasın)
const CURVE_FLAT_RADIUS := 12.0
const GROUND_Y := 0.12 ## Karakter ayaklarının hemen altı
const NODE_Y := GROUND_Y + 0.07 ## Kaide merkezi (silindir height 0.14)

## Asset paths — senin dosya isimlerinle eşleşir
const PATH_MAP_BG := "res://assets/map/forest/map_bg_forest.png"
const PATH_MAP_HORIZON := "res://assets/map/forest/map_horizon_forest.png"
const PATH_MAP_GROUND := "res://assets/map/forest/map_ground_forest.png"
const PATH_TREE := [
	"res://assets/props/foliage/tree_plane_a.png",
	"res://assets/props/foliage/tree_plane_b.png",
	"res://assets/props/foliage/tree_plane_c.png",
]
const PATH_BUSH := [
	"res://assets/props/foliage/bush_plane_a.png",
	"res://assets/props/foliage/bush_plane_b.png",
]
const PATH_ROCK := [
	"res://assets/props/rocks/rock_a.png",
	"res://assets/props/rocks/rock_b.png",
]
const PATH_BOX := [
	"res://assets/props/boxes/box_cardboard_a.png",
	"res://assets/props/boxes/box_cardboard_b.png",
]

var _highest_unlocked: int = 1
var _world_slot: int = 0
var _cursor: int = 0
var _level_badges: Dictionary = {} ## level_index str → rank
var _levels: Array[int] = []
var _node_roots: Array[Node3D] = []
var _node_pos: Array[Vector3] = []
var _active: bool = false
var _palette: Dictionary = {}
var _auto_advancing: bool = false
var _wallet_coins: int = 0

var _ground: MeshInstance3D
var _ground_mat: ShaderMaterial
var _horizon: MeshInstance3D
var _horizon_mat: StandardMaterial3D
var _hills_root: Node3D
var _decor_root: Node3D
var _foliage_root: Node3D
var _path_mesh: MeshInstance3D
var _path_mat: ShaderMaterial
var _nodes_root: Node3D
var _pawn: Node3D
var _janitor: JanitorVisual
var _camera: Camera3D
var _cam_env: Environment
var _sun: DirectionalLight3D
var _hud: CanvasLayer
var _world_label: Label
var _coin_icon: TextureRect
var _coin_hud: Label
var _info: Label
var _hint: Label
var _play_btn: Button
var _prev_btn: Button
var _next_btn: Button
var _sfx: AudioStreamPlayer
var _move_tween: Tween
var _bounce_tween: Tween
var _walking: bool = false
var _game_camera: Camera3D
var _curve_mats: Array[ShaderMaterial] = []
var _cliff: MeshInstance3D
var _decor_rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_decor_rng.randomize()
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"SFX"
	_sfx.volume_db = -6.0
	add_child(_sfx)
	_build_world()
	_build_hud()
	set_active(false)


func set_game_camera(cam: Camera3D) -> void:
	_game_camera = cam


func set_active(on: bool) -> void:
	_active = on
	visible = on
	process_mode = Node.PROCESS_MODE_ALWAYS if on else Node.PROCESS_MODE_DISABLED
	if _hud != null:
		_hud.visible = on
	if _camera != null:
		_camera.current = on
	if on:
		if not _auto_advancing:
			_snap_pawn(false)
		_refresh_node_visuals()
		_refresh_labels()
		_refresh_coin_hud()
		_update_camera()
	elif _game_camera != null:
		_game_camera.current = true


func set_wallet_coins(amount: int) -> void:
	_wallet_coins = maxi(0, amount)
	_refresh_coin_hud()


## Seviye / bölüm sonrası: karakter cleared → next node'a yürür, bitince sinyal.
func play_advance(from_level: int, to_level: int, highest_unlocked: int) -> void:
	_auto_advancing = true
	_highest_unlocked = maxi(1, highest_unlocked)
	_set_nav_controls_enabled(false)
	if _hint != null:
		_hint.text = "Sonraki seviyeye geçiliyor…"
	if _play_btn != null:
		_play_btn.disabled = true
		_play_btn.text = "Geçiş…"

	var from_world := LevelData3D.world_slot_for_level(from_level)
	var to_world := LevelData3D.world_slot_for_level(to_level)

	_load_world(from_world, from_level)
	_snap_pawn(false)
	_refresh_coin_hud()
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout

	if from_world == to_world:
		var to_idx := _index_in_levels(to_level)
		if to_idx >= 0:
			_cursor = to_idx
			_refresh_node_visuals()
			_update_info()
			await _walk_pawn_to_cursor_async(true)
	else:
		# Bölüm sonu: son node'a yürü → yeni dünya → ilk hedefe yürü
		var last_idx := _levels.size() - 1
		if last_idx > _cursor:
			_cursor = last_idx
			_refresh_node_visuals()
			_update_info()
			await _walk_pawn_to_cursor_async(true)
		await get_tree().create_timer(0.2).timeout
		_load_world(to_world, to_level)
		_snap_pawn(false)
		_play_world_switch_bounce(1)
		if _bounce_tween != null and _bounce_tween.is_valid():
			await _bounce_tween.finished
		var to_idx2 := _index_in_levels(to_level)
		if to_idx2 >= 0 and to_idx2 != _cursor:
			_cursor = to_idx2
			_refresh_node_visuals()
			_update_info()
			await _walk_pawn_to_cursor_async(true)

	await get_tree().create_timer(0.35).timeout
	_auto_advancing = false
	_set_nav_controls_enabled(true)
	if _play_btn != null:
		_play_btn.text = "Gir  ·  Space"
		_update_play_enabled()
	if _hint != null:
		_hint.text = "Q/E seviye  ·  W/S dünya  ·  Space gir"
	advance_finished.emit(to_level)


func _index_in_levels(level_index: int) -> int:
	for i in _levels.size():
		if _levels[i] == level_index:
			return i
	return -1


func _set_nav_controls_enabled(on: bool) -> void:
	if _prev_btn != null:
		_prev_btn.disabled = not on or _world_slot <= 0
	if _next_btn != null:
		_next_btn.disabled = not on or _world_slot >= LevelData3D.world_count() - 1
	if _play_btn != null:
		if on:
			_update_play_enabled()
		else:
			_play_btn.disabled = true


func _refresh_coin_hud() -> void:
	if _coin_hud == null:
		return
	_coin_hud.text = "%d" % _wallet_coins


func is_map_active() -> bool:
	return _active


func setup(highest_unlocked: int, prefer_level: int = -1) -> void:
	_highest_unlocked = maxi(1, highest_unlocked)
	if prefer_level >= 0:
		_world_slot = LevelData3D.world_slot_for_level(prefer_level)
	else:
		_world_slot = _default_world_for_progress()
	_load_world(_world_slot, prefer_level)


func set_level_badges(badges: Dictionary) -> void:
	_level_badges = badges.duplicate()
	_refresh_node_visuals()


func set_highest_unlocked(n: int) -> void:
	_highest_unlocked = maxi(1, n)
	_refresh_node_visuals()
	_refresh_labels()


func _default_world_for_progress() -> int:
	var last_unlocked := clampi(_highest_unlocked - 1, 0, LevelData3D.level_count() - 1)
	return LevelData3D.world_slot_for_level(last_unlocked)


func _build_world() -> void:
	_curve_mats.clear()

	_sun = DirectionalLight3D.new()
	_sun.light_energy = 1.05
	_sun.shadow_enabled = true
	_sun.rotation_degrees = Vector3(-52, 28, 0)
	add_child(_sun)

	# Subdivided plane — vertex curve için gerekli
	_ground = MeshInstance3D.new()
	_ground.name = "Ground"
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(56, 36)
	ground_mesh.subdivide_width = 48
	ground_mesh.subdivide_depth = 32
	_ground.mesh = ground_mesh
	_ground_mat = _make_curve_mat(Color(0.22, 0.48, 0.26), PATH_MAP_GROUND, 8.0, false)
	_ground.material_override = _ground_mat
	_ground.position = Vector3(0, GROUND_Y, 0)
	add_child(_ground)

	# Kenar uçurum şeridi (eğri zeminle birlikte aşağı düşer)
	_cliff = MeshInstance3D.new()
	_cliff.name = "CliffRim"
	var cliff_mesh := PlaneMesh.new()
	cliff_mesh.size = Vector2(58, 10)
	cliff_mesh.subdivide_width = 40
	cliff_mesh.subdivide_depth = 8
	_cliff.mesh = cliff_mesh
	var cliff_mat := _make_curve_mat(Color(0.35, 0.28, 0.18), "", 1.0, false)
	_cliff.material_override = cliff_mat
	_cliff.position = Vector3(0, GROUND_Y - 0.45, -14.0)
	_cliff.rotation_degrees.x = -18.0
	add_child(_cliff)

	_hills_root = Node3D.new()
	_hills_root.name = "Hills"
	add_child(_hills_root)
	# Eski küre tepeler prototip; arka sırada plane tree
	for i in 7:
		var hp := Vector3(-18.0 + float(i) * 6.0, GROUND_Y, -8.0 - float(i % 2) * 1.8)
		ForestVegetation.spawn_plane_tree(_hills_root, hp, 6.2 + float(i % 3) * 0.7)

	_build_horizon()

	_decor_root = Node3D.new()
	_decor_root.name = "ThemeDecor"
	add_child(_decor_root)

	_foliage_root = Node3D.new()
	_foliage_root.name = "Foliage"
	add_child(_foliage_root)

	_path_mesh = MeshInstance3D.new()
	_path_mesh.name = "PathRibbon"
	_path_mat = ShaderMaterial.new()
	_path_mat.shader = PATH_CURVE_SHADER
	_path_mat.set_shader_parameter("curve_strength", CURVE_STRENGTH)
	_path_mat.set_shader_parameter("curve_max_drop", CURVE_MAX_DROP)
	_path_mat.set_shader_parameter("curve_flat_radius", CURVE_FLAT_RADIUS)
	_curve_mats.append(_path_mat)
	_path_mesh.material_override = _path_mat
	add_child(_path_mesh)

	_nodes_root = Node3D.new()
	_nodes_root.name = "LevelNodes"
	add_child(_nodes_root)

	_pawn = Node3D.new()
	_pawn.name = "MapPawn"
	add_child(_pawn)
	_janitor = JanitorVisualScript.new()
	_janitor.name = "JanitorVisual"
	_janitor.size_mult = 1.75
	_janitor.yaw_offset = 0.0
	_pawn.add_child(_janitor)
	if not _janitor.setup():
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.28
		cap.height = 1.05
		body.mesh = cap
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.35, 0.62, 0.95)
		body.material_override = pmat
		body.position.y = 0.55
		_pawn.add_child(body)
	else:
		_janitor.play_loco(&"idle", 1.0)

	_camera = Camera3D.new()
	_camera.name = "MapCamera"
	_camera.fov = 38.0
	_camera.current = false
	_cam_env = Environment.new()
	_cam_env.background_mode = Environment.BG_COLOR
	_cam_env.background_color = Color(0.55, 0.78, 0.95)
	_cam_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_cam_env.ambient_light_color = Color(0.62, 0.72, 0.55)
	_cam_env.ambient_light_energy = 0.65
	_cam_env.fog_enabled = true
	_cam_env.fog_light_color = Color(0.72, 0.85, 0.95)
	_cam_env.fog_density = 0.012
	_cam_env.fog_aerial_perspective = 0.35
	_camera.environment = _cam_env
	add_child(_camera)
	PixelLook.bind_camera(_camera)
	_palette = _palette_for_world(0)
	_apply_palette_visuals()
	_rebuild_foliage()


func _make_curve_mat(col: Color, tex_path: String = "", uv_scale: float = 6.0, with_outline: bool = true) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CURVE_SHADER
	mat.set_shader_parameter("albedo_color", col)
	mat.set_shader_parameter("curve_strength", CURVE_STRENGTH)
	mat.set_shader_parameter("curve_max_drop", CURVE_MAX_DROP)
	mat.set_shader_parameter("curve_flat_radius", CURVE_FLAT_RADIUS)
	mat.set_shader_parameter("uv_scale", uv_scale)
	mat.set_shader_parameter("roughness", 0.92)
	var tex := _try_load_tex(tex_path)
	if tex != null:
		mat.set_shader_parameter("albedo_tex", tex)
		mat.set_shader_parameter("use_texture", true)
	else:
		mat.set_shader_parameter("use_texture", false)
	if with_outline:
		_attach_outline(mat, 0.028)
	_curve_mats.append(mat)
	return mat


func _make_curve_mat_tex(col: Color, tex: Texture2D = null, uv_scale: float = 1.0) -> ShaderMaterial:
	## Sadece zemin / cliff / tepe — prop’larda kullanma (UV kaybı).
	var mat := ShaderMaterial.new()
	mat.shader = CURVE_SHADER
	mat.set_shader_parameter("albedo_color", col)
	mat.set_shader_parameter("curve_strength", CURVE_STRENGTH)
	mat.set_shader_parameter("curve_max_drop", CURVE_MAX_DROP)
	mat.set_shader_parameter("curve_flat_radius", CURVE_FLAT_RADIUS)
	mat.set_shader_parameter("uv_scale", uv_scale)
	mat.set_shader_parameter("roughness", 0.92)
	if tex != null:
		mat.set_shader_parameter("albedo_tex", tex)
		mat.set_shader_parameter("use_texture", true)
	else:
		mat.set_shader_parameter("use_texture", false)
	_attach_outline(mat, 0.03)
	_curve_mats.append(mat)
	return mat


## Prop material — StandardMaterial (curve shader sampler/UV sorununu bypass)
func _make_prop_mat(col: Color, tex: Texture2D = null, outline_w: float = 0.03) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE if tex != null else col
	if tex != null:
		m.albedo_texture = tex
	m.roughness = 0.9
	m.metallic = 0.0
	_attach_outline(m, outline_w)
	return m


func _ensure_mesh_outline(mi: MeshInstance3D, width: float) -> void:
	if mi == null:
		return
	if mi.material_override != null:
		_attach_outline(mi.material_override, width)
		return
	if mi.mesh == null:
		return
	for si in mi.mesh.get_surface_count():
		var mat := mi.get_active_material(si)
		if mat == null:
			mat = mi.mesh.surface_get_material(si)
		if mat == null:
			continue
		var dup := mat.duplicate()
		_attach_outline(dup, width)
		mi.set_surface_override_material(si, dup)


func _snap_node_to_ground(node: Node3D, ground_y: float = -1.0) -> void:
	if node == null:
		return
	if ground_y < 0.0:
		ground_y = GROUND_Y
	var aabb := AABB()
	var first := true
	var meshes: Array = []
	if node is MeshInstance3D:
		meshes.append(node)
	meshes.append_array(node.find_children("*", "MeshInstance3D", true, false))
	for n in meshes:
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var a: AABB = mi.global_transform * mi.mesh.get_aabb()
		if first:
			aabb = a
			first = false
		else:
			aabb = aabb.merge(a)
	if first:
		return
	node.global_position.y += ground_y - aabb.position.y


## GLB sahnesini koruyarak spawn (gömülü material kalır).
func _try_spawn_packed_prop(
	parent: Node3D,
	pick: Dictionary,
	pos: Vector3,
	xform: Dictionary,
	target_size: float,
	flip_x: float = 0.0,
) -> bool:
	var packed: PackedScene = pick.get("scene") as PackedScene
	if packed == null or parent == null:
		return false
	var root := packed.instantiate() as Node3D
	if root == null:
		return false
	parent.add_child(root)
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		meshes.append(root as MeshInstance3D)
	for c in root.find_children("*", "MeshInstance3D", true, false):
		meshes.append(c as MeshInstance3D)
	var combined := AABB()
	var first := true
	var tex: Texture2D = pick.get("texture") as Texture2D
	for mi in meshes:
		if mi.mesh == null:
			continue
		var local_aabb: AABB = mi.transform * mi.mesh.get_aabb()
		if first:
			combined = local_aabb
			first = false
		else:
			combined = combined.merge(local_aabb)
		_ensure_mesh_outline(mi, 0.028)
		# Gömülü albedo yoksa katalog texture’ı bas
		var has_alb := false
		if mi.material_override is BaseMaterial3D:
			has_alb = (mi.material_override as BaseMaterial3D).albedo_texture != null
		elif mi.mesh.get_surface_count() > 0:
			var sm := mi.get_active_material(0)
			if sm is BaseMaterial3D and (sm as BaseMaterial3D).albedo_texture != null:
				has_alb = true
		if not has_alb and tex != null:
			mi.material_override = _make_prop_mat(Color.WHITE, tex, 0.028)
	var max_dim := maxf(combined.size.x, maxf(combined.size.y, combined.size.z))
	var sc_mul := 1.0
	var raw_sc = xform.get("scale", 1.0)
	if typeof(raw_sc) == TYPE_FLOAT or typeof(raw_sc) == TYPE_INT:
		sc_mul = float(raw_sc)
	elif typeof(raw_sc) == TYPE_VECTOR3:
		sc_mul = ((raw_sc as Vector3).x + (raw_sc as Vector3).y + (raw_sc as Vector3).z) / 3.0
	if max_dim > 0.001:
		root.scale = Vector3.ONE * ((target_size / max_dim) * sc_mul)
	root.rotation = Vector3(
		flip_x + float(xform.get("tilt_x", 0.0)) * 0.35,
		float(xform.get("yaw", 0.0)),
		float(xform.get("tilt_z", 0.0)) * 0.35
	)
	root.position = Vector3(pos.x, 0.0, pos.z)
	_snap_node_to_ground(root)
	return true


func _attach_outline(mat: Material, width: float = 0.03) -> void:
	if mat == null:
		return
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter("outline_color", Color(0.06, 0.04, 0.09, 1.0))
	outline.set_shader_parameter("outline_width", width)
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).next_pass = outline
	elif mat is BaseMaterial3D:
		(mat as BaseMaterial3D).next_pass = outline


## Mesh tabanını ground_y’ye oturt (parent local).
func _snap_mesh_to_ground(mi: MeshInstance3D, ground_y: float = -1.0) -> void:
	if mi == null or mi.mesh == null:
		return
	if ground_y < 0.0:
		ground_y = GROUND_Y
	# mesh AABB + node transform (scale/rot) → tabanı yere yapıştır
	var mesh_aabb := mi.mesh.get_aabb()
	var world_aabb := mi.transform * mesh_aabb
	mi.position.y += ground_y - world_aabb.position.y


func _try_load_tex(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _make_sky_fallback_tex() -> Texture2D:
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var top := Color(0.52, 0.76, 0.94)
	var mid := Color(0.78, 0.86, 0.72)
	var bot := Color(0.22, 0.42, 0.20)
	for y in 32:
		var t := float(y) / 31.0
		var col: Color
		if t < 0.62:
			col = top.lerp(mid, t / 0.62)
		else:
			col = mid.lerp(bot, (t - 0.62) / 0.38)
		for x in 64:
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _build_horizon() -> void:
	## Ayrı ufuk katmanı — eğrilmez; sky + distant hills billboard
	_horizon = MeshInstance3D.new()
	_horizon.name = "HorizonSky"
	var quad := QuadMesh.new()
	quad.size = Vector2(90, 32)
	_horizon.mesh = quad
	_horizon_mat = StandardMaterial3D.new()
	_horizon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_horizon_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_horizon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var bg := _try_load_tex(PATH_MAP_BG)
	var sil := _try_load_tex(PATH_MAP_HORIZON)
	if bg != null:
		_horizon_mat.albedo_texture = bg
		_horizon_mat.albedo_color = Color.WHITE
	elif sil != null:
		_horizon_mat.albedo_texture = sil
		_horizon_mat.albedo_color = Color.WHITE
	else:
		_horizon_mat.albedo_texture = _make_sky_fallback_tex()
		_horizon_mat.albedo_color = Color.WHITE
	_horizon.material_override = _horizon_mat
	# QuadMesh -Z bakar; kamera +Z'den -Z'ye bakıyor → ufuk önde
	_horizon.position = Vector3(0, 8.5, -28.0)
	add_child(_horizon)


func _push_curve_cam() -> void:
	## Eğri merkezi = karakter/odak — kameraya göre düşerse zemin ayakların altında kalır
	var focus := Vector3.ZERO
	if _pawn != null:
		focus = _pawn.global_position
	elif _camera != null:
		focus = _camera.global_position
	for mat in _curve_mats:
		if mat != null:
			mat.set_shader_parameter("curve_cam_pos", focus)
			mat.set_shader_parameter("curve_flat_radius", CURVE_FLAT_RADIUS)


func _rebuild_foliage() -> void:
	if _foliage_root == null:
		return
	for c in _foliage_root.get_children():
		c.queue_free()
	PropCatalog3D.refresh()
	var leaf_tint: Color = _palette.get("hill", Color(0.22, 0.48, 0.22))
	var grass_tint: Color = _palette.get("ground", Color(0.18, 0.52, 0.24)).lerp(Color(0.12, 0.62, 0.20), 0.45)
	var flower_tint: Color = _palette.get("accent", Color(0.95, 0.85, 0.4))
	ForestVegetation.fill_world_map(_foliage_root, GROUND_Y, leaf_tint, grass_tint, _decor_rng, flower_tint)
	# Kayalar — düz mesh + katalog RNG
	var rock_spots: Array[Vector3] = [
		Vector3(-5.2, 0, 3.2), Vector3(6.4, 0, 3.0), Vector3(-7.8, 0, -2.2),
		Vector3(8.0, 0, -2.8), Vector3(-3.0, 0, -4.5), Vector3(3.5, 0, -4.2),
		Vector3(-10.5, 0, 3.5), Vector3(10.8, 0, 1.5),
	]
	for i in rock_spots.size():
		var pick: Dictionary = PropCatalog3D.pick_rock(_decor_rng)
		var xform: Dictionary = PropCatalog3D.roll_rock_xform(_decor_rng)
		if pick.is_empty():
			continue
		_spawn_catalog_rock(pick, rock_spots[i], xform)


func _spawn_billboard(tex: Texture2D, pos: Vector3, size: Vector2) -> void:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.35
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_attach_outline(mat, 0.035)
	mi.material_override = mat
	mi.position = Vector3(pos.x, GROUND_Y + size.y * 0.5, pos.z)
	_foliage_root.add_child(mi)


func _spawn_catalog_rock(pick: Dictionary, pos: Vector3, xform: Dictionary) -> void:
	var target := 0.85
	if _try_spawn_packed_prop(_foliage_root, pick, pos, xform, target):
		return
	var rock := MeshInstance3D.new()
	var custom: Mesh = pick.get("mesh") as Mesh
	var tex: Texture2D = pick.get("texture") as Texture2D
	if tex == null and custom != null:
		tex = _texture_from_mesh(custom)
	if custom == null:
		return
	rock.mesh = custom
	var tint := Color.WHITE if tex != null else Color(0.48, 0.46, 0.42)
	rock.material_override = _make_prop_mat(tint, tex, 0.028)
	var sc: Vector3 = xform.get("scale", Vector3(1.2, 0.7, 1.1))
	if custom != null:
		var aabb := custom.get_aabb()
		var sz := aabb.size
		if sz.x > 0.001:
			var uni := target / maxf(sz.x, maxf(sz.y, sz.z))
			sc *= uni
	rock.scale = sc
	rock.rotation = Vector3(
		float(xform.get("tilt_x", 0.0)) * 0.5,
		float(xform.get("yaw", 0.0)),
		float(xform.get("tilt_z", 0.0)) * 0.5
	)
	rock.position = Vector3(pos.x, 0.0, pos.z)
	_foliage_root.add_child(rock)
	_snap_mesh_to_ground(rock)


func _texture_from_mesh(mesh: Mesh) -> Texture2D:
	if mesh == null:
		return null
	for si in mesh.get_surface_count():
		var mat := mesh.surface_get_material(si)
		if mat is StandardMaterial3D:
			var t := (mat as StandardMaterial3D).albedo_texture
			if t != null:
				return t
		if mat is BaseMaterial3D:
			var t2 := (mat as BaseMaterial3D).albedo_texture
			if t2 != null:
				return t2
		if mat is ShaderMaterial:
			var sm := mat as ShaderMaterial
			var t3 = sm.get_shader_parameter("albedo_texture")
			if t3 is Texture2D:
				return t3 as Texture2D
			t3 = sm.get_shader_parameter("albedo_tex")
			if t3 is Texture2D:
				return t3 as Texture2D
	return null


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 12
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hud)

	_world_label = Label.new()
	_world_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world_label.anchor_right = 1.0
	_world_label.offset_top = 258.0
	_world_label.offset_bottom = 292.0
	_world_label.add_theme_font_size_override("font_size", 28)
	_world_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	_world_label.add_theme_color_override("font_outline_color", Color(0.08, 0.1, 0.08, 0.95))
	_world_label.add_theme_constant_override("outline_size", 8)
	_hud.add_child(_world_label)

	var coin_row := HBoxContainer.new()
	coin_row.name = "MapCoinRow"
	coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_row.anchor_left = 0.5
	coin_row.anchor_right = 0.5
	coin_row.offset_left = -90.0
	coin_row.offset_right = 90.0
	coin_row.offset_top = 292.0
	coin_row.offset_bottom = 322.0
	coin_row.add_theme_constant_override("separation", 8)
	coin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(coin_row)

	_coin_icon = HudIcons.make_rect("coin", Vector2(28, 28))
	_coin_icon.name = "MapCoinIcon"
	coin_row.add_child(_coin_icon)

	_coin_hud = Label.new()
	_coin_hud.name = "MapCoinHud"
	_coin_hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coin_hud.add_theme_font_size_override("font_size", 26)
	_coin_hud.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_coin_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_coin_hud.add_theme_constant_override("outline_size", 7)
	_coin_hud.text = "0"
	coin_row.add_child(_coin_hud)

	_prev_btn = Button.new()
	_prev_btn.text = "◀ Dünya"
	_prev_btn.focus_mode = Control.FOCUS_NONE
	_prev_btn.offset_left = 24.0
	_prev_btn.offset_top = 286.0
	_prev_btn.offset_right = 140.0
	_prev_btn.offset_bottom = 322.0
	_prev_btn.pressed.connect(func() -> void: _shift_world(-1))
	_hud.add_child(_prev_btn)

	_next_btn = Button.new()
	_next_btn.text = "Dünya ▶"
	_next_btn.focus_mode = Control.FOCUS_NONE
	_next_btn.anchor_left = 1.0
	_next_btn.anchor_right = 1.0
	_next_btn.offset_left = -140.0
	_next_btn.offset_right = -24.0
	_next_btn.offset_top = 286.0
	_next_btn.offset_bottom = 322.0
	_next_btn.pressed.connect(func() -> void: _shift_world(1))
	_hud.add_child(_next_btn)

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.anchor_left = 0.0
	_info.anchor_right = 1.0
	_info.anchor_top = 1.0
	_info.anchor_bottom = 1.0
	_info.offset_left = 48.0
	_info.offset_right = -48.0
	_info.offset_top = -150.0
	_info.offset_bottom = -78.0
	_info.add_theme_font_size_override("font_size", 20)
	_info.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0))
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_info.add_theme_constant_override("outline_size", 6)
	_hud.add_child(_info)

	_play_btn = Button.new()
	_play_btn.text = "Gir  ·  Space"
	_play_btn.focus_mode = Control.FOCUS_NONE
	_play_btn.anchor_left = 0.5
	_play_btn.anchor_right = 0.5
	_play_btn.anchor_top = 1.0
	_play_btn.anchor_bottom = 1.0
	_play_btn.offset_left = -150.0
	_play_btn.offset_right = 150.0
	_play_btn.offset_top = -68.0
	_play_btn.offset_bottom = -24.0
	_play_btn.pressed.connect(_try_enter_level)
	_hud.add_child(_play_btn)

	_hint = Label.new()
	_hint.text = "Q/E seviye  ·  W/S dünya  ·  Space gir"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -178.0
	_hint.offset_bottom = -152.0
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_hint.add_theme_constant_override("outline_size", 4)
	_hud.add_child(_hint)


func _process(_delta: float) -> void:
	if not _active:
		return
	_update_camera()
	_push_curve_cam()
	if _horizon != null and _camera != null:
		# Horizon kamerayı X'te takip eder; Z/Y sabit — eğrilmez
		var hp := _horizon.global_position
		hp.x = _camera.global_position.x
		_horizon.global_position = hp


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _auto_advancing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode
		if key == KEY_NONE:
			key = event.keycode
		match key:
			KEY_Q, KEY_A:
				_move_cursor(-1)
				get_viewport().set_input_as_handled()
			KEY_E, KEY_D:
				_move_cursor(1)
				get_viewport().set_input_as_handled()
			KEY_W:
				_shift_world(-1)
				get_viewport().set_input_as_handled()
			KEY_S:
				_shift_world(1)
				get_viewport().set_input_as_handled()
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				_try_enter_level()
				get_viewport().set_input_as_handled()
		return
	# interact (E / sol tık) haritada seviye BAŞLATMASIN — sadece Space
	if event.is_action_pressed("ui_accept"):
		_try_enter_level()
		get_viewport().set_input_as_handled()


func _shift_world(dir: int) -> void:
	if _auto_advancing:
		return
	var max_w := LevelData3D.world_count() - 1
	var next := _world_slot + dir
	if next < 0 or next > max_w:
		PrototypeSfx.play(_sfx, PrototypeSfx.Kind.SWITCH, 0.8)
		return
	if not _world_has_unlocked(next) and next != 0:
		PrototypeSfx.play(_sfx, PrototypeSfx.Kind.TASK_FAIL, 1.3)
		return
	_load_world(next, -1) # bölüm değişince ilk açık seviyeden
	_play_world_switch_bounce(dir)
	world_changed.emit(_world_slot)
	PrototypeSfx.play(_sfx, PrototypeSfx.Kind.SWITCH, 1.0)


func _world_has_unlocked(slot: int) -> bool:
	for li in LevelData3D.level_indices_for_world(slot):
		if LevelData3D.is_level_unlocked(li, _highest_unlocked):
			return true
	return false


func _load_world(slot: int, prefer_level: int = -1) -> void:
	_world_slot = clampi(slot, 0, LevelData3D.world_count() - 1)
	_levels = LevelData3D.level_indices_for_world(_world_slot)
	_cursor = 0
	if prefer_level >= 0:
		var found := false
		for i in _levels.size():
			if _levels[i] == prefer_level:
				_cursor = i
				found = true
				break
		if not found:
			_cursor = _first_unlocked_cursor()
	else:
		_cursor = _first_unlocked_cursor()
	_palette = _palette_for_world(_world_slot)
	_apply_palette_visuals()
	_rebuild_theme_decor()
	_rebuild_nodes()
	_snap_pawn(false)
	_refresh_labels()


func get_world_slot() -> int:
	return _world_slot


func _first_unlocked_cursor() -> int:
	for i in _levels.size():
		if LevelData3D.is_level_unlocked(_levels[i], _highest_unlocked):
			return i
	return 0


func _rebuild_nodes() -> void:
	for c in _nodes_root.get_children():
		c.queue_free()
	_node_roots.clear()
	_node_pos.clear()
	var n := _levels.size()
	if n <= 0:
		_rebuild_path_mesh()
		return
	var start_x := -PATH_SPACING * float(n - 1) * 0.5
	for i in n:
		var t := 0.0 if n == 1 else float(i) / float(n - 1)
		var x := start_x + float(i) * PATH_SPACING
		var z := sin(t * PI * 1.1 + float(_world_slot) * 0.4) * 1.6
		if i == n - 1 and n >= 4:
			z -= 0.85
		var pos := Vector3(x, NODE_Y, z)
		_node_pos.append(pos)
		var root := _make_node_visual(i)
		root.position = pos
		_nodes_root.add_child(root)
		_node_roots.append(root)
	_rebuild_path_mesh()
	_refresh_node_visuals()


## Her level'a deterministik görsel çeşitlilik — base (pedestal) şekli/yön/renk tonu.
## level_id'ye bağlı olduğundan sabit kalır (rebuild'lerde titremez).
func _pedestal_style(level_id: int) -> Dictionary:
	var sides_arr := [64, 6, 8, 4, 5, 3, 12]
	var taper_arr := [0.06, 0.0, -0.05, 0.1]
	var info := LevelData3D.get_level(level_id)
	var is_boss := bool(info.get("is_boss_room", false))
	return {
		"sides": int(sides_arr[level_id % sides_arr.size()]),
		"height": 0.12 + float((level_id * 7) % 4) * 0.025,
		"top_delta": float(taper_arr[(level_id >> 1) % taper_arr.size()]),
		"radius_mul": 1.28 if is_boss else 1.0,
		"yaw": float(level_id % 6) * 0.26,
		"hue_rot": (float((level_id * 3) % 7) - 3.0) * 0.016,
		"val_mul": 0.92 + float((level_id * 5) % 5) * 0.04,
		"sat_mul": 0.85 + float((level_id * 11) % 4) * 0.1,
	}


func _make_node_visual(index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Node_%d" % index
	var level_id: int = _levels[index] if index < _levels.size() else index
	var style := _pedestal_style(level_id)
	var rmul: float = style["radius_mul"]
	var ped_h: float = style["height"]
	var pedestal := MeshInstance3D.new()
	pedestal.name = "Pedestal"
	var cyl := CylinderMesh.new()
	cyl.top_radius = (NODE_PEDESTAL_R + float(style["top_delta"])) * rmul
	cyl.bottom_radius = (NODE_PEDESTAL_R + 0.04) * rmul
	cyl.height = ped_h
	cyl.radial_segments = int(style["sides"])
	pedestal.mesh = cyl
	pedestal.position.y = 0.0
	pedestal.rotation.y = float(style["yaw"])
	root.add_child(pedestal)
	var gem := MeshInstance3D.new()
	gem.name = "Gem"
	var sph := SphereMesh.new()
	sph.radius = NODE_GEM_R
	sph.height = NODE_GEM_R * 2.0
	gem.mesh = sph
	gem.position.y = ped_h * 0.5 + 0.21
	root.add_child(gem)
	var label := Label3D.new()
	label.name = "Tag"
	label.font_size = 28
	label.position = Vector3(0, 0.62, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	root.add_child(label)
	return root


func _rebuild_path_mesh() -> void:
	if _path_mesh == null:
		return
	if _node_pos.size() < 2:
		_path_mesh.mesh = null
		return
	var path_on: Color = _palette.get("path", Color(0.95, 0.8, 0.35))
	var path_off: Color = _palette.get("path_locked", Color(0.35, 0.38, 0.36))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(_node_pos.size() - 1):
		var a: Vector3 = _node_pos[i]
		var b: Vector3 = _node_pos[i + 1]
		var unlocked_edge := LevelData3D.is_level_unlocked(_levels[mini(i + 1, _levels.size() - 1)], _highest_unlocked)
		var col := path_on if unlocked_edge else path_off
		_add_path_quad(st, a, b, 0.38, col)
	_path_mesh.mesh = st.commit()
	if _path_mat == null:
		_path_mat = ShaderMaterial.new()
		_path_mat.shader = PATH_CURVE_SHADER
		_path_mat.set_shader_parameter("curve_strength", CURVE_STRENGTH)
		_path_mat.set_shader_parameter("curve_max_drop", CURVE_MAX_DROP)
		_path_mat.set_shader_parameter("curve_flat_radius", CURVE_FLAT_RADIUS)
		_curve_mats.append(_path_mat)
	_path_mesh.material_override = _path_mat


func _add_path_quad(st: SurfaceTool, a: Vector3, b: Vector3, half_w: float, col: Color) -> void:
	var dir := (b - a)
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	var side := Vector3(-dir.z, 0.0, dir.x) * half_w
	var y := GROUND_Y + 0.03
	var p0 := Vector3(a.x, y, a.z) - side
	var p1 := Vector3(a.x, y, a.z) + side
	var p2 := Vector3(b.x, y, b.z) + side
	var p3 := Vector3(b.x, y, b.z) - side
	st.set_color(col)
	st.set_normal(Vector3.UP)
	st.add_vertex(p0)
	st.add_vertex(p1)
	st.add_vertex(p2)
	st.add_vertex(p0)
	st.add_vertex(p2)
	st.add_vertex(p3)


func _refresh_node_visuals() -> void:
	var col_locked: Color = _palette.get("node_locked", Color(0.45, 0.45, 0.48))
	var col_open: Color = _palette.get("node", Color(0.92, 0.32, 0.28))
	var col_clear: Color = _palette.get("node_clear", Color(0.35, 0.85, 0.45))
	var col_boss: Color = _palette.get("node_boss", Color(0.95, 0.5, 0.3))
	var ped_col: Color = _palette.get("pedestal", Color(0.55, 0.5, 0.42))
	for i in _node_roots.size():
		var root := _node_roots[i]
		if not is_instance_valid(root):
			continue
		var li: int = _levels[i]
		var unlocked := LevelData3D.is_level_unlocked(li, _highest_unlocked)
		var cleared := LevelData3D.is_level_cleared(li, _highest_unlocked)
		var info := LevelData3D.get_level(li)
		var is_boss := bool(info.get("is_boss_room", false))
		var selected := i == _cursor
		var fill := col_locked
		if unlocked:
			fill = col_boss if is_boss else col_open
			if cleared:
				fill = col_clear
		var ped := root.get_node_or_null("Pedestal") as MeshInstance3D
		if ped != null:
			var style := _pedestal_style(li)
			var pc := ped_col
			pc.h = fposmod(pc.h + float(style["hue_rot"]), 1.0)
			pc.s = clampf(pc.s * float(style["sat_mul"]), 0.0, 1.0)
			pc.v = clampf(pc.v * float(style["val_mul"]), 0.05, 1.0)
			var pmat := StandardMaterial3D.new()
			pmat.albedo_color = pc.darkened(0.15 if not unlocked else 0.0)
			ped.material_override = pmat
		var gem := root.get_node_or_null("Gem") as MeshInstance3D
		if gem != null:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = fill
			mat.emission_enabled = selected or unlocked
			mat.emission = fill
			mat.emission_energy_multiplier = 1.55 if selected else 0.45
			gem.material_override = mat
			gem.scale = Vector3.ONE * (1.22 if selected else 1.0)
		var tag := root.get_node_or_null("Tag") as Label3D
		if tag != null:
			var best_b := int(_level_badges.get(str(li), BadgeRating3D.Rank.NONE))
			if not unlocked:
				tag.text = "🔒"
			elif best_b >= BadgeRating3D.Rank.BRONZE:
				tag.text = BadgeRating3D.icon(best_b)
			elif cleared:
				tag.text = "★"
			elif is_boss:
				tag.text = "🏰"
			elif bool(info.get("tutorial_level", false)):
				tag.text = String(info.get("icon", "📘"))
			else:
				tag.text = str(int(info.get("tier", i)) + 1)
	_rebuild_path_mesh()


func _refresh_labels() -> void:
	if _world_label != null:
		_world_label.text = LevelData3D.world_title(_world_slot)
		var ac: Color = _palette.get("accent", Color(1.0, 0.92, 0.45))
		_world_label.add_theme_color_override("font_color", ac)
	_update_info()
	if _auto_advancing:
		_set_nav_controls_enabled(false)
	else:
		_update_play_enabled()
		if _prev_btn != null:
			_prev_btn.disabled = _world_slot <= 0
		if _next_btn != null:
			_next_btn.disabled = _world_slot >= LevelData3D.world_count() - 1
	_refresh_coin_hud()


func _current_level_index() -> int:
	if _cursor < 0 or _cursor >= _levels.size():
		return -1
	return _levels[_cursor]


func _update_info() -> void:
	if _info == null:
		return
	var li := _current_level_index()
	if li < 0:
		_info.text = ""
		return
	var info := LevelData3D.get_level(li)
	var unlocked := LevelData3D.is_level_unlocked(li, _highest_unlocked)
	var cleared := LevelData3D.is_level_cleared(li, _highest_unlocked)
	var status := "🔒 Kilitli"
	if unlocked:
		status = "✅ Temizlendi" if cleared else "▶ Hazır"
	_info.text = "%s\n%s\n%s" % [
		String(info.get("name", "Seviye")),
		String(info.get("subtitle", "")),
		status,
	]


func _update_play_enabled() -> void:
	var li := _current_level_index()
	var ok := li >= 0 and LevelData3D.is_level_unlocked(li, _highest_unlocked)
	if _play_btn != null:
		_play_btn.disabled = not ok
		_play_btn.modulate = Color.WHITE if ok else Color(0.6, 0.6, 0.65, 0.85)


func _move_cursor(dir: int) -> void:
	if _auto_advancing or _levels.is_empty():
		return
	var next := _cursor + dir
	if next < 0 or next >= _levels.size():
		PrototypeSfx.play(_sfx, PrototypeSfx.Kind.SWITCH, 0.85)
		return
	if not LevelData3D.is_level_unlocked(_levels[next], _highest_unlocked):
		PrototypeSfx.play(_sfx, PrototypeSfx.Kind.TASK_FAIL, 1.35)
		return
	_cursor = next
	_walk_pawn_to_cursor(true)
	_refresh_node_visuals()
	_update_info()
	_update_play_enabled()
	PrototypeSfx.play(_sfx, PrototypeSfx.Kind.SWITCH, 1.15)


func _pawn_stand_pos(idx: int) -> Vector3:
	if idx < 0 or idx >= _node_pos.size():
		return Vector3.ZERO
	var p: Vector3 = _node_pos[idx]
	return Vector3(p.x, 0.0, p.z)


func _walk_pawn_to_cursor_async(animate: bool) -> void:
	_walk_pawn_to_cursor(animate)
	if not animate:
		return
	if _move_tween != null and _move_tween.is_valid():
		await _move_tween.finished


func _walk_pawn_to_cursor(animate: bool) -> void:
	if _pawn == null or _cursor < 0 or _cursor >= _node_pos.size():
		return
	var target := _pawn_stand_pos(_cursor)
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	if not animate:
		_walking = false
		_pawn.position = target
		_play_janitor_idle()
		return
	var from := _pawn.position
	var flat := Vector3(target.x - from.x, 0.0, target.z - from.z)
	var dist := flat.length()
	if dist < 0.04:
		_walking = false
		_pawn.position = target
		_play_janitor_idle()
		return
	_face_direction(flat)
	_play_janitor_run(clampf(dist / 2.5, 0.95, 1.35))
	_walking = true
	var dur := clampf(dist / WALK_SPEED, 0.32, 1.1)
	_move_tween = create_tween()
	_move_tween.tween_property(_pawn, "position", target, dur)\
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	_move_tween.finished.connect(_on_pawn_walk_finished)


func _on_pawn_walk_finished() -> void:
	_walking = false
	_play_janitor_idle()


func _face_direction(dir: Vector3) -> void:
	if _pawn == null or dir.length_squared() < 0.0001:
		return
	# Model +Z bakıyorsa atan2(x,z); ters ise +PI
	_pawn.rotation.y = atan2(dir.x, dir.z)


func _play_janitor_run(speed: float = 1.15) -> void:
	if _janitor != null and _janitor.is_ready_visual():
		_janitor.play_loco(&"run", speed)


func _play_janitor_idle() -> void:
	if _janitor != null and _janitor.is_ready_visual():
		_janitor.play_loco(&"idle", 1.0)


func _snap_pawn(animate: bool) -> void:
	_walk_pawn_to_cursor(animate)


func _play_world_switch_bounce(dir: int = 1) -> void:
	if _pawn == null:
		return
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
		_walking = false
	var base := _pawn_stand_pos(_cursor) if _cursor >= 0 and _cursor < _node_pos.size() else _pawn.position
	_pawn.position = base
	_pawn.scale = Vector3.ONE
	_pawn.rotation.y += float(dir) * 0.2
	_bounce_tween = create_tween()
	# Hafif squash
	_bounce_tween.tween_property(_pawn, "scale", Vector3(1.08, 0.9, 1.08), 0.05)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Küçük hop
	_bounce_tween.tween_property(_pawn, "scale", Vector3(0.96, 1.08, 0.96), 0.07)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bounce_tween.parallel().tween_property(_pawn, "position:y", base.y + 0.28, 0.09)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Yumuşak iniş
	_bounce_tween.tween_property(_pawn, "position:y", base.y, 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_bounce_tween.parallel().tween_property(_pawn, "scale", Vector3.ONE, 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_callback(func() -> void:
		if _pawn != null:
			_pawn.scale = Vector3.ONE
			_pawn.position = base
		_play_janitor_idle()
	)


func _try_enter_level() -> void:
	if not _active or _auto_advancing:
		return
	var li := _current_level_index()
	if li < 0:
		return
	if not LevelData3D.is_level_unlocked(li, _highest_unlocked):
		PrototypeSfx.play(_sfx, PrototypeSfx.Kind.TASK_FAIL, 1.2)
		return
	PrototypeSfx.play(_sfx, PrototypeSfx.Kind.TASK_OK, 1.1)
	level_chosen.emit(li)


func _update_camera() -> void:
	if _camera == null:
		return
	var focus := Vector3.ZERO
	if _pawn != null:
		focus = _pawn.global_position
	elif _cursor >= 0 and _cursor < _node_pos.size():
		focus = _node_pos[_cursor]
	elif not _node_pos.is_empty():
		focus = _node_pos[int(_node_pos.size() * 0.5)]
	# NSMB / AC tarzı: daha alçak, arkadan bakış — ufuk görünür
	var desired := focus + Vector3(0.0, 7.2, 11.5)
	_camera.global_position = _camera.global_position.lerp(desired, 0.14)
	_camera.look_at(focus + Vector3(0, 0.55, -1.5), Vector3.UP)


func _palette_for_world(slot: int) -> Dictionary:
	# Eğitim / orman hub
	if slot <= 0:
		return {
			"id": "tutorial",
			"sky": Color(0.58, 0.82, 0.95),
			"ambient": Color(0.62, 0.75, 0.55),
			"ground": Color(0.28, 0.52, 0.28),
			"hill": Color(0.2, 0.42, 0.24),
			"path": Color(0.92, 0.78, 0.42),
			"path_locked": Color(0.42, 0.45, 0.38),
			"node": Color(0.88, 0.42, 0.28),
			"node_clear": Color(0.4, 0.85, 0.45),
			"node_boss": Color(0.95, 0.55, 0.25),
			"node_locked": Color(0.42, 0.45, 0.4),
			"pedestal": Color(0.55, 0.48, 0.36),
			"accent": Color(0.95, 0.85, 0.4),
			"sun": 1.1,
			"fog": Color(0.75, 0.88, 0.95),
		}
	var themes: Dictionary = {
		"liquids": {
			"sky": Color(0.42, 0.68, 0.88), "ambient": Color(0.5, 0.7, 0.85),
			"ground": Color(0.28, 0.34, 0.4), "hill": Color(0.22, 0.3, 0.38),
			"path": Color(0.45, 0.85, 1.0), "path_locked": Color(0.3, 0.4, 0.45),
			"node": Color(0.35, 0.75, 0.95), "node_clear": Color(0.4, 0.9, 0.75),
			"node_boss": Color(0.2, 0.55, 0.9), "pedestal": Color(0.45, 0.55, 0.62),
			"accent": Color(0.45, 0.85, 1.0), "sun": 1.1,
		},
		"mold": {
			"sky": Color(0.35, 0.55, 0.38), "ambient": Color(0.4, 0.55, 0.4),
			"ground": Color(0.16, 0.28, 0.18), "hill": Color(0.12, 0.22, 0.14),
			"path": Color(0.55, 0.9, 0.4), "path_locked": Color(0.28, 0.35, 0.28),
			"node": Color(0.45, 0.9, 0.35), "node_clear": Color(0.7, 0.95, 0.4),
			"node_boss": Color(0.25, 0.7, 0.2), "pedestal": Color(0.3, 0.4, 0.28),
			"accent": Color(0.45, 0.95, 0.4), "sun": 0.9,
		},
		"broom": {
			"sky": Color(0.72, 0.58, 0.4), "ambient": Color(0.7, 0.6, 0.45),
			"ground": Color(0.32, 0.22, 0.14), "hill": Color(0.26, 0.18, 0.12),
			"path": Color(0.95, 0.75, 0.4), "path_locked": Color(0.4, 0.32, 0.25),
			"node": Color(0.9, 0.65, 0.3), "node_clear": Color(0.85, 0.85, 0.45),
			"node_boss": Color(0.85, 0.45, 0.2), "pedestal": Color(0.45, 0.35, 0.25),
			"accent": Color(0.95, 0.72, 0.35), "sun": 1.15,
		},
		"slime": {
			"sky": Color(0.3, 0.55, 0.5), "ambient": Color(0.35, 0.6, 0.55),
			"ground": Color(0.12, 0.26, 0.24), "hill": Color(0.1, 0.2, 0.18),
			"path": Color(0.4, 1.0, 0.75), "path_locked": Color(0.25, 0.35, 0.32),
			"node": Color(0.3, 0.95, 0.7), "node_clear": Color(0.55, 1.0, 0.8),
			"node_boss": Color(0.15, 0.75, 0.55), "pedestal": Color(0.25, 0.4, 0.38),
			"accent": Color(0.35, 1.0, 0.72), "sun": 0.95,
		},
		"brush": {
			"sky": Color(0.55, 0.35, 0.7), "ambient": Color(0.55, 0.4, 0.7),
			"ground": Color(0.32, 0.18, 0.4), "hill": Color(0.26, 0.14, 0.34),
			"path": Color(0.9, 0.45, 1.0), "path_locked": Color(0.4, 0.3, 0.45),
			"node": Color(0.85, 0.4, 0.95), "node_clear": Color(0.7, 0.55, 1.0),
			"node_boss": Color(0.7, 0.25, 0.85), "pedestal": Color(0.4, 0.28, 0.48),
			"accent": Color(0.85, 0.4, 1.0), "sun": 1.0,
		},
		"spray": {
			"sky": Color(0.35, 0.55, 0.78), "ambient": Color(0.4, 0.6, 0.8),
			"ground": Color(0.14, 0.22, 0.32), "hill": Color(0.12, 0.18, 0.28),
			"path": Color(0.45, 0.9, 1.0), "path_locked": Color(0.28, 0.35, 0.42),
			"node": Color(0.4, 0.85, 1.0), "node_clear": Color(0.55, 0.95, 0.9),
			"node_boss": Color(0.25, 0.65, 0.95), "pedestal": Color(0.3, 0.4, 0.5),
			"accent": Color(0.4, 0.85, 1.0), "sun": 1.05,
		},
		"alien": {
			"sky": Color(0.12, 0.22, 0.18), "ambient": Color(0.28, 0.45, 0.32),
			"ground": Color(0.1, 0.16, 0.12), "hill": Color(0.08, 0.14, 0.1),
			"path": Color(0.45, 1.0, 0.55), "path_locked": Color(0.25, 0.35, 0.28),
			"node": Color(0.5, 1.0, 0.45), "node_clear": Color(0.7, 1.0, 0.55),
			"node_boss": Color(0.85, 1.0, 0.3), "pedestal": Color(0.22, 0.32, 0.24),
			"accent": Color(0.45, 1.0, 0.55), "sun": 0.9,
		},
		"tweezers": {
			"sky": Color(0.4, 0.42, 0.58), "ambient": Color(0.45, 0.48, 0.62),
			"ground": Color(0.18, 0.18, 0.26), "hill": Color(0.14, 0.14, 0.2),
			"path": Color(0.85, 0.9, 1.0), "path_locked": Color(0.35, 0.35, 0.42),
			"node": Color(0.75, 0.85, 1.0), "node_clear": Color(0.9, 0.9, 0.7),
			"node_boss": Color(0.95, 0.85, 0.45), "pedestal": Color(0.35, 0.35, 0.42),
			"accent": Color(0.75, 0.85, 1.0), "sun": 0.85,
		},
		"dark": {
			"sky": Color(0.08, 0.1, 0.16), "ambient": Color(0.2, 0.22, 0.32),
			"ground": Color(0.07, 0.07, 0.1), "hill": Color(0.05, 0.05, 0.08),
			"path": Color(0.35, 0.7, 0.95), "path_locked": Color(0.2, 0.22, 0.28),
			"node": Color(0.4, 0.75, 1.0), "node_clear": Color(0.45, 0.85, 0.7),
			"node_boss": Color(0.7, 0.35, 0.95), "pedestal": Color(0.2, 0.2, 0.28),
			"accent": Color(0.45, 0.85, 1.0), "sun": 0.45,
		},
		"ritual": {
			"sky": Color(0.35, 0.15, 0.4), "ambient": Color(0.45, 0.25, 0.5),
			"ground": Color(0.18, 0.08, 0.2), "hill": Color(0.14, 0.06, 0.16),
			"path": Color(0.95, 0.4, 0.85), "path_locked": Color(0.35, 0.22, 0.38),
			"node": Color(0.9, 0.35, 0.8), "node_clear": Color(0.75, 0.5, 0.95),
			"node_boss": Color(0.95, 0.25, 0.55), "pedestal": Color(0.35, 0.2, 0.4),
			"accent": Color(0.95, 0.4, 0.85), "sun": 0.75,
		},
		"finale": {
			"sky": Color(0.55, 0.2, 0.18), "ambient": Color(0.6, 0.3, 0.25),
			"ground": Color(0.28, 0.08, 0.1), "hill": Color(0.22, 0.06, 0.08),
			"path": Color(1.0, 0.45, 0.3), "path_locked": Color(0.4, 0.22, 0.22),
			"node": Color(1.0, 0.35, 0.35), "node_clear": Color(1.0, 0.7, 0.35),
			"node_boss": Color(1.0, 0.2, 0.15), "pedestal": Color(0.4, 0.18, 0.16),
			"accent": Color(1.0, 0.35, 0.4), "sun": 1.2,
		},
	}
	var ids := ["liquids", "mold", "broom", "slime", "brush", "spray", "alien", "dark", "ritual", "finale"]
	var idx := clampi(slot - 1, 0, ids.size() - 1)
	var tid: String = ids[idx]
	var theme: Dictionary = themes[tid] as Dictionary
	var palette: Dictionary = theme.duplicate()
	palette["id"] = tid
	palette["node_locked"] = Color(0.35, 0.35, 0.38)
	return palette


func _apply_palette_visuals() -> void:
	if _palette.is_empty():
		return
	var ground_c: Color = _palette.get("ground", Color(0.25, 0.4, 0.25))
	if _ground_mat != null:
		_ground_mat.set_shader_parameter("albedo_color", ground_c)
	if _cliff != null and _cliff.material_override is ShaderMaterial:
		(_cliff.material_override as ShaderMaterial).set_shader_parameter(
			"albedo_color", ground_c.darkened(0.25).lerp(Color(0.4, 0.3, 0.18), 0.4)
		)
	if _hills_root != null:
		var hill_c: Color = _palette.get("hill", Color(0.2, 0.35, 0.2))
		var i := 0
		for c in _hills_root.get_children():
			var mi := c as MeshInstance3D
			if mi == null:
				continue
			if mi.material_override is ShaderMaterial:
				(mi.material_override as ShaderMaterial).set_shader_parameter(
					"albedo_color", hill_c.darkened(0.04 * float(i % 3))
				)
			i += 1
	if _cam_env != null:
		var sky_c: Color = _palette.get("sky", Color(0.45, 0.72, 0.95))
		_cam_env.background_color = sky_c
		_cam_env.ambient_light_color = _palette.get("ambient", Color(0.55, 0.65, 0.75))
		_cam_env.ambient_light_energy = 0.55 if float(_palette.get("sun", 1.0)) > 0.7 else 0.35
		_cam_env.fog_enabled = true
		_cam_env.fog_light_color = _palette.get("fog", sky_c.lightened(0.15))
		_cam_env.fog_density = 0.012
	if _horizon_mat != null and _horizon_mat.albedo_texture == null:
		_horizon_mat.albedo_color = _palette.get("sky", Color(0.58, 0.8, 0.95))
	if _sun != null:
		_sun.light_energy = float(_palette.get("sun", 1.0))
		var accent: Color = _palette.get("accent", Color.WHITE)
		_sun.light_color = Color(1.0, 0.95, 0.9).lerp(accent, 0.25)
	if _world_label != null:
		var ac: Color = _palette.get("accent", Color(1.0, 0.92, 0.45))
		_world_label.add_theme_color_override("font_color", ac)


func _rebuild_theme_decor() -> void:
	if _decor_root == null:
		return
	for c in _decor_root.get_children():
		c.queue_free()
	_rebuild_foliage()
	var tid := String(_palette.get("id", "tutorial"))
	var accent: Color = _palette.get("accent", Color(0.8, 0.7, 0.4))
	match tid:
		"tutorial":
			_spawn_box_props(accent)
			_spawn_prop_label("🧹", Vector3(-7, 1.2, 4.5))
		"liquids":
			_spawn_puddles(accent)
			_spawn_bucket(Vector3(-8.5, 0, 3.2), accent)
			_spawn_bucket(Vector3(8.2, 0, -2.5), accent)
			_spawn_prop_label("💧", Vector3(0, 2.2, -5.5))
		"mold":
			_spawn_blobs(Color(0.35, 0.75, 0.3), 8)
			_spawn_prop_label("🤢", Vector3(-6, 1.8, 4))
		"broom":
			_spawn_dust_piles()
			_spawn_box_props(Color(0.7, 0.5, 0.3))
			_spawn_prop_label("👻", Vector3(7, 1.6, 3.5))
		"slime":
			_spawn_blobs(Color(0.3, 0.95, 0.65), 10)
			_spawn_prop_label("🐌", Vector3(-5, 1.5, -4))
		"brush":
			_spawn_potions(accent)
			_spawn_prop_label("🧪", Vector3(6.5, 1.8, 2.5))
		"spray":
			_spawn_cans(accent)
			_spawn_mist(accent)
			_spawn_prop_label("💧", Vector3(-7, 2.0, 3))
		"alien":
			_spawn_blobs(Color(0.4, 1.0, 0.5), 9)
			_spawn_prop_label("👽", Vector3(5, 1.7, -3.5))
		"tweezers":
			_spawn_candles()
			_spawn_prop_label("🕯", Vector3(5, 1.7, -3.5))
		"dark":
			_spawn_lanterns(accent)
			_spawn_prop_label("🦇", Vector3(0, 2.4, -6))
		"ritual":
			_spawn_candles()
			_spawn_runes(accent)
			_spawn_prop_label("🧙", Vector3(-6.5, 1.9, 3.5))
		"finale":
			_spawn_box_props(Color(0.85, 0.25, 0.25))
			_spawn_flames()
			_spawn_prop_label("🔥", Vector3(0, 2.5, -5.5))
		_:
			_spawn_box_props(accent)


func _mat(col: Color, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.75
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	_attach_outline(m, 0.026)
	return m


func _spawn_mesh(mesh: Mesh, pos: Vector3, col: Color, emit: float = 0.0, mesh_scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col, emit)
	mi.position = pos
	mi.scale = mesh_scale
	_decor_root.add_child(mi)
	return mi


func _spawn_prop_label(label_text: String, pos: Vector3) -> void:
	var lab := Label3D.new()
	lab.text = label_text
	lab.font_size = 96
	lab.position = pos
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.outline_size = 10
	_decor_root.add_child(lab)


func _spawn_box_props(col: Color) -> void:
	var spots := [
		Vector3(-9, 0, 4), Vector3(-8.2, 0, 4.6), Vector3(9, 0, -3),
		Vector3(8.3, 0, -3.2), Vector3(-10, 0, -2), Vector3(10, 0, 2.5),
		Vector3(-6.5, 0, 5.2), Vector3(7.2, 0, 4.8),
	]
	for i in spots.size():
		var prefer_fallen := i == 3 or _decor_rng.randf() < 0.2
		var pick: Dictionary = PropCatalog3D.pick_box(_decor_rng, prefer_fallen)
		var xform: Dictionary = PropCatalog3D.roll_box_xform(_decor_rng)
		var base := 0.55 + _decor_rng.randf_range(0.0, 0.18)
		var fallen := prefer_fallen or bool(pick.get("fallen", false))
		var flip_x := 0.0 if fallen else PI
		if _try_spawn_packed_prop(_decor_root, pick, spots[i], xform, base, flip_x):
			continue
		var sj: Vector3 = xform.get("size_jitter", Vector3.ONE)
		var custom: Mesh = pick.get("mesh") as Mesh
		var mi := MeshInstance3D.new()
		if custom != null:
			mi.mesh = custom
		else:
			var box := BoxMesh.new()
			box.size = Vector3(base * sj.x, base * sj.y, base * sj.z)
			mi.mesh = box
		var tex: Texture2D = pick.get("texture") as Texture2D
		if tex == null and custom != null:
			tex = _texture_from_mesh(custom)
		var tint: Color = xform.get("tint", Color.WHITE)
		var albedo := (col.darkened(0.08 * float(i % 3)) * tint) if tex == null else Color.WHITE
		mi.material_override = _make_prop_mat(albedo, tex, 0.028)
		if custom != null:
			var aabb := custom.get_aabb()
			var sz := aabb.size
			if sz.x > 0.001:
				mi.scale = Vector3.ONE * (base / maxf(sz.x, maxf(sz.y, sz.z)))
		else:
			mi.scale = Vector3.ONE * float(xform.get("scale", 1.0))
		var off: Vector3 = xform.get("offset", Vector3.ZERO)
		mi.position = Vector3(spots[i].x + off.x, 0.0, spots[i].z + off.z)
		if fallen:
			mi.rotation = Vector3(
				deg_to_rad(_decor_rng.randf_range(82.0, 92.0)),
				float(xform.get("yaw", 0.0)),
				deg_to_rad(_decor_rng.randf_range(-12.0, 12.0))
			)
		else:
			mi.rotation = Vector3(
				flip_x + float(xform.get("tilt_x", 0.0)) * 0.35,
				float(xform.get("yaw", 0.0)),
				float(xform.get("tilt_z", 0.0)) * 0.35
			)
		_decor_root.add_child(mi)
		_snap_mesh_to_ground(mi)


func _spawn_puddles(col: Color) -> void:
	for i in 7:
		var disk := CylinderMesh.new()
		disk.top_radius = 0.7 + float(i % 3) * 0.25
		disk.bottom_radius = disk.top_radius
		disk.height = 0.04
		var pos := Vector3(-9.0 + float(i) * 3.0, 0.02, 3.5 - float(i % 2) * 5.5)
		_spawn_mesh(disk, pos, Color(col.r, col.g, col.b, 0.85).lightened(0.1), 0.35)


func _spawn_bucket(pos: Vector3, col: Color) -> void:
	var body := CylinderMesh.new()
	body.top_radius = 0.35
	body.bottom_radius = 0.4
	body.height = 0.55
	_spawn_mesh(body, pos + Vector3(0, 0.28, 0), Color(0.45, 0.5, 0.55))
	var water := CylinderMesh.new()
	water.top_radius = 0.28
	water.bottom_radius = 0.28
	water.height = 0.08
	_spawn_mesh(water, pos + Vector3(0, 0.48, 0), col, 0.5)


func _spawn_blobs(col: Color, count: int) -> void:
	for i in count:
		var sph := SphereMesh.new()
		sph.radius = 0.25 + float(i % 4) * 0.08
		sph.height = sph.radius * 1.4
		var pos := Vector3(
			-10.0 + float(i) * 2.4 + sin(float(i)) * 0.8,
			sph.radius * 0.45,
			3.8 - float(i % 3) * 3.2
		)
		_spawn_mesh(sph, pos, col.darkened(0.05 * float(i % 3)), 0.25)


func _spawn_dust_piles() -> void:
	for i in 6:
		var sph := SphereMesh.new()
		sph.radius = 0.35 + float(i % 3) * 0.1
		sph.height = sph.radius * 0.9
		_spawn_mesh(
			sph,
			Vector3(-8.5 + float(i) * 3.2, 0.12, 4.0 - float(i % 2) * 6.0),
			Color(0.55, 0.48, 0.38)
		)


func _spawn_potions(col: Color) -> void:
	for i in 5:
		var bottle := CylinderMesh.new()
		bottle.top_radius = 0.12
		bottle.bottom_radius = 0.16
		bottle.height = 0.55
		var pos := Vector3(-8.0 + float(i) * 4.0, 0.3, 3.5 - float(i % 2) * 5.5)
		_spawn_mesh(bottle, pos, col, 0.7)
		var cap := SphereMesh.new()
		cap.radius = 0.1
		_spawn_mesh(cap, pos + Vector3(0, 0.35, 0), Color(0.9, 0.85, 0.3), 0.4)


func _spawn_cans(col: Color) -> void:
	for i in 4:
		var can := CylinderMesh.new()
		can.top_radius = 0.14
		can.bottom_radius = 0.14
		can.height = 0.45
		_spawn_mesh(can, Vector3(-7.5 + float(i) * 4.5, 0.25, 4.2), col.lightened(0.15), 0.3)


func _spawn_mist(col: Color) -> void:
	for i in 5:
		var sph := SphereMesh.new()
		sph.radius = 0.8 + float(i % 3) * 0.2
		var mi := _spawn_mesh(
			sph,
			Vector3(-9.0 + float(i) * 4.0, 1.2 + float(i % 2) * 0.4, -4.5),
			Color(col.r, col.g, col.b, 0.25),
			0.2
		)
		var mat := mi.material_override as StandardMaterial3D
		if mat != null:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.28


func _spawn_candles() -> void:
	for i in 6:
		var stick := CylinderMesh.new()
		stick.top_radius = 0.06
		stick.bottom_radius = 0.07
		stick.height = 0.45
		var pos := Vector3(-9.0 + float(i) * 3.5, 0.25, 3.8 - float(i % 2) * 6.0)
		_spawn_mesh(stick, pos, Color(0.9, 0.88, 0.8))
		var flame := SphereMesh.new()
		flame.radius = 0.09
		_spawn_mesh(flame, pos + Vector3(0, 0.32, 0), Color(1.0, 0.7, 0.25), 2.2)


func _spawn_lanterns(col: Color) -> void:
	for i in 4:
		var pole := CylinderMesh.new()
		pole.top_radius = 0.05
		pole.bottom_radius = 0.06
		pole.height = 1.4
		var pos := Vector3(-8.5 + float(i) * 5.5, 0.7, 4.0 - float(i % 2) * 7.0)
		_spawn_mesh(pole, pos, Color(0.25, 0.25, 0.28))
		var lamp := SphereMesh.new()
		lamp.radius = 0.22
		_spawn_mesh(lamp, pos + Vector3(0, 0.85, 0), col, 2.8)


func _spawn_runes(col: Color) -> void:
	for i in 5:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.35
		ring.outer_radius = 0.48
		var mi := _spawn_mesh(
			ring,
			Vector3(-8.0 + float(i) * 4.0, 0.08, 3.2 - float(i % 2) * 5.0),
			col,
			0.9
		)
		mi.rotation_degrees.x = 90.0


func _spawn_flames() -> void:
	for i in 5:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.05
		cone.bottom_radius = 0.35
		cone.height = 1.1
		_spawn_mesh(
			cone,
			Vector3(-8.0 + float(i) * 4.0, 0.55, 4.0 - float(i % 2) * 6.5),
			Color(1.0, 0.4 + float(i % 3) * 0.1, 0.15),
			2.5
		)
