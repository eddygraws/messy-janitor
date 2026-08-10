class_name MicroTaskDirector
extends Node

## WarioWare tarzı anlık emirler.
## Faz1: AT!/SİL!/TOPLA!  ·  Faz2: SEÇ!/ÇİFTE!/KAÇ!  ·  Faz3: DUR!/HEPSİNİ AT!/SON KUTU!

signal task_issued(task_type: String, duration: float, color: Color)
signal task_succeeded(task_type: String, star_units: int)
signal task_failed(task_type: String)
signal task_cleared
## DUR! verilmeden önce 3 → 2 → 1 (saniye kalan).
signal stop_countdown_tick(seconds_left: int)

const TASK_THROW := "throw"
const TASK_SCRUB := "scrub"
const TASK_GATHER := "gather"
const TASK_CHOOSE := "choose"
const TASK_DOUBLE := "double"
const TASK_DODGE := "dodge"
const TASK_STOP := "stop"
const TASK_ALL := "all"
const TASK_LAST := "last"

@export var enabled: bool = true
@export var first_task_delay: float = 4.0
@export var base_interval: float = 11.0
@export var task_duration: float = 3.8
@export var gather_count: int = 2
@export var dodge_radius: float = 1.85
@export var unlock_dodge_level: int = 0
@export var min_task_duration: float = 3.0
@export var max_task_duration: float = 4.2

var _tempo: TempoPhaseDirector
var _spawner: Node
var _player: Node
var _cooldown: float = 0.0
var _task_time_left: float = 0.0
var _active: Dictionary = {}
var _targets: Array[ClutterProp] = []
var _decoys: Array[ClutterProp] = []
var _choose_correct: ClutterProp
var _active_star_units: int = 0
var _last_types: Array[String] = []
var _running: bool = false
var _stop_grace: float = 0.0
var _dodge_zone: Node3D
var _dodge_center: Vector3 = Vector3.ZERO
var _dodge_escaped: bool = false
var _level_index: int = 0
var _chaos: float = 0.0
var _boss_mode: String = ""
var _curse_interval_mult: float = 1.0
var _curse_duration_mult: float = 1.0
var _curse_stop_freq: float = 1.0
var _diff_interval_mult: float = 1.0
var _diff_duration_mult: float = 1.0
var _timing_base_interval: float = 9.0
var _timing_base_duration: float = 3.6
var _timing_base_min: float = 2.6
var _timing_base_max: float = 3.8
var _stop_countdown: float = -1.0
var _stop_countdown_shown: int = -1
var _pending_stop_duration: float = 3.2
const STOP_COUNTDOWN_SECONDS := 3.0


func setup(tempo: TempoPhaseDirector, spawner: Node, player: Node = null) -> void:
	_tempo = tempo
	_spawner = spawner
	_player = player
	if _tempo != null and not _tempo.tempo_phase_changed.is_connected(_on_phase_changed):
		_tempo.tempo_phase_changed.connect(_on_phase_changed)
	_bind_player()


## Adventure seviye eğrisi: tempo aynı; emirler her seviyede faz havuzuna uyar.
func configure_for_level(level_index: int) -> void:
	_level_index = maxi(0, level_index)
	_chaos = clampf(float(_level_index) / 45.0, 0.0, 1.0)
	_boss_mode = ""
	first_task_delay = lerpf(3.6, 2.4, _chaos)
	_timing_base_interval = lerpf(9.5, 6.5, _chaos)
	_timing_base_duration = lerpf(3.6, 3.1, _chaos)
	_timing_base_min = 2.6
	_timing_base_max = 3.8
	gather_count = 2 if _level_index < 12 else 3
	_reapply_curse_to_timing()


## Tutorial son bölüm: yavaş emir temposu (ısınma).
func configure_tutorial_tempo() -> void:
	_level_index = 0
	_chaos = 0.0
	_boss_mode = ""
	first_task_delay = 5.5
	_timing_base_interval = 12.5
	_timing_base_duration = 4.6
	_timing_base_min = 3.6
	_timing_base_max = 5.0
	gather_count = 2
	_reapply_curse_to_timing()


func configure_boss_mode(mode: String) -> void:
	_boss_mode = mode
	first_task_delay = 1.4
	_timing_base_interval = 4.2
	_timing_base_duration = 2.8
	_timing_base_min = 2.2
	_timing_base_max = 3.2
	gather_count = 3
	match mode:
		"box_rain":
			_timing_base_interval = 3.6
		"mega_scrub":
			_timing_base_interval = 4.0
		"ritual_rush":
			_timing_base_interval = 3.8
		_:
			pass
	_reapply_curse_to_timing()


