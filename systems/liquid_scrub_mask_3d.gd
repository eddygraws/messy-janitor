class_name LiquidScrubMask3D
extends RefCounted

## 3D puddle wipe mask — stamp only (no smear). Progress = wiped area ratio.

const SCRUB_SHADER := preload("res://shaders/liquid_scrub_3d.gdshader")
const MASK_SIZE := 160

var _mesh: MeshInstance3D
var _half_extent: float = 1.0
var _image: Image
var _texture: ImageTexture
var _material: ShaderMaterial
var _dirty_goal: float = 1.0
var _wipe_sum: float = 0.0


func setup(mesh: MeshInstance3D, albedo: Texture2D, half_extent: float, tint: Color = Color.WHITE) -> void:
	_mesh = mesh
	_half_extent = maxf(0.2, half_extent)
	_image = Image.create(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RF)
	_image.fill(Color(0, 0, 0, 1))
	_texture = ImageTexture.create_from_image(_image)
	_material = ShaderMaterial.new()
	_material.shader = SCRUB_SHADER
	_material.set_shader_parameter("albedo_texture", albedo)
	_material.set_shader_parameter("scrub_mask", _texture)
	_material.set_shader_parameter("tint_color", tint)
	_material.set_shader_parameter("opacity", 0.92)
	_material.set_shader_parameter("wet_rim", 1.15)
	mesh.material_override = _material
	_dirty_goal = _estimate_dirty_goal(albedo) * 0.72
	_wipe_sum = 0.0


func stamp_world(world_pos: Vector3, radius_m: float, strength: float) -> float:
	if _mesh == null or _image == null:
		return get_wipe_ratio()
	var local: Vector3 = _mesh.to_local(world_pos)
	var uv := Vector2(
		local.x / (_half_extent * 2.0) + 0.5,
		local.z / (_half_extent * 2.0) + 0.5
	)
	if uv.x < -0.08 or uv.x > 1.08 or uv.y < -0.08 or uv.y > 1.08:
		return get_wipe_ratio()
	var radius_uv := clampf(radius_m / maxf(_half_extent * 2.0, 0.01), 0.07, 0.5)
	var strength_amt := clampf(strength, 0.12, 0.62)
	_paint_uv(uv, radius_uv, strength_amt)
	_texture.update(_image)
	if _material != null:
		_material.set_shader_parameter("scrub_mask", _texture)
	return get_wipe_ratio()


func get_wipe_ratio() -> float:
	if _dirty_goal <= 0.001:
		return 0.0
	return clampf(_wipe_sum / _dirty_goal, 0.0, 1.0)


func _paint_uv(uv: Vector2, radius_norm: float, strength: float) -> void:
	var cx := int(uv.x * float(MASK_SIZE))
	var cy := int(uv.y * float(MASK_SIZE))
	var r := maxi(1, int(radius_norm * float(MASK_SIZE)))
	var r_sq := r * r
	for y in range(maxi(0, cy - r), mini(MASK_SIZE, cy + r + 1)):
		for x in range(maxi(0, cx - r), mini(MASK_SIZE, cx + r + 1)):
			var dx := x - cx
			var dy := y - cy
			var d2 := dx * dx + dy * dy
			if d2 > r_sq:
				continue
			var falloff := 1.0 - sqrt(float(d2)) / float(r)
			falloff = falloff * falloff
			var old := _image.get_pixel(x, y).r
			var neu := clampf(old + strength * falloff, 0.0, 1.0)
			_wipe_sum += neu - old
			_image.set_pixel(x, y, Color(neu, 0.0, 0.0))


func _estimate_dirty_goal(albedo: Texture2D) -> float:
	var fallback := float(MASK_SIZE * MASK_SIZE) * 0.32
	if albedo == null:
		return fallback
	var img := albedo.get_image()
	if img == null or img.is_empty():
		return fallback
	if img.is_compressed():
		img = img.duplicate()
		img.decompress()
	var total := 0.0
	for y in MASK_SIZE:
		for x in MASK_SIZE:
			var u := (float(x) + 0.5) / float(MASK_SIZE)
			var v := (float(y) + 0.5) / float(MASK_SIZE)
			var sx := clampi(int(u * float(img.get_width())), 0, img.get_width() - 1)
			var sy := clampi(int(v * float(img.get_height())), 0, img.get_height() - 1)
			if img.get_pixel(sx, sy).a > 0.08:
				total += 1.0
	return maxf(total, fallback * 0.5)
