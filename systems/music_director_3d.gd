class_name MusicDirector3D
extends Node

## Önce res://audio/music/Lantern Drop.wav (veya aday isimler); yoksa procedural bank.
## Tek parça fazda pitch: 1.0 → 1.08 → 1.18
## İsteğe bağlı katmanlar: gameplay_1 / gameplay_2 / gameplay_3

signal intensity_changed(layer: int)

const MUSIC_DIR := "res://audio/music/"
## Ana müzik — sırayla denenir (uzantı: .ogg / .wav / .mp3)
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
const BASE_BPM := 96.0

var _layers: Array[AudioStreamPlayer] = []
var _target_db: Array[float] = [-80.0, -80.0, -80.0]
var _phase: int = 1
var _playing: bool = false
var _master_db: float = -14.0
var _using_custom: bool = false
var _single_track: bool = false


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
		# Tek track’te 1 player yeter; faz sadece pitch + volume
		while _layers.size() < 3 and not _single_track:
			_add_player(_layers.size(), custom[mini(_layers.size(), custom.size() - 1)])


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
		p.volume_db = lerpf(p.volume_db, target, clampf(3.2 * delta, 0.0, 1.0))


func start(phase: int = 1) -> void:
	_playing = true
	for p in _layers:
		if p.stream != null and not p.playing:
			p.play()
	set_phase(phase)


func stop(fade: bool = true) -> void:
	_playing = false
	if fade:
		for i in _target_db.size():
			_target_db[i] = -80.0
		for p in _layers:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -80.0, 0.55)
			tw.finished.connect(func() -> void:
				if not _playing and is_instance_valid(p):
					p.stop()
			)
	else:
		for p in _layers:
			p.stop()
			p.volume_db = -80.0


func set_phase(phase: int) -> void:
	_phase = clampi(phase, 1, 3)
	if _single_track:
		# Tek dosya: volume sabit, pitch fazla artar
		_target_db = [_master_db, -80.0, -80.0]
		match _phase:
			1:
				_set_pitch(1.0)
			2:
				_set_pitch(1.08)
			3:
				_set_pitch(1.18)
	else:
		match _phase:
			1:
				_target_db = [_master_db, -80.0, -80.0]
				_set_pitch(1.0)
			2:
				_target_db = [_master_db + 1.0, _master_db - 2.0, -80.0]
				_set_pitch(1.08)
			3:
				_target_db = [_master_db + 2.0, _master_db, _master_db - 1.5]
				_set_pitch(1.18)
	# Hedef dizisini katman sayısına uydur
	while _target_db.size() < _layers.size():
		_target_db.append(-80.0)
	intensity_changed.emit(_phase)


func get_phase() -> int:
	return _phase


func _set_pitch(scale: float) -> void:
	for p in _layers:
		p.pitch_scale = scale


func _build_loop(layer: int) -> AudioStreamWAV:
	var bpm := BASE_BPM
	var beat := 60.0 / bpm
	var duration := beat * float(LOOP_BEATS)
	var count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)

	var root_hz := 110.0
	match layer:
		0:
			root_hz = 98.0
		1:
			root_hz = 196.0
		2:
			root_hz = 392.0

	var scale_deg: Array[int] = [0, 3, 5, 7, 10, 12, 15, 17]
	for i in count:
		var t := float(i) / float(MIX_RATE)
		var beat_i := int(t / beat) % LOOP_BEATS
		var beat_pos := fmod(t, beat) / beat
		var sample := 0.0

		if layer == 0:
			var bass_note := scale_deg[beat_i % 4]
			var freq := root_hz * pow(2.0, float(bass_note) / 12.0)
			var env_b := exp(-beat_pos * 4.5)
			sample += sin(t * freq * TAU) * env_b * 0.38
			if beat_i % 2 == 0:
				var kick := exp(-beat_pos * 18.0) * sin(t * lerpf(120.0, 40.0, beat_pos) * TAU)
				sample += kick * 0.42
		elif layer == 1:
			var deg := scale_deg[(beat_i * 2 + int(beat_pos * 2.0)) % scale_deg.size()]
			var freq := root_hz * pow(2.0, float(deg) / 12.0)
			var env := sin(beat_pos * PI) * 0.55
			sample += sin(t * freq * TAU) * env * 0.28
			sample += sin(t * freq * 2.0 * TAU) * env * 0.08
		else:
			var hat := 0.0
			if beat_pos < 0.08 or (beat_pos > 0.45 and beat_pos < 0.52):
				hat = (randf() * 2.0 - 1.0) * exp(-fmod(beat_pos, 0.5) * 40.0) * 0.22
			sample += hat
			var deg2 := scale_deg[(beat_i + 3) % scale_deg.size()]
			var freq2 := root_hz * pow(2.0, float(deg2) / 12.0)
			var stab := exp(-beat_pos * 8.0) * sin(t * freq2 * TAU) * 0.2
			if beat_i % 2 == 1:
				sample += stab

		sample = clampf(sample, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = count
	return wav
