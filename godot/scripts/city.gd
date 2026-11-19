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
				if cells.size() == 1 and b.rects[0].d > 0.3: b.rects = _courtyard(b.rects[0])
			col.append(b)
		blocks.append(col)

## A big building round a courtyard: four wings, the east one with a gateway through it (no new random numbers,
## so the rest of the city comes out the same).
func _courtyard(r: Dictionary) -> Array:
	var wd := 105.0; var gap := 46.0
	var mid: float = (r.h - 2 * wd - gap) / 2
	var out := []
	for q in [[r.x, r.y, r.w, wd], [r.x, r.y + r.h - wd, r.w, wd], [r.x, r.y + wd, wd, r.h - 2 * wd],
			[r.x + r.w - wd, r.y + wd, wd, mid], [r.x + r.w - wd, r.y + wd + mid + gap, wd, mid]]:
		var e := r.duplicate(); e.x = q[0]; e.y = q[1]; e.w = q[2]; e.h = q[3]; e.court = true; out.append(e)
	return out

var courts: Array = []
var grass_nodes: Array = []   # the park grass, for the quality setting
var sign_spots: Array = []   # over a shop front: where a neon sign can hang (Godot units, +z out of the wall)   # courtyard middles, game units

## A roof terrace: railings round the edge; tall buildings get a glass penthouse set back from it.
func _roof_extras(r: Dictionary, h: float, rails: Array, pent: Array) -> void:
	var top := h + 3.7
	if h > FULL * 0.84:
		var inset := 40.0; var ph := 30.0
		pent.append(_box_xf(r.x + r.w / 2.0, top + ph / 2.0, r.y + r.h / 2.0, r.w - inset * 2, ph, r.h - inset * 2))
		pent.append(_box_xf(r.x + r.w / 2.0, top + ph + 1.0, r.y + r.h / 2.0, r.w - inset * 2 + 6, 2, r.h - inset * 2 + 6))
	elif h > FULL * 0.6: return
	for e in [[r.x, r.y, r.x + r.w, r.y], [r.x, r.y + r.h, r.x + r.w, r.y + r.h], [r.x, r.y, r.x, r.y + r.h], [r.x + r.w, r.y, r.x + r.w, r.y + r.h]]:
		var a := Vector2(e[0], e[1]); var b := Vector2(e[2], e[3]); var L := a.distance_to(b); var c := (a + b) / 2
		var horiz: bool = e[1] == e[3]
		rails.append(_box_xf(c.x, top + 9.5, c.y, L if horiz else 0.8, 0.8, 0.8 if horiz else L))
		rails.append(_box_xf(c.x, top + 4.5, c.y, L if horiz else 0.4, 0.4, 0.4 if horiz else L))
		var k := 0.0
		while k <= L:
			var p := a.lerp(b, k / L); rails.append(_box_xf(p.x, top + 5, p.y, 0.6, 10, 0.6)); k += 14.0

## Each building's height in game units: from two-storey houses to a few towers.
static func bheight(r: Dictionary) -> float:
	if r.get("court", false): return FULL * 0.62
	return FULL * [1.0, 0.77, 0.62, 0.85, 0.42, 0.55, 0.92, 1.3][int(r.z * 7.3) % 8]

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
		for c in props.get(Vector2i(i, j), []):   # benches, bins, lamps, kiosks
			var d: Vector2 = p - c[0]; var rr: float = c[1] + r
			if d.length_squared() < rr * rr and d.length_squared() > 0.0001: p = c[0] + d.normalized() * rr
	p.x = clampf(p.x, 8, WS - 8); p.y = clampf(p.y, 8, WS - 8)
	return p

func ground_y(x: float, y: float) -> float:   # pavements are raised
	return CURB if x > 120 and y > 120 and x < WS and y < WS and fmod(x, CELL) >= 120 and fmod(y, CELL) >= 120 else 0.0

func road_point() -> Vector2:  # a random spot in the middle of a street
	var k := randi_range(0, N); var m := randi_range(0, N - 1); var t := ic(m) + randf_range(150, 370)
	return Vector2(t, ic(k)) if randf() < 0.5 else Vector2(ic(k), t)

