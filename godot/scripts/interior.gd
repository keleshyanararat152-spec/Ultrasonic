extends Node3D
## Stage 4: the Neon club (a dance floor that pays for dancing on the beat, a bar, a VIP room), your house
## with a flat inside (sleep, wardrobe, call your car), the car dealer and the clothes shop.
## Rooms sit off the map, like in the browser game: the club at (CX, CY), the VIP room at (VX, VY), the
## flat at (HX, HY), all in game units.

const S := 0.1
const CELL := 520
const CX := -3000.0
const CY := 1000.0
const VX := -3000.0
const VY := 1700.0
const HX := -3000.0
const HY := 2600.0
const STEP := 60.0 / 124.0 / 4.0      # a sixteenth note at 124 BPM
const BEAT := STEP * 4
const HOME_PRICE := 20000
const CAR_SHOP := [
	{ "id": "sport", "model": "traffic_coupe", "name": "Սպորտ", "max": 380, "acc": 1.35, "grip": 1.1, "stars": 2, "price": 8000 },
	{ "id": "lux", "model": "traffic_sedan", "name": "Լյուքս", "max": 420, "acc": 1.55, "grip": 1.15, "stars": 3, "price": 15000 },
	{ "id": "racer", "model": "traffic_sport", "name": "Մրցարշավային", "max": 480, "acc": 1.85, "grip": 1.3, "stars": 4, "price": 30000 },
	{ "id": "gclass", "model": "gclass", "name": "Mercedes G-class", "max": 360, "acc": 1.3, "grip": 1.05, "stars": 2, "price": 22000 },
	{ "id": "mclaren", "model": "mclaren", "name": "McLaren 720S", "max": 470, "acc": 1.8, "grip": 1.3, "stars": 4, "price": 38000 },
	{ "id": "goblin", "model": "goblin", "name": "V12 Goblin", "max": 490, "acc": 1.9, "grip": 1.32, "stars": 4, "price": 45000 },
	{ "id": "revuelto", "model": "revuelto", "name": "Lamborghini Revuelto", "max": 510, "acc": 2.0, "grip": 1.35, "stars": 4, "price": 60000 }]
const OUTFITS := [{ "id": "m07", "name": "Մուգ բաճկոն", "price": 0 }, { "id": "m02", "name": "Բեժ սվիտեր", "price": 1500 }, { "id": "m06", "name": "Կարմիր վերնաշապիկ", "price": 1500 },
	{ "id": "m08", "name": "Կապույտ վերնաշապիկ", "price": 2000 }, { "id": "m16", "name": "Մուգ կապույտ շապիկ", "price": 2000 }, { "id": "m10", "name": "Բորդո բաճկոն", "price": 2500 },
	{ "id": "m12", "name": "Ջինսե բաճկոն", "price": 3000 }, { "id": "m04", "name": "Սև կապյուշոն", "price": 3000 }, { "id": "m17", "name": "Մարզական բաճկոն", "price": 3500 }, { "id": "m03", "name": "Կոստյում", "price": 6000 }]

var m                      # main.gd
var inside := ""           # "" in the city, or "club", "vip", "home"
var arm := false           # a ring fires when you walk in, after you have stepped out of all of them
var built := {}
var owned: Car = null      # your own car, waiting at a kerb
var tiles: MultiMesh
var dancers := []          # [avatar, x, y, face, style, phase, base_y]
var troupe := []
var people := []           # [avatar, role, x, y, a]
var club_lights := []
var ball: Node3D
var music: AudioStreamPlayer
var drink_t := 0.0
var combo := 0
var last_hit := -9.0
var house := {}

# --------------------------------------------------------------------- helpers ----------
func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new(); mt.albedo_color = c; mt.roughness = 0.8
	if unshaded: mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mt

func _box(w: float, h: float, d: float, mat: Material, x: float, y: float, z: float, parent: Node3D = self, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(w, h, d) * S; mi.mesh = bm; mi.material_override = mat
	mi.position = Vector3(x, y + h / 2, z) * S
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi); return mi

func _cyl(r0: float, r1: float, h: float, mat: Material, x: float, y: float, z: float, parent: Node3D = self, seg := 24) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r0 * S; cm.bottom_radius = r1 * S; cm.height = h * S; cm.radial_segments = seg
	mi.mesh = cm; mi.material_override = mat; mi.position = Vector3(x, y + h / 2, z) * S; parent.add_child(mi); return mi

func _ring(x: float, y: float, col: Color, parent: Node3D = self) -> void:
	var t := TorusMesh.new(); t.inner_radius = 9 * S; t.outer_radius = 12 * S; t.rings = 32; t.ring_segments = 6
	var mi := MeshInstance3D.new(); mi.mesh = t; mi.scale = Vector3(1, 0.06, 1); mi.material_override = _mat(col, true)
	mi.position = Vector3(x, 0.6, y) * S; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(mi)

func _room(w: float, h: float, d: float, wall: Color, floor_mat: Material, x: float, z: float, parent: Node3D) -> void:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(w, h, d) * S; bm.flip_faces = true
	mi.mesh = bm; mi.material_override = _mat(wall); mi.position = Vector3(x, h / 2, z) * S; parent.add_child(mi)
	_box(w + 20, 4, d + 20, _mat(Color("120d16")), x, h + 0.5, z, parent)   # a lid that keeps the sun out
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(w, d) * S; fl.mesh = pm; fl.material_override = floor_mat
	fl.position = Vector3(x, 0.3, z) * S; parent.add_child(fl)

