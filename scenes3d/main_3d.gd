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
var _heat_bar: ProgressBar
var _heat_fill_style: StyleBoxFlat
var _commission: CommissionDirector3D
var _commission_card: CommissionCardUI
var _commission_info: Label
var _hazards: HazardDirector
var _curses: CurseDirector3D
var _curse_label: Label
var _hard_mode_btn: Button
var _diff_btn: Button
var _difficulty: int = DifficultyProfile3D.Tier.NORMAL
var _score: ScoreTracker3D
var _score_label: Label
var _result_ui: RunResultUI
var _daily_mode: bool = false
var _pending_next_level: int = -1
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
	_stress.decay_per_second = 12.0
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

	_hazards = HazardDirector.new()
	_hazards.name = "HazardDirector"
	add_child(_hazards)
	_hazards.setup(_player, _stress, _spawner, $World as Node3D, _tempo)
	_hazards.fall_impact.connect(_on_hazard_fall_impact)
	_hazards.slippery_spawned.connect(_on_hazard_slippery)
	_hazards.furniture_shifted.connect(_on_hazard_furniture)
	if _player != null:
		_player.floor_scrubbed.connect(_on_floor_scrubbed)

	_curses = CurseDirector3D.new()
	_curses.name = "CurseDirector3D"
	add_child(_curses)
	_curses.roll_daily()
	_curses.curses_rolled.connect(func(_c: Array) -> void: _refresh_curse_hud())

	_score = ScoreTracker3D.new()
	_score.name = "ScoreTracker3D"
	add_child(_score)
	_score.score_changed.connect(_on_score_changed)

	_result_ui = RunResultUI.new()
	_result_ui.name = "RunResultUI"
	$UI.add_child(_result_ui)
	_result_ui.closed.connect(_on_result_closed)

	_curse_label = Label.new()
	_curse_label.name = "CurseLabel"
	_curse_label.anchor_left = 1.0
	_curse_label.anchor_right = 1.0
	_curse_label.offset_left = -420.0
	_curse_label.offset_right = -24.0
	_curse_label.offset_top = 92.0
	_curse_label.offset_bottom = 140.0
	_curse_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_curse_label.add_theme_font_size_override("font_size", 16)
	_curse_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	_curse_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$UI.add_child(_curse_label)
	_refresh_curse_hud()

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
	if _music != null and _tempo != null and _tempo.is_running():
		_music.set_intensity(_tempo.get_elapsed_ratio())


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
	# Vignette heat bar / stres üzerinden güncellenir (_on_stress_changed)


func _on_fx_burst(kind: StringName, world_pos: Vector3, strength: float) -> void:
	if _particles != null:
		_particles.burst(kind, world_pos, strength)
	# Başarı micro-shake (fail ~2.4 ile karışmasın)
	if _camera_rig != null and (kind == &"dispose" or kind == &"clean"):
		_camera_rig.shake(clampf(0.35 + strength * 0.22, 0.35, 0.7))


func _spawn_pop(text: String, color: Color = Color(1.0, 0.92, 0.45), font_px: int = 64) -> void:
	if _player == null:
		return
	var host: Node = $World if has_node("World") else self
	FloatingPop3D.spawn(host, _player.global_position, text, color, font_px)


