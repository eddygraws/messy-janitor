class_name PlayerCharacter3D
extends CharacterBody3D

## Overcooked tarzı: hareket, dash, tut/fırlat, kova durulama, yönlü vuruş.

signal move_started
signal move_stopped
signal interact_attempted
signal tool_switched(tool_name: String)
signal tools_unlocked_changed(count: int)
signal carried_changed(holding: bool)
signal item_disposed(prop_id: String)
signal floor_scrubbed(world_pos: Vector3)
signal mop_dirt_changed(ratio: float)
signal vacuum_bag_changed(count: int, capacity: int)
signal rinsed
signal dance_changed(dancing: bool)
signal fx_burst(kind: StringName, world_pos: Vector3, strength: float)
signal forbidden_touched
signal status_message(text: String)
signal junk_eaten(world_pos: Vector3)
signal junk_powerup(kind: StringName) ## &"speed_rush" | &"scene_sweep"
signal wrong_tool_used(needed: String)
signal secret_probe(secret_id: String, world_pos: Vector3)
signal bag_emptied(dumped: int, was_full: bool, world_pos: Vector3)
signal scrap_hold_finished
signal scrap_hold_ui_ready ## Elde tutuyor + dönüyor — UI geçişine hazır

@export var move_speed: float = 6.4
@export var carry_speed_mult: float = 0.68 ## Tek kutu — bilinçli yavaşlatma
@export var stack_speed_falloff: float = 0.70 ## Her ekstra kutu çarpanı (2→×0.70, 3→×0.49…)
@export var stack_speed_floor: float = 0.22 ## Stack ile minimum hız çarpanı (move_speed’e göre)
@export var camera_rig_path: NodePath = ^"../../IsometricCameraRig"

@export_group("Etkileşim")
@export var swing_range: float = 2.45 ## Menzil — yan/arka yaklaşmada da rahat
@export var interact_cone_dot: float = 0.22 ## Uzak kenarda minimum bakış (≈77°)
@export var close_magnet_range: float = 1.35 ## Bu mesafede bakış şart değil (360°)
@export var soft_cone_range: float = 1.95 ## Bu mesafeye kadar yanlar da kabul
@export var mop_swing_strength: float = 1.0
@export var brush_swing_strength: float = 1.45
@export var mop_swing_cooldown: float = 0.2
@export var brush_swing_cooldown: float = 0.3
@export var scrub_mash_cooldown: float = 0.09
@export var drop_distance: float = 1.15
@export var throw_speed: float = 9.8
@export var bloat_decay_per_sec: float = 0.045
@export var bloat_per_junk: float = 0.42
@export var bloat_max_scale: float = 2.05
@export var junk_powerup_every: int = 3
@export var speed_rush_duration: float = 9.5
@export var speed_rush_move_mult: float = 1.48
@export var speed_rush_carry_mult: float = 1.6

@export_group("Paspas kiri")
@export var mop_dirt_per_hit: float = 0.14
@export var rinse_per_second: float = 1.15

@export_group("Süpürge emme")
@export var vacuum_range: float = 4.4
@export var vacuum_sector_half_deg: float = 42.0 ## Sektör yarı-açısı (~84° toplam)
@export var vacuum_cone_dot: float = 0.72 ## cos(~44°) — uzak hedef filtre
@export var vacuum_close_magnet: float = 1.75 ## Bu mesafede 360° emme (ayak altı dahil)
@export var vacuum_pull_speed: float = 7.0
@export var vacuum_bag_capacity: int = 3
@export var vacuum_move_mult: float = 0.72 ## Hedef çekerken yavaşlama
@export var vacuum_idle_move_mult: float = 0.92 ## Süpürge açık, hedef yokken hafif yavaşlama
@export var vacuum_max_targets: int = 8

@export_group("Dash")
@export var dash_speed: float = 14.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.55
@export var max_dash_charges: int = 1

@export_group("Komik fizik / Dans")
@export var bump_bounce: float = 11.5
@export var bump_min_speed: float = 2.2
@export var dance_hop: float = 0.28
@export var dance_spin_speed: float = 9.5
@export var slip_accel: float = 0.045 ## Kaygan zeminde yön kontrolü (düşük = daha kaygan)
@export var slip_friction: float = 0.008 ## Kayganken fren
@export var slip_speed_boost: float = 1.18 ## Buzda kayma hızı (kontrol zor)

@export_group("İksir sarhoşluğu")
@export var potion_drunk_build: float = 1.8 ## sn'de dolma
@export var potion_drunk_decay: float = 0.55 ## sn'de iniş
@export var potion_drunk_speed_mult: float = 0.72
@export var potion_drunk_drift: float = 0.55 ## yön sapması
@export var potion_silence_threshold: float = 0.85
@export var potion_silence_duration: float = 1.6
@export var potion_silence_cooldown: float = 3.0

@export_group("Karakter modeli")
@export var use_janitor_model: bool = true
@export var janitor_yaw_offset: float = 0.0 ## ters yürüyorsa PI dene
## 1.0 = sahne boyu · 0.7 küçült · 1.3 büyüt (kolay slider)
@export_range(0.25, 1.75, 0.01) var janitor_size_mult: float = 1.0
## 0=otomatik. Elle: ham FBX scale (bu modelde genelde 12–18)
@export var janitor_manual_scale: float = 0.0
@export var move_anim_speed_threshold: float = 0.45

const JanitorVisualScript := preload("res://scenes3d/player/janitor_visual.gd")
const PROP_GROUP := &"ClutterProp"
const TRASH_GROUP := &"TrashDrop"
const BUCKET_GROUP := &"BucketStation"
## Bakış yönüne göre sol-ön; kutuyu karakterin solunda taşır
const HOLD_RIGHT := -0.30
const HOLD_FORWARD := 0.52
const HOLD_Y := 0.42 ## Göğüs / el hizası — kutular alçak kalmasın

enum ToolKind { MOP, BROOM, BRUSH, SPRAY, TWEEZERS }

const TOOL_NAMES: Array[String] = ["mop", "broom", "brush", "spray", "tweezers"]
const TOOL_LABELS: Array[String] = ["Paspas", "Süpürge", "Fırça", "Sprey", "Cımbız"]
const TOOL_ICONS: Array[String] = ["🧹", "🧺", "🪥", "🧴", "🔬"]

@export var active_tool: ToolKind = ToolKind.MOP
## Seviye paspas kullanmıyorsa false (L1).
var allow_mop: bool = true
var unlocked_tool_count: int = 1

var _camera_rig: IsometricCameraRig
var _facing: Vector3 = Vector3(0.0, 0.0, -1.0)
var _was_moving: bool = false
var _swing_cooldown: float = 0.0
var _held: ClutterProp
var _hold_point: Node3D
var _dash_time: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO
var _dash_charges: int = 1
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
var _floor_slip: float = 0.0
var _potion_drunk: float = 0.0
var _drunk_t: float = 0.0
var _potion_silence: float = 0.0
var _potion_silence_cd: float = 0.0
var _face_root: Node3D
var _janitor: Node # JanitorVisual
## Karanlık seviye: bakış sektörü maskesi (zemin dilimi) — gameplay menzili aynı parametrelerden
var _flash_mask: Node3D
var _flash_sector: MeshInstance3D
var _flash_enabled: bool = false
var _flash_range: float = 7.0
var _flash_half_angle_deg: float = 34.0
# Lanet / baseline
var _base_carry_speed_mult: float = -1.0
var _base_stack_falloff: float = -1.0
var _base_scrub_mash_cooldown: float = -1.0
var _bloat: float = 0.0
var _junk_toward_powerup: int = 0
var _speed_rush_t: float = 0.0
var _vacuum_target: ClutterProp
var _vacuum_targets: Array[ClutterProp] = []
var _vacuum_rig: Node3D
var _vacuum_nozzle: Node3D
var _vacuum_beam: MeshInstance3D
var _vacuum_beam_mat: StandardMaterial3D
var _vacuum_tank_mesh: MeshInstance3D
var _vacuum_sector: MeshInstance3D
var _vacuum_sector_mat: StandardMaterial3D
var _vacuum_sector_rim: MeshInstance3D
var _vacuum_active: bool = false
var _vacuum_hum_cd: float = 0.0
var _vacuum_bag: int = 0
var _vacuum_pulse_t: float = 0.0
var _scrap_hold_root: Node3D
var _scrap_holding: bool = false
var _scrap_spin_y: float = 0.0
var _scrap_spinning: bool = false
var _control_locked: bool = false


func set_control_locked(on: bool) -> void:
	_control_locked = on
	if on:
		velocity = Vector3.ZERO
		_bump_vel = Vector3.ZERO
		_dash_time = 0.0


func is_control_locked() -> bool:
	return _control_locked


func set_floor_slip(amount: float) -> void:
	_floor_slip = clampf(amount, 0.0, 1.0)


func get_potion_drunk() -> float:
	return _potion_drunk


func apply_curse_mods(carry_mult: float, stack_falloff_mult: float, scrub_cd_mult: float) -> void:
	if _base_carry_speed_mult < 0.0:
		_base_carry_speed_mult = carry_speed_mult
		_base_stack_falloff = stack_speed_falloff
		_base_scrub_mash_cooldown = scrub_mash_cooldown
	carry_speed_mult = _base_carry_speed_mult * carry_mult
	stack_speed_falloff = clampf(_base_stack_falloff * stack_falloff_mult, 0.45, 0.95)
	scrub_mash_cooldown = _base_scrub_mash_cooldown * scrub_cd_mult


func clear_curse_mods() -> void:
	if _base_carry_speed_mult >= 0.0:
		carry_speed_mult = _base_carry_speed_mult
		stack_speed_falloff = _base_stack_falloff
		scrub_mash_cooldown = _base_scrub_mash_cooldown
	_base_carry_speed_mult = -1.0
	_base_stack_falloff = -1.0
	_base_scrub_mash_cooldown = -1.0


## Raf/dolap çarpması — HazardDirector çağırır
func apply_hazard_shove(dir: Vector3, power: float = 13.5) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	_bump_vel = dir * power
	_bump_cd = 0.16
	_facing = dir
	_squash = Vector3(1.0 + absf(dir.x) * 1.2, 0.4, 1.0 + absf(dir.z) * 1.2)
	_visual_spin += randf_range(2.5, 5.0) * (1.0 if randf() > 0.5 else -1.0)
	_hop_y = 0.22
	_play_sfx(PrototypeSfx.Kind.BUMP, 1.05)
	fx_burst.emit(&"bump", global_position, power * 0.1)


