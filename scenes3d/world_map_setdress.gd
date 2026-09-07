extends RefCounted

## Dünya haritası set-dress: Paspas mahallesi gibi her bölüm ayrı diorama.
## PNG gelince assets/map/<tema>/ altına koy — yoksa primitive placeholder.

const OUTLINE_SHADER := preload("res://shaders/mesh_outline.gdshader")
const TREE_TEX := "res://assets/props/foliage/tree_plane_a_treetrunl.png"


static func skips_forest(tid: String) -> bool:
	return tid != "tutorial"


static func fill(decor: Node3D, foliage: Node3D, tid: String, ground_y: float) -> void:
	if decor == null:
		return
	match tid:
		"tutorial":
			_fill_garage_yard(decor, ground_y)
		"liquids":
			_fill_suburb(decor, foliage, ground_y)
		"mold":
			_fill_swamp(decor, ground_y)
		"broom":
			_fill_haunted(decor, ground_y)
		"slime":
			_fill_marsh(decor, foliage, ground_y)
		"brush":
			_fill_witch(decor, ground_y)
		"spray":
			_fill_wet_alley(decor, ground_y)
		"alien":
			_fill_city(decor, ground_y)
		"dark":
			_fill_graveyard(decor, ground_y)
		"ritual":
			_fill_temple(decor, ground_y)
		"finale":
			_fill_inferno(decor, ground_y)
		_:
			_fill_garage_yard(decor, ground_y)


static func tick(decor: Node3D, delta: float) -> void:
	if decor == null:
		return
	for n in decor.get_children():
		if not (n is Node3D) or not n.has_meta("ufo"):
			continue
		var node := n as Node3D
		var t := float(node.get_meta("ufo_t")) + delta * float(node.get_meta("ufo_spd"))
		node.set_meta("ufo_t", t)
		var c: Vector3 = node.get_meta("ufo_c")
		var r := float(node.get_meta("ufo_r"))
		node.position = Vector3(
			c.x + cos(t) * r,
			c.y + sin(t * 1.6) * 0.38,
			c.z + sin(t) * r * 0.52
		)
		node.rotation.y = t * 0.85


static func _try_tex(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func _mat(col: Color, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.82
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter("outline_color", Color(0.06, 0.04, 0.09, 1.0))
	outline.set_shader_parameter("outline_width", 0.026)
	m.next_pass = outline
	return m


static func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, col: Color, emit: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col, emit)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, pos: Vector3, size: Vector3, col: Color, emit: float = 0.0) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(parent, b, pos, col, emit)


static func _cyl(parent: Node3D, pos: Vector3, r: float, h: float, col: Color, emit: float = 0.0) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	return _mesh(parent, c, pos, col, emit)


