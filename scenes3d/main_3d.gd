extends Node3D

## Ana 3D oyun — 10 seviye, tempo fazları + mikro-görevler, komedi fizik.

const WorldClearUIScript := preload("res://ui/world_clear_ui.gd")
const LevelCountdownUIScript := preload("res://ui/level_countdown_ui.gd")
const RoomLayoutScript := preload("res://scenes3d/props/room_layout_3d.gd")
const UfoAbductionDirectorScript := preload("res://systems/ufo_abduction_director.gd")

@onready var _player: PlayerCharacter3D = $World/PlayerCharacter
@onready var _camera_rig: IsometricCameraRig = $IsometricCameraRig
@onready var _hint: Label = $UI/HintLabel
@onready var _spawner: GarageClutterSpawner = $World/GarageClutter
@onready var _floor_mesh: MeshInstance3D = $World/GarageFloor/Mesh

var _room_layout: RoomLayout3D

var _mop_label: Label
var _vacuum_label: Label
var _vacuum_bar: ProgressBar
var _objective_label: Label
var _level_label: Label
var _phase_hud: Label
var _menu: Control
var _world_map: WorldMapHub3D
var _particles: ComedyParticles
var _tempo: TempoPhaseDirector
var _micro: MicroTaskDirector
var _banner: TaskBanner
var _music: MusicDirector3D
var _stress: StressComponent
var _combo: RunCombo3D
var _room_timer: RoomTimer3D
var _ui_sfx: AudioStreamPlayer
var _stress_label: Label
var _combo_label: Label
var _time_label: Label
var _badge_hud: Control
var _badge_medal_label: Label
var _badge_time_label: Label
var _badge_hint_label: Label
var _hud_badge_rank: int = BadgeRating3D.Rank.NONE
var _badge_pulse_tween: Tween
var _heat_bar: ProgressBar
var _heat_fill_style: StyleBoxFlat
var _commission: CommissionDirector3D
var _commission_card: CommissionCardUI
var _commission_info: Label
var _hazards: HazardDirector
var _ufos: UfoAbductionDirector
var _junk_rain: JunkRain3D
var _curses: CurseDirector3D
var _curse_label: Label
var _hard_mode_btn: Button
var _diff_btn: Button
var _difficulty: DifficultyProfile3D.Tier = DifficultyProfile3D.Tier.NORMAL
var _score: ScoreTracker3D
var _score_label: Label
var _wallet: Wallet3D
var _lives: Lives3D
var _scrap_collection: ScrapCollection3D
var _scrap_director: ScrapDirector3D
var _scrap_reveal: ScrapRevealUI
var _menu_scrap_label: Label
var _pending_scrap_ids: PackedStringArray = []
var _scrap_revealing: bool = false
var _coin_label: Label
var _lives_label: Label
var _menu_coin_label: Label
var _menu_lives_label: Label
var _menu_records_label: Label
var _result_ui: RunResultUI
var _world_clear_ui # WorldClearUI (preload)
var _countdown_ui # LevelCountdownUI (preload)
var _fail_overlay: Control
var _tool_bar: HBoxContainer
var _tool_bar_buttons: Array[Button] = []
var _daily_mode: bool = false
var _pending_next_level: int = -1
var _level_index: int = 0
var _highest_unlocked: int = 1
var _menu_open: bool = false
var _map_advancing: bool = false
var _title_screen: TitleScreen3D
var _boot_on_title: bool = true
var _level_failing: bool = false
var _game_paused: bool = false
var _pause_overlay: Control
var _paused_room_timer: bool = false
var _save_path := "user://messy3d_progress_v2.cfg"
var _pending_wallet_coins: int = -1
var _pending_lives: int = -1
var _pending_life_coin_progress: int = -1
var _section_hint: String = ""
var _tutorial_banner_sticky: bool = false
var _tutorial_section_busy: bool = false
var _stop_vignette_active: bool = false
var _vac_was_full: bool = false
var _world_run_slot: int = -1
var _world_run_stats: Dictionary = {}
## level_index (str) → BadgeRating3D.Rank (best)
var _level_badges: Dictionary = {}
@export var task_fail_stress: float = 14.0
@export var task_success_relief: float = 6.0


func _ready() -> void:
	# Eski 10'lu kampanya kaydı → yumuşak reset (yeni filler temposuna uyum)
	if not FileAccess.file_exists(_save_path) and FileAccess.file_exists("user://messy3d_progress.cfg"):
		var old := ConfigFile.new()
		if old.load("user://messy3d_progress.cfg") == OK:
			_highest_unlocked = clampi(int(old.get_value("progress", "unlocked", 1)), 1, 3)
			_save_progress()
	_load_progress()
	if _camera_rig != null and _player != null:
		_camera_rig.set_follow(_player)
	_ensure_wall_colliders()
	_ensure_room_layout()
	_remove_arcade_void()
	_setup_tempo_and_tasks()
	_setup_hud()
	_setup_menu()
	_ensure_pause_overlay()
	_particles = ComedyParticles.new()
	_particles.name = "ComedyParticles"
	$World.add_child(_particles)

	if _player != null:
		_player.item_disposed.connect(_on_item_disposed)
		_player.mop_dirt_changed.connect(_on_mop_dirt_changed)
		if _player.has_signal("vacuum_bag_changed"):
			_player.vacuum_bag_changed.connect(_on_vacuum_bag_changed)
		_player.rinsed.connect(_on_rinsed)
		_player.carried_changed.connect(_on_carried_changed)
		_player.dance_changed.connect(_on_dance_changed)
		_player.fx_burst.connect(_on_fx_burst)
		_player.forbidden_touched.connect(_on_forbidden_touched)
		_player.tool_switched.connect(_on_tool_switched)
		_player.tools_unlocked_changed.connect(_on_tools_unlocked)
		_player.junk_eaten.connect(_on_junk_eaten)
		if _player.has_signal("junk_powerup"):
			_player.junk_powerup.connect(_on_junk_powerup)
		_player.wrong_tool_used.connect(_on_wrong_tool)
		if _player.has_signal("secret_probe"):
			_player.secret_probe.connect(_on_secret_probe)
		if _player.has_signal("bag_emptied"):
			_player.bag_emptied.connect(_on_bag_emptied)
		if _player.has_signal("status_message"):
			_player.status_message.connect(_on_player_status_message)

	if _spawner != null:
		_spawner.spawn_on_ready = false
		_spawner.objective_changed.connect(_on_objective_changed)
		_spawner.level_cleared.connect(_on_level_cleared)
		_spawner.section_advanced.connect(_on_section_advanced)
		_spawner.prop_cleared.connect(_on_prop_cleared)

	_setup_title_screen()
	_boot_to_title()
	_configure_pause_modes()


func _configure_pause_modes() -> void:
	## Esc pause: Main3D + UI çalışır, dünya / tempo / oyuncu durur.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for c in get_children():
		if c.name == "UI":
			c.process_mode = Node.PROCESS_MODE_ALWAYS
		else:
			c.process_mode = Node.PROCESS_MODE_PAUSABLE


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
	_micro.stop_countdown_tick.connect(_on_stop_countdown_tick)

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

	_room_timer = RoomTimer3D.new()
	_room_timer.name = "RoomTimer3D"
	add_child(_room_timer)
	_room_timer.time_changed.connect(_on_room_time_changed)
	# Süre fail yok — kronometre + rozet
	_stress.mistake_registered.connect(_on_stress_mistake_side)

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

	_ufos = UfoAbductionDirectorScript.new() as UfoAbductionDirector
	_ufos.name = "UfoAbductionDirector"
	add_child(_ufos)
	_ufos.player_abducted.connect(_on_player_abducted)

	_junk_rain = JunkRain3D.new()
	_junk_rain.name = "JunkRain3D"
	add_child(_junk_rain)
	_junk_rain.setup($World as Node3D, _tempo)

	_curses = CurseDirector3D.new()
	_curses.name = "CurseDirector3D"
	add_child(_curses)
	_curses.roll_daily()
	_curses.curses_rolled.connect(func(_c: Array) -> void: _refresh_curse_hud())

	_score = ScoreTracker3D.new()
	_score.name = "ScoreTracker3D"
	add_child(_score)
	_score.score_changed.connect(_on_score_changed)
	_score.run_coins_changed.connect(_on_run_coins_changed)

	_wallet = Wallet3D.new()
	_wallet.name = "Wallet3D"
	add_child(_wallet)
	_wallet.balance_changed.connect(_on_wallet_changed)
	if _pending_wallet_coins >= 0:
		_wallet.set_balance(_pending_wallet_coins)
		_pending_wallet_coins = -1

	_scrap_collection = ScrapCollection3D.new()
	_scrap_collection.name = "ScrapCollection3D"
	add_child(_scrap_collection)
	if not _pending_scrap_ids.is_empty():
		_scrap_collection.load_ids(_pending_scrap_ids)
		_pending_scrap_ids.clear()
	_scrap_collection.collection_changed.connect(_on_scrap_collection_changed)

	_scrap_director = ScrapDirector3D.new()
	_scrap_director.name = "ScrapDirector3D"
	add_child(_scrap_director)
	_scrap_director.setup(_scrap_collection, _player, $World as Node3D)
	_scrap_director.scrap_found.connect(_on_scrap_found)

	_scrap_reveal = ScrapRevealUI.new()
	_scrap_reveal.name = "ScrapRevealUI"
	$UI.add_child(_scrap_reveal)
	_scrap_reveal.closed.connect(_on_scrap_reveal_closed)
	_scrap_reveal.flight_started.connect(_on_scrap_flight_started)

	_lives = Lives3D.new()
	_lives.name = "Lives3D"
	add_child(_lives)
	_lives.lives_changed.connect(_on_lives_changed)
	_lives.life_gained.connect(_on_life_gained)
	_lives.coin_progress_changed.connect(func(_p: int, _n: int) -> void: _refresh_lives_hud())
	if _pending_lives >= 0:
		_lives.set_state(_pending_lives, maxi(0, _pending_life_coin_progress))
		_pending_lives = -1
		_pending_life_coin_progress = -1

	_result_ui = RunResultUI.new()
	_result_ui.name = "RunResultUI"
	$UI.add_child(_result_ui)
	_result_ui.closed.connect(_on_result_closed)

	_world_clear_ui = WorldClearUIScript.new()
	_world_clear_ui.name = "WorldClearUI"
	$UI.add_child(_world_clear_ui)
	_world_clear_ui.closed.connect(_on_result_closed)

	_countdown_ui = LevelCountdownUIScript.new()
	_countdown_ui.name = "LevelCountdownUI"
	$UI.add_child(_countdown_ui)

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

	_ensure_fail_overlay()

	_ui_sfx = AudioStreamPlayer.new()
	_ui_sfx.name = "UiSfx"
	_ui_sfx.bus = &"Master"
	_ui_sfx.volume_db = -4.0
	add_child(_ui_sfx)
	GameAudioBank.ensure_ready()


func _process(_delta: float) -> void:
	if _menu_open or _game_paused:
		return
	if _banner != null and _micro != null and _micro.has_active_task():
		_banner.set_time_ratio(_micro.get_time_ratio())
	elif _banner != null and _tutorial_banner_sticky:
		_banner.set_time_ratio(1.0)
	_update_corner_timer()
	_update_phase_progress_hud()
	if _music != null and _tempo != null and _tempo.is_running():
		_music.set_intensity(_tempo.get_elapsed_ratio())
	if _player != null and _player.get_potion_drunk() > 0.2:
		_refresh_hint()


func _update_phase_progress_hud() -> void:
	if _phase_hud == null or _tempo == null or not _tempo.is_running():
		return
	var ratio := _tempo.get_elapsed_ratio()
	if LevelData3D.is_tutorial_level(_level_index):
		if _spawner != null and _spawner.has_sections():
			var s := _spawner.get_section_index() + 1
			var n := _spawner.get_section_count()
			_phase_hud.text = "TUTORIAL · Bölüm %d/%d  (%d%%)" % [s, n, roundi(ratio * 100.0)]
		else:
			_phase_hud.text = "TUTORIAL · Sakin öğren  (%d%%)" % roundi(ratio * 100.0)
		_phase_hud.modulate = Color(0.65, 0.95, 0.75)
		return
	var phase := _tempo.get_phase()
	var phase_name := "Isınma"
	match phase:
		TempoPhaseDirector.PHASE_RAMP:
			phase_name = "Hızlan"
		TempoPhaseDirector.PHASE_FINALE:
			phase_name = "Son Patlama"
	_phase_hud.text = "FAZ %d · %s  (%d%%)" % [phase, phase_name, roundi(ratio * 100.0)]
	# Vignette heat bar / stres üzerinden güncellenir (_on_stress_changed)


