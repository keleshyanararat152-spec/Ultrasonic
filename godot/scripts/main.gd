extends Node3D
## The Godot port of Pink City. Stage 2: driving and walking, getting in and out of cars, traffic that
## stops at red lights, pedestrians, police with stars, day and night. Stage 3 (missions.gd, ui.gd): money,
## deliveries and taxi fares, the race and escape rings, the story, the radar and the big map.

const S := 0.1
const CELL := 520
const N := 7
const MODELS := {   # length in metres, and whether the model faces -x (see game/city CARX)
	"mclaren": [4.54, true], "gclass": [4.82, true], "goblin": [4.6, true], "revuelto": [4.95, false], "policesuv": [4.95, false],
	"police_sedan": [5.2, true], "taxi": [5.15, false], "traffic_compact": [3.6, false], "traffic_coupe": [4.5, false],
	"traffic_hatchback": [4.1, false], "traffic_minivan": [4.8, false], "traffic_offroad": [4.2, true], "traffic_pickup": [5.3, false],
	"traffic_sedan": [4.6, true], "traffic_sport": [4.3, true], "traffic_suv": [4.8, true], "traffic_wagon": [4.6, true] }
const TRAFFIC := ["traffic_compact", "traffic_coupe", "traffic_hatchback", "traffic_minivan", "traffic_offroad", "traffic_pickup", "traffic_sedan", "traffic_sport", "traffic_suv", "traffic_wagon"]
const FAST := { "mclaren": [470, 1.8, 1.3], "revuelto": [510, 2.0, 1.35], "goblin": [490, 1.9, 1.32], "gclass": [360, 1.3, 1.05] }
const DAY_LEN := 480.0

var city
var cars: Array = []
var peds: Array = []
var scenes := {}
var people_scenes := []
var pcar: Car = null                 # the car the player drives, or null on foot
var me := { "x": 0.0, "y": 0.0, "a": 0.0, "walk": 0.0, "moving": 0.0 }
var me_av                            # the player's avatar
var cam: Camera3D
var cam_a := 0.0
var shake := 0.0
var crash_cd := 0.0
var time := 0.0
var day_t := 0.12
var heat := 0.0
var evade_t := 0.0
var bust_t := 0.0
var toast_t := 0.0
var touch_ui
var hud := {}
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var hi := false                      # the computer renderer (Forward+): screen-space effects are on
var lamp_lights: Array = []
var head_light: SpotLight3D
var sig: Array = []                  # traffic signals: { I, J, d }
var sig_mm: MultiMesh
var sig_t := -9.0
var missions
var ui
var interior

func _ready() -> void:
	randomize()
	_environment()
	city = preload("res://scripts/city.gd").new()
	add_child(city)
	city.generate(); city.keep_out = [preload("res://scripts/interior.gd").house_spot(city).rect]
	city.build()
	_build_signals()
	for name in MODELS: scenes[name] = load("res://assets/cars/%s.glb" % name)
	for name in People.AVATARS: people_scenes.append(load("res://assets/people/%s.glb" % name))
	# you start on foot by the square, next to a McLaren at the kerb
	me.x = ic(3) + 120; me.y = ic(3) + 76; me.a = 0
	var mine := _make_car(ic(3) + 210, ic(3) + 50, 0.0, "mclaren")
	_fast(mine)
	for n in 34:
		var c := _make_car(0, 0, 0, TRAFFIC.pick_random() if randf() > 0.12 else "taxi")
		c.driver = true
		c.next_leg(randi_range(0, 7), randi_range(0, 7))
		c.x = c.ai.wx; c.y = c.ai.wy; c.a = c.ai.d * PI / 2
		c.cruise = randf_range(95, 130)
		if n < 2: c.model = "policesuv" if n == 0 else "police_sedan"; c.kind = "police"; c.max_speed = 300; _rebuild_node(c)
	for n in 14:   # parked along the kerb
		var d := randi_range(0, 3); var I := randi_range(0, 7); var J := randi_range(0, 7)
		var dv: Vector2i = Car.DV[d]
		if I + dv.x < 0 or J + dv.y < 0 or I + dv.x > 7 or J + dv.y > 7: continue
		var r: Vector2i = Car.DV[(d + 1) % 4]; var t := randf_range(150, 370)
		_make_car(ic(I) + dv.x * t + r.x * 50, ic(J) + dv.y * t + r.y * 50, d * PI / 2, TRAFFIC.pick_random())
	var lite := OS.has_feature("mobile")
	for n in (26 if lite else 40):
		var p := People.Ped.new()
		p.i = randi_range(0, 6); p.j = randi_range(0, 6); p.t = randf_range(0, 1512); p.dir = 1 if randf() < 0.5 else -1; p.sp = randf_range(32, 50)
		_ped_avatar(p); peds.append(p)
	me_av = People.Avatar.new(people_scenes[0]); add_child(me_av.root)
	cam = Camera3D.new(); cam.fov = 62; cam.near = 0.2; cam.far = 600
	add_child(cam)
	missions = preload("res://scripts/missions.gd").new(); add_child(missions); missions.setup(self)
	interior = preload("res://scripts/interior.gd").new(); interior.m = self; add_child(interior); interior.build_house()
	_hud()
	interior.start()
	toast(missions.start_text(), 4)

static func ic(i: int) -> float:
	return i * CELL + 60.0

