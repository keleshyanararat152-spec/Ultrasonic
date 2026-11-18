extends Node3D
## Stage 3: money, delivery jobs and taxi fares, the race and escape rings, and the five-chapter story.
## A port of newOffer / actUpdate / the story (CHS, storyNext, storyStep ...) from game/city/index.html.
## Positions are in game units on the ground (x, y); main.gd turns them into the 3D world.

const CELL := 520
const N := 7
const S := 0.1
const SAVE_PATH := "user://save.json"

var m                       # main.gd
var cash := 0
var prog := {}              # story chapters done, race record, and (stage 4) cars, outfits, home
var job = null              # a delivery or a taxi fare: { kind, stage, p, label, time, pay, dmg0, hits }
var act = null              # a running activity: race, escape or a story chapter
var places: Array = []      # rings you drive or walk into
var wp = null               # the waypoint you set on the big map (Vector2 or null)
var club_rect := {}
var club_door := Vector2.ZERO
var saved_cash := -1
var save_t := 0.0
var sp := {}                # story spots
var st := { "arm": true, "failed": false, "chain_t": 0.0 }
var npc := {}               # story characters standing in the city: id -> People.Avatar
var beam: MeshInstance3D    # the pink light over whoever waits for you
var marker: MeshInstance3D  # the column over the current goal
var marker_mat: StandardMaterial3D

const CAST := {
	"gurgen": { "gen": "Գուրգեն քեռու", "name": "Գուրգեն քեռի", "nom": "Գուրգեն քեռին", "av": "m02", "col": "ffcf4a" },
	"nare": { "gen": "Նարեի", "name": "Նարե", "nom": "Նարեն", "av": "f05", "col": "ff8fb8" },
	"rubo": { "gen": "Ռուբոյի", "name": "Ռուբո", "nom": "Ռուբոն", "av": "m04", "col": "ff5a5f" },
	"levon": { "gen": "Լևոնի", "name": "Լևոն", "nom": "Լևոնը", "av": "m17", "col": "35d6e6" },
	"lilit": { "gen": "Լիլիթի", "name": "Լիլիթ", "nom": "Լիլիթը", "av": "f13", "col": "b48cff" },
	"you": { "name": "Դու", "col": "f1ede6" } }
const ICON := { "dealer": "4d8dff", "clothes": "b48cff", "home": "58d68d", "race": "35d6e6", "escape": "ff5a5f", "pickup": "ffcf4a", "deliver": "58d68d",
	"cp": "35d6e6", "wp": "ff9f1c", "square": "4f9fc0", "story": "ff4fa3", "rival": "35d6e6", "club": "ff4fa3" }
const PLACE_NAME := { "square": "Հրապարակ", "club": "Նեոն ակումբ", "race": "Մրցարշավ", "escape": "Փախուստ", "dealer": "Ավտոսրահ", "clothes": "Հագուստ", "home": "Տուն" }
const GOODS := ["լավաշ", "ծաղիկներ", "ծանրոց", "խորոված", "ուղևոր", "դեղորայք", "ծիրան"]

var chs: Array = []

static func money(n: float) -> String:
	var s := str(int(round(absf(n)))); var out := ""
	while s.length() > 3: out = " " + s.substr(s.length() - 3) + out; s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out + " ֏"

static func fmt_t(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]

static func ic(i: int) -> float:
	return i * CELL + 60.0

# ------------------------------------------------------------------------- setup ----------
func setup(main) -> void:
	m = main
	for ij in [[4, 3], [3, 2], [2, 3], [3, 4], [4, 4], [2, 2], [4, 2]]:   # the club takes the first building near the square
		var b: Dictionary = m.city.blocks[ij[0]][ij[1]]
		if b.type == "b": club_rect = b.rects[0]; break
	club_door = Vector2(club_rect.x + club_rect.w / 2, club_rect.y - 10)
	_build_places()
	_build_story()
	marker_mat = StandardMaterial3D.new(); marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; marker_mat.cull_mode = BaseMaterial3D.CULL_DISABLED; marker_mat.no_depth_test = false
	var cm := CylinderMesh.new(); cm.top_radius = 3.4; cm.bottom_radius = 3.4; cm.height = 14; cm.cap_top = false; cm.cap_bottom = false
	marker = MeshInstance3D.new(); marker.mesh = cm; marker.material_override = marker_mat; marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	_load()
	new_offer()

func _ring(x: float, y: float, r0: float, r1: float, col: Color) -> MeshInstance3D:
	var t := TorusMesh.new(); t.inner_radius = r0 * S; t.outer_radius = r1 * S; t.rings = 40; t.ring_segments = 6
	var mi := MeshInstance3D.new(); mi.mesh = t; mi.scale = Vector3(1, 0.06, 1)
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.albedo_color = col
	mi.material_override = mat; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(x, m.city.ground_y(x, y) + 0.5, y) * S
	add_child(mi)
	return mi

func _sign(x: float, y: float, text: String, col: Color) -> void:
	var l := Label3D.new(); l.text = text; l.font = load("res://fonts/NotoSansArmenian.ttf"); l.font_size = 96; l.pixel_size = 0.012
	l.modulate = Color.WHITE; l.outline_modulate = col.darkened(0.5); l.outline_size = 24; l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position = Vector3(x, 34, y) * S; l.no_depth_test = false
	add_child(l)

func _build_places() -> void:
	var defs := [{ "id": "dealer", "b": [1, 2], "car": false }, { "id": "clothes", "b": [2, 4], "car": false }, { "id": "home", "b": [4, 1], "car": false },
		{ "id": "race", "b": [5, 5], "car": true }, { "id": "escape", "b": [1, 5], "car": true }]
	var ci := int(club_rect.x / CELL); var cj := int(club_rect.y / CELL)
	for d in defs:
		var i: int = d.b[0]; var j: int = (d.b[1] + 1) % N if (d.b[0] == ci and d.b[1] == cj) else d.b[1]
		var x := i * CELL + 270.0; var y := j * CELL + (92.0 if d.car else 131.0)
		var col := Color(ICON[d.id])
		_ring(x, y, 20 if d.car else 9, 24 if d.car else 12, col)
		if d.id != "home": _sign(x, j * CELL + (128.0 if d.car else 140.0), PLACE_NAME[d.id].to_upper(), col)
		places.append({ "id": d.id, "x": x, "y": y, "j": j, "car": d.car, "arm": false, "park": Vector3(x + 80, j * CELL + 98, 0) })
	_ring(club_door.x, club_door.y, 9, 12, Color(ICON.club))
	_sign(club_door.x, club_door.y + 8, "ՆԵՈՆ ԱԿՈՒՄԲ", Color(ICON.club))

