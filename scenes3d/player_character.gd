class_name PlayerCharacter3D
extends CharacterBody3D

## Overcooked tarzı: hareket, dash, tut/fırlat, kova durulama, yönlü vuruş.

signal move_started
signal move_stopped
signal interact_attempted
signal tool_switched(tool_name: String)
signal carried_changed(holding: bool)
signal item_disposed(prop_id: String)
signal mop_dirt_changed(ratio: float)
signal rinsed
signal dance_changed(dancing: bool)
signal fx_burst(kind: StringName, world_pos: Vector3, strength: float)
signal forbidden_touched

@export var move_speed: float = 6.4
@export var carry_speed_mult: float = 0.72
@export var camera_rig_path: NodePath = ^"../../IsometricCameraRig"

@export_group("Etkileşim")
@export var swing_range: float = 1.9
@export var interact_cone_dot: float = 0.52
@export var mop_swing_strength: float = 1.0
@export var shovel_swing_strength: float = 1.45
@export var mop_swing_cooldown: float = 0.2
@export var shovel_swing_cooldown: float = 0.3
@export var scrub_mash_cooldown: float = 0.09
@export var drop_distance: float = 1.15
@export var throw_speed: float = 9.8

@export_group("Paspas kiri")
@export var mop_dirt_per_hit: float = 0.14
@export var rinse_per_second: float = 1.15

@export_group("Dash")
@export var dash_speed: float = 14.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.55

@export_group("Komik fizik / Dans")
@export var bump_bounce: float = 11.5
@export var bump_min_speed: float = 2.2
@export var dance_hop: float = 0.28
@export var dance_spin_speed: float = 9.5

const PROP_GROUP := &"ClutterProp"
const TRASH_GROUP := &"TrashDrop"
const BUCKET_GROUP := &"BucketStation"

enum ToolKind { MOP, SHOVEL }

@export var active_tool: ToolKind = ToolKind.MOP
## Seviye paspas kullanmıyorsa false (L1).
var allow_mop: bool = true

var _camera_rig: IsometricCameraRig
var _facing: Vector3 = Vector3(0.0, 0.0, -1.0)
var _was_moving: bool = false
var _swing_cooldown: float = 0.0
var _held: ClutterProp
var _hold_point: Node3D
var _dash_time: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO
var _mop_dirt: float = 0.0
var _rinsing: bool = false
var _sfx: AudioStreamPlayer
var _visual: Node3D
var _dancing: bool = false
var _dance_t: float = 0.0
var _bump_vel: Vector3 = Vector3.ZERO
var _bump_cd: float = 0.0
var _squash: Vector3 = Vector3.ONE
var _visual_spin: float = 0.0
var _hop_y: float = 0.0
var _fail_stun: float = 0.0


func _ready() -> void:
	add_to_group("Player")
	_visual = get_node_or_null("Mesh") as Node3D
	if _visual == null:
		_visual = self
	_hold_point = Node3D.new()
	_hold_point.name = "HoldPoint"
	_hold_point.position = Vector3(0.0, 0.95, -0.55)
	add_child(_hold_point)
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "Sfx"
	_sfx.bus = &"Master"
	_sfx.volume_db = -6.0
	add_child(_sfx)
	call_deferred("_bind_camera")


func _bind_camera() -> void:
	_camera_rig = get_node_or_null(camera_rig_path) as IsometricCameraRig