func target_pos() -> Vector2:
	return Vector2(pcar.x, pcar.y) if pcar else Vector2(me.x, me.y)

func map_pos() -> Vector2:   # where the maps put you: the club door or your house while you are inside
	return interior.map_pos() if interior.inside != "" else target_pos()

func set_outfit(id: String) -> void:
	if me_av: me_av.root.queue_free()
	me_av = People.Avatar.new(People.scene(id)); add_child(me_av.root)

# -------------------------------------------------------------------- environment ----------
func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	hi = RenderingServer.get_rendering_device() != null   # Forward+ on computers; phones use Compatibility
	var sky := Sky.new(); sky_mat = ShaderMaterial.new(); sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat; sky.radiance_size = Sky.RADIANCE_SIZE_128 if hi else Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL if hi else Sky.PROCESS_MODE_AUTOMATIC
	env.background_mode = Environment.BG_SKY; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.tonemap_exposure = 1.05; env.tonemap_white = 6.0
	env.fog_enabled = true; env.fog_density = 0.0022; env.fog_sky_affect = 0.2
	env.glow_enabled = true; env.glow_intensity = 0.5; env.glow_strength = 0.9; env.glow_bloom = 0.04; env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true; env.adjustment_saturation = 1.12; env.adjustment_contrast = 1.06
	if hi:   # on a computer: shading in the corners, light bouncing off walls, reflections in glass
		env.ssao_enabled = true; env.ssao_radius = 1.4; env.ssao_intensity = 1.6; env.ssao_power = 1.4
		env.ssil_enabled = true; env.ssil_radius = 4.0; env.ssil_intensity = 0.7
		env.ssr_enabled = true; env.ssr_max_steps = 48; env.ssr_fade_in = 0.15; env.ssr_fade_out = 2.0
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN; env.glow_intensity = 0.35
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		get_viewport().msaa_3d = Viewport.MSAA_4X
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if hi else DirectionalLight3D.SHADOW_ORTHOGONAL
	if hi: sun.directional_shadow_max_distance = 260; sun.shadow_blur = 1.5; sun.light_angular_distance = 0.6
	add_child(sun)
	for k in (3 if OS.has_feature("mobile") else (12 if hi else 6)):   # street lamps near you light up at night
		var l := OmniLight3D.new(); l.light_color = Color("ffcf8f"); l.omni_range = 18; l.light_energy = 0; l.omni_attenuation = 1.6; l.shadow_enabled = hi and k < 2
		add_child(l); lamp_lights.append(l)
	head_light = SpotLight3D.new(); head_light.light_color = Color("fff0d2"); head_light.spot_range = 34; head_light.spot_angle = 28; head_light.light_energy = 0
	add_child(head_light)

## One day lasts DAY_LEN seconds: 0 is sunrise, 0.5 sunset. Sun, sky, fog, lamps and windows follow it.
func _day_night(dt: float) -> void:
	day_t = fmod(day_t + dt / DAY_LEN, 1.0)
	var ph := day_t * TAU; var el := sin(ph)
	var night := clampf(smoothstep(0.06, -0.14, el), 0, 1)
	var dusk := maxf(0, 1 - absf(el) / 0.3) * (1 - night * 0.7)
	var sd: Vector3
	if night < 0.5: sd = Vector3(cos(ph) * 0.8, maxf(0.12, el), -0.35).normalized()
	else: sd = Vector3(-cos(ph) * 0.6, maxf(0.3, -el), 0.3).normalized()   # the moon
	sun.look_at_from_position(Vector3.ZERO, -sd, Vector3.UP if absf(sd.y) < 0.99 else Vector3.FORWARD)
	sun.light_energy = 0.18 if night > 0.5 else (0.3 + 0.8 * minf(1, maxf(0, el) / 0.45)) * (1 - night)
	sun.light_color = Color("ffdcb0").lerp(Color("ff9a5a"), dusk).lerp(Color("8aa0d8"), night)
	var tint := Color.WHITE.lerp(Color(1, 0.62, 0.46), dusk).lerp(Color(0.11, 0.14, 0.25), night)
	var top := Color("4f8fd0").lerp(Color("6a7fb8"), dusk).lerp(Color("070b18"), night)
	var hor := Color("f0d2b6").lerp(Color("ffa060"), dusk).lerp(Color("1c2236"), night)
	sky_mat.set_shader_parameter("top_col", top); sky_mat.set_shader_parameter("hor_col", hor)
	sky_mat.set_shader_parameter("gnd_col", Color("8a7d74") * tint); sky_mat.set_shader_parameter("night", night)
	sky_mat.set_shader_parameter("cloud_col", Color.WHITE.lerp(Color("ffb48a"), dusk).lerp(Color("2a3046"), night))
	sky_mat.set_shader_parameter("sun_col", sun.light_color * (0.35 if night > 0.5 else 1.0)); sky_mat.set_shader_parameter("t", time)
	env.fog_light_color = Color("f0d2b6") * tint
	env.ambient_light_color = Color(0.62, 0.66, 0.72).lerp(Color(0.75, 0.55, 0.5), dusk).lerp(Color(0.15, 0.17, 0.27), night)
	env.ambient_light_energy = 1.0
	if interior.inside != "":   # indoors: no sun, the room's own light
		sun.light_energy = 0.0
		env.ambient_light_color = Color(0.52, 0.48, 0.44) if interior.inside == "home" else Color(0.32, 0.26, 0.38)
	for g: Array in city.facade_mats:
		(g[0] as StandardMaterial3D).albedo_color = Color(1.0, 0.82, 0.55) * night * (1.6 if hi else 1.1); (g[1] as Node3D).visible = night > 0.02
	city.bulb_mat.emission_energy_multiplier = 0.4 + night * 3.5
	var t := target_pos()
	var near: Array = city.lamps.duplicate()
	near.sort_custom(func(p, q): return p.distance_squared_to(t) < q.distance_squared_to(t))
	for k in lamp_lights.size():
		var l: OmniLight3D = lamp_lights[k]; l.light_energy = night * (2.0 if hi else 1.2); l.omni_range = 26 if hi else 20
		l.position = Vector3(near[k].x, city.CURB + 44, near[k].y) * S
	head_light.light_energy = night * 2.4 if pcar else 0.0
	if pcar:
		var f := Vector3(cos(pcar.a), 0, sin(pcar.a)); var gy: float = city.ground_y(pcar.x, pcar.y)
		head_light.position = Vector3(pcar.x, gy + 8, pcar.y) * S + f * 2.2
		head_light.look_at(head_light.position + f * 10 + Vector3(0, -1.1, 0))