# ----------------------------------------------------------------- money and saving ----------
func prog0() -> Dictionary:
	return { "cars": [], "car": null, "outfit": "m07", "outfits": ["m07"], "home": false, "race_best": 0.0, "story": 0, "kind": false, "vip_table": false }

func place(id: String):
	for pl in places: if pl.id == id: return pl
	return null

func pay(price: int, ok: Callable) -> void:
	if cash < price: m.toast("Փողդ չի հերիքում. պակասում է " + money(price - cash)); return
	cash -= price; ok.call(); save()

func _load() -> void:
	prog = prog0()
	if not FileAccess.file_exists(SAVE_PATH): return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null: return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY: return
	cash = int(d.get("cash", 0))
	var p = d.get("prog", {})
	if typeof(p) == TYPE_DICTIONARY:
		for k in p: prog[k] = p[k]
	prog.story = int(prog.story)
	saved_cash = cash

func save() -> void:
	saved_cash = cash
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({ "cash": cash, "prog": prog }))

func earn(n: int) -> void:
	cash += n; save()

# ------------------------------------------------------------------------- jobs ----------
func road_point() -> Vector2:   # a random spot in the middle of a street
	var k := randi_range(0, N); var t := ic(randi_range(0, N - 1)) + randf_range(150, 370)
	return Vector2(t, ic(k)) if randf() < 0.5 else Vector2(ic(k), t)

func _in_taxi() -> bool:
	return m.pcar != null and m.pcar.model == "taxi"

func new_offer() -> void:
	if _in_taxi(): job = { "kind": "taxi", "stage": "pickup", "p": road_point(), "label": "ուղևոր" }; return
	job = { "kind": "goods", "stage": "pickup", "p": road_point(), "label": GOODS.pick_random() }

func on_enter_car(c) -> void:
	if c.model == "taxi" and not (job and (job.kind == "taxi" or job.stage == "deliver")):
		new_offer(); m.toast("Դու տաքսիստ ես. վերցրու ուղևորներին")

func on_exit_car() -> void:
	if job and job.kind == "taxi" and job.stage == "pickup": new_offer()

func _jobs(dt: float, tg: Vector2) -> void:
	if job == null or act != null: return
	var d := tg.distance_to(job.p)
	if job.stage == "pickup" and d < 38 and (job.kind != "taxi" or (_in_taxi() and absf(m.pcar.v) < 140)):
		var to := road_point()
		while to.distance_to(job.p) < 900: to = road_point()
		var L := absf(to.x - job.p.x) + absf(to.y - job.p.y)
		job.stage = "deliver"; job.p = to; job.time = L / 150 + 12; job.pay = roundi((L * 1.6 + 600) / 100) * 100
		if job.kind == "taxi":
			job.dmg0 = m.pcar.dmg; job.time = L / 140 + 20; job.pay = roundi((L * 1.3 + 500) / 100) * 100
			m.toast("Ուղևորը նստեց. տար զգույշ, առանց վթարի")
		else: m.toast("Վերցված է, շտապիր")
	elif job.stage == "deliver":
		job.time -= dt
		var hits: int = (m.pcar.dmg - job.dmg0) if (job.kind == "taxi" and m.pcar) else 0
		job.hits = hits
		if job.kind == "taxi" and not _in_taxi(): m.toast("Ուղևորը իջավ"); new_offer()
		elif hits >= 4: m.toast("Ուղևորը վախեցավ ու իջավ"); new_offer()
		elif d < 38:
			var tip := roundi(job.time * 20 / 100) * 100; var got := roundi((job.pay + tip) * (1 - 0.2 * hits) / 100) * 100
			earn(got)
			m.toast(("Ուղևորը դժգոհ է  +" if hits else "Ուղևորը գոհ է  +") + money(got) if job.kind == "taxi" else "Հասցված է  +" + money(got))
			new_offer()
		elif job.time <= 0: m.toast("Ուշացար, պատվերը չեղարկվեց"); new_offer()

# ------------------------------------------------------------------ race and escape ----------
func _place_check(tg: Vector2) -> void:
	if act != null: return
	for pl in places:
		var d := tg.distance_to(Vector2(pl.x, pl.y)); var r := 26.0 if pl.car else 13.0
		if d > r + 22: pl.arm = true
		elif d < r and pl.arm:
			pl.arm = false
			if pl.car and not m.pcar: m.toast("Այստեղ մեքենայով արի")
			elif not pl.car and m.pcar: m.toast("Իջիր մեքենայից ու ոտքով մտիր օղակը")
			else: _open_place(pl)

func _open_place(pl) -> void:
	if pl.id in ["dealer", "clothes", "home"]: m.interior.open_place(pl); return
	if pl.id == "race":
		m.ui.panel("Մրցարշավ", "Անցիր 6 ստուգակետով ժամանակին։ Մրցանակ՝ 2 500 ֏, գումարած 50 ֏ մնացած ամեն վայրկյանի համար։" + (" Ռեկորդդ՝ " + fmt_t(prog.race_best) + "։" if prog.race_best > 0 else ""),
			[{ "label": "Սկսել", "go": _go_race.bind(pl) }])
	elif pl.id == "escape":
		m.ui.panel("Փախուստ", "Կստանաս 3 աստղ։ Կորիր ոստիկաններից 2 րոպեում ու մի բռնվիր։ Մրցանակ՝ 3 500 ֏։",
			[{ "label": "Սկսել", "go": _go_escape }])

func _go_race(pl) -> void:
	m.ui.close_panel(); _start_race(pl)