func _physics_process(delta: float) -> void:
	if _swing_cooldown > 0.0:
		_swing_cooldown = maxf(0.0, _swing_cooldown - delta)
	if _dash_cd > 0.0:
		_dash_cd = maxf(0.0, _dash_cd - delta)
	if _bump_cd > 0.0:
		_bump_cd = maxf(0.0, _bump_cd - delta)
	if _fail_stun > 0.0:
		_fail_stun = maxf(0.0, _fail_stun - delta)

	_update_bucket_rinse(delta)
	_update_comedy_visuals(delta)

	# Emir fail sendeleme
	if _fail_stun > 0.0:
		velocity.x = _bump_vel.x
		velocity.z = _bump_vel.z
		velocity.y = 0.0
		_bump_vel = _bump_vel.lerp(Vector3.ZERO, clampf(6.0 * delta, 0.0, 1.0))
		move_and_slide()
		_update_motion_signals()
		return

	# Abartılı bump geri sekmesi
	if _bump_vel.length_squared() > 0.05:
		velocity.x = _bump_vel.x
		velocity.z = _bump_vel.z
		velocity.y = 0.0
		_bump_vel = _bump_vel.lerp(Vector3.ZERO, clampf(8.0 * delta, 0.0, 1.0))
		move_and_slide()
		_process_bumps(false)
		_update_mop_scrub(delta)
		_update_motion_signals()
		return

	if _dash_time > 0.0:
		_dash_time = maxf(0.0, _dash_time - delta)
		var dash_spd := dash_speed * (0.82 if _held != null else 1.0)
		velocity.x = _dash_dir.x * dash_spd
		velocity.z = _dash_dir.z * dash_spd
		velocity.y = 0.0
		move_and_slide()
		_process_bumps(true)
		_update_mop_scrub(delta)
		_update_motion_signals()
		return

	_apply_overcooked_movement()
	_update_mop_scrub(delta)
	_update_motion_signals()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dance"):
		_toggle_dance()
		return
	if event.is_action_pressed("dash"):
		_try_dash()
		return
	if event.is_action_pressed("throw"):
		_try_throw()
		return
	if event.is_action_pressed("interact"):
		_try_interact()
		return
	if event.is_action_released("interact"):
		_rinsing = false
		return
	if event.is_action_pressed("tool_mop"):
		if allow_mop:
			_set_tool(ToolKind.MOP)
		return
	if event.is_action_pressed("tool_shovel"):
		_set_tool(ToolKind.SHOVEL)


func _toggle_dance() -> void:
	_dancing = not _dancing
	_dance_t = 0.0
	dance_changed.emit(_dancing)
	_play_sfx(PrototypeSfx.Kind.DANCE, 1.15 if _dancing else 0.85)
	if _dancing:
		_squash = Vector3(1.35, 0.65, 1.35)
		fx_burst.emit(&"dance", global_position, 1.0)


func _try_dash() -> void:
	if _fail_stun > 0.0:
		return
	if _dash_cd > 0.0 or _dash_time > 0.0:
		return
	if _dancing:
		_dancing = false
		dance_changed.emit(false)
	var dir := _facing
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = -global_transform.basis.z
		dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	_dash_dir = dir.normalized()
	_dash_time = dash_duration * (0.88 if _held != null else 1.0)
	_dash_cd = dash_cooldown
	_snap_face(_dash_dir)
	_squash = Vector3(0.55, 1.45, 0.55)
	_play_sfx(PrototypeSfx.Kind.DASH)
	fx_burst.emit(&"dash", global_position, 1.0)


func _apply_overcooked_movement() -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var axes: Dictionary = _get_movement_axes()
	var right: Vector3 = axes["right"] as Vector3
	var forward: Vector3 = axes["forward"] as Vector3
	var wish: Vector3 = right * input.x + forward * (-input.y)
	wish.y = 0.0
	var speed := move_speed * (carry_speed_mult if _held != null else 1.0)
	if _held != null:
		var units := _held.get_stack_units()
		if units > 1:
			speed *= clampf(1.0 / (1.0 + 0.14 * float(units - 1)), 0.55, 1.0)
	if _dancing:
		speed *= 0.55

	if wish.length_squared() > 0.001:
		wish = wish.normalized()
		_facing = wish
		velocity.x = wish.x * speed
		velocity.z = wish.z * speed
		if not _dancing:
			_snap_face(wish)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	velocity.y = 0.0
	move_and_slide()
	_process_bumps(false)