# ---------------------------------------------------------------- building the scene ----------
var hi := RenderingServer.get_rendering_device() != null   # Forward+ on a computer: full detail

func _tex_mat(path: String, uv: Vector3, tint := Color.WHITE, rough := 0.9, normal := "", nscale := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if hi and normal != "":
		m.normal_enabled = true; m.normal_texture = load(normal); m.normal_scale = nscale
	m.albedo_texture = load(path)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = uv
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

## Plane trees grown in Blender (tools/blender/trees.py): bark and leaf cards, one multimesh per block and kind.
func _real_trees(spots: Array, rng: RandomNumberGenerator) -> void:
	var bark := StandardMaterial3D.new(); bark.albedo_texture = load("res://assets/tree/bark_diff.jpg"); bark.uv1_scale = Vector3(3, 6, 1)
	bark.normal_enabled = true; bark.normal_texture = load("res://assets/tree/bark_nor.jpg"); bark.roughness = 0.9
	var leaf := ShaderMaterial.new(); leaf.shader = load("res://shaders/leaves.gdshader"); leaf.set_shader_parameter("leaves", load("res://assets/tree/leaves.png"))
	var meshes := []
	for nm in ["tree_a", "tree_b"]:
		var root: Node = load("res://assets/tree/%s.glb" % nm).instantiate(); var mesh: ArrayMesh = null
		var st := [root]
		while st.size():
			var n: Node = st.pop_back(); st.append_array(n.get_children())
			if n is MeshInstance3D and mesh == null: mesh = (n as MeshInstance3D).mesh
		root.free()
		for k in mesh.get_surface_count():
			var m := mesh.surface_get_material(k)
			mesh.surface_set_material(k, leaf if m and m.resource_name == "leaves" else bark)
		meshes.append(mesh)
	var groups := {}
	for t in spots:
		var key := Vector3i(t[3], t[4], rng.randi() % meshes.size())
		if not groups.has(key): groups[key] = [[], []]
		var sc: float = t[2] * rng.randf_range(0.85, 1.12)
		groups[key][0].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(t[0] * S, CURB * S, t[1] * S)))
		groups[key][1].append(Color(rng.randf_range(0.85, 1.05), rng.randf_range(0.9, 1.08), rng.randf_range(0.8, 0.95)))
	for key: Vector3i in groups:
		var mi := _multi(meshes[key.z], null, groups[key][0], true, groups[key][1])
		mi.visibility_range_end = 520.0; mi.visibility_range_end_margin = 50.0; mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

## A tree crown in a unit box: a cluster of lumps instead of one ball.
func _crown_mesh() -> Mesh:
	var st := SurfaceTool.new()
	for b in [[Vector3(0, -0.05, 0), 0.4], [Vector3(0.2, 0.08, 0.12), 0.3], [Vector3(-0.2, 0.06, -0.12), 0.3], [Vector3(0.04, 0.25, -0.06), 0.27],
			[Vector3(-0.1, -0.08, 0.22), 0.27], [Vector3(0.16, -0.1, -0.2), 0.25]]:
		var sp := SphereMesh.new(); sp.radius = b[1]; sp.height = b[1] * 2; sp.radial_segments = 14 if hi else 9; sp.rings = 8 if hi else 5
		st.append_from(sp, 0, Transform3D(Basis.IDENTITY, b[0]))
	return st.commit()

## A Poly Haven texture set (colour, OpenGL normal, roughness), laid in world space; size: one image in Godot units.
func _ph_mat(name: String, size: float, tint := Color.WHITE, nscale := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); var base := "res://assets/tex/ph/" + name
	m.albedo_texture = load(base + "_diff.jpg"); m.albedo_color = tint
	m.normal_enabled = true; m.normal_texture = load(base + "_nor.jpg"); m.normal_scale = nscale
	m.roughness_texture = load(base + "_rough.jpg"); m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED; m.roughness = 1.0
	m.uv1_triplanar = true; m.uv1_world_triplanar = true; m.uv1_scale = Vector3.ONE / size
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

