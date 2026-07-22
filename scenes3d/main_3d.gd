extends Node3D

## Ana 3D oyun — 10 seviye, tempo fazları + mikro-görevler, komedi fizik.

const ARCADE_VOID_SHADER := preload("res://shaders/arcade_tile_void_3d.gdshader")

@onready var _player: PlayerCharacter3D = $World/PlayerCharacter
@onready var _camera_rig: IsometricCameraRig = $IsometricCameraRig
@onready var _hint: Label = $UI/HintLabel
@onready var _spawner: GarageClutterSpawner = $World/GarageClutter
@onready var _floor_mesh: MeshInstance3D = $World/GarageFloor/Mesh

var _mop_label: Label
var _objective_label: Label
var _level_label: Label
var _phase_hud: Label
var _menu: Control
var _level_grid: GridContainer
var _particles: ComedyParticles
var _tempo: TempoPhaseDirector
var _micro: MicroTaskDirector
var _banner: TaskBanner
var _music: MusicDirector3D
var _stress: StressComponent
var _combo: RunCombo3D
var _ui_sfx: AudioStreamPlayer
var _stress_label: Label
var _combo_label: Label
var _commission: CommissionDirector3D
var _commission_card: CommissionCardUI
var _commission_info: Label
var _level_index: int = 0
var _highest_unlocked: int = 1
var _menu_open: bool = false
var _save_path := "user://messy3d_progress.cfg"
var _arcade_void_mat: ShaderMaterial
var _arcade_void: MeshInstance3D
@export var task_fail_stress: float = 14.0
@export var task_success_relief: float = 6.0


func _ready() -> void:
	_load_progress()
	if _camera_rig != null and _player != null:
		_camera_rig.set_follow(_player)
	_ensure_wall_colliders()
	_ensure_arcade_void()
	_setup_tempo_and_tasks()
	_setup_hud()
	_setup_menu()
	_particles = ComedyParticles.new()
	_particles.name = "ComedyParticles"
	$World.add_child(_particles)

	if _player != null:
		_player.item_disposed.connect(_on_item_disposed)
		_player.mop_dirt_changed.connect(_on_mop_dirt_changed)
		_player.rinsed.connect(_on_rinsed)
		_player.carried_changed.connect(func(_h: bool) -> void: _refresh_hint())
		_player.dance_changed.connect(_on_dance_changed)
		_player.fx_burst.connect(_on_fx_burst)
		_player.forbidden_touched.connect(_on_forbidden_touched)

	if _spawner != null:
		_spawner.spawn_on_ready = false
		_spawner.objective_changed.connect(_on_objective_changed)
		_spawner.level_cleared.connect(_on_level_cleared)
		_spawner.reinforcement_spawned.connect(_on_reinforcement_spawned)

	_show_menu(true)


func _setup_tempo_and_tasks() -> void:
	_tempo = TempoPhaseDirector.new()
	_tempo.name = "TempoPhaseDirector"
	add_child(_tempo)
	_tempo.tempo_phase_changed.connect(_on_tempo_phase_changed)
	_tempo.phase_flash.connect(_on_phase_flash)

	_micro = MicroTaskDirector.new()
	_micro.name = "MicroTaskDirector"
	add_child(_micro)
	_micro.setup(_tempo, _spawner, _player)
	_micro.task_issued.connect(_on_task_issued)
	_micro.task_succeeded.connect(_on_task_succeeded)
	_micro.task_failed.connect(_on_task_failed)
	_micro.task_cleared.connect(_on_task_cleared)

	if _spawner != null:
		_spawner.bind_tempo(_tempo)

	_music = MusicDirector3D.new()
	_music.name = "MusicDirector3D"
	add_child(_music)

	_stress = StressComponent.new()
	_stress.name = "StressComponent"
	_stress.mistake_stress = task_fail_stress
	_stress.gain_scale = 0.85
	add_child(_stress)
	_stress.stress_changed.connect(_on_stress_changed)
	_stress.stress_critical.connect(_on_stress_critical)
	_stress.stress_exploded.connect(_on_stress_exploded)

	_combo = RunCombo3D.new()
	_combo.name = "RunCombo3D"
	add_child(_combo)
	_combo.combo_changed.connect(_on_combo_changed)
	_combo.combo_milestone.connect(_on_combo_milestone)

	_banner = TaskBanner.new()
	_banner.name = "TaskBanner"
	$UI.add_child(_banner)

	_commission_card = CommissionCardUI.new()
	_commission_card.name = "CommissionCardUI"
	$UI.add_child(_commission_card)

	_commission_info = Label.new()
	_commission_info.name = "CommissionInfo"
	_commission_info.anchor_left = 0.5
	_commission_info.anchor_right = 0.5
	_commission_info.offset_left = -280.0
	_commission_info.offset_right = 280.0
	_commission_info.offset_top = 8.0
	_commission_info.offset_bottom = 40.0
	_commission_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_commission_info.add_theme_font_size_override("font_size", 20)
	$UI.add_child(_commission_info)

	_commission = CommissionDirector3D.new()
	_commission.name = "CommissionDirector3D"
	add_child(_commission)
	_commission.setup(_commission_card, _commission_info, _stress, _spawner, _player, _camera_rig)
	_commission.time_up.connect(_on_commission_time_up)

	_ui_sfx = AudioStreamPlayer.new()
	_ui_sfx.name = "UiSfx"
	_ui_sfx.bus = &"Master"
	_ui_sfx.volume_db = -4.0
	add_child(_ui_sfx)
	GameAudioBank.ensure_ready()