func clock_text() -> String:
	var m := int(fmod(6 + day_t * 24, 24) * 60)
	return "%02d:%02d" % [m / 60, m % 60]

# ------------------------------------------------------------------ traffic lights ----------
## Two phases per crossroads, east-west then north-south, each with a short amber; neighbours are out of step.
func light_at(I: int, J: int, d: int) -> String:
	var ph := fmod(time + ((I * 7 + J * 3) % 8) * 2, 16.0)
	if d % 2 == 0: return "g" if ph < 6.5 else ("y" if ph < 8 else "r")
	return "g" if ph >= 8 and ph < 14.5 else ("y" if ph >= 14.5 else "r")

func _build_signals() -> void:   # one signal on the near right corner of every approach
	var posts := []; var heads := []; var lamps := []
	for I in N + 1:
		for J in N + 1:
			var X := I * CELL; var Y := J * CELL
			for e in [[0, I > 0, X - 16, Y + 138], [1, J > 0, X - 16, Y - 18], [2, I < N, X + 136, Y - 18], [3, J < N, X + 136, Y + 138]]:
				if not e[1]: continue
				sig.append({ "I": I, "J": J, "d": e[0] })
				posts.append(Transform3D(Basis.from_scale(Vector3(1.8, 34, 1.8) * S), Vector3(e[2], city.CURB + 17, e[3]) * S))
				heads.append(Transform3D(Basis.from_scale(Vector3(4.4, 11, 4.4) * S), Vector3(e[2], city.CURB + 37, e[3]) * S))
				lamps.append(Transform3D(Basis.from_scale(Vector3(5, 5, 5) * S), Vector3(e[2], city.CURB + 38.5, e[3]) * S))
	var unit := BoxMesh.new()
	city._multi(unit, city._plain(Color("2a2c31")), posts)
	city._multi(unit, city._plain(Color("1d1e22")), heads)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
	var sp := SphereMesh.new(); sp.radius = 0.5; sp.height = 1; sp.radial_segments = 8; sp.rings = 4
	mm.mesh = sp; mm.instance_count = lamps.size()
	for k in lamps.size(): mm.set_instance_transform(k, lamps[k])
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.vertex_color_use_as_albedo = true
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = mat; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi); sig_mm = mm

func _paint_signals() -> void:
	if time - sig_t < 0.2: return
	sig_t = time
	var col := { "r": Color("ff3b30"), "y": Color("ffcc00"), "g": Color("34e07a") }
	for k in sig.size(): sig_mm.set_instance_color(k, col[light_at(sig[k].I, sig[k].J, sig[k].d)])

# ------------------------------------------------------------------------ cars ----------
func _make_car(x: float, y: float, a: float, model: String) -> Car:
	var c := Car.new()
	c.x = x; c.y = y; c.a = a; c.model = model; c.max_speed = randf_range(290, 350)
	cars.append(c)
	_rebuild_node(c)
	return c

func _fast(c: Car) -> void:
	var st: Array = FAST.get(c.model, [340, 1.3, 1.1])
	c.max_speed = st[0]; c.acc = st[1]; c.grip = st[2]

func _rebuild_node(c: Car) -> void:
	if c.node: c.node.queue_free()
	var spec: Array = MODELS[c.model]
	var root := Node3D.new(); var tilt := Node3D.new(); root.add_child(tilt)
	var model: Node3D = scenes[c.model].instantiate()
	tilt.add_child(model)
	var box := _aabb(model)
	var k: float = spec[0] * 10.5 * S / maxf(0.001, box.size.x)
	model.scale = Vector3.ONE * k
	if spec[1]: model.rotation.y = PI
	var wheels := []; _find_wheels(model, wheels)
	var front := []
	for wn: Node3D in wheels: front.append((wn.position.x < 0) if spec[1] else (wn.position.x > 0))
	var lights := []
	if c.kind == "police":   # a light bar that flashes red and blue while chasing
		for s in [-1, 1]:
			var bar := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.26, 0.16, 0.44); bar.mesh = bm
			var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.albedo_color = Color("9aa3ad"); bar.material_override = mat
			bar.position = Vector3(-0.2, box.size.y * k - 0.04, s * 0.28); root.add_child(bar); lights.append(mat)
	c.anim = { "tilt": tilt, "wheels": wheels, "front": front, "dir": 1.0 if spec[1] else -1.0, "spin": 0.0, "roll": 0.0, "pitch": 0.0, "pa": c.a, "pv": c.v, "lights": lights }
	add_child(root)
	c.node = root