var _pnoise: NoiseTexture2D
## The same Poly Haven set as _ph_mat, but a shader that gets wet in the rain (shaders/wet_ground.gdshader).
func _wet_mat(name: String, size: float, tint := Color.WHITE, nscale := 1.0, keeps := 1.0) -> ShaderMaterial:
	if _pnoise == null:
		var fn := FastNoiseLite.new(); fn.seed = 11; fn.frequency = 0.02; fn.fractal_octaves = 3
		_pnoise = NoiseTexture2D.new(); _pnoise.width = 512; _pnoise.height = 512; _pnoise.seamless = true; _pnoise.noise = fn
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/wet_ground.gdshader"); var base := "res://assets/tex/ph/" + name
	m.set_shader_parameter("diff", load(base + "_diff.jpg")); m.set_shader_parameter("nor", load(base + "_nor.jpg"))
	m.set_shader_parameter("rough", load(base + "_rough.jpg")); m.set_shader_parameter("pnoise", _pnoise)
	m.set_shader_parameter("tint", tint); m.set_shader_parameter("size", size); m.set_shader_parameter("nscale", nscale)
	m.set_shader_parameter("keeps_water", keeps)
	return m

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
	if mat: mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _box_xf(cx: float, cy: float, cz: float, sx: float, sy: float, sz: float) -> Transform3D:  # centre and size in game units
	return Transform3D(Basis.from_scale(Vector3(sx, sy, sz) * S), Vector3(cx, cy, cz) * S)

var props := {}           # Vector2i(block) -> [[centre, radius]]: street furniture you cannot walk through
var lamp_glow: Array = []   # lamp glass that lights up at night
var benches: Array = []     # [position, facing angle] in game units, for people to sit on

## The first mesh in a model file, with its own materials.
func kit(name: String) -> Mesh:
	var root: Node = load("res://assets/street/%s.glb" % name).instantiate(); var mesh: Mesh = null
	var st := [root]
	while st.size() and mesh == null:
		var n: Node = st.pop_back(); st.append_array(n.get_children())
		if n is MeshInstance3D: mesh = (n as MeshInstance3D).mesh
	root.free()
	return mesh

func _solid(at: Vector2, r: float) -> void:
	var k := Vector2i(int(floor(at.x / CELL)), int(floor(at.y / CELL)))
	if not props.has(k): props[k] = []
	props[k].append([at, r])

