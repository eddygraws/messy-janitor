class_name PropCatalog3D
extends RefCounted

## 3D prop asset çözümleyici — dosya yoksa null; RNG ile varyant seçer.
## Beklenen klasörler: assets/props/boxes|rocks|foliage (+ map/forest)

const BOX_DIR := "res://assets/props/boxes/"
const ROCK_DIR := "res://assets/props/rocks/"
const FOLIAGE_DIR := "res://assets/props/foliage/"

## İsim + Blender export alias’ları
const BOX_UPRIGHT_CANDIDATES: Array[String] = [
	"box_cardboard_a",
	"box_cardboard_b",
	"kutu1",
	"kutu2",
	"box_a",
	"box_b",
]
const BOX_FALLEN_CANDIDATES: Array[String] = [
	"box_cardboard_fallen",
	"kutu_fallen",
	"box_fallen",
]
const ROCK_CANDIDATES: Array[String] = [
	"rock_a",
	"rock_b",
	"rock_a ", # yanlışlıkla boşluklu export
	"kaya1",
	"kaya2",
]
const TREE_CANDIDATES: Array[String] = [
	"tree_plane_a",
	"tree_plane_b",
	"tree_plane_c",
]
const BUSH_CANDIDATES: Array[String] = [
	"bush_plane_a",
	"bush_plane_b",
]

static var _box_upright_cache: Array[Dictionary] = []
static var _box_fallen_cache: Array[Dictionary] = []
static var _rock_cache: Array[Dictionary] = []
static var _tree_cache: Array[Texture2D] = []
static var _bush_cache: Array[Texture2D] = []
static var _scanned: bool = false


static func refresh() -> void:
	_scanned = false
	_ensure_scanned()


static func _ensure_scanned() -> void:
	if _scanned:
		return
	_scanned = true
	_box_upright_cache = _scan_mesh_props(BOX_DIR, BOX_UPRIGHT_CANDIDATES)
	_box_fallen_cache = _scan_mesh_props(BOX_DIR, BOX_FALLEN_CANDIDATES)
	_rock_cache = _scan_mesh_props(ROCK_DIR, ROCK_CANDIDATES)
	_tree_cache = _scan_textures(FOLIAGE_DIR, TREE_CANDIDATES)
	_bush_cache = _scan_textures(FOLIAGE_DIR, BUSH_CANDIDATES)


## { "id", "mesh": Mesh|null, "texture": Texture2D|null, "fallen": bool }
static func pick_box(rng: RandomNumberGenerator, prefer_fallen: bool = false) -> Dictionary:
	_ensure_scanned()
	if prefer_fallen and not _box_fallen_cache.is_empty():
		return _box_fallen_cache[rng.randi() % _box_fallen_cache.size()].duplicate()
	# ~18% yıkık şansı (fallen asset varsa)
	if not prefer_fallen and not _box_fallen_cache.is_empty() and rng.randf() < 0.18:
		return _box_fallen_cache[rng.randi() % _box_fallen_cache.size()].duplicate()
	if not _box_upright_cache.is_empty():
		return _box_upright_cache[rng.randi() % _box_upright_cache.size()].duplicate()
	if not _box_fallen_cache.is_empty():
		return _box_fallen_cache[rng.randi() % _box_fallen_cache.size()].duplicate()
	return {}


static func pick_rock(rng: RandomNumberGenerator) -> Dictionary:
	_ensure_scanned()
	if _rock_cache.is_empty():
		return {}
	return _rock_cache[rng.randi() % _rock_cache.size()].duplicate()


static func pick_tree_tex(rng: RandomNumberGenerator) -> Texture2D:
	_ensure_scanned()
	if _tree_cache.is_empty():
		return null
	return _tree_cache[rng.randi() % _tree_cache.size()]


static func pick_bush_tex(rng: RandomNumberGenerator) -> Texture2D:
	_ensure_scanned()
	if _bush_cache.is_empty():
		return null
	return _bush_cache[rng.randi() % _bush_cache.size()]


static func has_box_assets() -> bool:
	_ensure_scanned()
	return not _box_upright_cache.is_empty() or not _box_fallen_cache.is_empty()