func _find_wheels(n: Node, out: Array) -> void:
	for ch in n.get_children():
		if ch is Node3D and String(ch.name).begins_with("WHEEL"): out.append(ch)
		else: _find_wheels(ch, out)

func _aabb(n: Node) -> AABB:
	var box := AABB(); var first := true
	var stack := [[n, Transform3D.IDENTITY]]
	while stack.size():
		var it: Array = stack.pop_back(); var node: Node = it[0]; var t: Transform3D = it[1]
		if node is Node3D and node != n: t = t * (node as Node3D).transform
		if node is MeshInstance3D:
			var b: AABB = t * (node as MeshInstance3D).get_aabb()
			if first: box = b; first = false
			else: box = box.merge(b)
		for ch in node.get_children(): stack.append([ch, t])
	return box

func _ped_avatar(p) -> void:
	p.av = People.Avatar.new(people_scenes[randi_range(1, people_scenes.size() - 1)])
	add_child(p.av.root)

# --------------------------------------------------------------------- getting in and out ----------
func act() -> void:
	if interior.inside != "": interior.act(); return
	if interior.near_door(): interior.enter_club(); return
	if pcar:
		if absf(pcar.v) > 45: return
		var p := Vector2(pcar.x + sin(pcar.a) * 28, pcar.y - cos(pcar.a) * 28)
		p = city.push_out(p, 7)
		me.x = p.x; me.y = p.y; me.a = pcar.a; pcar.v = 0; pcar.steer_in = 0; pcar = null
		missions.on_exit_car()
		return
	var best: Car = null; var bd := 58.0
	for c: Car in cars:
		var d := Vector2(c.x - me.x, c.y - me.y).length()
		if d < bd and c.kind != "police": bd = d; best = c
	if best == null: return
	if best.driver:   # taking someone's car: the driver runs off and the police are called
		add_heat(1); toast("Ուրիշի մեքենան վերցրիր")
		for p in peds: if Vector2(p.x - best.x, p.y - best.y).length() < 300: People.panic(p, Vector2(best.x, best.y))
	best.driver = false; best.ai = {}; best.stun = 0; best.chase = false
	pcar = best
	if not FAST.has(best.model): best.max_speed = maxf(best.max_speed, 330)
	missions.on_enter_car(best)

func add_heat(n: float) -> void:
	heat = minf(5, heat + n); evade_t = 0

func toast(msg: String, dur := 2.4) -> void:
	hud.toast.text = msg; hud.toast_panel.visible = true; toast_t = dur