func _person(id: String, x: float, y: float, a: float, parent: Node3D):
	var av = People.Avatar.new(People.scene(id)); parent.add_child(av.root)
	av.root.position = Vector3(x, 0, y) * S; av.root.rotation.y = -a; av.walk(0.0, 0.0)
	return av

func _label(text: String, x: float, y: float, z: float, col: Color, size: int, parent: Node3D, rot := 0.0) -> Label3D:
	var l := Label3D.new(); l.text = text; l.font = load("res://fonts/NotoSansArmenian.ttf"); l.font_size = size; l.pixel_size = 0.01
	l.modulate = col; l.outline_size = 0; l.position = Vector3(x, y, z) * S; l.rotation.y = rot; l.double_sided = false
	parent.add_child(l); return l

# ---------------------------------------------------------------- the house in the city ----------
## Where the house stands: the 'home' place's block, set back in the park. Worked out before the city is built,
## so the park trees there can be left out.
static func house_spot(city) -> Dictionary:
	var club_rect: Dictionary = {}
	for ij in [[4, 3], [3, 2], [2, 3], [3, 4], [4, 4], [2, 2], [4, 2]]:
		var b: Dictionary = city.blocks[ij[0]][ij[1]]
		if b.type == "b": club_rect = b.rects[0]; break
	var ci := int(club_rect.x / CELL); var cj := int(club_rect.y / CELL)
	var i := 4; var j := (1 + 1) % 7 if (i == ci and cj == 1) else 1
	var x := i * CELL + 270.0; var front := j * CELL + 152.0
	return { "x": x, "front": front, "i": i, "j": j, "rect": Rect2(x - 65 - 8, front - 14, 130 + 16, 96 + 22) }

func build_house() -> void:   # a two-storey house with a pitched roof, a front garden and a fence
	house = house_spot(m.city)
	var W := 130.0; var D := 96.0; var x: float = house.x; var f: float = house.front
	var g := Node3D.new(); add_child(g)
	var gy: float = m.city.CURB
	g.position = Vector3(0, gy * S, 0)
	var plaster := _mat(Color("d9a28a")); var stone := _mat(Color("b8ab98")); var trim := _mat(Color("f3ede2")); var roofm := _mat(Color("9c4430"))
	_box(W, 4, D, stone, x, 0, f + D / 2, g); _box(W - 0.4, 30, D - 0.4, plaster, x, 4, f + D / 2, g); _box(W + 1.6, 2, D + 1.6, trim, x, 34, f + D / 2, g)
	_box(W, 32, D, plaster, x, 36, f + D / 2, g); _box(W + 3, 2, D + 3, trim, x, 68, f + D / 2, g)
	var roof := MeshInstance3D.new(); var pm := PrismMesh.new(); pm.size = Vector3(D + 14, 36, W + 12) * S; roof.mesh = pm; roof.material_override = roofm
	roof.position = Vector3(x, 70 + 18, f + D / 2) * S; roof.rotation.y = PI / 2; g.add_child(roof)
	_box(11, 30, 11, _mat(Color("8a4a36")), x + W / 2 - 28, 84, f + D / 2 + 14, g)
	var glass := _mat(Color("2d3d4c")); glass.metallic = 0.3; glass.roughness = 0.15
	for cx in [-40, 40]: _box(14, 18, 1.4, glass, x + cx, 11, f - 0.6, g, false); _box(17, 1.6, 3, trim, x + cx, 9.6, f - 1.4, g, false)
	for cx in [-40, 0, 40]: _box(14, 18, 1.4, glass, x + cx, 44, f - 0.6, g, false); _box(17, 1.6, 3, trim, x + cx, 42.6, f - 1.4, g, false)
	for cx in [-40, 0, 40]: _box(14, 18, 1.4, glass, x + cx, 11, f + D + 0.6, g, false); _box(14, 18, 1.4, glass, x + cx, 44, f + D + 0.6, g, false)
	_box(20, 30, 1, trim, x, 4, f - 0.4, g); _box(15, 26, 1, _mat(Color("3f5e46")), x, 4, f - 0.9, g)
	_box(34, 1.6, 13, _mat(Color("2f3a44")), x, 33, f - 6, g)
	for lx in [-13, 13]: _box(2.4, 3.4, 2, _mat(Color("ffe2a0"), true), x + lx, 24, f - 1.2, g, false)
	_box(26, 2, 9, stone, x, 0, f - 4.5, g)
	_box(20, 5.5, 0.6, _mat(Color("1d2a22")), x, 37, f - 0.9, g, false)
	_label("ԻՄ ՏՈՒՆԸ", x, gy + 39.7, f - 1.4, Color("e9f4ec"), 40, self, 0)
	for px in range(-int(W / 2) - 4, int(W / 2) + 5, 10):
		if absf(px) > 10: _box(1.6, 9, 1.6, trim, x + px, 0, f - 10, g)
	for sx in [-1, 1]:
		var L := W / 2 + 4 - 10; var cx: float = sx * (10 + L / 2)
		_box(L, 1.2, 1, trim, x + cx, 4, f - 10, g); _box(L, 1.2, 1, trim, x + cx, 7.4, f - 10, g)
	var bush := _mat(Color("4f7d45"))
	for bx in [-52, -30, 30, 52]:
		var b := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 5.5 * S; sm.height = 10 * S; sm.radial_segments = 8; sm.rings = 4
		b.mesh = sm; b.material_override = bush; b.position = Vector3(x + bx, 4.5, f - 4) * S; g.add_child(b)
	# solid for walking and driving
	m.city.blocks[house.i][house.j].rects.append({ "x": x - W / 2, "y": f, "w": W, "h": D, "z": 0, "d": 0 })