func _process(_delta: float) -> void:
	if _menu_open:
		return
	if _banner != null and _micro != null and _micro.has_active_task():
		_banner.set_time_ratio(_micro.get_time_ratio())
	_update_phase_progress_hud()


func _update_phase_progress_hud() -> void:
	if _phase_hud == null or _tempo == null or not _tempo.is_running():
		return
	var ratio := _tempo.get_elapsed_ratio()
	var phase := _tempo.get_phase()
	var phase_name := "Isınma"
	match phase:
		TempoPhaseDirector.PHASE_RAMP:
			phase_name = "Hızlan"
		TempoPhaseDirector.PHASE_FINALE:
			phase_name = "Son Patlama"
	_phase_hud.text = "FAZ %d · %s  (%d%%)" % [phase, phase_name, int(ratio * 100.0)]
	if _banner != null:
		if phase >= TempoPhaseDirector.PHASE_FINALE:
			_banner.set_vignette_heat(0.55 + ratio * 0.35)
		elif phase >= TempoPhaseDirector.PHASE_RAMP:
			_banner.set_vignette_heat(0.12)
		else:
			_banner.set_vignette_heat(0.0)


func _on_fx_burst(kind: StringName, world_pos: Vector3, strength: float) -> void:
	if _particles != null:
		_particles.burst(kind, world_pos, strength)


func start_level(index: int) -> void:
	_level_index = clampi(index, 0, LevelData3D.level_count() - 1)
	_show_menu(false)
	if _player != null:
		_player.global_position = Vector3(0.0, 0.9, 2.0)
		_player.velocity = Vector3.ZERO
	if _tempo != null:
		_tempo.stop_room()
	if _micro != null:
		_micro.stop_session()
	if _spawner != null:
		_spawner.stop_pressure()
	if _music != null:
		_music.stop(true)
	if _commission != null:
		_commission.clear()
	if _banner != null:
		_banner.hide_task(true)
		_banner.set_vignette_heat(0.0)

	var spec: Dictionary = {}
	if _spawner != null:
		spec = _spawner.load_level(_level_index)
	_apply_theme(spec)
	var mop_ok := bool(spec.get("allow_mop", true))
	if _player != null:
		_player.configure_for_level(mop_ok)
	if _mop_label != null:
		_mop_label.visible = mop_ok
	if _level_label != null:
		_level_label.text = String(spec.get("name", "Seviye"))
	_refresh_hint()
	if _hint != null:
		_hint.text = String(spec.get("tutorial", _hint.text))
	_on_mop_dirt_changed(_player.get_mop_dirt() if _player != null else 0.0)

	# Komisyon kartı — oyun başlamadan önce
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.PHASE, 0.95)
	if _commission != null:
		await _commission.present_for_level(spec)
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_OK, 1.05)

	# Tempo + mikro-görev seansı
	var duration := lerpf(78.0, 58.0, clampf(float(_level_index) / 9.0, 0.0, 1.0))
	if _camera_rig != null:
		_camera_rig.set_finale_zoom(false)
	if _tempo != null:
		_tempo.start_room(duration)
	if _spawner != null:
		_spawner.bind_tempo(_tempo)
		_spawner.start_pressure()
	if _micro != null:
		_micro.setup(_tempo, _spawner, _player)
		_micro.configure_for_level(_level_index)
		_micro.start_session()
	if _music != null:
		_music.start(1)
	if _stress != null:
		_stress.reset_stress()
		# HIGH_RISK multiplier komisyon apply sonrası yeniden set edilmiş olabilir
		if _commission != null:
			var c := _commission.get_current()
			if int(c.get("rule", 0)) == CommissionData.Rule.HIGH_RISK:
				_stress.mistake_multiplier = clampf(float(c.get("param", 2.0)), 1.4, 3.0)
	if _combo != null:
		_combo.reset()
	if _phase_hud != null:
		_phase_hud.text = "FAZ 1 · Isınma  (0%)"
		_phase_hud.modulate = Color(0.75, 0.9, 1.0)
	_on_stress_changed(_stress.current_stress if _stress else 0.0, _stress.max_stress if _stress else 100.0)
	_on_combo_changed(0)


