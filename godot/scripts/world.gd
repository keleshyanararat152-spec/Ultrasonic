extends Node3D
class_name World
## Beyond the old city: the river along its east side with two stone bridges, a new district on the far bank,
## and in the south hills a mountain road that winds up to a viewpoint. All in game units (x, y on the ground);
## heights in game units too (×S for Godot).

const S := 0.1
const CELL := 520
const RX0 := 3760.0          # the river, between its two embankments
const RX1 := 4160.0
const BRIDGES := [2, 5]      # the street rows that cross it
const T0 := Vector2(-1400.0, 3760.0)   # the hills: the height grid's corner, cell size and count
const TC := 40.0
const TNX := 180
const TNY := 100
const ROAD_W := 52.0         # half the mountain road's width
const RIVER_DEPTH := -34.0   # the water, and the riverbed below it
const BED := -60.0

var city
var hts := PackedFloat32Array()   # terrain heights, row by row
var road: Array = []              # [Vector2 point, height, side vector] every ~20 units
var road_cells := {}              # Vector2i(cell of 200) -> indices into road, for quick distance checks
var summit := Vector2.ZERO
var water_mat: ShaderMaterial

static func on_bridge(y: float) -> bool:
	for j in BRIDGES:
		if absf(y - (j * CELL + 60.0)) < 58.0: return true
	return false

static func in_river(x: float, y: float) -> bool:
	return x > RX0 and x < RX1 and not (on_bridge(y) and y < 3760.0)

## The river is a wall you cannot drive or walk into, except over a bridge.
static func river_push(p: Vector2, r: float) -> Vector2:
	if p.x > RX0 - r and p.x < RX1 + r and not (on_bridge(p.y) and p.y < 3760.0):
		if p.x - (RX0 - r) < (RX1 + r) - p.x: p.x = RX0 - r
		else: p.x = RX1 + r
	return p

# ------------------------------------------------------------------ the mountain road ----------
const PATH := [Vector2(1100, 3700), Vector2(1100, 4250), Vector2(1500, 4700), Vector2(2400, 4650), Vector2(3150, 5000), Vector2(3000, 5550),
	Vector2(2200, 5750), Vector2(1300, 5650), Vector2(600, 6050), Vector2(900, 6650), Vector2(1800, 6900), Vector2(2500, 6700)]
const TOP := 620.0           # height at the viewpoint, game units (62 m)

func _make_road() -> void:
	var pts: Array = []
	for k in PATH.size() - 1:   # Catmull-Rom through the control points
		var p0: Vector2 = PATH[maxi(0, k - 1)]; var p1: Vector2 = PATH[k]; var p2: Vector2 = PATH[k + 1]; var p3: Vector2 = PATH[mini(PATH.size() - 1, k + 2)]
		var n := int(p1.distance_to(p2) / 20.0) + 1
		for s in n:
			var t := float(s) / n; var t2 := t * t; var t3 := t2 * t
			pts.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
	pts.append(PATH[PATH.size() - 1])
	var total := 0.0; var lens := [0.0]
	for k in range(1, pts.size()): total += (pts[k] as Vector2).distance_to(pts[k - 1]); lens.append(total)
	for k in pts.size():
		var d: Vector2 = ((pts[mini(k + 1, pts.size() - 1)] as Vector2) - (pts[maxi(k - 1, 0)] as Vector2)).normalized()
		var u: float = lens[k] / total
		var h := TOP * smoothstep(0.0, 1.0, clampf((u - 0.04) / 0.96, 0, 1))   # flat where it leaves the city, then climbing
		road.append([pts[k], h, Vector2(-d.y, d.x)])
		var c := Vector2i(int(floor(pts[k].x / 200.0)), int(floor(pts[k].y / 200.0)))
		if not road_cells.has(c): road_cells[c] = []
		road_cells[c].append(k)
	summit = PATH[PATH.size() - 1]