func apply_curse_mods(interval_mult: float, duration_mult: float, stop_freq: float) -> void:
	_curse_interval_mult = interval_mult
	_curse_duration_mult = duration_mult
	_curse_stop_freq = stop_freq
	_reapply_curse_to_timing()


func clear_curse_mods() -> void:
	_curse_interval_mult = 1.0
	_curse_duration_mult = 1.0
	_curse_stop_freq = 1.0
	_reapply_curse_to_timing()


func apply_difficulty_mult(interval_mult: float, duration_mult: float) -> void:
	_diff_interval_mult = interval_mult
	_diff_duration_mult = duration_mult
	_reapply_curse_to_timing()


func _reapply_curse_to_timing() -> void:
	base_interval = maxf(2.8, _timing_base_interval * _curse_interval_mult * _diff_interval_mult)
	task_duration = clampf(_timing_base_duration * _curse_duration_mult * _diff_duration_mult, 2.0, 5.5)
	min_task_duration = clampf(_timing_base_min * _curse_duration_mult * _diff_duration_mult, 1.8, 4.0)
	max_task_duration = clampf(_timing_base_max * _curse_duration_mult * _diff_duration_mult, 2.4, 5.5)


func _cap_dur(seconds: float) -> float:
	return clampf(seconds, min_task_duration, max_task_duration)


func _bind_player() -> void:
	if _player == null:
		return
	if _player.has_signal("item_disposed") and not _player.item_disposed.is_connected(_on_player_disposed):
		_player.item_disposed.connect(_on_player_disposed)
	if _player.has_signal("interact_attempted") and not _player.interact_attempted.is_connected(_on_player_interact):
		_player.interact_attempted.connect(_on_player_interact)


func start_session() -> void:
	_clear_task(false)
	_cancel_stop_countdown()
	_running = true
	_cooldown = first_task_delay
	_last_types.clear()
	_bind_player()


func stop_session() -> void:
	_running = false
	_cancel_stop_countdown()
	_clear_task(false)


func is_stop_countdown_active() -> bool:
	return _stop_countdown >= 0.0


func get_stop_countdown_left() -> float:
	return maxf(0.0, _stop_countdown)


func get_task_time_left() -> float:
	return maxf(0.0, _task_time_left)


func get_active_task_type() -> String:
	return String(_active.get("type", ""))


func _on_phase_changed(phase: int) -> void:
	if not _running:
		return
	# Faz değişince emri çabuk getir — özellikle finale hissedilsin
	if _active.is_empty():
		_cooldown = minf(_cooldown, 0.55 if phase >= TempoPhaseDirector.PHASE_FINALE else 1.0)


func _process(delta: float) -> void:
	if not enabled or not _running:
		return
	if _stop_countdown >= 0.0:
		_update_stop_countdown(delta)
		return
	if not _active.is_empty():
		_task_time_left -= delta
		if _stop_grace > 0.0:
			_stop_grace = maxf(0.0, _stop_grace - delta)
		_prune_dead_targets()
		_check_choose_fail()
		_update_dodge_state()
		if _active.is_empty():
			return
		if _is_task_complete():
			_succeed()
			return
		if _task_time_left <= 0.0:
			# DUR!: süre dolunca başarı (hiç dokunmadıysa)
			if String(_active.get("type", "")) == TASK_STOP:
				_succeed()
			else:
				_fail()
			return
		return

	_cooldown -= delta
	if _cooldown <= 0.0:
		_try_issue_task()


func _update_stop_countdown(delta: float) -> void:
	_stop_countdown -= delta
	var shown := maxi(1, int(ceil(_stop_countdown)))
	if _stop_countdown <= 0.0:
		_stop_countdown = -1.0
		_stop_countdown_shown = -1
		_begin_stop_task(_pending_stop_duration)
		return
	if shown != _stop_countdown_shown:
		_stop_countdown_shown = shown
		stop_countdown_tick.emit(shown)


func _cancel_stop_countdown() -> void:
	_stop_countdown = -1.0
	_stop_countdown_shown = -1
	_pending_stop_duration = 0.0


func _begin_stop_task(duration: float) -> void:
	_stop_grace = 0.45
	_commit_active(TASK_STOP, duration)


func _on_player_disposed(_prop_id: String) -> void:
	if _active.is_empty():
		return
	if String(_active.get("type", "")) == TASK_STOP and _stop_grace <= 0.0:
		_fail()