# --------------------------------------------------------------------- the club ----------
func _build_club() -> void:
	var g := Node3D.new(); add_child(g); built.club = g
	_room(320, 70, 240, Color("2a1d33"), _mat(Color("1d1524")), CX, CY, g)
	# the dance floor: tiles that change colour on the beat
	tiles = MultiMesh.new(); tiles.transform_format = MultiMesh.TRANSFORM_3D; tiles.use_colors = true
	var pm := PlaneMesh.new(); pm.size = Vector2(27, 27) * S; tiles.mesh = pm; tiles.instance_count = 30
	for a in 6:
		for b in 5: tiles.set_instance_transform(a * 5 + b, Transform3D(Basis.IDENTITY, Vector3(CX - 85 + a * 29, 0.5, CY - 52 + b * 29) * S))
	var tm := MultiMeshInstance3D.new(); tm.multimesh = tiles; var tmat := _mat(Color.WHITE, true); tmat.vertex_color_use_as_albedo = true; tm.material_override = tmat; g.add_child(tm)
	# stage with the DJ, neon strips behind it
	_box(62, 7, 210, _mat(Color("3d2246")), CX + 126, 0, CY, g)
	for n in 7: _box(1.5, 56, 6, _mat(Color("ff4fa3") if n % 2 else Color("35d6e6"), true), CX + 158.5, 6, CY - 90 + n * 30, g, false)
	_box(16, 12, 40, _mat(Color("15121a")), CX + 112, 7, CY, g)
	for s in [-1, 1]: _cyl(5, 5, 0.6, _mat(Color("222")), CX + 112, 19.2, CY + s * 10, g)
	_box(1, 2, 38, _mat(Color("35d6e6"), true), CX + 103.8, 15, CY, g, false)
	people.append([_person("m12", CX + 124, CY, PI, g), "dj", CX + 124, CY, PI])
	# bar with bottles and a barman
	var bar := _mat(Color("6a4630")); bar.roughness = 0.4
	_box(130, 13, 14, bar, CX - 30, 0, CY - 106, g)
	for n in 14: _box(2, 6, 2, _mat([Color("7be0c3"), Color("ffcf4a"), Color("ff8a5c"), Color("9db8ff")][n % 4], true), CX - 88 + n * 9, 23, CY - 117, g, false)
	_box(124, 1.5, 6, _mat(Color("3a2a22")), CX - 30, 22, CY - 116, g)
	people.append([_person("m16", CX - 30, CY - 113, PI / 2, g), "tender", CX - 30, CY - 113, PI / 2])
	# booths, side lights, the exit and the disco ball
	var lounge := _mat(Color("391b34"))
	for side in [-1, 1]:
		_box(64, 6, 21, lounge, CX - 93, 0, CY + side * 87, g); _box(64, 16, 5, lounge, CX - 93, 0, CY + side * 97, g)
		_cyl(10, 10, 1.4, _mat(Color("221624")), CX - 30, 9, CY + side * 83, g); _cyl(1.1, 1.1, 9, _mat(Color("986b4e")), CX - 30, 0, CY + side * 83, g, 10)
	for n in 6: _box(2, 15, 2, _mat(Color("f0438d") if n % 2 else Color("40cee0"), true), CX - 158, 28, CY - 81 + n * 32, g, false)
	_box(1.5, 8, 22, _mat(Color("58d68d"), true), CX - 159, 30, CY, g, false)
	_label("ԵԼՔ", CX - 158, 40, CY, Color("58d68d"), 64, g, -PI / 2)
	_ring(CX - 142, CY, Color("58d68d"), g); _ring(CX - 60, CY + 100, Color("ffcf4a"), g); _ring(CX - 30, CY - 82, Color("ff9f1c"), g)
	_label("VIP", CX - 60, 40, CY + 119, Color("ffcf4a"), 96, g, 0)
	_label("ԲԱՐ", CX - 30, 34, CY - 118.5, Color("ff9f1c"), 80, g, PI)
	var bm := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 7 * S; sm.height = 14 * S; sm.radial_segments = 12; sm.rings = 6
	var bmat := _mat(Color("dfe6ee")); bmat.metallic = 1.0; bmat.roughness = 0.05; bm.mesh = sm; bm.material_override = bmat
	bm.position = Vector3(CX - 12, 58, CY) * S; g.add_child(bm); ball = bm
	# people dancing on the floor
	var ids := ["f02", "m06", "f05", "m10", "f13", "m03", "m04", "f02"]
	for n in 8:
		var x := CX - 82 + (n % 4) * 43.0; var y := CY - 37 + (n / 4) * 66.0
		dancers.append([_person(ids[n], x, y, 0.4 if n % 2 else 2.7, g), x, y, 0.4 if n % 2 else 2.7, n % 4, n * 0.81, 0.0])
	for c in [Color("ff4fa3"), Color("35d6e6"), Color("ffcf4a")]:
		var l := OmniLight3D.new(); l.light_color = c; l.omni_range = 26; l.light_energy = 1.4; l.shadow_enabled = false; g.add_child(l); club_lights.append(l)
	var fill := OmniLight3D.new(); fill.light_color = Color("658aff"); fill.omni_range = 30; fill.light_energy = 0.8; fill.position = Vector3(CX + 84, 50, CY) * S; g.add_child(fill)
	var bl := OmniLight3D.new(); bl.light_color = Color("ffd9a0"); bl.omni_range = 14; bl.light_energy = 1.2; bl.position = Vector3(CX - 30, 30, CY - 95) * S; g.add_child(bl)
	# the VIP room: a round stage with a dance troupe, sofas, a curtain
	var v := Node3D.new(); add_child(v); built.vip = v
	_room(230, 70, 170, Color("2b1220"), _mat(Color("24101b")), VX, VY, v)
	var gold := _mat(Color("ffcf4a")); gold.metallic = 0.8; gold.roughness = 0.3
	_cyl(44, 46, 6, _mat(Color("40182c")), VX + 62, 0, VY, v, 40); _cyl(44.5, 44.5, 0.6, gold, VX + 62, 6, VY, v, 40)
	for n in 15: _cyl(3.4, 3.4, 62, _mat(Color("5a1630")), VX + 112, 2, VY - 77 + n * 11, v, 8)
	var sofa := _mat(Color("3a1626"))
	for sy in [-1, 1]:
		_box(110, 8, 16, sofa, VX - 45, 0, VY + sy * 75, v); _box(110, 16, 5, sofa, VX - 45, 0, VY + sy * 82, v)
		for n in 3: _cyl(6, 6, 1, _mat(Color("1d0c16")), VX - 85 + n * 40, 8.5, VY + sy * 52, v, 14)
	for zy in [-60, 60]: _cyl(2.6, 3.3, 60, _mat(Color("5c2a40")), VX + 99, 2, VY + zy, v, 16)
	_ring(VX - 96, VY, Color("58d68d"), v); _ring(VX - 45, VY + 30, Color("ffcf4a"), v)
	built.table = _box(30, 8, 18, gold, VX - 45, 0, VY + 52, v)
	for c in [["f05", 0.0], ["m06", 1.15], ["f13", 2.3], ["m17", 3.45]]: troupe.append(_person(c[0], VX + 62, VY, 0, v))
	var gl := OmniLight3D.new(); gl.light_color = Color("ffb67f"); gl.omni_range = 24; gl.light_energy = 1.4; gl.position = Vector3(VX + 58, 58, VY) * S; v.add_child(gl)
	var gl2 := OmniLight3D.new(); gl2.light_color = Color("d1a1eb"); gl2.omni_range = 26; gl2.light_energy = 0.8; gl2.position = Vector3(VX - 40, 50, VY) * S; v.add_child(gl2)
	_make_music()

