extends Node3D
## Stage 1 of the Godot port: the city, driving with the browser game's physics, traffic and the car models.

const S := 0.1
const MODELS := {   # length in metres, and whether the model faces -x (see game/city CARX)
	"mclaren": [4.54, true], "gclass": [4.82, true], "goblin": [4.6, true], "revuelto": [4.95, false], "policesuv": [4.95, false],
	"police_sedan": [5.2, true], "taxi": [5.15, false], "traffic_compact": [3.6, false], "traffic_coupe": [4.5, false],
	"traffic_hatchback": [4.1, false], "traffic_minivan": [4.8, false], "traffic_offroad": [4.2, true], "traffic_pickup": [5.3, false],
	"traffic_sedan": [4.6, true], "traffic_sport": [4.3, true], "traffic_suv": [4.8, true], "traffic_wagon": [4.6, true] }
const TRAFFIC := ["traffic_compact", "traffic_coupe", "traffic_hatchback", "traffic_minivan", "traffic_offroad", "traffic_pickup", "traffic_sedan", "traffic_sport", "traffic_suv", "traffic_wagon"]
const PLAYER_CARS := ["mclaren", "revuelto", "goblin", "gclass", "policesuv", "taxi", "traffic_sport"]
const PLAYER_STATS := { "mclaren": [470, 1.8, 1.3], "revuelto": [510, 2.0, 1.35], "goblin": [490, 1.9, 1.32], "gclass": [360, 1.3, 1.05] }

var city
var cars: Array = []
var player: Car
var player_model := 0
var scenes := {}
var cam: Camera3D
var cam_a := 0.0
var shake := 0.0
var crash_cd := 0.0
var touch_ui
var hud_speed: Label
var hud_hint: Label
var sun: DirectionalLight3D

func _ready() -> void:
	randomize()
	_environment()
	city = preload("res://scripts/city.gd").new()
	add_child(city)
	city.build()
	for name in MODELS: scenes[name] = load("res://assets/cars/%s.glb" % name)
	# the player's car on the street by the square, then the traffic and some parked cars
	player = _make_car(Car.ic_static(3) + 210, Car.ic_static(3) + 28, 0.0, PLAYER_CARS[0])
	_apply_player_stats()
	for n in 34:
		var c := _make_car(0, 0, 0, TRAFFIC.pick_random())
		c.driver = true
		c.next_leg(randi_range(0, 7), randi_range(0, 7))
		c.x = c.ai.wx; c.y = c.ai.wy; c.a = c.ai.d * PI / 2
		c.cruise = randf_range(95, 130)
		if n < 3: c.model = "policesuv" if n < 2 else "police_sedan"; c.kind = "police"; _rebuild_node(c)
	for n in 14:   # parked along the kerb
		var d := randi_range(0, 3); var I := randi_range(0, 7); var J := randi_range(0, 7)
		var dv: Vector2i = Car.DV[d]
		if I + dv.x < 0 or J + dv.y < 0 or I + dv.x > 7 or J + dv.y > 7: continue
		var r: Vector2i = Car.DV[(d + 1) % 4]; var t := randf_range(150, 370)
		_make_car(Car.ic_static(I) + dv.x * t + r.x * 50, Car.ic_static(J) + dv.y * t + r.y * 50, d * PI / 2, TRAFFIC.pick_random())
	cam = Camera3D.new(); cam.fov = 62; cam.near = 0.2; cam.far = 600
	add_child(cam)
	cam_a = player.a
	_hud()

func _environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("5f9bd1"); sm.sky_horizon_color = Color("f0d2b6"); sm.ground_horizon_color = Color("f0d2b6"); sm.ground_bottom_color = Color("8a7d74")
	sm.sun_angle_max = 20
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY; e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; e.ambient_light_energy = 0.9
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true; e.fog_light_color = Color("f0d2b6"); e.fog_density = 0.0022; e.fog_sky_affect = 0.25
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.light_color = Color("ffdcb0"); sun.light_energy = 1.05
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)

# ------------------------------------------------------------------------ cars ----------
func _make_car(x: float, y: float, a: float, model: String) -> Car:
	var c := Car.new()
	c.x = x; c.y = y; c.a = a; c.model = model; c.max_speed = randf_range(290, 350)
	cars.append(c)
	_rebuild_node(c)
	return c