func start_level(index: int, daily: bool = false) -> void:
	_daily_mode = daily
	_pending_next_level = -1
	_level_index = clampi(index, 0, LevelData3D.level_count() - 1)
	_show_menu(false)
	if _player != null:
		_player.global_position = Vector3(0.0, 0.9, 2.0)
		_player.velocity = Vector3.ZERO
	if _tempo != null:
		_tempo.stop_room()
	if _micro != null:
		_micro.stop_session()
	if _hazards != null:
		_hazards.stop_session()
	if _curses != null:
		_curses.revert_defaults(_stress, _player, _micro, _hazards)
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
	var is_boss := bool(spec.get("is_boss_room", false))
	var boss_mode := String(spec.get("boss_mode", ""))
	var duration := lerpf(62.0, 48.0, clampf(float(_level_index) / 9.0, 0.0, 1.0))
	if is_boss:
		duration = lerpf(55.0, 70.0, clampf(float(_level_index) / 9.0, 0.0, 1.0))
	if _camera_rig != null:
		_camera_rig.set_finale_zoom(is_boss)
	if _tempo != null:
		if is_boss:
			_tempo.start_boss_room(duration)
		else:
			_tempo.start_room(duration)
	if _spawner != null:
		_spawner.bind_tempo(_tempo)
		_spawner.start_pressure(boss_mode if is_boss else "")
	if _micro != null:
		_micro.setup(_tempo, _spawner, _player)
		_micro.configure_for_level(_level_index)
		if is_boss:
			_micro.configure_boss_mode(boss_mode)
		_micro.start_session()
	if _hazards != null:
		_hazards.setup(_player, _stress, _spawner, $World as Node3D, _tempo)
		_hazards.start_session(_level_index, mop_ok)
	# Günlük lanet — level/boss ayarlarından sonra uygula
	if _curses != null:
		if not _curses.has_curses():
			_curses.roll_daily()
		_curses.apply_to(_stress, _player, _micro, _hazards)
		_refresh_curse_hud()
	_apply_difficulty_profile()
	if _music != null:
		_music.start(3 if is_boss else 1)
	if _stress != null:
		_stress.reset_stress()
		if _commission != null:
			var c := _commission.get_current()
			if int(c.get("rule", 0)) == CommissionData.Rule.HIGH_RISK:
				_stress.mistake_multiplier = clampf(float(c.get("param", 2.0)), 1.4, 3.0)
	if _combo != null:
		_combo.reset()
	if _phase_hud != null:
		if is_boss:
			_phase_hud.text = "BOSS · Son Patlama"
			_phase_hud.modulate = Color(1.0, 0.35, 0.4)
		else:
			_phase_hud.text = "FAZ 1 · Isınma  (0%)"
			_phase_hud.modulate = Color(0.75, 0.9, 1.0)
	_on_stress_changed(_stress.current_stress if _stress else 0.0, _stress.max_stress if _stress else 100.0)
	_on_combo_changed(0)
	if _score != null:
		_score.begin_level()
		_on_score_changed(0)
	if is_boss:
		_flash_boss_intro(String(spec.get("boss_title", "SET-PIECE")))
	if _daily_mode and _hint != null:
		_hint.text = "📅 Günlük meydan okuma — kendini geç!"


func _start_daily_challenge() -> void:
	var lv := DailyChallenge3D.todays_level_index(LevelData3D.level_count())
	# Kilidi açılmış olmalı; değilse en yüksek açık seviyeyi kullan
	if lv + 1 > _highest_unlocked:
		lv = clampi(_highest_unlocked - 1, 0, LevelData3D.level_count() - 1)
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.PHASE, 1.1)
	start_level(lv, true)


func _flash_boss_intro(title: String) -> void:
	if _banner != null:
		_banner.flash_boss(title)
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.PHASE, 1.2)
	if _camera_rig != null:
		_camera_rig.punch_fov(8.0)
		_camera_rig.shake(1.8)
	if _hint != null:
		_hint.text = "%s — ısınma yok, direkt kaos!" % title
	if _particles != null and _player != null:
		_particles.burst(&"bump", _player.global_position, 1.6)


func _on_commission_time_up() -> void:
	if _hint != null:
		_hint.text = "⏱ Komisyon süresi doldu — stres!"
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_FAIL, 0.8)
	if _banner != null:
		_banner.flash_fail()
	if _music != null and _stress != null:
		_music.on_mistake(_stress.get_stress_ratio())


