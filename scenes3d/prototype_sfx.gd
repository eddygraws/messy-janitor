class_name PrototypeSfx
extends RefCounted

## Kısa SFX — banka `res://audio/sfx/`, yoksa prosedürel yedek.

enum Kind { HIT, PICKUP, DROP, THROW, DASH, RINSE, DISPOSE, SWITCH, DANCE, BUMP, TASK, TASK_OK, TASK_FAIL, PHASE, STOP }


static func play(player: AudioStreamPlayer, kind: Kind, pitch_scale: float = 1.0) -> void:
	if player == null:
		return
	var bank_stream := GameAudioBank.get_sfx(int(kind))
	player.stream = bank_stream if bank_stream != null else _stream_for(kind)
	player.pitch_scale = clampf(pitch_scale * randf_range(0.94, 1.06), 0.7, 1.4)
	player.play()


static func _stream_for(kind: Kind) -> AudioStreamWAV:
	match kind:
		Kind.HIT:
			return _tone(180.0, 0.07, 0.35, true)
		Kind.PICKUP:
			return _chirp(320.0, 520.0, 0.08, 0.28)
		Kind.DROP:
			return _tone(140.0, 0.09, 0.3, true)
		Kind.THROW:
			return _whoosh(0.12, 0.25)
		Kind.DASH:
			return _whoosh(0.1, 0.22)
		Kind.RINSE:
			return _noise_burst(0.16, 0.22)
		Kind.DISPOSE:
			return _chirp(220.0, 120.0, 0.12, 0.3)
		Kind.SWITCH:
			return _tone(440.0, 0.04, 0.2, false)
		Kind.DANCE:
			return _chirp(280.0, 640.0, 0.11, 0.32)
		Kind.BUMP:
			return _tone(95.0, 0.11, 0.42, true)
		Kind.TASK:
			return _chirp(480.0, 720.0, 0.09, 0.4)
		Kind.TASK_OK:
			return _chirp(360.0, 880.0, 0.12, 0.35)
		Kind.TASK_FAIL:
			return _tone(75.0, 0.28, 0.55, true)
		Kind.PHASE:
			return _chirp(200.0, 600.0, 0.14, 0.38)
		Kind.STOP:
			# DUR!: alçak uyarı — diğer emir chirp'lerinden net ayrılır
			return _tone(55.0, 0.22, 0.5, true)
		_:
			return _tone(200.0, 0.05, 0.2, false)


static func _tone(freq: float, duration: float, vol: float, thud: bool) -> AudioStreamWAV:
	var rate := 22050
	var count := maxi(1, int(rate * duration))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(rate)
		var env := 1.0 - t / duration
		if thud:
			env *= exp(-t * 18.0)
		var sample := sin(t * freq * TAU) * env
		if thud:
			sample += sin(t * freq * 0.5 * TAU) * env * 0.45
		_write_s16(data, i, sample * vol)
	return _make_wav(data, rate)


static func _chirp(f0: float, f1: float, duration: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var count := maxi(1, int(rate * duration))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var u := float(i) / float(count)
		var t := float(i) / float(rate)
		var freq := lerpf(f0, f1, u)
		var env := sin(u * PI)
		_write_s16(data, i, sin(t * freq * TAU) * env * vol)
	return _make_wav(data, rate)


static func _whoosh(duration: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var count := maxi(1, int(rate * duration))
	var data := PackedByteArray()
	data.resize(count * 2)
	var state := 0.0
	for i in count:
		var u := float(i) / float(count)
		var env := sin(u * PI) * (0.35 + 0.65 * (1.0 - u))
		state = fmod(state * 1103515245.0 + 12345.0, 2147483647.0)
		var noise := (state / 2147483647.0) * 2.0 - 1.0
		_write_s16(data, i, noise * env * vol)
	return _make_wav(data, rate)


static func _noise_burst(duration: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var count := maxi(1, int(rate * duration))
	var data := PackedByteArray()
	data.resize(count * 2)
	var state := 17.0
	var prev := 0.0
	for i in count:
		var u := float(i) / float(count)
		var env := pow(1.0 - u, 0.55)
		state = fmod(state * 1103515245.0 + 12345.0, 2147483647.0)
		var noise := (state / 2147483647.0) * 2.0 - 1.0
		# Hafif low-pass = su/sıçrama hissi
		prev = lerpf(prev, noise, 0.35)
		_write_s16(data, i, prev * env * vol)
	return _make_wav(data, rate)


static func _write_s16(data: PackedByteArray, index: int, sample: float) -> void:
	var v := int(clampf(sample, -1.0, 1.0) * 32767.0)
	data.encode_s16(index * 2, v)


static func _make_wav(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