func _on_fx_burst(kind: StringName, world_pos: Vector3, strength: float) -> void:
	if _particles != null:
		_particles.burst(kind, world_pos, strength)
	# Başarı micro-shake (fail ~2.4 ile karışmasın)
	if _camera_rig != null and (kind == &"dispose" or kind == &"clean" or kind == &"suck"):
		_camera_rig.shake(clampf(0.28 + strength * 0.18, 0.25, 0.55) if kind == &"suck" else clampf(0.35 + strength * 0.22, 0.35, 0.7))


func _spawn_pop(pop_text: String, color: Color = Color(1.0, 0.92, 0.45), font_px: int = 64) -> void:
	if _player == null:
		return
	var host: Node = $World if has_node("World") else self
	FloatingPop3D.spawn(host, _player.global_position, pop_text, color, font_px)


func start_level(index: int, daily: bool = false) -> void:
	if _map_advancing:
		return
	if _lives != null and not _lives.has_lives():
		# Softlock önleme: 100 coin = 1 can (cüzdandan)
		if _wallet != null and _wallet.spend(Lives3D.COINS_PER_LIFE):
			_lives.add_life(&"buy")
			_save_progress()
			_spawn_pop("❤️ 100 coin → can", Color(1.0, 0.45, 0.55), 64)
		else:
			_show_menu(true)
			if _menu_lives_label != null:
				_menu_lives_label.text = "🖤 Can yok · 100 coin lazım"
			PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_FAIL, 1.1)
			return
	_set_game_paused(false)
	_daily_mode = daily
	_pending_next_level = -1
	_level_index = clampi(index, 0, LevelData3D.level_count() - 1)
	_level_failing = false
	if _player != null and _player.has_method("set_control_locked"):
		_player.call("set_control_locked", false)
	# Dünya ilk seviyesinde özet sayacı sıfırla
	var _ws := LevelData3D.world_slot_for_level(_level_index)
	var _wix := LevelData3D.level_indices_for_world(_ws)
	if not _wix.is_empty() and _wix[0] == _level_index:
		_reset_world_run()
	_ensure_world_run(_level_index)
	_hide_fail_overlay()
	_show_menu(false)
	_section_hint = ""
	_tutorial_banner_sticky = false
	_tutorial_section_busy = false
	if _room_timer != null:
		_room_timer.stop()
	_set_time_label_visible(false)
	if _junk_rain != null:
		_junk_rain.stop_session()
	if _ufos != null:
		_ufos.stop_session()
	if _player != null:
		_player.scale = Vector3.ONE
		var spawn := _room_layout.player_spawn() if _room_layout != null else RoomLayout3D.player_spawn_default()
		_player.global_position = spawn
		_player.velocity = Vector3.ZERO
	if _tempo != null:
		_tempo.stop_room()
	if _micro != null:
		_micro.stop_session()
	if _hazards != null:
		_hazards.stop_session()
	if _ufos != null:
		_ufos.stop_session()
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
		_spawner.prop_difficulty_mult = DifficultyProfile3D.prop_count_mult(_difficulty)
		spec = _spawner.begin_level(_level_index)
		_apply_theme(spec)
		_spawner.populate_from_spec(spec)
	else:
		spec = LevelData3D.get_level(_level_index)
		_apply_theme(spec)
	var mop_ok := bool(spec.get("allow_mop", true))
	var dash_charges := LevelData3D.dash_charges_for(_level_index)
	var unlocked_tools := LevelData3D.unlocked_tools_for(_level_index)
	var want_flashlight := _is_dark_level(spec)
	_stop_vignette_active = false
	_apply_dark_room_lighting(want_flashlight)
	if _scrap_director != null:
		_scrap_director.reset_level()
	if _player != null:
		_player.configure_for_level(mop_ok, dash_charges, want_flashlight, unlocked_tools)
		var start_tool := String(spec.get("start_tool", ""))
		if start_tool == "broom" and unlocked_tools >= 2:
			_player.try_set_tool_index(1)
	if _mop_label != null:
		_mop_label.visible = false
	if _vacuum_label != null:
		_vacuum_label.visible = unlocked_tools >= 2
	if _vacuum_bar != null:
		_vacuum_bar.visible = unlocked_tools >= 2
	_refresh_tool_bar()
	if _level_label != null:
		_level_label.visible = false
		_level_label.text = String(spec.get("name", "Seviye"))
	_refresh_hint()
	if _hint != null:
		_hint.visible = false
		_hint.text = String(spec.get("tutorial", _hint.text))
	if bool(spec.get("allow_junk", false)) and bool(spec.get("tutorial_level", false)):
		_section_hint = String(spec.get("tutorial", "Space ile abur cubur ye · 3 = power-up"))
	_on_mop_dirt_changed(_player.get_mop_dirt() if _player != null else 0.0)
	if _player != null and _player.has_method("get_vacuum_bag_count"):
		_vac_was_full = false
		_on_vacuum_bag_changed(_player.get_vacuum_bag_count(), _player.vacuum_bag_capacity)

	# Komisyon kartı — oyun başlamadan önce
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.PHASE, 0.95)
	if _commission != null:
		await _commission.present_for_level(spec)
		# LOW_VISIBILITY / dark — fener + karanlık kesin açık
		if _player != null and (int(_commission.get_current().get("rule", 0)) as CommissionData.Rule) == CommissionData.Rule.LOW_VISIBILITY:
			_apply_dark_room_lighting(true)
			_player.set_flashlight_enabled(true)

	# 3-2-1 — tempo/skor başlamadan önce (hareket kilitli)
	await _play_countdown_locked()
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_OK, 1.05)

	# Tempo + mikro-görev seansı
	var is_tutorial := bool(spec.get("tutorial_level", false)) or LevelData3D.is_tutorial_level(_level_index)
	var is_boss := bool(spec.get("is_boss_room", false)) and not is_tutorial
	var boss_mode := String(spec.get("boss_mode", "")) if not is_tutorial else ""
	var duration := lerpf(90.0, 72.0, clampf(float(_level_index) / 9.0, 0.0, 1.0))
	if is_tutorial:
		# Çok bölümlü tutorial — tempo ısınması için uzun oda
		duration = 280.0 if (_spawner != null and _spawner.has_sections()) else 120.0
	elif is_boss:
		duration = lerpf(85.0, 105.0, clampf(float(_level_index) / 9.0, 0.0, 1.0))
	if _camera_rig != null:
		_camera_rig.set_finale_zoom(is_boss)
	if _tempo != null:
		if is_boss:
			_tempo.start_boss_room(duration)
		else:
			_tempo.start_room(duration)
	if _spawner != null:
		_spawner.bind_tempo(_tempo)
		var no_pressure := is_tutorial or bool(spec.get("disable_pressure", false))
		if not no_pressure:
			_spawner.start_pressure(boss_mode if is_boss else "")
	if _micro != null:
		var no_micro := is_tutorial or bool(spec.get("disable_micro", false))
		if not no_micro:
			_micro.setup(_tempo, _spawner, _player)
			_micro.configure_for_level(_level_index)
			if is_boss:
				_micro.configure_boss_mode(boss_mode)
			_micro.start_session()
	if _hazards != null:
		var no_hazards := is_tutorial or bool(spec.get("disable_hazards", false))
		if not no_hazards:
			_hazards.setup(_player, _stress, _spawner, $World as Node3D, _tempo)
			_hazards.start_session(_level_index, mop_ok)
	if _ufos != null:
		if bool(spec.get("ufo_abduction", false)) and not is_tutorial:
			var hx := _room_layout.half_x() if _room_layout != null else 5.8
			var hz := _room_layout.half_z() if _room_layout != null else 3.8
			_ufos.setup(_player, $World as Node3D, hx, hz)
			var intensity := clampf(float(spec.get("tier", 0)) / 4.0, 0.0, 1.0)
			_ufos.start_session(intensity)
		else:
			_ufos.stop_session()
	if _junk_rain != null:
		# Tutorial da allow_junk=true ise yağmur açık (abur cubur tutorial)
		var no_junk := bool(spec.get("disable_junk", false)) \
			or not bool(spec.get("allow_junk", not is_tutorial))
		if no_junk:
			_junk_rain.stop_session()
		else:
			_junk_rain.setup($World as Node3D, _tempo)
			_junk_rain.spawn_interval_min = float(spec.get("junk_interval_min", 9.5))
			_junk_rain.spawn_interval_max = float(spec.get("junk_interval_max", 15.0))
			_junk_rain.max_concurrent = int(spec.get("junk_max_concurrent", 1))
			_junk_rain.start_session()
			var burst := int(spec.get("junk_starter_burst", 0))
			if burst > 0:
				_junk_rain.spawn_guaranteed(burst)
	# Günlük lanet — tutorial'da kapalı
	if _curses != null:
		var no_curses := is_tutorial or bool(spec.get("disable_curses", false))
		if no_curses:
			_curses.revert_defaults(_stress, _player, _micro, _hazards)
			_refresh_curse_hud()
		else:
			if not _curses.has_curses():
				_curses.roll_daily()
			_curses.apply_to(_stress, _player, _micro, _hazards)
			_refresh_curse_hud()
	if is_tutorial:
		if _stress != null:
			_stress.gain_scale = 0.4
			_stress.mistake_multiplier = 0.45
	else:
		_apply_difficulty_profile()
	if _music != null:
		_music.start(3 if is_boss else 1)
	if _stress != null:
		_stress.reset_stress()
		if is_tutorial:
			_stress.mistake_multiplier = 0.45
		elif _commission != null:
			var c := _commission.get_current()
			if (int(c.get("rule", 0)) as CommissionData.Rule) == CommissionData.Rule.HIGH_RISK:
				_stress.mistake_multiplier = clampf(float(c.get("param", 2.0)), 1.4, 3.0)
	if _combo != null:
		_combo.reset()
	if _phase_hud != null:
		if is_tutorial:
			if _spawner != null and _spawner.has_sections():
				_phase_hud.text = "TUTORIAL · Bölüm 1/%d" % _spawner.get_section_count()
			elif bool(spec.get("allow_junk", false)):
				_phase_hud.text = "TUTORIAL · Abur Cubur"
			else:
				_phase_hud.text = "TUTORIAL · Sakin öğren"
			_phase_hud.modulate = Color(0.65, 0.95, 0.75)
		elif is_boss:
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
		_on_run_coins_changed(0)
	_spawn_level_bonus_coins(spec, is_tutorial)
	if is_boss:
		_flash_boss_intro(String(spec.get("boss_title", "SET-PIECE")))
	if _daily_mode and _hint != null:
		_hint.text = "📅 Günlük meydan okuma — kendini geç!"
	# Tutorial bölüm 1 UI (komisyon kartından sonra, ikinci kart yok)
	if is_tutorial and _spawner != null and _spawner.has_sections():
		await _apply_tutorial_section(_spawner.get_current_section(), 0, _spawner.get_section_count(), false)
	else:
		var limit := float(spec.get("time_limit", 0.0))
		if limit <= 0.0:
			limit = 48.0
		_start_room_timer(limit)


func _start_daily_challenge() -> void:
	if _map_advancing:
		return
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
	# Soft / hard süre fail kaldırıldı — rozet sistemi
	pass


func _start_room_timer(seconds: float) -> void:
	if _room_timer == null:
		return
	_hud_badge_rank = BadgeRating3D.Rank.NONE
	_room_timer.start(maxf(seconds, 0.0))
	_set_time_label_visible(true)
	_on_room_time_changed(0.0)


func _set_time_label_visible(vis: bool) -> void:
	if _badge_hud != null:
		_badge_hud.visible = vis
	if _time_label != null:
		_time_label.visible = false
		if not vis:
			_time_label.text = ""
	if not vis:
		_hud_badge_rank = BadgeRating3D.Rank.NONE


func _on_room_time_changed(elapsed: float) -> void:
	if _micro != null and (
		_micro.is_stop_countdown_active()
		or String(_micro.get_active_task_type()) == MicroTaskDirector.TASK_STOP
	):
		return
	if _room_timer == null or not _room_timer.is_active():
		if elapsed <= 0.0:
			_set_time_label_visible(false)
		return
	_show_corner_stopwatch(elapsed)


func _show_corner_stopwatch(elapsed: float) -> void:
	if _badge_hud == null or _room_timer == null:
		return
	_badge_hud.visible = true
	if _time_label != null:
		_time_label.visible = false
	var par := _room_timer.get_par_seconds()
	var rank := BadgeRating3D.rank_from_elapsed(elapsed, par)
	var total := ceili(elapsed)
	var mins := floori(total / 60.0)
	var secs := total % 60
	if _badge_time_label != null:
		_badge_time_label.text = "%d:%02d" % [mins, secs]
	if _badge_medal_label != null:
		_badge_medal_label.text = BadgeRating3D.icon(rank)
		_badge_medal_label.modulate = BadgeRating3D.color(rank)
	if _badge_hint_label != null:
		_badge_hint_label.text = _badge_drop_hint(elapsed, par, rank)
		_badge_hint_label.modulate = BadgeRating3D.color(rank).lerp(Color.WHITE, 0.25)
	# Madalya düşüşü — Moving Out tarzı anlık feedback
	if _hud_badge_rank != BadgeRating3D.Rank.NONE and rank < _hud_badge_rank:
		_pulse_badge_drop(rank)
	_hud_badge_rank = rank