func _on_tempo_phase_changed(phase: int) -> void:
	if _music != null:
		_music.set_phase(phase, true)
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
	# Şekil öneki — renk körü dostu (sadece renge güvenme)
	var label := "▲ AT!"
	var sub := "İşaretli kutuyu çöpe at!"
	match task_type:
		MicroTaskDirector.TASK_SCRUB:
			label = "● SİL!"
			sub = "İşaretli lekeye sol tık / Space spam!"
		MicroTaskDirector.TASK_GATHER:
			label = "■ TOPLA!"
			sub = "İşaretli kutuları hızlıca çöpe!"
		MicroTaskDirector.TASK_CHOOSE:
			label = "◆ SEÇ!"
			sub = "★ yıldızlıyı at — ✕ olanı atma!"
		MicroTaskDirector.TASK_DOUBLE:
			label = "✚ ÇİFTE!"
			sub = "Kutu AT + leke SİL — ikisini bitir!"
		MicroTaskDirector.TASK_DODGE:
			label = "◇ KAÇ!"
			sub = "Kırmızı bölgeden DIŞARI çık!"
		MicroTaskDirector.TASK_STOP:
			label = "✕ DUR!"
			sub = "Hiçbir şeye DOKUNMA!"
		MicroTaskDirector.TASK_ALL:
			label = "▣ HEPSİNİ AT!"
			sub = "İşaretli kutuların hepsini çöpe!"
		MicroTaskDirector.TASK_LAST:
			label = "★ SON KUTU!"
			sub = "En uzaktaki yıldızlı kutuyu at!"
		_:
			label = "▲ AT!"
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
	var combo_n := _combo.get_combo() if _combo else 0
	if _score != null:
		_score.on_task_ok(combo_n)
	if _stress != null:
		_stress.reduce_stress(task_success_relief)
	if _music != null:
		_music.pulse_upbeat(0.05 + 0.01 * float(combo_n))
	if _particles != null and _player != null:
		_particles.burst(&"clean", _player.global_position + Vector3(0, 1, 0), 1.1)
	if _camera_rig != null:
		_camera_rig.shake(0.55)
	_spawn_pop("+%d" % (80 + mini(combo_n, 8) * 12), Color(0.55, 1.0, 0.7), 72)
	if _hint != null:
		_hint.text = "Emir tamam! ★  combo x%d" % combo_n


func _on_task_failed(_task_type: String) -> void:
	if _banner != null:
		_banner.flash_fail()
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_FAIL, 0.85)
	await get_tree().create_timer(0.08).timeout
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.BUMP, 0.65)
	if _combo != null:
		_combo.register_fail()
	if _score != null:
		_score.on_task_fail()
	if _stress != null:
		_stress.register_mistake()
	if _music != null and _stress != null:
		_music.on_mistake(_stress.get_stress_ratio())
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
	var ratio := current / maxf(maximum, 1.0)
	if _stress_label != null:
		var pct := int(ratio * 100.0)
		_stress_label.text = "HEAT: %d%%" % pct
		_stress_label.modulate = Color(1.0, lerpf(1.0, 0.35, ratio), lerpf(1.0, 0.35, ratio))
	if _heat_bar != null:
		_heat_bar.value = ratio * 100.0
		if _heat_fill_style != null:
			_heat_fill_style.bg_color = Color(1.0, lerpf(0.75, 0.15, ratio), lerpf(0.25, 0.1, ratio))
	if _music != null:
		_music.set_heat(ratio)
	if _banner != null and _tempo != null and _tempo.is_running():
		# Faz vignette + heat birleşimi
		var phase_heat := 0.0
		var phase := _tempo.get_phase()
		if phase >= TempoPhaseDirector.PHASE_FINALE:
			phase_heat = 0.35
		elif phase >= TempoPhaseDirector.PHASE_RAMP:
			phase_heat = 0.1
		_banner.set_vignette_heat(maxi(phase_heat, ratio * 0.85))


func _on_forbidden_touched() -> void:
	if _commission != null:
		_commission.notify_forbidden_touched()
	if _score != null:
		_score.on_mistake()
	if _music != null and _stress != null:
		_music.on_mistake(_stress.get_stress_ratio())
	if _hint != null:
		_hint.text = "⛔ Yasak! Ona dokunma!"
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.STOP, 0.9)

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
	if _score != null and combo > 0:
		_score.on_combo(combo)