func _go_escape() -> void:
	m.ui.close_panel(); m.heat = 3; m.evade_t = 0; act = { "kind": "escape", "time": 120.0, "goal": null }; m.toast("Ոստիկանները քո հետևից են")

func race_cps(I: int, J: int) -> Array:
	var cps := []
	for k in 6:
		var ni := I; var nj := J
		for tries in 60:
			ni = clampi(I + randi_range(-3, 3), 0, N); nj = clampi(J + randi_range(-3, 3), 0, N)
			var dup := false
			for q in cps: if q.i == ni and q.j == nj: dup = true
			if absi(ni - I) + absi(nj - J) >= 2 and not dup: break
		I = ni; J = nj; cps.append({ "x": ic(I), "y": ic(J), "i": I, "j": J })
	return cps

func _start_race(pl) -> void:
	var I := clampi(roundi((pl.x - 60) / CELL), 0, N); var J := clampi(roundi((pl.y - 60) / CELL), 0, N)
	var cps := race_cps(I, J); var L := 0.0; var px: float = pl.x; var py: float = pl.y
	for c in cps: L += absf(c.x - px) + absf(c.y - py); px = c.x; py = c.y
	act = { "kind": "race", "cps": cps, "k": 0, "time": float(roundi(L / 230 + 10)), "t0": m.time, "goal": { "p": Vector2(cps[0].x, cps[0].y), "stage": "race" } }
	m.toast("Գնա՛ · %d ստուգակետ" % cps.size())

func _act_end(msg: String) -> void:
	act = null; m.toast(msg)

func _act_update(dt: float, tg: Vector2) -> void:
	if act == null: return
	act.time -= dt
	if act.kind == "story": _story_step(dt, tg); return
	if act.kind == "race":
		if not m.pcar: _act_end("Մրցարշավը ընդհատվեց՝ իջար մեքենայից"); return
		var c = act.cps[act.k]
		if tg.distance_to(Vector2(c.x, c.y)) < 55:
			act.k += 1
			if act.k >= act.cps.size():
				var took: float = m.time - act.t0; var prize := 2500 + roundi(maxf(0, act.time)) * 50
				var rec: bool = prog.race_best <= 0 or took < prog.race_best
				if rec: prog.race_best = took
				earn(prize)
				_act_end("Ավարտ՝ " + fmt_t(took) + (" · նոր ռեկորդ" if rec else "") + "  +" + money(prize)); return
			act.goal.p = Vector2(act.cps[act.k].x, act.cps[act.k].y)
		if act.time <= 0: _act_end("Ժամանակը սպառվեց")
	elif act.kind == "escape":
		if m.heat <= 0: earn(3500); _act_end("Փախար  +" + money(3500)); return
		if act.time <= 0: _act_end("Չհասցրիր փախչել")

func on_busted() -> void:
	var fine := roundi(cash * 0.2 / 100) * 100
	cash -= fine; save()
	if job and job.stage == "deliver": new_offer()
	var msg := ("Բռնվեցիր, տուգանք " + money(fine)) if fine > 0 else "Բռնվեցիր"
	if story_on(): story_fail(msg); return
	m.toast(("Առաջադրանքը ձախողվեց. " if act else "") + msg, 3); act = null