func _on_commission_time_up() -> void:
	if _hint != null:
		_hint.text = "⏱ Komisyon süresi doldu — stres!"
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_FAIL, 0.8)
	if _banner != null:
		_banner.flash_fail()


func _on_tempo_phase_changed(phase: int) -> void:
	if _music != null:
		_music.set_phase(phase)
	if _phase_hud == null:
		return
	match phase:
		TempoPhaseDirector.PHASE_RAMP:
			_phase_hud.text = "FAZ 2 · Hızlan"
			_phase_hud.modulate = Color(1.0, 0.8, 0.35)
		TempoPhaseDirector.PHASE_FINALE:
			_phase_hud.text = "FAZ 3 · Son Patlama"
			_phase_hud.modulate = Color(1.0, 0.4, 0.4)
			if _camera_rig != null:
				_camera_rig.set_finale_zoom(true)
		_:
			_phase_hud.text = "FAZ 1 · Isınma"
			_phase_hud.modulate = Color(0.75, 0.9, 1.0)
			if _camera_rig != null:
				_camera_rig.set_finale_zoom(false)


func _on_phase_flash(phase: int) -> void:
	if _banner != null:
		_banner.flash_phase(phase)
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.PHASE, 1.0 + float(phase) * 0.08)
	if _camera_rig != null:
		_camera_rig.punch_fov(5.0 + float(phase) * 2.0)
		_camera_rig.shake(1.2 if phase == 2 else 2.0)
	if _particles != null and _player != null:
		_particles.burst(&"bump", _player.global_position, 1.2)
	if _hint != null:
		if phase == 2:
			_hint.text = "⚡ HIZLAN — ekstra kir geliyor!"
		elif phase == 3:
			_hint.text = "🔥 SON PATLAMA — baskı maksimum!"


func _on_reinforcement_spawned(count: int) -> void:
	if count <= 0:
		return
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.PHASE, 0.8)
	if _particles != null and _player != null:
		_particles.burst(&"throw", _player.global_position + Vector3(0, 0.5, 0), 0.9)
	if _hint != null:
		_hint.text = "Yeni kir düştü! (+%d)" % count


func _on_task_issued(task_type: String, duration: float, color: Color) -> void:
	var label := "AT!"
	var sub := "İşaretli kutuyu çöpe at!"
	match task_type:
		MicroTaskDirector.TASK_SCRUB:
			label = "SİL!"
			sub = "İşaretli lekeye sol tık / Space spam!"
		MicroTaskDirector.TASK_GATHER:
			label = "TOPLA!"
			sub = "İşaretli kutuları hızlıca çöpe!"
		MicroTaskDirector.TASK_CHOOSE:
			label = "SEÇ!"
			sub = "★ yıldızlıyı at — ✕ olanı atma!"
		MicroTaskDirector.TASK_DOUBLE:
			label = "ÇİFTE!"
			sub = "Kutu AT + leke SİL — ikisini bitir!"
		MicroTaskDirector.TASK_DODGE:
			label = "KAÇ!"
			sub = "Kırmızı bölgeden DIŞARI çık!"
		MicroTaskDirector.TASK_STOP:
			label = "DUR!"
			sub = "Hiçbir şeye DOKUNMA!"
		MicroTaskDirector.TASK_ALL:
			label = "HEPSİNİ AT!"
			sub = "İşaretli kutuların hepsini çöpe!"
		MicroTaskDirector.TASK_LAST:
			label = "SON KUTU!"
			sub = "En uzaktaki yıldızlı kutuyu at!"
		_:
			label = "AT!"
			sub = "İşaretli kutuyu çöpe at!"
	var special := "stop" if task_type == MicroTaskDirector.TASK_STOP else ""
	if _banner != null:
		_banner.show_task(label, color, sub, special)
	if task_type == MicroTaskDirector.TASK_STOP:
		PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.STOP, 0.9)
	else:
		PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK)
	if _hint != null:
		_hint.text = "Emir: %s  (%.0fs)" % [label, duration]