## The nearest point of the road: [distance, its height]
func road_near(p: Vector2) -> Array:
	var c := Vector2i(int(floor(p.x / 200.0)), int(floor(p.y / 200.0)))
	var best := 1e9; var bh := 0.0
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			for k in road_cells.get(c + Vector2i(dx, dy), []):
				var d: float = p.distance_squared_to(road[k][0])
				if d < best: best = d; bh = road[k][1]
	return [sqrt(best), bh]

# ----------------------------------------------------------------------- the hills ----------
func _hash(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n & 0xffff) / 65535.0

func _vnoise(p: Vector2) -> float:
	var i := Vector2i(int(floor(p.x)), int(floor(p.y))); var f := p - Vector2(i); f = f * f * (Vector2(3, 3) - 2 * f)
	return lerpf(lerpf(_hash(i.x, i.y), _hash(i.x + 1, i.y), f.x), lerpf(_hash(i.x, i.y + 1), _hash(i.x + 1, i.y + 1), f.x), f.y)

func _hills(x: float, y: float) -> float:   # rolling hills rising away from the city, a valley for the river
	var p := Vector2(x, y) / 900.0
	var n := _vnoise(p) * 0.55 + _vnoise(p * 2.1 + Vector2(5, 3)) * 0.3 + _vnoise(p * 4.3 + Vector2(1, 9)) * 0.15
	var rise := smoothstep(3760.0, 5200.0, y)
	var h := (n * 1300.0 - 150.0) * rise + 380.0 * rise
	var rv := absf(x - (RX0 + RX1) / 2.0)   # the river valley
	h = lerpf(BED + 20.0, h, smoothstep(220.0, 700.0, rv))
	return h

func _build_heights() -> void:
	hts.resize((TNX + 1) * (TNY + 1))
	for j in TNY + 1:
		for i in TNX + 1:
			var x := T0.x + i * TC; var y := T0.y + j * TC
			var h := _hills(x, y)
			var rn := road_near(Vector2(x, y))   # the ground is cut and filled to carry the road
			h = lerpf(rn[1] - 1.0, h, smoothstep(ROAD_W + 10.0, ROAD_W + 160.0, rn[0]))
			if y < T0.y + 120.0 and not (x > RX0 - 300 and x < RX1 + 300): h = minf(h, lerpf(0.0, h, (y - T0.y) / 120.0))   # meets the city's edge
			hts[j * (TNX + 1) + i] = h

## Ground height in the hills (game units), from the grid.
func height(x: float, y: float) -> float:
	var fx := clampf((x - T0.x) / TC, 0, TNX - 0.001); var fy := clampf((y - T0.y) / TC, 0, TNY - 0.001)
	var i := int(fx); var j := int(fy); var u := fx - i; var v := fy - j
	var w := TNX + 1
	return lerpf(lerpf(hts[j * w + i], hts[j * w + i + 1], u), lerpf(hts[(j + 1) * w + i], hts[(j + 1) * w + i + 1], u), v)

func in_hills(x: float, y: float) -> bool:
	return y > T0.y and x > T0.x and x < T0.x + TNX * TC and y < T0.y + TNY * TC

# ------------------------------------------------------------------------- building ----------
func build(c) -> void:
	city = c
	_make_road(); _build_heights()
	_terrain(); _road_mesh(); _river(); _bridges(); _hill_trees()

func _terrain() -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := TNX + 1
	for j in TNY + 1:
		for i in TNX + 1:
			var x := T0.x + i * TC; var y := T0.y + j * TC
			var hl := hts[j * w + maxi(i - 1, 0)]; var hr := hts[j * w + mini(i + 1, TNX)]
			var hu := hts[maxi(j - 1, 0) * w + i]; var hd := hts[mini(j + 1, TNY) * w + i]
			st.set_normal(Vector3((hl - hr) * S, 2 * TC * S, (hu - hd) * S).normalized())
			st.add_vertex(Vector3(x, hts[j * w + i], y) * S)
	for j in TNY:
		for i in TNX:
			var a := j * w + i
			st.add_index(a); st.add_index(a + 1); st.add_index(a + w); st.add_index(a + 1); st.add_index(a + w + 1); st.add_index(a + w)
	var mi := MeshInstance3D.new(); mi.mesh = st.commit()
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/terrain.gdshader")
	for k in ["diff", "nor", "rough"]:
		m.set_shader_parameter("grass_" + k, load("res://assets/tex/ph/leafy_grass_%s.jpg" % k))
		m.set_shader_parameter("rock_" + k, load("res://assets/tex/ph/rocky_terrain_02_%s.jpg" % k))
	mi.material_override = m; add_child(mi)