func _badge_drop_hint(elapsed: float, par: float, rank: int) -> String:
	var gold_t := BadgeRating3D.gold_threshold(par)
	var silver_t := BadgeRating3D.silver_threshold(par)
	match rank as BadgeRating3D.Rank:
		BadgeRating3D.Rank.GOLD:
			var left := maxf(0.0, gold_t - elapsed)
			return "ALTIN  ·  🥈 %.0fs" % left
		BadgeRating3D.Rank.SILVER:
			var left2 := maxf(0.0, silver_t - elapsed)
			return "GÜMÜŞ  ·  🥉 %.0fs" % left2
		BadgeRating3D.Rank.BRONZE:
			return "BRONZ"
		_:
			return ""


func _pulse_badge_drop(new_rank: int) -> void:
	if _badge_medal_label == null:
		return
	_spawn_pop(
		"%s %s" % [BadgeRating3D.icon(new_rank), BadgeRating3D.label(new_rank)],
		BadgeRating3D.color(new_rank),
		68
	)
	if _camera_rig != null:
		_camera_rig.shake(0.35)
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_FAIL, 1.15)
	if _badge_pulse_tween != null and _badge_pulse_tween.is_valid():
		_badge_pulse_tween.kill()
	_badge_medal_label.scale = Vector2(1.4, 1.4)
	_badge_pulse_tween = create_tween()
	_badge_pulse_tween.tween_property(_badge_medal_label, "scale", Vector2.ONE, 0.28)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_corner_timer() -> void:
	if _micro == null:
		return
	if _micro.is_stop_countdown_active():
		var n := maxi(1, ceili(_micro.get_stop_countdown_left()))
		_show_corner_countdown(n)
		return
	if String(_micro.get_active_task_type()) == MicroTaskDirector.TASK_STOP:
		_show_corner_countdown(maxi(0, ceili(_micro.get_task_time_left())))
		return
	if _room_timer != null and _room_timer.is_active():
		_show_corner_stopwatch(_room_timer.get_elapsed())


func _show_corner_countdown(n: int) -> void:
	# DUR uyarısı — rozet panelini geçici gizle, büyük sayı göster
	if _badge_hud != null:
		_badge_hud.visible = false
	if _time_label == null:
		return
	_time_label.visible = true
	_time_label.add_theme_font_size_override("font_size", 120)
	_time_label.text = str(n)
	_time_label.modulate = Color(1.0, 0.25, 0.28) if n <= 1 else Color(1.0, 0.55, 0.35)


func _on_stop_countdown_tick(seconds_left: int) -> void:
	_show_corner_countdown(seconds_left)
	if _banner != null:
		_banner.show_task(
			"HAZIR OL",
			Color(1.0, 0.35, 0.4),
			"DUR geliyor — %d" % seconds_left,
			"stop_warn"
		)
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK, 0.75 + 0.08 * float(4 - seconds_left))


func _on_stress_mistake_side() -> void:
	pass


func _on_player_abducted() -> void:
	_fail_level("👽 UFO KAÇIRDI!")


func _fail_level(title_text: String) -> void:
	if _level_failing or _menu_open:
		return
	_level_failing = true
	if _tempo != null:
		_tempo.stop_room()
	if _micro != null:
		_micro.stop_session()
	if _hazards != null:
		_hazards.stop_session()
	if _ufos != null:
		_ufos.stop_session()
	if _junk_rain != null:
		_junk_rain.stop_session()
	if _spawner != null:
		_spawner.stop_pressure()
	if _music != null:
		_music.stop(true)
	if _banner != null:
		_banner.flash_fail()
	if _camera_rig != null:
		_camera_rig.shake(2.4)
	if _player != null:
		_player.scale = Vector3.ONE
		if _player.has_method("set_control_locked"):
			_player.call("set_control_locked", true)
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_FAIL, 0.75)
	if _lives != null:
		_lives.lose_life()
		_save_progress()
	if _hint != null:
		var left := _lives.get_lives() if _lives != null else 0
		_hint.text = "%s  ·  can: %d" % [title_text, left]
	_show_fail_overlay(title_text)


func _show_fail_overlay(title_text: String = "BAŞARISIZ!") -> void:
	if _fail_overlay == null:
		_ensure_fail_overlay()
	_refresh_fail_overlay(title_text)
	if _fail_overlay != null:
		_fail_overlay.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _hide_fail_overlay() -> void:
	if _fail_overlay != null:
		_fail_overlay.visible = false


func _refresh_fail_overlay(title_text: String = "") -> void:
	if _fail_overlay == null:
		return
	var left := _lives.get_lives() if _lives != null else 0
	var title := _fail_overlay.get_node_or_null("Panel/VBox/FailTitle") as Label
	var sub := _fail_overlay.get_node_or_null("Panel/VBox/FailSub") as Label
	var retry := _fail_overlay.get_node_or_null("Panel/VBox/FailRetry") as Button
	if title != null and not title_text.is_empty():
		title.text = title_text
	if sub != null:
		if left > 0:
			sub.text = "Kalan can: %d  ·  Tekrar dene veya menüye dön" % left
		else:
			sub.text = "Can bitti! 100 coin veya seviyede ❤️ bul"
	if retry != null:
		retry.disabled = left <= 0
		retry.text = "Tekrar" if left > 0 else "Can yok"


func _ensure_fail_overlay() -> void:
	if _fail_overlay != null:
		return
	var ui: CanvasLayer = $UI as CanvasLayer
	_fail_overlay = Control.new()
	_fail_overlay.name = "FailOverlay"
	_fail_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fail_overlay.visible = false
	_fail_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.add_child(_fail_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.02, 0.03, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_fail_overlay.add_child(dim)
	_fail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	panel.offset_top = -130.0
	panel.offset_bottom = 130.0
	_fail_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.name = "FailTitle"
	title.text = "BAŞARISIZ!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	vbox.add_child(title)

	var sub := Label.new()
	sub.name = "FailSub"
	sub.text = "Kalan can: 3"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.modulate = Color(0.85, 0.8, 0.75)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(sub)

	var retry := Button.new()
	retry.name = "FailRetry"
	retry.text = "Tekrar"
	retry.custom_minimum_size = Vector2(0, 40)
	retry.pressed.connect(_on_fail_retry)
	vbox.add_child(retry)

	var menu_btn := Button.new()
	menu_btn.text = "Menü"
	menu_btn.custom_minimum_size = Vector2(0, 36)
	menu_btn.pressed.connect(_on_fail_menu)
	vbox.add_child(menu_btn)


func _on_fail_retry() -> void:
	if _lives != null and not _lives.has_lives():
		PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_FAIL, 1.2)
		_refresh_fail_overlay()
		return
	_hide_fail_overlay()
	_level_failing = false
	start_level(_level_index, _daily_mode)


func _on_fail_menu() -> void:
	_hide_fail_overlay()
	_level_failing = false
	if _room_timer != null:
		_room_timer.stop()
	_set_time_label_visible(false)
	_show_menu(true)


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
	# Erken tutorial bölümlerinde faz flaşı banner'ı bozmasın
	if _tutorial_banner_sticky:
		return
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
			_hint.text = "⚡ HIZLAN — tempo yükseliyor!"
		elif phase == 3:
			_hint.text = "🔥 SON PATLAMA — emirler sıklaşıyor!"


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
		_stop_vignette_active = true
		if _banner != null:
			_banner.set_vignette_heat(0.95)
		PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.STOP, 0.9)
	else:
		_stop_vignette_active = false
		PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK)
	if _hint != null:
		_hint.text = "Emir: %s  (%.0fs)" % [label, duration]


func _on_player_status_message(msg: String) -> void:
	if _hint != null and not msg.is_empty():
		_hint.text = msg


func _clear_stop_vignette() -> void:
	_stop_vignette_active = false
	if _stress != null:
		_on_stress_changed(_stress.current_stress, _stress.max_stress)
	elif _banner != null:
		_banner.set_vignette_heat(0.0)


func _on_task_succeeded(_task_type: String, star_units: int = 1) -> void:
	_clear_stop_vignette()
	if _banner != null:
		_banner.hide_task(true)
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_OK, 1.1)
	if _combo != null:
		_combo.register_success()
	if _room_timer != null and _room_timer.is_active():
		_room_timer.on_clean()
	var combo_n := _combo.get_combo() if _combo else 0
	if _score != null:
		_score.on_task_ok(combo_n)
		_score.on_star_task(star_units)
	if _stress != null:
		_stress.reduce_stress(task_success_relief)
	if _music != null:
		_music.pulse_upbeat(0.05 + 0.01 * float(combo_n))
	if _particles != null and _player != null:
		_particles.burst(&"clean", _player.global_position + Vector3(0, 1, 0), 1.1)
	if _camera_rig != null:
		_camera_rig.shake(0.55)
	_spawn_pop("+%d" % (80 + mini(combo_n, 8) * 12), Color(0.55, 1.0, 0.7), 72)
	if star_units >= 2:
		_spawn_pop("+%d🪙" % maxi(0, star_units - 1), Color(1.0, 0.85, 0.35), 56)
	if _hint != null:
		_hint.text = "Emir tamam! ★  combo x%d" % combo_n


func _on_task_failed(_task_type: String) -> void:
	_clear_stop_vignette()
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
		var pct := roundi(ratio * 100.0)
		_stress_label.text = "HEAT: %d%%" % pct
		_stress_label.modulate = Color(1.0, lerpf(1.0, 0.35, ratio), lerpf(1.0, 0.35, ratio))
	if _heat_bar != null:
		_heat_bar.value = ratio * 100.0
		if _heat_fill_style != null:
			_heat_fill_style.bg_color = Color(1.0, lerpf(0.75, 0.15, ratio), lerpf(0.25, 0.1, ratio))
	if _music != null:
		_music.set_heat(ratio)
	if _banner != null and _stop_vignette_active:
		_banner.set_vignette_heat(0.95)
		return
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


func _on_run_coins_changed(run_coins: int) -> void:
	_refresh_coin_hud(run_coins)


func _on_wallet_changed(_balance: int) -> void:
	_refresh_coin_hud(-1)
	var bal := _wallet.get_balance() if _wallet != null else 0
	if _menu_coin_label != null:
		_menu_coin_label.text = "🪙 %d" % bal
	if _world_map != null:
		_world_map.set_wallet_coins(bal)
	_refresh_lives_hud()


func _on_lives_changed(_lives_n: int) -> void:
	_refresh_lives_hud()


func _on_life_gained(reason: StringName, lives_n: int) -> void:
	_refresh_lives_hud()
	if reason == &"coins":
		_spawn_pop("❤️ +1 CAN", Color(1.0, 0.45, 0.55), 70)
		if _hint != null and not _menu_open:
			_hint.text = "❤️ 100 coin → can! (toplam %d)" % lives_n


func _refresh_coin_hud(run_override: int = -1) -> void:
	if _coin_label == null:
		return
	var total := _wallet.get_balance() if _wallet != null else 0
	var run_c := run_override
	if run_c < 0 and _score != null:
		run_c = _score.get_run_bonus_coins()
	if run_c > 0:
		_coin_label.text = "🪙 %d  (+%d bu tur)" % [total, run_c]
	else:
		_coin_label.text = "🪙 %d" % total


func _refresh_lives_hud() -> void:
	var n := _lives.get_lives() if _lives != null else Lives3D.START_LIVES
	var prog := _lives.get_coin_progress() if _lives != null else 0
	var need := _lives.get_coins_per_life() if _lives != null else Lives3D.COINS_PER_LIFE
	var hearts := ""
	for _i in n:
		hearts += "❤️"
	if hearts.is_empty():
		hearts = "🖤"
	if _lives_label != null:
		_lives_label.text = "%s %d  ·  %d/%d" % [hearts, n, prog, need]
	if _menu_lives_label != null:
		_menu_lives_label.text = "%s %d  ·  %d/%d coin → +can" % [hearts, n, prog, need]


func _clear_bonus_coins() -> void:
	for n in get_tree().get_nodes_in_group("CoinPickup"):
		if is_instance_valid(n):
			n.queue_free()
	for n in get_tree().get_nodes_in_group("HeartPickup"):
		if is_instance_valid(n):
			n.queue_free()