func _ready() -> void:
	add_to_group("Player")
	_setup_visuals()
	_setup_flashlight()
	_dash_charges = max_dash_charges
	_hold_point = get_node_or_null("HoldPoint") as Node3D
	if _hold_point == null:
		_hold_point = Node3D.new()
		_hold_point.name = "HoldPoint"
		add_child(_hold_point)
	_place_hold_point()
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "Sfx"
	_sfx.bus = &"Master"
	_sfx.volume_db = -6.0
	add_child(_sfx)
	call_deferred("_bind_camera")


func _setup_flashlight() -> void:
	# Eski SpotLight varsa kapat
	var old := get_node_or_null("Flashlight") as Light3D
	if old != null:
		old.visible = false
		old.light_energy = 0.0
	_flash_mask = get_node_or_null("FlashMask") as Node3D
	if _flash_mask == null:
		_flash_mask = Node3D.new()
		_flash_mask.name = "FlashMask"
		add_child(_flash_mask)
	# Eski çocukları temizle — yeniden kur
	while _flash_mask.get_child_count() > 0:
		var c := _flash_mask.get_child(0)
		_flash_mask.remove_child(c)
		c.free()

	# Tek görsel: zemin sektörü (geniş ağzı oyuncuya bakan 3D koni yok)
	_flash_sector = MeshInstance3D.new()
	_flash_sector.name = "FloorSector"
	_flash_sector.mesh = _build_flashlight_sector_mesh(_flash_range, _flash_half_angle_deg, 28)
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fmat.albedo_color = Color(0.35, 0.78, 1.0, 0.22)
	fmat.emission_enabled = true
	fmat.emission = Color(0.4, 0.85, 1.0)
	fmat.emission_energy_multiplier = 1.8
	fmat.no_depth_test = true
	_flash_sector.material_override = fmat
	_flash_sector.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_sector.position = Vector3(0.0, -0.82, 0.0) # göğüs origin → yere yakın
	_flash_mask.add_child(_flash_sector)

	_flash_mask.visible = false
	_flash_enabled = false


func _build_flashlight_sector_mesh(radius: float, half_deg: float, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ha := deg_to_rad(half_deg)
	var y := 0.05
	for i in segs:
		var a0 := -ha + (2.0 * ha) * float(i) / float(segs)
		var a1 := -ha + (2.0 * ha) * float(i + 1) / float(segs)
		# İleri = -Z (looking_at uyumu)
		var p0 := Vector3(0.0, y, 0.0)
		var p1 := Vector3(sin(a0) * radius, y, -cos(a0) * radius)
		var p2 := Vector3(sin(a1) * radius, y, -cos(a1) * radius)
		st.set_normal(Vector3.UP)
		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(p2)
	st.generate_normals()
	return st.commit()


func set_flashlight_enabled(on: bool) -> void:
	if _flash_mask == null:
		_setup_flashlight()
	_flash_enabled = on
	_flash_mask.visible = on
	if on:
		_update_flashlight_aim()


func is_flashlight_on() -> bool:
	return _flash_enabled


func get_flashlight_range() -> float:
	return _flash_range


func get_flashlight_half_angle_deg() -> float:
	return _flash_half_angle_deg


func set_max_dash_charges(charges: int) -> void:
	max_dash_charges = clampi(charges, 1, 2)
	_dash_charges = max_dash_charges
	_dash_cd = 0.0


func is_potion_silenced() -> bool:
	return _potion_silence > 0.0


func _setup_visuals() -> void:
	var capsule := get_node_or_null("Mesh") as Node3D
	_visual = get_node_or_null("VisualRoot") as Node3D
	if _visual == null:
		_visual = Node3D.new()
		_visual.name = "VisualRoot"
		add_child(_visual)
	# Player y≈0.9 iken ayaklar yere (~0) otursun
	_visual.position = Vector3(0.0, -0.9, 0.0)

	if use_janitor_model:
		_janitor = JanitorVisualScript.new()
		_janitor.name = "JanitorVisual"
		_janitor.yaw_offset = janitor_yaw_offset
		_janitor.size_mult = janitor_size_mult
		_janitor.manual_scale = janitor_manual_scale
		_visual.add_child(_janitor)
		if _janitor.setup():
			if capsule != null:
				capsule.visible = false
			return
		_janitor.queue_free()
		_janitor = null

	# Fallback: eski kapsül + yüz ipucu
	if capsule != null:
		capsule.reparent(_visual)
		capsule.position = Vector3(0.0, 0.9, 0.0)
		capsule.visible = true
		if capsule is MeshInstance3D:
			(capsule as MeshInstance3D).material_override = HitWobbleMaterial.create(
				Color(0.92, 0.72, 0.45), 0.75, Color(1.0, 0.85, 0.55), 0.08, 0.06, true, 0.035
			)
	_build_facing_face()


## Capsule belirsiz — burun + göz ile bakış yönü (lokal -Z = ön).
func _build_facing_face() -> void:
	_face_root = Node3D.new()
	_face_root.name = "FaceHint"
	if _visual != null and _visual != self:
		_visual.add_child(_face_root)
	else:
		add_child(_face_root)
	_face_root.position = Vector3(0.0, 0.35, 0.0)

	var nose := MeshInstance3D.new()
	nose.name = "Nose"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.12
	cone.height = 0.28
	nose.mesh = cone
	nose.material_override = HitWobbleMaterial.create(
		Color(0.95, 0.45, 0.35), 0.7, Color(1.0, 0.5, 0.35), 0.15, 0.04, true, 0.02
	)
	nose.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	nose.position = Vector3(0.0, 0.15, -0.38)
	_face_root.add_child(nose)

	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.07
		sphere.height = 0.14
		eye.mesh = sphere
		eye.material_override = HitWobbleMaterial.create(
			Color(0.12, 0.1, 0.14), 0.5, Color(0.9, 0.95, 1.0), 0.35, 0.02, true, 0.015
		)
		eye.position = Vector3(side * 0.12, 0.28, -0.28)
		_face_root.add_child(eye)

	var back := MeshInstance3D.new()
	var cap := SphereMesh.new()
	cap.radius = 0.22
	cap.height = 0.28
	back.mesh = cap
	back.material_override = HitWobbleMaterial.create(
		Color(0.25, 0.45, 0.85), 0.8, Color.BLACK, 0.0, 0.03, true, 0.02
	)
	back.position = Vector3(0.0, 0.55, 0.12)
	back.scale = Vector3(1.1, 0.55, 0.9)
	_face_root.add_child(back)


func _bind_camera() -> void:
	_camera_rig = get_node_or_null(camera_rig_path) as IsometricCameraRig


func _physics_process(delta: float) -> void:
	if _swing_cooldown > 0.0:
		_swing_cooldown = maxf(0.0, _swing_cooldown - delta)
	if _dash_cd > 0.0:
		_dash_cd = maxf(0.0, _dash_cd - delta)
		if _dash_cd <= 0.0:
			_dash_charges = max_dash_charges
	if _bump_cd > 0.0:
		_bump_cd = maxf(0.0, _bump_cd - delta)
	if _fail_stun > 0.0:
		_fail_stun = maxf(0.0, _fail_stun - delta)
	if _potion_silence > 0.0:
		_potion_silence = maxf(0.0, _potion_silence - delta)
		if _potion_silence <= 0.0 and _dancing:
			_dancing = false
			dance_changed.emit(false)
	if _potion_silence_cd > 0.0:
		_potion_silence_cd = maxf(0.0, _potion_silence_cd - delta)
	if _bloat > 0.0:
		_bloat = maxf(0.0, _bloat - bloat_decay_per_sec * delta)
	if _speed_rush_t > 0.0:
		_speed_rush_t = maxf(0.0, _speed_rush_t - delta)

	_update_bucket_rinse(delta)
	_update_potion_drunk(delta)
	_update_flashlight_aim()
	_update_comedy_visuals(delta)
	_update_janitor_anim()

	# Countdown / bölüm arası — hareket ve etkileşim yok
	if _control_locked:
		velocity = Vector3.ZERO
		_bump_vel = Vector3.ZERO
		_dash_time = 0.0
		move_and_slide()
		_update_motion_signals()
		return

	# Kayıp eşya tutuş — hareket yok; elde sürekli dönüş
	if _scrap_holding:
		if _scrap_spinning and _scrap_hold_root != null and is_instance_valid(_scrap_hold_root):
			_scrap_spin_y += delta * 4.2
			_scrap_hold_root.rotation.y = _scrap_spin_y
		velocity = Vector3.ZERO
		_bump_vel = Vector3.ZERO
		move_and_slide()
		_update_motion_signals()
		return

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
		_update_broom_vacuum(delta)
		_update_motion_signals()
		return

	if _dash_time > 0.0:
		_dash_time = maxf(0.0, _dash_time - delta)
		# Dash da stack ağırlığı hisseder (tam yürüme kadar değil)
		var dash_spd := dash_speed * sqrt(_carry_move_mult())
		velocity.x = _dash_dir.x * dash_spd
		velocity.z = _dash_dir.z * dash_spd
		velocity.y = 0.0
		move_and_slide()
		_process_bumps(true)
		_update_mop_scrub(delta)
		_update_broom_vacuum(delta)
		_update_motion_signals()
		return

	_apply_overcooked_movement()
	_update_mop_scrub(delta)
	_update_broom_vacuum(delta)
	_update_motion_signals()


func _unhandled_input(event: InputEvent) -> void:
	if _control_locked or _scrap_holding:
		return
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
		# Süpürge artık basılı tutma değil — bırakınca emme kesilmesin
		return
	if event.is_action_pressed("tool_mop") or event.is_action_pressed("tool_1"):
		_try_set_tool_index(0)
		return
	if event.is_action_pressed("tool_shovel") or event.is_action_pressed("tool_2"):
		_try_set_tool_index(1)
		return
	if event.is_action_pressed("tool_3"):
		_try_set_tool_index(2)
		return
	if event.is_action_pressed("tool_4"):
		_try_set_tool_index(3)
		return
	if event.is_action_pressed("tool_5"):
		_try_set_tool_index(4)
		return


func _toggle_dance() -> void:
	_dancing = not _dancing
	_dance_t = 0.0
	dance_changed.emit(_dancing)
	_play_sfx(PrototypeSfx.Kind.DANCE, 1.15 if _dancing else 0.85)
	if _dancing:
		_squash = Vector3(1.35, 0.65, 1.35)
		fx_burst.emit(&"dance", global_position, 1.0)


func _try_dash() -> void:
	if _fail_stun > 0.0 or _potion_silence > 0.0:
		return
	if _dash_time > 0.0:
		return
	if _dash_charges <= 0:
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
	_dash_charges -= 1
	if _dash_charges <= 0:
		_dash_cd = dash_cooldown
	_snap_face(_dash_dir)
	_squash = Vector3(0.55, 1.45, 0.55)
	# Kutu eldeyken dash animi yok — eller carry'de kalsın (eski hissiyat)
	if _held == null and _janitor != null and _janitor.has_method("play_dash"):
		_janitor.call("play_dash")
	elif _held != null and _janitor != null and _janitor.is_ready_visual():
		if _janitor.has_anim(&"carry_walk"):
			_janitor.play_loco(&"carry_walk", 1.35)
		else:
			_janitor.play_loco(&"carry", 1.0)
	_play_sfx(PrototypeSfx.Kind.DASH)
	fx_burst.emit(&"dash", global_position, 1.0)


func _carry_move_mult() -> float:
	if _held == null:
		return 1.0
	var units := maxi(1, _held.get_stack_units())
	# 1 kutu: carry_speed_mult; her ekstra kutu stack_speed_falloff ile çarpılır
	var stack_mult := pow(stack_speed_falloff, float(units - 1))
	var m := maxf(stack_speed_floor, carry_speed_mult * stack_mult)
	if _speed_rush_t > 0.0:
		m = minf(1.15, m * speed_rush_carry_mult)
	return m


func _apply_overcooked_movement() -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var axes: Dictionary = _get_movement_axes()
	var right: Vector3 = axes["right"] as Vector3
	var forward: Vector3 = axes["forward"] as Vector3
	# İksir: input sapması — dans/sarhoş kontrol
	if _potion_drunk > 0.12:
		var w := _potion_drunk
		_drunk_t += get_physics_process_delta_time()
		input.x += sin(_drunk_t * 7.5) * potion_drunk_drift * w
		input.y += cos(_drunk_t * 5.2) * potion_drunk_drift * w * 0.85
		input = input.limit_length(1.15)
	var wish: Vector3 = right * input.x + forward * (-input.y)
	wish.y = 0.0
	var speed := move_speed * _carry_move_mult()
	if _vacuum_active:
		if not _vacuum_targets.is_empty():
			speed *= vacuum_move_mult
		else:
			speed *= vacuum_idle_move_mult
	if _speed_rush_t > 0.0 and _held == null:
		speed *= speed_rush_move_mult
	elif _speed_rush_t > 0.0:
		speed *= lerpf(1.0, speed_rush_move_mult, 0.55)
	if _dancing:
		speed *= 0.55
	if _potion_drunk > 0.1:
		speed *= lerpf(1.0, potion_drunk_speed_mult, _potion_drunk)
	if _potion_silence > 0.0:
		speed *= 0.55
	if _floor_slip > 0.05:
		speed *= lerpf(1.0, slip_speed_boost, _floor_slip)

	if wish.length_squared() > 0.001:
		wish = wish.normalized()
		_facing = wish
		var wish_vel := wish * speed
		if _floor_slip > 0.05 or _potion_drunk > 0.2:
			var slip_amt := maxf(_floor_slip, _potion_drunk * 0.85)
			var blend := lerpf(1.0, slip_accel, slip_amt)
			velocity.x = lerpf(velocity.x, wish_vel.x, blend)
			velocity.z = lerpf(velocity.z, wish_vel.z, blend)
			var side := Vector3(-wish.z, 0.0, wish.x)
			var lateral := velocity.dot(side)
			velocity.x -= side.x * lateral * (0.04 * slip_amt)
			velocity.z -= side.z * lateral * (0.04 * slip_amt)
		else:
			velocity.x = wish_vel.x
			velocity.z = wish_vel.z
		if not _dancing:
			_snap_face(wish)
	else:
		if _floor_slip > 0.05 or _potion_drunk > 0.25:
			var slip_amt2 := maxf(_floor_slip, _potion_drunk * 0.7)
			var brake := lerpf(1.0, slip_friction, slip_amt2)
			velocity.x = lerpf(velocity.x, 0.0, brake)
			velocity.z = lerpf(velocity.z, 0.0, brake)
		else:
			velocity.x = 0.0
			velocity.z = 0.0

	velocity.y = 0.0
	move_and_slide()
	_process_bumps(false)


func _update_potion_drunk(delta: float) -> void:
	var on_potion := false
	for node in get_tree().get_nodes_in_group(PROP_GROUP):
		var prop := node as ClutterProp
		if prop == null or not bool(prop.get_meta("causes_drunk", false)):
			continue
		if prop.is_destroying() or not prop.is_scrub_target():
			continue
		var flat := prop.global_position - global_position
		flat.y = 0.0
		if flat.length() <= prop.scrub_radius + 0.25:
			on_potion = true
			break
	if on_potion:
		_potion_drunk = minf(1.0, _potion_drunk + potion_drunk_build * delta)
		if (
			_potion_drunk >= potion_silence_threshold
			and _potion_silence <= 0.0
			and _potion_silence_cd <= 0.0
		):
			_trigger_potion_silence()
	else:
		_potion_drunk = maxf(0.0, _potion_drunk - potion_drunk_decay * delta)


func _trigger_potion_silence() -> void:
	_potion_silence = potion_silence_duration
	_potion_silence_cd = potion_silence_cooldown
	_potion_drunk = minf(_potion_drunk, 0.55)
	_rinsing = false
	_swing_cooldown = maxf(_swing_cooldown, 0.35)
	_dancing = true
	_dance_t = 0.0
	dance_changed.emit(true)
	if _janitor != null and _janitor.has_method("has_anim") and bool(_janitor.call("has_anim", &"dance")):
		_janitor.call("play_loco", &"dance", 1.15)
	elif _janitor != null and _janitor.has_method("play_hit"):
		_janitor.call("play_hit", 1.8)
	_squash = Vector3(1.35, 0.65, 1.35)
	fx_burst.emit(&"dance", global_position, 1.2)
	_play_sfx(PrototypeSfx.Kind.DANCE, 1.2)
	status_message.emit("İKSİR! Kısa süre etkileşim yok")


func _update_flashlight_aim() -> void:
	if _flash_mask == null or not _flash_enabled:
		return
	var fwd := _aim_direction()
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		fwd = Vector3(0.0, 0.0, -1.0)
	fwd = fwd.normalized()
	# Göğüs hizası — koni öne doğru yayılır
	var origin := global_position + Vector3(0.0, 0.85, 0.0)
	_flash_mask.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), origin)


