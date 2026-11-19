extends Node
## Sounds, all made in code at start (no files): your engine rising through the gears, the engines of the
## nearest cars, tyres squealing, crashes, police sirens that wail from their cars, rain, the city's hum,
## birds by day and crickets at night. Each is a short loop played at a changing pitch and volume.

const RATE := 22050
var m
var engine: AudioStreamPlayer
var squeal: AudioStreamPlayer
var crash: AudioStreamPlayer
var rain: AudioStreamPlayer
var hum: AudioStreamPlayer
var birds: AudioStreamPlayer
var crickets: AudioStreamPlayer
var others: Array = []        # AudioStreamPlayer3D on the nearest cars
var sirens: Array = []        # AudioStreamPlayer3D on chasing police cars
var _gear_rpm := 0.0
var master := 1.0             # from the settings (0..1)

func setup(main) -> void:
	m = main
	var eng := _engine_loop()
	engine = _player(eng, -8); engine.play()
	squeal = _player(_squeal_loop(), -80); squeal.play()
	crash = _player(_crash_hit(), -2)
	rain = _player(_noise_loop(2.0, 0.5, 0.6), -80); rain.play()
	hum = _player(_noise_loop(3.0, 0.97, 0.9), -22); hum.play()
	birds = _player(_birds_loop(), -14); birds.play()
	crickets = _player(_crickets_loop(), -80); crickets.play()
	for k in 3:
		var p := AudioStreamPlayer3D.new(); p.stream = eng; p.volume_db = -12; p.unit_size = 6; p.max_distance = 60; p.bus = "Master"
		add_child(p); p.play(); others.append(p)
	var sir := _siren_loop()
	for k in 2:
		var p := AudioStreamPlayer3D.new(); p.stream = sir; p.volume_db = 2; p.unit_size = 14; p.max_distance = 220
		add_child(p); sirens.append(p)