func _on_player_interact() -> void:
	if _active.is_empty():
		return
	if String(_active.get("type", "")) == TASK_STOP and _stop_grace <= 0.0:
		_fail()


func get_time_ratio() -> float:
	if _stop_countdown >= 0.0:
		return clampf(_stop_countdown / STOP_COUNTDOWN_SECONDS, 0.0, 1.0)
	if _active.is_empty():
		return 0.0
	var dur := float(_active.get("duration", task_duration))
	return clampf(_task_time_left / maxf(dur, 0.01), 0.0, 1.0)


func has_active_task() -> bool:
	return not _active.is_empty() or _stop_countdown >= 0.0


func _try_issue_task() -> void:
	var phase := TempoPhaseDirector.PHASE_WARMUP
	if _tempo != null:
		phase = _tempo.get_phase()
	# Boss odası: her zaman finale emir havuzu
	if not _boss_mode.is_empty():
		phase = TempoPhaseDirector.PHASE_FINALE
	var pool := _pool_for_phase(phase)
	var choice := _pick_weighted(pool)
	if choice.is_empty():
		_cooldown = 2.5
		return
	if not _issue(String(choice.get("type", "")), float(choice.get("duration", task_duration))):
		_cooldown = 1.5


func _pool_for_phase(phase: int) -> Array[Dictionary]:
	var dur := _cap_dur(task_duration)
	var dodge_ok := _level_index >= unlock_dodge_level
	# Erken seviyede kaos emirleri daha hafif ağırlık; kilit yok
	var early := _chaos < 0.35
	match phase:
		TempoPhaseDirector.PHASE_RAMP:
			# Faz 2: SEÇ! / KAÇ! / ÇİFTE! baskın — P1 seyrek baharat
			var ramp: Array[Dictionary] = [
				{"type": TASK_CHOOSE, "weight": 30.0, "duration": _cap_dur(dur + 0.2)},
				{"type": TASK_DOUBLE, "weight": 26.0, "duration": _cap_dur(dur + 0.35)},
				{"type": TASK_THROW, "weight": 6.0, "duration": dur},
				{"type": TASK_SCRUB, "weight": 6.0, "duration": _cap_dur(dur + 0.15)},
				{"type": TASK_GATHER, "weight": 6.0, "duration": _cap_dur(dur + 0.25)},
			]
			if dodge_ok:
				ramp.append({"type": TASK_DODGE, "weight": 28.0, "duration": _cap_dur(3.2)})
			return ramp
		TempoPhaseDirector.PHASE_FINALE:
			# Faz 3: DUR! / HEPSİNİ AT! / SON KUTU! her seviyede
			var all_w := 14.0 if early else 24.0
			var stop_w := (26.0 if early else 18.0) * _curse_stop_freq
			var last_w := 22.0 if early else 20.0
			var finale: Array[Dictionary] = [
				{"type": TASK_ALL, "weight": all_w, "duration": _cap_dur(dur + 0.4)},
				{"type": TASK_STOP, "weight": stop_w, "duration": _cap_dur(3.2)},
				{"type": TASK_LAST, "weight": last_w, "duration": _cap_dur(dur + 0.2)},
				{"type": TASK_CHOOSE, "weight": 8.0, "duration": dur},
				{"type": TASK_DOUBLE, "weight": 8.0, "duration": _cap_dur(dur + 0.2)},
			]
			if dodge_ok:
				finale.append({"type": TASK_DODGE, "weight": 16.0, "duration": _cap_dur(3.0)})
			return finale
		_:
			# Faz 1: AT! / SİL! / TOPLA!
			return [
				{"type": TASK_THROW, "weight": 40.0, "duration": dur},
				{"type": TASK_SCRUB, "weight": 35.0, "duration": _cap_dur(dur + 0.2)},
				{"type": TASK_GATHER, "weight": 25.0, "duration": _cap_dur(dur + 0.3)},
			]


func _pick_weighted(pool: Array[Dictionary]) -> Dictionary:
	var filtered: Array[Dictionary] = []
	for entry in pool:
		var t := String(entry.get("type", ""))
		if t in _last_types:
			continue
		filtered.append(entry)
	if filtered.is_empty():
		filtered = pool
	var total := 0.0
	for e in filtered:
		total += float(e.get("weight", 1.0))
	var roll := randf() * total
	var acc := 0.0
	for e in filtered:
		acc += float(e.get("weight", 1.0))
		if roll <= acc:
			return e
	return filtered.back() if not filtered.is_empty() else {}


