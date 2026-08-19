class_name LiquidScrubMask
extends RefCounted

const LIQUID_SHADER := preload("res://shaders/liquid_scrub.gdshader")
const MASK_SIZE := 128

var _sprite: Sprite2D
var _image: Image
var _texture: ImageTexture
var _material: ShaderMaterial
var _dirty_goal: float = 1.0
var _wipe_sum: float = 0.0


func bind_sprite(sprite: Sprite2D) -> void:
	_sprite = sprite
	_image = Image.create(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_L8)
	_image.fill(Color.BLACK)
	_texture = ImageTexture.create_from_image(_image)
	_material = ShaderMaterial.new()
	_material.shader = LIQUID_SHADER
	_material.set_shader_parameter("scrub_mask", _texture)
	sprite.material = _material
	_dirty_goal = _estimate_dirty_goal()
	_wipe_sum = 0.0


func stamp_world(world_pos: Vector2, effort: float, effectiveness: float) -> bool:
	if _sprite == null or _image == null:
		return false
	var uv := _world_to_uv(world_pos)
	if uv.x < -0.05 or uv.x > 1.05 or uv.y < -0.05 or uv.y > 1.05:
		return false
	var radius := clampf(0.055 + effort * 0.00011, 0.045, 0.14) * effectiveness
	var strength := clampf(0.12 + effort * 0.004, 0.1, 0.38) * effectiveness
	_paint_uv(uv, radius, strength, 1.0)
	_texture.update(_image)
	return true


## Kirli paspas: silinen yere kir geri sürer (VCD hissi).
func smear_world(world_pos: Vector2, effort: float, dirtiness: float) -> bool:
	if _sprite == null or _image == null or dirtiness <= 0.01:
		return false
	var uv := _world_to_uv(world_pos)
	if uv.x < -0.05 or uv.x > 1.05 or uv.y < -0.05 or uv.y > 1.05:
		return false
	var radius := clampf(0.05 + effort * 0.00009, 0.04, 0.12)
	var strength := clampf(0.08 + effort * 0.003, 0.06, 0.28) * dirtiness
	_paint_uv(uv, radius, strength, -1.0)
	_texture.update(_image)
	return true


func get_wipe_ratio() -> float:
	if _dirty_goal <= 0.001:
		return 0.0
	return clampf(_wipe_sum / _dirty_goal, 0.0, 1.0)


## Powerup / script temizliği: hedef wipe oranına kadar maskeyi doldur.
func add_wipe_progress(amount: float) -> float:
	if _image == null or _dirty_goal <= 0.001:
		return 0.0
	var target := clampf(get_wipe_ratio() + amount, 0.0, 1.0)
	var guard := 0
	while get_wipe_ratio() < target - 0.01 and guard < 48:
		_paint_uv(Vector2(randf_range(0.15, 0.85), randf_range(0.15, 0.85)), 0.42, 0.55, 1.0)
		guard += 1
	_texture.update(_image)
	return get_wipe_ratio()


func _world_to_uv(world_pos: Vector2) -> Vector2:
	var local := _sprite.to_local(world_pos)
	var tex_size := _sprite.texture.get_size() * _sprite.scale.abs()
	if tex_size.x < 1.0 or tex_size.y < 1.0:
		return Vector2(-1, -1)
	var half := tex_size * 0.5
	return Vector2((local.x + half.x) / tex_size.x, (local.y + half.y) / tex_size.y)


func _paint_uv(uv: Vector2, radius_norm: float, strength: float, sign: float) -> void:
	var cx := floori(uv.x * float(MASK_SIZE))
	var cy := floori(uv.y * float(MASK_SIZE))
	var r := maxi(1, floori(radius_norm * float(MASK_SIZE)))
	var r_sq := r * r
	for y in range(maxi(0, cy - r), mini(MASK_SIZE, cy + r + 1)):
		for x in range(maxi(0, cx - r), mini(MASK_SIZE, cx + r + 1)):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy > r_sq:
				continue
			var falloff := 1.0 - sqrt(float(dx * dx + dy * dy)) / float(r)
			var old := _image.get_pixel(x, y).r
			var delta := strength * falloff * sign
			var neu := clampf(old + delta, 0.0, 1.0)
			_wipe_sum += neu - old
			_image.set_pixel(x, y, Color(neu, 0.0, 0.0))


func _estimate_dirty_goal() -> float:
	if _sprite == null or _sprite.texture == null:
		return float(MASK_SIZE * MASK_SIZE) * 0.35
	var tex_img: Image = _sprite.texture.get_image()
	if tex_img == null or tex_img.is_empty():
		return float(MASK_SIZE * MASK_SIZE) * 0.35
	var total := 0.0
	for y in MASK_SIZE:
		for x in MASK_SIZE:
			var u := (float(x) + 0.5) / float(MASK_SIZE)
			var v := (float(y) + 0.5) / float(MASK_SIZE)
			var sx := int(u * float(tex_img.get_width()))
			var sy := int(v * float(tex_img.get_height()))
			sx = clampi(sx, 0, tex_img.get_width() - 1)
			sy = clampi(sy, 0, tex_img.get_height() - 1)
			if tex_img.get_pixel(sx, sy).a > 0.08:
				total += 1.0
	return maxf(total, float(MASK_SIZE * MASK_SIZE) * 0.2)