# ------------------------------------------------------------------------ the story ----------
func _build_story() -> void:
	var pv := func(i: int, j: int, dx: float) -> Vector2: return Vector2(i * CELL + dx, j * CELL + 131)
	var kerb := func(i: int, j: int, dx: float) -> Vector2: return Vector2(i * CELL + dx, j * CELL + 92)
	var sq := Vector2(3 * CELL + 320, 3 * CELL + 320)
	var cj := int(club_rect.y / CELL)
	sp = { "square": sq + Vector2(-60, -150), "garage": pv.call(1, 3, 330), "garageCar": kerb.call(1, 3, 330), "taxi": Vector3(2 * CELL + 300, ic(5) + 50, 0),
		"bakery": pv.call(5, 1, 330), "lav": [Vector2(ic(6), CELL + 300), Vector2(4 * CELL + 300, ic(0)), Vector2(ic(4), 2 * CELL + 330)],
		"rubo": Vector3(5 * CELL + 180, ic(1) + 28, 0), "levon": pv.call(5, 5, 430), "rival": Vector3(5 * CELL + 430, ic(5) + 28, 0),
		"lilit": club_door + Vector2(45, -4), "courier": Vector3(club_door.x - 150, ic(cj) + 28, 0),
		"finalL": sq + Vector2(0, -150), "finalG": sq + Vector2(-26, -160), "finalN": sq + Vector2(26, -160) }
	var bm := CylinderMesh.new(); bm.top_radius = 22 * S; bm.bottom_radius = 22 * S; bm.height = 420 * S; bm.cap_top = false; bm.cap_bottom = false
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.albedo_color = Color(1, 0.31, 0.64, 0.32)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.cull_mode = BaseMaterial3D.CULL_DISABLED; mat.disable_fog = true
	beam = MeshInstance3D.new(); beam.mesh = bm; beam.material_override = mat; beam.visible = false; beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	chs = [
		{ "title": "Վերադարձ", "who": "gurgen", "at": "square", "reward": 1500,
			"intro": [["gurgen", "Վա՜յ, ո՞վ եմ տեսնում։ Եկա՞ր, տղաս։ Տասը տարի է՝ քեզ չեմ տեսել։"],
				["you", "Բարև, Գուրգեն քեռի։ Զանգել էիր, ասում էիր՝ օգնություն է պետք։"],
				["gurgen", "Պետք է, պետք է։ Բայց նախ մի փոքր գործ։ Իմ հին տաքսին կանգնած է հարավում՝ մի բակի մոտ։ Տղաները նորոգել են, պետք է բերել արհեստանոց։"],
				{ "choice": [["Հեշտ բան է, քեռի", [["gurgen", "Միայն զգույշ, լա՞վ։ Նա ինձնից էլ է ծեր։ Ոչ մի տեղ չխփես։"]]],
					["Էդ մեքենան դեռ քշո՞ւմ է", [["gurgen", "Քշում է, ու քեզնից լավ։ Բայց ոչ մի տեղ չխփես, նա ինձնից էլ է ծեր։"]]]] }],
			"retry": [["gurgen", "Ոչինչ, տղաս, պատահում է։ Տղաները տաքսին նորից տեղն են դրել, գնա բեր։"]],
			"steps": [
				{ "t": "getcar", "label": "Գտիր Գուրգենի հին դեղին տաքսին" },
				{ "t": "drive", "to": "garageCar", "time": 150.0, "hits": 3, "label": "Տար տաքսին Գուրգենի արհեստանոց" },
				{ "t": "talk", "who": "gurgen", "at": "garage", "lines": [["gurgen", "Ամբողջական է։ Ապրես, տղաս։"],
					["gurgen", "Հիմա լսիր, թե ինչու եմ քեզ կանչել։ «Ոսկե աշտարակ» ընկերությունը ուզում է քանդել մեր ամբողջ թաղը՝ արհեստանոցս, փռերը, հրապարակի կրպակները, ու տեղը ապակե աշտարակ կառուցել։"],
					["you", "Իսկ դուք համաձա՞յն չեք։"],
					["gurgen", "Ո՞վ է համաձայն։ Բայց Սարգիս Ոսկանյանը «ոչ» չի ընդունում։ Նրա մարդիկ ամեն օր գալիս են ու ստիպում ստորագրել։"],
					["gurgen", "Գնա Նարեի մոտ՝ իմ աղջկա։ Արևելքում փուռ ունի։ Նրան էլ են նեղացնում, բայց ինձ չի ասում, որ չանհանգստանամ։"]] }] },
		{ "title": "Լավաշ ու սպառնալիք", "who": "nare", "at": "bakery", "reward": 2000,
			"intro": [["nare", "Դու ես, չէ՞, հայրիկիս ասած հյուրը։ Լավ ժամանակին ես եկել։"],
				["nare", "Առաքիչս այսօր հրաժարվեց, ասում է՝ իրեն սպառնացել են։ Իսկ ես երեք պատվեր ունեմ, ու լավաշը սառչում է։"],
				["you", "Տուր, ես կտանեմ։"],
				["nare", "Իսկական փրկիչ ես։ Երեք հասցե, իրար հետևից։ Մեքենայով արագ կլինի։"]],
			"retry": [["nare", "Ոչինչ, նոր խմորից թխեցի։ Նույն երեք հասցեն են, արի նորից փորձենք։"]],
			"steps": [
				{ "t": "multi", "time": 170.0, "label": "Հասցրու տաք լավաշը" },
				{ "t": "talk", "who": "nare", "at": "bakery", "lines": [["nare", "Բոլորը գոհ են, տաք-տաք հասավ։ Բայց տես, թե ինչ արեցին մինչ դու գնացել էիր…"],
					["you", "Ապակի՞ն… Ո՞վ է արել։"],
					["nare", "Ռուբոն։ Ոսկանյանի մարդն է։ Ասաց՝ եթե մինչև շաբաթվա վերջ չստորագրենք, փուռը կփակվի։ Միայն հայրիկին չասես, խնդրում եմ։"],
					["nare", "Վերցրու, սա քո աշխատածն է։"],
					{ "choice": [["Շնորհակալություն", [["nare", "Արժանի ես։"]]],
						["Պահիր, ապակին նորոգիր", [_set_kind, ["nare", "Դու լավ մարդ ես։ Չեմ մոռանա։"]]]] },
					["nare", "Ռուբոյի սև մեքենան հենց հիմա կանգնած է փողոցում։ Հետևիր նրան, տես՝ ուր է գնում։ Միայն թե չմոտենաս, թե չէ կնկատի։"]] }] },
		{ "title": "Ստվեր", "who": "nare", "at": "bakery", "reward": 3000, "chain": true,
			"intro": [["nare", "Ռուբոն դեռ այնտեղ է։ Նստիր մեքենա ու հեռվից հետևիր։"]],
			"retry": [["nare", "Ռուբոն նորից մոտակայքում է։ Այս անգամ ավելի զգույշ։"]],
			"steps": [
				{ "t": "tail", "dur": 55.0 },
				{ "t": "talk", "who": "rubo", "at": _at_rubo, "lines": [["rubo", "Էս ո՞վ է։ Ամբողջ ճանապարհին հետևիցս էիր գալիս, կարծում էիր չե՞մ տեսնում։"],
					["you", "Թողեք Գուրգենին ու Նարեին հանգիստ։"],
					["rubo", "Ես պատվեր եմ կատարում, ընկեր ջան։ Իսկ դու հիմա իսկական խնդիր ունես։"],
					["rubo", "Ալո՞… Այո, պարոն լեյտենանտ։ Մի կասկածելի տիպ է այստեղ, մեքենաներ է ջարդում։ Արագ եկեք։"]] },
				{ "t": "escape", "heat": 3, "time": 150.0, "label": "Կորիր ոստիկաններից" },
				{ "t": "talk", "who": "gurgen", "at": "garage", "no_heat": true, "lines": [["gurgen", "Ոստիկանությո՞ւն էլ են կանչում… Ոսկանյանը կես քաղաքը գնել է։"],
					["gurgen", "Բայց մի մարդ կա, որ կարող է օգնել՝ Լևոնը։ Գիշերային մրցարշավներ է անում։ Փողոցներում ինչ կատարվում է, նա գիտի։"],
					["gurgen", "Ժամանակին մեքենան եմ նորոգել, պարտք է ինձ։ Գնա, նա հարավ-արևելքում է, մրցարշավի օղակի մոտ։"]] }] },
		{ "title": "Լևոնի խաղը", "who": "levon", "at": "levon", "reward": 4000,
			"intro": [["levon", "Գուրգենի տղա՞ն։ Լսել եմ քո մասին։ Ասում են՝ ոստիկաններից էլ ես փախել։"],
				["you", "Ինձ պետք է իմանալ, թե ինչպես կանգնեցնել Ոսկանյանին։"],
				["levon", "Մի բան գիտեմ։ Բայց այս փողոցներում ոչինչ ձրի չէ։ Հաղթիր ինձ մրցարշավում, ու կասեմ։"],
				{ "choice": [["Համաձայն եմ", [["levon", "Լավ։ Վեց ստուգակետ։ Ով առաջինը հասնի վերջինին, նա է հաղթել։ Մեքենա նստիր ու կանգնիր կողքիս։"]]],
					["Իսկ եթե պարտվե՞մ", [["levon", "Կփորձես նորից։ Ես համբերատար եմ։ Վեց ստուգակետ, ով առաջինը։ Մեքենա նստիր ու կանգնիր կողքիս։"]]]] }],
			"retry": [["levon", "Ռևանշի՞ ես եկել։ Լավ, մեկ էլ։ Մեքենա նստիր ու կանգնիր կողքիս։"]],
			"steps": [
				{ "t": "race" },
				{ "t": "talk", "who": "levon", "at": _at_finish, "lines": [["levon", "Վա՜հ։ Վաղուց ինձ ոչ ոք չէր հաղթել։ Խոսքս խոսք է։"],
					["levon", "Ամեն գիշեր Ոսկանյանի սուրհանդակը մոխրագույն մեքենայով մի թղթապանակ է տանում Նեոն ակումբից։ Այնտեղ են կեղծ ստորագրություններն ու կաշառքների ցուցակը։"],
					["levon", "Լիլիթը՝ լրագրողը, վաղուց է որսում այդ թղթապանակը։ Նա քեզ կսպասի ակումբի դռան մոտ։"]] }] },
		{ "title": "Թղթապանակը", "who": "lilit", "at": "lilit", "reward": 10000,
			"intro": [["lilit", "Դու երևի Լևոնի ասած մարդն ես։ Ես Լիլիթն եմ՝ «Քաղաքի ձայն» թերթից։"],
				["lilit", "Երկու տարի է՝ գրում եմ Ոսկանյանի մասին, բայց առանց ապացույցի ոչ ոք չի հավատում։ Այսօր ամեն ինչ կարող է փոխվել։"],
				["lilit", "Սուրհանդակը հիմա դուրս կգա։ Մոխրագույն մեքենան է։ Կանգնեցրու նրան, միայն մարդկանց չվնասես, լա՞վ։"],
				{ "choice": [["Նա չի փախչի", [["lilit", "Թղթապանակը բեր հրապարակ, ես այնտեղ կսպասեմ։ Հաջողություն։"]]],
					["Ինչո՞ւ ես այդքան ռիսկի դիմում", [["lilit", "Որովհետև սա իմ քաղաքն էլ է։ Թղթապանակը բեր հրապարակ, ես այնտեղ կսպասեմ։"]]]] }],
			"retry": [["lilit", "Սուրհանդակը վերադարձավ ակումբ։ Ունենք ևս մեկ հնարավորություն։ Նստիր մեքենա։"]],
			"steps": [
				{ "t": "chase", "time": 120.0 },
				{ "t": "talk", "who": "lilit", "at": "finalL", "also": [["gurgen", "finalG"], ["nare", "finalN"]], "no_heat": true, "label": "Տար թղթապանակը Լիլիթին հրապարակում",
					"lines": _final_lines }] }]