func _on_score_changed(score: int) -> void:
	if _score_label != null:
		_score_label.text = "SKOR: %d" % score
		if _daily_mode:
			_score_label.text = "📅 SKOR: %d" % score


func _on_combo_milestone(combo: int) -> void:
	if _hint != null:
		_hint.text = "🔥 Combo x%d — tempo yüksek!" % combo
	if _particles != null and _player != null:
		_particles.burst(&"dance", _player.global_position, 1.3)
	if _camera_rig != null:
		_camera_rig.shake(0.5)
	_spawn_pop("COMBO x%d" % combo, Color(1.0, 0.75, 0.35), 80)
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_OK, 1.25)


func _on_task_cleared() -> void:
	pass


func _apply_theme(spec: Dictionary) -> void:
	var floor_c: Color = spec.get("floor", Color(0.34, 0.36, 0.38)) as Color
	var wall_c: Color = spec.get("wall", Color(0.5, 0.5, 0.5)) as Color
	if _floor_mesh != null:
		_floor_mesh.material_override = HitWobbleMaterial.create_flat(floor_c, 0.94, 0.08)
		_floor_mesh.set_surface_override_material(0, null)
	_apply_arcade_void(floor_c, spec.get("accent", Color(0.7, 0.5, 0.3)) as Color)
	for wall_name in ["WallBack", "WallLeft"]:
		var wall: MeshInstance3D = $World.get_node_or_null(wall_name) as MeshInstance3D
		if wall == null:
			continue
		# Duvar: ince outline — oda silueti
		wall.material_override = HitWobbleMaterial.create(
			wall_c, 0.9, Color.BLACK, 0.0, 0.0, true, 0.02
		)


func _ensure_arcade_void() -> void:
	var void_size := Vector3(90.0, 70.0, 90.0)
	# Sadece duvarlar — zemin/tavan yok
	var mesh := BeveledBoxMesh.create_walls(void_size, 0.28, 16)
	if _arcade_void != null and is_instance_valid(_arcade_void):
		_arcade_void.mesh = mesh
		_arcade_void.position = Vector3(0.0, 12.0, 0.0)
		if _arcade_void_mat == null:
			_arcade_void_mat = _arcade_void.material_override as ShaderMaterial
		return
	_arcade_void = MeshInstance3D.new()
	_arcade_void.name = "ArcadeTileVoid"
	_arcade_void.mesh = mesh
	_arcade_void.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arcade_void.position = Vector3(0.0, 12.0, 0.0)
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


## Arka plan void — pastel değil; doygun + parlak arcade.
func _vividize(c: Color, sat_mul: float = 1.55, val_lift: float = 0.12) -> Color:
	var out := c
	out.s = clampf(out.s * sat_mul, 0.45, 1.0)
	out.v = clampf(out.v + val_lift, 0.38, 0.98)
	return out