func _issue(task_type: String, duration: float) -> bool:
	_targets.clear()
	_decoys.clear()
	_choose_correct = null
	_stop_grace = 0.0

	match task_type:
		TASK_THROW:
			var box := _pick_one("throw")
			if box == null:
				return false
			_targets.append(box)
		TASK_SCRUB:
			var stain := _pick_one("scrub")
			if stain == null:
				return _issue(TASK_THROW, duration)
			_targets.append(stain)
		TASK_GATHER:
			var boxes := _pick_many("throw", gather_count)
			if boxes.size() < 2:
				return _issue(TASK_THROW, duration)
			_targets = boxes
		TASK_CHOOSE:
			var pair := _pick_many("throw", 2)
			if pair.size() < 2:
				return _issue(TASK_THROW, duration)
			_choose_correct = pair[0]
			_targets.append(pair[0])
			_decoys.append(pair[1])
			_mark_target(pair[0], true, "correct")
			_mark_target(pair[1], true, "wrong")
			_commit_active(task_type, duration)
			return true
		TASK_DOUBLE:
			var b := _pick_one("throw")
			var s := _pick_one("scrub")
			if b == null:
				return _issue(TASK_THROW, duration)
			if s == null:
				return _issue(TASK_GATHER, duration)
			_targets.append(b)
			_targets.append(s)
		TASK_DODGE:
			if _player == null or not (_player is Node3D):
				return _issue(TASK_THROW, duration)
			_spawn_dodge_zone((_player as Node3D).global_position)
			_dodge_escaped = false
			_commit_active(task_type, duration)
			return true
		TASK_STOP:
			# 3-2-1 uyarı, sonra DUR! (hedef yok — dokunmama)
			_pending_stop_duration = duration
			_stop_countdown = STOP_COUNTDOWN_SECONDS
			_stop_countdown_shown = 3
			stop_countdown_tick.emit(3)
			return true
		TASK_ALL:
			# Kısa sürede bitirilebilir hedef sayısı
			var want := 3 if _chaos < 0.35 else (4 if _chaos < 0.7 else 5)
			var all_boxes := _pick_many("throw", want)
			if all_boxes.is_empty():
				return _issue(TASK_THROW, duration)
			_targets = all_boxes
		TASK_LAST:
			var far := _pick_farthest("throw")
			if far == null:
				return _issue(TASK_THROW, duration)
			_targets.append(far)
		_:
			return false

	for t in _targets:
		_mark_target(t, true, "correct")
	_commit_active(task_type, duration)
	return true


func _commit_active(task_type: String, duration: float) -> void:
	duration = _boost_duration_for_targets(duration, _targets)
	_active_star_units = 0
	for t in _targets:
		if t != null and is_instance_valid(t):
			_active_star_units += t.get_stack_units()
	_active = {
		"type": task_type,
		"duration": duration,
		"label": _label_for(task_type),
		"color": _color_for(task_type),
	}
	_task_time_left = duration
	_last_types.push_front(task_type)
	while _last_types.size() > 2:
		_last_types.pop_back()
	task_issued.emit(task_type, duration, _color_for(task_type))


## Yıldız sayısıyla doğru orantılı süre: ★ → 1x, ★★ → 2x, ★★★ → 3x (hedeflerin toplam yıldızı).
func _boost_duration_for_targets(base: float, targets: Array) -> float:
	var star_sum := 0
	for t in targets:
		var prop := t as ClutterProp
		if prop == null or not is_instance_valid(prop):
			continue
		star_sum += prop.get_stack_units()
	star_sum = maxi(1, star_sum)
	return maxf(min_task_duration, base * float(star_sum))


func _label_for(task_type: String) -> String:
	match task_type:
		TASK_THROW:
			return "AT!"
		TASK_SCRUB:
			return "SİL!"
		TASK_GATHER:
			return "TOPLA!"
		TASK_CHOOSE:
			return "SEÇ!"
		TASK_DOUBLE:
			return "ÇİFTE!"
		TASK_DODGE:
			return "KAÇ!"
		TASK_STOP:
			return "DUR!"
		TASK_ALL:
			return "HEPSİNİ AT!"
		TASK_LAST:
			return "SON KUTU!"
		_:
			return "HIZLI!"