func _set_kind() -> void:
	prog.kind = true

func _at_rubo():
	return act.get("rubo") if act else null

func _at_finish():
	return act.get("finish") if act else null

func _final_lines() -> Array:
	return [["lilit", "Սա է։ Կեղծ ստորագրություններ, կաշառքներ, անուններ… Ամեն ինչ այստեղ է։"],
		["lilit", "Վաղը առավոտյան ամբողջ քաղաքը կկարդա։ Ոսկանյանի աշտարակը թղթի վրա էլ չի մնա։"],
		["gurgen", "Տղաս… Դու փրկեցիր մեր թաղը։ Քո պապը քեզնով կհպարտանար։"],
		["nare", "Ու իմ փուռը։ Ապակին արդեն նորն է՝ քո չվերցրած փողով։ Ամեն առավոտ տաք լավաշը քեզ համար է։"] if prog.kind else ["nare", "Ու իմ փուռը։ Ամեն առավոտ տաք լավաշը քեզ համար է։"],
		["you", "Սա բոլորինս է։ Ես միայն մեքենա էի քշում։"],
		["lilit", "Լավ էլ քշում էիր։ Եթե մի օր նոր պատմություն ունենամ, գիտեմ՝ ում զանգել։"]]

func story_on() -> bool:
	return act != null and act.kind == "story"

func story_done() -> bool:
	return int(prog.story) >= chs.size()

func spos(at):   # a story spot: a name in sp, or a function giving a spot (or null)
	var p = at.call() if at is Callable else sp.get(at)
	if p is Vector3: return Vector2(p.x, p.y)
	return p

func start_text() -> String:
	return "Նստիր մեքենան ու գնա դեղին օղակի մոտ" if story_done() else CAST[chs[prog.story].who].nom + " սպասում է քեզ · վարդագույն նշանը քարտեզին"

func _begin_chapter() -> void:
	var n: int = prog.story; var ch: Dictionary = chs[n]; st.arm = false
	m.ui.chapter_card("Գլուխ %d / %d" % [n + 1, chs.size()], ch.title)
	m.ui.say(ch.retry if st.failed else ch.intro, _after_intro.bind(n))

func _after_intro(n: int) -> void:
	st.failed = false; act = { "kind": "story", "ch": n, "k": -1, "time": INF, "goal": null }; _story_next()

func _story_car(at: Vector3, model: String) -> Car:
	var c: Car = m._make_car(at.x, at.y, at.z, model)
	c.story = true
	return c