func _on_task_succeeded(_task_type: String) -> void:
	if _banner != null:
		_banner.hide_task(true)
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_OK, 1.1)
	if _combo != null:
		_combo.register_success()
	if _stress != null:
		_stress.reduce_stress(task_success_relief)
	if _particles != null and _player != null:
		_particles.burst(&"dispose", _player.global_position + Vector3(0, 1, 0), 1.1)
	if _hint != null:
		_hint.text = "Emir tamam! ★  combo x%d" % (_combo.get_combo() if _combo else 0)


func _on_task_failed(_task_type: String) -> void:
	if _banner != null:
		_banner.flash_fail()
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_FAIL, 0.85)
	await get_tree().create_timer(0.08).timeout
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.BUMP, 0.65)
	if _combo != null:
		_combo.register_fail()
	if _stress != null:
		_stress.register_mistake()
	if _camera_rig != null:
		_camera_rig.punch_fov(10.0)
		_camera_rig.shake(2.4)
	if _player != null:
		_player.play_task_fail_recoil()
	if _particles != null and _player != null:
		_particles.burst(&"bump", _player.global_position + Vector3(0, 0.7, 0), 2.0)
		_particles.burst(&"hit", _player.global_position + Vector3(0.4, 1.0, 0), 1.4)
	if _hint != null:
		_hint.text = "💥 EMİR KAÇTI — stres + combo kırıldı!"
	if _objective_label != null:
		_objective_label.modulate = Color(1.0, 0.35, 0.35)
		await get_tree().create_timer(0.7).timeout
		if _objective_label != null:
			_objective_label.modulate = Color(0.9, 0.92, 1.0)


func _on_stress_changed(current: float, maximum: float) -> void:
	if _stress_label == null:
		return
	var pct := int((current / maxf(maximum, 1.0)) * 100.0)
	_stress_label.text = "STRES: %d%%" % pct
	_stress_label.modulate = Color(1.0, lerpf(1.0, 0.35, current / maximum), lerpf(1.0, 0.35, current / maximum))


func _on_stress_critical() -> void:
	if _camera_rig != null:
		_camera_rig.shake(1.8)
		_camera_rig.punch_fov(7.0)
	if _hint != null:
		_hint.text = "⚠️ STRES KRİTİK!"
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_FAIL, 0.75)


func _on_stress_exploded() -> void:
	if _camera_rig != null:
		_camera_rig.shake(3.0)
	if _banner != null:
		_banner.flash_fail()
	if _hint != null:
		_hint.text = "🤯 STRES PATLADI — nefes al!"
	if _stress != null:
		# 3D'de oyun bitsin diye değil — sert ceza + reset
		await get_tree().create_timer(1.0).timeout
		_stress.reset_stress()
		_stress.add_stress(35.0)


func _on_combo_changed(combo: int) -> void:
	if _combo_label == null:
		return
	_combo_label.text = "COMBO x%d" % combo
	_combo_label.modulate = Color(1.0, 0.9, 0.4) if combo > 0 else Color(0.6, 0.65, 0.7)


func _on_combo_milestone(combo: int) -> void:
	if _hint != null:
		_hint.text = "🔥 Combo x%d — tempo yüksek!" % combo
	if _particles != null and _player != null:
		_particles.burst(&"dance", _player.global_position, 1.3)
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_OK, 1.25)


func _on_task_cleared() -> void:
	pass


