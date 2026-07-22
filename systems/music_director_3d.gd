class_name MusicDirector3D
extends Node

## Lantern Drop (veya aday isimler) + dinamik tempo.
## Faz eşiğinde / loop sonunda: yavaşlat → hızla yükselt (drop-rush).
## Intensity sürekli yükselir — daha upbeat, hızlı his.

signal intensity_changed(layer: int)

const MUSIC_DIR := "res://audio/music/"
const MAIN_CANDIDATES: Array[String] = [
	"Lantern Drop",
	"laterndrop",
	"LanternDrop",
	"lantern_drop",
	"gameplay",
]
const LAYER_BASENAMES: Array[String] = ["gameplay_1", "gameplay_2", "gameplay_3"]
const EXT_CANDIDATES: Array[String] = [".ogg", ".wav", ".mp3", ".WAV", ".OGG", ".MP3"]

const MIX_RATE := 22050
const LOOP_BEATS := 8
const BASE_BPM := 108.0

## Faz baz pitch (upbeat taban yüksek)
const PITCH_PHASE := {1: 1.06, 2: 1.16, 3: 1.30}
const DROP_PITCH := 0.72
const RUSH_OVERSHOOT := 1.14

var _layers: Array[AudioStreamPlayer] = []
var _target_db: Array[float] = [-80.0, -80.0, -80.0]
var _phase: int = 1
var _playing: bool = false
var _master_db: float = -12.0
var _using_custom: bool = false
var _single_track: bool = false

var _intensity: float = 0.0
var _heat: float = 0.0
var _heat_clock: float = 0.0
var _pitch_current: float = 1.06
var _pitch_settle: float = 1.06
var _hit_busy: bool = false
var _hit_tween: Tween
var _loop_end_armed: bool = true
var _main_player: AudioStreamPlayer


func _ready() -> void:
	GameAudioBank.ensure_ready()
	var custom := _try_load_custom_tracks()
	if custom.is_empty():
		_using_custom = false
		_single_track = false
		for i in 3:
			_add_player(i, GameAudioBank.get_music_layer(i))
	else:
		_using_custom = true
		_single_track = custom.size() == 1
		for i in custom.size():
			_add_player(i, custom[i])
		while _layers.size() < 3 and not _single_track:
			_add_player(_layers.size(), custom[mini(_layers.size(), custom.size() - 1)])
	if not _layers.is_empty():
		_main_player = _layers[0]


func _add_player(index: int, stream: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.name = "MusicLayer%d" % (index + 1)
	p.bus = &"Master"
	p.volume_db = -80.0
	if stream != null:
		_enable_loop(stream)
		p.stream = stream
	else:
		p.stream = _build_loop(index)
	add_child(p)
	_layers.append(p)


func _try_load_custom_tracks() -> Array[AudioStream]:
	var layered: Array[AudioStream] = []
	for base in LAYER_BASENAMES:
		var s := _load_named(base)
		if s != null:
			layered.append(s)
	if layered.size() >= 1:
		return layered
	var main: AudioStream = null
	for base in MAIN_CANDIDATES:
		main = _load_named(base)
		if main != null:
			break
	if main != null:
		return [main] as Array[AudioStream]
	return []


func _load_named(basename: String) -> AudioStream:
	for ext in EXT_CANDIDATES:
		var path := MUSIC_DIR + basename + ext
		if ResourceLoader.exists(path):
			var res := load(path)
			if res is AudioStream:
				print("[MusicDirector3D] loaded ", path)
				return res as AudioStream
	return null


func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		if wav.data.size() > 0:
			wav.loop_end = int(wav.data.size() / (4 if wav.stereo else 2))


func _process(delta: float) -> void:
	if not _playing:
		return
	for i in _layers.size():
		var p: AudioStreamPlayer = _layers[i]
		var target := _target_db[mini(i, _target_db.size() - 1)]
		p.volume_db = lerpf(p.volume_db, target, clampf(4.0 * delta, 0.0, 1.0))

	_heat_clock += delta
	# Heat varken loop-hit kapalı — heat pitch'i bozmasın
	if _heat < 0.08:
		_update_loop_end_hit()
	if _hit_busy and _heat < 0.12:
		return

	# Heat > 0: müzik yavaş + detune; heat düşünce normale döner
	var climb := lerpf(0.0, 0.06, _intensity)
	var base := _pitch_settle + climb
	var heat_eased := _heat * _heat # daha hissedilir slow
	var slow_mult := lerpf(1.0, 0.52, heat_eased)
	var detune := sin(_heat_clock * (5.0 + _heat * 14.0)) * _heat * 0.045
	var want := base * slow_mult + detune
	# Hata anında hızlı yavaşla; soğurken yumuşak toparla
	var follow := 10.0 if _heat > 0.35 else 3.2
	_pitch_current = lerpf(_pitch_current, want, clampf(follow * delta, 0.0, 1.0))
	_apply_pitch(_pitch_current)


func _update_loop_end_hit() -> void:
	if not _single_track or _main_player == null or not _main_player.playing:
		return
	var stream := _main_player.stream
	if stream == null:
		return
	var length := stream.get_length()
	if length <= 0.5:
		return
	var pos := _main_player.get_playback_position()
	if pos >= length - 0.42 and _loop_end_armed and not _hit_busy and _heat < 0.1:
		_loop_end_armed = false
		play_coordinated_hit(0.85)
	elif pos < 1.2:
		_loop_end_armed = true


func start(phase: int = 1) -> void:
	_playing = true
	_intensity = 0.0
	_heat = 0.0
	_heat_clock = 0.0
	_hit_busy = false
	_loop_end_armed = true
	for p in _layers:
		if p.stream != null and not p.playing:
			p.play()
	set_phase(phase, false)


func stop(fade: bool = true) -> void:
	_playing = false
	_hit_busy = false
	_heat = 0.0
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	if fade:
		for i in _target_db.size():
			_target_db[i] = -80.0
		for p in _layers:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -80.0, 0.45)
			tw.finished.connect(func() -> void:
				if not _playing and is_instance_valid(p):
					p.stop()
			)
	else:
		for p in _layers:
			p.stop()
			p.volume_db = -80.0


