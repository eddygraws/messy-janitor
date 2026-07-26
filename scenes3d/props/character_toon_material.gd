class_name CharacterToonMaterial
extends RefCounted

## Blender Color Ramp (Constant) toon — character_toon.gdshader wrapper.
## Görsel referans: mor üniforma 3 bant (gölge / orta / highlight) + outline.

const TOON_SHADER := preload("res://shaders/character_toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/mesh_outline.gdshader")


## mid + otomatik gölge/highlight (albedo'dan türetilir).
static func create_from_mid(
	mid: Color,
	shadow_stop: float = 0.42,
	highlight_stop: float = 0.73,
	with_outline: bool = true,
	outline_width: float = 0.022,
) -> ShaderMaterial:
	var shadow := Color(
		mid.r * 0.28 + 0.04,
		mid.g * 0.22 + 0.03,
		mid.b * 0.38 + 0.08,
		1.0
	)
	var highlight := Color(
		minf(mid.r * 1.35 + 0.12, 1.0),
		minf(mid.g * 1.28 + 0.10, 1.0),
		minf(mid.b * 1.22 + 0.14, 1.0),
		1.0
	)
	return create(mid, shadow, highlight, shadow_stop, highlight_stop, with_outline, outline_width)


static func create(
	mid: Color,
	shadow: Color,
	highlight: Color,
	shadow_stop: float = 0.42,
	highlight_stop: float = 0.73,
	with_outline: bool = true,
	outline_width: float = 0.022,
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("mid_color", mid)
	mat.set_shader_parameter("shadow_color", Vector3(shadow.r, shadow.g, shadow.b))
	mat.set_shader_parameter("highlight_color", Vector3(highlight.r, highlight.g, highlight.b))
	mat.set_shader_parameter("shadow_stop", shadow_stop)
	mat.set_shader_parameter("highlight_stop", highlight_stop)
	mat.set_shader_parameter("use_texture", 0.0)
	mat.set_shader_parameter("rim_strength", 0.12)
	mat.set_shader_parameter("ambient_fill", 0.08)
	mat.set_shader_parameter("wrap", 0.45)
	mat.set_shader_parameter("light_gain", 0.55)
	if with_outline:
		mat.next_pass = _make_outline(outline_width)
	return mat


## Blender ekran görüntüsündeki mor üniforma ramp'i (3 stop).
static func preset_uniform_purple(with_outline: bool = true) -> ShaderMaterial:
	return create(
		Color(0.48, 0.30, 0.68), # mid
		Color(0.14, 0.09, 0.24), # shadow
		Color(0.78, 0.66, 0.92), # highlight
		0.42,
		0.73,
		with_outline,
		0.014
	)


static func preset_skin(with_outline: bool = true) -> ShaderMaterial:
	return create(
		Color(0.92, 0.72, 0.58),
		Color(0.42, 0.22, 0.20),
		Color(1.0, 0.88, 0.78),
		0.40,
		0.72,
		with_outline,
		0.012
	)


static func preset_hair(with_outline: bool = true) -> ShaderMaterial:
	return create(
		Color(0.28, 0.16, 0.10),
		Color(0.08, 0.04, 0.03),
		Color(0.48, 0.30, 0.18),
		0.40,
		0.70,
		with_outline,
		0.018
	)


static func preset_dark_apron(with_outline: bool = true) -> ShaderMaterial:
	return create(
		Color(0.18, 0.12, 0.22),
		Color(0.06, 0.04, 0.10),
		Color(0.32, 0.24, 0.38),
		0.40,
		0.72,
		with_outline,
		0.02
	)


static func preset_eyes_white(with_outline: bool = false) -> ShaderMaterial:
	return create(
		Color(0.96, 0.96, 0.98),
		Color(0.55, 0.55, 0.62),
		Color(1.0, 1.0, 1.0),
		0.35,
		0.75,
		with_outline,
		0.012
	)


## Mesh ağacındaki tüm MeshInstance3D materyallerini toon'a çevir.
## name_hints: {"torso": preset_fn, ...} — boşsa hepsine purple uniform.
static func apply_to_node(root: Node, default_preset: String = "purple") -> void:
	if root == null:
		return
	var fallback := _preset_by_name(default_preset)
	_apply_recursive(root, fallback)


static func apply_slots(root: Node, slot_map: Dictionary) -> void:
	## slot_map: {"Body": "skin", "Shirt": "purple", "Hair": "hair"}
	if root == null:
		return
	_apply_slots_recursive(root, slot_map)


static func _apply_recursive(node: Node, mat: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		set_mesh_materials(node as MeshInstance3D, mat)
	for c in node.get_children():
		_apply_recursive(c, mat)


static func _apply_slots_recursive(node: Node, slot_map: Dictionary) -> void:
	if node is MeshInstance3D:
		var key := String(node.name)
		var preset_name := "purple"
		for slot_key in slot_map.keys():
			if key.findn(String(slot_key)) >= 0:
				preset_name = String(slot_map[slot_key])
				break
		set_mesh_materials(node as MeshInstance3D, _preset_by_name(preset_name))
	for c in node.get_children():
		_apply_slots_recursive(c, slot_map)


static func set_mesh_materials(mi: MeshInstance3D, mat: ShaderMaterial) -> void:
	if mi == null or mat == null:
		return
	var count := 0
	if mi.mesh != null:
		count = mi.mesh.get_surface_count()
	if count <= 0:
		mi.material_override = mat
		return
	mi.material_override = null
	for i in count:
		mi.set_surface_override_material(i, mat)


static func preset_by_name(name: String) -> ShaderMaterial:
	return _preset_by_name(name)


static func _preset_by_name(name: String) -> ShaderMaterial:
	match name:
		"skin":
			return preset_skin()
		"hair":
			return preset_hair()
		"apron", "dark":
			return preset_dark_apron()
		"eye", "eyes":
			return preset_eyes_white()
		_:
			return preset_uniform_purple()


static func _make_outline(width: float) -> ShaderMaterial:
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter("outline_color", Color(0.06, 0.04, 0.10, 1.0))
	outline.set_shader_parameter("outline_width", width)
	return outline