func _apply_theme(spec: Dictionary) -> void:
	var floor_c: Color = spec.get("floor", Color(0.34, 0.36, 0.38)) as Color
	var wall_c: Color = spec.get("wall", Color(0.5, 0.5, 0.5)) as Color
	if _floor_mesh != null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = floor_c
		mat.roughness = 0.92
		_floor_mesh.material_override = mat
		_floor_mesh.set_surface_override_material(0, null)
	_apply_arcade_void(floor_c, spec.get("accent", Color(0.7, 0.5, 0.3)) as Color)
	for wall_name in ["WallBack", "WallLeft"]:
		var wall: MeshInstance3D = $World.get_node_or_null(wall_name) as MeshInstance3D
		if wall == null:
			continue
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = wall_c
		wmat.roughness = 0.9
		wall.material_override = wmat


func _ensure_arcade_void() -> void:
	if _arcade_void != null and is_instance_valid(_arcade_void):
		return
	_arcade_void = MeshInstance3D.new()
	_arcade_void.name = "ArcadeTileVoid"
	var sphere := SphereMesh.new()
	sphere.radius = 48.0
	sphere.height = 96.0
	sphere.radial_segments = 48
	sphere.rings = 24
	_arcade_void.mesh = sphere
	_arcade_void.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arcade_void.position = Vector3(0.0, 8.0, 0.0)
	add_child(_arcade_void)
	_arcade_void_mat = ShaderMaterial.new()
	_arcade_void_mat.shader = ARCADE_VOID_SHADER
	_arcade_void.material_override = _arcade_void_mat


func _pastelize(c: Color, lift: float = 0.2) -> Color:
	## Canlı ama aşırı neon olmayan ton — map başına sonra customize edilir.
	var out := c.lightened(lift)
	out.s = clampf(out.s * 1.15, 0.28, 0.85)
	out.v = clampf(out.v, 0.42, 0.88)
	return out


func _apply_arcade_void(theme: Color, accent_fallback: Color) -> void:
	_ensure_arcade_void()
	if _arcade_void_mat == null:
		return
	var pal: Dictionary = LevelData.arcade_palette(theme)
	var a := _pastelize(pal.get("color_a", theme) as Color, 0.12)
	var b := _pastelize(pal.get("color_b", theme.lightened(0.2)) as Color, 0.18)
	var accent := _pastelize(pal.get("color_accent", accent_fallback) as Color, 0.05)
	# Karolar arasında net renk farkı
	b = a.lerp(b, 0.85).lightened(0.06)
	accent.s = clampf(accent.s * 1.25, 0.4, 0.95)
	_arcade_void_mat.set_shader_parameter("color_a", a)
	_arcade_void_mat.set_shader_parameter("color_b", b)
	_arcade_void_mat.set_shader_parameter("color_accent", accent)
	_arcade_void_mat.set_shader_parameter("tile_world_size", 2.6)
	_arcade_void_mat.set_shader_parameter("scroll_speed", float(pal.get("scroll_speed", 0.11)) * 0.75)
	_arcade_void_mat.set_shader_parameter("diagonal_angle", 0.785398)
	_arcade_void_mat.set_shader_parameter("pulse_amount", 0.03)
	_arcade_void_mat.set_shader_parameter("accent_chance", float(pal.get("accent_chance", 0.08)) * 1.35)
	_arcade_void_mat.set_shader_parameter("vignette", 0.28)


func _on_objective_changed(remaining: int, total: int) -> void:
	if _objective_label == null:
		return
	if remaining <= 0:
		_objective_label.text = "✓ ODA TEMİZ!"
		_objective_label.modulate = Color(0.5, 1.0, 0.6)
	else:
		_objective_label.text = "HEDEF: %d / %d temizlendi" % [total - remaining, total]
		_objective_label.modulate = Color(0.9, 0.92, 1.0)


func _on_level_cleared() -> void:
	if _tempo != null:
		_tempo.stop_room()
	if _micro != null:
		_micro.stop_session()
	if _spawner != null:
		_spawner.stop_pressure()
	if _music != null:
		_music.stop(true)
	if _commission != null:
		_commission.clear()
	if _stress != null:
		_stress.reset_stress()
	if _combo != null:
		_combo.reset()
	if _banner != null:
		_banner.hide_task(true)
		_banner.set_vignette_heat(0.0)
	if _camera_rig != null:
		_camera_rig.set_finale_zoom(false)
	var next := _level_index + 1
	if next + 1 > _highest_unlocked and next < LevelData3D.level_count():
		_highest_unlocked = next + 1
		_save_progress()
	if _hint != null:
		_hint.text = "🎉 Seviye bitti! Space veya Esc → menü"
	if _objective_label != null:
		_objective_label.text = "✓ SEVİYE TEMİZ — Esc menü"
	await get_tree().create_timer(1.4).timeout
	if next < LevelData3D.level_count():
		start_level(next)
	else:
		if _hint != null:
			_hint.text = "🏆 10/10 tamam! Dans et (G) · Esc menü"
		_highest_unlocked = LevelData3D.level_count()
		_save_progress()