static func has_rock_assets() -> bool:
	_ensure_scanned()
	return not _rock_cache.is_empty()


## Python tile generator tarzı: hafif renk / ölçek jitter
static func roll_box_xform(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"yaw": rng.randf_range(-PI, PI),
		"tilt_x": rng.randf_range(-0.06, 0.06),
		"tilt_z": rng.randf_range(-0.06, 0.06),
		"scale": rng.randf_range(0.88, 1.12),
		"size_jitter": Vector3(
			rng.randf_range(0.92, 1.08),
			rng.randf_range(0.9, 1.1),
			rng.randf_range(0.92, 1.08)
		),
		"offset": Vector3(
			rng.randf_range(-0.05, 0.05),
			0.0,
			rng.randf_range(-0.05, 0.05)
		),
		"tint": Color(
			rng.randf_range(0.94, 1.06),
			rng.randf_range(0.94, 1.04),
			rng.randf_range(0.9, 1.02),
			1.0
		),
	}


static func roll_rock_xform(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"yaw": rng.randf_range(0.0, TAU),
		"tilt_x": rng.randf_range(-0.2, 0.2),
		"tilt_z": rng.randf_range(-0.15, 0.15),
		"scale": Vector3(
			rng.randf_range(0.75, 1.35),
			rng.randf_range(0.55, 0.95),
			rng.randf_range(0.75, 1.35)
		),
	}