## A house loop in A minor, made once: kick, clap, hats, a bass line, an arpeggio and a chord on each bar.
func _make_music() -> void:
	var rate := 22050; var bars := 4; var n := int(STEP * 16 * bars * rate)
	var buf := PackedFloat32Array(); buf.resize(n)
	var tone := func(t0: float, f0: float, f1: float, dur: float, wave: int, vol: float) -> void:
		var i0 := int(t0 * rate); var len := int(dur * rate); var ph := 0.0
		for i in len:
			var u := float(i) / len; var f := f0 * pow(f1 / f0, u); ph += f / rate
			var s := 0.0
			match wave:
				0: s = sin(ph * TAU)
				1: s = 1.0 - 4.0 * absf(fmod(ph, 1.0) - 0.5)   # triangle
				2: s = 2.0 * fmod(ph, 1.0) - 1.0               # saw
			var k := (i0 + i) % n
			buf[k] += s * vol * pow(0.0001, u)
	var noise := func(t0: float, dur: float, vol: float, bright: float) -> void:
		var i0 := int(t0 * rate); var len := int(dur * rate); var prev := 0.0
		for i in len:
			var w := randf() * 2 - 1; var hp := w - prev * bright; prev = w
			buf[(i0 + i) % n] += hp * vol * pow(0.0001, float(i) / len)
	for st in 16 * bars:
		var s := st % 16; var bar := st / 16; var root: float = [55.0, 55.0, 43.65, 49.0][bar]; var t := st * STEP
		if s % 4 == 0: tone.call(t, 150, 40, 0.22, 0, 0.55)
		if s == 4 or s == 12: noise.call(t, 0.14, 0.22, 0.6)
		if s % 4 == 2: noise.call(t, 0.05, 0.12, 0.95)
		elif s % 2 == 1: noise.call(t, 0.025, 0.05, 0.98)
		if s in [0, 3, 6, 10, 14]: tone.call(t, root * 2, root * 2, 0.15, 1, 0.24); tone.call(t, root * 2, root * 2, 0.12, 2, 0.05)
		if s % 2 == 0:
			var k: float = [1.0, 1.2, 1.5, 1.8, 2.0, 1.8, 1.5, 1.2][(s / 2 + bar * 3) % 8]
			tone.call(t, root * 8 * k, root * 8 * k, 0.12, 1, 0.06)
		if s == 0:
			for k in [1.0, 1.2, 1.5]: tone.call(t, root * 4 * k, root * 4 * k, 0.55, 2, 0.025)
	var pcm := PackedByteArray(); pcm.resize(n * 2)
	for i in n: pcm.encode_s16(i * 2, int(clampf(buf[i], -1, 1) * 30000))
	var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = rate; wav.stereo = false; wav.data = pcm
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD; wav.loop_begin = 0; wav.loop_end = n
	music = AudioStreamPlayer.new(); music.stream = wav; music.volume_db = -4; add_child(music)