## Lamps at the corners, and along the pavements benches, bins, hydrants, bus stops; kiosks in the parks.
func _street_furniture(rng: RandomNumberGenerator) -> void:
	var lamp := kit("lamp")
	for k in lamp.get_surface_count():   # the lantern's glass and bulb glow after dusk
		var m = lamp.surface_get_material(k)
		if m is BaseMaterial3D and (String(m.resource_name).contains("glass") or String(m.resource_name).contains("bulb")):
			var g: BaseMaterial3D = m.duplicate(); g.emission_enabled = true; g.emission = Color("ffd9a0"); g.emission_energy_multiplier = 0.0
			lamp.surface_set_material(k, g); lamp_glow.append(g)
	var lx := []
	for p: Vector2 in lamps:
		lx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 1.2), Vector3(p.x, CURB, p.y) * S)); _solid(p, 3)
	_multi(lamp, null, lx)
	var put := { "bench": [], "bin": [], "hydrant": [], "busstop": [], "kiosk": [], "planter": [] }
	var stops := 0
	for i in N:
		for j in N:
			var b: Dictionary = blocks[i][j]
			var bx := i * CELL + 120.0; var by := j * CELL + 120.0
			if b.type == "park":   # a kiosk at one corner of the park
				var c := rng.randi() % 4; var cx := bx + (60.0 if c % 2 == 0 else 340.0); var cy := by + (60.0 if c < 2 else 340.0)
				put.kiosk.append([Vector2(cx, cy), atan2(by + 200 - cy, bx + 200 - cx) + PI]); _solid(Vector2(cx, cy), 17)
			if b.type == "plaza": continue
			for side in 4:
				var n: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][side]
				var along := Vector2(-n.y, n.x)
				var mid := Vector2(bx + 200, by + 200) + n * 200   # the kerb at the middle of this side
				var at := func(t: float, off: float) -> Vector2: return mid + along * (t - 200) - n * off
				var face := atan2(n.y, n.x)
				if stops < 12 and rng.randf() < 0.18 and b.type != "park":
					stops += 1; var c: Vector2 = at.call(250, 10)
					put.busstop.append([c, face]); _solid(c - along * 15, 8); _solid(c + along * 15, 8)
				elif rng.randf() < 0.55:
					var t := 150.0 if rng.randf() < 0.5 else 250.0; var c: Vector2 = at.call(t, 5)
					put.bench.append([c, face]); _solid(c, 6); benches.append([c, face])
				if rng.randf() < 0.5: var c: Vector2 = at.call(124, 4); put.bin.append([c, face]); _solid(c, 4)
				if rng.randf() < 0.3: var c: Vector2 = at.call(60, 4); put.hydrant.append([c, face + PI / 2]); _solid(c, 3)
	for cc: Vector2 in courts:   # benches round the courtyard tree
		for a in [0.0, PI]:
			var c := cc + Vector2.from_angle(a) * 28; put.bench.append([c, a]); _solid(c, 6); benches.append([c, a])
	# the square: benches round the pond side, planters at the corners, two kiosks
	var sx := 3 * CELL + 120.0; var sy := 3 * CELL + 120.0
	for c in [[sx + 40, sy + 40], [sx + 360, sy + 40], [sx + 40, sy + 360], [sx + 360, sy + 360]]:
		for q in [Vector2(22, 0), Vector2(0, 22)]: put.planter.append([Vector2(c[0], c[1]) + q, 0.0])
	put.kiosk.append([Vector2(sx + 70, sy + 330), -PI / 4]); put.kiosk.append([Vector2(sx + 330, sy + 70), PI * 3 / 4])
	for kname in put:
		var xs := []
		for e in put[kname]:
			var p: Vector2 = e[0]
			xs.append(Transform3D(Basis(Vector3.UP, -float(e[1])), Vector3(p.x, CURB, p.y) * S))
		if xs.size(): _multi(kit(kname), null, xs)

## Blades of grass in a 1 m patch: thin bent triangles, the vertex alpha saying how high up the blade.
func _grass_patch(rng: RandomNumberGenerator, blades: int) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in blades:
		var p := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
		var a := rng.randf() * TAU; var side := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.012, 0.022)
		var lean := Vector3(sin(a), 0, -cos(a)) * rng.randf_range(0.02, 0.12)
		var h := rng.randf_range(0.14, 0.34); var shade := rng.randf_range(0.8, 1.15)
		var c0 := Color(shade, shade, shade, 0.0); var c1 := Color(shade, shade, shade, 0.55); var c2 := Color(shade, shade, shade, 1.0)
		var m := p + Vector3(0, h * 0.55, 0) + lean * 0.4; var top := p + Vector3(0, h, 0) + lean
		st.set_normal(Vector3.UP)
		for v in [[p - side, c0], [p + side, c0], [m + side * 0.6, c1], [p - side, c0], [m + side * 0.6, c1], [m - side * 0.6, c1], [m - side * 0.6, c1], [m + side * 0.6, c1], [top, c2]]:
			st.set_color(v[1]); st.add_vertex(v[0])
	return st.commit()