static func _scan_mesh_props(dir: String, stems: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for stem in stems:
		var key := stem.strip_edges()
		if seen.has(key):
			continue
		var packed := _try_load_scene(dir, stem)
		var mesh := _try_load_mesh(dir, stem)
		var tex := _try_load_texture(dir, stem)
		# MTL’deki map_Kd alias (kutu1.png vb.)
		if tex == null and stem.begins_with("box_cardboard"):
			tex = _try_load_texture(dir, "kutu1" if stem.ends_with("_a") else "kutu2")
		if tex == null and stem.begins_with("rock_"):
			# Blender yan ürün isimleri
			tex = _try_load_texture(dir, stem + "_Cube")
			if tex == null:
				tex = _try_load_texture(dir, stem + "_Material")
		# GLB gömülü albedo
		if tex == null and packed != null:
			tex = _texture_from_scene(packed)
		if mesh == null and packed != null:
			mesh = _mesh_from_scene(packed)
		if mesh == null and tex == null and packed == null:
			continue
		seen[key] = true
		out.append({
			"id": key,
			"mesh": mesh,
			"texture": tex,
			"scene": packed,
			"fallen": stem.find("fallen") >= 0,
		})
	return out


static func _scan_textures(dir: String, stems: Array[String]) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for stem in stems:
		var tex := _try_load_texture(dir, stem)
		if tex == null:
			var packed := _try_load_scene(dir, stem)
			if packed != null:
				tex = _texture_from_scene(packed)
		if tex != null:
			out.append(tex)
	return out


static func _try_load_texture(dir: String, stem: String) -> Texture2D:
	var names: Array[String] = [
		stem,
		stem + "_Cube",
		stem + "_Material",
		stem + "_BaseColor",
		stem + "_albedo",
		stem + "_diff",
		stem + "_kutu1",
		stem + "_kutu2",
		stem + "_Untitled",
		stem + "_treetrunl",
	]
	# rock_a → rock_a_Cube (Blender export)
	if stem == "rock_a":
		names.append("rock_a_Cube")
	if stem == "rock_b":
		names.append("rock_b_Material")
	if stem == "box_cardboard_a":
		names.append_array(["box_cardboard_a_kutu2", "kutu1", "kutu2"])
	if stem == "box_cardboard_b":
		names.append_array(["box_cardboard_b_Untitled", "kutu2", "kutu1"])
	if stem == "tree_plane_a":
		names.append("tree_plane_a_treetrunl")
	for name: String in names:
		for ext: String in [".png", ".webp", ".jpg", ".jpeg"]:
			var path: String = dir + name + ext
			if ResourceLoader.exists(path):
				return load(path) as Texture2D
	# Stem önekli yan ürünler (Blender: stem_Anything.png)
	var prefix_hit := _texture_by_stem_prefix(dir, stem)
	if prefix_hit != null:
		return prefix_hit
	# MTL map_Kd
	return _texture_from_mtl(dir, stem)


static func _texture_by_stem_prefix(dir: String, stem: String) -> Texture2D:
	var da := DirAccess.open(dir)
	if da == null:
		return null
	da.list_dir_begin()
	var file := da.get_next()
	var best: String = ""
	while file != "":
		if not da.current_is_dir():
			var lower := file.to_lower()
			if lower.begins_with(stem.to_lower() + "_") or lower.begins_with(stem.to_lower() + "."):
				if lower.ends_with(".png") or lower.ends_with(".webp") or lower.ends_with(".jpg") or lower.ends_with(".jpeg"):
					# .import dosyalarını atla
					if not lower.ends_with(".import"):
						best = file
						break
		file = da.get_next()
	da.list_dir_end()
	if best.is_empty():
		return null
	var path: String = dir + best
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static func _texture_from_mtl(dir: String, stem: String) -> Texture2D:
	var mtl_path := dir + stem + ".mtl"
	if not FileAccess.file_exists(mtl_path):
		return null
	var f := FileAccess.open(mtl_path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	for line in text.split("\n"):
		var s := line.strip_edges()
		if not s.begins_with("map_Kd"):
			continue
		var parts := s.split(" ", false)
		if parts.size() < 2:
			continue
		var tex_name := parts[parts.size() - 1].replace("\\", "/").get_file()
		var path := dir + tex_name
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
		# Sadece stem önekli ara
		var hit := _texture_by_stem_prefix(dir, stem)
		if hit != null:
			return hit
	return null


static func _try_load_scene(dir: String, stem: String) -> PackedScene:
	for ext: String in [".glb", ".gltf", ".fbx"]:
		var path: String = dir + stem + ext
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is PackedScene:
				return res as PackedScene
	return null


static func _try_load_mesh(dir: String, stem: String) -> Mesh:
	# GLB önce (gömülü UV/material daha temiz)
	var packed := _try_load_scene(dir, stem)
	if packed != null:
		var from_glb := _mesh_from_scene(packed)
		if from_glb != null:
			return from_glb
	for ext: String in [".obj", ".res", ".tres", ".mesh"]:
		var path: String = dir + stem + ext
		if not ResourceLoader.exists(path):
			continue
		var res = load(path)
		if res is Mesh:
			return res as Mesh
		if res is PackedScene:
			return _mesh_from_scene(res as PackedScene)
	return null


static func _mesh_from_scene(scene: PackedScene) -> Mesh:
	if scene == null:
		return null
	var root := scene.instantiate()
	var found: Mesh = null
	if root is MeshInstance3D:
		found = (root as MeshInstance3D).mesh
	else:
		for child in root.find_children("*", "MeshInstance3D", true, false):
			var mi := child as MeshInstance3D
			if mi != null and mi.mesh != null:
				found = mi.mesh
				break
	root.free()
	return found


static func _texture_from_scene(scene: PackedScene) -> Texture2D:
	if scene == null:
		return null
	var root := scene.instantiate()
	var found: Texture2D = null
	var nodes: Array = []
	if root is MeshInstance3D:
		nodes.append(root)
	nodes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	for n in nodes:
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		found = _texture_from_material(mi.material_override)
		if found != null:
			break
		if mi.mesh != null:
			for si in mi.mesh.get_surface_count():
				found = _texture_from_material(mi.get_active_material(si))
				if found != null:
					break
				found = _texture_from_material(mi.mesh.surface_get_material(si))
				if found != null:
					break
		if found != null:
			break
	root.free()
	return found


static func _texture_from_material(mat: Material) -> Texture2D:
	if mat == null:
		return null
	if mat is StandardMaterial3D:
		return (mat as StandardMaterial3D).albedo_texture
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).albedo_texture
	if mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		var t = sm.get_shader_parameter("albedo_texture")
		if t is Texture2D:
			return t as Texture2D
		t = sm.get_shader_parameter("albedo_tex")
		if t is Texture2D:
			return t as Texture2D
	return null