func _rebuild_node(c: Car) -> void:
	if c.node: c.node.queue_free()
	var spec: Array = MODELS[c.model]
	var root := Node3D.new(); var tilt := Node3D.new(); root.add_child(tilt)
	var model: Node3D = scenes[c.model].instantiate()
	tilt.add_child(model)
	# size the model to its real length; it is built with its front along ±x
	var box := _aabb(model, Transform3D.IDENTITY)
	var k: float = spec[0] * 10.5 * S / maxf(0.001, box.size.x)
	model.scale = Vector3.ONE * k
	if spec[1]: model.rotation.y = PI
	var wheels := []
	_find_wheels(model, wheels)
	var dir := 1.0 if spec[1] else -1.0
	var front := []
	for wn: Node3D in wheels:
		var is_front: bool = (wn.position.x < 0) if spec[1] else (wn.position.x > 0)
		front.append(is_front)
	c.anim = { "tilt": tilt, "wheels": wheels, "front": front, "dir": dir, "spin": 0.0, "roll": 0.0, "pitch": 0.0, "pa": c.a, "pv": c.v }
	add_child(root)
	c.node = root

func _find_wheels(n: Node, out: Array) -> void:
	for ch in n.get_children():
		if ch is Node3D and String(ch.name).begins_with("WHEEL"): out.append(ch)
		else: _find_wheels(ch, out)

func _aabb(n: Node, xf: Transform3D) -> AABB:
	var box := AABB(); var first := true
	var stack := [[n, xf]]
	while stack.size():
		var it: Array = stack.pop_back(); var node: Node = it[0]; var t: Transform3D = it[1]
		if node is Node3D and node != n: t = t * (node as Node3D).transform
		if node is MeshInstance3D:
			var b: AABB = t * (node as MeshInstance3D).get_aabb()
			if first: box = b; first = false
			else: box = box.merge(b)
		for ch in node.get_children(): stack.append([ch, t])
	return box

func _apply_player_stats() -> void:
	var st: Array = PLAYER_STATS.get(player.model, [340, 1.3, 1.1])
	player.max_speed = st[0]; player.acc = st[1]; player.grip = st[2]; player.kind = "civ"; player.driver = false

func cycle_car() -> void:
	player_model = (player_model + 1) % PLAYER_CARS.size()
	player.model = PLAYER_CARS[player_model]; player.v = 0; player.lat = 0; player.w = 0
	_apply_player_stats(); _rebuild_node(player)

# ------------------------------------------------------------------------ loop ----------
func _physics_process(dt: float) -> void:
	var inp: Dictionary = touch_ui.read_input()
	var hit := player.step(city, inp.thr, inp.steer * 0.8, inp.hand, dt)
	if hit > 70: _crash(hit)
	var pp := Vector2(player.x, player.y)
	for c: Car in cars:
		if c == player: continue
		if c.driver: c.drive(city, cars, pp, false, dt)
		else:
			c.v -= c.v * 2.5 * dt; c.step(city, 0, 0, false, dt)
	for i in cars.size():
		for j in range(i + 1, cars.size()):
			var imp := Car.collide(cars[i], cars[j])
			if imp > 70 and (cars[i] == player or cars[j] == player): _crash(imp)
	crash_cd -= dt

func _crash(impact: float) -> void:
	if crash_cd > 0: return
	crash_cd = 0.45; shake = minf(1.0, maxf(shake, impact / 260))
	player.dmg += 2 if impact > 260 else 1
	if OS.has_feature("mobile"): Input.vibrate_handheld(int(minf(60, 15 + impact / 8)))

func _process(dt: float) -> void:
	for c: Car in cars: _place(c, dt)
	# camera: behind the car, a little further back at speed
	var spd := absf(player.v)
	cam_a += wrapf(player.a - cam_a, -PI, PI) * minf(1, dt * 3.6)
	var portrait := get_viewport().get_visible_rect().size.x < get_viewport().get_visible_rect().size.y
	var far := 1.45 if portrait else 1.0
	var dist := (80 + spd * 0.07) * far
	var p := Vector2(player.x - cos(cam_a) * dist, player.y - sin(cam_a) * dist)
	if shake > 0:
		var k := shake * shake * 6; p += Vector2(randf_range(-k, k), randf_range(-k, k)); shake = maxf(0, shake - dt * 2.5)
	cam.position = Vector3(p.x, 36 * far + city.ground_y(player.x, player.y), p.y) * S
	cam.look_at(Vector3(player.x + cos(cam_a) * 45, 9, player.y + sin(cam_a) * 45) * S)
	cam.fov = 60 + spd * 0.035
	sun.global_position = cam.global_position
	hud_speed.text = "%d կմ/ժ" % int(absf(player.v) * 0.42)
	_test_tick()