static func _billboard(parent: Node3D, tex: Texture2D, pos: Vector3, size: Vector2, ground_y: float) -> void:
	if parent == null or tex == null:
		return
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
	mi.material_override = mat
	mi.position = Vector3(pos.x, ground_y + size.y * 0.5, pos.z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func _fill_garage_yard(d: Node3D, gy: float) -> void:
	_box(d, Vector3(-9.2, gy + 1.1, -5.6), Vector3(4.2, 2.2, 3.0), Color(0.55, 0.42, 0.34))
	_box(d, Vector3(-9.2, gy + 0.7, -4.05), Vector3(1.8, 1.4, 0.08), Color(0.28, 0.3, 0.32))
	var crate := Color(0.62, 0.48, 0.32)
	for i in 5:
		_box(d, Vector3(-6.5 + float(i) * 3.1, gy + 0.28, 4.6), Vector3(0.7, 0.55, 0.7), crate.darkened(0.04 * float(i % 3)))
	_cyl(d, Vector3(8.4, gy + 0.4, -3.8), 0.32, 0.8, Color(0.42, 0.28, 0.18))
	_cyl(d, Vector3(9.1, gy + 0.4, -3.2), 0.32, 0.8, Color(0.38, 0.26, 0.16))


static func _fill_suburb(d: Node3D, foliage: Node3D, gy: float) -> void:
	var walls: Array[Color] = [
		Color(0.86, 0.78, 0.68), Color(0.78, 0.72, 0.62), Color(0.82, 0.76, 0.70),
		Color(0.74, 0.70, 0.62), Color(0.80, 0.74, 0.64),
	]
	var roofs: Array[Color] = [
		Color(0.62, 0.32, 0.28), Color(0.40, 0.44, 0.50), Color(0.55, 0.38, 0.26),
		Color(0.42, 0.48, 0.36), Color(0.58, 0.34, 0.30),
	]
	var house_a := _try_tex("res://assets/map/suburb/house_a.png")
	var house_b := _try_tex("res://assets/map/suburb/house_b.png")
	var garage := _try_tex("res://assets/map/suburb/garage.png")
	var xs: Array[float] = [-8.8, -4.4, 0.0, 4.4, 8.8]
	for i in xs.size():
		var hx := xs[i]
		var hz := -5.4 - float(i % 2) * 0.55
		var tex: Texture2D = garage if i == 0 and garage != null else (house_a if (i % 2) == 0 else house_b)
		if tex == null:
			tex = house_a if house_a != null else house_b
		if tex != null:
			_billboard(foliage if foliage != null else d, tex, Vector3(hx, 0, hz), Vector2(3.4, 3.7), gy)
		else:
			var w := 3.1 if i == 0 else 2.35
			var dd := 2.4 if i == 0 else 2.05
			var h := 1.55 if i == 0 else 1.72
			_box(d, Vector3(hx, gy + h * 0.5, hz), Vector3(w, h, dd), walls[i])
			_box(d, Vector3(hx, gy + h + 0.18, hz), Vector3(w + 0.22, 0.38, dd + 0.22), roofs[i])
			if i == 0:
				_box(d, Vector3(hx, gy + 0.62, hz + dd * 0.5), Vector3(1.55, 1.15, 0.08), Color(0.28, 0.3, 0.32))
			else:
				_box(d, Vector3(hx - 0.35, gy + 0.48, hz + dd * 0.5), Vector3(0.42, 0.95, 0.08), Color(0.38, 0.26, 0.18))
		_box(d, Vector3(hx, gy + 0.04, hz + 2.15), Vector3(2.6, 0.06, 1.6), Color(0.30, 0.56, 0.26))
		if i == 0:
			_box(d, Vector3(hx, gy + 0.03, hz + 2.75), Vector3(1.7, 0.05, 2.8), Color(0.42, 0.42, 0.44))
		else:
			_box(d, Vector3(hx + 1.15, gy + 0.36, hz + 2.55), Vector3(0.08, 0.72, 0.08), Color(0.55, 0.55, 0.52))
			_box(d, Vector3(hx + 1.15, gy + 0.78, hz + 2.55), Vector3(0.28, 0.18, 0.16), Color(0.82, 0.22, 0.18))
	var x := -11.5
	while x <= 11.5:
		_box(d, Vector3(x, gy + 0.28, 4.8), Vector3(0.85, 0.55, 0.45), Color(0.22, 0.46, 0.22))
		_box(d, Vector3(x, gy + 0.28, -7.6), Vector3(0.85, 0.55, 0.45), Color(0.22, 0.46, 0.22))
		x += 1.35
	var tree := _try_tex(TREE_TEX)
	if tree != null:
		var host := foliage if foliage != null else d
		_billboard(host, tree, Vector3(-12.8, 0, -4.2), Vector2(3.4, 4.6), gy)
		_billboard(host, tree, Vector3(12.6, 0, -3.4), Vector2(3.1, 4.2), gy)


static func _fill_swamp(d: Node3D, gy: float) -> void:
	_box(d, Vector3(0.0, gy + 0.02, -6.5), Vector3(22.0, 0.08, 4.0), Color(0.12, 0.28, 0.16))
	for i in 6:
		_cyl(d, Vector3(-9.0 + float(i) * 3.5, gy + 0.55, -5.2 - float(i % 2) * 0.8), 0.22, 1.1, Color(0.28, 0.55, 0.28))
		_cyl(d, Vector3(-9.0 + float(i) * 3.5, gy + 1.05, -5.2 - float(i % 2) * 0.8), 0.55, 0.28, Color(0.45, 0.78, 0.32), 0.08)
	for i in 4:
		_box(d, Vector3(-7.5 + float(i) * 4.4, gy + 0.22, 4.4), Vector3(1.1, 0.45, 0.8), Color(0.32, 0.28, 0.18))


static func _fill_haunted(d: Node3D, gy: float) -> void:
	_box(d, Vector3(-1.5, gy + 1.5, -6.2), Vector3(5.4, 3.0, 3.2), Color(0.42, 0.32, 0.24))
	_box(d, Vector3(-1.5, gy + 3.2, -6.2), Vector3(5.8, 0.55, 3.5), Color(0.28, 0.18, 0.14))
	_box(d, Vector3(-1.5, gy + 0.85, -4.55), Vector3(0.7, 1.6, 0.1), Color(0.18, 0.12, 0.1))
	_web(d, Vector3(1.4, gy + 2.2, -4.7), 1.4)
	_web(d, Vector3(-3.6, gy + 2.4, -4.8), 1.1)
	for i in 5:
		_cyl(d, Vector3(-8.5 + float(i) * 4.0, gy + 0.18, 4.5), 0.55, 0.22, Color(0.55, 0.48, 0.36))


static func _fill_marsh(d: Node3D, foliage: Node3D, gy: float) -> void:
	_cyl(d, Vector3(0.0, gy + 0.04, -6.0), 5.5, 0.08, Color(0.12, 0.38, 0.32), 0.06)
	for i in 8:
		_box(d, Vector3(-10.0 + float(i) * 2.8, gy + 0.7, -4.8 + float(i % 3) * 0.4), Vector3(0.12, 1.4, 0.12), Color(0.22, 0.5, 0.28))
	var tree := _try_tex(TREE_TEX)
	if tree != null:
		var host := foliage if foliage != null else d
		_billboard(host, tree, Vector3(-12.0, 0, -3.5), Vector2(3.2, 4.4), gy)
		_billboard(host, tree, Vector3(11.5, 0, -4.0), Vector2(3.0, 4.0), gy)


static func _fill_witch(d: Node3D, gy: float) -> void:
	var castle := _try_tex("res://assets/map/brush/castle.png")
	if castle != null:
		_billboard(d, castle, Vector3(0.0, 0, -11.0), Vector2(14.0, 10.0), gy)
	else:
		_box(d, Vector3(0.0, gy + 2.4, -10.5), Vector3(7.2, 4.8, 4.4), Color(0.32, 0.18, 0.42))
		_cyl(d, Vector3(-3.6, gy + 3.6, -10.5), 1.05, 7.2, Color(0.28, 0.14, 0.38))
		_cyl(d, Vector3(3.6, gy + 3.2, -10.5), 0.95, 6.4, Color(0.30, 0.16, 0.40))
		_cyl(d, Vector3(-3.6, gy + 7.35, -10.5), 1.35, 0.55, Color(0.18, 0.08, 0.22))
		_cyl(d, Vector3(3.6, gy + 6.65, -10.5), 1.25, 0.5, Color(0.16, 0.07, 0.2))
		_box(d, Vector3(0.0, gy + 5.15, -10.5), Vector3(2.2, 0.7, 2.2), Color(0.22, 0.1, 0.28))
		_box(d, Vector3(0.0, gy + 1.2, -8.2), Vector3(1.4, 2.4, 0.16), Color(0.12, 0.06, 0.16))
		_box(d, Vector3(-1.6, gy + 2.8, -8.2), Vector3(0.7, 0.7, 0.1), Color(0.85, 0.45, 1.0), 0.35)
		_box(d, Vector3(1.6, gy + 2.8, -8.2), Vector3(0.7, 0.7, 0.1), Color(0.85, 0.45, 1.0), 0.35)
	_web(d, Vector3(-6.2, gy + 1.8, -4.0), 1.6)
	_web(d, Vector3(6.8, gy + 2.1, -3.4), 1.35)
	_web(d, Vector3(-4.5, gy + 1.4, 4.2), 1.1)
	var book_cols: Array[Color] = [
		Color(0.55, 0.18, 0.22), Color(0.22, 0.28, 0.55), Color(0.45, 0.32, 0.12),
		Color(0.28, 0.45, 0.28), Color(0.45, 0.18, 0.42),
	]
	for i in 7:
		var hx := -8.5 + float(i) * 2.6
		_box(d, Vector3(hx, gy + 0.12, 4.35), Vector3(0.55, 0.08, 0.38), book_cols[i % book_cols.size()])
		_box(d, Vector3(hx + 0.08, gy + 0.22, 4.38), Vector3(0.5, 0.08, 0.34), book_cols[(i + 2) % book_cols.size()])
		_box(d, Vector3(hx - 0.05, gy + 0.32, 4.32), Vector3(0.48, 0.08, 0.32), book_cols[(i + 4) % book_cols.size()])
	_cyl(d, Vector3(8.6, gy + 0.55, -3.8), 0.28, 1.1, Color(0.42, 0.22, 0.55), 0.2)
	_cyl(d, Vector3(8.6, gy + 1.15, -3.8), 0.12, 0.22, Color(0.9, 0.7, 0.35), 0.4)


static func _fill_wet_alley(d: Node3D, gy: float) -> void:
	_box(d, Vector3(-10.5, gy + 2.2, -6.0), Vector3(3.2, 4.4, 3.4), Color(0.28, 0.36, 0.48))
	_box(d, Vector3(10.5, gy + 2.0, -5.6), Vector3(3.0, 4.0, 3.2), Color(0.26, 0.34, 0.46))
	for i in 5:
		_cyl(d, Vector3(-7.0 + float(i) * 3.4, gy + 0.28, 4.4), 0.16, 0.55, Color(0.55, 0.78, 0.95), 0.15)
		_cyl(d, Vector3(-6.5 + float(i) * 3.2, gy + 0.06, -2.2 + float(i % 2)), 0.7, 0.05, Color(0.35, 0.55, 0.72), 0.08)


static func _fill_city(d: Node3D, gy: float) -> void:
	var tower := _try_tex("res://assets/map/alien/skyscraper.png")
	var heights: Array[float] = [8.5, 11.2, 7.4, 13.0, 9.6, 6.8, 10.4]
	var xs: Array[float] = [-11.5, -7.6, -3.6, 0.4, 4.4, 8.2, 12.0]
	for i in xs.size():
		var h := heights[i]
		if tower != null:
			_billboard(d, tower, Vector3(xs[i], 0, -11.0 - float(i % 3) * 0.8), Vector2(2.6, h * 0.85), gy)
		else:
			var wall := Color(0.18, 0.22, 0.28).lightened(0.04 * float(i % 3))
			_box(d, Vector3(xs[i], gy + h * 0.5, -11.2 - float(i % 2) * 1.1), Vector3(2.4, h, 2.4), wall)
			for wy in 4:
				_box(
					d,
					Vector3(xs[i], gy + 1.4 + float(wy) * (h / 5.0), -10.0 - float(i % 2) * 1.1),
					Vector3(1.8, 0.18, 0.08),
					Color(0.45, 1.0, 0.55),
					0.55
				)
	_box(d, Vector3(0.0, gy + 0.04, 0.0), Vector3(26.0, 0.06, 8.0), Color(0.16, 0.18, 0.2))
	for i in 4:
		_spawn_ufo(d, Vector3(-6.0 + float(i) * 4.2, gy + 6.2 + float(i % 2) * 0.8, -3.5), 4.5 + float(i), 0.35 + float(i) * 0.08)


static func _spawn_ufo(d: Node3D, center: Vector3, radius: float, spd: float) -> void:
	var tex := _try_tex("res://assets/map/alien/ufo.png")
	var root := Node3D.new()
	root.name = "HubUfo"
	root.set_meta("ufo", true)
	root.set_meta("ufo_t", center.x * 0.2)
	root.set_meta("ufo_c", center)
	root.set_meta("ufo_r", radius)
	root.set_meta("ufo_spd", spd)
	root.position = center
	d.add_child(root)
	if tex != null:
		_billboard(root, tex, Vector3.ZERO, Vector2(1.8, 0.7), 0.0)
		return
	var disc := CylinderMesh.new()
	disc.top_radius = 0.85
	disc.bottom_radius = 0.85
	disc.height = 0.14
	_mesh(root, disc, Vector3(0, 0, 0), Color(0.55, 0.62, 0.58), 0.2)
	var dome := SphereMesh.new()
	dome.radius = 0.38
	dome.height = 0.42
	_mesh(root, dome, Vector3(0, 0.22, 0), Color(0.45, 1.0, 0.55), 0.7)
	var ring := CylinderMesh.new()
	ring.top_radius = 0.55
	ring.bottom_radius = 0.55
	ring.height = 0.05
	_mesh(root, ring, Vector3(0, -0.08, 0), Color(0.85, 1.0, 0.4), 0.85)


static func _fill_graveyard(d: Node3D, gy: float) -> void:
	var stone := _try_tex("res://assets/map/dark/tombstone.png")
	var spots: Array[Vector3] = [
		Vector3(-8.5, 0, -4.6), Vector3(-5.2, 0, -5.4), Vector3(-1.8, 0, -4.8),
		Vector3(1.6, 0, -5.6), Vector3(5.0, 0, -4.5), Vector3(8.4, 0, -5.2),
		Vector3(-7.2, 0, 4.4), Vector3(-3.4, 0, 4.8), Vector3(2.2, 0, 4.5),
		Vector3(6.6, 0, 4.9),
	]
	for i in spots.size():
		var p: Vector3 = spots[i]
		p.y = gy
		if stone != null:
			_billboard(d, stone, p, Vector2(0.9, 1.35), gy)
		else:
			_tombstone(d, p + Vector3(0, 0.55, 0), 0.08 * float(i % 3))
	_iron_fence_row(d, gy, -11.0, 11.0, -3.35)
	_iron_fence_row(d, gy, -11.0, 11.0, 3.45)
	_dead_tree(d, Vector3(-11.5, gy, -6.8), 3.4)
	_dead_tree(d, Vector3(11.2, gy, -6.2), 3.8)
	_dead_tree(d, Vector3(-9.5, gy, 5.6), 2.8)
	_dead_tree(d, Vector3(10.4, gy, 5.2), 3.1)
	_cyl(d, Vector3(0.0, gy + 0.08, -8.5), 1.4, 0.16, Color(0.22, 0.24, 0.28))


static func _tombstone(d: Node3D, pos: Vector3, jitter: float) -> void:
	_box(d, pos + Vector3(jitter, 0.0, 0.0), Vector3(0.55, 1.05, 0.18), Color(0.38, 0.40, 0.42))
	_box(d, pos + Vector3(jitter, 0.52, 0.0), Vector3(0.62, 0.22, 0.2), Color(0.32, 0.34, 0.36))


static func _iron_fence_row(d: Node3D, gy: float, x0: float, x1: float, z: float) -> void:
	var x := x0
	var iron := Color(0.14, 0.14, 0.16)
	while x <= x1:
		_box(d, Vector3(x, gy + 0.55, z), Vector3(0.07, 1.1, 0.07), iron)
		_box(d, Vector3(x, gy + 1.12, z), Vector3(0.12, 0.12, 0.12), iron)
		if x + 0.55 <= x1:
			_box(d, Vector3(x + 0.28, gy + 0.72, z), Vector3(0.55, 0.05, 0.05), iron)
			_box(d, Vector3(x + 0.28, gy + 0.38, z), Vector3(0.55, 0.05, 0.05), iron)
		x += 0.55


static func _dead_tree(d: Node3D, pos: Vector3, h: float) -> void:
	var bark := Color(0.22, 0.18, 0.16)
	_cyl(d, pos + Vector3(0, h * 0.45, 0), 0.16, h, bark)
	_box(d, pos + Vector3(0.55, h * 0.78, 0.05), Vector3(1.15, 0.1, 0.1), bark)
	_box(d, pos + Vector3(-0.45, h * 0.7, -0.1), Vector3(0.95, 0.08, 0.08), bark)
	_box(d, pos + Vector3(0.15, h * 0.92, 0.35), Vector3(0.08, 0.08, 0.85), bark)


static func _web(d: Node3D, pos: Vector3, span: float) -> void:
	var silk := Color(0.78, 0.78, 0.82, 0.55)
	var a := BoxMesh.new()
	a.size = Vector3(span, 0.025, 0.025)
	var mi := _mesh(d, a, pos, silk, 0.05)
	var mat := mi.material_override as StandardMaterial3D
	if mat != null:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.rotation.z = 0.45
	var b := BoxMesh.new()
	b.size = Vector3(span * 0.85, 0.022, 0.022)
	var mi2 := _mesh(d, b, pos + Vector3(0.05, -0.08, 0.02), silk, 0.05)
	var mat2 := mi2.material_override as StandardMaterial3D
	if mat2 != null:
		mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi2.rotation.z = -0.55
	var c := BoxMesh.new()
	c.size = Vector3(span * 0.4, 0.02, 0.02)
	_mesh(d, c, pos + Vector3(0.0, 0.12, 0.0), silk)


static func _fill_temple(d: Node3D, gy: float) -> void:
	_cyl(d, Vector3(0.0, gy + 0.08, -7.5), 4.2, 0.16, Color(0.28, 0.12, 0.32))
	for i in 6:
		var ang := float(i) / 6.0 * TAU
		_cyl(d, Vector3(cos(ang) * 3.2, gy + 1.1, -7.5 + sin(ang) * 2.2), 0.22, 2.2, Color(0.42, 0.18, 0.48))
	_box(d, Vector3(0.0, gy + 0.45, -7.5), Vector3(1.6, 0.9, 1.6), Color(0.55, 0.2, 0.6), 0.25)


static func _fill_inferno(d: Node3D, gy: float) -> void:
	_box(d, Vector3(-8.5, gy + 1.4, -6.0), Vector3(3.4, 2.8, 2.8), Color(0.35, 0.12, 0.1))
	_box(d, Vector3(8.2, gy + 1.1, -5.4), Vector3(3.0, 2.2, 2.6), Color(0.32, 0.1, 0.08))
	for i in 6:
		_cyl(d, Vector3(-8.0 + float(i) * 3.2, gy + 0.7, -4.2), 0.18, 1.4, Color(1.0, 0.45, 0.18), 0.8)
		_cyl(d, Vector3(-8.0 + float(i) * 3.2, gy + 1.25, -4.2), 0.1, 0.55, Color(1.0, 0.85, 0.35), 1.1)