func _process_bumps(from_dash: bool) -> void:
	if _bump_cd > 0.0:
		return
	var count := get_slide_collision_count()
	if count <= 0:
		return
	var impact := Vector3.ZERO
	var hit_prop: ClutterProp = null
	for i in count:
		var col: KinematicCollision3D = get_slide_collision(i)
		var n: Vector3 = col.get_normal()
		n.y = 0.0
		if n.length_squared() < 0.001:
			continue
		impact += n.normalized()
		var collider_obj: Object = col.get_collider() as Object
		if collider_obj is Node:
			var prop: ClutterProp = _find_prop_from(collider_obj as Node)
			if prop != null:
				hit_prop = prop
	if impact.length_squared() < 0.001:
		return

	var speed_now := velocity.length()
	if speed_now < bump_min_speed and not from_dash and not _dancing:
		return

	impact = impact.normalized()
	var power := bump_bounce
	if from_dash:
		power *= 1.55
	if _dancing:
		power *= 1.85

	_bump_vel = impact * power
	_bump_cd = 0.22 if not _dancing else 0.14
	_facing = impact
	# Abartılı squash: duvara yapışıp jöle gibi
	_squash = Vector3(1.0 + absf(impact.x) * 1.1, 0.45, 1.0 + absf(impact.z) * 1.1)
	_visual_spin += randf_range(2.8, 5.5) * (1.0 if randf() > 0.5 else -1.0)
	_hop_y = 0.35 if _dancing else 0.18
	_play_sfx(PrototypeSfx.Kind.BUMP, 0.85 + power * 0.04)
	fx_burst.emit(&"bump", global_position, power * 0.12)

	if hit_prop != null and not hit_prop.is_being_carried():
		var strength := 1.0 if from_dash else 0.75
		if _dancing:
			strength *= 1.4
		hit_prop.apply_impact(-impact, strength)


func _find_prop_from(node: Node) -> ClutterProp:
	var n: Node = node
	while n != null:
		if n is ClutterProp:
			return n as ClutterProp
		n = n.get_parent()
	return null


func _update_comedy_visuals(delta: float) -> void:
	if _visual == null:
		return
	var target_squash := Vector3.ONE
	var target_spin := 0.0
	var target_hop := 0.0

	if _dancing:
		_dance_t += delta
		var bob := sin(_dance_t * 14.0)
		var sway := sin(_dance_t * 9.0)
		target_squash = Vector3(
			1.15 + bob * 0.28,
			0.78 - bob * 0.22,
			1.15 + bob * 0.28
		)
		target_spin = sway * 0.55
		target_hop = absf(sin(_dance_t * 7.0)) * dance_hop
		# Dans ederken kendi etrafında dön
		rotation.y += dance_spin_speed * delta * (1.2 + 0.4 * sin(_dance_t * 3.0))

	_squash = _squash.lerp(target_squash, clampf(10.0 * delta, 0.0, 1.0))
	_visual_spin = lerpf(_visual_spin, target_spin, clampf(8.0 * delta, 0.0, 1.0))
	_hop_y = lerpf(_hop_y, target_hop, clampf(12.0 * delta, 0.0, 1.0))

	_visual.scale = _squash
	_visual.rotation.z = _visual_spin * 0.35
	_visual.rotation.x = -_visual_spin * 0.15
	_visual.position.y = _hop_y
	if _hold_point != null:
		_hold_point.position = Vector3(0.0, 0.95 + _hop_y * 0.6, -0.55)
		_hold_point.rotation.z = _visual_spin * 0.5


func _get_movement_axes() -> Dictionary:
	if _camera_rig != null:
		var axes: Dictionary = _camera_rig.get_movement_axes()
		return axes
	return {
		"forward": Vector3(0.0, 0.0, -1.0),
		"right": Vector3(1.0, 0.0, 0.0),
	}


func _snap_face(dir: Vector3) -> void:
	if dir.length_squared() < 0.0001:
		return
	rotation.y = atan2(dir.x, dir.z)


func _set_tool(tool: ToolKind) -> void:
	if tool == ToolKind.MOP and not allow_mop:
		return
	if active_tool == tool:
		return
	active_tool = tool
	tool_switched.emit("mop" if tool == ToolKind.MOP else "shovel")
	_play_sfx(PrototypeSfx.Kind.SWITCH)


func configure_for_level(mop_allowed: bool) -> void:
	allow_mop = mop_allowed
	_fail_stun = 0.0
	if not allow_mop:
		_mop_dirt = 0.0
		mop_dirt_changed.emit(0.0)
		_set_tool(ToolKind.SHOVEL)
	elif active_tool == ToolKind.SHOVEL:
		pass
	else:
		_set_tool(ToolKind.MOP)


## Emir kaçırınca abartılı negatif juice.
func play_task_fail_recoil() -> void:
	_fail_stun = 0.55
	_swing_cooldown = maxf(_swing_cooldown, 0.45)
	_rinsing = false
	if _dancing:
		_dancing = false
		dance_changed.emit(false)
	var away := -_facing
	away.y = 0.0
	if away.length_squared() < 0.001:
		away = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	away = away.normalized()
	_bump_vel = away * 7.5
	_squash = Vector3(1.55, 0.4, 1.55)
	_visual_spin += randf_range(4.0, 7.0) * (1.0 if randf() > 0.5 else -1.0)
	_hop_y = 0.4
	_play_sfx(PrototypeSfx.Kind.BUMP, 0.7)
	fx_burst.emit(&"bump", global_position + Vector3(0, 0.6, 0), 1.6)


