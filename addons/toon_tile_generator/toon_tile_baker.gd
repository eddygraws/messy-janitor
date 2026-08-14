@tool
extends RefCounted
class_name ToonTileBaker

## Pure-GDScript fallback (no Python). Same ideas: hard grout, quantized stains, tile tint.

enum Pattern { FLOOR, WALL_BRICK }


static func bake_to_path(
	path: String,
	pattern: Pattern,
	main: Color,
	grout: Color,
	stain: Color,
	size: int = 1024,
	tiles: int = 4,
	grout_px: int = 6,
	seed: int = 7,
) -> Error:
	var img := generate(pattern, main, grout, stain, size, tiles, grout_px, seed)
	var abs_path := ProjectSettings.globalize_path(path)
	var dir := abs_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var err := img.save_png(abs_path)
	if err != OK:
		return err
	_write_import_sidecar(path)
	return OK


static func generate(
	pattern: Pattern,
	main: Color,
	grout: Color,
	stain: Color,
	size: int = 1024,
	tiles: int = 4,
	grout_px: int = 6,
	seed: int = 7,
) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var img: Image
	if pattern == Pattern.WALL_BRICK:
		img = _gen_wall_brick(rng, main, grout, size, tiles, grout_px)
	else:
		img = _gen_floor(rng, main, grout, size, tiles, grout_px)
	_apply_stains(img, rng, stain, 22 if pattern == Pattern.WALL_BRICK else 26)
	return img


static func _gen_floor(
	rng: RandomNumberGenerator,
	main: Color,
	grout: Color,
	size: int,
	tiles: int,
	grout_px: int,
) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(main)
	var tile := int(size / float(tiles))
	var half := int(grout_px / 2.0)
	for i in tiles + 1:
		var x := i * tile
		img.fill_rect(Rect2i(x - half, 0, grout_px + 1, size), grout)
		var y := i * tile
		img.fill_rect(Rect2i(0, y - half, size, grout_px + 1), grout)
	for ty in tiles:
		for tx in tiles:
			var variation := rng.randi_range(-6, 6) / 255.0
			var c := Color(
				clampf(main.r + variation, 0.0, 1.0),
				clampf(main.g + variation, 0.0, 1.0),
				clampf(main.b + variation, 0.0, 1.0)
			)
			var x0 := tx * tile + grout_px
			var y0 := ty * tile + grout_px
			var x1 := (tx + 1) * tile - grout_px
			var y1 := (ty + 1) * tile - grout_px
			_blend_rect(img, Rect2i(x0, y0, maxi(1, x1 - x0), maxi(1, y1 - y0)), c, 0.25)
	return img


static func _gen_wall_brick(
	rng: RandomNumberGenerator,
	main: Color,
	grout: Color,
	size: int,
	tiles: int,
	grout_px: int,
) -> Image:
	var cols := tiles
	var rows := maxi(tiles + 1, int(tiles * 1.25))
	var brick_w := int(size / float(cols))
	var brick_h := int(size / float(rows))
	var half := int(grout_px / 2.0)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(grout)
	for row in rows + 1:
		var y0 := (row % rows) * brick_h
		var offset := int(brick_w / 2.0) if (row % 2) == 1 else 0
		for col in range(-1, cols + 1):
			var x0 := col * brick_w + offset
			var variation := rng.randi_range(-8, 8) / 255.0
			var c := Color(
				clampf(main.r + variation, 0.0, 1.0),
				clampf(main.g + variation, 0.0, 1.0),
				clampf(main.b + variation, 0.0, 1.0)
			)
			for ox in [-size, 0, size]:
				var ix0 := x0 + half + ox
				var iy0 := y0 + half
				var ix1 := x0 + brick_w - half + ox
				var iy1 := y0 + brick_h - half
				var cx0 := clampi(ix0, 0, size)
				var cx1 := clampi(ix1, 0, size)
				var cy0 := clampi(iy0, 0, size)
				var cy1 := clampi(iy1, 0, size)
				if cx1 > cx0 and cy1 > cy0:
					img.fill_rect(Rect2i(cx0, cy0, cx1 - cx0, cy1 - cy0), c)
	return img


static func _blend_rect(img: Image, rect: Rect2i, color: Color, amount: float) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var src := img.get_pixel(x, y)
			img.set_pixel(x, y, src.lerp(color, amount))


