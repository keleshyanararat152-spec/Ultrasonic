extends Node
## Replay and photo mode.
## Replay: the last eight seconds of every car and of you are kept; after a big crash press R to watch it again
## in slow motion from a camera that circles the wreck, then the game carries on where it was.
## Photo mode: P stops the city; fly the camera with W A S D, Q / E for up and down, the arrow keys or the mouse
## to look, Z / X for zoom, F for a soft background; Enter saves a picture (in the game's folder: photos).

const KEEP := 480            # physics frames kept (8 s)
var m
var buf: Array = []          # [ { cars: [[car, x, y, a, v]], me: [x, y, a] } ]
var active := false          # a replay playing
var photo := false
var pos := 0.0
var crash_at := -1           # index in buf of the last big crash, or -1
var crash_t := 0.0           # how long ago it happened
var label: Label
var cam_p := Vector3.ZERO
var yaw := 0.0
var pitch := -0.2
var fov := 55.0
var dof := false
var mouse_look := Vector2.ZERO

func setup(main, layer: CanvasLayer) -> void:
	m = main
	label = Label.new(); label.add_theme_font_size_override("font_size", 22); label.visible = false
	label.add_theme_color_override("font_color", Color("ff5a5f")); label.position = Vector2(24, 20)
	layer.add_child(label)

func record() -> void:
	if active or photo: return
	var snap := { "cars": [], "me": [m.me.x, m.me.y, m.me.a], "pcar": m.pcar }
	for c: Car in m.cars: snap.cars.append([c, c.x, c.y, c.a, c.v])
	buf.append(snap)
	if buf.size() > KEEP: buf.pop_front(); crash_at -= 1
	if crash_t > 0: crash_t -= 1.0 / 60.0

func crashed(impact: float) -> void:
	if impact < 240 or active: return
	crash_at = buf.size() - 1; crash_t = 6.0
	m.toast("R — կրկնել վթարը", 3)

func start_replay() -> void:
	if buf.size() < 30 or active or photo: return
	active = true; pos = float(maxi(0, (crash_at if crash_at > 0 else buf.size() - 1) - 240))
	label.text = "● ԿՐԿՆՈՒԹՅՈՒՆ   R — դուրս"; label.visible = true

func stop_replay() -> void:
	if not active: return
	active = false; label.visible = false
	_apply(buf[buf.size() - 1])   # back to now

func _apply(s: Dictionary) -> void:
	for e in s.cars:
		var c = e[0]
		if is_instance_valid(c.node): c.x = e[1]; c.y = e[2]; c.a = e[3]; c.v = e[4]
	m.me.x = s.me[0]; m.me.y = s.me[1]; m.me.a = s.me[2]

## Called instead of the city's physics while a replay runs: half speed, then back to the game.
func step(dt: float) -> void:
	pos += dt * 60.0 * 0.5
	if pos >= buf.size() - 1: stop_replay(); return
	_apply(buf[int(pos)])

## Camera for the replay and photo mode (from main._process, after the normal camera).
func camera(dt: float) -> void:
	var cam: Camera3D = m.cam
	if active:
		var s: Dictionary = buf[int(pos)]; var c = s.pcar
		var t := Vector2(s.me[0], s.me[1])
		if c != null and is_instance_valid(c.node): t = Vector2(c.x, c.y)
		var gy: float = m.city.ground_y(t.x, t.y)
		var a := pos * 0.006
		cam.position = Vector3(t.x + cos(a) * 75, gy + 22, t.y + sin(a) * 75) * m.S
		cam.look_at(Vector3(t.x, gy + 6, t.y) * m.S); cam.fov = 50
	elif photo:
		var mv := Vector3.ZERO
		if Input.is_key_pressed(KEY_W): mv.z -= 1
		if Input.is_key_pressed(KEY_S): mv.z += 1
		if Input.is_key_pressed(KEY_A): mv.x -= 1
		if Input.is_key_pressed(KEY_D): mv.x += 1
		if Input.is_key_pressed(KEY_E): mv.y += 1
		if Input.is_key_pressed(KEY_Q): mv.y -= 1
		if Input.is_key_pressed(KEY_LEFT): yaw += dt * 1.4
		if Input.is_key_pressed(KEY_RIGHT): yaw -= dt * 1.4
		if Input.is_key_pressed(KEY_UP): pitch = minf(1.4, pitch + dt * 1.0)
		if Input.is_key_pressed(KEY_DOWN): pitch = maxf(-1.4, pitch - dt * 1.0)
		if Input.is_key_pressed(KEY_Z): fov = maxf(15, fov - dt * 25)
		if Input.is_key_pressed(KEY_X): fov = minf(90, fov + dt * 25)
		yaw -= mouse_look.x * 0.004; pitch = clampf(pitch - mouse_look.y * 0.004, -1.4, 1.4); mouse_look = Vector2.ZERO
		var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
		cam_p += (b * Vector3(mv.x, 0, mv.z) + Vector3(0, mv.y, 0)) * dt * 8.0
		cam_p.y = maxf(0.3, cam_p.y)
		cam.transform = Transform3D(b, cam_p); cam.fov = fov

func toggle_photo() -> void:
	if active: return
	photo = not photo
	m.hud_layer.visible = not photo
	label.visible = photo
	if photo:
		cam_p = m.cam.global_position; yaw = m.cam.global_rotation.y; pitch = m.cam.global_rotation.x; fov = m.cam.fov
		label.text = "ՖՈՏՈՌԵԺԻՄ   WASD QE · սլաքներ · Z/X · F · Enter — նկարել · P — դուրս"
		label.reparent(m.photo_layer)
	else:
		label.reparent(m.hud_layer); _dof(false)

func _dof(on: bool) -> void:
	dof = on
	if m.cam.attributes == null: m.cam.attributes = CameraAttributesPractical.new()
	var a: CameraAttributesPractical = m.cam.attributes
	a.dof_blur_far_enabled = on; a.dof_blur_far_distance = 12.0; a.dof_blur_far_transition = 20.0; a.dof_blur_amount = 0.12

func save_photo() -> void:
	label.visible = false
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://photos")
	var path := "user://photos/pink_city_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	m.get_viewport().get_texture().get_image().save_png(path)
	label.visible = true; label.text = "Պահվեց՝ " + ProjectSettings.globalize_path(path)

func input(e: InputEvent) -> bool:   # true when the key was ours
	if e is InputEventMouseMotion and photo and (e.button_mask & MOUSE_BUTTON_MASK_RIGHT): mouse_look += e.relative; return true
	if not (e is InputEventKey and e.pressed and not e.echo): return false
	match e.keycode:
		KEY_R:
			if active: stop_replay()
			elif not photo and crash_at >= 0: start_replay()
			else: return false
			return true
		KEY_P: toggle_photo(); return true
		KEY_F: if photo: _dof(not dof); return true
		KEY_ENTER, KEY_KP_ENTER: if photo: save_photo(); return true
	return false