func _spawn_level_bonus_coins(spec: Dictionary, is_tutorial: bool) -> void:
	_clear_bonus_coins()
	if _spawner == null:
		return
	# İlk garaj tutorial bölümlerinde yok; abur cubur tutorial ve normal seviyelerde var
	if is_tutorial and _spawner.has_sections():
		return
	if bool(spec.get("disable_coins", false)):
		return
	var count := int(spec.get("bonus_coins", -1))
	if count < 0:
		count = 2 + mini(2, floori(float(_level_index) / 12.0))
		if bool(spec.get("allow_junk", false)) and is_tutorial:
			count = 3
	var world := $World as Node3D
	var spawned := _spawner.spawn_bonus_coins(count, world)
	for n in get_tree().get_nodes_in_group("CoinPickup"):
		var coin := n as CoinPickup3D
		if coin != null and not coin.collected.is_connected(_on_coin_collected):
			coin.collected.connect(_on_coin_collected)
	_spawn_level_heart(spec, is_tutorial, world)
	if spawned > 0 and _hint != null and not is_tutorial:
		pass


func _spawn_level_heart(spec: Dictionary, is_tutorial: bool, world: Node3D) -> void:
	if _spawner == null or world == null:
		return
	if bool(spec.get("disable_hearts", false)):
		return
	# Tutorial / boss: daha seyrek veya kapalı
	var chance := float(spec.get("heart_chance", -1.0))
	if chance < 0.0:
		chance = 0.22
		if is_tutorial:
			chance = 0.12
		elif bool(spec.get("is_boss_room", false)):
			chance = 0.35
	if randf() > chance:
		return
	if not _spawner.spawn_heart_pickup(world):
		return
	for n in get_tree().get_nodes_in_group("HeartPickup"):
		var heart := n as HeartPickup3D
		if heart != null and not heart.collected.is_connected(_on_heart_collected):
			heart.collected.connect(_on_heart_collected)


func _on_coin_collected(amount: int, world_pos: Vector3) -> void:
	if _score != null:
		_score.on_coin_pickup(amount)
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.DISPOSE, 1.35)
	_spawn_pop("+%d🪙" % amount, Color(1.0, 0.85, 0.3), 64)
	if _particles != null:
		_particles.burst(&"clean", world_pos + Vector3(0, 0.5, 0), 0.9)
	if _camera_rig != null:
		_camera_rig.shake(0.2)


func _on_heart_collected(world_pos: Vector3) -> void:
	var ok := false
	if _lives != null:
		ok = _lives.add_life(&"pickup")
		_save_progress()
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_OK, 1.2)
	if ok:
		_spawn_pop("+1❤️", Color(1.0, 0.4, 0.5), 72)
	else:
		_spawn_pop("CAN DOLU", Color(1.0, 0.7, 0.75), 56)
	if _particles != null:
		_particles.burst(&"clean", world_pos + Vector3(0, 0.6, 0), 1.1)
	if _camera_rig != null:
		_camera_rig.shake(0.35)
	if _hint != null and ok:
		_hint.text = "❤️ Can +1!"


func _on_combo_milestone(combo: int) -> void:
	if _hint != null:
		_hint.text = "🔥 Combo x%d!" % combo
	if _particles != null and _player != null:
		_particles.burst(&"dance", _player.global_position, 1.3)
	if _camera_rig != null:
		_camera_rig.shake(0.5)
	_spawn_pop("COMBO x%d" % combo, Color(1.0, 0.75, 0.35), 80)
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_OK, 1.25)


func _on_task_cleared() -> void:
	# DUR bitti → kronometreye dön
	if _room_timer != null and _room_timer.is_active():
		_show_corner_stopwatch(_room_timer.get_elapsed())
	# Tutorial tempo bölümünde emir aralarında öğretici şeridi geri getir
	if not LevelData3D.is_tutorial_level(_level_index):
		return
	if _spawner == null or not _spawner.has_sections() or _banner == null:
		return
	var sec := _spawner.get_current_section()
	if sec.is_empty() or not bool(sec.get("enable_micro", false)):
		return
	_banner.show_task(
		String(sec.get("banner", "EMİRLER GELİYOR!")),
		sec.get("banner_color", Color(1.0, 0.45, 0.55)) as Color,
		String(sec.get("subtitle", "")),
		""
	)
	if not _section_hint.is_empty() and _hint != null:
		_hint.text = _section_hint


func _ensure_room_layout() -> void:
	var world: Node3D = $World as Node3D
	if world == null:
		return
	_room_layout = world.get_node_or_null("RoomLayout") as RoomLayout3D
	if _room_layout == null:
		_room_layout = RoomLayoutScript.new() as RoomLayout3D
		_room_layout.name = "RoomLayout"
		world.add_child(_room_layout)
	if _spawner != null and _spawner.has_method("bind_room_layout"):
		_spawner.call("bind_room_layout", _room_layout)


func _apply_theme(spec: Dictionary) -> void:
	var floor_c: Color = spec.get("floor", Color(0.34, 0.36, 0.38)) as Color
	var wall_c: Color = spec.get("wall", Color(0.5, 0.5, 0.5)) as Color
	var dark_room := _is_dark_level(spec)
	if _room_layout != null:
		_room_layout.apply_spec(spec)
		_apply_room_footprint(_room_layout.half_x(), _room_layout.half_z(), _is_outdoor_level(spec))
	if _floor_mesh != null:
		_floor_mesh.material_override = RoomToonMaterial.make_floor(floor_c, dark_room)
		_floor_mesh.set_surface_override_material(0, null)
	_apply_plain_backdrop(floor_c, dark_room)
	var outdoor := _is_outdoor_level(spec)
	var wall_style := RoomToonMaterial.wall_style_for_spec(spec)
	var wall_i := 0
	for wall_name in ["WallBack", "WallLeft"]:
		var wall: MeshInstance3D = $World.get_node_or_null(wall_name) as MeshInstance3D
		if wall == null:
			continue
		wall.visible = not outdoor
		if outdoor:
			continue
		wall.material_override = RoomToonMaterial.make_wall(wall_c, dark_room, wall_style, wall_i)
		wall_i += 1


func _apply_room_footprint(hx: float, hz: float, outdoor: bool = false) -> void:
	## Seviye başına harita boyutu — zemin, duvar mesh/collider hizası
	var floor_w := hx * 2.0
	var floor_d := hz * 2.0
	var floor_body := $World.get_node_or_null("GarageFloor") as StaticBody3D
	if floor_body != null:
		var mesh_n := floor_body.get_node_or_null("Mesh") as MeshInstance3D
		if mesh_n != null:
			var bm := mesh_n.mesh as BoxMesh
			if bm == null:
				bm = BoxMesh.new()
				mesh_n.mesh = bm
			bm.size = Vector3(floor_w, 0.2, floor_d)
		var col_n := floor_body.get_node_or_null("Collision") as CollisionShape3D
		if col_n != null:
			var bs := col_n.shape as BoxShape3D
			if bs == null:
				bs = BoxShape3D.new()
				col_n.shape = bs
			bs.size = Vector3(floor_w, 0.2, floor_d)

	var wall_h := 3.2
	var back := $World.get_node_or_null("WallBack") as MeshInstance3D
	if back != null:
		var wbm := BoxMesh.new()
		wbm.size = Vector3(floor_w + 0.5, wall_h, 0.28)
		back.mesh = wbm
		back.transform = Transform3D.IDENTITY
		back.position = Vector3(0.0, wall_h * 0.5, -hz - 0.14)
		back.visible = not outdoor

	var left := $World.get_node_or_null("WallLeft") as MeshInstance3D
	if left != null:
		var lbm := BoxMesh.new()
		lbm.size = Vector3(0.28, wall_h, floor_d + 0.5)
		left.mesh = lbm
		left.transform = Transform3D.IDENTITY
		left.position = Vector3(-hx - 0.14, wall_h * 0.5, 0.0)
		left.visible = not outdoor

	var world: Node3D = $World as Node3D
	if world == null:
		return
	var thick := 0.45
	_add_wall_body(world, "WallColliderBack", Vector3(0, 1.5, -hz - 0.35), Vector3(floor_w + 0.8, 3.2, thick), false)
	_add_wall_body(world, "WallColliderLeft", Vector3(-hx - 0.35, 1.5, 0), Vector3(thick, 3.2, floor_d + 0.8), false)
	_add_wall_body(world, "WallColliderRight", Vector3(hx + 0.35, 1.5, 0), Vector3(thick, 3.2, floor_d + 0.8), true)
	_add_wall_body(world, "WallColliderFront", Vector3(0, 1.5, hz + 0.35), Vector3(floor_w + 0.8, 3.2, thick), true)


func _is_outdoor_level(spec: Dictionary) -> bool:
	if bool(spec.get("tutorial_level", false)):
		return false
	if spec.has("outdoor"):
		return bool(spec.get("outdoor"))
	var id := String(spec.get("theme_id", spec.get("id", "")))
	return id == "slime" or id.begins_with("slime_")


func _is_dark_level(spec: Dictionary) -> bool:
	var id := String(spec.get("id", ""))
	if id == "dark" or id.begins_with("dark_"):
		return true
	return (int(spec.get("commission", {}).get("rule", 0)) as CommissionData.Rule) == CommissionData.Rule.LOW_VISIBILITY


func _apply_dark_room_lighting(on: bool) -> void:
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_energy = 0.045 if on else 0.45
		sun.light_color = Color(0.45, 0.55, 0.85) if on else Color(1, 1, 1)
	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if on and env_node == null:
		env_node = WorldEnvironment.new()
		env_node.name = "WorldEnvironment"
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.02, 0.03, 0.05)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.04, 0.05, 0.08)
		env.ambient_light_energy = 0.12
		env_node.environment = env
		add_child(env_node)
	elif env_node != null:
		if on:
			var env := env_node.environment
			if env == null:
				env = Environment.new()
				env_node.environment = env
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.02, 0.03, 0.05)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.04, 0.05, 0.08)
			env.ambient_light_energy = 0.12
		else:
			# Dark dışı: tema gökyüzü; dark: _apply_dark_room_lighting yönetir
			_apply_plain_backdrop(Color(0.34, 0.36, 0.38), false)


func _remove_arcade_void() -> void:
	var existing := get_node_or_null("ArcadeTileVoid")
	if existing != null:
		existing.queue_free()


func _apply_plain_backdrop(floor_c: Color, dark_room: bool) -> void:
	## Gökyüzü yok — dış zemin tonu (oyun alanı dışı ile aynı)
	_remove_arcade_void()
	if dark_room:
		return
	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node == null:
		env_node = WorldEnvironment.new()
		env_node.name = "WorldEnvironment"
		add_child(env_node)
	var env := env_node.environment
	if env == null:
		env = Environment.new()
		env_node.environment = env
	var ground := Color(0.16, 0.15, 0.14)
	if _room_layout != null and _room_layout.has_method("outside_ground_color"):
		ground = _room_layout.outside_ground_color()
	else:
		ground = floor_c.darkened(0.45).lerp(Color(0.16, 0.15, 0.14), 0.55)
	env.background_mode = Environment.BG_COLOR
	env.background_color = ground
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.66)
	env.ambient_light_energy = 0.5
	env.fog_enabled = false


func _on_objective_changed(remaining: int, total: int) -> void:
	if _objective_label == null:
		return
	var section_prefix := ""
	if _spawner != null and _spawner.has_sections():
		section_prefix = "Bölüm %d/%d · " % [_spawner.get_section_index() + 1, _spawner.get_section_count()]
	if remaining <= 0:
		_objective_label.text = "✓ %sGEÇİLDİ!" % section_prefix
		_objective_label.modulate = Color(0.5, 1.0, 0.6)
	else:
		_objective_label.text = "%sHEDEF: %d / %d" % [section_prefix, total - remaining, total]
		_objective_label.modulate = Color(0.9, 0.92, 1.0)


func _on_section_advanced(section_index: int, section_count: int, section: Dictionary) -> void:
	if _tutorial_section_busy:
		return
	await _apply_tutorial_section(section, section_index, section_count, true)