func _process_bumps(from_dash: bool) -> void:
	if _bump_cd > 0.0:
		return
	# Süpürge emerken tozlar nozula yapışır — hit animi / geri sekme yok
	if _vacuum_active:
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
				# Emilmekte / emilebilir toza çarpma = hit animi oynatma
				if prop.is_vacuumable() and prop.get_vacuum_progress() > 0.01:
					continue
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
		# Objeye çarpınca kısa hit (≈ yarı süre)
		if _janitor != null:
			_janitor.play_hit(2.4)
		_snap_face(-impact)


func _find_prop_from(node: Node) -> ClutterProp:
	var n: Node = node
	while n != null:
		if n is ClutterProp:
			return n as ClutterProp
		n = n.get_parent()
	return null


func _update_janitor_anim() -> void:
	if _janitor == null or not _janitor.is_ready_visual():
		return
	if _scrap_holding:
		if _janitor.has_method("force_loco"):
			_janitor.call("force_loco", &"carry", 1.0)
		elif _janitor.has_anim(&"carry"):
			_janitor.play_loco(&"carry", 1.0)
		return
	if _janitor.is_oneshot():
		return
	if _dancing:
		_janitor.play_loco(&"dance", 1.0)
		return
	# Boş elle dash: oneshot; kutu ile dash: carry devam
	if _dash_time > 0.0 and _held == null and not _janitor.has_anim(&"dash"):
		_janitor.play_loco(&"run", 1.85)
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if _held != null:
		if _dash_time > 0.0 or speed > move_anim_speed_threshold:
			_janitor.play_loco(&"carry_walk", 1.35 if _dash_time > 0.0 else clampf(speed / move_speed, 0.8, 1.25))
		else:
			_janitor.play_loco(&"carry", 1.0)
	elif speed > move_anim_speed_threshold:
		_janitor.play_loco(&"run", clampf(speed / move_speed, 0.85, 1.35))
	else:
		_janitor.play_loco(&"idle", 1.0)