func _ensure_wall_colliders() -> void:
	var world: Node3D = $World as Node3D
	if world == null:
		return
	# Görünür duvarlar: Back + Left. Açık kenarlar: Front + Right → görünmez duvar.
	_add_wall_body(world, "WallColliderBack", Vector3(0, 1.5, -5.2), Vector3(14.5, 3.2, 0.45), false)
	_add_wall_body(world, "WallColliderLeft", Vector3(-7.2, 1.5, 0), Vector3(0.45, 3.2, 10.5), false)
	_add_wall_body(world, "WallColliderRight", Vector3(7.2, 1.5, 0), Vector3(0.45, 3.2, 10.5), true)
	_add_wall_body(world, "WallColliderFront", Vector3(0, 1.5, 5.2), Vector3(14.5, 3.2, 0.45), true)


func _add_wall_body(parent: Node3D, wall_name: String, pos: Vector3, size: Vector3, invisible_visual: bool) -> void:
	if parent.get_node_or_null(wall_name) != null:
		return
	var body := StaticBody3D.new()
	body.name = wall_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if invisible_visual:
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "InvisibleMesh"
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_inst.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.7, 0.85, 1.0, 0.0)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_inst.material_override = mat
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mesh_inst)


func _setup_hud() -> void:
	var ui: CanvasLayer = $UI as CanvasLayer
	_mop_label = Label.new()
	_mop_label.offset_left = 24.0
	_mop_label.offset_top = 52.0
	_mop_label.offset_right = 480.0
	_mop_label.offset_bottom = 82.0
	_mop_label.add_theme_font_size_override("font_size", 18)
	ui.add_child(_mop_label)

	_objective_label = Label.new()
	_objective_label.offset_left = 24.0
	_objective_label.offset_top = 84.0
	_objective_label.offset_right = 520.0
	_objective_label.offset_bottom = 114.0
	_objective_label.add_theme_font_size_override("font_size", 20)
	ui.add_child(_objective_label)

	_level_label = Label.new()
	_level_label.anchor_left = 1.0
	_level_label.anchor_right = 1.0
	_level_label.offset_left = -520.0
	_level_label.offset_right = -24.0
	_level_label.offset_top = 18.0
	_level_label.offset_bottom = 52.0
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_level_label.add_theme_font_size_override("font_size", 22)
	_level_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	ui.add_child(_level_label)

	_phase_hud = Label.new()
	_phase_hud.anchor_left = 1.0
	_phase_hud.anchor_right = 1.0
	_phase_hud.offset_left = -420.0
	_phase_hud.offset_right = -24.0
	_phase_hud.offset_top = 56.0
	_phase_hud.offset_bottom = 88.0
	_phase_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_phase_hud.add_theme_font_size_override("font_size", 18)
	_phase_hud.text = "FAZ 1 · Isınma"
	ui.add_child(_phase_hud)

	_stress_label = Label.new()
	_stress_label.offset_left = 24.0
	_stress_label.offset_top = 116.0
	_stress_label.offset_right = 320.0
	_stress_label.offset_bottom = 144.0
	_stress_label.add_theme_font_size_override("font_size", 18)
	_stress_label.text = "STRES: 0%"
	ui.add_child(_stress_label)

	_combo_label = Label.new()
	_combo_label.offset_left = 24.0
	_combo_label.offset_top = 144.0
	_combo_label.offset_right = 320.0
	_combo_label.offset_bottom = 172.0
	_combo_label.add_theme_font_size_override("font_size", 18)
	_combo_label.text = "COMBO x0"
	_combo_label.modulate = Color(0.6, 0.65, 0.7)
	ui.add_child(_combo_label)