# ------------------------------------------------------------------------ loop ----------
func _physics_process(dt: float) -> void:
	if ui.busy(): return   # talking, a panel or the big map: the city waits
	time += dt
	var inp: Dictionary = touch_ui.read_input()
	if interior.inside != "": interior.step(dt, inp); return   # in the club or at home the city waits too
	if pcar:
		var hit := pcar.step(city, inp.thr, inp.steer * 0.8, inp.hand, dt)
		if hit > 70: _crash(hit)
		me.x = pcar.x; me.y = pcar.y
	else:   # walking: forward/back moves, sideways turns
		var mv: float = inp.move.y; var tn: float = inp.move.x
		me.a += tn * 2.8 * dt
		var spd: float = -mv * (150.0 if mv < 0 else 80.0)
		me.x += cos(me.a) * spd * dt; me.y += sin(me.a) * spd * dt
		me.moving = absf(mv)
		if absf(mv) > 0.05: me.walk += dt * 10 * absf(mv) * (1.0 if mv < 0 else -0.7)
		var p := Vector2(me.x, me.y)
		for c: Car in cars:   # cars are solid boxes you cannot walk through
			var d := p - Vector2(c.x, c.y)
			if absf(d.x) > 42 or absf(d.y) > 42: continue
			var ca := cos(c.a); var sa := sin(c.a); var lx := d.x * ca + d.y * sa; var ly := -d.x * sa + d.y * ca
			var hx := Car.HX + 6; var hy := Car.HY + 6
			if absf(lx) >= hx or absf(ly) >= hy: continue
			if hx - absf(lx) < hy - absf(ly): lx = signf(lx) * hx
			else: ly = signf(ly) * hy
			p = Vector2(c.x + lx * ca - ly * sa, c.y + lx * sa + ly * ca)
		p = city.push_out(p, 7); me.x = p.x; me.y = p.y
		interior.door_tick()
	# traffic: civilians keep to the streets and lights; police chase when you have stars
	var blockers := []
	if not pcar: blockers.append(Vector2(me.x, me.y))
	for p in peds: if not p.cross.is_empty() and not p.cross.wait: blockers.append(Vector2(p.x, p.y))
	var tgt := target_pos(); var chasing := 0; var near := false; var close := false
	var spd := absf(pcar.v) if pcar else 0.0
	for c: Car in cars:
		if c == pcar: continue
		if c.kind == "police":
			if heat > 0 and not c.chase: c.chase = true; c.resync()
			if heat <= 0 and c.chase: c.chase = false; c.resync()
			if c.chase:
				chasing += 1; var d := tgt.distance_to(Vector2(c.x, c.y))
				if d < 480: near = true
				if d < (75 if pcar else 46) and spd < 30: close = true
		if c.path.size(): c.path_drive(city, dt)
		elif c.driver or c.kind == "police": c.drive(self, cars, blockers, dt)
		else: c.v -= c.v * 2.5 * dt; c.step(city, 0, 0, false, dt)
	for i in cars.size():
		for j in range(i + 1, cars.size()):
			var a: Car = cars[i]; var b: Car = cars[j]
			var imp := Car.collide(a, b)
			if imp > 70 and pcar and (a == pcar or b == pcar):
				var other: Car = b if a == pcar else a
				if crash_cd <= 0 and not (other.kind == "police" and other.chase): add_heat(1.5 if other.kind == "police" else (0.8 if imp > 200 else 0.5))
				_crash(imp)
	crash_cd -= dt
	# people on the pavements
	for k in range(peds.size() - 1, -1, -1):
		var p = peds[k]
		if p.down > 0: p.down -= dt
		elif p.free_life > 0:
			p.x += cos(p.a) * 70 * dt; p.y += sin(p.a) * 70 * dt; var q: Vector2 = city.push_out(Vector2(p.x, p.y), 5); p.x = q.x; p.y = q.y
			p.free_life -= dt
		else: People.step(p, self, dt)
		if pcar and absf(pcar.v) > 110 and p.down <= 0 and p.panic_t <= 0 and absf(p.x - pcar.x) < 120 and absf(p.y - pcar.y) < 120: People.panic(p, Vector2(pcar.x, pcar.y))
		if p.down <= 0:
			for c: Car in cars:
				if absf(c.v) > 50 and absf(c.x - p.x) < 18 and absf(c.y - p.y) < 18:
					p.down = 2.5
					if c == pcar: add_heat(0.8); toast("Զգույշ, մարդիկ կան")
					break
	# stars: more police the more stars; lose them by staying out of sight; caught when they box you in
	if heat > 0:
		if chasing < mini(4, ceili(heat)):
			for t in 20:
				var I := randi_range(0, 7); var J := randi_range(0, 7); var d := Vector2(ic(I), ic(J)).distance_to(tgt)
				if d > 650 and d < 1500:
					var c := _make_car(ic(I), ic(J), atan2(tgt.y - ic(J), tgt.x - ic(I)), "policesuv" if randf() < 0.6 else "police_sedan")
					c.kind = "police"; c.max_speed = 300; c.driver = true; c.chase = true; c.resync(); _rebuild_node(c)
					break
		if near: evade_t = 0
		else:
			evade_t += dt
			if evade_t > 6:
				evade_t = 0; heat = maxf(0, ceilf(heat) - 1)
				if heat == 0: toast("Աստղերը մարեցին")
		bust_t = bust_t + dt if close else maxf(0, bust_t - dt)
		if bust_t > 1.5: _busted()
	else:   # let extra patrol cars leave once nobody is looking
		var cops := 0
		for k in range(cars.size() - 1, -1, -1):
			var c: Car = cars[k]
			if c.kind != "police": continue
			cops += 1
			if cops > 2 and Vector2(c.x, c.y).distance_to(tgt) > 900: c.node.queue_free(); cars.remove_at(k)
	missions.tick(dt)

func _busted() -> void:
	heat = 0; bust_t = 0
	if pcar: pcar.v = 0; pcar = null
	me.x = ic(3) + 96; me.y = ic(3) + 76
	for c: Car in cars: if c.kind == "police": c.chase = false
	missions.on_busted()

func _crash(impact: float) -> void:
	if crash_cd > 0: return
	crash_cd = 0.45; shake = minf(1.0, maxf(shake, impact / 260))
	pcar.dmg += 2 if impact > 260 else 1
	if OS.has_feature("mobile"): Input.vibrate_handheld(int(minf(60, 15 + impact / 8)))

func _process(dt: float) -> void:
	_day_night(dt)
	_paint_signals()
	var flash := int(time * 6) % 2 == 0
	for c: Car in cars:
		_place(c, dt)
		for k in c.anim.lights.size():
			(c.anim.lights[k] as StandardMaterial3D).albedo_color = (Color("ff5a5f") if (k == 0) == flash else Color("4d8dff")) if c.chase else Color("9aa3ad")
	for p in peds: _place_ped(p, dt)
	missions.frame(dt)
	interior.frame(dt)
	# you on foot
	me_av.root.visible = pcar == null
	if not pcar:
		me_av.root.position = Vector3(me.x, city.ground_y(me.x, me.y), me.y) * S
		me_av.root.rotation.y = -me.a
		me_av.walk(me.walk * 0.85, minf(1, me.moving * 1.5))
	# camera: behind the car or the walker
	var t := target_pos(); var head: float = pcar.a if pcar else me.a
	var spd := absf(pcar.v) if pcar else 0.0
	cam_a += wrapf(head - cam_a, -PI, PI) * minf(1, dt * 3.6)
	var vs := get_viewport().get_visible_rect().size
	var far := 1.45 if vs.x < vs.y else 1.0
	var dist := ((80 + spd * 0.07) if pcar else 60.0) * far
	var p := Vector2(t.x - cos(cam_a) * dist, t.y - sin(cam_a) * dist)
	if not pcar: p = interior.cam_fix(p) if interior.inside != "" else city.push_out(p, 9)
	if shake > 0:
		var k := shake * shake * 6; p += Vector2(randf_range(-k, k), randf_range(-k, k)); shake = maxf(0, shake - dt * 2.5)
	var gy: float = city.ground_y(t.x, t.y)
	cam.position = Vector3(p.x, (36 if pcar else 30) * far + gy, p.y) * S
	cam.look_at(Vector3(t.x + cos(cam_a) * 45, gy + (9 if pcar else 14), t.y + sin(cam_a) * 45) * S)
	cam.fov = 60 + spd * 0.035
	sun.global_position = cam.global_position
	_hud_tick(dt)
	_test_tick()