func _update_comedy_visuals(delta: float) -> void:
	if _visual == null:
		return
	var target_squash := Vector3.ONE
	var target_spin := 0.0
	var target_hop := 0.0
	var has_model: bool = _janitor != null and bool(_janitor.call("is_ready_visual"))
	var has_dance_anim: bool = has_model and bool(_janitor.call("has_anim", &"dance"))

	if _dancing and not has_dance_anim:
		# Dans animi yoksa eski squash dansı
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
		rotation.y += dance_spin_speed * delta * (1.2 + 0.4 * sin(_dance_t * 3.0))
	elif _dancing and has_dance_anim:
		# Anim varken sadece yavaş dönüş
		rotation.y += dance_spin_speed * delta * 0.55
	elif _potion_drunk > 0.15 and not has_model:
		_drunk_t += delta
		var w := _potion_drunk
		var bob2 := sin(_drunk_t * 16.0)
		var sway2 := sin(_drunk_t * 11.0)
		target_squash = Vector3(
			1.1 + bob2 * 0.22 * w,
			0.82 - bob2 * 0.18 * w,
			1.1 + bob2 * 0.22 * w
		)
		target_spin = sway2 * 0.7 * w
		target_hop = absf(sin(_drunk_t * 9.0)) * dance_hop * 0.85 * w
		if Engine.get_physics_frames() % 20 == 0 and w > 0.45:
			fx_burst.emit(&"dance", global_position + Vector3(0, 0.4, 0), 0.45 * w)

	# Janitor modelinde squash/tilt ışınlanma gibi kaydırır — bloat hariç kilitle
	var bloat_mul := lerpf(1.0, bloat_max_scale, _bloat)
	var bloat_scale := Vector3(bloat_mul, lerpf(1.0, 1.22, _bloat), bloat_mul)
	if _speed_rush_t > 0.0:
		var pulse := 1.0 + 0.04 * sin(Time.get_ticks_msec() * 0.02)
		bloat_scale *= pulse
	if has_model:
		target_squash = bloat_scale
		target_spin = 0.0
		target_hop = 0.0
	else:
		target_squash = Vector3(
			target_squash.x * bloat_scale.x,
			target_squash.y * bloat_scale.y,
			target_squash.z * bloat_scale.z
		)

	_squash = _squash.lerp(target_squash, clampf(10.0 * delta, 0.0, 1.0))
	_visual_spin = lerpf(_visual_spin, target_spin, clampf(8.0 * delta, 0.0, 1.0))
	_hop_y = lerpf(_hop_y, target_hop, clampf(12.0 * delta, 0.0, 1.0))

	_visual.scale = _squash
	_visual.rotation.z = _visual_spin * 0.35
	_visual.rotation.x = -_visual_spin * 0.15
	_visual.position = Vector3(0.0, -0.9 + _hop_y, 0.0)
	_place_hold_point()


func _place_hold_point() -> void:
	if _hold_point == null:
		return
	# Dünya uzayında bakış yönüne göre yerleştir — yerel eksen sapmalarını aşar
	var fwd := _facing
	if fwd.length_squared() < 0.0001:
		fwd = Vector3(0.0, 0.0, -1.0)
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := Vector3(fwd.z, 0.0, -fwd.x)
	var world_off := right * HOLD_RIGHT + fwd * HOLD_FORWARD + Vector3(0.0, HOLD_Y + _hop_y * 0.25, 0.0)
	_hold_point.global_position = global_position + world_off
	_hold_point.rotation = Vector3.ZERO


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
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	_facing = dir
	rotation.y = atan2(dir.x, dir.z)


## Yumuşak bakış — her karede sert snap 360° spin yapmasın.
func _soft_face_toward(dir: Vector3, max_rad_per_frame: float = 0.1) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.12:
		return
	dir = dir.normalized()
	_facing = _facing.lerp(dir, 0.35).normalized()
	var target_yaw := atan2(dir.x, dir.z)
	var diff := wrapf(target_yaw - rotation.y, -PI, PI)
	rotation.y += clampf(diff, -max_rad_per_frame, max_rad_per_frame)


func try_set_tool_index(idx: int) -> void:
	_try_set_tool_index(idx)


func _try_set_tool_index(idx: int) -> void:
	if idx < 0 or idx >= unlocked_tool_count:
		return
	if idx == int(ToolKind.MOP) and not allow_mop:
		return
	_set_tool(idx as ToolKind)


func get_tool_name() -> String:
	var i := clampi(int(active_tool), 0, TOOL_NAMES.size() - 1)
	return TOOL_NAMES[i]


func get_unlocked_tool_count() -> int:
	return unlocked_tool_count


func get_bloat() -> float:
	return _bloat


func get_junk_powerup_progress() -> int:
	return _junk_toward_powerup


func is_speed_rush_active() -> bool:
	return _speed_rush_t > 0.0


func eat_junk() -> void:
	_bloat = minf(1.0, _bloat + bloat_per_junk)
	# Belirgin şişme pop — her lokmada daha “balon”
	var pop := 1.35 + _bloat * 0.55
	_squash = Vector3(pop, maxf(0.42, 0.85 - _bloat * 0.28), pop)
	_hop_y = 0.28 + _bloat * 0.22
	_play_sfx(PrototypeSfx.Kind.DISPOSE, 1.05 + _bloat * 0.2)
	fx_burst.emit(&"clean", global_position + Vector3(0, 0.8, 0), 1.15 + _bloat * 0.4)
	_junk_toward_powerup += 1
	var triggered := false
	if _junk_toward_powerup >= junk_powerup_every:
		_junk_toward_powerup = 0
		triggered = true
	junk_eaten.emit(global_position)
	if triggered:
		_roll_junk_powerup()


func _roll_junk_powerup() -> void:
	# İki güçten biri
	if randf() < 0.5:
		_speed_rush_t = speed_rush_duration
		_squash = Vector3(1.25, 1.15, 1.25)
		_hop_y = 0.4
		_play_sfx(PrototypeSfx.Kind.PHASE, 1.2)
		fx_burst.emit(&"dash", global_position, 1.6)
		status_message.emit("⚡ HIZ PATLAMASI! Koş + taşı hızlandı")
		junk_powerup.emit(&"speed_rush")
	else:
		_play_sfx(PrototypeSfx.Kind.PHASE, 0.85)
		fx_burst.emit(&"clean", global_position + Vector3(0, 1.0, 0), 2.0)
		status_message.emit("🌪️ SÜPÜRGE FIRTINASI! Sahne temizleniyor")
		junk_powerup.emit(&"scene_sweep")


func _set_tool(tool: ToolKind) -> void:
	var idx := int(tool)
	if idx < 0 or idx >= unlocked_tool_count:
		return
	if tool == ToolKind.MOP and not allow_mop:
		return
	if active_tool == tool:
		return
	active_tool = tool
	tool_switched.emit(get_tool_name())
	_play_sfx(PrototypeSfx.Kind.SWITCH)
	_refresh_vacuum_tool_visual()
	if tool != ToolKind.BROOM:
		_release_vacuum()


func configure_for_level(
	mop_allowed: bool,
	dash_charges: int = 1,
	flashlight: bool = false,
	unlocked_tools: int = 1,
) -> void:
	allow_mop = mop_allowed
	unlocked_tool_count = clampi(unlocked_tools, 1, TOOL_NAMES.size())
	if not allow_mop and unlocked_tool_count < 2:
		# Tutorial: vuruş için fırça slotu yoksa broom/brush yerine en az 1 alet
		unlocked_tool_count = maxi(1, unlocked_tool_count)
	_fail_stun = 0.0
	_potion_silence = 0.0
	_potion_silence_cd = 0.0
	_potion_drunk = 0.0
	_bloat = 0.0
	_junk_toward_powerup = 0
	_speed_rush_t = 0.0
	if _dancing:
		_dancing = false
		dance_changed.emit(false)
	set_max_dash_charges(dash_charges)
	set_flashlight_enabled(flashlight)
	tools_unlocked_changed.emit(unlocked_tool_count)
	_vacuum_bag = 0
	_refresh_vacuum_bag_visual()
	vacuum_bag_changed.emit(0, vacuum_bag_capacity)
	if not allow_mop:
		_mop_dirt = 0.0
		mop_dirt_changed.emit(0.0)
		# Tutorial: genel vuruş — unlock 1 iken mop kapalıysa brush yok; mop'u zorla açma
		if unlocked_tool_count >= 3:
			_set_tool(ToolKind.BRUSH)
		elif unlocked_tool_count >= 2:
			_set_tool(ToolKind.BROOM)
		else:
			# Tek alet ama mop yasak — mop'u yine de vuruş için kullan (L1 smash)
			allow_mop = false
			active_tool = ToolKind.MOP
			tool_switched.emit("mop")
	else:
		if int(active_tool) >= unlocked_tool_count:
			_set_tool(ToolKind.MOP)
		elif active_tool != ToolKind.MOP:
			pass
		else:
			_set_tool(ToolKind.MOP)
	_refresh_vacuum_tool_visual()


