extends Node3D
## Guns, on foot: a pistol, a submachine gun, a shotgun and a rifle, bought in the gun shop (or by a code).
## Left mouse button shoots (held down for the automatic ones), the wheel or Tab changes gun, Q reloads.
## The shot goes where you face, drawn to the nearest person or car in front of you. People fall and the others
## run; cars that take enough hits break down and smoke. Firing calls the police; from three stars they shoot back,
## and your health and armour are on the screen. At no health you wake up at the hospital.

const GUNS := {
	"pistol":  { "name": "Ատրճանակ",       "price": 1500, "mag": 12, "res": 72,  "rate": 0.28, "auto": false, "pellets": 1, "spread": 0.025, "range": 450.0, "dmg": 1.0, "two": false, "pitch": 1.15 },
	"smg":     { "name": "Ավտոմատ",         "price": 4500, "mag": 30, "res": 180, "rate": 0.085, "auto": true, "pellets": 1, "spread": 0.06,  "range": 380.0, "dmg": 0.7, "two": false, "pitch": 1.35 },
	"shotgun": { "name": "Որսորդական հրացան", "price": 6000, "mag": 6, "res": 36,  "rate": 0.85, "auto": false, "pellets": 7, "spread": 0.13,  "range": 240.0, "dmg": 0.8, "two": true,  "pitch": 0.7 },
	"rifle":   { "name": "Հրացան",          "price": 9000, "mag": 30, "res": 150, "rate": 0.12, "auto": true, "pellets": 1, "spread": 0.015, "range": 700.0, "dmg": 1.3, "two": true,  "pitch": 0.9 } }
const ORDER := ["pistol", "smg", "shotgun", "rifle"]

var m
var cur := ""                 # the gun in your hands, "" for none
var cd := 0.0                 # time till the next shot
var reload_t := 0.0
var aim_k := 0.0              # how far the arms are raised
var aim_t := 0.0              # seconds since the last shot
var hp := 100.0
var armor := 0.0
var endless := false          # a code: no reloading, no running out
var holding := false
var gun_nodes := {}
var flash: OmniLight3D
var flash_q: MeshInstance3D
var tracers: Array = []
var tk := 0
var shot_snd: Dictionary = {}
var cop_t := 0.0
var _av = null

func setup(main) -> void:
	m = main
	for id in ORDER:
		var n: Node3D = load("res://assets/weapons/%s.glb" % id).instantiate(); n.visible = false; add_child(n); gun_nodes[id] = n
	flash = OmniLight3D.new(); flash.light_color = Color(1.0, 0.75, 0.4); flash.omni_range = 6; flash.light_energy = 0; add_child(flash)
	flash_q = MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.28, 0.28); flash_q.mesh = q
	var fm := StandardMaterial3D.new(); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fm.albedo_color = Color(3.0, 2.0, 0.8)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; flash_q.material_override = fm
	flash_q.visible = false; add_child(flash_q)
	var tm := StandardMaterial3D.new(); tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; tm.albedo_color = Color(2.5, 2.0, 1.2, 0.7); tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for k in 10:
		var t := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = Vector3(1, 0.012, 0.012); t.mesh = b; t.material_override = tm; t.visible = false
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(t); tracers.append([t, 0.0])
	for id in ORDER:
		var p := AudioStreamPlayer.new(); p.stream = _bang(GUNS[id].pitch, id == "shotgun"); p.max_polyphony = 6; p.volume_db = -3; add_child(p); shot_snd[id] = p
	var cp := AudioStreamPlayer3D.new(); cp.stream = _bang(1.0, false); cp.max_polyphony = 4; cp.unit_size = 12; add_child(cp); shot_snd["cop"] = cp
	var have: Dictionary = m.missions.prog.get("weapons", {})
	if have.size(): cur = ORDER.filter(func(g): return have.has(g))[0]

## A shot made in code: a sharp crack, a thump and a short tail of noise.
func _bang(pitch: float, heavy: bool) -> AudioStreamWAV:
	var rate := 22050; var n := int(rate * (0.6 if heavy else 0.4)); var buf := PackedByteArray(); buf.resize(n * 2)
	var rng := RandomNumberGenerator.new(); rng.seed = int(pitch * 100); var lp := 0.0
	for i in n:
		var t := float(i) / rate
		lp += (rng.randf_range(-1, 1) - lp) * (0.5 if heavy else 0.7) * pitch
		var v := lp * exp(-t * (9.0 if heavy else 14.0)) * 1.4 + sin(t * TAU * 70 * pitch) * exp(-t * 25) * 0.8 + rng.randf_range(-1, 1) * exp(-t * 60) * 0.6
		buf.encode_s16(i * 2, int(clampf(v, -1, 1) * 30000))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.data = buf
	return w