## 0..1 oda ilerlemesi.
func set_intensity(ratio: float) -> void:
	_intensity = clampf(ratio, 0.0, 1.0)


## 0..1 heat / stres — bar yüksekken slow+pitch, düşünce normale.
func set_heat(ratio: float) -> void:
	_heat = clampf(ratio, 0.0, 1.0)


## Her hata: anında yavaşlat; heat bar düşünce toparlanır.
func on_mistake(heat_ratio: float = -1.0) -> void:
	if heat_ratio >= 0.0:
		_heat = clampf(heat_ratio, 0.0, 1.0)
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_busy = false
	var base := float(PITCH_PHASE.get(_phase, 1.06))
	# Anında slow-down
	_pitch_current = minf(_pitch_current, base * lerpf(0.78, 0.55, _heat))
	_apply_pitch(_pitch_current)


func set_phase(phase: int, with_hit: bool = true) -> void:
	_phase = clampi(phase, 1, 3)
	_pitch_settle = float(PITCH_PHASE.get(_phase, 1.06))
	if _single_track:
		_target_db = [_master_db, -80.0, -80.0]
	else:
		match _phase:
			1:
				_target_db = [_master_db, -80.0, -80.0]
			2:
				_target_db = [_master_db + 1.0, _master_db - 1.5, -80.0]
			3:
				_target_db = [_master_db + 2.0, _master_db + 0.5, _master_db - 1.0]
	while _target_db.size() < _layers.size():
		_target_db.append(-80.0)
	# Heat varken faz hit'i atlama — heat pitch öncelikli
	if with_hit and _playing and _heat < 0.12:
		play_coordinated_hit(1.0)
	elif not with_hit:
		_pitch_current = _pitch_settle
		_apply_pitch(_pitch_current)
	intensity_changed.emit(_phase)


## Eşik / loop sonu: yavaşla → hızla yüksel (drop-rush).
func play_coordinated_hit(strength: float = 1.0) -> void:
	strength = clampf(strength, 0.4, 1.25)
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_busy = true
	var drop_to := lerpf(1.0, DROP_PITCH, strength)
	var rush_to := _pitch_settle * lerpf(1.06, RUSH_OVERSHOOT, strength)
	var from := _pitch_current
	_hit_tween = create_tween()
	_hit_tween.tween_method(_apply_pitch, from, drop_to, 0.18 * strength)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hit_tween.tween_method(_apply_pitch, drop_to, rush_to, 0.32)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_method(_apply_pitch, rush_to, _pitch_settle, 0.22)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_callback(func() -> void:
		_hit_busy = false
		_pitch_current = _pitch_settle
	)


## Mikro-görev başarı / combo için kısa enerji bump.
func pulse_upbeat(amount: float = 0.06) -> void:
	if _hit_busy or not _playing or _heat > 0.2:
		return
	var bump := minf(_pitch_current + amount, _pitch_settle + 0.14)
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_busy = true
	_hit_tween = create_tween()
	_hit_tween.tween_method(_apply_pitch, _pitch_current, bump, 0.08)
	_hit_tween.tween_method(_apply_pitch, bump, _pitch_settle + lerpf(0.0, 0.05, _intensity), 0.2)
	_hit_tween.tween_callback(func() -> void:
		_hit_busy = false
	)


func get_phase() -> int:
	return _phase


func _apply_pitch(scale: float) -> void:
	_pitch_current = scale
	for p in _layers:
		p.pitch_scale = scale


func _build_loop(layer: int) -> AudioStreamWAV:
	var bpm := BASE_BPM
	var beat := 60.0 / bpm
	var duration := beat * float(LOOP_BEATS)
	var count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var root_hz := 98.0 if layer == 0 else (196.0 if layer == 1 else 392.0)
	var scale_deg: Array[int] = [0, 3, 5, 7, 10, 12, 15, 17]
	for i in count:
		var t := float(i) / float(MIX_RATE)
		var beat_i := int(t / beat) % LOOP_BEATS
		var beat_pos := fmod(t, beat) / beat
		var sample := 0.0
		if layer == 0:
			var freq := root_hz * pow(2.0, float(scale_deg[beat_i % 4]) / 12.0)
			sample += sin(t * freq * TAU) * exp(-beat_pos * 4.5) * 0.38
			if beat_i % 2 == 0:
				sample += exp(-beat_pos * 18.0) * sin(t * lerpf(120.0, 40.0, beat_pos) * TAU) * 0.42
		elif layer == 1:
			var deg := scale_deg[(beat_i * 2 + int(beat_pos * 2.0)) % scale_deg.size()]
			var freq := root_hz * pow(2.0, float(deg) / 12.0)
			var env := sin(beat_pos * PI) * 0.55
			sample += sin(t * freq * TAU) * env * 0.28
		else:
			if beat_pos < 0.08 or (beat_pos > 0.45 and beat_pos < 0.52):
				sample += (randf() * 2.0 - 1.0) * exp(-fmod(beat_pos, 0.5) * 40.0) * 0.22
			if beat_i % 2 == 1:
				var deg2 := scale_deg[(beat_i + 3) % scale_deg.size()]
				sample += exp(-beat_pos * 8.0) * sin(t * root_hz * pow(2.0, float(deg2) / 12.0) * TAU) * 0.2
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = count
	return wav