# ----------------------------------------------------------------------- the flat ----------
func _planks() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var cols := [Color("a4744c"), Color("9a6b44"), Color("ad7d54"), Color("96663f")]
	for r in 16:
		for q in 3:
			var x0 := q * 128 + (r % 2) * 64 - 64
			img.fill_rect(Rect2i(maxi(0, x0), r * 16, 128, 16), cols[(r * 3 + q) % 4])
		img.fill_rect(Rect2i(0, r * 16, 256, 1), Color("6a4a30"))
	return ImageTexture.create_from_image(img)

func _build_home() -> void:
	var g := Node3D.new(); add_child(g); built.home = g
	var fm := _mat(Color(0.85, 0.85, 0.85)); fm.albedo_texture = _planks(); fm.uv1_scale = Vector3(10, 7.5, 1)
	_room(320, 72, 240, Color("e7ddcf"), fm, HX, HY, g)
	var wood := _mat(Color("5a3a26")); var white := _mat(Color("f4f1ea")); var dark := _mat(Color("2b2c31"))
	# bed with a blanket and pillows, a bedside lamp
	_box(64, 9, 44, wood, HX + 40, 0, HY - 92, g); _box(60, 4, 40, white, HX + 40, 9, HY - 92, g); _box(46, 1.6, 41, _mat(Color("4d6f9e")), HX + 46, 13, HY - 92, g)
	for s in [-1, 1]: _box(10, 4, 14, white, HX + 14, 13, HY - 92 + s * 11, g)
	_box(64, 22, 3, wood, HX + 40, 0, HY - 115, g)
	_box(12, 12, 12, wood, HX + 82, 0, HY - 108, g); _cyl(2.5, 4, 8, _mat(Color("fff3d6"), true), HX + 82, 12, HY - 108, g, 12)
	# wardrobe, sofa, a low table, the TV, a rug, a plant, the kitchen corner
	_box(40, 60, 16, wood, HX - 90, 0, HY - 110, g); _box(0.6, 50, 0.6, _mat(Color("d9b45c")), HX - 90, 5, HY - 101.8, g)
	_box(70, 10, 24, _mat(Color("6b7f8e")), HX + 90, 0, HY + 104, g); _box(70, 18, 6, _mat(Color("5b6f7e")), HX + 90, 0, HY + 116, g)
	_box(36, 6, 18, wood, HX + 90, 0, HY + 72, g)
	_box(60, 32, 2.4, dark, HX + 155, 18, HY + 60, g).rotation.y = PI / 2
	var rug := MeshInstance3D.new(); var rp := PlaneMesh.new(); rp.size = Vector2(90, 60) * S; rug.mesh = rp; rug.material_override = _mat(Color("8e3b46"))
	rug.position = Vector3(HX + 90, 0.5, HY + 70) * S; g.add_child(rug)
	_cyl(5, 4, 10, _mat(Color("8a5a3a")), HX - 140, 0, HY - 100, g, 10)
	var pl := MeshInstance3D.new(); var ps := SphereMesh.new(); ps.radius = 9 * S; ps.height = 16 * S; pl.mesh = ps; pl.material_override = _mat(Color("4f7d45")); pl.position = Vector3(HX - 140, 18, HY - 100) * S; g.add_child(pl)
	_box(90, 14, 18, white, HX - 40, 0, HY + 110, g); _box(90, 1.4, 19, _mat(Color("3a3f47")), HX - 40, 14, HY + 110, g)
	# windows that show the sky, a door, lamps
	var sky := _mat(Color("bcd8ef"), true)
	for wx in [-60, 60]: _box(40, 26, 1, sky, HX + wx, 26, HY - 119.4, g, false)
	_box(1, 26, 40, sky, HX + 159.4, 26, HY - 40, g, false)
	_box(2, 44, 26, wood, HX - 159, 0, HY, g); _label("ԴՈՒՐՍ", HX - 157.5, 50, HY, Color("58d68d"), 56, g, -PI / 2)
	for p in [[-40, 0], [90, 40]]:
		var l := OmniLight3D.new(); l.light_color = Color("ffe0b0"); l.omni_range = 34; l.light_energy = 1.3; l.position = Vector3(HX + p[0], 62, HY + p[1]) * S; g.add_child(l)
		_box(10, 2, 10, _mat(Color("fff3d6"), true), HX + p[0], 66, HY + p[1], g, false)
	_ring(HX - 136, HY, Color("58d68d"), g); _ring(HX + 40, HY - 64, Color("4d8dff"), g); _ring(HX - 90, HY - 86, Color("b48cff"), g); _ring(HX - 116, HY + 78, Color("ffcf4a"), g)