## Parks on computers: thick grass with wind, beds of flowers in three colours, a few shrubs.
func _gardens(rng: RandomNumberGenerator) -> void:
	var patch := _grass_patch(rng, 70)
	var gm := ShaderMaterial.new(); gm.shader = load("res://shaders/grass.gdshader")
	var plants := {}
	for nm in ["flower_yellow", "flower_orange", "flower_blue", "shrub"]:
		var root: Node = load("res://assets/plants/%s.glb" % nm).instantiate(); var st := [root]
		while st.size():
			var n: Node = st.pop_back(); st.append_array(n.get_children())
			if n is MeshInstance3D: plants[nm] = (n as MeshInstance3D).mesh; break
		root.free()
	for i in N:
		for j in N:
			var b: Dictionary = blocks[i][j]
			if b.type != "park": continue
			var bx := i * CELL + 144.0; var by := j * CELL + 144.0   # the lawn inside the path ring
			var xs := []; var cols := []; var fl := { "flower_yellow": [], "flower_orange": [], "flower_blue": [], "shrub": [] }
			var y := 0.0
			while y < 352:
				var x := 0.0
				while x < 352:
					var p := Vector2(bx + x + rng.randf_range(-3, 3), by + y + rng.randf_range(-3, 3))
					var skip := false
					for r: Rect2 in keep_out: if r.grow(6).has_point(p): skip = true
					for c in props.get(Vector2i(i, j), []): if p.distance_to(c[0]) < c[1] + 4: skip = true
					if not skip:
						xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.2, rng.randf_range(0.8, 1.3), 1.2)), Vector3(p.x * S, CURB * S + 0.02, p.y * S)))
						cols.append(Color(rng.randf_range(0.85, 1.1), rng.randf_range(0.9, 1.1), rng.randf_range(0.8, 1.0)))
					x += 11
				y += 11
			for bed in 5:   # round flower beds of one kind each
				var kind: String = ["flower_yellow", "flower_orange", "flower_blue"][bed % 3]
				var c := Vector2(bx + rng.randf_range(40, 312), by + rng.randf_range(40, 312))
				var out := false
				for r: Rect2 in keep_out: if r.grow(30).has_point(c): out = true
				if out: continue
				for k in 46:
					var q := c + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 26
					fl[kind].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.6, 2.6)), Vector3(q.x * S, CURB * S, q.y * S)))
			for k in 8:
				var q := Vector2(bx + rng.randf_range(10, 342), by + (rng.randf_range(4, 20) if k % 2 else rng.randf_range(332, 348)))
				var out := false
				for r: Rect2 in keep_out: if r.grow(15).has_point(q): out = true
				if not out: fl.shrub.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)), Vector3(q.x * S, CURB * S, q.y * S)))
			var gi := _multi(patch, gm, xs, false, cols); grass_nodes.append(gi)
			gi.visibility_range_end = 140.0; gi.visibility_range_end_margin = 20.0; gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			for kind in fl:
				if fl[kind].is_empty(): continue
				var fi := _multi(plants[kind], null, fl[kind], kind == "shrub")
				fi.visibility_range_end = 160.0 if kind != "shrub" else 400.0

var parts                 # the 3D windows, balconies and shop fronts (computers)
var keep_out: Array = []   # Rect2s where park trees are left out (the house)