func _story_next() -> void:
	var ch: Dictionary = chs[act.ch]; act.k += 1
	if act.k >= ch.steps.size(): _chapter_done(); return
	var s: Dictionary = ch.steps[act.k]; act.s = s; act.time = s.get("time", INF); act.goal = { "p": null, "stage": "story" }; act.cps = null
	match s.t:
		"getcar":
			var c := _story_car(sp.taxi, "taxi"); c.max_speed = 300; act.car = c
		"drive": act.dmg0 = act.car.dmg if act.get("car") else 0
		"multi": act.m = 0
		"tail", "chase":
			var c := _story_car(sp.rubo if s.t == "tail" else sp.courier, "gclass" if s.t == "tail" else "traffic_sedan")
			if s.t == "tail": c.max_speed = 300; c.cruise = 112
			else: c.max_speed = 305; c.cruise = 235
			act.car = c; act.go = false; act.wait = 25.0; act.far = 0.0; act.near = 0.0; act.hold = 0.0; act.time = INF; act.dist = 999.0
		"escape": m.heat = maxf(m.heat, s.heat); m.evade_t = 0
		"race":
			var c := _story_car(sp.rival, "mclaren"); c.max_speed = 315; c.acc = 1.2; c.grip = 1.25
			act.rival = c; act.phase = "ready"; act.cd = 0.0
	if s.has("label") and s.t != "talk": m.toast(s.label, 3)

func _chapter_done() -> void:
	var n: int = act.ch; var ch: Dictionary = chs[n]; var got: int = 0 if (n == 1 and prog.kind) else ch.reward
	act = null; _story_clean(); prog.story = n + 1; earn(got)
	if story_done(): m.ui.chapter_card("Պատմության վերջը", "Քաղաքը քոնն է"); m.toast("Դու ավարտեցիր պատմությունը  +" + money(got), 4); return
	m.toast("Գլուխ %d-ն ավարտվեց" % (n + 1) + ("  +" + money(got) if got else ""), 3.5)
	if chs[n + 1].get("chain", false): st.chain_t = 1.8
	else: st.arm = true

func story_fail(msg: String) -> void:
	var ch: Dictionary = chs[act.ch]; act = null; _story_clean(); st.failed = true; st.arm = true
	m.toast(msg + " · վերադարձիր " + CAST[ch.who].gen + " մոտ", 4)

func _story_clean() -> void:
	for k in range(m.cars.size() - 1, -1, -1):
		var c: Car = m.cars[k]
		if c.story and c != m.pcar: c.node.queue_free(); m.cars.remove_at(k)
	m.ui.end_talk()

func _near_talk(p, r_foot := 26.0) -> bool:
	if p == null: return false
	var t: Vector2 = m.target_pos()
	return t.distance_to(p) < (50.0 if m.pcar else r_foot) and (not m.pcar or absf(m.pcar.v) < 50)

func _story_idle(dt: float, tg: Vector2) -> void:   # waiting for you to walk up to the next chapter's character
	if act != null or m.ui.talking() or story_done(): return
	if st.chain_t > 0:
		st.chain_t -= dt
		if st.chain_t <= 0: _begin_chapter()
		return
	var p = spos(chs[prog.story].at)
	if tg.distance_to(p) > 70: st.arm = true
	elif st.arm and _near_talk(p):
		if m.heat > 0: st.arm = false; m.toast("Նախ կորցրու ոստիկաններին")
		else: _begin_chapter()

func _has(c) -> bool:
	return c != null and is_instance_valid(c.node) and m.cars.has(c)

func _story_step(dt: float, tg: Vector2) -> void:
	var s: Dictionary = act.s; var G: Dictionary = act.goal
	match s.t:
		"talk":
			G.p = spos(s.at)
			if _near_talk(G.p, 30):
				if s.get("no_heat", false) and m.heat > 0:
					if not act.get("warned", false): act.warned = true; m.toast("Նախ կորցրու ոստիկաններին")
				else:
					act.warned = false
					var L = s.lines.call() if s.lines is Callable else s.lines
					m.ui.say(L, _story_next)
		"getcar":
			G.p = act.car
			if not _has(act.car): story_fail("Տաքսին կորավ"); return
			if m.pcar == act.car: _story_next()
		"drive":
			G.p = spos(s.to); var c: Car = act.car; var hits: int = c.dmg - act.dmg0; act.hits = hits
			if hits >= s.hits: story_fail("Տաքսին ջարդվեց"); return
			if m.pcar == c and Vector2(c.x, c.y).distance_to(G.p) < 42: _story_next(); return
			if act.time <= 0: story_fail("Ուշացար")
		"multi":
			G.p = sp.lav[act.m]
			if tg.distance_to(G.p) < 40:
				act.m += 1
				if act.m >= sp.lav.size(): _story_next(); return
				m.toast("Հասցված է · %d/%d" % [act.m, sp.lav.size()])
			if act.time <= 0: story_fail("Լավաշը սառեց")
		"tail", "chase":
			var c: Car = act.car; G.p = c
			if not _has(c): story_fail("Մեքենան կորավ"); return
			if m.pcar == c: story_fail("Ռուբոն տեսավ, որ մեքենան ես վերցնում" if s.t == "tail" else "Սուրհանդակը փախավ"); return
			var d := tg.distance_to(Vector2(c.x, c.y)); act.dist = d
			if not act.go:
				act.wait -= dt
				if m.pcar or act.wait <= 0:
					act.go = true; c.flee = s.t == "chase"; c.driver = true; c.resync(); act.time = s.dur if s.t == "tail" else s.time
					m.toast("Ռուբոն շարժվեց" if s.t == "tail" else "Սուրհանդակը փախչում է", 2.5)
				return
			if s.t == "tail":
				act.far = act.far + dt if d > 520 else maxf(0, act.far - dt)
				if act.far > 6: story_fail("Ռուբոն կորավ"); return
				act.near = act.near + dt if d < 62 else maxf(0, act.near - dt * 0.5)
				if act.near > 2.5: story_fail("Ռուբոն քեզ նկատեց"); return
				if act.time <= 0:   # he stops and gets out
					c.ai = {}; c.driver = false
					act.rubo = m.city.push_out(Vector2(c.x + sin(c.a) * 30, c.y - cos(c.a) * 30), 7)
					m.toast("Ռուբոն կանգնեց ու իջավ", 2.5); _story_next()
			else:
				if d < 55: act.hold += dt
				if d > 1500: story_fail("Սուրհանդակը կորավ"); return
				if act.hold >= 2:
					c.flee = false; c.ai = {}; c.driver = false; m.heat = maxf(m.heat, 2); m.evade_t = 0
					m.toast("Թղթապանակը քոնն է։ Ոսկանյանի մարդիկ ոստիկանություն կանչեցին", 3.5); _story_next(); return
				if act.time <= 0: story_fail("Սուրհանդակը փախավ")
		"escape":
			G.p = null
			if m.heat <= 0: m.toast("Փախար", 2); _story_next(); return
			if act.time <= 0: story_fail("Չհասցրիր փախչել")
		"race":
			var r: Car = act.rival
			if not _has(r): story_fail("Լևոնը գնաց"); return
			if act.phase == "ready":
				G.p = spos("rival")
				if m.pcar == r: story_fail("Լևոնի մեքենան չես կարող վերցնել"); return
				if m.pcar and tg.distance_to(G.p) < 110: act.phase = "count"; act.cd = 3.99; m.toast("3", 1)
			elif act.phase == "count":
				var before := ceili(act.cd - 0.99); act.cd -= dt; var now := ceili(act.cd - 0.99)
				if m.pcar: m.pcar.v *= pow(0.05, dt)
				if now != before and now > 0: m.toast(str(now), 1)
				if act.cd <= 1:   # go: checkpoints start at the crossroads east of the start
					act.phase = "go"; act.cps = race_cps(6, 5); act.ci = 0; m.toast("Գնա՛", 1.2)
					var pts := [Vector2(ic(6), ic(5))]; var pi := 6; var pj := 5
					for q in act.cps:
						if q.i != pi and q.j != pj: pts.append(Vector2(ic(q.i), ic(pj)))
						pts.append(Vector2(q.x, q.y)); pi = q.i; pj = q.j
					r.path = pts; r.pk = 0; r.ck = 0
			else:
				if not m.pcar: story_fail("Իջար մեքենայից"); return
				var c = act.cps[act.ci]; G.p = Vector2(c.x, c.y); G.stage = "race"
				if r.ck < act.cps.size():
					var rc = act.cps[r.ck]
					if Vector2(rc.x, rc.y).distance_to(Vector2(r.x, r.y)) < 45:
						r.ck += 1
						if r.ck >= act.cps.size(): story_fail("Լևոնը հաղթեց"); return
				if tg.distance_to(G.p) < 55:
					act.ci += 1
					if act.ci >= act.cps.size():
						var L = act.cps[act.cps.size() - 1]; var sx := -1 if L.i >= N else 1; var sy := -1 if L.j >= N else 1
						act.finish = Vector2(L.x + sx * 70, L.y + sy * 70)
						r.path = [Vector2(L.x + sx * 40, L.y)]; r.pk = 0; act.cps = null; m.toast("Հաղթեցիր", 2); _story_next()