# ------------------------------------------------------------------- rooms and rings ----------
func rings() -> Array:   # the rings of the room you are in: [x, y, hint, short, callable]
	match inside:
		"club": return [[CX - 142, CY, "դուրս գալ", "Դուրս", _leave_club], [CX - 60, CY + 100, "մտնել VIP սրահ", "VIP", _to_vip],
			[CX - 30, CY - 82, "խմիչք առնել (500 ֏)", "Խմիչք", _drink]]
		"vip": return [[VX - 96, VY, "վերադառնալ դահլիճ", "Դահլիճ", _from_vip],
			[VX - 45, VY + 30, "քո VIP սեղանը" if m.missions.prog.vip_table else "VIP սեղան վարձել (3 000 ֏)", "Սեղան", _table]]
		"home": return [[HX - 136, HY, "դուրս գալ", "Դուրս", leave_home], [HX + 40, HY - 64, "քնել մինչև առավոտ", "Քնել", _sleep],
			[HX - 90, HY - 86, "զգեստապահարան", "Հագուստ", _wardrobe], [HX - 116, HY + 78, "կանչել մեքենաս", "Մեքենա", _call_car]]
	return []

func _goto(x: float, y: float, a: float) -> void:
	m.me.x = x; m.me.y = y; m.me.a = a; m.cam_a = a; arm = false

func near_ring():
	var best = null; var bd := 34.0
	for r in rings():
		var d := Vector2(m.me.x - r[0], m.me.y - r[1]).length()
		if d < bd: bd = d; best = r
	return best

func on_floor() -> bool:
	return inside == "club" and m.me.x > CX - 100 and m.me.x < CX + 74 and m.me.y > CY - 67 and m.me.y < CY + 80

func near_door() -> bool:
	return inside == "" and m.pcar == null and Vector2(m.me.x, m.me.y).distance_to(m.missions.club_door) < 30

var door_arm := false
func door_tick() -> void:   # walking into the pink ring at the club door goes in
	if m.pcar or inside != "": return
	var d := Vector2(m.me.x, m.me.y).distance_to(m.missions.club_door)
	if d > 26: door_arm = true
	elif d < 13 and door_arm: door_arm = false; enter_club()

func enter_club() -> void:
	if m.heat > 0: m.toast("Ոստիկանները հետևիցդ են, հիմա չես կարող մտնել"); return
	if not built.has("club"): _build_club()
	inside = "club"; _goto(CX - 118, CY, 0); drink_t = 0; combo = 0
	if music and not music.playing: music.play()
	m.toast("Բարի գալուստ Նեոն ակումբ · պարահրապարակում պարիր ռիթմի տակ (Space / «Պարել»)", 4)

func _leave_club() -> void:
	inside = ""
	if music: music.stop()
	var d: Vector2 = m.missions.club_door
	_goto(d.x, d.y - 16, -PI / 2)

func _to_vip() -> void:
	inside = "vip"; _goto(VX - 74, VY, 0); m.toast("VIP սրահ. պարային շոու")

func _from_vip() -> void:
	inside = "club"; _goto(CX - 60, CY + 70, -PI / 2)

func _drink() -> void:
	m.missions.pay(500, _drunk)

func _drunk() -> void:
	drink_t = 90.0; m.toast("Խմիչք −500 ֏ · պարի շահույթը ×2, 90 վրկ")

func _table() -> void:
	if m.missions.prog.vip_table: m.toast("Սեղանն արդեն քոնն է"); return
	m.missions.pay(3000, _got_table)

func _got_table() -> void:
	m.missions.prog.vip_table = true; m.toast("VIP սեղանը քոնն է · պարի շահույթը ×1,5")

func enter_home() -> void:
	if not built.has("home"): _build_home()
	if m.pcar: m.pcar.v = 0; m.pcar = null
	inside = "home"; _goto(HX - 112, HY, 0); m.toast("Տանն ես")

func leave_home() -> void:
	var pl = m.missions.place("home"); inside = ""
	_goto(pl.x, pl.y - 30, -PI / 2); pl.arm = false

func _sleep() -> void:
	m.day_t = 1.0 / 24.0; m.missions.save(); m.toast("Բարի լույս · ժամը 07:00")

func _call_car() -> void:
	if m.missions.prog.car == null: m.toast("Դեռ մեքենա չունես. ավտոսրահը քարտեզի կապույտ նշանն է"); return
	spawn_owned(m.missions.place("home").park); m.toast("Մեքենադ մուտքի մոտ է")

func act() -> void:   # E or the round button inside
	if on_floor() and near_ring() == null: dance_hit(); return
	var r = near_ring()
	if r: arm = false; r[4].call()