func _apply_tutorial_section(section: Dictionary, section_index: int, section_count: int, with_card: bool) -> void:
	if section.is_empty():
		return
	_tutorial_section_busy = true
	_section_hint = String(section.get("hint", ""))
	var title := String(section.get("title", "Bölüm %d" % (section_index + 1)))
	var banner := String(section.get("banner", title))
	var subtitle := String(section.get("subtitle", ""))
	var col: Color = section.get("banner_color", Color(0.65, 0.92, 0.75)) as Color
	var enable_micro := bool(section.get("enable_micro", false))
	var enable_pressure := bool(section.get("enable_pressure", false))
	var soft_pressure := bool(section.get("soft_pressure", false))
	var section_limit := float(section.get("time_limit", 0.0))

	if _phase_hud != null:
		_phase_hud.text = "TUTORIAL · Bölüm %d/%d" % [section_index + 1, section_count]
		_phase_hud.modulate = Color(0.65, 0.95, 0.75)
	if _level_label != null:
		_level_label.text = "1 · Tutorial · %s" % title
	if _commission_info != null:
		_commission_info.text = "📘 %s  (%d / %d)" % [title, section_index + 1, section_count]
		_commission_info.modulate = col

	if with_card and _commission_card != null:
		if _room_timer != null:
			_room_timer.pause()
		var card := {
			"npc": "Kuzen Marv",
			"icon": "📘",
			"title": title,
			"desc": String(section.get("card_desc", subtitle)),
			"rule": CommissionData.Rule.NONE,
			"param": 0.0,
		}
		var prev_mode := process_mode
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
		PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.PHASE, 1.0)
		await _commission_card.show_card(card, 0.0, true)
		get_tree().paused = false
		process_mode = prev_mode
		PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_OK, 1.05)
		# Bölümler arası — timer bitene kadar hareket yok
		await _play_countdown_locked()

	if _banner != null:
		_banner.show_task(banner, col, subtitle, "")
	_tutorial_banner_sticky = not enable_micro

	if _micro != null:
		if enable_micro:
			_micro.setup(_tempo, _spawner, _player)
			_micro.configure_tutorial_tempo()
			_micro.start_session()
		else:
			_micro.stop_session()
	if _spawner != null:
		if enable_pressure:
			_spawner.start_pressure("", soft_pressure)
		else:
			_spawner.stop_pressure()

	# Tempo bölümünde kronometre; yoksa par fallback
	if section_limit > 0.0:
		_start_room_timer(section_limit)
	elif _room_timer != null and not _room_timer.is_active():
		_start_room_timer(48.0)

	if _hint != null and not _section_hint.is_empty():
		_hint.text = _section_hint
	_spawn_pop("Bölüm %d/%d" % [section_index + 1, section_count], col, 56)
	_tutorial_section_busy = false


func _play_countdown_locked() -> void:
	if _player != null:
		if _player.has_method("set_control_locked"):
			_player.call("set_control_locked", true)
		_player.set_process_unhandled_input(false)
		_player.velocity = Vector3.ZERO
	if _countdown_ui != null:
		await _countdown_ui.play()
	if _player != null:
		if _player.has_method("set_control_locked"):
			_player.call("set_control_locked", false)
		if not _menu_open and not _level_failing:
			_player.set_process_unhandled_input(true)


func _on_level_cleared() -> void:
	if _level_failing:
		return
	_section_hint = ""
	_tutorial_banner_sticky = false
	_tutorial_section_busy = false
	if _room_timer != null:
		_room_timer.stop()
	_set_time_label_visible(false)
	if _junk_rain != null:
		_junk_rain.stop_session()
	if _tempo != null:
		_tempo.stop_room()
	if _micro != null:
		_micro.stop_session()
	if _hazards != null:
		_hazards.stop_session()
	if _ufos != null:
		_ufos.stop_session()
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
	if _commission_info != null:
		_commission_info.text = ""
	if _camera_rig != null:
		_camera_rig.set_finale_zoom(false)

	# Skor sonucu — kendini geçtin mi?
	var stress_r := _stress.get_stress_ratio() if _stress else 0.0
	var result: Dictionary = {}
	if _score != null:
		result = _score.finalize(stress_r, _daily_mode, _level_index)
	# Rozet — kronometre elapsed + par
	var elapsed := float(result.get("elapsed", 0.0))
	var par := _room_timer.get_par_seconds() if _room_timer != null else float(LevelData3D.get_level(_level_index).get("time_limit", 48.0))
	if _room_timer != null and _room_timer.get_elapsed() > 0.05:
		elapsed = _room_timer.get_elapsed()
		result["elapsed"] = elapsed
	var badge := BadgeRating3D.rank_from_elapsed(elapsed, par)
	result["badge"] = badge
	result["badge_label"] = BadgeRating3D.label(badge)
	result["badge_icon"] = BadgeRating3D.icon(badge)
	_record_level_badge(_level_index, badge)
	var earned := int(result.get("coins_earned", 0))
	# Rozet coin bonus
	var badge_bonus := 0
	match badge as BadgeRating3D.Rank:
		BadgeRating3D.Rank.GOLD:
			badge_bonus = 8
		BadgeRating3D.Rank.SILVER:
			badge_bonus = 4
		BadgeRating3D.Rank.BRONZE:
			badge_bonus = 2
	if badge_bonus > 0:
		earned += badge_bonus
		result["coins_earned"] = earned
		result["coins_badge"] = badge_bonus
	if _wallet != null and earned > 0:
		_wallet.add(earned)
		var gained := 0
		if _lives != null:
			gained = _lives.register_coins_earned(earned)
		_save_progress()
		if gained > 0:
			result["lives_from_coins"] = gained
	if _lives != null:
		result["lives"] = _lives.get_lives()
		result["life_coin_progress"] = _lives.get_coin_progress()
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

	_accumulate_world_run(result)
	var world_finale := (not _daily_mode) and LevelData3D.is_world_finale(_level_index)

	if _particles != null and _player != null:
		_particles.burst(&"clean", _player.global_position + Vector3(0, 1.2, 0), 1.4)
		_particles.burst(&"dispose", _player.global_position + Vector3(0.3, 1.0, 0), 1.0)
	if _camera_rig != null:
		_camera_rig.shake(0.6)

	# Günlük: seviye sonucu. Kampanya: sadece dünya/bölüm sonunda özet.
	if _daily_mode and _result_ui != null:
		result["wallet_total"] = _wallet.get_balance() if _wallet != null else 0
		_result_ui.present(result, compare, true)
	elif world_finale and _world_clear_ui != null:
		var slot := LevelData3D.world_slot_for_level(_level_index)
		var wcmp := DailyChallenge3D.save_world_result(slot, int(_world_run_stats.get("score", 0)))
		_world_clear_ui.present(slot, _world_run_stats.duplicate(), wcmp)
		_reset_world_run()
	else:
		# Ara seviye — rozet pop
		var bicon := String(result.get("badge_icon", "🥉"))
		var blab := String(result.get("badge_label", "BRONZ"))
		var earned_show := int(result.get("coins_earned", 0))
		var sc := int(result.get("score", 0))
		_spawn_pop("%s %s" % [bicon, blab], BadgeRating3D.color(int(result.get("badge", 1))), 72)
		if bool(compare.get("is_new_best", false)):
			await get_tree().create_timer(0.25).timeout
			_spawn_pop("🏆 %d" % sc, Color(1.0, 0.85, 0.35), 64)
		elif earned_show > 0:
			await get_tree().create_timer(0.2).timeout
			_spawn_pop("+%d🪙" % earned_show, Color(1.0, 0.85, 0.35), 56)
		await get_tree().create_timer(0.65).timeout
		_on_result_closed()


func _reset_world_run() -> void:
	_world_run_slot = -1
	_world_run_stats = {}


func _ensure_world_run(level_index: int) -> void:
	var slot := LevelData3D.world_slot_for_level(level_index)
	if slot != _world_run_slot:
		_world_run_slot = slot
		_world_run_stats = {
			"score": 0,
			"coins": 0,
			"max_combo": 0,
			"disposed": 0,
			"boxes_carried": 0,
			"mop_scrubs": 0,
			"mistakes": 0,
			"elapsed": 0.0,
			"levels_cleared": 0,
			"badges": [], ## [{level, name, badge, icon}]
			"gold": 0,
			"silver": 0,
			"bronze": 0,
		}


func _accumulate_world_run(result: Dictionary) -> void:
	_ensure_world_run(_level_index)
	_world_run_stats["score"] = int(_world_run_stats.get("score", 0)) + int(result.get("score", 0))
	_world_run_stats["coins"] = int(_world_run_stats.get("coins", 0)) + int(result.get("coins_earned", 0))
	_world_run_stats["max_combo"] = maxi(
		int(_world_run_stats.get("max_combo", 0)), int(result.get("max_combo", 0))
	)
	_world_run_stats["disposed"] = int(_world_run_stats.get("disposed", 0)) + int(result.get("disposed", 0))
	_world_run_stats["mistakes"] = int(_world_run_stats.get("mistakes", 0)) + int(result.get("mistakes", 0))
	_world_run_stats["elapsed"] = float(_world_run_stats.get("elapsed", 0.0)) + float(result.get("elapsed", 0.0))
	_world_run_stats["levels_cleared"] = int(_world_run_stats.get("levels_cleared", 0)) + 1
	var badge := int(result.get("badge", BadgeRating3D.Rank.BRONZE))
	match badge as BadgeRating3D.Rank:
		BadgeRating3D.Rank.GOLD:
			_world_run_stats["gold"] = int(_world_run_stats.get("gold", 0)) + 1
		BadgeRating3D.Rank.SILVER:
			_world_run_stats["silver"] = int(_world_run_stats.get("silver", 0)) + 1
		_:
			_world_run_stats["bronze"] = int(_world_run_stats.get("bronze", 0)) + 1
	var info := LevelData3D.get_level(_level_index)
	var badges: Array = _world_run_stats.get("badges", []) as Array
	badges.append({
		"level": _level_index,
		"name": String(info.get("name", "Seviye")),
		"tier": int(info.get("tier", 0)),
		"badge": badge,
		"icon": BadgeRating3D.icon(badge),
		"label": BadgeRating3D.label(badge),
		"elapsed": float(result.get("elapsed", 0.0)),
	})
	_world_run_stats["badges"] = badges


func _record_level_badge(level_index: int, badge: int) -> void:
	var key := str(level_index)
	var prev := int(_level_badges.get(key, BadgeRating3D.Rank.NONE))
	_level_badges[key] = BadgeRating3D.best(prev, badge)
	_save_progress()
	if _world_map != null and _world_map.has_method("set_level_badges"):
		_world_map.call("set_level_badges", _level_badges)


func _on_result_closed() -> void:
	var was_daily := _daily_mode
	_daily_mode = false
	if was_daily or _pending_next_level < 0:
		_show_menu(true)
		return
	var from_level := _level_index
	var to_level := _pending_next_level
	_pending_next_level = -1
	await _play_map_advance_then_start(from_level, to_level)


func _play_map_advance_then_start(from_level: int, to_level: int) -> void:
	_map_advancing = true
	_show_menu(true)
	if _hard_mode_btn != null:
		_hard_mode_btn.disabled = true
	if _diff_btn != null:
		_diff_btn.disabled = true
	if _world_map == null:
		_map_advancing = false
		start_level(to_level, false)
		return
	var bal := _wallet.get_balance() if _wallet != null else 0
	_world_map.set_wallet_coins(bal)
	await _world_map.play_advance(from_level, to_level, _highest_unlocked)
	_map_advancing = false
	if _hard_mode_btn != null:
		_hard_mode_btn.disabled = false
	if _diff_btn != null:
		_diff_btn.disabled = false
	start_level(to_level, false)


func _ensure_wall_colliders() -> void:
	var world: Node3D = $World as Node3D
	if world == null:
		return
	# Görünür duvarlar: Back + Left. Açık kenarlar: Front + Right → görünmez duvar.
	_add_wall_body(world, "WallColliderBack", Vector3(0, 1.5, -6.7), Vector3(18.5, 3.2, 0.45), false)
	_add_wall_body(world, "WallColliderLeft", Vector3(-9.2, 1.5, 0), Vector3(0.45, 3.2, 13.5), false)
	_add_wall_body(world, "WallColliderRight", Vector3(9.2, 1.5, 0), Vector3(0.45, 3.2, 13.5), true)
	_add_wall_body(world, "WallColliderFront", Vector3(0, 1.5, 6.7), Vector3(18.5, 3.2, 0.45), true)


func _add_wall_body(parent: Node3D, wall_name: String, pos: Vector3, size: Vector3, _invisible_visual: bool) -> void:
	var body := parent.get_node_or_null(wall_name) as StaticBody3D
	if body == null:
		body = StaticBody3D.new()
		body.name = wall_name
		body.collision_layer = 1
		body.collision_mask = 0
		parent.add_child(body)
		var shape_node := CollisionShape3D.new()
		shape_node.name = "Collision"
		var box := BoxShape3D.new()
		shape_node.shape = box
		body.add_child(shape_node)
		# Görsel yok — sadece collider (eski InvisibleMesh ortada gri kutu gibi görünebiliyordu)
	body.position = pos
	var col := body.get_node_or_null("Collision") as CollisionShape3D
	if col == null:
		for c in body.get_children():
			if c is CollisionShape3D:
				col = c as CollisionShape3D
				break
	if col != null:
		var box_shape := col.shape as BoxShape3D
		if box_shape == null:
			box_shape = BoxShape3D.new()
			col.shape = box_shape
		box_shape.size = size
	# Eski InvisibleMesh kalıntısını temizle
	var invis := body.get_node_or_null("InvisibleMesh") as MeshInstance3D
	if invis != null:
		invis.queue_free()


