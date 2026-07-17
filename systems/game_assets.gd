class_name GameAssets
extends RefCounted

## Kendi PNG'lerini `res://assets/tools/` altına koy — dosya yoksa renkli placeholder kullanılır.

const TOOL_DIR := "res://assets/tools/"
const ASSET_DIR := "res://assets/"

# Dosya adı farklıysa buradan eşleştir (senin asset isimlerin dahil)
const DIRT_ALIASES: Dictionary = {
	"stain": ["dirt_stain.png", "dust_stain.png"],
	"scrub": ["dirt_scrub.png", "dust-export.png", "dust-export2.png", "dust-export3.png"],
	"hidden": ["dirt_hidden.png", "dust-export3.png"],
	"slime": ["dirt_slime.png"],
	"slime_boss": ["dirt_slime.png"],
	"slime_trail": ["dirt_slime.png", "dirt_scrub.png"],
	"potion": ["dirt_potion.png", "dirt_hidden.png", "dust_stain.png", "dirt_scrub.png"],
	"broom": ["dirt_crumbs.png"],
	"brush": ["dirt_brush.png"],
	"spray": ["dirt_spray.png"],
	"tweezers": ["dirt_tweezers.png"],
	"fragile": ["dirt_fragile.png"],
	"mold": ["dirt_mold.png", "dust-export2.png"],
	"mop_fragile": ["dirt_fragile.png"],
	"mop_mold": ["dirt_mold.png", "dust-export2.png"],
	"mop_stain": ["dirt_scrub.png", "dust-export.png"],
}

## Map kir sprite ölçeği (~0.46 ≈ önceki 0.23'ün 2 katı)
const DIRT_GLOBAL_SCALE := 0.46

# Eski / alternatif konumlar (assets/ kökündeki dosyalar da okunur)
const LEGACY_EQUIPMENT: Array[String] = [
	"res://assets/tool-ui-asset-mop.png",
	"",
	"res://assets/tool-ui-asset-brush.png",
	"",
	"",
]

const CURSOR_FILES: Array[String] = [
	"cursor_mop.png",
	"cursor_broom.png",
	"cursor_brush.png",
	"cursor_spray.png",
	"cursor_tweezers.png",
]

const ICON_FILES: Array[String] = [
	"icon_mop.png",
	"icon_broom.png",
	"icon_brush.png",
	"icon_spray.png",
	"icon_tweezers.png",
]

const CURSOR_OFFSETS: Array[Vector2] = [
	Vector2(0.75, -4.75),
	Vector2(0.5, -4.25),
	Vector2(0.25, -3.75),
	Vector2(1.0, -4.5),
	Vector2(0.0, -3.0),
]

const CURSOR_SCALES: Array[float] = [0.125, 0.125, 0.125, 0.125, 0.125]

const EQUIPMENT_ICON_SCALE := 0.125

const DIRT_FILES: Dictionary = {
	"stain": "dirt_stain.png",
	"scrub": "dirt_scrub.png",
	"hidden": "dirt_hidden.png",
	"slime": "dirt_slime.png",
	"slime_boss": "dirt_slime.png",
	"slime_trail": "dirt_slime.png",
	"potion": "dirt_potion.png",
	"broom": "dirt_crumbs.png",
	"brush": "dirt_brush.png",
	"spray": "dirt_spray.png",
	"tweezers": "dirt_tweezers.png",
	"fragile": "dirt_fragile.png",
	"mold": "dirt_mold.png",
	"mop_fragile": "dirt_fragile.png",
	"mop_mold": "dirt_mold.png",
	"mop_stain": "dirt_scrub.png",
}

const DIRT_SCALES: Dictionary = {
	"stain": 0.85,
	"scrub": 1.0,
	"hidden": 0.95,
	"slime": 0.8,
	"slime_boss": 1.2,
	"slime_trail": 0.55,
	"potion": 1.05,
	"broom": 0.75,
	"brush": 0.95,
	"spray": 1.15,
	"tweezers": 0.65,
	"fragile": 0.9,
	"mold": 1.0,
	"mop_fragile": 0.9,
	"mop_mold": 1.0,
	"mop_stain": 1.0,
}

const DIRT_FALLBACK: Dictionary = {
	"stain": Color(0.4, 0.32, 0.24),
	"scrub": Color(0.45, 0.3, 0.2),
	"hidden": Color(0.5, 0.35, 0.6),
	"slime": Color(0.35, 0.7, 0.42),
	"slime_boss": Color(0.25, 0.9, 0.45),
	"slime_trail": Color(0.4, 0.75, 0.48),
	"potion": Color(0.7, 0.3, 0.9),
	"broom": Color(0.6, 0.48, 0.3),
	"brush": Color(0.3, 0.28, 0.24),
	"spray": Color(0.55, 0.75, 0.9),
	"tweezers": Color(0.85, 0.92, 1.0),
	"fragile": Color(0.4, 0.55, 0.85),
	"mold": Color(0.3, 0.42, 0.22),
	"mop_fragile": Color(0.4, 0.55, 0.85),
	"mop_mold": Color(0.3, 0.42, 0.22),
	"mop_stain": Color(0.45, 0.3, 0.2),
}

