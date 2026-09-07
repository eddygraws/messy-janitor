class_name WorldClearScene
extends Node3D

## World-sonu tören — yüzen kara parçası; arkada/altta sadece gökyüzü (ufuk yok).

const JanitorVisualScript := preload("res://scenes3d/player/janitor_visual.gd")
const PerfBudget := preload("res://systems/perf_budget_3d.gd")
const PATH_CURVE_SHADER := preload("res://shaders/map_path_curve.gdshader")
const OUTLINE_SHADER := preload("res://shaders/mesh_outline.gdshader")

var _camera: Camera3D
var _janitor: JanitorVisual
var _path: MeshInstance3D
var _path_mat: ShaderMaterial
var _scroll_t: float = 0.0
var _path_stripe_offset: float = 0.0
var _pawn: Node3D
var _island: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _process(delta: float) -> void:
	_scroll_t += delta
	_path_stripe_offset += delta * 2.8
	if _path != null:
		_rebuild_path_stripe(_path_stripe_offset)
	if _pawn != null:
		_pawn.position.y = 0.18 + sin(_scroll_t * 10.0) * 0.025
	if _island != null:
		_island.rotation.z = sin(_scroll_t * 0.55) * 0.014
		_island.rotation.x = cos(_scroll_t * 0.4) * 0.01
		_island.position.y = sin(_scroll_t * 0.7) * 0.06


func _build() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = false
	sun.rotation_degrees = Vector3(-48, 28, 0)
	add_child(sun)

	var sky_col := Color(0.52, 0.78, 0.98)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky_col
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.88, 0.98)
	env.ambient_light_energy = 0.9
	env.fog_enabled = false
	PerfBudget.apply_environment(env)

	# İçten görünen gökyüzü küresi — alt/yan/arka hep gökyüzü
	var sky := MeshInstance3D.new()
	var sky_mesh := SphereMesh.new()
	sky_mesh.radius = 90.0
	sky_mesh.height = 180.0
	sky_mesh.radial_segments = 28
	sky_mesh.rings = 14
	sky.mesh = sky_mesh
	var sky_mat := StandardMaterial3D.new()
	sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	sky_mat.albedo_color = sky_col
	sky.material_override = sky_mat
	add_child(sky)

	# Uzak bulut lekeleri (ufuk çizgisi değil — gökyüzünde noktalar)
	_add_cloud_blob(Vector3(-14, 6, -18), 3.2)
	_add_cloud_blob(Vector3(10, 8, -22), 2.6)
	_add_cloud_blob(Vector3(4, 4, -28), 4.0)
	_add_cloud_blob(Vector3(-8, 10, -12), 2.0)

	_island = Node3D.new()
	_island.name = "FloatingIsland"
	_island.position = Vector3(0, 0.4, 0)
	add_child(_island)

	# Üst yüzey — sınırlı ada (sonsuz plane YOK)
	var top := MeshInstance3D.new()
	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = 4.6
	top_mesh.bottom_radius = 4.85
	top_mesh.height = 0.42
	top_mesh.radial_segments = 32
	top.mesh = top_mesh
	top.material_override = _solid_mat(Color(0.34, 0.58, 0.32), 0.042)
	top.position.y = 0.0
	_island.add_child(top)

	# Kenar “dudak” — ince halka, ufuk değil
	var lip := MeshInstance3D.new()
	var lip_mesh := TorusMesh.new()
	lip_mesh.inner_radius = 4.55
	lip_mesh.outer_radius = 5.05
	lip_mesh.rings = 24
	lip_mesh.ring_segments = 12
	lip.mesh = lip_mesh
	lip.material_override = _solid_mat(Color(0.28, 0.48, 0.26), 0.03)
	lip.position.y = -0.05
	lip.rotation.x = deg_to_rad(90.0)
	_island.add_child(lip)

	# Alt kaya — ada parçası; altında gökyüzü görünsün
	var under := MeshInstance3D.new()
	var under_mesh := CylinderMesh.new()
	under_mesh.top_radius = 4.5
	under_mesh.bottom_radius = 1.4
	under_mesh.height = 4.6
	under_mesh.radial_segments = 24
	under.mesh = under_mesh
	under.material_override = _solid_mat(Color(0.44, 0.34, 0.26), 0.036)
	under.position.y = -2.4
	_island.add_child(under)

	# Kök / sarkıt detay
	for i in 4:
		var drip := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = 0.35 - float(i) * 0.04
		dm.bottom_radius = 0.08
		dm.height = 1.1 + float(i % 2) * 0.5
		drip.mesh = dm
		drip.material_override = _solid_mat(Color(0.38, 0.3, 0.22), 0.02)
		var ang := float(i) * TAU / 4.0 + 0.4
		drip.position = Vector3(cos(ang) * 2.2, -4.2 - float(i % 2) * 0.3, sin(ang) * 2.2)
		_island.add_child(drip)

	# Küçük tepecikler
	for i in 3:
		var bump := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.75 + float(i) * 0.12
		bm.height = bm.radius * 0.85
		bump.mesh = bm
		bump.material_override = _solid_mat(Color(0.28, 0.5, 0.26).darkened(0.04 * float(i)), 0.028)
		bump.position = Vector3(-1.6 + float(i) * 1.5, 0.12, -1.8 - float(i % 2) * 0.5)
		bump.scale = Vector3(1.15, 0.5, 1.0)
		_island.add_child(bump)

	# Kısa yol — sadece ada üzerinde
	_path = MeshInstance3D.new()
	_path.name = "Road"
	_path_mat = ShaderMaterial.new()
	_path_mat.shader = PATH_CURVE_SHADER
	_path_mat.set_shader_parameter("curve_strength", 0.0)
	_path_mat.set_shader_parameter("curve_max_drop", 0.0)
	_path.material_override = _path_mat
	_island.add_child(_path)
	_rebuild_path_stripe(0.0)

	_pawn = Node3D.new()
	_pawn.name = "Runner"
	_pawn.position = Vector3(-0.35, 0.18, 0.55)
	_pawn.rotation.y = deg_to_rad(22.0)
	_island.add_child(_pawn)

	_janitor = JanitorVisualScript.new()
	_janitor.name = "JanitorVisual"
	_janitor.size_mult = 1.85
	_janitor.yaw_offset = 0.0
	_pawn.add_child(_janitor)
	if _janitor.setup():
		_janitor.play_loco(&"run", 1.15)
	else:
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.28
		cap.height = 1.0
		body.mesh = cap
		var bm2 := StandardMaterial3D.new()
		bm2.albedo_color = Color(0.55, 0.35, 0.85)
		body.material_override = bm2
		body.position.y = 0.55
		_pawn.add_child(body)

	# Kamera: adayı yandan/yukarıdan; altında ve arkada gökyüzü
	_camera = Camera3D.new()
	_camera.name = "ClearCam"
	_camera.fov = 36.0
	_camera.environment = env
	_camera.current = false
	_camera.position = Vector3(3.4, 4.2, 8.6)
	add_child(_camera)
	_camera.look_at(Vector3(0.0, -0.2, -0.8), Vector3.UP)