func _setup_hud() -> void:
	var ui: CanvasLayer = $UI as CanvasLayer
	_mop_label = Label.new()
	_mop_label.offset_left = 24.0
	_mop_label.offset_top = 52.0
	_mop_label.offset_right = 480.0
	_mop_label.offset_bottom = 82.0
	_mop_label.add_theme_font_size_override("font_size", 18)
	_mop_label.visible = false
	ui.add_child(_mop_label)

	_vacuum_label = Label.new()
	_vacuum_label.offset_left = 24.0
	_vacuum_label.offset_top = 52.0
	_vacuum_label.offset_right = 420.0
	_vacuum_label.offset_bottom = 82.0
	_vacuum_label.add_theme_font_size_override("font_size", 18)
	_vacuum_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_vacuum_label.add_theme_constant_override("outline_size", 6)
	_vacuum_label.visible = false
	ui.add_child(_vacuum_label)

	_vacuum_bar = ProgressBar.new()
	_vacuum_bar.offset_left = 24.0
	_vacuum_bar.offset_top = 84.0
	_vacuum_bar.offset_right = 260.0
	_vacuum_bar.offset_bottom = 104.0
	_vacuum_bar.min_value = 0.0
	_vacuum_bar.max_value = 3.0
	_vacuum_bar.value = 0.0
	_vacuum_bar.show_percentage = false
	_vacuum_bar.visible = false
	var vac_bg := StyleBoxFlat.new()
	vac_bg.bg_color = Color(0.12, 0.14, 0.18, 0.85)
	vac_bg.corner_radius_top_left = 4
	vac_bg.corner_radius_top_right = 4
	vac_bg.corner_radius_bottom_left = 4
	vac_bg.corner_radius_bottom_right = 4
	var vac_fill := StyleBoxFlat.new()
	vac_fill.bg_color = Color(0.35, 0.75, 1.0)
	vac_fill.corner_radius_top_left = 4
	vac_fill.corner_radius_top_right = 4
	vac_fill.corner_radius_bottom_left = 4
	vac_fill.corner_radius_bottom_right = 4
	_vacuum_bar.add_theme_stylebox_override("background", vac_bg)
	_vacuum_bar.add_theme_stylebox_override("fill", vac_fill)
	ui.add_child(_vacuum_bar)

	_objective_label = Label.new()
	_objective_label.offset_left = 24.0
	_objective_label.offset_top = 24.0
	_objective_label.offset_right = 520.0
	_objective_label.offset_bottom = 64.0
	_objective_label.add_theme_font_size_override("font_size", 28)
	_objective_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_objective_label.add_theme_constant_override("outline_size", 8)
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
	_level_label.visible = false
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
	_phase_hud.visible = false
	ui.add_child(_phase_hud)

	_stress_label = Label.new()
	_stress_label.offset_left = 24.0
	_stress_label.offset_top = 116.0
	_stress_label.offset_right = 320.0
	_stress_label.offset_bottom = 140.0
	_stress_label.add_theme_font_size_override("font_size", 18)
	_stress_label.text = "HEAT: 0%"
	_stress_label.visible = false
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
	_heat_bar.visible = false
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
	_combo_label.visible = false
	ui.add_child(_combo_label)

	_tool_bar = HBoxContainer.new()
	_tool_bar.name = "ToolBar"
	_tool_bar.offset_left = 24.0
	_tool_bar.offset_top = 72.0
	_tool_bar.offset_right = 420.0
	_tool_bar.offset_bottom = 118.0
	_tool_bar.add_theme_constant_override("separation", 6)
	ui.add_child(_tool_bar)
	_tool_bar_buttons.clear()
	for i in 5:
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 40)
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		var idx := i
		b.pressed.connect(func() -> void:
			if _player != null:
				_player.try_set_tool_index(idx)
			_refresh_tool_bar()
		)
		_tool_bar.add_child(b)
		_tool_bar_buttons.append(b)
	_refresh_tool_bar()

	# Moving Out tarzı rozet + süre — sağ alt
	_badge_hud = Control.new()
	_badge_hud.name = "BadgeHud"
	_badge_hud.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_badge_hud.anchor_left = 1.0
	_badge_hud.anchor_right = 1.0
	_badge_hud.anchor_top = 1.0
	_badge_hud.anchor_bottom = 1.0
	_badge_hud.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_badge_hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_badge_hud.offset_left = -340.0
	_badge_hud.offset_right = -20.0
	_badge_hud.offset_top = -168.0
	_badge_hud.offset_bottom = -18.0
	_badge_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_hud.visible = false
	ui.add_child(_badge_hud)

	var badge_row := HBoxContainer.new()
	badge_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_row.alignment = BoxContainer.ALIGNMENT_END
	badge_row.add_theme_constant_override("separation", 12)
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_hud.add_child(badge_row)

	var badge_col := VBoxContainer.new()
	badge_col.alignment = BoxContainer.ALIGNMENT_END
	badge_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_col.add_theme_constant_override("separation", 2)
	badge_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_row.add_child(badge_col)

	_badge_time_label = Label.new()
	_badge_time_label.name = "BadgeTime"
	_badge_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_badge_time_label.add_theme_font_size_override("font_size", 52)
	_badge_time_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	_badge_time_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	_badge_time_label.add_theme_constant_override("outline_size", 12)
	_badge_time_label.text = "0:00"
	_badge_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_col.add_child(_badge_time_label)

	_badge_hint_label = Label.new()
	_badge_hint_label.name = "BadgeHint"
	_badge_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_badge_hint_label.add_theme_font_size_override("font_size", 16)
	_badge_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_badge_hint_label.add_theme_constant_override("outline_size", 6)
	_badge_hint_label.text = "ALTIN"
	_badge_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_col.add_child(_badge_hint_label)

	_badge_medal_label = Label.new()
	_badge_medal_label.name = "BadgeMedal"
	_badge_medal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_medal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_medal_label.custom_minimum_size = Vector2(88, 88)
	_badge_medal_label.pivot_offset = Vector2(44, 44)
	_badge_medal_label.add_theme_font_size_override("font_size", 64)
	_badge_medal_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_badge_medal_label.add_theme_constant_override("outline_size", 8)
	_badge_medal_label.text = "🥇"
	_badge_medal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_row.add_child(_badge_medal_label)

	# DUR geri sayımı (geçici büyük sayı) — aynı köşe
	_time_label = Label.new()
	_time_label.name = "RoomTimeLabel"
	_time_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_time_label.anchor_left = 1.0
	_time_label.anchor_right = 1.0
	_time_label.anchor_top = 1.0
	_time_label.anchor_bottom = 1.0
	_time_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_time_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_time_label.offset_left = -280.0
	_time_label.offset_right = -28.0
	_time_label.offset_top = -160.0
	_time_label.offset_bottom = -28.0
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_time_label.add_theme_font_size_override("font_size", 64)
	_time_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_time_label.add_theme_constant_override("outline_size", 14)
	_time_label.modulate = Color(0.95, 0.92, 0.55)
	_time_label.visible = false
	ui.add_child(_time_label)

	_score_label = Label.new()
	_score_label.offset_left = 24.0
	_score_label.offset_top = 200.0
	_score_label.offset_right = 320.0
	_score_label.offset_bottom = 228.0
	_score_label.add_theme_font_size_override("font_size", 18)
	_score_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_score_label.text = "SKOR: 0"
	_score_label.visible = false
	ui.add_child(_score_label)

	_coin_label = Label.new()
	_coin_label.offset_left = 24.0
	_coin_label.offset_top = 228.0
	_coin_label.offset_right = 360.0
	_coin_label.offset_bottom = 256.0
	_coin_label.add_theme_font_size_override("font_size", 18)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	_coin_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_coin_label.add_theme_constant_override("outline_size", 6)
	_coin_label.text = "🪙 0"
	_coin_label.visible = false
	ui.add_child(_coin_label)
	_refresh_coin_hud()

	_lives_label = Label.new()
	_lives_label.offset_left = 24.0
	_lives_label.offset_top = 256.0
	_lives_label.offset_right = 420.0
	_lives_label.offset_bottom = 284.0
	_lives_label.add_theme_font_size_override("font_size", 18)
	_lives_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.5))
	_lives_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_lives_label.add_theme_constant_override("outline_size", 6)
	_lives_label.text = "❤️ 3"
	_lives_label.visible = false
	ui.add_child(_lives_label)
	_refresh_lives_hud()


func _setup_title_screen() -> void:
	_title_screen = TitleScreen3D.new()
	_title_screen.name = "TitleScreen3D"
	$UI.add_child(_title_screen)
	_title_screen.continued.connect(_on_title_continued)


func _boot_to_title() -> void:
	_boot_on_title = true
	_menu_open = false
	_set_run_hud_visible(false)
	if _menu != null:
		_menu.visible = false
	if has_node("World"):
		$World.visible = false
	if _camera_rig != null:
		_camera_rig.visible = false
		_camera_rig.set_process(false)
		_camera_rig.set_physics_process(false)
	if _player != null:
		_player.set_process_unhandled_input(false)
		_player.set_physics_process(false)
	if _world_map != null:
		_world_map.set_active(false)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _title_screen != null:
		_title_screen.present()


func _on_title_continued() -> void:
	_boot_on_title = false
	_show_menu(true)


func _setup_menu() -> void:
	# 3D dünya haritası hub
	_world_map = WorldMapHub3D.new()
	_world_map.name = "WorldMapHub3D"
	add_child(_world_map)
	if _camera_rig != null and _camera_rig.has_node("Camera3D"):
		_world_map.set_game_camera(_camera_rig.get_node("Camera3D") as Camera3D)
	_world_map.level_chosen.connect(func(idx: int) -> void:
		if _map_advancing:
			return
		start_level(idx)
	)
	_world_map.world_changed.connect(_on_menu_world_changed)

	_menu = Control.new()
	_menu.name = "LevelMenu"
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.visible = false
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_menu)

	# Üst şerit — 3D harita görünsün diye sadece header
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.offset_bottom = 300.0
	bg.color = Color(0.06, 0.08, 0.1, 0.72)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(bg)

	var title := Label.new()
	title.text = "MESSY JANITOR · 3D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_right = 1.0
	title.offset_top = 12.0
	title.offset_bottom = 56.0
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 6)
	_menu.add_child(title)

	_menu_coin_label = Label.new()
	_menu_coin_label.name = "MenuCoinLabel"
	_menu_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_coin_label.anchor_right = 1.0
	_menu_coin_label.offset_top = 52.0
	_menu_coin_label.offset_bottom = 78.0
	_menu_coin_label.add_theme_font_size_override("font_size", 22)
	_menu_coin_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_menu_coin_label.text = "🪙 0"
	_menu.add_child(_menu_coin_label)

	_menu_lives_label = Label.new()
	_menu_lives_label.name = "MenuLivesLabel"
	_menu_lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_lives_label.anchor_right = 1.0
	_menu_lives_label.offset_top = 78.0
	_menu_lives_label.offset_bottom = 102.0
	_menu_lives_label.add_theme_font_size_override("font_size", 20)
	_menu_lives_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.55))
	_menu_lives_label.text = "❤️ 3  ·  0/100 → +can"
	_menu.add_child(_menu_lives_label)

	_menu_scrap_label = Label.new()
	_menu_scrap_label.name = "MenuScrapLabel"
	_menu_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_scrap_label.anchor_right = 1.0
	_menu_scrap_label.offset_top = 102.0
	_menu_scrap_label.offset_bottom = 124.0
	_menu_scrap_label.add_theme_font_size_override("font_size", 16)
	_menu_scrap_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.88))
	_menu_scrap_label.text = "📦 Kayıp eşya 0/12"
	_menu.add_child(_menu_scrap_label)
	_refresh_menu_scrap_label()

	var sub := Label.new()
	sub.text = "3D harita  ·  Q/E seviye · W/S dünya · Space gir"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_right = 1.0
	sub.offset_top = 124.0
	sub.offset_bottom = 146.0
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.75, 0.88, 0.95))
	_menu.add_child(sub)

	_hard_mode_btn = Button.new()
	_hard_mode_btn.focus_mode = Control.FOCUS_NONE
	_hard_mode_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_hard_mode_btn.anchor_left = 0.5
	_hard_mode_btn.anchor_right = 0.5
	_hard_mode_btn.offset_left = -200.0
	_hard_mode_btn.offset_right = 200.0
	_hard_mode_btn.offset_top = 150.0
	_hard_mode_btn.offset_bottom = 182.0
	_hard_mode_btn.pressed.connect(_toggle_hard_mode)
	_menu.add_child(_hard_mode_btn)
	_update_hard_mode_btn()

	_diff_btn = Button.new()
	_diff_btn.focus_mode = Control.FOCUS_NONE
	_diff_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_diff_btn.anchor_left = 0.5
	_diff_btn.anchor_right = 0.5
	_diff_btn.offset_left = -200.0
	_diff_btn.offset_right = 200.0
	_diff_btn.offset_top = 188.0
	_diff_btn.offset_bottom = 220.0
	_diff_btn.pressed.connect(_cycle_difficulty)
	_menu.add_child(_diff_btn)
	_update_diff_btn()

	var daily_btn := Button.new()
	daily_btn.focus_mode = Control.FOCUS_NONE
	daily_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	daily_btn.anchor_left = 0.5
	daily_btn.anchor_right = 0.5
	daily_btn.offset_left = -200.0
	daily_btn.offset_right = 200.0
	daily_btn.offset_top = 226.0
	daily_btn.offset_bottom = 258.0
	var d_lv := DailyChallenge3D.todays_level_index(LevelData3D.level_count())
	daily_btn.text = "📅 %s" % DailyChallenge3D.challenge_title(d_lv)
	daily_btn.modulate = Color(1.0, 0.8, 0.45)
	daily_btn.pressed.connect(_start_daily_challenge)
	_menu.add_child(daily_btn)

	var curse_info := Label.new()
	curse_info.name = "MenuCurseInfo"
	curse_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	curse_info.anchor_right = 1.0
	curse_info.offset_top = 264.0
	curse_info.offset_bottom = 296.0
	curse_info.add_theme_font_size_override("font_size", 13)
	curse_info.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	curse_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu.add_child(curse_info)
	_refresh_menu_curse_info(curse_info)

	# Kayıtlar — seçili dünyanın rekorları (seviye sonu yerine burada)
	_menu_records_label = Label.new()
	_menu_records_label.name = "MenuRecordsLabel"
	_menu_records_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu_records_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_menu_records_label.anchor_left = 0.0
	_menu_records_label.anchor_right = 0.0
	_menu_records_label.offset_left = 16.0
	_menu_records_label.offset_right = 320.0
	_menu_records_label.offset_top = 150.0
	_menu_records_label.offset_bottom = 290.0
	_menu_records_label.add_theme_font_size_override("font_size", 13)
	_menu_records_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	_menu_records_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_records_label.text = "🏆 Kayıtlar"
	_menu.add_child(_menu_records_label)

	_world_map.setup(_highest_unlocked, -1)
	_world_map.set_level_badges(_level_badges)
	_refresh_menu_records(0)