func _place(c: Car, dt: float) -> void:
	var gy: float = city.ground_y(c.x, c.y)
	c.node.position = Vector3(c.x, gy, c.y) * S
	c.node.rotation.y = -c.a
	var u: Dictionary = c.anim
	var dc := (c.node.position - cam.position).length()
	c.node.visible = dc < 260
	if dt <= 0 or dc > 90: return
	u.spin += c.v * dt / 4.02
	var st := clampf(c.steer_in, -1, 1) * 0.42
	for k in u.wheels.size():
		(u.wheels[k] as Node3D).rotation = Vector3(0, -st * u.dir if u.front[k] else 0.0, u.spin * u.dir)
	var yaw: float = wrapf(c.a - u.pa, -PI, PI) / dt; var accel: float = (c.v - u.pv) / dt; u.pa = c.a; u.pv = c.v
	var roll := clampf(-c.v * yaw * 0.00035, -0.08, 0.08); var pitch := clampf(accel * 0.00022, -0.06, 0.06); var f := minf(1, dt * 6)
	u.roll += (roll - u.roll) * f; u.pitch += (pitch - u.pitch) * f
	(u.tilt as Node3D).rotation = Vector3(u.roll, 0, u.pitch)

func _place_ped(p, dt: float) -> void:
	var r: Node3D = p.av.root
	r.position = Vector3(p.x, city.ground_y(p.x, p.y), p.y) * S
	var dc := (r.position - cam.position).length()
	r.visible = dc < 130
	if not r.visible: return
	r.rotation = Vector3(0, -p.a, PI / 2 if p.down > 0 else 0.0)
	if p.down > 0: r.position.y += 0.3
	var moving: bool = p.down <= 0 and (p.free_life > 0 or p.cross.is_empty() or not p.cross.wait)
	var rate := (17.0 if p.panic_t > 0 or p.free_life > 0 else 11.0)
	p.av.phase += dt * rate * (1.0 if moving else 0.0)
	if dc < 70: p.av.walk(p.av.phase, 1.0 if moving else 0.0)

# ------------------------------------------------------------------------ HUD ----------
func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.08, 0.09, 0.11, 0.82); sb.set_corner_radius_all(10)
	sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	return panel

func _hud() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	touch_ui = preload("res://scripts/touch.gd").new()
	touch_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_ui.main = self
	layer.add_child(touch_ui)
	ui = preload("res://scripts/ui.gd").new(); ui.main = self; layer.add_child(ui)
	var panel := _panel(); panel.position = Vector2(16, 12)
	var box := VBoxContainer.new(); panel.add_child(box)
	var stars := Label.new(); stars.add_theme_font_size_override("font_size", 22)
	var speed := Label.new(); speed.add_theme_font_size_override("font_size", 18)
	var clock := Label.new(); clock.add_theme_font_size_override("font_size", 15); clock.add_theme_color_override("font_color", Color("a9a59c"))
	var cash := Label.new(); cash.add_theme_font_size_override("font_size", 22); cash.add_theme_color_override("font_color", Color("58d68d"))
	box.add_child(cash); box.add_child(stars); box.add_child(speed); box.add_child(clock)
	if not DisplayServer.is_touchscreen_available():   # on a computer: how to play with the keyboard
		var keys := Label.new(); keys.add_theme_font_size_override("font_size", 14); keys.add_theme_color_override("font_color", Color("a9a59c"))
		keys.text = "W / S — գազ, արգելակ, քայլել\nA / D — ղեկ, շրջվել\nSpace — ձեռքի արգելակ\nE — նստել, իջնել\nM — քարտեզ"
		box.add_child(keys)
	layer.add_child(panel)
	var tp := _panel(); tp.set_anchors_preset(Control.PRESET_CENTER_TOP); tp.position = Vector2(-240, 120); tp.custom_minimum_size = Vector2(480, 0)
	var tl := Label.new(); tl.add_theme_font_size_override("font_size", 20); tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tp.add_child(tl); tp.visible = false; layer.add_child(tp)
	var hp := _panel(); hp.visible = false
	var hl := Label.new(); hl.add_theme_font_size_override("font_size", 17); hp.add_child(hl); layer.add_child(hp)
	hud = { "hint": hl, "hint_panel": hp, "panel": panel, "cash": cash, "stars": stars, "speed": speed, "clock": clock, "toast": tl, "toast_panel": tp }