func _setup_menu() -> void:
	_menu = Control.new()
	_menu.name = "LevelMenu"
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.visible = false
	$UI.add_child(_menu)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.1, 0.12, 0.92)
	_menu.add_child(bg)

	var title := Label.new()
	title.text = "MESSY JANITOR · 3D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_right = 1.0
	title.offset_top = 48.0
	title.offset_bottom = 110.0
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	_menu.add_child(title)

	var sub := Label.new()
	sub.text = "2D level design → komedi fizik  ·  10 seviye"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_right = 1.0
	sub.offset_top = 110.0
	sub.offset_bottom = 150.0
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	_menu.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.5
	scroll.anchor_right = 0.5
	scroll.anchor_top = 0.5
	scroll.anchor_bottom = 0.5
	scroll.offset_left = -420.0
	scroll.offset_right = 420.0
	scroll.offset_top = -220.0
	scroll.offset_bottom = 260.0
	_menu.add_child(scroll)

	_level_grid = GridContainer.new()
	_level_grid.columns = 2
	_level_grid.add_theme_constant_override("h_separation", 14)
	_level_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_level_grid)
	_rebuild_level_buttons()


func _rebuild_level_buttons() -> void:
	for c in _level_grid.get_children():
		c.queue_free()
	for i in LevelData3D.level_count():
		var info: Dictionary = LevelData3D.get_level(i)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(400, 72)
		btn.focus_mode = Control.FOCUS_NONE
		var unlocked := (i + 1) <= _highest_unlocked
		btn.disabled = not unlocked
		if unlocked:
			btn.text = "%s\n%s" % [String(info.get("name", "")), String(info.get("subtitle", ""))]
			var idx := i
			btn.pressed.connect(func() -> void: start_level(idx))
		else:
			btn.text = "🔒  %s" % String(info.get("name", ""))
		_level_grid.add_child(btn)


func _show_menu(open: bool) -> void:
	_menu_open = open
	if open:
		if _tempo != null:
			_tempo.stop_room()
		if _micro != null:
			_micro.stop_session()
		if _spawner != null:
			_spawner.stop_pressure()
		if _music != null:
			_music.stop(true)
		if _commission != null:
			_commission.clear()
		if _banner != null:
			_banner.hide_task(true)
			_banner.set_vignette_heat(0.0)
		if _camera_rig != null:
			_camera_rig.set_finale_zoom(false)
	if _menu != null:
		_menu.visible = open
		if open:
			_rebuild_level_buttons()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _refresh_hint() -> void:
	if _hint == null or _menu_open:
		return
	if _player != null and _player.is_holding():
		_hint.text = "Kutu elde · başka kutuya Space = stack · çöpe Space = at (max 5)"
	else:
		_hint.text = "WASD · Shift dash · G dans · Space tut/fırlat · Esc menü"


func _on_dance_changed(dancing: bool) -> void:
	if _hint == null:
		return
	_hint.text = "💃 DANS — duvara çarp, partikül yağsın!" if dancing else "Dans bitti · Esc menü"


func _on_mop_dirt_changed(ratio: float) -> void:
	if _mop_label == null:
		return
	var pct := int(ratio * 100.0)
	_mop_label.text = "Paspas kiri: %d%%  %s" % [pct, "→ kovada basılı tut" if pct > 0 else ""]
	_mop_label.modulate = Color(1.0, lerpf(1.0, 0.55, ratio), lerpf(1.0, 0.4, ratio))


func _on_rinsed() -> void:
	if _hint != null:
		_hint.text = "Paspas temiz!"


func _on_forbidden_touched() -> void:
	if _commission != null:
		_commission.notify_forbidden_touched()
	if _hint != null:
		_hint.text = "⛔ Yasak! Ona dokunma!"
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.STOP, 0.9)


func _on_item_disposed(_prop_id: String) -> void:
	if _hint != null:
		_hint.text = "Atıldı!  ·  devam"
	if _spawner != null:
		_spawner.call_deferred("_emit_objective_state")
	_refresh_hint()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_show_menu(not _menu_open)
		get_viewport().set_input_as_handled()


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_save_path) == OK:
		_highest_unlocked = int(cfg.get_value("progress", "unlocked", 1))
	_highest_unlocked = clampi(_highest_unlocked, 1, LevelData3D.level_count())


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", _highest_unlocked)
	cfg.save(_save_path)