func _try_interact() -> void:
	if _fail_stun > 0.0:
		return
	if _swing_cooldown > 0.0:
		return
	interact_attempted.emit()

	# Kovada durulama (paspas + kirli + boş el)
	if _held == null and active_tool == ToolKind.MOP and _mop_dirt > 0.01:
		var bucket := _find_station(BUCKET_GROUP)
		if bucket != null:
			_rinsing = true
			_swing_cooldown = 0.05
			_play_sfx(PrototypeSfx.Kind.RINSE, 0.9)
			return

	if _held != null:
		if _try_dispose_held():
			return
		# Eldeki kutuyu yerdeki kutunun üstüne koy
		var stack_target := _find_interact_target()
		if stack_target != null and _try_stack_onto(stack_target):
			return
		_try_throw()
		return

	# Önce leke: sol tık / Space mash ovalama
	if _held == null and allow_mop:
		var scrub := _find_scrub_target()
		if scrub != null:
			_mash_scrub(scrub)
			return

	var prop := _find_interact_target()
	if prop == null:
		return

	if prop.can_carry and prop.is_carryable():
		_pick_up(prop)
		return

	if prop.is_scrub_target():
		if allow_mop:
			_mash_scrub(prop)
		return

	var hit_dir := prop.global_position - global_position
	var strength := mop_swing_strength if active_tool == ToolKind.MOP else shovel_swing_strength
	# Kirli paspas daha zayıf vurur
	if active_tool == ToolKind.MOP:
		strength *= lerpf(1.0, 0.45, _mop_dirt)
	var tool_name := "mop" if active_tool == ToolKind.MOP else "shovel"
	prop.apply_hit(prop.global_position, hit_dir, strength, tool_name)
	_swing_cooldown = mop_swing_cooldown if active_tool == ToolKind.MOP else shovel_swing_cooldown
	_snap_face(hit_dir)
	_play_sfx(PrototypeSfx.Kind.HIT, 1.0 + strength * 0.08)
	fx_burst.emit(&"hit", prop.global_position + Vector3(0, 0.7, 0), strength)
	if active_tool == ToolKind.MOP:
		_add_mop_dirt(mop_dirt_per_hit)


func _mash_scrub(prop: ClutterProp) -> void:
	if prop == null or not prop.is_scrub_target():
		return
	if active_tool != ToolKind.MOP:
		_set_tool(ToolKind.MOP)
	var effectiveness := lerpf(1.0, 0.45, _mop_dirt)
	var cleaned := prop.apply_scrub_tap(effectiveness)
	_swing_cooldown = scrub_mash_cooldown
	_snap_face(prop.global_position - global_position)
	_add_mop_dirt(mop_dirt_per_hit * 0.12)
	_play_sfx(PrototypeSfx.Kind.HIT, 0.85 + prop.get_scrub_progress() * 0.4)
	fx_burst.emit(&"hit", prop.global_position + Vector3(0, 0.25, 0), 0.65 + prop.get_scrub_progress() * 0.55)
	# Kısa squash — mash hissi
	_squash = Vector3(1.18, 0.82, 1.18)
	if cleaned:
		_play_sfx(PrototypeSfx.Kind.DISPOSE, 1.1)
		fx_burst.emit(&"dispose", prop.global_position + Vector3(0, 0.4, 0), 1.15)
		item_disposed.emit(prop.prop_id)


func _try_throw() -> void:
	if _fail_stun > 0.0:
		return
	if _held == null or _swing_cooldown > 0.0:
		return
	var prop := _held
	_held = null
	carried_changed.emit(false)
	var origin := global_position + Vector3(0.0, 1.05, 0.0) + _facing * 0.55
	prop.launch_throw(prop.get_home_parent(), origin, _facing, throw_speed)
	_swing_cooldown = 0.18
	_play_sfx(PrototypeSfx.Kind.THROW)
	fx_burst.emit(&"throw", origin, 1.0)