func _player(st: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new(); p.stream = st; p.volume_db = db; add_child(p); return p

func _wav(buf: PackedFloat32Array, loop := true) -> AudioStreamWAV:
	var pcm := PackedByteArray(); pcm.resize(buf.size() * 2)
	for i in buf.size(): pcm.encode_s16(i * 2, int(clampf(buf[i], -1, 1) * 30000))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.stereo = false; w.data = pcm
	if loop: w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_begin = 0; w.loop_end = buf.size()
	return w

## An engine at idle: the firing pulse and its harmonics, a little roughness. Exactly whole cycles, so it loops clean.
func _engine_loop() -> AudioStreamWAV:
	var f := 36.0; var n := int(RATE / f) * 24; var buf := PackedFloat32Array(); buf.resize(n)
	var rng := RandomNumberGenerator.new(); rng.seed = 3; var lp := 0.0
	for i in n:
		var t := float(i) / RATE; var ph := t * f * TAU
		var s := sin(ph) * 0.5 + sin(ph * 2) * 0.32 + sin(ph * 3 + 0.4) * 0.18 + sin(ph * 4) * 0.1 + sin(ph * 0.5) * 0.25
		var pulse := pow(maxf(0.0, sin(ph)), 6.0) * 0.4
		lp += (rng.randf_range(-1, 1) - lp) * 0.15
		buf[i] = (s + pulse) * 0.45 + lp * 0.12
	return _wav(buf)

func _squeal_loop() -> AudioStreamWAV:
	var n := RATE; var buf := PackedFloat32Array(); buf.resize(n); var rng := RandomNumberGenerator.new(); var ph := 0.0
	for i in n:
		var t := float(i) / RATE; ph += (1150.0 + sin(t * TAU * 7) * 60 + rng.randf_range(-40, 40)) / RATE
		buf[i] = (sin(ph * TAU) * 0.5 + sin(ph * TAU * 1.5) * 0.15) * (0.7 + 0.3 * sin(t * TAU * 13)) + rng.randf_range(-0.08, 0.08)
	return _wav(buf)

func _crash_hit() -> AudioStreamWAV:
	var n := int(RATE * 0.9); var buf := PackedFloat32Array(); buf.resize(n); var rng := RandomNumberGenerator.new(); var lp := 0.0
	for i in n:
		var t := float(i) / RATE; var e := exp(-t * 6.0)
		lp += (rng.randf_range(-1, 1) - lp) * 0.35
		var clang := sin(t * TAU * 420) * 0.25 * exp(-t * 9) + sin(t * TAU * 610) * 0.15 * exp(-t * 12)
		buf[i] = (lp * 0.9 + sin(t * TAU * 55) * 0.6 * exp(-t * 10) + clang + rng.randf_range(-1, 1) * 0.35 * exp(-t * 25)) * e
	return _wav(buf, false)

## Noise through a one-pole low-pass (smooth: 0 bright .. 0.99 dull), as rain or the far traffic.
func _noise_loop(sec: float, smooth: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * sec); var buf := PackedFloat32Array(); buf.resize(n); var rng := RandomNumberGenerator.new(); var lp := 0.0
	for i in n:
		lp = lp * smooth + rng.randf_range(-1, 1) * (1.0 - smooth)
		buf[i] = lp * vol * (1.0 / maxf(0.08, 1.0 - smooth)) * 0.25
	var fade := int(RATE * 0.05)   # blend the end into the start so the loop does not click
	for i in fade: buf[n - fade + i] = lerpf(buf[n - fade + i], buf[i], float(i) / fade)
	return _wav(buf)

func _siren_loop() -> AudioStreamWAV:
	var n := RATE * 4; var buf := PackedFloat32Array(); buf.resize(n); var ph := 0.0
	for i in n:
		var t := float(i) / RATE; var f := 700.0 + 550.0 * (0.5 - 0.5 * cos(t / 4.0 * TAU))
		ph += f / RATE
		buf[i] = (sin(ph * TAU) * 0.6 + sin(ph * TAU * 2) * 0.2 + sin(ph * TAU * 3) * 0.08)
	return _wav(buf)

func _birds_loop() -> AudioStreamWAV:
	var n := RATE * 6; var buf := PackedFloat32Array(); buf.resize(n); var rng := RandomNumberGenerator.new(); rng.seed = 21
	for c in 9:   # little phrases of chirps here and there
		var t0 := rng.randf_range(0, 5.3); var f0 := rng.randf_range(2600, 4200); var notes := rng.randi_range(2, 5)
		for k in notes:
			var s0 := int((t0 + k * 0.11) * RATE); var L := int(RATE * rng.randf_range(0.05, 0.09)); var ph := 0.0
			for i in L:
				var u := float(i) / L; ph += (f0 * (1.0 + 0.35 * sin(u * PI)) + 400 * sin(u * 40)) / RATE
				if s0 + i < n: buf[s0 + i] += sin(ph * TAU) * sin(u * PI) * 0.35
	return _wav(buf)

func _crickets_loop() -> AudioStreamWAV:
	var n := RATE * 3; var buf := PackedFloat32Array(); buf.resize(n)
	for i in n:
		var t := float(i) / RATE
		var gate := 1.0 if fmod(t * 3.3, 1.0) < 0.35 and sin(t * TAU * 45) > 0 else 0.0
		buf[i] = sin(t * TAU * 4300) * gate * 0.25 + sin(t * TAU * 4700 + 1) * gate * 0.1 * (1.0 if fmod(t * 2.1 + 0.3, 1.0) < 0.3 else 0.0)
	return _wav(buf)

static func db(v: float) -> float:
	return linear_to_db(maxf(v, 0.0001))

func crash_hit(strength: float) -> void:
	crash.volume_db = db(clampf(strength, 0.2, 1.0) * master); crash.pitch_scale = randf_range(0.85, 1.15); crash.play()

func tick(dt: float) -> void:
	var inside: bool = m.interior.inside != ""
	var c: Car = m.pcar
	# your engine: revs climb through five gears with speed, a jump when you press the gas
	if c and not inside:
		var sp := absf(c.v) / maxf(200.0, c.max_speed); var gear := mini(4, int(sp * 5.0))
		var in_gear := sp * 5.0 - gear
		var thr: float = m.touch_ui.read_input().thr
		var rpm := 0.9 + in_gear * 1.5 + gear * 0.12 + (0.35 if thr > 0.2 else 0.0)
		_gear_rpm += (rpm - _gear_rpm) * minf(1, dt * 8)
		engine.pitch_scale = clampf(_gear_rpm, 0.5, 3.2); engine.volume_db = db((0.35 + 0.35 * maxf(0, thr)) * master)
		var slide := clampf((absf(c.lat) - 40) / 120.0, 0, 1)
		if c.hand and absf(c.v) > 60: slide = maxf(slide, 0.7)
		squeal.volume_db = db(slide * 0.55 * master); squeal.pitch_scale = 0.9 + slide * 0.2
	else:
		engine.volume_db = -80; squeal.volume_db = -80
	# the nearest moving cars
	var t: Vector2 = m.target_pos(); var near: Array = []
	if not inside:
		for o: Car in m.cars:
			if o != c and absf(o.v) > 5 and absf(o.x - t.x) < 600 and absf(o.y - t.y) < 600: near.append(o)
		near.sort_custom(func(a, b): return Vector2(a.x, a.y).distance_squared_to(t) < Vector2(b.x, b.y).distance_squared_to(t))
	for k in others.size():
		var p: AudioStreamPlayer3D = others[k]
		if k < near.size():
			var o: Car = near[k]
			p.global_position = Vector3(o.x, 5, o.y) * m.S; p.pitch_scale = 0.7 + absf(o.v) / 300.0; p.volume_db = db(0.4 * master)
		else: p.volume_db = -80
	# sirens on the closest police cars that chase you
	var cops: Array = []
	if not inside:
		for o: Car in m.cars: if o.kind == "police" and o.chase: cops.append(o)
		cops.sort_custom(func(a, b): return Vector2(a.x, a.y).distance_squared_to(t) < Vector2(b.x, b.y).distance_squared_to(t))
	for k in sirens.size():
		var p: AudioStreamPlayer3D = sirens[k]
		if k < cops.size():
			var o: Car = cops[k]; p.global_position = Vector3(o.x, 8, o.y) * m.S; p.volume_db = db(0.9 * master)
			if not p.playing: p.play(randf() * 3.0)
		elif p.playing: p.stop()
	# the city: rain, the hum of traffic far away, birds by day and crickets after dark
	var r: float = 0.0 if inside else m.weather.cur.rain
	rain.volume_db = db(r * 0.7 * master)
	var night: float = m.night_k
	hum.volume_db = db((0.0 if inside else 0.22 * (1.0 - night * 0.6)) * master)
	birds.volume_db = db((0.0 if inside else 0.3 * (1.0 - night) * (1.0 - r)) * master)
	crickets.volume_db = db((0.0 if inside else 0.12 * night * (1.0 - r)) * master)
	if m.interior.music: m.interior.music.volume_db = -4 + db(m.interior.music_level)
