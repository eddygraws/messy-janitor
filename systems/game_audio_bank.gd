class_name GameAudioBank
extends RefCounted

## Kalıcı WAV bankası — ilk çalıştırmada user://messy_audio altına yazar.
## Sonraki açılışlarda dosyadan yükler (gerçek ses dosyası yolu).

const SFX_DIR := "user://messy_audio/sfx"
const MUSIC_DIR := "user://messy_audio/music"

static var _ready_bank: bool = false
static var _sfx: Dictionary = {}
static var _music_layers: Array[AudioStreamWAV] = []


static func ensure_ready() -> void:
	if _ready_bank:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SFX_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MUSIC_DIR))
	_sfx[PrototypeSfx.Kind.HIT] = _sfx_file("hit", _gen_hit())
	_sfx[PrototypeSfx.Kind.PICKUP] = _sfx_file("pickup", _gen_pickup())
	_sfx[PrototypeSfx.Kind.DROP] = _sfx_file("drop", _gen_drop())
	_sfx[PrototypeSfx.Kind.THROW] = _sfx_file("throw", _gen_whoosh())
	_sfx[PrototypeSfx.Kind.DASH] = _sfx_file("dash", _gen_dash())
	_sfx[PrototypeSfx.Kind.RINSE] = _sfx_file("rinse", _gen_rinse())
	_sfx[PrototypeSfx.Kind.DISPOSE] = _sfx_file("dispose", _gen_dispose())
	_sfx[PrototypeSfx.Kind.SWITCH] = _sfx_file("switch", _gen_switch())
	_sfx[PrototypeSfx.Kind.DANCE] = _sfx_file("dance", _gen_dance())
	_sfx[PrototypeSfx.Kind.BUMP] = _sfx_file("bump", _gen_bump())
	_sfx[PrototypeSfx.Kind.TASK] = _sfx_file("task", _gen_task())
	_sfx[PrototypeSfx.Kind.TASK_OK] = _sfx_file("task_ok", _gen_task_ok())
	_sfx[PrototypeSfx.Kind.TASK_FAIL] = _sfx_file("task_fail", _gen_task_fail())
	_sfx[PrototypeSfx.Kind.PHASE] = _sfx_file("phase", _gen_phase())
	_sfx[PrototypeSfx.Kind.STOP] = _sfx_file("stop", _gen_stop())
	_music_layers.clear()
	for i in 3:
		_music_layers.append(_music_file(i, _gen_music_layer(i)))
	_ready_bank = true


static func get_sfx(kind: int) -> AudioStream:
	ensure_ready()
	return _sfx.get(kind, null) as AudioStream


static func get_music_layer(index: int) -> AudioStream:
	ensure_ready()
	if index < 0 or index >= _music_layers.size():
		return null
	return _music_layers[index]


static func _sfx_file(name: String, pcm: PackedByteArray) -> AudioStreamWAV:
	var path := "%s/%s.wav" % [SFX_DIR, name]
	if FileAccess.file_exists(path):
		var loaded := _load_wav_file(path)
		if loaded != null:
			return loaded
	_save_wav_file(path, pcm, 22050)
	return _pcm_to_stream(pcm, 22050, false)


static func _music_file(layer: int, pcm: PackedByteArray) -> AudioStreamWAV:
	var path := "%s/layer_%d.wav" % [MUSIC_DIR, layer]
	if FileAccess.file_exists(path):
		var loaded := _load_wav_file(path)
		if loaded != null:
			loaded.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loaded.loop_begin = 0
			loaded.loop_end = floori(float(loaded.data.size()) * 0.5)
			return loaded
	_save_wav_file(path, pcm, 22050)
	return _pcm_to_stream(pcm, 22050, true)


static func _pcm_to_stream(pcm: PackedByteArray, rate: int, loop: bool) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = pcm
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = floori(float(pcm.size()) * 0.5)
	return s


static func _save_wav_file(path: String, pcm: PackedByteArray, rate: int) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	var data_size := pcm.size()
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data_size)
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(1)
	f.store_32(rate)
	f.store_32(rate * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data_size)
	f.store_buffer(pcm)
	f.close()


static func _load_wav_file(path: String) -> AudioStreamWAV:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var bytes := f.get_buffer(f.get_length())
	f.close()
	if bytes.size() < 44:
		return null
	var rate := 22050
	if bytes.size() >= 28:
		rate = bytes.decode_u32(24)
	return _pcm_to_stream(bytes.slice(44), rate, false)


static func _write_s16(data: PackedByteArray, i: int, sample: float) -> void:
	data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))


static func _alloc(count: int) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(count * 2)
	return data


static func _gen_hit() -> PackedByteArray:
	return _tone_pcm(190.0, 0.08, 0.4, true)

static func _gen_pickup() -> PackedByteArray:
	return _chirp_pcm(300.0, 560.0, 0.09, 0.32)

static func _gen_drop() -> PackedByteArray:
	return _tone_pcm(130.0, 0.1, 0.34, true)

static func _gen_whoosh() -> PackedByteArray:
	return _noise_pcm(0.13, 0.28, false)