func _try_stack_onto(target: ClutterProp) -> bool:
	if _held == null or target == null:
		return false
	# Yasak koli: stack yok, dokunma cezası
	if bool(target.get_meta("forbidden", false)) or bool(_held.get_meta("forbidden", false)):
		forbidden_touched.emit()
		_swing_cooldown = 0.2
		_play_sfx(PrototypeSfx.Kind.TASK_FAIL, 0.85)
		return true
	if not _held.is_box_stackable(true) or not target.is_box_stackable():
		return false
	if target.get_stack_units() + _held.get_stack_units() > ClutterProp.MAX_BOX_STACK:
		return false
	var held := _held
	_held = null
	carried_changed.emit(false)
	if not target.accept_stack_from(held):
		_held = held
		carried_changed.emit(true)
		return false
	_swing_cooldown = 0.14
	_play_sfx(PrototypeSfx.Kind.PICKUP, 1.15)
	fx_burst.emit(&"dispose", target.global_position + Vector3(0, target.get_stack_top_y(), 0), 0.7)
	# Yığını otomatik al — çöpe taşımak kolay olsun
	_pick_up(target)
	return true


func _pick_up(prop: ClutterProp) -> void:
	if prop == null or _held != null:
		return
	if bool(prop.get_meta("forbidden", false)):
		forbidden_touched.emit()
		_swing_cooldown = 0.2
		_play_sfx(PrototypeSfx.Kind.TASK_FAIL, 0.85)
		return
	if not prop.begin_carry(_hold_point):
		return
	_held = prop
	_swing_cooldown = 0.12
	carried_changed.emit(true)
	_play_sfx(PrototypeSfx.Kind.PICKUP)


func _drop_held() -> void:
	if _held == null:
		return
	var drop_pos := global_position + _facing.normalized() * drop_distance
	drop_pos.y = 0.0
	var prop := _held
	_held = null
	prop.end_carry(drop_pos, rotation.y)
	_swing_cooldown = 0.12
	carried_changed.emit(false)
	_play_sfx(PrototypeSfx.Kind.DROP)


func _try_dispose_held() -> bool:
	if _held == null:
		return false
	if bool(_held.get_meta("forbidden", false)):
		forbidden_touched.emit()
		_swing_cooldown = 0.2
		_play_sfx(PrototypeSfx.Kind.TASK_FAIL, 0.85)
		return true
	var deliver: String = String(_held.get_meta("deliver_to", ""))
	var zone: Node3D = null
	if deliver == "drain":
		zone = _find_station(&"DrainDrop")
	elif deliver == "trash":
		zone = _find_station(TRASH_GROUP)
	else:
		zone = _find_station(TRASH_GROUP)
		if zone == null:
			zone = _find_station(&"DrainDrop")
	if zone == null:
		return false
	var prop_id := _held.prop_id
	_held.dispose_at_trash()
	_held = null
	_swing_cooldown = 0.15
	carried_changed.emit(false)
	item_disposed.emit(prop_id)
	_play_sfx(PrototypeSfx.Kind.DISPOSE)
	fx_burst.emit(&"dispose", zone.global_position + Vector3(0, 0.8, 0), 1.0)
	return true


func _update_bucket_rinse(delta: float) -> void:
	if not _rinsing:
		return
	if not Input.is_action_pressed("interact") or _held != null or active_tool != ToolKind.MOP:
		_rinsing = false
		return
	var bucket := _find_station(BUCKET_GROUP)
	if bucket == null:
		_rinsing = false
		return
	if _mop_dirt <= 0.0:
		_rinsing = false
		return
	var before := _mop_dirt
	_mop_dirt = maxf(0.0, _mop_dirt - rinse_per_second * delta)
	if _mop_dirt != before:
		mop_dirt_changed.emit(_mop_dirt)
	if _mop_dirt <= 0.0:
		_rinsing = false
		rinsed.emit()
		_play_sfx(PrototypeSfx.Kind.RINSE)
		fx_burst.emit(&"rinse", global_position + Vector3(0, 0.5, 0), 1.0)