func story_label() -> String:
	var s = act.get("s")
	if s == null: return ""
	match s.t:
		"drive": return s.label + " · վթար %d/%d" % [act.get("hits", 0), s.hits]
		"multi": return s.label + " · %d/%d" % [act.m, sp.lav.size()]
		"tail": return "Նստիր մեքենա, Ռուբոն շուտով կշարժվի" if not act.go else ("Շատ մոտ ես, հետ մնա" if act.dist < 100 else ("Կորցնում ես նրան, մոտեցիր" if act.dist > 400 else "Հետևիր Ռուբոյին հեռվից"))
		"chase": return "Նստիր մեքենա, սուրհանդակը դուրս է գալիս" if not act.go else "Բռնիր սուրհանդակին · մնա կողքին %d%%" % mini(100, roundi(act.hold / 2 * 100))
		"race": return "Մեքենայով կանգնիր Լևոնի կողքին" if act.phase == "ready" else ("Պատրաստվիր…" if act.phase == "count" else "Մրցարշավ · դու %d/6 · Լևոն %d/6" % [act.ci, act.rival.ck])
		"talk":
			var hot: bool = m.heat > 0 and s.get("no_heat", false)
			if s.has("label"): return ("Կորցրու ոստիկաններին, հետո " + s.label.substr(0, 1).to_lower() + s.label.substr(1)) if hot else s.label
			return ("Կորցրու ոստիկաններին, հետո գնա " if hot else "Գնա ") + CAST[s.who].gen + " մոտ"
	return s.get("label", "")

func story_cast() -> Array:   # who stands where right now
	if story_done(): return [["gurgen", sp.garage], ["nare", sp.bakery]]
	if not story_on(): var ch: Dictionary = chs[prog.story]; return [[ch.who, spos(ch.at)]]
	var steps: Array = chs[act.ch].steps
	for k in range(act.k, steps.size()):
		if steps[k].t == "talk":
			var s: Dictionary = steps[k]; var out := [[s.who, spos(s.at)]]
			for a in s.get("also", []): out.append([a[0], spos(a[1])])
			return out
	return []

# --------------------------------------------------------------------- per frame ----------
func goal():   # what the map and the marker point at: { p, stage, kind }
	if act != null: return act.goal if act.goal != null else { "p": null, "stage": "escape" }
	return job

static func gpos(p) -> Vector2:
	if p is Vector2: return p
	if p is Car: return Vector2(p.x, p.y)
	return Vector2.INF

func tick(dt: float) -> void:   # from main._physics_process
	var tg: Vector2 = m.target_pos()
	_act_update(dt, tg); _story_idle(dt, tg); _place_check(tg)
	if wp != null and tg.distance_to(wp) < 45: wp = null; m.toast("Հասար նշված տեղը")
	_jobs(dt, tg)
	save_t += dt
	if cash != saved_cash and save_t > 1: save_t = 0; save()