func _road_mesh() -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var posts := []
	for k in road.size():
		var p: Vector2 = road[k][0]; var h: float = road[k][1] + 0.6; var sd: Vector2 = road[k][2]
		var l := p - sd * ROAD_W; var r := p + sd * ROAD_W
		st.set_normal(Vector3.UP); st.add_vertex(Vector3(l.x, h, l.y) * S); st.add_vertex(Vector3(r.x, h, r.y) * S)
		if k % 3 == 0 and k > 6:   # guard rail posts on both sides
			for q in [p - sd * (ROAD_W + 4), p + sd * (ROAD_W + 4)]:
				posts.append(Transform3D(Basis.from_scale(Vector3(0.18, 0.9, 0.18)), Vector3(q.x * S, (h + 4.5) * S, q.y * S)))
	for k in road.size() - 1:
		var a := k * 2
		st.add_index(a); st.add_index(a + 2); st.add_index(a + 1); st.add_index(a + 1); st.add_index(a + 2); st.add_index(a + 3)
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = city._wet_mat("asphalt_02", 4.0, Color(0.85, 0.85, 0.88))
	add_child(mi)
	var dash := []   # the centre line
	for k in range(2, road.size() - 1, 2):
		var p: Vector2 = road[k][0]; var q: Vector2 = road[k + 1][0]; var d := q - p
		dash.append(Transform3D(Basis(Vector3.UP, -d.angle()).scaled(Vector3(d.length() * 0.6 * S, 0.03, 0.25)), Vector3((p.x + q.x) / 2 * S, (road[k][1] + 0.75) * S, (p.y + q.y) / 2 * S)))
	city._multi(BoxMesh.new(), city._plain(Color("e9e7e1"), 0.8), dash, false)
	var iron: StandardMaterial3D = city._plain(Color(0.6, 0.62, 0.64), 0.4); iron.metallic = 0.8
	city._multi(BoxMesh.new(), iron, posts)
	var rail := []   # rails between the posts
	for k in range(6, road.size() - 3, 3):
		for s in [-1.0, 1.0]:
			var p: Vector2 = road[k][0] + road[k][2] * s * (ROAD_W + 4); var q: Vector2 = road[k + 3][0] + road[k + 3][2] * s * (ROAD_W + 4)
			var ha: float = road[k][1]; var hb: float = road[k + 3][1]
			var a := Vector3(p.x, ha + 8, p.y) * S; var b := Vector3(q.x, hb + 8, q.y) * S; var d := b - a
			if d.length() < 0.1: continue
			rail.append(Transform3D(Basis.looking_at(d.normalized(), Vector3.UP) * Basis.from_scale(Vector3(0.06, 0.3, d.length())), (a + b) / 2))
	city._multi(BoxMesh.new(), iron, rail)
	# the viewpoint at the top: a paved round with benches looking back over the city
	var vp := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 14; cm.bottom_radius = 14.5; cm.height = 0.4; vp.mesh = cm
	vp.material_override = city._wet_mat("pavement_02", 3.5); vp.position = Vector3(summit.x * S, (TOP + 0.6) * S, summit.y * S); add_child(vp)
	var bx := []
	for k in 5:
		var a := -PI / 2 - 0.9 + k * 0.45; var p := summit + Vector2.from_angle(a) * 110
		bx.append(Transform3D(Basis(Vector3.UP, -(a)), Vector3(p.x * S, (TOP + 2.6) * S, p.y * S)))
	city._multi(city.kit("bench"), null, bx)