func act_label() -> String:
	if inside == "":
		return "Մտնել" if near_door() else ""
	var r = near_ring()
	if r: return r[3]
	return "Պարել" if on_floor() else ""

func hint() -> String:
	if inside == "": return "E  մտնել ակումբ" if near_door() else ""
	var r = near_ring()
	if r: return "E  " + r[2]
	if on_floor(): return "Space  պարել ռիթմի տակ"
	return ""

func status() -> String:
	match inside:
		"home": return "տանը"
		"vip": return "VIP սրահ"
		"club": return ("խմիչք ×2 · %d վ" % ceili(drink_t)) if drink_t > 0 else "ակումբում"
	return ""

func map_pos() -> Vector2:
	if inside == "home":
		var pl = m.missions.place("home"); return Vector2(pl.x, pl.y)
	return m.missions.club_door

# --------------------------------------------------------------------- dancing ----------
func beat() -> float:   # beats since the music started, from where the music really is
	if music and music.playing:
		return (music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()) / BEAT
	return m.time / BEAT

func dance_hit() -> void:
	if not on_floor(): return
	var b := beat(); var err := minf(b - floor(b), ceil(b) - b) * BEAT
	if err < 0.125:
		combo = combo + 1 if m.time - last_hit < 1.6 else 1; last_hit = m.time
		var gain := roundi(50 * mini(combo, 10) * (2.0 if drink_t > 0 else 1.0) * (1.5 if m.missions.prog.vip_table else 1.0))
		m.missions.cash += gain
		m.toast("+" + m.missions.money(gain) + "  ×%d" % combo, 1)
	else:
		combo = 0; m.toast("Ռիթմից դուրս", 1)

# --------------------------------------------------------------------- per frame ----------
func bounds() -> Rect2:
	match inside:
		"club": return Rect2(CX - 152, CY - 94, 240, 206)
		"vip": return Rect2(VX - 102, VY - 70, 114, 140)
		"home": return Rect2(HX - 148, HY - 104, 276, 208)
	return Rect2()

func step(dt: float, inp: Dictionary) -> void:   # walking in a room, from main._physics_process
	var mv: float = inp.move.y; var tn: float = inp.move.x
	m.me.a += tn * 2.8 * dt
	var spd: float = -mv * (150.0 if mv < 0 else 80.0)
	m.me.x += cos(m.me.a) * spd * dt; m.me.y += sin(m.me.a) * spd * dt
	m.me.moving = absf(mv)
	if absf(mv) > 0.05: m.me.walk += dt * 10 * absf(mv) * (1.0 if mv < 0 else -0.7)
	var r := bounds(); m.me.x = clampf(m.me.x, r.position.x, r.end.x); m.me.y = clampf(m.me.y, r.position.y, r.end.y)
	if drink_t > 0: drink_t -= dt
	if combo and m.time - last_hit > 1.6: combo = 0
	var near := 1e9; var hit = null
	for q in rings():
		var d := Vector2(m.me.x - q[0], m.me.y - q[1]).length()
		near = minf(near, d)
		if d < 13: hit = q
	if near > 26: arm = true
	elif hit and arm: arm = false; hit[4].call()

func cam_fix(p: Vector2) -> Vector2:
	var r := bounds().grow(-0.0); var room := Rect2(r.position - Vector2(6, 6), r.size + Vector2(12, 12))
	return Vector2(clampf(p.x, room.position.x, room.end.x), clampf(p.y, room.position.y, room.end.y))

func frame(dt: float) -> void:   # from main._process: dancers, lights, tiles
	if inside == "club" or inside == "vip":
		var b := beat(); var kick := exp(-maxf(0, (b - floor(b)) * BEAT) * 7)
		if inside == "club":
			for n in tiles.instance_count:
				var h := fmod((n * 31 + int(b) * 53) % 360 / 360.0, 1.0)
				tiles.set_instance_color(n, Color.from_hsv(h, 0.75, 0.35 + 0.45 * kick + (0.12 if (n + int(b)) % 3 == 0 else 0.0)))
			for d in dancers:
				var av = d[0]; var tt: float = b + (0.5 if d[4] % 2 else 0.0)
				var drop: float = av.dance(tt, d[4], 0.85)
				av.root.position = Vector3(d[1] + sin(tt * PI) * 2.2, -drop / S, d[2] + sin(tt * PI / 2 + d[5]) * 2.5) * S
				av.root.rotation.y = -d[3] + sin(tt * PI / 4 + d[5]) * 0.35
			for n in club_lights.size():
				var l: OmniLight3D = club_lights[n]
				l.position = Vector3(CX - 12 + cos(m.time * (0.5 + n * 0.2) + n * 2) * 80, 47, CY + sin(m.time * (0.7 + n * 0.14) + n) * 52) * S
				l.light_energy = 0.8 + 1.4 * kick
			ball.rotation.y = m.time * 0.65
			for p in people:
				var av = p[0]
				if p[1] == "dj": av.dance(b, 3, 0.5); av.root.position.y = 7 * S
				elif p[1] == "tender":
					av.walk(m.time * 3, 0.25); av.root.position.x = (p[2] + sin(m.time * 0.35) * 38) * S
					av.root.rotation.y = -(PI if cos(m.time * 0.35) < 0 else 0.0)
		else:
			for n in troupe.size():   # a ring that opens and closes, a new move every four bars
				var av = troupe[n]; var a := n * TAU / troupe.size() + b * 0.12; var rad := 19 + 5 * sin(b * 0.3927)
				var drop: float = av.dance(b, int(b / 16) % 4, 0.9)
				av.root.position = Vector3(VX + 62 + cos(a) * rad, 6.5 - drop / S, VY + sin(a) * rad) * S
				av.root.rotation.y = PI + 0.25 * sin(b * 0.7854)
			(built.table as Node3D).visible = m.missions.prog.vip_table