func _wrong_tool(needed: String) -> void:
	wrong_tool_used.emit(needed)
	status_message.emit("Yanlış alet! (%s)" % needed.capitalize())
	_swing_cooldown = 0.18
	_squash = Vector3(1.2, 0.85, 1.2)
	_play_sfx(PrototypeSfx.Kind.TASK_FAIL, 0.85)


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
	if _fail_stun > 0.0 or _potion_silence > 0.0:
		return
	if _swing_cooldown > 0.0:
		return
	interact_attempted.emit()

	# Kovada durulama (paspas + kirli + boş el)
	if _held == null and active_tool == ToolKind.MOP and allow_mop and _mop_dirt > 0.01:
		var bucket := _find_station(BUCKET_GROUP)
		if bucket != null:
			_rinsing = true
			_swing_cooldown = 0.05
			_play_sfx(PrototypeSfx.Kind.RINSE, 0.9)
			return

	# Süpürge torbasını çöpe boşalt
	if _held == null and active_tool == ToolKind.BROOM and _vacuum_bag > 0:
		var trash := _find_station(TRASH_GROUP)
		if trash != null:
			_empty_vacuum_bag(trash)
			return

	if _held != null:
		if _try_dispose_held():
			return
		var stack_target := _find_interact_target()
		if stack_target != null and _try_stack_onto(stack_target):
			return
		_try_throw()
		return

	# Junk food — önce ye
	var junk := _find_junk_target()
	if junk != null:
		_eat_junk_prop(junk)
		return

	# ★ işaretli taşınabilir emir
	if _held == null:
		var marked_box := _find_marked_carry_target()
		if marked_box != null:
			if not _can_pick_prop(marked_box):
				return
			_pick_up(marked_box)
			return

	# Wet: önce sprey
	var spray_tgt := _find_needs_spray_target()
	if spray_tgt != null:
		if active_tool != ToolKind.SPRAY:
			_wrong_tool("spray")
			return
		spray_tgt.apply_spray()
		_swing_cooldown = 0.2
		_snap_face(spray_tgt.global_position - global_position)
		_play_sfx(PrototypeSfx.Kind.RINSE, 1.1)
		fx_burst.emit(&"scrub", spray_tgt.global_position + Vector3(0, 0.3, 0), 0.9)
		status_message.emit("Sprey OK — şimdi paspas!")
		return

	# Scrub (mop)
	if allow_mop:
		var scrub := _find_scrub_target()
		if scrub != null:
			if not scrub.can_interact_with(get_tool_name()):
				# Easter egg: küfe sprey
				if active_tool == ToolKind.SPRAY and scrub.prop_id in ["mold", "hidden"]:
					secret_probe.emit("spray_mold", scrub.global_position)
				_wrong_tool(scrub.required_tool if not scrub.required_tool.is_empty() else "mop")
				return
			_mash_scrub(scrub)
			return

	var prop := _find_interact_target()
	if prop == null:
		# Boş alanda broom tap → ipucu (emme zaten otomatik)
		if active_tool == ToolKind.BROOM and unlocked_tool_count >= 2:
			if is_vacuum_bag_full():
				status_message.emit("Torba dolu — çöpe yaklaşıp Space/tık")
			else:
				status_message.emit("Süpürge otomatik emer — toza yaklaş")
			_swing_cooldown = 0.12
		return

	# Tablo / TV tamir — herhangi alet (fırça L5+ önerilir)
	if prop.is_repair_target():
		# Easter egg: tabloya cımbız
		if prop.is_painting and active_tool == ToolKind.BRUSH:
			secret_probe.emit("tweezers_painting", prop.global_position)
		var done := prop.apply_repair_tap()
		_swing_cooldown = 0.12
		_snap_face(prop.global_position - global_position)
		_squash = Vector3(1.15, 0.88, 1.15)
		_play_sfx(PrototypeSfx.Kind.HIT, 1.0)
		fx_burst.emit(&"scrub", prop.global_position + Vector3(0, 0.5, 0), 0.7)
		if done:
			_play_sfx(PrototypeSfx.Kind.DISPOSE, 1.15)
			fx_burst.emit(&"clean", prop.global_position + Vector3(0, 0.55, 0), 1.25)
			if prop.is_painting:
				fx_burst.emit(&"dispose", prop.global_position + Vector3(0.15, 0.7, 0), 0.9)
			item_disposed.emit(prop.prop_id)
			status_message.emit("Tablo düzeldi!" if prop.is_painting else "TV tamir!")
		return

	# Luigi emme hedefleri — tap değil, basılı tut
	if prop.is_vacuum_target_for(get_tool_name()):
		status_message.emit("Basılı tut — em!")
		_swing_cooldown = 0.08
		_snap_face(prop.global_position - global_position)
		return

	if prop.can_carry and prop.is_carryable():
		# Süpürgeyle emilebilirleri taşıma — basılı tut
		if prop.is_vacuum_target_for("broom") and active_tool == ToolKind.BROOM:
			status_message.emit("Basılı tut — em!")
			_swing_cooldown = 0.08
			return
		if not _can_pick_prop(prop):
			return
		_pick_up(prop)
		return

	if prop.is_scrub_target():
		if allow_mop:
			if not prop.can_interact_with(get_tool_name()):
				_wrong_tool("mop")
				return
			_mash_scrub(prop)
		return

	# Hit
	var tool_name := get_tool_name()
	if not prop.can_interact_with(tool_name):
		_wrong_tool(prop.required_tool if not prop.required_tool.is_empty() else "brush")
		return
	var hit_dir := prop.global_position - global_position
	var strength := mop_swing_strength
	var cd := mop_swing_cooldown
	if active_tool == ToolKind.BRUSH:
		strength = brush_swing_strength
		cd = brush_swing_cooldown
	elif active_tool == ToolKind.BROOM:
		strength = 1.1
		cd = 0.25
	elif active_tool == ToolKind.SPRAY:
		strength = 0.85
		cd = 0.22
	if active_tool == ToolKind.MOP:
		strength *= lerpf(1.0, 0.45, _mop_dirt)
	# Tutorial mop yasak ama smash için: brush yoksa mop güçlü vursun
	if not allow_mop and unlocked_tool_count <= 1:
		strength = brush_swing_strength
		cd = brush_swing_cooldown
		tool_name = "brush"
	prop.apply_hit(prop.global_position, hit_dir, strength, tool_name)
	_swing_cooldown = cd
	_snap_face(hit_dir)
	_squash = Vector3(1.12, 0.88, 1.12)
	_play_sfx(PrototypeSfx.Kind.HIT, 1.0 + strength * 0.08)
	fx_burst.emit(&"hit", prop.global_position + Vector3(0, 0.7, 0), strength)
	if active_tool == ToolKind.MOP and allow_mop:
		_add_mop_dirt(mop_dirt_per_hit)


func _can_pick_prop(prop: ClutterProp) -> bool:
	if prop == null:
		return false
	if prop.prop_id == "crumb" or prop.required_tool == "broom" or prop.prop_id == "tiny":
		if active_tool != ToolKind.BROOM:
			_wrong_tool("broom")
			return false
	return true


func _find_junk_target() -> ClutterProp:
	var best: ClutterProp = null
	var best_d := 999.0
	for node in get_tree().get_nodes_in_group(PROP_GROUP):
		var p := node as ClutterProp
		if p == null or not p.is_junk():
			continue
		var flat := p.global_position - global_position
		flat.y = 0.0
		var d := flat.length()
		if d > swing_range * 0.85:
			continue
		if d < best_d:
			best_d = d
			best = p
	return best


func _find_needs_spray_target() -> ClutterProp:
	var best: ClutterProp = null
	var best_d := 999.0
	for node in get_tree().get_nodes_in_group(PROP_GROUP):
		var p := node as ClutterProp
		if p == null or not p.needs_spray():
			continue
		var flat := p.global_position - global_position
		flat.y = 0.0
		var d := flat.length()
		if d > maxf(p.scrub_radius, swing_range * 0.7) + 0.4:
			continue
		if d < best_d:
			best_d = d
			best = p
	return best


func _eat_junk_prop(prop: ClutterProp) -> void:
	if prop == null or not prop.is_junk():
		return
	var pos := prop.global_position
	prop.consume_junk()
	eat_junk()
	_swing_cooldown = 0.2
	_snap_face(pos - global_position)


func _mash_scrub(prop: ClutterProp) -> void:
	if prop == null or not prop.is_scrub_target():
		return
	if active_tool != ToolKind.MOP:
		if unlocked_tool_count >= 1 and allow_mop:
			_set_tool(ToolKind.MOP)
		else:
			_wrong_tool("mop")
			return
	var effectiveness := lerpf(1.0, 0.45, _mop_dirt)
	var cleaned := prop.apply_scrub_tap(effectiveness)
	_swing_cooldown = scrub_mash_cooldown
	_snap_face(prop.global_position - global_position)
	_add_mop_dirt(mop_dirt_per_hit * 0.12)
	_play_sfx(PrototypeSfx.Kind.HIT, 0.85 + prop.get_scrub_progress() * 0.4)
	fx_burst.emit(&"scrub", prop.global_position + Vector3(0, 0.25, 0), 0.65 + prop.get_scrub_progress() * 0.55)
	_squash = Vector3(1.18, 0.82, 1.18)
	if cleaned:
		_play_sfx(PrototypeSfx.Kind.DISPOSE, 1.1)
		fx_burst.emit(&"clean", prop.global_position + Vector3(0, 0.4, 0), 1.15)
		# Mash bitişi → kaygan ıslak iz (hazard); sürükleme temizliği iz bırakmaz
		floor_scrubbed.emit(prop.global_position)
		item_disposed.emit(prop.prop_id)
		status_message.emit("Hızlı silindi — zemin kaygan!")


func _try_throw() -> void:
	if _fail_stun > 0.0 or _potion_silence > 0.0:
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


## Paspasla sıvı ovalama (Viscera): basılı tut + yürü = silme izi; Space mash = hızlı + kaygan iz.
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
	var effectiveness := lerpf(1.0, 0.5, _mop_dirt)
	var cleaned := false
	if prop.liquid_wipe:
		# Alan kirle küçülmesin — kir sadece gücü düşürür
		var stamp_r := clampf(0.55 + motion * 3.2, 0.5, 0.95)
		var stamp_s := clampf(0.24 + motion * 3.6, 0.2, 0.52) * effectiveness
		cleaned = prop.apply_scrub_stamp(global_position, stamp_r, stamp_s)
	else:
		cleaned = prop.apply_scrub(motion * 1.35, effectiveness)
	_add_mop_dirt(mop_dirt_per_hit * 0.12 * clampf(motion * 3.5, 0.3, 1.0))
	if Engine.get_physics_frames() % 8 == 0:
		_play_sfx(PrototypeSfx.Kind.HIT, 0.75 + prop.get_scrub_progress() * 0.35)
		fx_burst.emit(&"scrub", prop.global_position + Vector3(0, 0.25, 0), 0.55 + prop.get_scrub_progress() * 0.5)
	if cleaned:
		_play_sfx(PrototypeSfx.Kind.DISPOSE, 1.1)
		fx_burst.emit(&"clean", prop.global_position + Vector3(0, 0.4, 0), 1.15)
		# Viscera sürükleme: temiz bitti, kayganlık yok
		item_disposed.emit(prop.prop_id)


