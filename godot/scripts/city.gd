extends Node3D
## The city: the same seeded layout as the browser game (game/city/index.html), built from multimeshes.
## Simulation coordinates are the browser game's units (x, y on the ground); S turns them into metres-ish
## Godot units: world = Vector3(x * S, height, y * S).

const CELL := 520
const N := 7
const LANE := 28
const S := 0.1
const CURB := 2.6          # pavement height, in game units
const FULL := 390.0        # height the baked facade texture covers, in game units
const WIDE := 562.0        # width it covers

var WS: int = N * CELL + 120
const TUFF := ["d98f7a", "c9755f", "e0a989", "b8695a", "8d5a52", "a8a39d", "e6b39a", "5b5560"]   # the tuff stone of each building
var blocks: Array = []     # blocks[i][j] = { type, rects: [ {x, y, w, h, z, d} ], trees: [ {x, y, r} ] }
var _seed: int = 20261116
var facade_mats: Array = []   # their night windows light up after dusk
var bulb_mat: StandardMaterial3D
var lamps: Array = []   # lamp positions, game units

static func ic(i: int) -> float:
	return i * CELL + 60.0

# --- the browser game's mulberry32, bit for bit, so the city comes out the same ---
func _imul(a: int, b: int) -> int:
	return (a * b) & 0xFFFFFFFF

func srand() -> float:
	_seed = (_seed + 0x6D2B79F5) & 0xFFFFFFFF
	var t: int = _imul(_seed ^ (_seed >> 15), 1 | _seed)
	t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

func generate() -> void:
	blocks.clear()
	for i in N:
		var col: Array = []
		for j in N:
			var ox := i * CELL + 142.0
			var oy := j * CELL + 142.0
			var b := { "type": "b", "rects": [], "trees": [] }
			var r := srand()
			if i == 3 and j == 3:
				b.type = "plaza"
			elif r < 0.14:
				b.type = "park"
				for t in 11:
					b.trees.append({ "x": ox + 20 + srand() * 316, "y": oy + 20 + srand() * 316, "r": 14 + srand() * 12 })
			else:
				var lay := srand()
				var cells: Array
				if lay < 0.22: cells = [[0, 0, 356, 356]]
				elif lay < 0.42: cells = [[0, 0, 170, 356], [186, 0, 170, 356]]
				elif lay < 0.62: cells = [[0, 0, 356, 170], [0, 186, 356, 170]]
				else: cells = [[0, 0, 170, 170], [186, 0, 170, 170], [0, 186, 170, 170], [186, 186, 170, 170]]
				for c in cells:
					var sx := srand() * 18; var sy := srand() * 18; var ex := srand() * 18; var ey := srand() * 18
					var tc: String = TUFF[int(srand() * TUFF.size())]
					b.rects.append({ "x": ox + c[0] + sx, "y": oy + c[1] + sy, "w": c[2] - sx - ex, "h": c[3] - sy - ey, "c": tc, "z": 7 + srand() * 10, "d": srand() })
			col.append(b)
		blocks.append(col)

## Keep a circle of radius r out of the buildings of its own block; returns true when it pushed.
func push_out(p: Vector2, r: float) -> Vector2:
	var i := int(floor(p.x / CELL)); var j := int(floor(p.y / CELL))
	if i >= 0 and j >= 0 and i < N and j < N:
		for b in blocks[i][j].rects:
			var cx := clampf(p.x, b.x, b.x + b.w); var cy := clampf(p.y, b.y, b.y + b.h)
			var dx := p.x - cx; var dy := p.y - cy; var d2 := dx * dx + dy * dy
			if d2 >= r * r: continue
			if d2 > 0.0001:
				var d := sqrt(d2); p.x += dx / d * (r - d); p.y += dy / d * (r - d)
			else:
				var l: float = p.x - b.x; var rr: float = b.x + b.w - p.x; var t: float = p.y - b.y; var bb: float = b.y + b.h - p.y
				var m := minf(minf(l, rr), minf(t, bb))
				if m == l: p.x = b.x - r
				elif m == rr: p.x = b.x + b.w + r
				elif m == t: p.y = b.y - r
				else: p.y = b.y + b.h + r
	p.x = clampf(p.x, 8, WS - 8); p.y = clampf(p.y, 8, WS - 8)
	return p