func _add_cloud_blob(pos: Vector3, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 0.7
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.92, 0.95, 1.0, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3(1.6, 0.45, 1.0)
	add_child(mi)


func _solid_mat(col: Color, outline_w: float = 0.03) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	var ol := ShaderMaterial.new()
	ol.shader = OUTLINE_SHADER
	ol.set_shader_parameter("outline_color", Color(0.06, 0.04, 0.09, 1.0))
	ol.set_shader_parameter("outline_width", outline_w)
	m.next_pass = ol
	return m


func _rebuild_path_stripe(scroll: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w := 0.75
	var z0 := 2.2
	var z1 := -2.0
	var segs := 10
	for i in segs:
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var za := lerpf(z0, z1, t0)
		var zb := lerpf(z0, z1, t1)
		var xa := sin((t0 + scroll * 0.08) * TAU * 0.4) * 0.18
		var xb := sin((t1 + scroll * 0.08) * TAU * 0.4) * 0.18
		var stripe := int(floor(t0 * 8.0 + scroll)) % 2 == 0
		var col := Color(0.38, 0.39, 0.4) if stripe else Color(0.48, 0.48, 0.46)
		_add_quad(st, Vector3(xa, 0.24, za), Vector3(xb, 0.24, zb), half_w, col)
		var dash := int(floor(t0 * 12.0 + scroll * 1.6)) % 2 == 0
		if dash:
			_add_quad(st, Vector3(xa, 0.25, za), Vector3(xb, 0.25, zb), 0.06, Color(0.95, 0.95, 0.9))
	_path.mesh = st.commit()


func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, half_w: float, col: Color) -> void:
	var dir := (b - a)
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	var side := Vector3(-dir.z, 0.0, dir.x) * half_w
	var p0 := a - side
	var p1 := a + side
	var p2 := b + side
	var p3 := b - side
	st.set_color(col)
	st.set_normal(Vector3.UP)
	st.add_vertex(p0)
	st.add_vertex(p1)
	st.add_vertex(p2)
	st.add_vertex(p0)
	st.add_vertex(p2)
	st.add_vertex(p3)


func play_run() -> void:
	if _camera != null:
		_camera.current = true
	if _janitor != null and _janitor.is_ready_visual():
		_janitor.play_loco(&"run", 1.15)