func _apply_arcade_void(theme: Color, accent_fallback: Color) -> void:
	_ensure_arcade_void()
	if _arcade_void_mat == null:
		return
	var pal: Dictionary = LevelData.arcade_palette(theme)
	var a := _vividize(pal.get("color_a", theme) as Color, 1.65, 0.18)
	var b := _vividize(pal.get("color_b", theme.lightened(0.15)) as Color, 1.7, 0.28)
	var accent := _vividize(pal.get("color_accent", accent_fallback) as Color, 1.45, 0.2)
	# Karolar arası net fark — pastel yıkama yok
	b = a.lerp(b, 0.92)
	b.v = clampf(b.v + 0.08, 0.45, 1.0)
	accent.s = clampf(accent.s * 1.2, 0.55, 1.0)
	accent.v = clampf(accent.v + 0.05, 0.55, 1.0)
	_arcade_void_mat.set_shader_parameter("color_a", a)
	_arcade_void_mat.set_shader_parameter("color_b", b)
	_arcade_void_mat.set_shader_parameter("color_accent", accent)
	_arcade_void_mat.set_shader_parameter("tile_world_size", 2.6)
	_arcade_void_mat.set_shader_parameter("scroll_speed", float(pal.get("scroll_speed", 0.11)) * 1.35)
	_arcade_void_mat.set_shader_parameter("diagonal_angle", 0.785398)
	_arcade_void_mat.set_shader_parameter("pulse_amount", 0.018)
	_arcade_void_mat.set_shader_parameter("accent_chance", float(pal.get("accent_chance", 0.08)) * 1.1)


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
	if _hazards != null:
		_hazards.stop_session()
	if _curses != null:
		_curses.revert_defaults(_stress, _player, _micro, _hazards)
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

	# Skor sonucu — kendini geçtin mi?
	var stress_r := _stress.get_stress_ratio() if _stress else 0.0
	var result: Dictionary = {}
	if _score != null:
		result = _score.finalize(stress_r, _daily_mode, _level_index)
	var compare := DailyChallenge3D.save_result(_level_index, int(result.get("score", 0)), _daily_mode)

	var next := _level_index + 1
	if next + 1 > _highest_unlocked and next < LevelData3D.level_count() and not _daily_mode:
		_highest_unlocked = next + 1
		_save_progress()
	if _daily_mode:
		_pending_next_level = -1 # menüye
	elif next < LevelData3D.level_count():
		_pending_next_level = next
	else:
		_pending_next_level = -1
		_highest_unlocked = LevelData3D.level_count()
		_save_progress()

	if _stress != null:
		_stress.reset_stress()
	if _combo != null:
		_combo.reset()

	if _result_ui != null:
		_result_ui.present(result, compare, _daily_mode)
		if _particles != null and _player != null:
			_particles.burst(&"clean", _player.global_position + Vector3(0, 1.2, 0), 1.4)
			_particles.burst(&"dispose", _player.global_position + Vector3(0.3, 1.0, 0), 1.0)
		if _camera_rig != null:
			_camera_rig.shake(0.6)
	else:
		_on_result_closed()