func _rebuild_level_buttons() -> void:
	if _world_map == null:
		return
	# Menüye dönüşte mevcut level'e odaklan; yoksa bölümün ilk açık seviyesi
	var prefer := _level_index if _level_index >= 0 else -1
	_world_map.setup(_highest_unlocked, prefer)
	_world_map.set_level_badges(_level_badges)


func _show_menu(open: bool) -> void:
	_set_game_paused(false)
	_menu_open = open
	if open:
		_level_failing = false
		_hide_fail_overlay()
		_clear_bonus_coins()
		if _score != null:
			_score.stop()
		if _room_timer != null:
			_room_timer.stop()
		_set_time_label_visible(false)
		if _junk_rain != null:
			_junk_rain.stop_session()
		if _tempo != null:
			_tempo.stop_room()
		if _micro != null:
			_micro.stop_session()
		if _hazards != null:
			_hazards.stop_session()
		if _ufos != null:
			_ufos.stop_session()
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
		if _player != null and _player.has_method("_release_vacuum"):
			_player.call("_release_vacuum")
	_set_run_hud_visible(not open)
	if _menu != null:
		_menu.visible = open
		if open:
			_rebuild_level_buttons()
			_on_wallet_changed(_wallet.get_balance() if _wallet != null else 0)
			_refresh_lives_hud()
			_refresh_menu_scrap_label()
			if _world_map != null:
				_refresh_menu_records(_world_map.get_world_slot() if _world_map.has_method("get_world_slot") else 0)
	# Oyun dünyası ↔ 3D harita
	if has_node("World"):
		$World.visible = not open
	if _camera_rig != null:
		_camera_rig.visible = not open
		_camera_rig.set_process(not open)
		_camera_rig.set_physics_process(not open)
	if _player != null:
		_player.set_process_unhandled_input(not open)
		_player.set_physics_process(not open)
	if _world_map != null:
		if open:
			_world_map.set_wallet_coins(_wallet.get_balance() if _wallet != null else 0)
		_world_map.set_active(open)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _set_run_hud_visible(hud_on: bool) -> void:
	if _score_label != null:
		_score_label.visible = hud_on
	if _coin_label != null:
		_coin_label.visible = hud_on
	if _lives_label != null:
		_lives_label.visible = hud_on
	if hud_on:
		_refresh_coin_hud()
		_refresh_lives_hud()


func _refresh_hint() -> void:
	if _hint == null or _menu_open:
		return
	if _player != null and _player.get_potion_drunk() > 0.35:
		_hint.text = "😵 İksir sarhoşu! Mor lekeden çık / paspasla temizle"
		return
	if _player != null and _player.is_holding():
		_hint.text = "Kutu elde · başka kutuya Space = stack · çöpe Space = at (max 5)"
	elif not _section_hint.is_empty():
		_hint.text = _section_hint
	else:
		_hint.text = "WASD · Shift dash · G dans · Space tut/fırlat · Esc menü"


func _on_dance_changed(dancing: bool) -> void:
	if _hint == null:
		return
	_hint.text = "💃 DANS — duvara çarp, partikül yağsın!" if dancing else "Dans bitti · Esc menü"


func _on_mop_dirt_changed(ratio: float) -> void:
	if _mop_label == null:
		return
	var pct := roundi(ratio * 100.0)
	_mop_label.text = "Paspas kiri: %d%%  %s" % [pct, "→ kovada basılı tut" if pct > 0 else ""]
	_mop_label.modulate = Color(1.0, lerpf(1.0, 0.55, ratio), lerpf(1.0, 0.4, ratio))


func _on_vacuum_bag_changed(count: int, capacity: int) -> void:
	if _vacuum_label == null:
		return
	var show_hud := _player != null and _player.get_unlocked_tool_count() >= 2 and not _menu_open
	_vacuum_label.visible = show_hud
	if _vacuum_bar != null:
		_vacuum_bar.visible = show_hud
	if not show_hud:
		_vac_was_full = false
		return
	var cap := maxi(capacity, 1)
	var full := count >= cap
	if _vacuum_bar != null:
		_vacuum_bar.max_value = float(cap)
		_vacuum_bar.value = float(count)
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = Color(1.0, 0.35, 0.22) if full else Color(0.35, 0.75, 1.0).lerp(Color(1.0, 0.7, 0.3), float(count) / float(cap))
		fill_style.corner_radius_top_left = 4
		fill_style.corner_radius_top_right = 4
		fill_style.corner_radius_bottom_left = 4
		fill_style.corner_radius_bottom_right = 4
		_vacuum_bar.add_theme_stylebox_override("fill", fill_style)
	if full:
		_vacuum_label.text = "TORBA DOLU %d/%d  →  ÇÖPE BOŞALT!" % [count, cap]
		_vacuum_label.modulate = Color(1.0, 0.45, 0.3)
		if not _vac_was_full:
			if _hint != null:
				_hint.visible = true
				_hint.text = "⚠️ Torba dolu — yeşil ÇÖP'ün yanında Space"
			_spawn_pop("TORBA DOLU!", Color(1.0, 0.45, 0.3), 72)
			if _camera_rig != null:
				_camera_rig.shake(0.55)
			if _banner != null and not _tutorial_banner_sticky:
				_banner.show_task("TORBA DOLU", Color(1.0, 0.4, 0.28), "Çöpün yanında Space ile boşalt", "")
	elif count <= 0:
		_vacuum_label.text = "Süpürge torbası: boş"
		_vacuum_label.modulate = Color(0.7, 0.9, 1.0)
		if _vac_was_full and _hint != null and _hint.text.find("Torba dolu") >= 0:
			_hint.text = "Torba boş — devam et"
	else:
		_vacuum_label.text = "Süpürge torbası: %d / %d" % [count, cap]
		_vacuum_label.modulate = Color(0.85, 0.95, 1.0).lerp(Color(1.0, 0.75, 0.4), float(count) / float(cap))
	_vac_was_full = full


func _on_rinsed() -> void:
	if _hint != null:
		_hint.text = "Paspas temiz!"
	if _scrap_director != null and _player != null and _player.has_method("is_speed_rushing") \
			and bool(_player.call("is_speed_rushing")):
		_scrap_director.try_secret("rush_rinse", _player.global_position)


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
	if _map_advancing:
		return
	_difficulty = (((_difficulty as int) + 1) % 3) as DifficultyProfile3D.Tier
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
	if _map_advancing or _curses == null:
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


func _on_carried_changed(holding: bool) -> void:
	_refresh_hint()
	if not holding or _player == null:
		return
	if not _player.has_method("get_held_prop"):
		return
	var prop = _player.call("get_held_prop")
	if prop == null:
		return
	var pid := ""
	if prop is ClutterProp:
		pid = String((prop as ClutterProp).prop_id)
	elif prop.get("prop_id") != null:
		pid = String(prop.get("prop_id"))
	if pid.find("box") < 0:
		return
	_ensure_world_run(_level_index)
	var units := 1
	if prop.has_method("get_stack_units"):
		units = maxi(1, int(prop.call("get_stack_units")))
	_world_run_stats["boxes_carried"] = int(_world_run_stats.get("boxes_carried", 0)) + units


func _on_item_disposed(prop_id: String) -> void:
	if _hint != null:
		_hint.text = "Atıldı!  ·  devam"
	if _spawner != null:
		_spawner.call_deferred("_emit_objective_state")
	if _score != null:
		_score.on_dispose()
	_spawn_pop("+40", Color(0.55, 1.0, 0.65), 68)
	_refresh_hint()
	var pos := _player.global_position if _player != null else Vector3.ZERO
	if _scrap_director != null:
		_scrap_director.on_prop_cleaned(prop_id, pos)
		if _player != null and _player.has_method("is_dancing") and bool(_player.call("is_dancing")):
			_scrap_director.try_secret("dance_dispose", pos)
	# Paspasla biten sıvı/leke
	match prop_id:
		"wet", "slime", "potion", "boss_slime":
			_ensure_world_run(_level_index)
			_world_run_stats["mop_scrubs"] = int(_world_run_stats.get("mop_scrubs", 0)) + 1


func _on_secret_probe(secret_id: String, world_pos: Vector3) -> void:
	if _scrap_director != null:
		_scrap_director.try_secret(secret_id, world_pos)


func _on_bag_emptied(_dumped: int, was_full: bool, world_pos: Vector3) -> void:
	if was_full and _scrap_director != null:
		_scrap_director.try_secret("empty_full_bag", world_pos)


func _on_scrap_found(scrap_id: String, is_new: bool, world_pos: Vector3) -> void:
	_save_progress()
	_refresh_menu_scrap_label()
	if _scrap_revealing:
		return
	_scrap_revealing = true
	var info := ScrapCatalog.by_id(scrap_id)
	var icon := String(info.get("icon", "📦"))
	var accent := Color(0.55, 0.7, 0.9) if is_new else Color(0.55, 0.62, 0.7)
	if _particles != null:
		_particles.burst(&"clean", world_pos + Vector3(0, 0.45, 0), 0.55)
	# 1) Elde tut + dön (carry)
	var from_screen := get_viewport().get_visible_rect().size * 0.5
	var start_yaw := 0.0
	if _player != null and _player.has_method("play_scrap_hold"):
		_player.set_process_unhandled_input(false)
		_player.call("play_scrap_hold", icon, accent)
		await _player.scrap_hold_ui_ready
		var cam: Camera3D = null
		if _camera_rig != null and _camera_rig.has_node("Camera3D"):
			cam = _camera_rig.get_node("Camera3D") as Camera3D
		if cam != null and _player.has_method("get_scrap_hold_screen_pos"):
			from_screen = _player.call("get_scrap_hold_screen_pos", cam) as Vector2
		if _player.has_method("get_scrap_spin_y"):
			start_yaw = float(_player.call("get_scrap_spin_y"))
	# 2) Kesintisiz UI geçişi — dönüş devam eder, pencere soft belirir
	var resume_pause := get_tree().paused
	get_tree().paused = true
	var found := _scrap_collection.found_count() if _scrap_collection != null else 1
	var total := ScrapCatalog.count()
	if _scrap_reveal != null:
		if not _scrap_reveal.seated.is_connected(_on_scrap_ui_seated):
			_scrap_reveal.seated.connect(_on_scrap_ui_seated, CONNECT_ONE_SHOT)
		# El, flight_started'da gizlenir (aynı karede uçuş kopyası görünür)
		_scrap_reveal.present_seamless(scrap_id, found, total, is_new, from_screen, start_yaw)
		await _scrap_reveal.closed
	_finish_scrap_reveal(resume_pause)