static func _apply_stains(img: Image, rng: RandomNumberGenerator, stain: Color, num_blobs: int) -> void:
	var size := img.get_width()
	# Sparse blob centers — hard threshold after soft falloff sample
	var blobs: Array[Dictionary] = []
	for _i in num_blobs:
		blobs.append({
			"cx": rng.randf() * size,
			"cy": rng.randf() * size,
			"r": rng.randf_range(size * 0.03, size * 0.09),
			"s": rng.randf_range(0.3, 0.7),
		})
	# Sample on a coarser grid then nearest expand for speed
	var step := 2
	var acc := PackedFloat32Array()
	acc.resize(size * size)
	acc.fill(0.0)
	for y in range(0, size, step):
		for x in range(0, size, step):
			var total := 0.0
			for b in blobs:
				var r: float = b["r"]
				var strength: float = b["s"]
				for ox in [-size, 0, size]:
					for oy in [-size, 0, size]:
						var dx: float = float(x) - (float(b["cx"]) + float(ox))
						var dy: float = float(y) - (float(b["cy"]) + float(oy))
						var d := sqrt(dx * dx + dy * dy)
						var m := clampf(1.0 - d / r, 0.0, 1.0)
						total += m * m * strength
			var v := 1.0 if total > 0.35 else 0.0
			for yy in range(y, mini(y + step, size)):
				for xx in range(x, mini(x + step, size)):
					acc[yy * size + xx] = v
	for y in size:
		for x in size:
			var m: float = acc[y * size + x] * 0.5
			if m <= 0.001:
				continue
			var src := img.get_pixel(x, y)
			img.set_pixel(x, y, src.lerp(stain, m))


static func _write_import_sidecar(res_path: String) -> void:
	## mipmaps on; repeat handled in toon_shader (repeat_enable).
	var abs_png := ProjectSettings.globalize_path(res_path)
	var import_path := abs_png + ".import"
	var digest := res_path.md5_text()
	var file_name := res_path.get_file()
	var dest := "res://.godot/imported/%s-%s.ctex" % [file_name, digest]
	var uid := "uid://g%s" % digest.substr(0, 13)
	var body := """[remap]

importer=\"texture\"
type=\"CompressedTexture2D\"
uid=\"%s\"
path=\"%s\"
metadata={
\"vram_texture\": false
}

[deps]

source_file=\"%s\"
dest_files=[\"%s\"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=\"\"
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
""" % [uid, dest, res_path, dest]
	var f := FileAccess.open(import_path, FileAccess.WRITE)
	if f != null:
		f.store_string(body)


static func bake_campaign_batch(size: int = 1024, tiles: int = 4) -> PackedStringArray:
	var jobs: Array[Dictionary] = [
		{"name": "floor_kitchen_clay", "pattern": Pattern.FLOOR, "main": Color8(196, 182, 158), "grout": Color8(138, 126, 108), "stain": Color8(168, 156, 134), "seed": 7},
		{"name": "floor_mold_green", "pattern": Pattern.FLOOR, "main": Color8(92, 128, 98), "grout": Color8(58, 82, 64), "stain": Color8(72, 108, 80), "seed": 11},
		{"name": "floor_broom_wood", "pattern": Pattern.FLOOR, "main": Color8(168, 128, 86), "grout": Color8(110, 82, 54), "stain": Color8(148, 112, 74), "seed": 19},
		{"name": "floor_slime_teal", "pattern": Pattern.FLOOR, "main": Color8(70, 130, 122), "grout": Color8(42, 86, 80), "stain": Color8(58, 112, 104), "seed": 23},
		{"name": "floor_brush_purple", "pattern": Pattern.FLOOR, "main": Color8(148, 108, 168), "grout": Color8(96, 68, 112), "stain": Color8(128, 92, 148), "seed": 29},
		{"name": "floor_check_dark", "pattern": Pattern.FLOOR, "main": Color8(62, 64, 78), "grout": Color8(36, 38, 48), "stain": Color8(78, 80, 96), "seed": 31},
		{"name": "wall_plaster_warm", "pattern": Pattern.WALL_BRICK, "main": Color8(210, 198, 182), "grout": Color8(150, 140, 128), "stain": Color8(188, 176, 160), "seed": 41},
		{"name": "wall_brick_garage", "pattern": Pattern.WALL_BRICK, "main": Color8(168, 112, 92), "grout": Color8(96, 72, 62), "stain": Color8(148, 98, 80), "seed": 47},
		{"name": "wall_brick_mold", "pattern": Pattern.WALL_BRICK, "main": Color8(98, 132, 108), "grout": Color8(62, 88, 72), "stain": Color8(80, 118, 92), "seed": 53},
		{"name": "wall_brick_ritual", "pattern": Pattern.WALL_BRICK, "main": Color8(118, 72, 128), "grout": Color8(72, 42, 80), "stain": Color8(102, 62, 112), "seed": 59},
	]
	var out := PackedStringArray()
	for job in jobs:
		var path := "res://textures/generated/%s.png" % String(job["name"])
		var err := bake_to_path(
			path,
			job["pattern"],
			job["main"],
			job["grout"],
			job["stain"],
			size,
			tiles,
			6,
			int(job["seed"]),
		)
		if err == OK:
			out.append(path)
	return out