func _on_result_closed() -> void:
	var was_daily := _daily_mode
	_daily_mode = false
	if was_daily or _pending_next_level < 0:
		_show_menu(true)
		return
	start_level(_pending_next_level, false)


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
	_stress_label.offset_bottom = 140.0
	_stress_label.add_theme_font_size_override("font_size", 18)
	_stress_label.text = "HEAT: 0%"
	ui.add_child(_stress_label)

	_heat_bar = ProgressBar.new()
	_heat_bar.offset_left = 24.0
	_heat_bar.offset_top = 142.0
	_heat_bar.offset_right = 280.0
	_heat_bar.offset_bottom = 162.0
	_heat_bar.min_value = 0.0
	_heat_bar.max_value = 100.0
	_heat_bar.value = 0.0
	_heat_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.1, 0.12, 0.85)
	bg.set_corner_radius_all(4)
	_heat_bar.add_theme_stylebox_override("background", bg)
	_heat_fill_style = StyleBoxFlat.new()
	_heat_fill_style.bg_color = Color(1.0, 0.55, 0.2)
	_heat_fill_style.set_corner_radius_all(4)
	_heat_bar.add_theme_stylebox_override("fill", _heat_fill_style)
	ui.add_child(_heat_bar)

	_combo_label = Label.new()
	_combo_label.offset_left = 24.0
	_combo_label.offset_top = 168.0
	_combo_label.offset_right = 320.0
	_combo_label.offset_bottom = 196.0
	_combo_label.add_theme_font_size_override("font_size", 18)
	_combo_label.text = "COMBO x0"
	_combo_label.modulate = Color(0.6, 0.65, 0.7)
	ui.add_child(_combo_label)

	_score_label = Label.new()
	_score_label.offset_left = 24.0
	_score_label.offset_top = 200.0
	_score_label.offset_right = 320.0
	_score_label.offset_bottom = 228.0
	_score_label.add_theme_font_size_override("font_size", 18)
	_score_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_score_label.text = "SKOR: 0"
	ui.add_child(_score_label)


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

	_hard_mode_btn = Button.new()
	_hard_mode_btn.focus_mode = Control.FOCUS_NONE
	_hard_mode_btn.anchor_left = 0.5
	_hard_mode_btn.anchor_right = 0.5
	_hard_mode_btn.offset_left = -200.0
	_hard_mode_btn.offset_right = 200.0
	_hard_mode_btn.offset_top = 152.0
	_hard_mode_btn.offset_bottom = 196.0
	_hard_mode_btn.pressed.connect(_toggle_hard_mode)
	_menu.add_child(_hard_mode_btn)
	_update_hard_mode_btn()

	_diff_btn = Button.new()
	_diff_btn.focus_mode = Control.FOCUS_NONE
	_diff_btn.anchor_left = 0.5
	_diff_btn.anchor_right = 0.5
	_diff_btn.offset_left = -200.0
	_diff_btn.offset_right = 200.0
	_diff_btn.offset_top = 202.0
	_diff_btn.offset_bottom = 242.0
	_diff_btn.pressed.connect(_cycle_difficulty)
	_menu.add_child(_diff_btn)
	_update_diff_btn()

	var daily_btn := Button.new()
	daily_btn.focus_mode = Control.FOCUS_NONE
	daily_btn.anchor_left = 0.5
	daily_btn.anchor_right = 0.5
	daily_btn.offset_left = -200.0
	daily_btn.offset_right = 200.0
	daily_btn.offset_top = 248.0
	daily_btn.offset_bottom = 292.0
	var d_lv := DailyChallenge3D.todays_level_index(LevelData3D.level_count())
	daily_btn.text = "📅 %s" % DailyChallenge3D.challenge_title(d_lv)
	daily_btn.modulate = Color(1.0, 0.8, 0.45)
	daily_btn.pressed.connect(_start_daily_challenge)
	_menu.add_child(daily_btn)

	var curse_info := Label.new()
	curse_info.name = "MenuCurseInfo"
	curse_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	curse_info.anchor_right = 1.0
	curse_info.offset_top = 298.0
	curse_info.offset_bottom = 340.0
	curse_info.add_theme_font_size_override("font_size", 15)
	curse_info.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	curse_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu.add_child(curse_info)
	_refresh_menu_curse_info(curse_info)

	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.5
	scroll.anchor_right = 0.5
	scroll.anchor_top = 0.5
	scroll.anchor_bottom = 0.5
	scroll.offset_left = -420.0
	scroll.offset_right = 420.0
	scroll.offset_top = -40.0
	scroll.offset_bottom = 290.0
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
		if _hazards != null:
			_hazards.stop_session()
		if _curses != null:
			_curses.revert_defaults(_stress, _player, _micro, _hazards)
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


func _refresh_curse_hud() -> void:
	if _curse_label == null:
		return
	if _curses == null or not _curses.has_curses():
		_curse_label.text = ""
		return
	var lines: PackedStringArray = ["LANET"]
	for c in _curses.get_active():
		lines.append("%s %s" % [String(c.get("icon", "☠")), String(c.get("title", "?"))])
	_curse_label.text = "\n".join(lines)


func _update_hard_mode_btn() -> void:
	if _hard_mode_btn == null or _curses == null:
		return
	if _curses.is_hard_mode():
		_hard_mode_btn.text = "ZORLU MOD: AÇIK (2 lanet) · tıkla kapat"
		_hard_mode_btn.modulate = Color(1.0, 0.55, 0.45)
	else:
		_hard_mode_btn.text = "ZORLU MOD: KAPALI · 1 günlük lanet"
		_hard_mode_btn.modulate = Color(0.85, 0.9, 0.95)


