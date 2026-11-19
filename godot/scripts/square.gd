extends Node3D
## The central square: a stone fountain with jets of water (lit in colour at night), benches round it, lamps,
## and a flock of pigeons that peck about the paving and take off when you or a car come too close.

const S := 0.1
var m
var C := Vector2(3 * 520 + 320, 3 * 520 + 320)   # the middle of the square, game units
var jets: Array = []
var glow: OmniLight3D
var birds: Array = []        # { p: Vector2, a, h, vy, mode: walk|peck|fly, t, land: Vector2, ph }
var flock: MultiMesh

func build(main) -> void:
	m = main
	var city = m.city
	var gy: float = city.CURB * S
	var f := MeshInstance3D.new(); f.mesh = city.kit("fountain")
	var wm := ShaderMaterial.new(); wm.shader = load("res://shaders/water.gdshader"); wm.set_shader_parameter("centre", Vector3(C.x * S, 0, C.y * S))
	for k in f.mesh.get_surface_count():
		var mt := f.mesh.surface_get_material(k)
		if mt and String(mt.resource_name) == "water": f.set_surface_override_material(k, wm)
	f.position = Vector3(C.x * S, gy, C.y * S); add_child(f)
	city._solid(C, 84)
	if m.hi:
		_jet(Vector3(0, 3.45, 0), Vector3(0, 1, 0), 4.2, 260, 4.0)   # the top jet
		for k in 10:   # arcs from the rim towards the middle
			var a := k * TAU / 10.0; var d := Vector3(cos(a), 0, sin(a))
			_jet(d * 7.6 + Vector3(0, 0.8, 0), (-d * 0.55 + Vector3(0, 1, 0)).normalized(), 5.2, 90, 6.0)
		glow = OmniLight3D.new(); glow.omni_range = 12; glow.light_energy = 0; glow.position = Vector3(C.x * S, gy + 1.2, C.y * S); add_child(glow)
	# benches facing the fountain, lamps between them
	var bx := []; var lx := []
	for k in 8:
		var a := k * TAU / 8.0 + PI / 8; var p := C + Vector2.from_angle(a) * 118
		bx.append(Transform3D(Basis(Vector3.UP, -(a + PI)), Vector3(p.x * S, gy, p.y * S))); city._solid(p, 6); city.benches.append([p, a + PI])
		var q := C + Vector2.from_angle(a + PI / 8) * 150
		lx.append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * 1.2), Vector3(q.x * S, gy, q.y * S))); city._solid(q, 3); city.lamps.append(q)
	city._multi(city.kit("bench"), null, bx)
	var lamp: Mesh = city.kit("lamp")
	for k in lamp.get_surface_count():
		var mt = lamp.surface_get_material(k)
		if mt is BaseMaterial3D and (String(mt.resource_name).contains("glass") or String(mt.resource_name).contains("bulb")):
			var g: BaseMaterial3D = mt.duplicate(); g.emission_enabled = true; g.emission = Color("ffd9a0"); g.emission_energy_multiplier = 0.0
			lamp.surface_set_material(k, g); city.lamp_glow.append(g)
	city._multi(lamp, null, lx)
	# pigeons
	flock = MultiMesh.new(); flock.transform_format = MultiMesh.TRANSFORM_3D; flock.use_custom_data = true
	flock.mesh = city.kit("pigeon"); flock.instance_count = 26
	var mat := ShaderMaterial.new(); mat.shader = load("res://shaders/pigeon.gdshader")
	var mi := MultiMeshInstance3D.new(); mi.multimesh = flock; mi.material_override = mat; add_child(mi)
	mi.custom_aabb = AABB(Vector3(C.x * S - 60, -5, C.y * S - 60), Vector3(120, 60, 120))
	for k in flock.instance_count:
		birds.append({ "p": _spot(), "a": randf() * TAU, "h": 0.0, "vy": 0.0, "mode": "walk", "t": randf() * 3, "land": Vector2.ZERO, "ph": randf(), "v": Vector2.ZERO })

func _spot() -> Vector2:   # somewhere on the paving, not in the water
	while true:
		var p := C + Vector2(randf_range(-185, 185), randf_range(-185, 185))
		if p.distance_to(C) > 95: return p
	return C