func _color_for(task_type: String) -> Color:
	match task_type:
		TASK_THROW:
			return Color(1.0, 0.55, 0.18)
		TASK_SCRUB:
			return Color(0.35, 0.75, 1.0)
		TASK_GATHER:
			return Color(0.55, 1.0, 0.4)
		TASK_CHOOSE:
			return Color(1.0, 0.85, 0.2)
		TASK_DOUBLE:
			return Color(0.85, 0.45, 1.0)
		TASK_DODGE:
			return Color(1.0, 0.35, 0.55)
		TASK_STOP:
			return Color(1.0, 0.2, 0.25)
		TASK_ALL:
			return Color(1.0, 0.4, 0.15)
		TASK_LAST:
			return Color(0.95, 0.95, 1.0)
		_:
			return Color.WHITE


func _check_choose_fail() -> void:
	if String(_active.get("type", "")) != TASK_CHOOSE:
		return
	for d in _decoys:
		if d == null or not is_instance_valid(d) or d.is_destroying():
			_fail()
			return


func _is_task_complete() -> bool:
	if _active.is_empty():
		return false
	var t := String(_active.get("type", ""))
	if t == TASK_STOP:
		return false
	if t == TASK_DODGE:
		return _dodge_escaped
	if t == TASK_CHOOSE:
		return _choose_correct == null or not is_instance_valid(_choose_correct) or _choose_correct.is_destroying()
	if _targets.is_empty():
		return true
	for prop in _targets:
		if is_instance_valid(prop) and not prop.is_destroying():
			return false
	return true


func _update_dodge_state() -> void:
	if String(_active.get("type", "")) != TASK_DODGE:
		return
	if _player == null or not (_player is Node3D):
		return
	var flat: Vector3 = (_player as Node3D).global_position - _dodge_center
	flat.y = 0.0
	if flat.length() > dodge_radius + 0.15:
		_dodge_escaped = true