func _on_scrap_flight_started() -> void:
	if _player != null and _player.has_method("set_scrap_hold_visible"):
		_player.call("set_scrap_hold_visible", false)


func _on_scrap_ui_seated() -> void:
	# Item UI'ye oturdu — eldeki kopya kaybolur (map zaten temiz)
	if _player != null:
		if _player.has_method("set_scrap_hold_visible"):
			_player.call("set_scrap_hold_visible", false)
		if _player.has_method("clear_scrap_hold"):
			_player.call("clear_scrap_hold")


func _on_scrap_reveal_closed() -> void:
	if _scrap_revealing and (_scrap_reveal == null or not _scrap_reveal.visible):
		_finish_scrap_reveal(false)


func _finish_scrap_reveal(resume_pause: bool = false) -> void:
	_scrap_revealing = false
	get_tree().paused = resume_pause
	if _player != null:
		if _player.has_method("clear_scrap_hold"):
			_player.call("clear_scrap_hold")
		if not _menu_open:
			_player.set_process_unhandled_input(true)
	_refresh_menu_scrap_label()


func _on_scrap_collection_changed(_found: int, _total: int) -> void:
	_refresh_menu_scrap_label()


func _refresh_menu_scrap_label() -> void:
	if _menu_scrap_label == null:
		return
	var found := _scrap_collection.found_count() if _scrap_collection != null else 0
	var total := ScrapCatalog.count()
	_menu_scrap_label.text = "📦 Kayıp eşya %d/%d" % [found, total]


func _on_menu_world_changed(world_slot: int) -> void:
	_refresh_menu_records(world_slot)


func _refresh_menu_records(world_slot: int) -> void:
	if _menu_records_label == null:
		return
	var icon := LevelData3D.world_icon(world_slot)
	var title := LevelData3D.world_title(world_slot)
	var body := DailyChallenge3D.world_records_summary(world_slot)
	_menu_records_label.text = "🏆 %s %s\n%s" % [icon, title, body]


func _on_prop_cleared() -> void:
	if _room_timer != null and _room_timer.is_active():
		_room_timer.on_clean()


func _on_tool_switched(_tool_name: String) -> void:
	_refresh_tool_bar()


func _on_tools_unlocked(_count: int) -> void:
	_refresh_tool_bar()


func _refresh_tool_bar() -> void:
	if _tool_bar == null:
		return
	var unlocked := 1
	var active := 0
	if _player != null:
		unlocked = _player.get_unlocked_tool_count()
		active = int(_player.active_tool)
	for i in _tool_bar_buttons.size():
		var b := _tool_bar_buttons[i]
		var open := i < unlocked
		b.visible = open
		b.disabled = not open
		if open:
			b.text = "%d %s" % [i + 1, PlayerCharacter3D.TOOL_ICONS[i]]
			b.tooltip_text = PlayerCharacter3D.TOOL_LABELS[i]
			b.button_pressed = (i == active)
			b.modulate = Color(1.0, 0.95, 0.55) if i == active else Color(0.75, 0.78, 0.82)


func _on_junk_eaten(world_pos: Vector3) -> void:
	if _score != null:
		_score.on_junk()
	if _room_timer != null and _room_timer.is_active():
		_room_timer.on_clean()
	_spawn_pop("+80 🍔", Color(1.0, 0.75, 0.35), 72)
	if _camera_rig != null:
		_camera_rig.punch_fov(4.0)
		_camera_rig.shake(0.45)
	if _stress != null:
		_stress.reduce_stress(6.0)
		_stress.add_delayed_stress(14.0, 1.8)
	if _particles != null:
		_particles.burst(&"clean", world_pos + Vector3(0, 0.8, 0), 1.2)
	if _hint != null and _player != null:
		var prog := _player.get_junk_powerup_progress()
		if prog == 0:
			_hint.text = "Afiyet! Şişiyorsun… (3. yemede power-up)"
		else:
			_hint.text = "Afiyet! Şişiyorsun… power-up'a %d abur cubur" % (_player.junk_powerup_every - prog)
	if _scrap_director != null and _player != null and _player.has_method("is_dancing") \
			and bool(_player.call("is_dancing")):
		_scrap_director.try_secret("dance_junk", world_pos)


func _on_junk_powerup(kind: StringName) -> void:
	if kind == &"speed_rush":
		_spawn_pop("⚡ HIZ!", Color(0.45, 0.95, 1.0), 88)
		if _camera_rig != null:
			_camera_rig.punch_fov(7.0)
			_camera_rig.shake(0.35)
		if _banner != null and not _tutorial_banner_sticky:
			_banner.show_task("HIZ PATLAMASI", Color(0.4, 0.9, 1.0), "Koş + taşı hızlandı!", "")
		if _hint != null:
			_hint.text = "⚡ Hız + taşıma boost — ~9 sn"
		if _room_timer != null and _room_timer.is_active():
			_room_timer.add_time(2.0)
		return
	if kind == &"scene_sweep":
		_spawn_pop("🌪️ SÜPÜR!", Color(0.95, 0.85, 0.35), 92)
		if _camera_rig != null:
			_camera_rig.punch_fov(10.0)
			_camera_rig.shake(0.85)
		if _banner != null:
			_banner.show_task("SÜPÜRGE FIRTINASI", Color(1.0, 0.75, 0.3), "Tüm sahne temizleniyor!", "")
		if _hint != null:
			_hint.text = "🌪️ Tek seferde silip süpürdü!"
		if _particles != null and _player != null:
			_particles.burst(&"clean", _player.global_position + Vector3(0, 1.0, 0), 2.4)
		if _spawner != null:
			_spawner.sweep_all_objectives()
		if _stress != null:
			_stress.reduce_stress(20.0)


func _on_wrong_tool(_needed: String) -> void:
	if _stress != null:
		_stress.add_stress(4.0)
	PrototypeSfx.play(_ui_sfx, PrototypeSfx.Kind.TASK_FAIL, 0.8)


func _on_floor_scrubbed(world_pos: Vector3) -> void:
	if _hazards != null:
		_hazards.notify_scrub_cleaned(world_pos)
	if _hint != null:
		_hint.text = "Zemin kaygan — dikkat!"
	# mop_scrubs: item_disposed (wet/slime/…) üzerinden — çift sayım yok


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
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	# Seviye seçim menüsü / fail / sonuç / kart — Esc ile ölü sahneye dönme
	if _boot_on_title:
		return
	if _scrap_revealing:
		return
	if _menu_open:
		return
	if _level_failing:
		return
	if _result_ui != null and _result_ui.visible:
		return
	if _world_clear_ui != null and _world_clear_ui.visible:
		return
	if _countdown_ui != null and _countdown_ui.visible:
		return
	if _commission_card != null and _commission_card.visible:
		return
	_toggle_game_pause()


func _ensure_pause_overlay() -> void:
	if _pause_overlay != null:
		return
	var ui := get_node_or_null("UI") as CanvasLayer
	if ui == null:
		return
	_pause_overlay = Control.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.visible = false
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(_pause_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.07, 0.1, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.add_child(dim)

	var title := Label.new()
	title.text = "DURAKLATILDI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_right = 1.0
	title.offset_top = 220.0
	title.offset_bottom = 280.0
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.55))
	_pause_overlay.add_child(title)

	var sub := Label.new()
	sub.text = "Esc · devam"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_right = 1.0
	sub.offset_top = 290.0
	sub.offset_bottom = 330.0
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	_pause_overlay.add_child(sub)

	var resume := Button.new()
	resume.text = "Devam"
	resume.focus_mode = Control.FOCUS_NONE
	resume.anchor_left = 0.5
	resume.anchor_right = 0.5
	resume.offset_left = -140.0
	resume.offset_right = 140.0
	resume.offset_top = 360.0
	resume.offset_bottom = 410.0
	resume.pressed.connect(func() -> void: _set_game_paused(false))
	_pause_overlay.add_child(resume)

	var to_menu := Button.new()
	to_menu.text = "Ana Menü"
	to_menu.focus_mode = Control.FOCUS_NONE
	to_menu.anchor_left = 0.5
	to_menu.anchor_right = 0.5
	to_menu.offset_left = -140.0
	to_menu.offset_right = 140.0
	to_menu.offset_top = 424.0
	to_menu.offset_bottom = 470.0
	to_menu.pressed.connect(_pause_quit_to_menu)
	_pause_overlay.add_child(to_menu)


func _toggle_game_pause() -> void:
	_set_game_paused(not _game_paused)


func _set_game_paused(on: bool) -> void:
	if on and (_menu_open or _level_failing or _boot_on_title or _scrap_revealing):
		return
	_game_paused = on
	_ensure_pause_overlay()
	if _pause_overlay != null:
		_pause_overlay.visible = on
	if on:
		if _player != null and _player.has_method("_release_vacuum"):
			_player.call("_release_vacuum")
		_paused_room_timer = false
		if _room_timer != null and _room_timer.is_active():
			_room_timer.pause()
			_paused_room_timer = true
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if _paused_room_timer and _room_timer != null:
			_room_timer.resume()
		_paused_room_timer = false
		get_tree().paused = false


func _pause_quit_to_menu() -> void:
	_set_game_paused(false)
	_show_menu(true)


func _load_progress() -> void:
	# Tüm seviyeler açık (dev / test) — coin + can kalıcı
	_highest_unlocked = LevelData3D.level_count()
	var cfg := ConfigFile.new()
	if cfg.load(_save_path) == OK:
		_pending_wallet_coins = maxi(0, int(cfg.get_value("wallet", "coins", 0)))
		_pending_lives = clampi(int(cfg.get_value("lives", "count", Lives3D.START_LIVES)), 0, Lives3D.MAX_LIVES)
		_pending_life_coin_progress = clampi(
			int(cfg.get_value("lives", "coin_progress", 0)), 0, Lives3D.COINS_PER_LIFE - 1
		)
		var scrap_var: Variant = cfg.get_value("scraps", "found", PackedStringArray())
		if scrap_var is PackedStringArray:
			_pending_scrap_ids = scrap_var
		elif scrap_var is Array:
			_pending_scrap_ids = PackedStringArray()
			for x in scrap_var as Array:
				_pending_scrap_ids.append(String(x))
		_level_badges.clear()
		if cfg.has_section("badges"):
			for key in cfg.get_section_keys("badges"):
				_level_badges[String(key)] = clampi(int(cfg.get_value("badges", key, 0)), 0, 3)
	else:
		_pending_lives = Lives3D.START_LIVES
		_pending_life_coin_progress = 0
	if _wallet != null and _pending_wallet_coins >= 0:
		_wallet.set_balance(_pending_wallet_coins)
		_pending_wallet_coins = -1
	if _lives != null and _pending_lives >= 0:
		_lives.set_state(_pending_lives, maxi(0, _pending_life_coin_progress))
		_pending_lives = -1
		_pending_life_coin_progress = -1
	if _scrap_collection != null and not _pending_scrap_ids.is_empty():
		_scrap_collection.load_ids(_pending_scrap_ids)
		_pending_scrap_ids.clear()


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_save_path)  # mevcut anahtarları koru
	cfg.set_value("progress", "unlocked", _highest_unlocked)
	var coins := 0
	if _wallet != null:
		coins = _wallet.get_balance()
	elif _pending_wallet_coins >= 0:
		coins = _pending_wallet_coins
	cfg.set_value("wallet", "coins", coins)
	var lives_n := Lives3D.START_LIVES
	var prog := 0
	if _lives != null:
		lives_n = _lives.get_lives()
		prog = _lives.get_coin_progress()
	elif _pending_lives >= 0:
		lives_n = _pending_lives
		prog = maxi(0, _pending_life_coin_progress)
	cfg.set_value("lives", "count", lives_n)
	cfg.set_value("lives", "coin_progress", prog)
	var scrap_ids: PackedStringArray = PackedStringArray()
	if _scrap_collection != null:
		scrap_ids = _scrap_collection.save_ids()
	elif not _pending_scrap_ids.is_empty():
		scrap_ids = _pending_scrap_ids
	cfg.set_value("scraps", "found", scrap_ids)
	if cfg.has_section("badges"):
		cfg.erase_section("badges")
	for k in _level_badges.keys():
		cfg.set_value("badges", String(k), int(_level_badges[k]))
	cfg.save(_save_path)