# ------------------------------------------------------------------------- shops ----------
func open_place(pl) -> void:
	match pl.id:
		"dealer": _dealer(pl)
		"clothes": _clothes()
		"home":
			if m.missions.prog.home: enter_home(); return
			m.ui.panel("Բնակարան", "Վաճառվում է տուն։ Գնելուց հետո ներս կմտնես, խաղը կսկսես այստեղից, կկարողանաս քնել, փոխել հագուստդ ու կանչել մեքենադ։",
				[{ "label": "Գնել տունը", "price": m.missions.money(HOME_PRICE), "go": _buy_home }])

func _buy_home() -> void:
	m.missions.pay(HOME_PRICE, _bought_home)

func _bought_home() -> void:
	m.missions.prog.home = true; m.ui.close_panel(); m.toast("Տունը քոնն է"); enter_home()

func _dealer(pl) -> void:
	var items := []
	for c in CAR_SHOP:
		var own: bool = m.missions.prog.cars.has(c.id)
		items.append({ "label": c.name + "  ·  մինչև %d կմ/ժ  " % roundi(c.max * 0.42) + "★".repeat(c.stars) + "☆".repeat(4 - c.stars),
			"price": "կանչել" if own else m.missions.money(c.price), "go": _dealer_pick.bind(c, pl) })
	m.ui.panel("Ավտոսրահ", "Գնած մեքենան մնում է քոնը։ Կանչիր այն այստեղից կամ տնից։", items)

func _dealer_pick(c: Dictionary, pl) -> void:
	var prog: Dictionary = m.missions.prog
	if prog.cars.has(c.id): _call_owned(c, pl, c.name + "-ը մուտքի մոտ է"); return
	m.missions.pay(c.price, _bought_car.bind(c, pl))

func _bought_car(c: Dictionary, pl) -> void:
	m.missions.prog.cars.append(c.id); _call_owned(c, pl, "Շնորհավոր, " + c.name + "-ը քոնն է")

func _call_owned(c: Dictionary, pl, msg: String) -> void:
	m.missions.prog.car = c.id; spawn_owned(pl.park); m.ui.close_panel(); m.toast(msg); m.missions.save()

func spawn_owned(park: Vector3) -> void:   # your car waits at the kerb; only one of your cars is out at a time
	var spec = null
	for c in CAR_SHOP: if c.id == m.missions.prog.car: spec = c
	if spec == null: return
	if owned and owned != m.pcar and m.cars.has(owned): owned.node.queue_free(); m.cars.erase(owned)
	var c: Car = m._make_car(park.x, park.y, park.z, spec.model)
	c.max_speed = spec.max; c.acc = spec.acc; c.grip = spec.grip
	owned = c

func _clothes() -> void:
	var items := []; var prog: Dictionary = m.missions.prog
	for o in OUTFITS:
		var own: bool = prog.outfits.has(o.id)
		items.append({ "label": o.name, "price": "հագիդ է" if prog.outfit == o.id else ("հագնել" if own else m.missions.money(o.price)), "go": _outfit_pick.bind(o) })
	m.ui.panel("Հագուստի խանութ", "Ընտրիր, թե ինչ ես հագնում։ Գնածը մնում է քոնը։", items)

func _outfit_pick(o: Dictionary) -> void:
	var prog: Dictionary = m.missions.prog
	if prog.outfits.has(o.id): wear(o.id); _clothes(); return
	m.missions.pay(o.price, _bought_outfit.bind(o))

func _bought_outfit(o: Dictionary) -> void:
	m.missions.prog.outfits.append(o.id); wear(o.id); _clothes()

func _wardrobe() -> void:
	var items := []; var prog: Dictionary = m.missions.prog
	for o in OUTFITS:
		if prog.outfits.has(o.id): items.append({ "label": o.name, "price": "հագիդ է" if prog.outfit == o.id else "հագնել", "go": _wear_home.bind(o.id) })
	m.ui.panel("Զգեստապահարան", "Քո հագուստները։ Նորերը կգտնես հագուստի խանութում։", items)

func _wear_home(id: String) -> void:
	wear(id); _wardrobe()

func wear(id: String) -> void:
	m.missions.prog.outfit = id; m.missions.save(); m.set_outfit(id)

## Where the game starts: in the flat if you own it; your car waits outside.
func start() -> void:
	var prog: Dictionary = m.missions.prog
	if prog.outfit != "m07": m.set_outfit(prog.outfit)
	var home = m.missions.place("home"); var dealer = m.missions.place("dealer")
	if prog.car != null: spawn_owned((home if prog.home else dealer).park)
	if prog.home: enter_home()