static var _cache: Dictionary = {}


static func get_cursor_texture(equipment_type: int) -> Texture2D:
	var idx := clampi(equipment_type, 0, CURSOR_FILES.size() - 1)
	var paths: Array[String] = [
		TOOL_DIR + CURSOR_FILES[idx],
		ASSET_DIR + CURSOR_FILES[idx],
	]
	if LEGACY_EQUIPMENT[idx] != "":
		paths.append(LEGACY_EQUIPMENT[idx])
	return _load_first(paths, CURSOR_FALLBACK_COLOR(idx), Vector2i(96, 96))


static func get_cursor_offset(equipment_type: int) -> Vector2:
	var idx := clampi(equipment_type, 0, CURSOR_OFFSETS.size() - 1)
	return CURSOR_OFFSETS[idx]


static func get_cursor_scale(equipment_type: int) -> float:
	var idx := clampi(equipment_type, 0, CURSOR_SCALES.size() - 1)
	return CURSOR_SCALES[idx]


static func get_equipment_icon(equipment_type: int) -> Texture2D:
	var idx := clampi(equipment_type, 0, ICON_FILES.size() - 1)
	var paths: Array[String] = [
		TOOL_DIR + ICON_FILES[idx],
		ASSET_DIR + ICON_FILES[idx],
	]
	if LEGACY_EQUIPMENT[idx] != "":
		paths.append(LEGACY_EQUIPMENT[idx])
	return _load_first(paths, EquipmentComponent.COLORS[idx], Vector2i(48, 48))


static func get_dirt_texture(dirt_type: String) -> Texture2D:
	var fallback: Color = DIRT_FALLBACK.get(dirt_type, Color(0.45, 0.35, 0.28))
	var names: Array = DIRT_ALIASES.get(dirt_type, [DIRT_FILES.get(dirt_type, "dirt_scrub.png")])
	var paths: Array[String] = []
	for file_name in names:
		paths.append(TOOL_DIR + String(file_name))
		paths.append(ASSET_DIR + String(file_name))
	return _load_first(paths, fallback, Vector2i(128, 128))


static func get_dirt_scale(dirt_type: String) -> float:
	return float(DIRT_SCALES.get(dirt_type, 1.0)) * DIRT_GLOBAL_SCALE


static func get_bucket_body() -> Texture2D:
	return _load_first([
		ASSET_DIR + "bucket-body.png",
		ASSET_DIR + "bucket_body.png",
		TOOL_DIR + "bucket_body.png",
		TOOL_DIR + "bucket-body.png",
	], Color(0.32, 0.34, 0.4), Vector2i(140, 152))


static func get_bucket_water() -> Texture2D:
	return _load_first([
		ASSET_DIR + "bucket-water.png",
		ASSET_DIR + "bucket_water.png",
		TOOL_DIR + "bucket_water.png",
		TOOL_DIR + "bucket-water.png",
	], Color(0.35, 0.62, 0.9), Vector2i(128, 64))


static func get_bucket_glow() -> Texture2D:
	return _load_first([
		ASSET_DIR + "bucket-glow.png",
		ASSET_DIR + "bucket_glow.png",
		TOOL_DIR + "bucket_glow.png",
		TOOL_DIR + "bucket-glow.png",
	], Color(1.0, 0.7, 0.25, 0.55), Vector2i(196, 224))


static func get_zone_texture(group: StringName) -> Texture2D:
	if group == &"TrashBin":
		return _load(TOOL_DIR + "zone_trash.png", Color(0.28, 0.3, 0.34), Vector2i(140, 140))
	return _load(TOOL_DIR + "zone_drain.png", Color(0.09, 0.09, 0.12), Vector2i(140, 140))


static func get_crosshair() -> Texture2D:
	return _load(TOOL_DIR + "crosshair.png", Color(0.2, 0.9, 0.5, 0.55), Vector2i(12, 12))


static func get_forbidden_ring() -> Texture2D:
	return _load(TOOL_DIR + "forbidden_ring.png", Color(1.0, 0.25, 0.2, 0.45), Vector2i(160, 160))


static func CURSOR_FALLBACK_COLOR(idx: int) -> Color:
	if idx >= 0 and idx < EquipmentComponent.COLORS.size():
		return EquipmentComponent.COLORS[idx]
	return Color(0.85, 0.82, 0.7)


static func _load(path: String, fallback: Color, size: Vector2i) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			return tex
	return _placeholder(fallback, size)


static func _load_first(paths: Array, fallback: Color, size: Vector2i) -> Texture2D:
	for path in paths:
		if String(path) == "":
			continue
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				return tex
	return _placeholder(fallback, size)


static func _placeholder(color: Color, size: Vector2i) -> Texture2D:
	var key := "%s_%s_%s" % [color, size.x, size.y]
	if _cache.has(key):
		return _cache[key] as Texture2D
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := size.x * 0.5
	var cy := size.y * 0.5
	var rx := size.x * 0.42
	var ry := size.y * 0.42
	for y in size.y:
		for x in size.x:
			var dx := (float(x) - cx) / rx
			var dy := (float(y) - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				var edge := clampf(1.0 - (dx * dx + dy * dy), 0.0, 1.0)
				img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * edge))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