func _update_diff_btn() -> void:
	if _diff_btn == null:
		return
	_diff_btn.text = "Zorluk: %s · tıkla değiştir" % DifficultyProfile3D.tier_name(_difficulty)
	match _difficulty:
		DifficultyProfile3D.Tier.EASY:
			_diff_btn.modulate = Color(0.55, 0.95, 0.7)
		DifficultyProfile3D.Tier.HARD:
			_diff_btn.modulate = Color(1.0, 0.5, 0.45)
		_:
			_diff_btn.modulate = Color(0.9, 0.92, 1.0)


func _cycle_difficulty() -> void:
	_difficulty = (_difficulty + 1) % 3
	_update_diff_btn()
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.SWITCH, 1.05)


func _apply_difficulty_profile() -> void:
	if _micro != null:
		_micro.apply_difficulty_mult(
			DifficultyProfile3D.task_interval_mult(_difficulty),
			DifficultyProfile3D.task_duration_mult(_difficulty)
		)
	if _stress != null:
		var curse_stress := 1.0
		if _curses != null:
			curse_stress = float(_curses.combined_mods().get("stress_gain", 1.0))
		_stress.gain_scale = 0.85 * curse_stress * DifficultyProfile3D.stress_gain_mult(_difficulty)


func _toggle_hard_mode() -> void:
	if _curses == null:
		return
	_curses.set_hard_mode(not _curses.is_hard_mode())
	_curses.roll_daily(true)
	_update_hard_mode_btn()
	_refresh_curse_hud()
	var info := _menu.get_node_or_null("MenuCurseInfo") as Label if _menu != null else null
	_refresh_menu_curse_info(info)
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.SWITCH, 1.0)


func _refresh_menu_curse_info(label: Label) -> void:
	if label == null or _curses == null:
		return
	if not _curses.has_curses():
		_curses.roll_daily()
	var parts: PackedStringArray = []
	for c in _curses.get_active():
		parts.append("%s %s — %s" % [
			String(c.get("icon", "")),
			String(c.get("title", "")),
			String(c.get("desc", "")),
		])
	label.text = "Bugünün laneti:\n" + "\n".join(parts)


func _on_item_disposed(_prop_id: String) -> void:
	if _hint != null:
		_hint.text = "Atıldı!  ·  devam"
	if _spawner != null:
		_spawner.call_deferred("_emit_objective_state")
	if _score != null:
		_score.on_dispose()
	_spawn_pop("+40", Color(0.55, 1.0, 0.65), 68)
	_refresh_hint()


func _on_floor_scrubbed(world_pos: Vector3) -> void:
	if _hazards != null:
		_hazards.notify_scrub_cleaned(world_pos)
	if _hint != null:
		_hint.text = "Zemin kaygan — dikkat!"
	# Micro-shake clean fx_burst'ten gelir; ekstra confetti yok


func _on_hazard_slippery(_world_pos: Vector3) -> void:
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.RINSE, 1.15)


func _on_hazard_furniture() -> void:
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.BUMP, 0.75)
	if _camera_rig != null:
		_camera_rig.shake(0.35)
	if _hint != null:
		_hint.text = "Raf kaydı — kırmızı çizgiye basma!"


func _on_hazard_fall_impact(hit_player: bool, world_pos: Vector3) -> void:
	if _particles != null:
		_particles.burst(&"bump", world_pos + Vector3(0, 0.4, 0), 1.6 if hit_player else 0.9)
	if _camera_rig != null:
		_camera_rig.shake(1.4 if hit_player else 0.55)
	if hit_player:
		PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_FAIL, 0.85)
		if _music != null and _stress != null:
			_music.on_mistake(_stress.get_stress_ratio())
		if _banner != null:
			_banner.set_vignette_heat(_stress.get_stress_ratio() if _stress else 0.4)
		if _hint != null:
			_hint.text = "Raf düştü — üzerine geldi!"
		if _player != null:
			_player.play_task_fail_recoil()
	else:
		PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.HIT, 0.7)
		if _hint != null:
			_hint.text = "Kurtuldun — raf yere çarptı"


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