## Süpürge seçiliyken sürekli emme — basılı tutmaya gerek yok.
func _update_broom_vacuum(delta: float) -> void:
	_refresh_vacuum_tool_visual()
	if _held != null or active_tool != ToolKind.BROOM or unlocked_tool_count < 2:
		_release_vacuum()
		return
	_vacuum_active = true
	_vacuum_pulse_t += delta
	_ensure_vacuum_visuals()
	_aim_vacuum_sector()
	# Torba doluysa sektör görünür ama emme yok
	if _vacuum_bag >= vacuum_bag_capacity:
		_aim_vacuum_beam(null)
		_release_vacuum_targets(delta, true)
		if Engine.get_physics_frames() % 45 == 0:
			status_message.emit("Torba dolu! Çöpe boşalt (%d/%d)" % [_vacuum_bag, vacuum_bag_capacity])
		_vacuum_hum_cd -= delta
		if _vacuum_hum_cd <= 0.0:
			_vacuum_hum_cd = 0.22
			_play_sfx(PrototypeSfx.Kind.TASK_FAIL, 0.55)
		return
	var targets := _find_vacuum_targets()
	_sync_vacuum_targets(targets, delta)
	_aim_vacuum_beam(targets[0] if not targets.is_empty() else null)
	_vacuum_hum_cd -= delta
	if _vacuum_hum_cd <= 0.0:
		_vacuum_hum_cd = 0.14 if targets.is_empty() else 0.10
		_play_sfx(PrototypeSfx.Kind.RINSE, 1.35 + randf_range(-0.08, 0.1))
	if targets.is_empty():
		return
	# En yakın hedefe hafif bak (spin yok)
	var focus := targets[0]
	var to_focus := focus.global_position - global_position
	to_focus.y = 0.0
	if to_focus.length() > 1.2:
		_soft_face_toward(to_focus, 0.07)
	var nozzle := _get_vacuum_nozzle_pos()
	var slots_left := vacuum_bag_capacity - _vacuum_bag
	var captured_n := 0
	for i in targets.size():
		var prop := targets[i]
		if prop == null or not is_instance_valid(prop):
			continue
		if Engine.get_physics_frames() % 2 == 0:
			var mid := prop.global_position.lerp(nozzle, 0.4) + Vector3(0, 0.15, 0)
			fx_burst.emit(&"suck", mid, 0.55 + prop.get_vacuum_progress() * 0.55)
		if slots_left <= 0:
			prop.apply_vacuum_suck(delta * 0.35, nozzle, vacuum_pull_speed * 0.4)
			continue
		var captured := prop.apply_vacuum_suck(delta, nozzle, vacuum_pull_speed)
		if captured:
			_add_vacuum_bag(1)
			slots_left -= 1
			captured_n += 1
			_play_sfx(PrototypeSfx.Kind.DISPOSE, 1.2 + randf_range(-0.05, 0.1))
			fx_burst.emit(&"clean", nozzle, 1.05)
			fx_burst.emit(&"dispose", nozzle + Vector3(0, 0.15, 0), 0.85)
			item_disposed.emit(prop.prop_id)
	if captured_n > 0:
		_vacuum_targets = _vacuum_targets.filter(func(p: ClutterProp) -> bool:
			return p != null and is_instance_valid(p) and not p.is_destroying()
		)
		_squash = Vector3(1.12, 0.9, 1.12)
		_hop_y = 0.1
		if is_vacuum_bag_full():
			status_message.emit("⚠️ TORBA DOLU — çöpe boşalt!")
		elif captured_n == 1:
			status_message.emit("Emildi · torba %d/%d" % [_vacuum_bag, vacuum_bag_capacity])
		else:
			status_message.emit("x%d emildi · torba %d/%d" % [captured_n, _vacuum_bag, vacuum_bag_capacity])


func _sync_vacuum_targets(fresh: Array[ClutterProp], delta: float) -> void:
	# Eski hedeflerden düşenleri yavaş bırak
	for old in _vacuum_targets:
		if old == null or not is_instance_valid(old):
			continue
		if old in fresh:
			continue
		old.cancel_vacuum_pull(delta)
	_vacuum_targets = fresh
	_vacuum_target = fresh[0] if not fresh.is_empty() else null


func _release_vacuum_targets(delta: float, snap: bool = false) -> void:
	for p in _vacuum_targets:
		if p != null and is_instance_valid(p):
			p.cancel_vacuum_pull(delta, snap)
	_vacuum_targets.clear()
	_vacuum_target = null


func _add_vacuum_bag(amount: int = 1) -> void:
	var before := _vacuum_bag
	_vacuum_bag = clampi(_vacuum_bag + amount, 0, vacuum_bag_capacity)
	_refresh_vacuum_bag_visual()
	if _vacuum_bag != before:
		vacuum_bag_changed.emit(_vacuum_bag, vacuum_bag_capacity)
	if before < vacuum_bag_capacity and _vacuum_bag >= vacuum_bag_capacity:
		_play_sfx(PrototypeSfx.Kind.TASK_FAIL, 0.75)
		fx_burst.emit(&"bump", global_position + Vector3(0, 1.0, 0), 1.1)
		_squash = Vector3(1.22, 0.82, 1.22)
		_hop_y = 0.18


func _empty_vacuum_bag(zone: Node3D) -> void:
	if _vacuum_bag <= 0:
		return
	var was_full := _vacuum_bag >= vacuum_bag_capacity
	var dumped := _vacuum_bag
	_vacuum_bag = 0
	_refresh_vacuum_bag_visual()
	vacuum_bag_changed.emit(_vacuum_bag, vacuum_bag_capacity)
	_swing_cooldown = 0.2
	_play_sfx(PrototypeSfx.Kind.DISPOSE, 0.95)
	var at := global_position + Vector3(0, 0.8, 0)
	if zone != null:
		at = zone.global_position + Vector3(0, 0.8, 0)
	fx_burst.emit(&"dispose", at, 1.15)
	fx_burst.emit(&"clean", at + Vector3(0.2, 0.1, 0), 0.9)
	status_message.emit("Torba boşaltıldı (−%d)" % dumped)
	_squash = Vector3(1.1, 0.9, 1.1)
	bag_emptied.emit(dumped, was_full, at)


func get_vacuum_bag_fill() -> float:
	return float(_vacuum_bag) / float(maxi(vacuum_bag_capacity, 1))


func get_vacuum_bag_count() -> int:
	return _vacuum_bag


func is_vacuum_bag_full() -> bool:
	return _vacuum_bag >= vacuum_bag_capacity


func _release_vacuum() -> void:
	_vacuum_active = false
	_release_vacuum_targets(0.08, true)
	if _vacuum_beam != null:
		_vacuum_beam.visible = false
	if _vacuum_sector != null:
		_vacuum_sector.visible = false
	if _vacuum_sector_rim != null:
		_vacuum_sector_rim.visible = false