## Paspasla sıvı ovalama: mash (tık) ana yol; basılı tut + hareket bonus.
func _update_mop_scrub(delta: float) -> void:
	if _held != null or not allow_mop or active_tool != ToolKind.MOP:
		return
	if _rinsing:
		return
	if not Input.is_action_pressed("interact"):
		return
	var prop := _find_scrub_target()
	if prop == null:
		return
	var motion := Vector2(velocity.x, velocity.z).length() * delta
	if _dash_time > 0.0:
		motion = maxf(motion, dash_speed * delta * 0.85)
	if motion < 0.008:
		return
	var effectiveness := lerpf(1.0, 0.4, _mop_dirt)
	var cleaned := prop.apply_scrub(motion * 1.35, effectiveness)
	_add_mop_dirt(mop_dirt_per_hit * 0.18 * clampf(motion * 4.0, 0.35, 1.2))
	if Engine.get_physics_frames() % 8 == 0:
		_play_sfx(PrototypeSfx.Kind.HIT, 0.75 + prop.get_scrub_progress() * 0.35)
		fx_burst.emit(&"hit", prop.global_position + Vector3(0, 0.25, 0), 0.55 + prop.get_scrub_progress() * 0.5)
	if cleaned:
		_play_sfx(PrototypeSfx.Kind.DISPOSE, 1.1)
		fx_burst.emit(&"dispose", prop.global_position + Vector3(0, 0.4, 0), 1.15)
		item_disposed.emit(prop.prop_id)


func _find_scrub_target() -> ClutterProp:
	var best: ClutterProp = null
	var best_dist := 999.0
	for node in get_tree().get_nodes_in_group(PROP_GROUP):
		var prop := node as ClutterProp
		if prop == null or not prop.is_scrub_target():
			continue
		var flat := prop.global_position - global_position
		flat.y = 0.0
		var dist := flat.length()
		# Biraz cömert menzil — mash için rahat
		if dist > prop.scrub_radius + 0.55:
			continue
		if dist < best_dist:
			best_dist = dist
			best = prop
	return best


func _add_mop_dirt(amount: float) -> void:
	var before := _mop_dirt
	_mop_dirt = clampf(_mop_dirt + amount, 0.0, 1.0)
	if _mop_dirt != before:
		mop_dirt_changed.emit(_mop_dirt)


func _find_station(group_name: StringName) -> Node3D:
	var facing := _facing
	facing.y = 0.0
	if facing.length_squared() < 0.0001:
		facing = Vector3(0, 0, -1)
	facing = facing.normalized()
	var best: Node3D = null
	var best_score := -999.0
	for node in get_tree().get_nodes_in_group(group_name):
		var zone := node as Node3D
		if zone == null:
			continue
		var to_z := zone.global_position - global_position
		to_z.y = 0.0
		var dist := to_z.length()
		var max_dist := float(zone.get_meta("interact_radius", swing_range * 1.2))
		if dist > max_dist or dist < 0.05:
			continue
		var dot := facing.dot(to_z / dist)
		if dot < interact_cone_dot * 0.8:
			continue
		var score := (1.0 - dist / max_dist) * 2.0 + dot
		if score > best_score:
			best_score = score
			best = zone
	return best


func _find_interact_target() -> ClutterProp:
	var facing := _facing
	facing.y = 0.0
	if facing.length_squared() < 0.0001:
		facing = -global_transform.basis.z
		facing.y = 0.0
	facing = facing.normalized()

	var best: ClutterProp = null
	var best_score := -999.0
	for node in get_tree().get_nodes_in_group(PROP_GROUP):
		var prop := node as ClutterProp
		if prop == null or prop.is_being_carried():
			continue
		var to_prop := prop.global_position - global_position
		to_prop.y = 0.0
		var dist := to_prop.length()
		if dist > swing_range or dist < 0.05:
			continue
		var dir := to_prop / dist
		var dot := facing.dot(dir)
		if dot < interact_cone_dot:
			continue
		var score := (1.0 - dist / swing_range) * 2.0 + dot
		if score > best_score:
			best_score = score
			best = prop
	return best


func get_facing_direction() -> Vector3:
	return _facing


func is_holding() -> bool:
	return _held != null


func get_mop_dirt() -> float:
	return _mop_dirt


func _play_sfx(kind: PrototypeSfx.Kind, pitch: float = 1.0) -> void:
	PrototypeSfx.play(_sfx, kind, pitch)


func _update_motion_signals() -> void:
	var moving := velocity.length_squared() > 0.04
	if moving and not _was_moving:
		move_started.emit()
	elif not moving and _was_moving:
		move_stopped.emit()
	_was_moving = moving