func frame(dt: float) -> void:   # from main._process: characters, the beam and the goal marker
	var seen := {}
	for it in story_cast():
		var id: String = it[0]; var p = it[1]
		if p == null: continue
		if not npc.has(id):
			npc[id] = People.Avatar.new(People.scene(CAST[id].av)); add_child(npc[id].root)
		var av = npc[id]; seen[id] = true; av.root.visible = true
		var t: Vector2 = m.target_pos(); var face := atan2(t.y - p.y, t.x - p.x) if t.distance_to(p) < 160 else -PI / 2
		av.root.position = Vector3(p.x, m.city.ground_y(p.x, p.y), p.y) * S; av.root.rotation.y = -face
		av.walk(0.0, 0.0)
	for id in npc: if not seen.has(id): npc[id].root.visible = false
	var giver = null
	if not story_on() and not story_done() and not m.ui.talking(): giver = spos(chs[prog.story].at)
	beam.visible = giver != null
	if giver != null:
		var s := 1 + sin(m.time * 4) * 0.1
		beam.position = Vector3(giver.x, 210, giver.y) * S; beam.scale = Vector3(s, 1, s)
	# the column over where to go next
	var g = goal(); var gp := Vector2.INF; var col := Color(ICON.pickup)
	if g != null and g.get("p") != null and not (g.get("stage") == "story" and act.s.t == "talk"):
		gp = gpos(g.p)
		col = Color(ICON.cp) if g.stage == "race" else (Color(ICON.story) if g.stage == "story" else (Color(ICON.deliver) if g.stage == "deliver" else Color(ICON.pickup)))
	marker.visible = gp != Vector2.INF and not (g.get("p") is Car)
	if marker.visible:
		marker.position = Vector3(gp.x, m.city.ground_y(gp.x, gp.y) + 70, gp.y) * S
		col.a = 0.28 + sin(m.time * 5) * 0.06; marker_mat.albedo_color = col

## The line on the HUD: [text, time left or "", colour]
func hud_line() -> Array:
	var g = goal()
	if g == null: return ["", "", Color.WHITE]
	var del: bool = act != null or g.stage == "deliver"
	var txt := ""
	if act != null:
		if story_on(): txt = story_label()
		elif act.kind == "race": txt = "Մրցարշավ · ստուգակետ %d/%d" % [mini(act.k + 1, act.cps.size()), act.cps.size()]
		else: txt = "Փախուստ · կորիր ոստիկաններից"
	elif g.kind == "taxi":
		txt = ("Տար ուղևորին · " + money(roundi(g.pay * (1 - 0.2 * g.get("hits", 0)) / 100) * 100) + (" · վթար %d/4" % g.hits if g.get("hits", 0) else "")) if del else "Տաքսի՝ վերցրու ուղևորին"
	else: txt = ("Հասցրու՝ " + g.label + " · " + money(g.pay)) if del else "Վերցրու պատվերը՝ " + g.label
	var tl: float = (act.time if act != null else g.get("time", INF)) if del else INF
	var col := Color(ICON.story) if story_on() else (Color(ICON.deliver) if del else Color(ICON.pickup))
	if tl != INF and tl <= 8: col = Color("ff5a5f")
	return [txt, fmt_t(maxf(0, ceilf(tl))) if tl != INF else "", col]

## What the maps show: { kind, p, name, big, n }
func map_items() -> Array:
	var out := [{ "kind": "square", "p": Vector2(3 * CELL + 320, 3 * CELL + 320), "name": PLACE_NAME.square }, { "kind": "club", "p": club_door, "name": PLACE_NAME.club }]
	for pl in places: out.append({ "kind": pl.id, "p": Vector2(pl.x, pl.y), "name": PLACE_NAME[pl.id] })
	if not story_on() and not story_done(): var ch: Dictionary = chs[prog.story]; out.append({ "kind": "story", "p": spos(ch.at), "name": CAST[ch.who].name, "big": true })
	if story_on() and act.get("rival") and act.phase == "go": out.append({ "kind": "rival", "p": Vector2(act.rival.x, act.rival.y) })
	var g = goal()
	if act != null and act.get("cps") and g.p != null: out.append({ "kind": "cp", "p": gpos(g.p), "n": (act.ci if story_on() else act.k) + 1, "big": true })
	elif g != null and g.get("p") != null: out.append({ "kind": "story" if g.stage == "story" else ("pickup" if g.stage == "pickup" else "deliver"), "p": gpos(g.p), "big": true })
	if wp != null: out.append({ "kind": "wp", "p": wp, "big": true })
	return out

# --------------------------------------------------------------- the waypoint route ----------
func snap_road(p: Vector2) -> Dictionary:   # the nearest point on a street and the crossroads either side
	var fi := func(v: float) -> float: return clampf((v - 60) / CELL, 0, N)
	var I := roundi(fi.call(p.x)); var J := roundi(fi.call(p.y)); var vert := absf(p.x - ic(I)) < absf(p.y - ic(J))
	var q := Vector2(ic(I), clampf(p.y, ic(0), ic(N))) if vert else Vector2(clampf(p.x, ic(0), ic(N)), ic(J))
	var nodes := [[I, floori(fi.call(q.y))], [I, ceili(fi.call(q.y))]] if vert else [[floori(fi.call(q.x)), J], [ceili(fi.call(q.x)), J]]
	return { "p": q, "nodes": nodes, "vert": vert, "road": I if vert else J }

func route(from: Vector2) -> Array:
	if wp == null: return []
	var sa := snap_road(from); var sb := snap_road(wp)
	var D := func(p: Vector2, q: Vector2) -> float: return absf(p.x - q.x) + absf(p.y - q.y)
	if sa.vert == sb.vert and sa.road == sb.road and sa.nodes[0] == sb.nodes[0]: return [from, sa.p, sb.p, wp]
	var best := []; var bl := 1e12
	for na in sa.nodes:
		for nb in sb.nodes:
			var A := Vector2(ic(na[0]), ic(na[1])); var B := Vector2(ic(nb[0]), ic(nb[1]))
			for corner in [Vector2(B.x, A.y), Vector2(A.x, B.y)]:
				var L: float = D.call(sa.p, A) + D.call(A, corner) + D.call(corner, B) + D.call(B, sb.p)
				if L < bl: bl = L; best = [from, sa.p, A, corner, B, sb.p, wp]
	return best

func set_waypoint(p) -> void:
	wp = p
	if p != null: m.toast("Նշված է · հետևիր նարնջագույն գծին")