static func _gen_dash() -> PackedByteArray:
	return _noise_pcm(0.11, 0.26, false)

static func _gen_rinse() -> PackedByteArray:
	return _noise_pcm(0.18, 0.24, true)

static func _gen_dispose() -> PackedByteArray:
	return _chirp_pcm(240.0, 110.0, 0.14, 0.34)

static func _gen_switch() -> PackedByteArray:
	return _tone_pcm(520.0, 0.045, 0.22, false)

static func _gen_dance() -> PackedByteArray:
	return _chirp_pcm(260.0, 700.0, 0.12, 0.34)

static func _gen_bump() -> PackedByteArray:
	return _tone_pcm(85.0, 0.14, 0.5, true)

static func _gen_task() -> PackedByteArray:
	return _chirp_pcm(460.0, 760.0, 0.1, 0.42)

static func _gen_task_ok() -> PackedByteArray:
	return _chirp_pcm(340.0, 920.0, 0.14, 0.38)

static func _gen_task_fail() -> PackedByteArray:
	return _tone_pcm(70.0, 0.32, 0.58, true)

static func _gen_phase() -> PackedByteArray:
	return _chirp_pcm(180.0, 640.0, 0.16, 0.4)

static func _gen_stop() -> PackedByteArray:
	return _tone_pcm(48.0, 0.26, 0.55, true)


static func _tone_pcm(freq: float, duration: float, vol: float, thud: bool) -> PackedByteArray:
	var rate := 22050
	var count := maxi(1, int(rate * duration))
	var data := _alloc(count)
	for i in count:
		var t := float(i) / float(rate)
		var env := 1.0 - t / duration
		if thud:
			env *= exp(-t * 18.0)
		var sample := sin(t * freq * TAU) * env
		if thud:
			sample += sin(t * freq * 0.5 * TAU) * env * 0.45
		_write_s16(data, i, sample * vol)
	return data


static func _chirp_pcm(f0: float, f1: float, duration: float, vol: float) -> PackedByteArray:
	var rate := 22050
	var count := maxi(1, int(rate * duration))
	var data := _alloc(count)
	for i in count:
		var u := float(i) / float(count)
		var t := float(i) / float(rate)
		var freq := lerpf(f0, f1, u)
		_write_s16(data, i, sin(t * freq * TAU) * sin(u * PI) * vol)
	return data


static func _noise_pcm(duration: float, vol: float, watery: bool) -> PackedByteArray:
	var rate := 22050
	var count := maxi(1, int(rate * duration))
	var data := _alloc(count)
	var state := 17.0
	var prev := 0.0
	for i in count:
		var u := float(i) / float(count)
		var env := sin(u * PI) if not watery else pow(1.0 - u, 0.55)
		state = fmod(state * 1103515245.0 + 12345.0, 2147483647.0)
		var noise := (state / 2147483647.0) * 2.0 - 1.0
		if watery:
			prev = lerpf(prev, noise, 0.35)
			noise = prev
		_write_s16(data, i, noise * env * vol)
	return data


static func _gen_music_layer(layer: int) -> PackedByteArray:
	var rate := 22050
	var bpm := 100.0
	var beat := 60.0 / bpm
	var beats := 8
	var duration := beat * float(beats)
	var count := int(rate * duration)
	var data := _alloc(count)
	var root := 98.0 if layer == 0 else (196.0 if layer == 1 else 392.0)
	var scale_deg: Array[int] = [0, 3, 5, 7, 10, 12, 15, 17]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42 + layer * 97
	for i in count:
		var t := float(i) / float(rate)
		var beat_i := floori(t / beat) % beats
		var beat_pos := fmod(t, beat) / beat
		var sample := 0.0
		if layer == 0:
			var freq := root * pow(2.0, float(scale_deg[beat_i % 4]) / 12.0)
			sample += sin(t * freq * TAU) * exp(-beat_pos * 4.2) * 0.36
			if beat_i % 2 == 0:
				sample += exp(-beat_pos * 16.0) * sin(t * lerpf(130.0, 40.0, beat_pos) * TAU) * 0.4
		elif layer == 1:
			var deg := scale_deg[(beat_i * 2 + floori(beat_pos * 2.0)) % scale_deg.size()]
			var freq := root * pow(2.0, float(deg) / 12.0)
			var env := sin(beat_pos * PI) * 0.5
			sample += sin(t * freq * TAU) * env * 0.26
			sample += sin(t * freq * 2.0 * TAU) * env * 0.08
		else:
			if beat_pos < 0.08 or (beat_pos > 0.45 and beat_pos < 0.52):
				sample += (rng.randf() * 2.0 - 1.0) * exp(-fmod(beat_pos, 0.5) * 38.0) * 0.2
			if beat_i % 2 == 1:
				var deg2 := scale_deg[(beat_i + 3) % scale_deg.size()]
				var freq2 := root * pow(2.0, float(deg2) / 12.0)
				sample += exp(-beat_pos * 8.0) * sin(t * freq2 * TAU) * 0.18
		_write_s16(data, i, sample)
	return data