func _place(c: Car, dt: float) -> void:
	var gy: float = city.ground_y(c.x, c.y)
	c.node.position = Vector3(c.x, gy, c.y) * S
	c.node.rotation.y = -c.a
	var u: Dictionary = c.anim
	if dt <= 0 or (c.node.position - cam.position).length() > 90: return
	u.spin += c.v * dt / 4.02
	var st := clampf(c.steer_in, -1, 1) * 0.42
	for k in u.wheels.size():
		var wn: Node3D = u.wheels[k]
		wn.rotation = Vector3(0, -st * u.dir if u.front[k] else 0.0, u.spin * u.dir)
	var yaw: float = wrapf(c.a - u.pa, -PI, PI) / dt; var accel: float = (c.v - u.pv) / dt; u.pa = c.a; u.pv = c.v
	var roll := clampf(-c.v * yaw * 0.00035, -0.08, 0.08); var pitch := clampf(accel * 0.00022, -0.06, 0.06); var f := minf(1, dt * 6)
	u.roll += (roll - u.roll) * f; u.pitch += (pitch - u.pitch) * f
	(u.tilt as Node3D).rotation = Vector3(u.roll, 0, u.pitch)

# ------------------------------------------------------------------------ HUD ----------
func _hud() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	touch_ui = preload("res://scripts/touch.gd").new()
	touch_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(touch_ui)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.08, 0.09, 0.11, 0.82); sb.set_corner_radius_all(10); sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(16, 12)
	var box := VBoxContainer.new(); panel.add_child(box)
	var title := Label.new(); title.text = "Վարդագույն քաղաք"; title.add_theme_font_size_override("font_size", 18); title.add_theme_color_override("font_color", Color("ff7ab8"))
	hud_speed = Label.new(); hud_speed.add_theme_font_size_override("font_size", 22)
	box.add_child(title); box.add_child(hud_speed)
	if not DisplayServer.is_touchscreen_available():   # on a computer: how to drive with the keyboard
		var keys := Label.new(); keys.add_theme_font_size_override("font_size", 14); keys.add_theme_color_override("font_color", Color("a9a59c"))
		keys.text = "W / S — գազ, արգելակ\nA / D — ղեկ\nSpace — ձեռքի արգելակ\nC — փոխել մեքենան"
		box.add_child(keys)
	layer.add_child(panel)
	var btn := Button.new(); btn.text = "Փոխել մեքենան"; btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 18)
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT); btn.position = Vector2(-220, 14); btn.size = Vector2(200, 46)
	btn.pressed.connect(cycle_car)
	layer.add_child(btn)

# testing aid: `godot -- --shot=/path/out.png [--drive=N] [--frames=N]` drives forward a while, saves a frame and quits
var _test := {}
var _frame := 0
func _test_tick() -> void:
	if _test.is_empty():
		_test = { "on": false }
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shot="): _test.on = true; _test.shot = a.substr(7)
			if a.begins_with("--frames="): _test.frames = int(a.substr(9))
			if a.begins_with("--car="): player.model = a.substr(6); _apply_player_stats(); _rebuild_node(player)
	if not _test.on: return
	touch_ui.touched = true
	_frame += 1
	if _frame < 40: touch_ui.pedals = { 99: "gas" }
	elif _frame < 70: touch_ui.pedals = { 99: "gas" }; touch_ui.steer_id = 98; touch_ui.steer_x = 0.6
	else: touch_ui.pedals = {}; touch_ui.steer_id = -1
	if _frame == _test.get("frames", 120):
		get_viewport().get_texture().get_image().save_png(_test.shot)
		print("SHOT ", _test.shot, " pos ", player.x, " ", player.y, " v ", player.v, " dmg ", player.dmg)
		get_tree().quit()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_C: cycle_car()