func owned() -> Dictionary:
	if not m.missions.prog.has("weapons") or typeof(m.missions.prog.weapons) != TYPE_DICTIONARY: m.missions.prog.weapons = {}
	return m.missions.prog.weapons

func give(id: String, save := true) -> void:
	var w := owned(); var g: Dictionary = GUNS[id]
	if w.has(id): w[id] = [g.mag, mini(int(w[id][1]) + g.res, g.res * 3)]
	else: w[id] = [g.mag, g.res]
	cur = id
	if save: m.missions.save()

func next_gun(dir := 1) -> void:
	var have := ORDER.filter(func(g): return owned().has(g))
	if have.is_empty(): cur = ""; return
	var opts: Array = [""] + have
	cur = opts[(opts.find(cur) + dir + opts.size()) % opts.size()]
	reload_t = 0.0
	m.toast(GUNS[cur].name if cur != "" else "Զենքը պահեցիր", 1.0)

func can_shoot() -> bool:
	return cur != "" and m.pcar == null and m.interior.inside == "" and not m.ui.busy() and not m.cine.photo and not m.cine.active

func input(e: InputEvent) -> bool:
	if e is InputEventMouseButton and e.pressed and m.pcar == null:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: next_gun(1); return true
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN: next_gun(-1); return true
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		holding = e.pressed
		if e.pressed and can_shoot() and not GUNS[cur].auto: _try_shot()
		return can_shoot()
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_TAB and m.pcar == null: next_gun(1); return true
		if e.keycode == KEY_Q and can_shoot(): _reload(); return true
	return false

func _reload() -> void:
	var a: Array = owned()[cur]; var g: Dictionary = GUNS[cur]
	if int(a[0]) >= g.mag or int(a[1]) <= 0 or reload_t > 0: return
	reload_t = 1.4 if g.two else 1.0
	m.toast("Լիցքավորում…", 0.9)

func _try_shot() -> void:
	if cd > 0 or reload_t > 0: return
	var a: Array = owned()[cur]; var g: Dictionary = GUNS[cur]
	if int(a[0]) <= 0:
		if int(a[1]) > 0: _reload()
		else: m.toast("Փամփուշտ չկա", 1.0)
		return
	if not endless: a[0] = int(a[0]) - 1
	cd = g.rate; aim_t = 0.0
	_fire(g)
	if int(a[0]) <= 0 and int(a[1]) > 0: _reload()

## One trigger pull: each pellet flies along where you face, pulled to the nearest target in a narrow cone.
func _fire(g: Dictionary) -> void:
	var me := Vector2(m.me.x, m.me.y); var fa: float = m.me.a
	var best = null; var bd: float = g.range; var cone := 0.22
	for p in m.peds:
		if p.down > 0 or not p.av.root.visible: continue
		var d := Vector2(p.x, p.y) - me; var L := d.length()
		if L < bd and L > 2 and absf(wrapf(d.angle() - fa, -PI, PI)) < cone: bd = L; best = Vector2(p.x, p.y)
	for c: Car in m.cars:
		var d := Vector2(c.x, c.y) - me; var L := d.length()
		if L < bd and L > 2 and absf(wrapf(d.angle() - fa, -PI, PI)) < cone * 0.8: bd = L; best = Vector2(c.x, c.y)
	var base_a: float = (best - me).angle() if best != null else fa
	var muzzle := _muzzle()
	for k in int(g.pellets):
		var a: float = base_a + randf_range(-g.spread, g.spread)
		_ray(me, Vector2.from_angle(a), g, muzzle)
	flash.global_position = muzzle; flash.light_energy = 6.0; flash_q.global_position = muzzle; flash_q.visible = true
	(shot_snd[cur] as AudioStreamPlayer).volume_db = linear_to_db(maxf(0.0001, 0.8 * m.snd.master)); (shot_snd[cur] as AudioStreamPlayer).play()
	m.shake = maxf(m.shake, 0.08 if not g.two else 0.15)
	m.add_heat(0.35 if m.heat < 1 else 0.12)   # gunfire is heard
	for p in m.peds:
		if absf(p.x - me.x) < 260 and absf(p.y - me.y) < 260: People.panic(p, me)

