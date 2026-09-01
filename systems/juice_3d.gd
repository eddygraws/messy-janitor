extends RefCounted

## P2 juice — tek tablo. Abartı yok: tavanlı shake / FOV, fail = recoil, combo = nabız.

const HIT := &"hit"
const SUCCESS := &"success"
const COMBO := &"combo"
const FAIL := &"fail"
const BURST := &"burst"
const TICK := &"tick"
const PHASE := &"phase"

const SHAKE_CAP := 1.05
const FOV_CAP := 5.5


static func spec(kind: StringName) -> Dictionary:
	match kind:
		HIT:
			return {"shake": 0.22, "fov": 0.0, "pop": 0, "burst": 0.7, "fx": &"hit"}
		SUCCESS:
			return {"shake": 0.32, "fov": 2.4, "pop": 56, "burst": 0.9, "fx": &"clean"}
		COMBO:
			return {"shake": 0.42, "fov": 3.2, "pop": 64, "burst": 1.0, "fx": &"dance"}
		FAIL:
			return {"shake": 0.72, "fov": 4.2, "pop": 56, "burst": 1.1, "fx": &"bump"}
		BURST:
			return {"shake": 0.95, "fov": 5.0, "pop": 0, "burst": 1.2, "fx": &"bump"}
		TICK:
			return {"shake": 0.18, "fov": 0.0, "pop": 52, "burst": 0.0, "fx": &""}
		PHASE:
			return {"shake": 0.55, "fov": 3.6, "pop": 0, "burst": 0.8, "fx": &"bump"}
		_:
			return {"shake": 0.22, "fov": 0.0, "pop": 52, "burst": 0.0, "fx": &""}


static func clamp_shake(amount: float) -> float:
	return clampf(amount, 0.0, SHAKE_CAP)


static func clamp_fov(amount: float) -> float:
	return clampf(amount, 0.0, FOV_CAP)


static func pop_px(kind: StringName) -> int:
	return int(spec(kind).get("pop", 56))


static func apply(camera: Node, kind: StringName, particles: Node = null, world_pos: Vector3 = Vector3.ZERO) -> Dictionary:
	var s := spec(kind)
	if camera != null:
		if camera.has_method("shake"):
			camera.call("shake", float(s["shake"]))
		if float(s["fov"]) > 0.05 and camera.has_method("punch_fov"):
			camera.call("punch_fov", float(s["fov"]))
	var fx: StringName = s["fx"] as StringName
	var burst_n := float(s["burst"])
	if particles != null and burst_n > 0.01 and fx != &"" and particles.has_method("burst"):
		particles.call("burst", fx, world_pos, burst_n)
	return s