func _hud_tick(dt: float) -> void:
	var n := ceili(heat)
	hud.stars.text = "★".repeat(n) + "☆".repeat(5 - n)
	hud.stars.add_theme_color_override("font_color", Color("ff5a5f") if n > 0 else Color("a9a59c"))
	hud.speed.text = interior.status() if interior.inside != "" else (("%d կմ/ժ" % int(absf(pcar.v) * 0.42)) if pcar else "ոտքով")
	hud.clock.text = clock_text()
	hud.cash.text = missions.money(missions.cash)
	hud.panel.visible = not ui.big.visible
	if toast_t > 0:
		toast_t -= dt
		if toast_t <= 0: hud.toast_panel.visible = false
	var il: String = interior.act_label()
	touch_ui.act_label = "Իջնել" if pcar else (il if il != "" else ("Նստել" if _car_near() and interior.inside == "" else ""))
	var hn: String = interior.hint()
	hud.hint.text = hn; hud.hint_panel.visible = hn != "" and not DisplayServer.is_touchscreen_available() and not ui.busy()
	var vs := get_viewport().get_visible_rect().size; var hp: Control = hud.hint_panel
	hp.reset_size(); hp.position = Vector2((vs.x - hp.size.x) / 2, vs.y - hp.size.y - 24)
	touch_ui.driving = pcar != null

func _car_near() -> bool:
	for c: Car in cars:
		if c.kind != "police" and Vector2(c.x - me.x, c.y - me.y).length() < 58: return true
	return false

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_E or e.keycode == KEY_F): act()
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_SPACE and interior.on_floor(): interior.dance_hit()

# testing aid: `godot -- --shot=/path/out.png [--frames=N] [--drive]` saves a frame and quits
var _test := {}
var _frame := 0
func _test_tick() -> void:
	if _test.is_empty():
		_test = { "on": false }
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shot="): _test.on = true; _test.shot = a.substr(7)
			if a.begins_with("--frames="): _test.frames = int(a.substr(9))
			if a == "--drive": _test.drive = true
			if a.begins_with("--hour="): day_t = fmod((float(a.substr(7)) - 6) / 24.0 + 1, 1)
			if a == "--heat": heat = 3
			if a == "--talk": _test.talk = true
			if a == "--map": _test.map = true
			if a == "--club": _test.club = true
			if a == "--vip": _test.vip = true
			if a == "--home": _test.home = true
			if a == "--house": _test.house = true
			if a.begins_with("--at="): _test.at = a.substr(5).split(",")
			if a == "--storytest": _test.story = true
			if a == "--jobtest": _test.jobs = true
			if a == "--shoptest": _test.shop = true
	if _test.get("story", false): _story_test(); return
	if _test.get("jobs", false): _job_test(); return
	if _test.get("shop", false): _shop_test(); return
	if not _test.on: return
	touch_ui.touched = true
	_frame += 1
	if _frame == 40 and _test.get("talk", false): me.x = missions.sp.square.x; me.y = missions.sp.square.y + 10
	if _frame == 5 and _test.get("club", false): interior.enter_club(); me.x = interior.CX - 110; me.y = interior.CY + 10; me.a = 0; cam_a = 0
	if _frame == 5 and _test.get("vip", false): interior.enter_club(); interior._to_vip(); me.x = interior.VX - 60; me.y = interior.VY
	if _frame == 5 and _test.get("home", false): interior.enter_home(); me.x = interior.HX - 40; me.y = interior.HY + 30; me.a = -0.5; cam_a = -0.5
	if _test.has("at") and _frame < 100:
		var q: Array = _test.at; me.x = float(q[0]); me.y = float(q[1]); me.a = float(q[2]); cam_a = me.a
		touch_ui.stick = Vector2.ZERO
		if _frame == 99 or _frame == _test.get("frames", 120): pass
	if _frame == 3 and _test.get("house", false): me.x = interior.house.x - 30; me.y = interior.house.front - 150; me.a = PI / 2 - 0.3; cam_a = me.a
	if _frame == 60 and _test.get("map", false): missions.set_waypoint(Vector2(ic(6), ic(1))); ui.toggle_map()
	if _frame > 30:   # script time per frame, for comparing speed-ups
		_test.proc = _test.get("proc", 0.0) + Performance.get_monitor(Performance.TIME_PROCESS) * 1000
		_test.phys = _test.get("phys", 0.0) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000
	if _frame == _test.get("frames", 120) and _frame > 30:
		print("PROF ms/frame process %.2f physics %.2f" % [_test.proc / (_frame - 30), _test.phys / (_frame - 30)])
	if _test.get("drive", false):
		if _frame == 5: me.x = cars[0].x - 20; me.y = cars[0].y - 40; act()
		if _frame > 5 and _frame < 60: touch_ui.pedals = { 99: "gas" }
		else: touch_ui.pedals = {}
	elif not _test.has("at"):
		touch_ui.stick = Vector2(0, -1) if _frame < 50 else Vector2.ZERO
	if _frame == _test.get("frames", 120):
		get_viewport().get_texture().get_image().save_png(_test.shot)
		print("SHOT ", _test.shot, " car ", pcar != null, " me ", me.x, " ", me.y, " heat ", heat, " cars ", cars.size(), " peds ", peds.size())
		get_tree().quit()

