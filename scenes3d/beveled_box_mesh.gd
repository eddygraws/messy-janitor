class_name BeveledBoxMesh
extends RefCounted

## Skybox: bevel'li duvarlar (zemin/tavan yok) veya tam kutu.

static var _cache: ArrayMesh
static var _cache_key: String = ""


## Sadece 4 yan duvar — zemin/tavan yok.
static func create_walls(size: Vector3, bevel: float = 0.22, segments: int = 14) -> ArrayMesh:
	return _build(size, bevel, segments, true)


static func create(size: Vector3, bevel: float = 0.22, segments: int = 14) -> ArrayMesh:
	return _build(size, bevel, segments, false)


static func _build(size: Vector3, bevel: float, segments: int, walls_only: bool) -> ArrayMesh:
	var key := "%s_%.3f_%d_%s" % [str(size), bevel, segments, walls_only]
	if _cache != null and _cache_key == key:
		return _cache
	var half := size * 0.5
	var b := clampf(bevel, 0.0, 0.85)
	var seg := clampi(segments, 4, 32)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 0:+X 1:-X 2:+Y 3:-Y 4:+Z 5:-Z — walls_only ise Y yüzleri atlanır
	for face in 6:
		if walls_only and (face == 2 or face == 3):
			continue
		_add_face(st, face, half, b, seg)

	st.generate_normals()
	_cache = st.commit()
	_cache_key = key
	return _cache


static func _add_face(st: SurfaceTool, face: int, half: Vector3, bevel: float, seg: int) -> void:
	for j in seg:
		for i in seg:
			var u0 := -1.0 + 2.0 * float(i) / float(seg)
			var u1 := -1.0 + 2.0 * float(i + 1) / float(seg)
			var v0 := -1.0 + 2.0 * float(j) / float(seg)
			var v1 := -1.0 + 2.0 * float(j + 1) / float(seg)
			var p00 := _rounded_cube_point(face, u0, v0, half, bevel)
			var p10 := _rounded_cube_point(face, u1, v0, half, bevel)
			var p01 := _rounded_cube_point(face, u0, v1, half, bevel)
			var p11 := _rounded_cube_point(face, u1, v1, half, bevel)
			_tri(st, p00, p10, p11)
			_tri(st, p00, p11, p01)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_normal((b - a).cross(c - a).normalized())
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


static func _rounded_cube_point(face: int, u: float, v: float, half: Vector3, bevel: float) -> Vector3:
	var p := Vector3.ZERO
	match face:
		0:
			p = Vector3(1.0, u, v)
		1:
			p = Vector3(-1.0, u, v)
		2:
			p = Vector3(u, 1.0, v)
		3:
			p = Vector3(u, -1.0, v)
		4:
			p = Vector3(u, v, 1.0)
		_:
			p = Vector3(u, v, -1.0)

	var on_cube := p
	var on_sphere := p.normalized()
	var mixed := on_cube.lerp(on_sphere, bevel)
	var m := maxf(absf(mixed.x), maxf(absf(mixed.y), absf(mixed.z)))
	if m > 0.0001:
		mixed /= m
	mixed = mixed.lerp(mixed.normalized(), bevel * 0.45)
	return Vector3(mixed.x * half.x, mixed.y * half.y, mixed.z * half.z)
