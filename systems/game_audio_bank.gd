class_name GameAudioBank
extends RefCounted

## Ship SFX bankası: `res://audio/sfx/{kind}.wav` (ogg/mp3 da olur).
## Dosya yoksa kısa orijinal prosedürel yedek. Müzik bu sınıfta üretilmez.

const SFX_DIR := "res://audio/sfx/"
const EXT_CANDIDATES: Array[String] = [".wav", ".ogg", ".mp3", ".WAV", ".OGG", ".MP3"]

const KIND_NAMES: PackedStringArray = [
	"hit", "pickup", "drop", "throw", "dash", "rinse", "dispose", "switch",
	"dance", "bump", "task", "task_ok", "task_fail", "phase", "stop",
]

static var _ready_bank: bool = false
static var _sfx: Dictionary = {}


static func ensure_ready() -> void:
	if _ready_bank:
		return
	for kind in KIND_NAMES.size():
		var name := KIND_NAMES[kind]
		var stream := _load_res_sfx(name)
		if stream == null:
			stream = _procedural_for(kind)
		_sfx[kind] = stream
	_ready_bank = true


static func get_sfx(kind: int) -> AudioStream:
	ensure_ready()
	return _sfx.get(kind, null) as AudioStream


static func get_music_layer(index: int) -> AudioStream:
	## Müzik `MusicDirector3D` + `res://audio/music/`. Burada yedek yok.
	return null


static func _load_res_sfx(name: String) -> AudioStream:
	for ext in EXT_CANDIDATES:
		var path := SFX_DIR + name + ext
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is AudioStream:
				return res as AudioStream
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			var raw := _load_wav_file(abs_path)
			if raw != null:
				return raw
	return null


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
	var channels := 1
	if bytes.size() >= 24:
		channels = bytes.decode_u16(22)
	var bits := 16
	if bytes.size() >= 36:
		bits = bytes.decode_u16(34)
	if channels != 1 or bits != 16:
		return null
	return _pcm_to_stream(bytes.slice(44), rate, false)


static func _write_s16(data: PackedByteArray, i: int, sample: float) -> void:
	data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))


static func _alloc(count: int) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(count * 2)
	return data


static func _procedural_for(kind: int) -> AudioStreamWAV:
	match kind:
		PrototypeSfx.Kind.HIT:
			return _pcm_to_stream(_gen_hit(), 22050, false)
		PrototypeSfx.Kind.PICKUP:
			return _pcm_to_stream(_gen_pickup(), 22050, false)
		PrototypeSfx.Kind.DROP:
			return _pcm_to_stream(_gen_drop(), 22050, false)
		PrototypeSfx.Kind.THROW:
			return _pcm_to_stream(_gen_whoosh(), 22050, false)
		PrototypeSfx.Kind.DASH:
			return _pcm_to_stream(_gen_dash(), 22050, false)
		PrototypeSfx.Kind.RINSE:
			return _pcm_to_stream(_gen_rinse(), 22050, false)
		PrototypeSfx.Kind.DISPOSE:
			return _pcm_to_stream(_gen_dispose(), 22050, false)
		PrototypeSfx.Kind.SWITCH:
			return _pcm_to_stream(_gen_switch(), 22050, false)
		PrototypeSfx.Kind.DANCE:
			return _pcm_to_stream(_gen_dance(), 22050, false)
		PrototypeSfx.Kind.BUMP:
			return _pcm_to_stream(_gen_bump(), 22050, false)
		PrototypeSfx.Kind.TASK:
			return _pcm_to_stream(_gen_task(), 22050, false)
		PrototypeSfx.Kind.TASK_OK:
			return _pcm_to_stream(_gen_task_ok(), 22050, false)
		PrototypeSfx.Kind.TASK_FAIL:
			return _pcm_to_stream(_gen_task_fail(), 22050, false)
		PrototypeSfx.Kind.PHASE:
			return _pcm_to_stream(_gen_phase(), 22050, false)
		PrototypeSfx.Kind.STOP:
			return _pcm_to_stream(_gen_stop(), 22050, false)
		_:
			return _pcm_to_stream(_gen_switch(), 22050, false)


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