func _muzzle() -> Vector3:
	var n: Node3D = gun_nodes.get(cur)
	if n and n.visible: return n.global_transform * Vector3(0.5 if GUNS[cur].two else 0.2, 0.06, 0)
	return Vector3(m.me.x, m.city.ground_y(m.me.x, m.me.y) + 14, m.me.y) * m.S

## Steps along the line of fire (game units) until it meets a person, a car or a wall.
func _ray(from: Vector2, dir: Vector2, g: Dictionary, muzzle: Vector3) -> void:
	var t := 4.0; var hit := Vector2.INF; var hy := 1.3
	while t < g.range:
		var p := from + dir * t
		for q in m.peds:
			if q.down <= 0 and absf(q.x - p.x) < 5 and absf(q.y - p.y) < 5:
				q.down = 9.0; m.add_heat(1.0); hit = p; hy = 1.0; break
		if hit != Vector2.INF: break
		for c: Car in m.cars:
			if absf(c.x - p.x) < 22 and absf(c.y - p.y) < 22:
				var lp := (p - Vector2(c.x, c.y)).rotated(-c.a)
				if absf(lp.x) < Car.HX and absf(lp.y) < Car.HY: _car_hit(c, p, g.dmg); hit = p; hy = 0.9; break
		if hit != Vector2.INF: break
		if m.city.push_out(p, 0.5) != p: hit = p; break
		t += 6.0
	if hit == Vector2.INF: hit = from + dir * g.range
	var end := Vector3(hit.x * m.S, m.city.ground_y(hit.x, hit.y) * m.S + hy, hit.y * m.S)
	_tracer(muzzle, end)
	m.fx.spark(hit, 0.15)

func _car_hit(c: Car, p: Vector2, dmg: float) -> void:
	var hp_c: float = c.anim.get("hp", 12.0) - dmg; c.anim.hp = hp_c
	if c.kind == "police": m.add_heat(0.5)
	if c.driver and hp_c > 0 and c.kind != "police": c.stun = 1.5
	if hp_c <= 0 and not c.anim.get("wreck", false):   # broken down: it stops and smokes
		c.anim.wreck = true; c.driver = false; c.chase = false; c.ai = {}; c.v = 0; c.path = []
		var sm := GPUParticles3D.new(); sm.amount = 50; sm.lifetime = 3.0
		var pm := ParticleProcessMaterial.new(); pm.direction = Vector3(0, 1, 0); pm.spread = 15; pm.initial_velocity_min = 1.2; pm.initial_velocity_max = 2.2
		pm.gravity = Vector3(0, 0.4, 0); pm.scale_curve = m.fx._grow(); pm.color_ramp = m.fx._fade(0.7); sm.process_material = pm
		var q := QuadMesh.new(); q.size = Vector2(1.1, 1.1); q.material = m.fx._puff_mat(Color(0.12, 0.12, 0.13, 0.7)); sm.draw_pass_1 = q
		sm.position = Vector3(1.4, 1.1, 0); c.node.add_child(sm)
		if c == m.pcar: c.dmg = maxi(c.dmg, 10); m.fx.damage_look(c)
		m.snd.crash_hit(0.8)

func _tracer(a: Vector3, b: Vector3) -> void:
	var t: Array = tracers[tk]; tk = (tk + 1) % tracers.size()
	var mi: MeshInstance3D = t[0]; var d := b - a; var L := d.length()
	if L < 0.1: return
	mi.global_transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP) * Basis(Vector3.UP, PI / 2) * Basis.from_scale(Vector3(L, 1, 1)), (a + b) / 2)
	mi.visible = true; t[1] = 0.07

## Police shoot back from three stars, when you are on foot and they are close.
func _cops(dt: float) -> void:
	if m.heat < 3 or m.interior.inside != "" or m.pcar != null: return
	cop_t -= dt
	if cop_t > 0: return
	cop_t = randf_range(0.5, 1.1) / (m.heat - 1.5)
	var me := Vector2(m.me.x, m.me.y)
	for c: Car in m.cars:
		if c.kind != "police" or not c.chase or c.anim.get("wreck", false): continue
		var d := Vector2(c.x, c.y).distance_to(me)
		if d > 320: continue
		var from := Vector3(c.x * m.S, 1.4, c.y * m.S); var to := Vector3(m.me.x * m.S, m.city.ground_y(m.me.x, m.me.y) * m.S + 1.2, m.me.y * m.S)
		var sp := shot_snd["cop"] as AudioStreamPlayer3D; sp.global_position = from; sp.play()
		if randf() < 0.28 - d / 2000.0: hurt(randf_range(6, 11)); _tracer(from, to)
		else: _tracer(from, to + Vector3(randf_range(-1.5, 1.5), randf_range(-0.5, 0.8), randf_range(-1.5, 1.5)))
		break