func _find_vacuum_targets() -> Array[ClutterProp]:
	var facing := _aim_direction()
	var tool := get_tool_name()
	var nozzle := _get_vacuum_nozzle_pos()
	var scored: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group(PROP_GROUP):
		var prop := node as ClutterProp
		if prop == null or not prop.is_vacuum_target_for(tool):
			continue
		var flat_p := prop.global_position - global_position
		flat_p.y = 0.0
		var dist_p := flat_p.length()
		var flat_n := prop.global_position - nozzle
		flat_n.y = 0.0
		var dist_n := flat_n.length()
		# Oyuncu veya nozul yakını — ayak altı / yan tozlar kaçmasın
		var dist := minf(dist_p, dist_n)
		if dist > vacuum_range:
			continue
		var magnet := dist <= vacuum_close_magnet or dist_p <= vacuum_close_magnet * 0.85
		var dot := 1.0
		if dist_p > 0.04:
			dot = facing.dot(flat_p / dist_p)
		if not magnet:
			# Orta mesafe: yumuşak koni; uzak: tam sektör
			var need := vacuum_cone_dot
			if dist < vacuum_close_magnet * 1.45:
				need = lerpf(0.15, vacuum_cone_dot, (dist - vacuum_close_magnet) / maxf(vacuum_close_magnet * 0.45, 0.01))
			if dot < need:
				continue
		# Yakın / emilmekte olanlar öncelikli
		var score := (1.0 - dist / vacuum_range) * 2.6 + maxf(dot, 0.0) + prop.get_vacuum_progress() * 1.6
		if magnet:
			score += 1.8
		if dist_p < 0.55:
			score += 1.2
		scored.append({"prop": prop, "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)
	var out: Array[ClutterProp] = []
	for i in mini(scored.size(), vacuum_max_targets):
		out.append(scored[i]["prop"] as ClutterProp)
	return out


func _find_vacuum_target() -> ClutterProp:
	var list := _find_vacuum_targets()
	return list[0] if not list.is_empty() else null


func _get_vacuum_nozzle_pos() -> Vector3:
	if _vacuum_nozzle != null and is_instance_valid(_vacuum_nozzle):
		return _vacuum_nozzle.global_position
	var fwd := _aim_direction()
	return global_position + fwd * 0.85 + Vector3(0, 0.75, 0)


func _ensure_vacuum_visuals() -> void:
	if _vacuum_rig != null and is_instance_valid(_vacuum_rig):
		_layout_vacuum_backpack()
		return
	if _visual == null:
		return
	_vacuum_rig = Node3D.new()
	_vacuum_rig.name = "VacuumRig"
	_visual.add_child(_vacuum_rig)

	# Sırt tankı — sırt çantası gibi omuzların arkasında
	_vacuum_tank_mesh = MeshInstance3D.new()
	var tank_mesh := CapsuleMesh.new()
	tank_mesh.radius = 0.2
	tank_mesh.height = 0.62
	_vacuum_tank_mesh.mesh = tank_mesh
	_vacuum_tank_mesh.material_override = _vac_mat(Color(0.25, 0.55, 0.95), Color(0.45, 0.85, 1.0))
	_vacuum_rig.add_child(_vacuum_tank_mesh)

	# Omuz askısı (görsel)
	for side in [-1.0, 1.0]:
		var strap := MeshInstance3D.new()
		strap.name = "Strap%s" % ("L" if side < 0.0 else "R")
		var strap_mesh := BoxMesh.new()
		strap_mesh.size = Vector3(0.06, 0.42, 0.04)
		strap.mesh = strap_mesh
		strap.position = Vector3(side * 0.16, 0.28, -0.06)
		strap.rotation_degrees = Vector3(-18.0, 0.0, side * -12.0)
		strap.material_override = _vac_mat(Color(0.2, 0.22, 0.28), Color(0.35, 0.4, 0.5))
		_vacuum_rig.add_child(strap)

	# Hortum: sırt → omuz → öne
	var hose := MeshInstance3D.new()
	hose.name = "Hose"
	var hose_mesh := CylinderMesh.new()
	hose_mesh.top_radius = 0.04
	hose_mesh.bottom_radius = 0.05
	hose_mesh.height = 0.85
	hose.mesh = hose_mesh
	hose.material_override = _vac_mat(Color(0.15, 0.15, 0.18), Color(0.3, 0.35, 0.4))
	_vacuum_rig.add_child(hose)

	# Nozul — elde / önde
	_vacuum_nozzle = Node3D.new()
	_vacuum_nozzle.name = "Nozzle"
	_vacuum_rig.add_child(_vacuum_nozzle)

	var nozzle_mesh := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.12
	cone.bottom_radius = 0.04
	cone.height = 0.28
	nozzle_mesh.mesh = cone
	nozzle_mesh.rotation_degrees = Vector3(90, 0, 0)
	nozzle_mesh.material_override = _vac_mat(Color(0.85, 0.75, 0.25), Color(1.0, 0.95, 0.4))
	_vacuum_nozzle.add_child(nozzle_mesh)

	_layout_vacuum_backpack()

	# Emme ışını
	_vacuum_beam = MeshInstance3D.new()
	_vacuum_beam.name = "VacuumBeam"
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.08
	beam_mesh.bottom_radius = 0.22
	beam_mesh.height = 1.0
	_vacuum_beam.mesh = beam_mesh
	_vacuum_beam_mat = StandardMaterial3D.new()
	_vacuum_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_vacuum_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_vacuum_beam_mat.albedo_color = Color(0.45, 0.9, 1.0, 0.35)
	_vacuum_beam_mat.emission_enabled = true
	_vacuum_beam_mat.emission = Color(0.4, 0.85, 1.0)
	_vacuum_beam_mat.emission_energy_multiplier = 2.4
	_vacuum_beam.material_override = _vacuum_beam_mat
	_vacuum_beam.visible = false
	add_child(_vacuum_beam)  # dünya uzayında hizalanacak

	# ZZZ tarzı yer sektörü (toplama alanı)
	_vacuum_sector = MeshInstance3D.new()
	_vacuum_sector.name = "VacuumSector"
	_vacuum_sector.mesh = _build_vacuum_sector_mesh(vacuum_range, vacuum_sector_half_deg, 28)
	_vacuum_sector_mat = StandardMaterial3D.new()
	_vacuum_sector_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_vacuum_sector_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_vacuum_sector_mat.albedo_color = Color(0.35, 0.78, 1.0, 0.22)
	_vacuum_sector_mat.emission_enabled = true
	_vacuum_sector_mat.emission = Color(0.4, 0.85, 1.0)
	_vacuum_sector_mat.emission_energy_multiplier = 1.8
	_vacuum_sector_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_vacuum_sector_mat.no_depth_test = true
	_vacuum_sector.material_override = _vacuum_sector_mat
	_vacuum_sector.visible = false
	add_child(_vacuum_sector)

	_vacuum_sector_rim = MeshInstance3D.new()
	_vacuum_sector_rim.name = "VacuumSectorRim"
	_vacuum_sector_rim.mesh = _build_vacuum_sector_rim_mesh(vacuum_range, vacuum_sector_half_deg, 28)
	var rim_mat := StandardMaterial3D.new()
	rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rim_mat.albedo_color = Color(0.85, 0.95, 1.0, 0.75)
	rim_mat.emission_enabled = true
	rim_mat.emission = Color(0.7, 0.95, 1.0)
	rim_mat.emission_energy_multiplier = 3.2
	rim_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	rim_mat.no_depth_test = true
	_vacuum_sector_rim.material_override = rim_mat
	_vacuum_sector_rim.visible = false
	add_child(_vacuum_sector_rim)


## Torba sırtta (lokal -Z), hortum/nozul önde (lokal +Z).
func _layout_vacuum_backpack() -> void:
	if _vacuum_rig == null:
		return
	# Sırt: -Z, karaktere yakın
	_vacuum_rig.position = Vector3(0.0, 1.02, -0.28)
	if _vacuum_tank_mesh != null:
		_vacuum_tank_mesh.position = Vector3(0.0, 0.06, -0.08)
		_vacuum_tank_mesh.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	var hose := _vacuum_rig.get_node_or_null("Hose") as MeshInstance3D
	if hose != null:
		hose.position = Vector3(0.26, 0.18, 0.08)
		hose.rotation_degrees = Vector3(-52.0, 38.0, -8.0)
	if _vacuum_nozzle != null:
		_vacuum_nozzle.position = Vector3(0.4, -0.05, 0.58)
	for c in _vacuum_rig.get_children():
		if c is MeshInstance3D and String(c.name).begins_with("Strap"):
			var s := c as MeshInstance3D
			s.position.z = -0.02
			s.rotation_degrees.x = -14.0


func _vac_mat(albedo: Color, emission: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = 1.4
	mat.roughness = 0.55
	return mat


func _refresh_vacuum_tool_visual() -> void:
	_ensure_vacuum_visuals()
	if _vacuum_rig == null:
		return
	var show_vac := active_tool == ToolKind.BROOM and unlocked_tool_count >= 2
	_vacuum_rig.visible = show_vac
	if not show_vac:
		if _vacuum_sector != null:
			_vacuum_sector.visible = false
		if _vacuum_sector_rim != null:
			_vacuum_sector_rim.visible = false
	if show_vac:
		var pulse := 1.0 + (0.03 if _vacuum_active else 0.0) * sin(Time.get_ticks_msec() * 0.035)
		_vacuum_rig.scale = Vector3.ONE * pulse
		_refresh_vacuum_bag_visual()


func _refresh_vacuum_bag_visual() -> void:
	if _vacuum_tank_mesh == null:
		return
	var fill := get_vacuum_bag_fill()
	var empty_c := Color(0.25, 0.55, 0.95)
	var full_c := Color(0.95, 0.45, 0.2)
	var c := empty_c.lerp(full_c, fill)
	_vacuum_tank_mesh.material_override = _vac_mat(c, c.lightened(0.25))
	# Doluluk: tank biraz şişsin
	_vacuum_tank_mesh.scale = Vector3.ONE * lerpf(1.0, 1.28, fill)


func _build_vacuum_sector_mesh(radius: float, half_deg: float, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ha := deg_to_rad(half_deg)
	var y := 0.04
	for i in segs:
		var a0 := -ha + (2.0 * ha) * float(i) / float(segs)
		var a1 := -ha + (2.0 * ha) * float(i + 1) / float(segs)
		# İleri = -Z (look_at uyumu)
		var p0 := Vector3(sin(a0) * radius, y, -cos(a0) * radius)
		var p1 := Vector3(sin(a1) * radius, y, -cos(a1) * radius)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(0.0, y, 0.0))
		st.add_vertex(p0)
		st.add_vertex(p1)
	st.generate_normals()
	return st.commit()


func _build_vacuum_sector_rim_mesh(radius: float, half_deg: float, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ha := deg_to_rad(half_deg)
	var y := 0.055
	var thick := 0.07
	var r0 := maxf(0.2, radius - thick)
	var r1 := radius + 0.02
	for i in segs:
		var a0 := -ha + (2.0 * ha) * float(i) / float(segs)
		var a1 := -ha + (2.0 * ha) * float(i + 1) / float(segs)
		var i0 := Vector3(sin(a0) * r0, y, -cos(a0) * r0)
		var i1 := Vector3(sin(a1) * r0, y, -cos(a1) * r0)
		var o0 := Vector3(sin(a0) * r1, y, -cos(a0) * r1)
		var o1 := Vector3(sin(a1) * r1, y, -cos(a1) * r1)
		st.set_normal(Vector3.UP)
		st.add_vertex(i0)
		st.add_vertex(o0)
		st.add_vertex(o1)
		st.add_vertex(i0)
		st.add_vertex(o1)
		st.add_vertex(i1)
	# İki yan kenar
	for side: float in [-1.0, 1.0]:
		var a: float = side * ha
		var inner := Vector3(sin(a) * 0.15, y, -cos(a) * 0.15)
		var outer := Vector3(sin(a) * r1, y, -cos(a) * r1)
		var perp := Vector3(cos(a), 0.0, sin(a)) * 0.04 * side
		st.add_vertex(inner - perp)
		st.add_vertex(outer - perp)
		st.add_vertex(outer + perp)
		st.add_vertex(inner - perp)
		st.add_vertex(outer + perp)
		st.add_vertex(inner + perp)
	st.generate_normals()
	return st.commit()


func _aim_vacuum_sector() -> void:
	if _vacuum_sector == null:
		return
	var fwd := _aim_direction()
	_vacuum_sector.visible = true
	if _vacuum_sector_rim != null:
		_vacuum_sector_rim.visible = true
	var origin := Vector3(global_position.x, 0.0, global_position.z)
	var look_basis := Basis.looking_at(fwd, Vector3.UP)
	_vacuum_sector.global_transform = Transform3D(look_basis, origin)
	if _vacuum_sector_rim != null:
		_vacuum_sector_rim.global_transform = Transform3D(look_basis, origin)
	# Nabız — doluyken kırmızımsı
	var pulse := 0.18 + 0.08 * absf(sin(_vacuum_pulse_t * 5.5))
	if _vacuum_sector_mat != null:
		if _vacuum_bag >= vacuum_bag_capacity:
			_vacuum_sector_mat.albedo_color = Color(1.0, 0.35, 0.25, pulse + 0.08)
			_vacuum_sector_mat.emission = Color(1.0, 0.4, 0.25)
			_vacuum_sector_mat.emission_energy_multiplier = 2.4
		else:
			var hot := clampf(float(_vacuum_targets.size()) / 3.0, 0.0, 1.0)
			_vacuum_sector_mat.albedo_color = Color(0.35, 0.78, 1.0, pulse).lerp(
				Color(0.55, 0.95, 1.0, pulse + 0.12), hot
			)
			_vacuum_sector_mat.emission = Color(0.4, 0.85, 1.0)
			_vacuum_sector_mat.emission_energy_multiplier = lerpf(1.6, 3.0, hot)


func _aim_vacuum_beam(target: ClutterProp) -> void:
	if _vacuum_beam == null:
		return
	var nozzle := _get_vacuum_nozzle_pos()
	var tip := nozzle + _aim_direction() * minf(vacuum_range * 0.55, 2.2)
	if target != null and is_instance_valid(target):
		tip = target.global_position + Vector3(0, 0.25, 0)
	var mid := (nozzle + tip) * 0.5
	var span := tip - nozzle
	var length := maxf(span.length(), 0.2)
	_vacuum_beam.visible = true
	_vacuum_beam.global_position = mid
	if span.length_squared() > 0.0001:
		_vacuum_beam.look_at(tip, Vector3.UP)
		_vacuum_beam.rotate_object_local(Vector3(1, 0, 0), PI * 0.5)
	var mesh := _vacuum_beam.mesh as CylinderMesh
	if mesh != null:
		mesh.height = length
		var widen := 0.2 if target != null else 0.12
		mesh.top_radius = 0.04
		mesh.bottom_radius = widen + (0.06 if _vacuum_active else 0.0)
	if _vacuum_beam_mat != null:
		var a := 0.5 if target != null else 0.2
		_vacuum_beam_mat.albedo_color = Color(0.45, 0.92, 1.0, a)
		_vacuum_beam_mat.emission_energy_multiplier = 3.0 if target != null else 1.4


func _find_scrub_target() -> ClutterProp:
	var best: ClutterProp = null
	var best_dist := 999.0
	var facing := _aim_direction()
	for node in get_tree().get_nodes_in_group(PROP_GROUP):
		var prop := node as ClutterProp
		if prop == null or not prop.is_scrub_target():
			continue
		var flat := prop.global_position - global_position
		flat.y = 0.0
		var dist := flat.length()
		# Yakın leke: bakış gerekmez; biraz uzakta yan yaklaşma OK
		var reach := prop.scrub_radius + 1.35
		if dist > reach:
			continue
		if dist > close_magnet_range:
			var dir := flat / maxf(dist, 0.001)
			if not _facing_ok(facing.dot(dir), dist, reach, true):
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


## Bakış + hareket yönü karışımı — koşarak yaklaşırken yan objeler de yakalanır.
func _aim_direction() -> Vector3:
	var facing := _facing
	facing.y = 0.0
	if facing.length_squared() < 0.0001:
		facing = -global_transform.basis.z
		facing.y = 0.0
	if facing.length_squared() < 0.0001:
		facing = Vector3(0, 0, -1)
	facing = facing.normalized()
	var vel := Vector3(velocity.x, 0.0, velocity.z)
	if vel.length_squared() > 1.2:
		facing = facing.lerp(vel.normalized(), 0.42).normalized()
	return facing


## Mesafe → bakış toleransı: yakın = 360°, orta = yanlar OK, uzak = hafif koni.
func _facing_ok(dot: float, dist: float, range_limit: float, generous: bool = false) -> bool:
	var magnet := close_magnet_range * (1.15 if generous else 1.0)
	if dist <= magnet:
		return true
	var soft := soft_cone_range * (1.1 if generous else 1.0)
	if dist <= soft:
		return dot >= (-0.45 if generous else -0.25)
	var t := 0.0
	if range_limit > soft:
		t = clampf((dist - soft) / (range_limit - soft), 0.0, 1.0)
	var need := lerpf(-0.08, interact_cone_dot, t * t)
	if generous:
		need -= 0.2
	return dot >= need


func _score_target(dot: float, dist: float, range_limit: float) -> float:
	# Önce yakınlık, sonra bakış — önünde olan kazanır ama yan da alınır
	return (1.0 - dist / maxf(range_limit, 0.01)) * 2.4 + maxf(dot, -0.2) * 1.1


func _find_station(group_name: StringName) -> Node3D:
	var facing := _aim_direction()
	var best: Node3D = null
	var best_score := -999.0
	# Elde bir şey varken çöp/kova: bakış neredeyse şart değil
	var holding := _held != null
	for node in get_tree().get_nodes_in_group(group_name):
		var zone := node as Node3D
		if zone == null:
			continue
		var to_z := zone.global_position - global_position
		to_z.y = 0.0
		var dist := to_z.length()
		var max_dist := float(zone.get_meta("interact_radius", swing_range * 1.25))
		if holding:
			max_dist *= 1.2
		if dist > max_dist or dist < 0.05:
			continue
		var dot := facing.dot(to_z / dist)
		if not _facing_ok(dot, dist, max_dist, true):
			continue
		var score := _score_target(dot, dist, max_dist)
		if holding:
			score += 1.5 # Dispose önceliği
		if score > best_score:
			best_score = score
			best = zone
	return best


func _find_marked_carry_target() -> ClutterProp:
	var facing := _aim_direction()
	var best: ClutterProp = null
	var best_score := -999.0
	var range_limit := swing_range + 1.15
	for node in get_tree().get_nodes_in_group(PROP_GROUP):
		var prop := node as ClutterProp
		if prop == null or prop.is_destroying() or prop.is_being_carried():
			continue
		if not bool(prop.get_meta("micro_task_marked", false)):
			continue
		if bool(prop.get_meta("forbidden", false)):
			continue
		if not (prop.can_carry and prop.is_carryable()):
			continue
		var to_prop := prop.global_position - global_position
		to_prop.y = 0.0
		var dist := to_prop.length()
		if dist > range_limit or dist < 0.05:
			continue
		var dir := to_prop / dist
		var dot := facing.dot(dir)
		if not _facing_ok(dot, dist, range_limit, true):
			continue
		var score := _score_target(dot, dist, range_limit) + 3.5
		if score > best_score:
			best_score = score
			best = prop
	return best


func _find_interact_target() -> ClutterProp:
	var facing := _aim_direction()
	var best: ClutterProp = null
	var best_score := -999.0
	for node in get_tree().get_nodes_in_group(PROP_GROUP):
		var prop := node as ClutterProp
		if prop == null or prop.is_being_carried() or prop.is_destroying():
			continue
		var to_prop := prop.global_position - global_position
		to_prop.y = 0.0
		var dist := to_prop.length()
		var marked := bool(prop.get_meta("micro_task_marked", false))
		# Prop kendi hitbox menzilini de kullan — büyük objeler (TV) daha cömert
		var prop_reach := maxf(prop.max_hit_distance, prop.react_distance) * 0.92
		var range_limit := maxf(swing_range, prop_reach) + (0.9 if marked else 0.0)
		if dist > range_limit or dist < 0.05:
			continue
		var dir := to_prop / dist
		var dot := facing.dot(dir)
		if not _facing_ok(dot, dist, range_limit, marked):
			continue
		var score := _score_target(dot, dist, range_limit)
		if marked:
			score += 3.5
		if bool(prop.get_meta("forbidden", false)):
			score -= 2.0
		# Taşınabilir / vurulabilir: aynı mesafede bakılan kazanır
		if prop.can_carry and prop.is_carryable():
			score += 0.15
		if score > best_score:
			best_score = score
			best = prop
	return best


func get_facing_direction() -> Vector3:
	return _facing


func get_aim_direction() -> Vector3:
	return _aim_direction()


func is_dancing() -> bool:
	return _dancing


func is_speed_rushing() -> bool:
	return _speed_rush_t > 0.0


func is_scrap_holding() -> bool:
	return _scrap_holding


## Elde tut (carry) + akıcı dönüş; kısa süre sonra UI geçişine hazır.
func play_scrap_hold(icon: String = "📦", accent: Color = Color(0.55, 0.65, 0.78)) -> void:
	if _scrap_holding:
		_clear_scrap_hold()
	_scrap_holding = true
	_scrap_spinning = true
	_scrap_spin_y = 0.0
	_rinsing = false
	if _dancing:
		_dancing = false
		dance_changed.emit(false)
	_release_vacuum()
	_squash = Vector3(1.12, 0.92, 1.12)
	_hop_y = 0.12
	_place_hold_point()
	_ensure_scrap_hold_visual(icon, accent)
	if _janitor != null and _janitor.is_ready_visual():
		if _janitor.has_method("force_loco"):
			_janitor.call("force_loco", &"carry", 1.0)
		elif _janitor.has_anim(&"carry"):
			_janitor.play_loco(&"carry", 1.0)
	_play_sfx(PrototypeSfx.Kind.TASK_OK, 1.0)
	var root := _scrap_hold_root
	if root == null:
		_scrap_holding = false
		_scrap_spinning = false
		scrap_hold_ui_ready.emit()
		scrap_hold_finished.emit()
		return
	root.visible = true
	root.scale = Vector3(0.15, 0.15, 0.15)
	root.position = Vector3.ZERO
	root.rotation = Vector3.ZERO
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Büyü + dönerek elde tut
	tw.tween_property(root, "scale", Vector3(1.25, 1.25, 1.25), 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		scrap_hold_ui_ready.emit()
	)


func get_scrap_hold_screen_pos(cam: Camera3D) -> Vector2:
	if cam == null:
		return Vector2.ZERO
	var gp := global_position + Vector3(0, 1.1, 0)
	if _hold_point != null and is_instance_valid(_hold_point):
		gp = _hold_point.global_position
	elif _scrap_hold_root != null and is_instance_valid(_scrap_hold_root):
		gp = _scrap_hold_root.global_position
	if cam.is_position_behind(gp):
		return get_viewport().get_visible_rect().size * 0.5
	return cam.unproject_position(gp)


func get_scrap_spin_y() -> float:
	return _scrap_spin_y


func set_scrap_hold_visible(on: bool) -> void:
	if _scrap_hold_root != null and is_instance_valid(_scrap_hold_root):
		_scrap_hold_root.visible = on


func clear_scrap_hold() -> void:
	_clear_scrap_hold()


func _ensure_scrap_hold_visual(icon: String, accent: Color) -> void:
	if _scrap_hold_root != null and is_instance_valid(_scrap_hold_root):
		_scrap_hold_root.queue_free()
		_scrap_hold_root = null
	_scrap_hold_root = Node3D.new()
	_scrap_hold_root.name = "ScrapHold"
	# Carry pozu: elde / hold point
	if _hold_point != null and is_instance_valid(_hold_point):
		_hold_point.add_child(_scrap_hold_root)
	else:
		add_child(_scrap_hold_root)

	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.32, 0.22, 0.38)
	box.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = accent.darkened(0.15)
	mat.emission_enabled = true
	mat.emission = accent
	mat.emission_energy_multiplier = 0.55
	box.material_override = mat
	_scrap_hold_root.add_child(box)

	var tape := MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3(0.34, 0.05, 0.1)
	tape.mesh = strip
	tape.position = Vector3(0, 0.02, 0)
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.78, 0.58, 0.28)
	tape.material_override = tmat
	_scrap_hold_root.add_child(tape)

	var lab := Label3D.new()
	lab.text = icon
	lab.font_size = 64
	lab.pixel_size = 0.014
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = Vector3(0, 0.28, 0)
	_scrap_hold_root.add_child(lab)


func _clear_scrap_hold() -> void:
	_scrap_holding = false
	_scrap_spinning = false
	if _scrap_hold_root != null and is_instance_valid(_scrap_hold_root):
		_scrap_hold_root.queue_free()
	_scrap_hold_root = null


func is_holding() -> bool:
	return _held != null


func get_held_prop() -> ClutterProp:
	return _held


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