func _spawn_dodge_zone(at: Vector3) -> void:
	_clear_dodge_zone()
	_dodge_center = at
	_dodge_center.y = 0.0
	var zone := Node3D.new()
	zone.name = "DodgeDangerZone"
	zone.position = _dodge_center
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = dodge_radius
	cyl.bottom_radius = dodge_radius
	cyl.height = 0.08
	mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.2, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.25)
	mat.emission_energy_multiplier = 2.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	mesh.position = Vector3(0.0, 0.05, 0.0)
	zone.add_child(mesh)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = dodge_radius - 0.08
	torus.outer_radius = dodge_radius + 0.06
	ring.mesh = torus
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(1.0, 0.4, 0.2, 0.85)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.emission_enabled = true
	rmat.emission = Color(1.0, 0.5, 0.1)
	rmat.emission_energy_multiplier = 3.0
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rmat
	ring.position = Vector3(0.0, 0.12, 0.0)
	zone.add_child(ring)
	var label := Label3D.new()
	label.text = "TEHLİKE"
	label.font_size = 64
	label.modulate = Color(1.0, 0.5, 0.4)
	label.position = Vector3(0.0, 1.2, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	zone.add_child(label)
	var parent: Node = _spawner if _spawner != null else get_tree().current_scene
	parent.add_child(zone)
	_dodge_zone = zone
	var pulse := zone.create_tween().set_loops()
	pulse.tween_property(mat, "albedo_color:a", 0.2, 0.25)
	pulse.tween_property(mat, "albedo_color:a", 0.55, 0.25)


func _clear_dodge_zone() -> void:
	if _dodge_zone != null and is_instance_valid(_dodge_zone):
		_dodge_zone.queue_free()
	_dodge_zone = null
	_dodge_escaped = false


func _prune_dead_targets() -> void:
	var alive: Array[ClutterProp] = []
	for t in _targets:
		if is_instance_valid(t) and not t.is_destroying():
			alive.append(t)
	_targets = alive
	var alive_d: Array[ClutterProp] = []
	for d in _decoys:
		if is_instance_valid(d) and not d.is_destroying():
			alive_d.append(d)
	_decoys = alive_d


func _succeed() -> void:
	var t := String(_active.get("type", ""))
	var stars := _active_star_units
	_clear_task(false)
	task_succeeded.emit(t, stars)
	_schedule_next()


func _fail() -> void:
	if _active.is_empty():
		return
	var t := String(_active.get("type", ""))
	_clear_task(true)
	task_failed.emit(t)
	_schedule_next()


func _schedule_next() -> void:
	var mult := 1.0
	if _tempo != null:
		mult = _tempo.get_task_interval_mult()
	# Gerideyken emirler biraz daha seyrek — toparlanma fırsatı
	var mercy := 1.0
	if _spawner != null and _spawner.has_method("get_remaining_objectives"):
		var rem := int(_spawner.call("get_remaining_objectives"))
		if rem >= 12:
			mercy = 1.35
		elif rem >= 8:
			mercy = 1.18
	_cooldown = base_interval * mult * mercy * randf_range(0.9, 1.15)


func _clear_task(_unmark_fail: bool) -> void:
	for t in _targets:
		if is_instance_valid(t):
			_mark_target(t, false)
	for d in _decoys:
		if is_instance_valid(d):
			_mark_target(d, false)
	_targets.clear()
	_decoys.clear()
	_choose_correct = null
	_clear_dodge_zone()
	_active.clear()
	_active_star_units = 0
	_task_time_left = 0.0
	_stop_grace = 0.0
	task_cleared.emit()


func _mark_target(prop: ClutterProp, on: bool, style: String = "correct") -> void:
	if prop == null or not is_instance_valid(prop):
		return
	prop.set_meta("micro_task_marked", on)
	prop.set_micro_task_highlight(on, style)
	# Eski merge bağlantılarını temizle
	for c in prop.merged_into.get_connections():
		var cb: Callable = c["callable"]
		if cb.get_object() == self:
			prop.merged_into.disconnect(cb)
	if on:
		prop.merged_into.connect(_on_marked_merged.bind(prop, style))


func _on_marked_merged(from: ClutterProp, style: String, host: ClutterProp) -> void:
	if host == null or not is_instance_valid(host) or from == null or _active.is_empty():
		return
	for i in _targets.size():
		if _targets[i] == from:
			_targets[i] = host
	if _choose_correct == from:
		_choose_correct = host
	for i in _decoys.size():
		if _decoys[i] == from:
			_decoys[i] = host
	from.set_meta("micro_task_marked", false)
	_mark_target(host, true, style)


func _matches(kind: String, p: ClutterProp) -> bool:
	if bool(p.get_meta("forbidden", false)):
		return false
	match kind:
		"throw":
			return p.can_carry and String(p.get_meta("deliver_to", "")) == "trash" and not p.requires_scrub
		"scrub":
			return p.requires_scrub
		_:
			return false


func _pick_one(kind: String) -> ClutterProp:
	var many := _pick_many(kind, 1)
	return many[0] if not many.is_empty() else null


func _pick_many(kind: String, max_count: int) -> Array[ClutterProp]:
	var out: Array[ClutterProp] = []
	if _spawner == null:
		return out
	var all: Array = []
	# Spawner çocukları + taşınmayan dünya props
	var nodes: Array = _spawner.get_children()
	for c in nodes:
		var p := c as ClutterProp
		if p == null or p.is_destroying() or p.is_being_carried():
			continue
		if bool(p.get_meta("micro_task_marked", false)):
			continue
		if bool(p.get_meta("forbidden", false)):
			continue
		if _matches(kind, p):
			all.append(p)
	# Oyuncuya yakın olanları hafifçe tercih et (götürülebilir olsun)
	if _player != null and _player is Node3D and all.size() > 1:
		var origin: Vector3 = (_player as Node3D).global_position
		all.sort_custom(func(a: ClutterProp, b: ClutterProp) -> bool:
			return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin)
		)
		# En yakın %60'ı karıştır — tamamen rastgele uzak kutu seçilmesin
		var near_n := maxi(1, int(ceil(float(all.size()) * 0.65)))
		var near: Array = all.slice(0, near_n)
		near.shuffle()
		all = near
	else:
		all.shuffle()
	for i in mini(max_count, all.size()):
		out.append(all[i] as ClutterProp)
	return out


func _pick_farthest(kind: String) -> ClutterProp:
	if _spawner == null or _player == null:
		return _pick_one(kind)
	var best: ClutterProp = null
	var best_d := -1.0
	var origin: Vector3 = (_player as Node3D).global_position
	for c in _spawner.get_children():
		var p := c as ClutterProp
		if p == null or p.is_destroying() or p.is_being_carried():
			continue
		if bool(p.get_meta("forbidden", false)):
			continue
		if not _matches(kind, p):
			continue
		var d := origin.distance_to(p.global_position)
		# Çok uzak (duvar arkası / erişilemez) seçme — oda içinde makul
		if d > 9.5:
			continue
		if d > best_d:
			best_d = d
			best = p
	return best if best != null else _pick_one(kind)