## testing aid: `godot --headless -- --storytest` plays the whole story by teleporting, printing each step
var _st_last := ""
func _story_test() -> void:
	_frame += 1
	var ms = missions
	if _frame == 2: ms.prog = ms.prog0(); ms.cash = 0
	var tag := "ch%d %s" % [ms.prog.story, (ms.act.s.t + str(ms.act.k)) if ms.story_on() and ms.act.get("s") else "-"]
	if tag != _st_last: _st_last = tag; print("STORY ", _frame, " ", tag, " cash ", ms.cash, " heat ", heat)
	if ms.story_done() or _frame > 20000:
		print("STORY END done=", ms.story_done(), " cash ", ms.cash); get_tree().quit(); return
	if ui.talking():
		if ui.talk.choice != null: ui._pick(0)
		else: ui._next()
		return
	var put := func(p: Vector2):
		if pcar: pcar.x = p.x; pcar.y = p.y; pcar.v = 0
		else: me.x = p.x; me.y = p.y
	var need_car := func():
		if pcar == null:
			var c := _make_car(me.x + 30, me.y, 0.0, "mclaren"); me.x = c.x - 20; act()
	if not ms.story_on():
		if heat > 0: heat = 0
		if pcar and ms.prog.story != 3: act()
		var g = ms.spos(ms.chs[ms.prog.story].at)
		if _frame % 30 == 0: put.call(g + Vector2(200, 0))
		else: put.call(g)
		return
	var s: Dictionary = ms.act.s
	match s.t:
		"talk":
			heat = 0
			var p = ms.spos(s.at)
			if p != null: put.call(p)
		"getcar":
			if pcar: act()
			me.x = ms.act.car.x; me.y = ms.act.car.y + 20; act()
		"drive": put.call(ms.sp.garageCar)
		"multi":
			need_car.call(); put.call(ms.sp.lav[ms.act.m])
		"tail":
			need_car.call()
			var c: Car = ms.act.car
			if ms.act.go: ms.act.time = 0.0
			put.call(Vector2(c.x, c.y) + Vector2(200, 0))
		"escape": heat = 0
		"race":
			need_car.call()
			if ms.act.phase == "ready": put.call(ms.spos("rival") + Vector2(0, 40))
			elif ms.act.phase == "go": put.call(Vector2(ms.act.cps[ms.act.ci].x, ms.act.cps[ms.act.ci].y))
		"chase":
			need_car.call()
			var c: Car = ms.act.car
			put.call(Vector2(c.x, c.y) + Vector2(0, 40))

func _job_test() -> void:   # deliveries, a taxi fare, the race and the escape, by teleporting
	_frame += 1
	var ms = missions
	if _frame == 2:
		ms.prog.story = 5; ms.cash = 0; ms.act = null
		var c := _make_car(me.x + 30, me.y, 0.0, "taxi"); me.x = c.x - 20; act(); print("JOB in taxi ", ms.job.kind)
	if ui.busy():
		if ui.shop.visible: (ui.shop_list.get_child(0) as Button).pressed.emit()
		return
	if ms.act == null and ms.job:
		if pcar == null: return
		if _frame < 200:
			pcar.x = ms.job.p.x; pcar.y = ms.job.p.y; pcar.v = 0
		elif _frame == 200:
			print("JOB cash after fares ", ms.cash); pcar.x = ms.places[0].x + 120; pcar.y = ms.places[0].y
		elif _frame == 210: pcar.x = ms.places[0].x; pcar.y = ms.places[0].y
		elif _frame == 400:
			print("JOB cash after race ", ms.cash, " best ", ms.prog.race_best); pcar.x = ms.places[1].x + 120; pcar.y = ms.places[1].y
		elif _frame == 410: pcar.x = ms.places[1].x; pcar.y = ms.places[1].y
		elif _frame > 600: print("JOB end cash ", ms.cash); get_tree().quit()
	elif ms.act != null and ms.act.kind == "race":
		var c = ms.act.cps[ms.act.k]; pcar.x = c.x; pcar.y = c.y; pcar.v = 0
	elif ms.act != null and ms.act.kind == "escape":
		if _frame % 20 == 0: heat = 0

func _shop_test() -> void:   # buys a car, an outfit and the house, then goes home and dances in the club
	_frame += 1
	var ms = missions
	if _frame == 2: ms.prog = ms.prog0(); ms.cash = 200000
	if _frame == 4: interior.open_place(ms.place("dealer")); (ui.shop_list.get_child(4) as Button).pressed.emit(); print("SHOP car ", ms.prog.car, " cash ", ms.cash, " owned ", interior.owned != null)
	if _frame == 6: interior.open_place(ms.place("clothes")); (ui.shop_list.get_child(9) as Button).pressed.emit(); ui.close_panel(); print("SHOP outfit ", ms.prog.outfit, " cash ", ms.cash)
	if _frame == 8: interior.open_place(ms.place("home")); (ui.shop_list.get_child(0) as Button).pressed.emit(); print("SHOP home ", ms.prog.home, " inside ", interior.inside, " cash ", ms.cash)
	if _frame == 10: interior._call_car(); interior._sleep(); interior._wardrobe(); (ui.shop_list.get_child(0) as Button).pressed.emit(); ui.close_panel(); print("SHOP wardrobe ", ms.prog.outfit)
	if _frame == 12: interior.leave_home(); print("SHOP out ", interior.inside, " me ", me.x, " ", me.y)
	if _frame == 14: interior.enter_club(); me.x = interior.CX - 40; me.y = interior.CY; print("SHOP club ", interior.inside, " floor ", interior.on_floor())
	if _frame > 14 and _frame < 300 and _frame % 7 == 0: interior.dance_hit()
	if _frame == 300: interior._drink(); interior._to_vip(); interior._table(); print("SHOP vip ", interior.inside, " table ", ms.prog.vip_table, " cash ", ms.cash)
	if _frame == 310: interior._from_vip(); interior._leave_club(); print("SHOP left ", interior.inside); get_tree().quit()