func ground_y(x: float, y: float) -> float:   # pavements are raised
	return CURB if x > 120 and y > 120 and x < WS and y < WS and fmod(x, CELL) >= 120 and fmod(y, CELL) >= 120 else 0.0

func road_point() -> Vector2:  # a random spot in the middle of a street
	var k := randi_range(0, N); var m := randi_range(0, N - 1); var t := ic(m) + randf_range(150, 370)
	return Vector2(t, ic(k)) if randf() < 0.5 else Vector2(ic(k), t)

# ---------------------------------------------------------------- building the scene ----------
func _tex_mat(path: String, uv: Vector3, tint := Color.WHITE, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = uv
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

## A tree crown in a unit box: a cluster of lumps instead of one ball.
func _crown_mesh() -> Mesh:
	var st := SurfaceTool.new()
	for b in [[Vector3(0, -0.05, 0), 0.4], [Vector3(0.2, 0.08, 0.12), 0.3], [Vector3(-0.2, 0.06, -0.12), 0.3], [Vector3(0.04, 0.25, -0.06), 0.27],
			[Vector3(-0.1, -0.08, 0.22), 0.27], [Vector3(0.16, -0.1, -0.2), 0.25]]:
		var sp := SphereMesh.new(); sp.radius = b[1]; sp.height = b[1] * 2; sp.radial_segments = 9; sp.rings = 5
		st.append_from(sp, 0, Transform3D(Basis.IDENTITY, b[0]))
	return st.commit()

func _plain(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = rough; return m

func _multi(mesh: Mesh, mat: Material, xforms: Array, shadows := true, colors := []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors.size() > 0
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size(): mm.set_instance_transform(k, xforms[k])
	for k in colors.size(): mm.set_instance_color(k, colors[k])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _box_xf(cx: float, cy: float, cz: float, sx: float, sy: float, sz: float) -> Transform3D:  # centre and size in game units
	return Transform3D(Basis.from_scale(Vector3(sx, sy, sz) * S), Vector3(cx, cy, cz) * S)

var keep_out: Array = []   # Rect2s where park trees are left out (the house)

func build() -> void:
	if blocks.is_empty(): generate()
	var unit := BoxMesh.new()   # 1 x 1 x 1, scaled per instance
	# ground: asphalt everywhere, the blocks sit on it as raised slabs
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(WS, WS) * S
	ground.mesh = pm
	ground.material_override = _tex_mat("res://assets/tex/asphalt.jpg", Vector3(1.0 / 9.6, 1.0 / 9.6, 1.0 / 9.6), Color(0.82, 0.82, 0.84), 0.95)
	ground.position = Vector3(WS / 2.0, 0, WS / 2.0) * S
	add_child(ground)
	var far := MeshInstance3D.new()   # hills beyond the edge
	var fm := PlaneMesh.new(); fm.size = Vector2(1400, 1400)
	far.mesh = fm; far.material_override = _plain(Color("76866a")); far.position = Vector3(WS / 2.0 * S, -0.1, WS / 2.0 * S)
	add_child(far)

	var slabs := []; var parks := []; var plaza := []
	var walls := { 0: [], 1: [] }; var wall_cols := { 0: [], 1: [] }; var roofs := []; var ledges := []; var ledge_cols := []
	var trunks := []; var crowns := []; var crown_cols := []; var kit := []; var kit_cols := []
	var rng := RandomNumberGenerator.new(); rng.seed = 7041   # looks only: leaves the city's own random numbers alone
	for i in N:
		for j in N:
			var b: Dictionary = blocks[i][j]
			var xf := _box_xf(i * CELL + 320, CURB / 2.0, j * CELL + 320, 400, CURB, 400)
			if b.type == "plaza": plaza.append(xf)
			else: slabs.append(xf)
			if b.type == "park":
				parks.append(_box_xf(i * CELL + 320, CURB + 0.1, j * CELL + 320, 352, 0.2, 352))
				for t in b.trees:
					var out := false
					for r: Rect2 in keep_out: if r.grow(t.r).has_point(Vector2(t.x, t.y)): out = true
					if out: continue
					trunks.append(_box_xf(t.x, CURB + 9, t.y, 4, 18, 4))
					crowns.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(t.r, t.r * 1.15, t.r) * S * 2.0), Vector3(t.x, CURB + 18 + t.r * 0.8, t.y) * S))
					crown_cols.append(Color("4f7d45").lerp(Color(rng.randf_range(0.3, 0.55), rng.randf_range(0.5, 0.65), 0.25), rng.randf() * 0.6))
			var n := 0
			for r in b.rects:
				n += 1
				var f: float = [1.0, 0.77, 0.62, 0.85][int(r.z) % 4]
				var h: float = FULL * f
				walls[n % 2].append(_box_xf(r.x + r.w / 2.0, h / 2.0, r.y + r.h / 2.0, r.w, h, r.h))
				var tuff := Color(r.c).lerp(Color.WHITE, 0.12)
				wall_cols[n % 2].append(tuff); ledge_cols.append(tuff.lerp(Color.WHITE, 0.45))
				roofs.append(_box_xf(r.x + r.w / 2.0, h + 0.4, r.y + r.h / 2.0, r.w - 2, 1, r.h - 2))
				# on the roof: a stair house and a few air-conditioning boxes
				var hut := Vector2(rng.randf_range(r.x + 20, r.x + r.w - 40), rng.randf_range(r.y + 20, r.y + r.h - 40))
				kit.append(_box_xf(hut.x + 12, h + 6, hut.y + 9, 24, 12, 18)); kit_cols.append(Color(r.c).darkened(0.15))
				for q in rng.randi_range(2, 5):
					var p := Vector2(rng.randf_range(r.x + 12, r.x + r.w - 12), rng.randf_range(r.y + 12, r.y + r.h - 12))
					kit.append(_box_xf(p.x, h + 3, p.y, 8, 5, 6)); kit_cols.append(Color("b9bcbf").darkened(rng.randf() * 0.2))
				ledges.append(_box_xf(r.x + r.w / 2.0, h + 1.6, r.y + r.h / 2.0, r.w + 4.4, 4.2, r.h + 4.4))
	var paving := _tex_mat("res://assets/tex/paving.jpg", Vector3(1, 1, 1) / 5.7, Color(0.8, 0.76, 0.72))
	_multi(unit, paving, slabs, false)
	_multi(unit, _tex_mat("res://assets/tex/paving.jpg", Vector3(1, 1, 1) / 5.7, Color(0.95, 0.88, 0.8)), plaza, false)
	_multi(unit, _plain(Color("6c9659")), parks, false)
	var fac_uv := Vector3(1.0 / (WIDE * S), 1.0 / (FULL * S), 1.0 / (WIDE * S))
	for q in 2:
		var wm := _tex_mat("res://assets/tex/facade%d.jpg" % (q + 1), fac_uv, Color.WHITE, 1.0)
		wm.vertex_color_use_as_albedo = true   # each building its own tuff
		wm.vertex_color_is_srgb = RenderingServer.get_rendering_device() != null   # Forward+ reads instance colours as linear
		wm.roughness_texture = load("res://assets/tex/facade%d_r.png" % (q + 1)); wm.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		wm.metallic_specular = 0.6
		_multi(unit, wm, walls[q], true, wall_cols[q])
		# night windows: the same walls a hair larger, the lit-window texture added on top after dusk
		var glow := _tex_mat("res://assets/tex/facade%d_n.jpg" % (q + 1), fac_uv, Color.BLACK)
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; glow.disable_receive_shadows = true
		var gx := []
		for xf: Transform3D in walls[q]: gx.append(Transform3D(xf.basis.scaled(Vector3(1.004, 1.0, 1.004)), xf.origin))
		var gi := _multi(unit, glow, gx, false); gi.visible = false
		facade_mats.append([glow, gi])
	_multi(unit, _tex_mat("res://assets/tex/roof.jpg", Vector3(1, 1, 1) / 12.0), roofs, false)
	var lm := _plain(Color.WHITE); lm.vertex_color_use_as_albedo = true; lm.vertex_color_is_srgb = RenderingServer.get_rendering_device() != null
	_multi(unit, lm, ledges, true, ledge_cols)
	# trees: the park trees plus a row along every pavement, and three-headed lamps at the corners
	for i in N:
		for j in N:
			var bx := i * CELL + 120.0; var by := j * CELL + 120.0
			for t in [100, 200, 300]:
				for p in [[bx + t, by + 6], [bx + t, by + 394], [bx + 6, by + t], [bx + 394, by + t]]:
					var sz := 9 + srand() * 4
					trunks.append(_box_xf(p[0], CURB + 22, p[1], 2.6, 44, 2.6))
					crowns.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sz * 1.25, sz, sz * 1.25) * S * 2.0), Vector3(p[0], CURB + 42 + sz, p[1]) * S))
					crown_cols.append(Color("4f7d45").lerp(Color(rng.randf_range(0.3, 0.55), rng.randf_range(0.5, 0.65), 0.25), rng.randf() * 0.6))
	var trunk := CylinderMesh.new(); trunk.top_radius = 0.3; trunk.bottom_radius = 0.5; trunk.height = 1.0; trunk.radial_segments = 7; trunk.rings = 1
	_multi(trunk, _plain(Color("6b4a35")), trunks)
	var cm := _plain(Color.WHITE, 0.85); cm.vertex_color_use_as_albedo = true; cm.vertex_color_is_srgb = RenderingServer.get_rendering_device() != null
	_multi(_crown_mesh(), cm, crowns, true, crown_cols)
	var km := _plain(Color.WHITE); km.vertex_color_use_as_albedo = true; km.vertex_color_is_srgb = cm.vertex_color_is_srgb
	_multi(unit, km, kit, true, kit_cols)
	var posts := []; var bulbs := []
	for i in N:
		for j in N:
			var bx := i * CELL + 120.0; var by := j * CELL + 120.0
			for p in [[bx + 7, by + 7], [bx + 393, by + 7], [bx + 7, by + 393], [bx + 393, by + 393]]:
				posts.append(_box_xf(p[0], CURB + 23, p[1], 1.6, 46, 1.6))
				bulbs.append(_box_xf(p[0], CURB + 47, p[1], 4, 4, 4))
	_multi(unit, _plain(Color("2f3238")), posts)
	var bm := _plain(Color("fff1c9")); bm.emission_enabled = true; bm.emission = Color("ffe6b0"); bm.emission_energy_multiplier = 0.4; bulb_mat = bm
	lamps.clear()
	for i in N:
		for j in N:
			var bx := i * CELL + 120.0; var by := j * CELL + 120.0
			for p in [[bx + 7, by + 7], [bx + 393, by + 7], [bx + 7, by + 393], [bx + 393, by + 393]]: lamps.append(Vector2(p[0], p[1]))
	_multi(unit, bm, bulbs, false)
	# road markings: a dashed centre line on every street and zebra crossings at every crossroads
	var dashes := []; var zebra := []
	for k in N + 1:
		var c := ic(k)
		var pos := 0.0
		while pos < WS:
			var inside := fmod(pos, CELL)
			if inside > 150 and inside < 510:
				dashes.append(_box_xf(c, 0.15, pos + 9, 2.5, 0.3, 18))
				dashes.append(_box_xf(pos + 9, 0.15, c, 18, 0.3, 2.5))
			pos += 40
	for i in N + 1:
		for j in N + 1:
			var X := i * CELL; var Y := j * CELL
			for s in 6:
				var o := 8 + s * 19
				zebra.append(_box_xf(X - 15, 0.15, Y + o + 4.5, 16, 0.3, 9))
				zebra.append(_box_xf(X + 135, 0.15, Y + o + 4.5, 16, 0.3, 9))
				zebra.append(_box_xf(X + o + 4.5, 0.15, Y - 15, 9, 0.3, 16))
				zebra.append(_box_xf(X + o + 4.5, 0.15, Y + 135, 9, 0.3, 16))
	var paint := _plain(Color("e9e7e1"), 0.8)
	_multi(unit, paint, dashes, false)
	_multi(unit, paint, zebra, false)