func build() -> void:
	if blocks.is_empty(): generate()
	var unit := BoxMesh.new()   # 1 x 1 x 1, scaled per instance
	# ground: asphalt everywhere, the blocks sit on it as raised slabs
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(WS, WS) * S
	ground.mesh = pm
	ground.material_override = _wet_mat("asphalt_02", 4.0, Color(0.92, 0.92, 0.95))
	ground.position = Vector3(WS / 2.0, 0, WS / 2.0) * S
	add_child(ground)
	var far := MeshInstance3D.new()   # hills beyond the edge
	var fm := PlaneMesh.new(); fm.size = Vector2(1400, 1400)
	far.mesh = fm; far.material_override = _plain(Color("76866a")); far.position = Vector3(WS / 2.0 * S, -0.1, WS / 2.0 * S)
	add_child(far)

	var slabs := []; var parks := []; var plaza := []
	var walls := { 0: [], 1: [] }; var wall_cols := { 0: [], 1: [] }; var roofs := []; var ledges := []; var ledge_cols := []
	var trunks := []; var crowns := []; var crown_cols := []; var kit := []; var kit_cols := []
	var rails := []; var pent := []
	var tree_spots := []   # [x, y, size, block i, block j] for the Blender trees on computers
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
					tree_spots.append([t.x, t.y, 0.8 + t.r / 50.0, i, j])
					trunks.append(_box_xf(t.x, CURB + 9, t.y, 4, 18, 4))
					crowns.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(t.r, t.r * 1.15, t.r) * S * 2.0), Vector3(t.x, CURB + 18 + t.r * 0.8, t.y) * S))
					crown_cols.append(Color("4f7d45").lerp(Color(rng.randf_range(0.3, 0.55), rng.randf_range(0.5, 0.65), 0.25), rng.randf() * 0.6))
			if b.rects.size() and b.rects[0].get("court", false):   # a tree in the middle of the courtyard
				var r0: Dictionary = b.rects[0]; var r1: Dictionary = b.rects[1]
				var cc := Vector2(r0.x + r0.w / 2.0 + 20, (r0.y + r0.h + r1.y) / 2.0)
				tree_spots.append([cc.x, cc.y, 1.1, i, j]); courts.append(cc)
			var n := 0
			for r in b.rects:
				n += 1
				var h: float = bheight(r)
				if hi and not r.get("court", false): _roof_extras(r, h, rails, pent)
				walls[n % 2].append(_box_xf(r.x + r.w / 2.0, h / 2.0, r.y + r.h / 2.0, r.w, h, r.h))
				if hi:   # buildings hide what is behind them: the GPU skips drawing it (occlusion culling)
					var oc := OccluderInstance3D.new(); var bo := BoxOccluder3D.new(); bo.size = Vector3(r.w - 4, h - 2, r.h - 4) * S
					oc.occluder = bo; oc.position = Vector3(r.x + r.w / 2.0, h / 2.0, r.y + r.h / 2.0) * S; add_child(oc)
				var tuff := Color(r.c).lerp(Color.WHITE, 0.12); tuff.a = 1.0 if r.d > 0.35 else 0.0   # alpha picks the stone
				wall_cols[n % 2].append(tuff); ledge_cols.append(tuff.lerp(Color.WHITE, 0.45))
				roofs.append(_box_xf(r.x + r.w / 2.0, h + 0.4, r.y + r.h / 2.0, r.w - 2, 1, r.h - 2))
				ledges.append(_box_xf(r.x + r.w / 2.0, h + 1.6, r.y + r.h / 2.0, r.w + 4.4, 4.2, r.h + 4.4))
	if hi and rails.size():   # roof terraces: iron railings, and glass penthouses on the tall ones
		var iron := _plain(Color(0.12, 0.12, 0.13), 0.4); iron.metallic = 0.7
		_multi(unit, iron, rails)
		var gl := _plain(Color(0.16, 0.2, 0.24), 0.05); gl.metallic = 0.4; gl.metallic_specular = 1.0
		_multi(unit, gl, pent)
	var paving := _wet_mat("hexagonal_concrete_paving", 2.4, Color(0.86, 0.83, 0.82), 1.0, 0.6)
	_multi(unit, paving, slabs, false)
	_multi(unit, _wet_mat("pavement_02", 3.5, Color.WHITE, 1.0, 0.8), plaza, false)
	_multi(unit, _wet_mat("leafy_grass", 2.5, Color(0.9, 0.95, 0.85), 1.0, 0.25), parks, false)
	var fac_uv := Vector3(1.0 / (WIDE * S), 1.0 / (FULL * S), 1.0 / (WIDE * S))
	for q in 2:
		var wm := ShaderMaterial.new(); wm.shader = load("res://shaders/facade.gdshader")   # windows plus cut tuff blocks
		wm.set_shader_parameter("facade", load("res://assets/tex/facade%d.jpg" % (q + 1)))
		wm.set_shader_parameter("facade_r", load("res://assets/tex/facade%d_r.png" % (q + 1)))
		wm.set_shader_parameter("stone", load("res://assets/tex/ph/sandstone_blocks_05_diff.jpg"))
		wm.set_shader_parameter("stone_n", load("res://assets/tex/ph/sandstone_blocks_05_nor.jpg"))
		wm.set_shader_parameter("stone_r", load("res://assets/tex/ph/sandstone_blocks_05_rough.jpg"))
		wm.set_shader_parameter("fac_size", Vector2(WIDE, FULL) * S); wm.set_shader_parameter("srgb_tint", hi)
		wm.set_shader_parameter("windows", not hi)
		wm.set_shader_parameter("stone2", load("res://assets/tex/ph/rough_block_wall_diff.jpg"))
		wm.set_shader_parameter("stone2_n", load("res://assets/tex/ph/rough_block_wall_nor.jpg"))
		wm.set_shader_parameter("stone2_r", load("res://assets/tex/ph/rough_block_wall_rough.jpg"))
		wm.set_shader_parameter("ground", CURB * S)
		_multi(unit, wm, walls[q], true, wall_cols[q])
		# night windows: the same walls a hair larger, the lit-window texture added on top after dusk
		var glow := _tex_mat("res://assets/tex/facade%d_n.jpg" % (q + 1), fac_uv, Color.BLACK)
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; glow.disable_receive_shadows = true
		var gx := []
		for xf: Transform3D in walls[q]: gx.append(Transform3D(xf.basis.scaled(Vector3(1.004, 1.0, 1.004)), xf.origin))
		if not hi:   # on a computer the 3D windows light up instead
			var gi := _multi(unit, glow, gx, false); gi.visible = false
			facade_mats.append([glow, gi])
	if hi: parts = preload("res://scripts/facade_parts.gd").new(); parts.build(self)
	_multi(unit, _tex_mat("res://assets/tex/roof.jpg", Vector3(1, 1, 1) / 12.0, Color.WHITE, 0.9, "res://assets/tex/roof_n.png"), roofs, false)
	var lm := _plain(Color.WHITE); lm.vertex_color_use_as_albedo = true; lm.vertex_color_is_srgb = RenderingServer.get_rendering_device() != null
	_multi(unit, lm, ledges, true, ledge_cols)
	# trees: the park trees plus a row along every pavement, and three-headed lamps at the corners
	for i in N:
		for j in N:
			var bx := i * CELL + 120.0; var by := j * CELL + 120.0
			for t in [100, 200, 300]:
				for p in [[bx + t, by + 6], [bx + t, by + 394], [bx + 6, by + t], [bx + 394, by + t]]:
					var sz := 9 + srand() * 4
					tree_spots.append([p[0], p[1], 0.62 + sz / 60.0, i, j])
					trunks.append(_box_xf(p[0], CURB + 22, p[1], 2.6, 44, 2.6))
					crowns.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sz * 1.25, sz, sz * 1.25) * S * 2.0), Vector3(p[0], CURB + 42 + sz, p[1]) * S))
					crown_cols.append(Color("4f7d45").lerp(Color(rng.randf_range(0.3, 0.55), rng.randf_range(0.5, 0.65), 0.25), rng.randf() * 0.6))
	var trunk := CylinderMesh.new(); trunk.top_radius = 0.3; trunk.bottom_radius = 0.5; trunk.height = 1.0; trunk.radial_segments = 7; trunk.rings = 1
	if hi: _real_trees(tree_spots, rng)
	else:
		_multi(trunk, _plain(Color("6b4a35")), trunks)
		var cm := _plain(Color.WHITE, 0.85); cm.vertex_color_use_as_albedo = true; cm.vertex_color_is_srgb = false
		_multi(_crown_mesh(), cm, crowns, true, crown_cols)
	lamps.clear()
	for i in N:
		for j in N:
			var bx := i * CELL + 120.0; var by := j * CELL + 120.0
			for p in [[bx + 7, by + 7], [bx + 393, by + 7], [bx + 7, by + 393], [bx + 393, by + 393]]: lamps.append(Vector2(p[0], p[1]))
	var bm := _plain(Color("fff1c9")); bm.emission_enabled = true; bm.emission = Color("ffe6b0"); bm.emission_energy_multiplier = 0.4; bulb_mat = bm
	_street_furniture(rng)
	if hi: _gardens(rng)
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
