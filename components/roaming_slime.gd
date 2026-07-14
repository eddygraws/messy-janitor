extends "res://components/draggable_cleanable.gd"

## Miniboss balçık: dolaşırken kir bırakır ve küçülür.
## Yeterince zayıflayınca (küçük ölçek) paspasla GİDER'e sürülebilir.
## Bıraktığı izleri temizlemek de onu daha hızlı zayıflatır.

@export var wander_speed: float = 95.0
@export var retarget_time: float = 1.6
@export var trail_interval: float = 1.25
@export var max_trails: int = 12
@export var trail_gap: float = 90.0
@export var max_scale: float = 1.65
@export var min_scale: float = 0.52
@export var capturable_mass: float = 0.42
@export var shrink_per_trail_drop: float = 0.07
@export var shrink_per_trail_clean: float = 0.11
@export var base_hitbox: Vector2 = Vector2(110, 96)

var _mass: float = 1.0
var _target: Vector2 = Vector2.ZERO
var _retarget_timer: float = 0.0
var _trail_timer: float = 0.0
var _trail_count: int = 0
var _drag_grace: float = 0.0
var _pulse_time: float = 0.0
var _stun_timer: float = 0.0
var _hint_shown: bool = false


func stun(seconds: float) -> void:
	_stun_timer = maxf(_stun_timer, seconds)


func is_capturable() -> bool:
	return _mass <= capturable_mass


func get_mass_ratio() -> float:
	return _mass


func _ready() -> void:
	super._ready()
	add_to_group("SlimeBoss")
	_mass = 1.0
	target_group = &"Drain"
	required_equipment = EQ_MOP
	_apply_visual_scale()
	_pick_target()
	_trail_timer = trail_interval * 0.35


func drag_toward(target: Vector2, delta: float) -> void:
	if not is_capturable():
		return
	_drag_grace = 0.2
	super.drag_toward(target, delta)


func deliver() -> void:
	if not is_capturable():
		return
	_drag_grace = 0.0
	super.deliver()


func _process(delta: float) -> void:
	super._process(delta)
	if is_cleaned() or _is_broken:
		return
	if not _is_in_active_room():
		return

	_pulse_time += delta
	_apply_visual_scale()

	if _stun_timer > 0.0:
		_stun_timer -= delta
		modulate = Color(0.75, 1.0, 0.9)
		return

	if is_capturable():
		# Yakalanabilir: nabızlı yeşil
		var blink := 0.55 + sin(_pulse_time * 6.0) * 0.45
		modulate = Color(0.45, 1.0, 0.65).lerp(Color(0.9, 1.0, 0.75), blink)
	else:
		modulate = Color(0.35, 0.85, 0.5)

	if _drag_grace > 0.0:
		_drag_grace -= delta
		return

	# Henüz yakalanamazken dolaş + kir bırak
	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or global_position.distance_to(_target) < 28.0:
		_pick_target()

	var dir := (_target - global_position).normalized()
	var speed := wander_speed * lerpf(1.15, 0.7, 1.0 - _mass)
	global_position += dir * speed * delta
	if not RoomSpawnBounds.is_on_surface(global_position):
		global_position = RoomSpawnBounds.random_point([], 40.0, 12)
		_pick_target()
	z_index = RoomSpawnBounds.depth_z(global_position.y)

	if _trail_count < max_trails and _mass > capturable_mass * 0.85:
		_trail_timer -= delta
		if _trail_timer <= 0.0:
			_trail_timer = trail_interval
			_try_drop_trail()


func notify_trail_cleaned() -> void:
	if is_cleaned():
		return
	_shrink(shrink_per_trail_clean)
	if is_capturable() and not _hint_shown:
		_hint_shown = true
		_show_capture_hint()


func _shrink(amount: float) -> void:
	_mass = maxf(0.2, _mass - amount)
	_apply_visual_scale()


func _apply_visual_scale() -> void:
	var t := inverse_lerp(0.2, 1.0, _mass)
	var s := lerpf(min_scale, max_scale, clampf(t, 0.0, 1.0))
	var pulse := 1.0
	if is_capturable():
		pulse = 1.0 + sin(_pulse_time * 5.0) * 0.06
	else:
		pulse = 1.0 + sin(_pulse_time * 2.6) * 0.03
	scale = Vector2.ONE * s * pulse
	hitbox_size = base_hitbox * s


func _is_in_active_room() -> bool:
	var rm := get_tree().get_first_node_in_group("RoomManagerGroup")
	if rm == null or not rm.has_method("get_current_room"):
		return true
	return rm.get_current_room() == get_parent()


func _pick_target() -> void:
	_target = RoomSpawnBounds.random_point([], 40.0, 20)
	_retarget_timer = retarget_time * randf_range(0.7, 1.35)


func _try_drop_trail() -> void:
	var room := get_parent() as Node2D
	if room == null:
		return
	if not RoomSpawnBounds.is_on_surface(global_position):
		return
	for child in room.get_children():
		if child.is_in_group("SlimeTrail") and child.has_method("is_cleaned") and not child.is_cleaned():
			if child.global_position.distance_to(global_position) < trail_gap:
				return

	var trail: Node2D = RoomFactory.make_dirt("slime_trail", room.to_local(global_position))
	trail.set_meta("dirt_type", "slime_trail")
	if "dirt_kind" in trail:
		trail.set("dirt_kind", "slime_trail")
	trail.set_meta("boss_owner", self)
	trail.z_index = RoomSpawnBounds.depth_z(global_position.y)
	room.add_child(trail)
	_trail_count += 1
	_shrink(shrink_per_trail_drop)

	if trail.has_signal("cleaned"):
		trail.cleaned.connect(_on_owned_trail_cleaned)

	var rm := get_tree().get_first_node_in_group("RoomManagerGroup")
	if rm != null and rm.has_method("emit_current_objective"):
		rm.emit_current_objective()


func _on_owned_trail_cleaned() -> void:
	notify_trail_cleaned()


func _show_capture_hint() -> void:
	var rm := get_tree().get_first_node_in_group("RoomManagerGroup")
	if rm != null and rm.has_signal("tutorial_requested"):
		rm.tutorial_requested.emit("Balçık zayıfladı! Paspasla yakala ve GİDERE sürükle.")