func _river() -> void:
	var len_y := T0.y + TNY * TC + 800.0
	water_mat = ShaderMaterial.new(); water_mat.shader = load("res://shaders/river.gdshader")
	var wm := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(RX1 - RX0 + 600, len_y + 800) * S; pm.subdivide_width = 8; pm.subdivide_depth = 80
	wm.mesh = pm; wm.material_override = water_mat; wm.position = Vector3((RX0 + RX1) / 2 * S, RIVER_DEPTH * S, (len_y / 2 - 400) * S); add_child(wm)
	var bed := MeshInstance3D.new(); var bm := PlaneMesh.new(); bm.size = Vector2(RX1 - RX0 + 600, len_y + 800) * S; bed.mesh = bm
	bed.material_override = city._plain(Color("4a463c")); bed.position = Vector3((RX0 + RX1) / 2 * S, BED * S, (len_y / 2 - 400) * S); add_child(bed)
	# stone embankments along the city stretch, with an iron railing on top
	var stone: StandardMaterial3D = city._ph_mat("rough_block_wall", 3.0, Color(0.75, 0.68, 0.62))
	var walls := []; var rails := []; var posts := []
	for x in [RX0, RX1]:
		var y0 := -400.0
		var cuts := []
		for j in BRIDGES: cuts.append(j * CELL + 60.0)
		var ys := [y0]
		for c in cuts:
			ys.append(c - 60.0); ys.append(c + 60.0)
		ys.append(3760.0)
		for k in range(0, ys.size(), 2):
			var a: float = ys[k]; var b: float = ys[k + 1]; var cx: float = x + (-6.0 if x == RX0 else 6.0)
			walls.append(city._box_xf(cx, (BED + city.CURB) / 2.0, (a + b) / 2.0, 12, city.CURB - BED, b - a))
			if a > 0:   # a railing so you do not fall in (the pavements only)
				rails.append(city._box_xf(cx, city.CURB + 10, (a + b) / 2.0, 0.8, 0.8, b - a))
				var yy := a
				while yy < b: posts.append(city._box_xf(cx, city.CURB + 5, yy, 0.7, 10, 0.7)); yy += 25
	city._multi(BoxMesh.new(), stone, walls)
	var iron: StandardMaterial3D = city._plain(Color(0.08, 0.08, 0.09), 0.4); iron.metallic = 0.8
	city._multi(BoxMesh.new(), iron, rails); city._multi(BoxMesh.new(), iron, posts)

func _bridges() -> void:
	var mesh: Mesh = city.kit("bridge")
	var asphalt = city._wet_mat("asphalt_02", 4.0, Color(0.92, 0.92, 0.95))
	for k in mesh.get_surface_count():
		var mt := mesh.surface_get_material(k)
		if mt and String(mt.resource_name) == "road": mesh.surface_set_material(k, asphalt)
	var xs := []
	for j in BRIDGES:
		xs.append(Transform3D(Basis.IDENTITY, Vector3((RX0 + RX1) / 2 * S, 0.02, (j * CELL + 60) * S)))
		city.lamps.append(Vector2(RX0 + 5, j * CELL + 4)); city.lamps.append(Vector2(RX1 - 5, j * CELL + 116))
	city._multi(mesh, null, xs)

func _hill_trees() -> void:
	if not city.hi: return
	var rng := RandomNumberGenerator.new(); rng.seed = 919
	var spots := []
	for k in 520:
		var x := rng.randf_range(T0.x, T0.x + TNX * TC); var y := rng.randf_range(T0.y + 200, T0.y + TNY * TC)
		if absf(x - (RX0 + RX1) / 2) < 320: continue
		if (road_near(Vector2(x, y))[0] as float) < ROAD_W + 40: continue
		var h := height(x, y)
		spots.append([x, y, rng.randf_range(0.9, 1.5), 20 + int((x - T0.x) / 1400.0), 20 + int((y - T0.y) / 1400.0), h])
	city._real_trees(spots, rng)
