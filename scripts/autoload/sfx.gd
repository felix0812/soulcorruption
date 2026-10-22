extends Node
## Procedural sound ("Sfx"). Every sound is synthesised at start-up, so the game
## ships without audio files. Includes a looping ambient drone.

const RATE := 22050

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _players3d: Array[AudioStreamPlayer3D] = []
var _drone: AudioStreamPlayer
var _next := 0
var _next3d := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_sounds()
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for i in 16:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 6.0
		p3.max_distance = 45.0
		add_child(p3)
		_players3d.append(p3)
	_drone = AudioStreamPlayer.new()
	_drone.stream = _streams["drone"]
	_drone.volume_db = -14.0
	add_child(_drone)
	apply_volume()


func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(Cfg.gf("audio.master_volume"), 0.0001, 1.0)))


func play(sound: String, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	if not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch_jitter := 0.1) -> void:
	if not _streams.has(sound) or not is_inside_tree():
		return
	var p := _players3d[_next3d]
	_next3d = (_next3d + 1) % _players3d.size()
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.global_position = pos
	p.play()


func set_drone(on: bool, pitch := 1.0, volume_db := -14.0) -> void:
	_drone.pitch_scale = pitch
	_drone.volume_db = volume_db
	if on and not _drone.playing:
		_drone.play()
	elif not on and _drone.playing:
		_drone.stop()


# --------------------------------------------------------------------------
# Synthesis
# --------------------------------------------------------------------------

func _build_sounds() -> void:
	_streams["slash"] = _to_wav(_noise_burst(0.16, 0.6, 30.0, 0.55))
	_streams["hit"] = _to_wav(_mix(_tone(0.22, 95.0, 50.0, 0.9, 18.0), _noise_burst(0.08, 0.5, 45.0, 0.2)))
	_streams["hurt"] = _to_wav(_mix(_tone(0.3, 140.0, 70.0, 0.7, 10.0, "saw"), _noise_burst(0.2, 0.4, 14.0, 0.5)))
	_streams["pickup"] = _to_wav(_chime([660.0, 990.0, 1320.0], 0.7))
	_streams["buy"] = _to_wav(_chime([520.0, 780.0], 0.45))
	_streams["bolt"] = _to_wav(_tone(0.35, 300.0, 900.0, 0.5, 7.0, "saw"))
	_streams["dash"] = _to_wav(_noise_burst(0.25, 0.4, 9.0, 0.85))
	_streams["death"] = _to_wav(_tone(0.9, 320.0, 60.0, 0.6, 3.0, "saw"))
	_streams["whisper"] = _to_wav(_whisper(1.4))
	_streams["laugh"] = _to_wav(_laugh())
	_streams["teleport"] = _to_wav(_tone(0.5, 1200.0, 150.0, 0.45, 4.0, "sine"))
	_streams["wave"] = _to_wav(_bell(2.5))
	_streams["summon"] = _to_wav(_mix(_chime([330.0, 495.0, 660.0], 1.2), _whisper(1.2)))
	_streams["drone"] = _to_wav(_drone_loop(6.0), true)


func _to_wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = (a[i] if i < a.size() else 0.0) + (b[i] if i < b.size() else 0.0)
	return out


## Tone sweeping from f0 to f1 with exponential decay.
func _tone(dur: float, f0: float, f1: float, amp: float, decay: float, wave := "sine") -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / dur)
		phase += f / RATE
		var s := sin(TAU * phase) if wave == "sine" else (fmod(phase, 1.0) * 2.0 - 1.0)
		out[i] = s * amp * exp(-t * decay) * minf(1.0, t * 400.0)
	return out


func _noise_burst(dur: float, amp: float, decay: float, brightness: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), brightness)
		out[i] = lp * amp * exp(-t * decay)
	return out


func _chime(freqs: Array, dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for k in freqs.size():
		var start := int(k * 0.07 * RATE)
		for i in range(start, n):
			var t := float(i - start) / RATE
			out[i] += sin(TAU * freqs[k] * t) * 0.25 * exp(-t * 4.0)
	return out


func _bell(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var partials := [[110.0, 0.5], [220.5, 0.3], [302.0, 0.2], [441.0, 0.12], [587.0, 0.08]]
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for p in partials:
			s += sin(TAU * p[0] * t) * p[1]
		out[i] = s * exp(-t * 1.6) * 0.7
	return out


## Breathy filtered noise with a syllable-like amplitude pattern.
func _whisper(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var bp1 := 0.0
	var bp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := randf_range(-1.0, 1.0)
		bp1 = lerpf(bp1, x, 0.35)
		bp2 = lerpf(bp2, bp1, 0.35)
		var hp := bp1 - bp2
		var syll := pow(maxf(0.0, sin(TAU * 5.3 * t + sin(TAU * 1.7 * t) * 2.0)), 2.0)
		var env := sin(PI * t / dur)
		out[i] = hp * syll * env * 1.4
	return out


func _laugh() -> PackedFloat32Array:
	var n := int(1.1 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 210.0 - t * 60.0 + sin(TAU * 7.0 * t) * 25.0
		phase += f / RATE
		var pulse := pow(maxf(0.0, sin(TAU * 6.5 * t)), 3.0)
		out[i] = (sin(TAU * phase) * 0.6 + sin(TAU * phase * 2.01) * 0.25) * pulse * exp(-t * 1.8) * 0.6
	return out


func _drone_loop(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	# Frequencies are chosen to be whole cycles over `dur` so the loop is seamless.
	var f1 := 55.0
	var f2 := 55.0 + 1.0 / dur * 3.0
	var f3 := 82.5
	for i in n:
		var t := float(i) / RATE
		var mod := 0.6 + 0.4 * sin(TAU * t / dur)
		out[i] = (sin(TAU * f1 * t) * 0.35 + sin(TAU * f2 * t) * 0.3 + sin(TAU * f3 * t) * 0.15 * mod) * 0.7
	return out