func _jet(at: Vector3, dir: Vector3, speed: float, n: int, spread: float) -> void:
	var p := GPUParticles3D.new(); p.amount = n; p.lifetime = 1.0; p.local_coords = false
	var pm := ParticleProcessMaterial.new(); pm.direction = dir; pm.spread = spread; pm.initial_velocity_min = speed * 0.92; pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -9.8, 0); pm.scale_min = 0.6; pm.scale_max = 1.2
	p.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.06, 0.16)
	var qm := StandardMaterial3D.new(); qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(0.85, 0.93, 1.0, 0.55); qm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y; q.material = qm
	p.draw_pass_1 = q; p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-10, -2, -10), Vector3(20, 10, 20))
	p.position = Vector3(C.x * S, m.city.CURB * S, C.y * S) + at
	add_child(p); jets.append([p, qm])

func frame(dt: float) -> void:
	var cam: Vector3 = m.cam.global_position
	var near: bool = Vector2(cam.x / S, cam.z / S).distance_to(C) < 900 and m.interior.inside == ""
	for j in jets: (j[0] as GPUParticles3D).emitting = near
	if glow:   # at night the fountain glows, slowly changing colour
		glow.light_energy = m.night_k * 3.0
		glow.light_color = Color.from_hsv(fmod(m.time * 0.03, 1.0), 0.6, 1.0)
		for j in jets: (j[1] as StandardMaterial3D).albedo_color = Color(0.85, 0.93, 1.0, 0.55).lerp(glow.light_color * 1.6, m.night_k * 0.5)
	if not near: return
	var threats: Array = []
	if m.pcar == null: threats.append(Vector2(m.me.x, m.me.y))
	for c: Car in m.cars:
		if absf(c.v) > 20 and absf(c.x - C.x) < 320 and absf(c.y - C.y) < 320: threats.append(Vector2(c.x, c.y))
	var gy: float = m.city.CURB * S
	for k in birds.size():
		var b: Dictionary = birds[k]
		match b.mode:
			"walk", "peck":
				b.t -= dt
				if b.t <= 0: b.mode = "peck" if b.mode == "walk" and randf() < 0.5 else "walk"; b.t = randf_range(0.6, 2.5); b.a += randf_range(-1.2, 1.2)
				if b.mode == "walk":
					var np: Vector2 = b.p + Vector2.from_angle(b.a) * 6.0 * dt
					if np.distance_to(C) < 92 or absf(np.x - C.x) > 192 or absf(np.y - C.y) > 192: b.a += PI * 0.7
					else: b.p = np
				for t: Vector2 in threats:
					if t.distance_to(b.p) < 50:   # take off, away from it
						b.mode = "fly"; b.vy = randf_range(30, 45); b.t = randf_range(2.0, 3.6)
						b.v = (b.p - t).normalized().rotated(randf_range(-0.6, 0.6)) * randf_range(60, 90); b.land = _spot(); break
			"fly":
				b.t -= dt
				if b.t > 0:
					b.p += b.v * dt; b.h += b.vy * dt; b.vy = maxf(0.0, b.vy - 18 * dt)
				else:   # glide back down to a quiet spot
					var d: Vector2 = b.land - b.p; var L := d.length()
					b.p += d / maxf(L, 0.01) * minf(L, 80 * dt); b.h = maxf(0.0, b.h - 22 * dt)
					b.v = d
					if L < 2 and b.h <= 0.01: b.mode = "walk"; b.h = 0.0; b.t = randf_range(1, 3)
				b.a = atan2(b.v.y, b.v.x)
		var pitch := 0.6 if b.mode == "peck" and fmod(m.time * 3.0 + b.ph * 7.0, 1.0) < 0.5 else 0.0
		var bas := Basis(Vector3.UP, -b.a) * Basis(Vector3.FORWARD, pitch)
		flock.set_instance_transform(k, Transform3D(bas.scaled(Vector3.ONE * 1.2), Vector3(b.p.x * S, gy + b.h * S, b.p.y * S)))
		flock.set_instance_custom_data(k, Color(1.0 if b.mode == "fly" and (b.h > 0.5 or b.t > 0) else 0.0, b.ph, 0, 0))