func hurt(n: float) -> void:
	var a := minf(armor, n * 0.7); armor -= a; hp -= n - a
	m.shake = maxf(m.shake, 0.25)
	if hp <= 0: _down()

func _down() -> void:   # wake up at the hospital by the square: a bill, no stars, health back
	var bill := mini(m.missions.cash, 1000 + int(m.missions.cash * 0.05))
	m.missions.cash -= bill; m.missions.save()
	hp = 100; armor = 0; m.heat = 0
	for c: Car in m.cars: if c.kind == "police": c.chase = false
	if m.pcar: m.pcar = null
	m.me.x = m.ic(3) + 96; m.me.y = m.ic(2) + 76
	m.toast("Հիվանդանոցում ես. հաշիվը՝ " + m.missions.money(bill), 4)

func tick(dt: float) -> void:
	cd -= dt; aim_t += dt; _cops(dt)
	if reload_t > 0:
		reload_t -= dt
		if reload_t <= 0 and cur != "":
			var a: Array = owned()[cur]; var need: int = GUNS[cur].mag - int(a[0]); var take := mini(need, int(a[1]))
			a[0] = int(a[0]) + take; a[1] = int(a[1]) - take
	if holding and can_shoot() and GUNS[cur].auto: _try_shot()
	flash.light_energy = maxf(0.0, flash.light_energy - dt * 120); flash_q.visible = flash.light_energy > 1.0
	for t in tracers:
		if t[1] > 0:
			t[1] -= dt
			if t[1] <= 0: (t[0] as MeshInstance3D).visible = false
	if hp < 100 and m.heat <= 0: hp = minf(100, hp + dt * 2.0)   # health comes back slowly when nobody is after you

## After the avatar is posed (main._process): raise the arms when shooting, put the gun in the hand.
func pose(dt: float) -> void:
	for id in gun_nodes: (gun_nodes[id] as Node3D).visible = false
	var on_foot: bool = m.pcar == null and m.interior.inside == "" and cur != ""
	var want := 1.0 if on_foot and (aim_t < 1.6 or holding) else 0.0
	aim_k += (want - aim_k) * minf(1, dt * 10)
	if not on_foot: return
	var av = m.me_av
	if av.skel == null: return
	var g: Dictionary = GUNS[cur]
	av.aim(g.two, aim_k)
	var hb: int = av.bones.get("R Hand", -1)
	if hb < 0: return
	var hand: Vector3 = av.skel.global_transform * av.pose_global(hb).origin
	var n: Node3D = gun_nodes[cur]; n.visible = true
	var face := Basis(Vector3.UP, -m.me.a)
	var down := Basis(Vector3.FORWARD, 1.2 * (1.0 - aim_k))   # pointing at the ground when lowered
	n.global_transform = Transform3D(face * down, hand + Vector3(0, 0.03, 0))

func hud_text() -> String:
	var s := "♥ %d" % int(hp)
	if armor > 0: s += "   ◆ %d" % int(armor)
	if cur != "":
		var a: Array = owned()[cur]
		s += "   %s  %s" % [GUNS[cur].name, ("∞" if endless else "%d / %d" % [int(a[0]), int(a[1])])]
	return s

## The gun shop: buy a gun with its ammunition, more ammunition, or a vest.
func shop() -> void:
	var items := []
	for id in ORDER:
		var g: Dictionary = GUNS[id]; var have: bool = owned().has(id)
		items.append({ "label": g.name + (" — փամփուշտ" if have else ""), "price": m.missions.money(g.price / 4 if have else g.price), "go": _buy.bind(id) })
	items.append({ "label": "Զրահաբաճկոն", "price": m.missions.money(2500), "go": _vest })
	m.ui.panel("Զենքի խանութ", "Մկնիկի ձախ կոճակ՝ կրակել, անիվ կամ Tab՝ զենքը փոխել, Q՝ լիցքավորել։ Կրակոցը ոստիկաններին է կանչում։", items)

func _buy(id: String) -> void:
	var price: int = GUNS[id].price / 4 if owned().has(id) else GUNS[id].price
	m.missions.pay(price, _bought.bind(id))

func _bought(id: String) -> void:
	give(id); shop()

func _vest() -> void:
	m.missions.pay(2500, _vested)

func _vested() -> void:
	armor = 100.0; shop()

func _input(e: InputEvent) -> void:
	if m and input(e): get_viewport().set_input_as_handled()
