extends "res://scripts/city.gd"
## Yerevan, from OpenStreetMap (assets/yerevan/center.json, made by tools/osm/osm2game.py): the real streets
## with their names, every building from its footprint and number of floors, parks, squares, footpaths, the
## trees and fountains on the map. It takes the place of the made-up city: the same calls (push_out, ground_y,
## lamps, kit ...) so the rest of the game drives, walks and lights it the same way.
## Map data © OpenStreetMap contributors, ODbL.

const CH := 2000.0            # chunk size for meshes (game units): far chunks are skipped by the camera
const SPAWN := Vector2(6000, 14000)   # the middle of Republic Square
var data := {}
var bpolys: Array = []        # [PackedVector2Array, Rect2, building dict]
var bcells := {}              # Vector2i(cell of 300) -> building indices
var roads: Array = []         # [PackedVector2Array, width (game units), name, kind]
var rcells := {}              # Vector2i(cell of 300) -> [road index, segment index]
var walk_lines: Array = []    # footpaths as PackedVector2Array, for people to walk on
var bounds := Rect2()
var is_yerevan := true
var landmarks: Array = []     # [Vector2, name] for the map
var water_areas: Array = []
var square_centre := SPAWN   # ponds and the singing fountains' pool

func generate() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/yerevan/center.json"))
	blocks = []
	bounds = Rect2(SPAWN, Vector2.ZERO)
	for b in data.buildings:
		var pts := PackedVector2Array(); var arr: Array = b.p
		for i in range(0, arr.size(), 2): pts.append(Vector2(arr[i], arr[i + 1]))
		var r := Rect2(pts[0], Vector2.ZERO)
		for q in pts: r = r.expand(q)
		bounds = bounds.merge(r)
		var k := bpolys.size(); bpolys.append([pts, r, b])
		for cx in range(int(floor(r.position.x / 300)), int(floor(r.end.x / 300)) + 1):
			for cy in range(int(floor(r.position.y / 300)), int(floor(r.end.y / 300)) + 1):
				var c := Vector2i(cx, cy)
				if not bcells.has(c): bcells[c] = []
				bcells[c].append(k)
		if b.has("n") and String(b.n).length() > 2 and (b.h >= 12 or ["government", "public", "civic", "museum", "theatre", "hotel", "church", "cathedral"].has(b.t)):
			var cen := Vector2.ZERO
			for q in pts: cen += q
			landmarks.append([cen / pts.size(), b.n])
	for rd in data.roads:
		var pts := PackedVector2Array(); var arr: Array = rd.p
		for i in range(0, arr.size(), 2): pts.append(Vector2(arr[i], arr[i + 1]))
		var k := roads.size(); roads.append([pts, float(rd.w) * 10.0, rd.n, rd.k])
		for s in pts.size() - 1:
			var c := Vector2i(int(floor(pts[s].x / 300)), int(floor(pts[s].y / 300)))
			if not rcells.has(c): rcells[c] = []
			rcells[c].append([k, s])
	for w in data.walks:
		var pts := PackedVector2Array(); var arr: Array = w.p
		for i in range(0, arr.size(), 2): pts.append(Vector2(arr[i], arr[i + 1]))
		if pts.size() > 1 and w.k != "steps": walk_lines.append(pts)
	bounds = bounds.grow(600)
	WX = int(bounds.end.x)

# ---------------------------------------------------------------- collision and ground ----------
static func _inside(p: Vector2, poly: PackedVector2Array) -> bool:
	var c := false; var j := poly.size() - 1
	for i in poly.size():
		var a := poly[i]; var b := poly[j]
		if ((a.y > p.y) != (b.y > p.y)) and (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x): c = not c
		j = i
	return c

## Buildings are solid: a circle of radius r is pushed out of any footprint it overlaps.
func push_out(p: Vector2, r: float) -> Vector2:
	var c := Vector2i(int(floor(p.x / 300)), int(floor(p.y / 300)))
	for k in bcells.get(c, []):
		var e: Array = bpolys[k]
		if e[2].get("min", 0.0) > 2.0: continue   # a roof on posts, or a bridge between buildings: walk under it
		if not (e[1] as Rect2).grow(r).has_point(p): continue
		var poly: PackedVector2Array = e[0]
		var best := 1e9; var bq := p
		for i in poly.size():
			var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
			var d := q.distance_squared_to(p)
			if d < best: best = d; bq = q
		var inside := _inside(p, poly)
		if inside: p = bq + (bq - p).normalized() * r if bq.distance_to(p) > 0.001 else bq
		elif best < r * r: p = bq + (p - bq).normalized() * r
	for cc in props.get(Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL))), []):
		var d: Vector2 = p - cc[0]; var rr: float = cc[1] + r
		if d.length_squared() < rr * rr and d.length_squared() > 0.0001: p = cc[0] + d.normalized() * rr
	p.x = clampf(p.x, bounds.position.x, bounds.end.x); p.y = clampf(p.y, bounds.position.y, bounds.end.y)
	return p

func ground_y(_x: float, _y: float) -> float:
	return 0.0

func road_point() -> Vector2:
	var rd: Array = roads[randi() % roads.size()]
	while rd[1] < 90: rd = roads[randi() % roads.size()]
	var pts: PackedVector2Array = rd[0]; var s := randi() % maxi(1, pts.size() - 1)
	return pts[s].lerp(pts[mini(s + 1, pts.size() - 1)], randf())

## The nearest road to p: [distance, width, point, direction]
func near_road(p: Vector2) -> Array:
	var c := Vector2i(int(floor(p.x / 300)), int(floor(p.y / 300)))
	var best := [1e9, 0.0, p, Vector2.RIGHT]
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for e in rcells.get(c + Vector2i(dx, dy), []):
				var rd: Array = roads[e[0]]; var pts: PackedVector2Array = rd[0]
				var a := pts[e[1]]; var b := pts[e[1] + 1]
				var q := Geometry2D.get_closest_point_to_segment(p, a, b); var d := q.distance_to(p)
				if d < best[0]: best = [d, rd[1], q, (b - a).normalized()]
	return best

# ------------------------------------------------------------------------- building ----------
func _chunk(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CH)), int(floor(p.y / CH)))

## One triangle, turned so its front faces along nrm (Godot draws clockwise triangles as front faces).
static func _tri(st: SurfaceTool, v: Array, nrm: Vector3, uv: Array = [], col = null) -> void:
	if ((v[1] - v[0]) as Vector3).cross(v[2] - v[0]).dot(nrm) > 0:
		v = [v[0], v[2], v[1]]
		if uv.size(): uv = [uv[0], uv[2], uv[1]]
	for i in 3:
		st.set_normal(nrm)
		if col != null: st.set_color(col)
		if uv.size(): st.set_uv(uv[i])
		st.add_vertex(v[i])

func _strip(st: SurfaceTool, pts: PackedVector2Array, w: float, y: float) -> void:   # a ribbon w wide along pts
	if pts.size() < 2: return
	var L := []; var R := []
	for i in pts.size():
		var d0 := (pts[i] - pts[maxi(i - 1, 0)]).normalized() if i > 0 else Vector2.ZERO
		var d1 := (pts[mini(i + 1, pts.size() - 1)] - pts[i]).normalized() if i < pts.size() - 1 else Vector2.ZERO
		var d := (d0 + d1).normalized()
		if d == Vector2.ZERO: d = d0 if d0 != Vector2.ZERO else Vector2.RIGHT
		var n := Vector2(-d.y, d.x); var k := 1.0 / maxf(0.5, n.dot(Vector2(-d1.y, d1.x) if d1 != Vector2.ZERO else n))
		L.append(pts[i] + n * w * 0.5 * minf(k, 2.0)); R.append(pts[i] - n * w * 0.5 * minf(k, 2.0))
	for i in pts.size() - 1:
		var a: Vector2 = L[i]; var b: Vector2 = R[i]; var c: Vector2 = L[i + 1]; var e: Vector2 = R[i + 1]
		var V := func(q: Vector2) -> Vector3: return Vector3(q.x * S, y, q.y * S)
		_tri(st, [V.call(a), V.call(c), V.call(b)], Vector3.UP); _tri(st, [V.call(b), V.call(c), V.call(e)], Vector3.UP)

func _poly_fill(st: SurfaceTool, poly: PackedVector2Array, y: float) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	for i in range(0, idx.size(), 3):
		var v := []
		for k in [idx[i], idx[i + 1], idx[i + 2]]: v.append(Vector3(poly[k].x * S, y, poly[k].y * S))
		_tri(st, v, Vector3.UP)

func _add_mesh(st: SurfaceTool, mat: Material, shadows := true, vis := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis > 0: mi.visibility_range_end = vis; mi.visibility_range_end_margin = 30; mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mi); return mi

const YTUFF := ["d98f7a", "e3a58c", "c97862", "e8b48a", "d9a066", "e6c08a", "b77a66", "cfa38f", "8d5a52"]   # pink, salmon, ochre, honey tuff and a dark one

func _colour(b: Dictionary, rng: RandomNumberGenerator) -> Color:
	if b.has("c"):
		var s := String(b.c)
		if Color.html_is_valid(s): return Color.html(s)
		var named := { "white": "e8e4dc", "grey": "a6a29c", "gray": "a6a29c", "pink": "d98f7a", "yellow": "e6c08a", "brown": "8d5a52", "orange": "e3a066", "beige": "dcc6a8", "red": "b5554a" }
		if named.has(s.to_lower()): return Color(named[s.to_lower()])
	if b.lv >= 9 and b.t in ["apartments", "yes", "residential"]: return Color(["c9c4bb", "b9b5ae", "d8d2c6", "a8a39d"][rng.randi() % 4])   # Soviet blocks
	if b.t in ["garage", "garages", "roof", "construction", "shed"]: return Color("8f8b85")
	return Color(YTUFF[rng.randi() % YTUFF.size()])

func build() -> void:
	if data.is_empty(): generate()
	var rng := RandomNumberGenerator.new(); rng.seed = 1918
	# the ground: tuff paving everywhere, then parks, squares, roads and footpaths over it
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = bounds.size * S + Vector2(400, 400)
	ground.mesh = pm; ground.material_override = _wet_mat("hexagonal_concrete_paving", 2.4, Color(0.88, 0.82, 0.78), 1.0, 0.6)
	ground.position = Vector3(bounds.get_center().x * S, -0.02, bounds.get_center().y * S); add_child(ground)
	var green := SurfaceTool.new(); green.begin(Mesh.PRIMITIVE_TRIANGLES)
	var square := SurfaceTool.new(); square.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parks: Array = []
	for a in data.areas:
		var poly := PackedVector2Array(); var arr: Array = a.p
		for i in range(0, arr.size() - 2, 2): poly.append(Vector2(arr[i], arr[i + 1]))
		if poly.size() < 3: continue
		if a.k in ["park", "garden", "grass", "recreation_ground", "playground", "scrub", "wood"]: _poly_fill(green, poly, 0.03); parks.append(poly)
		elif a.k == "pedestrian" and String(a.n).contains("Հանրապետ"): _carpet(poly)
		elif a.k == "pedestrian": _poly_fill(square, poly, 0.025)
		elif a.k == "water" or a.k == "swimming_pool": water_areas.append(poly)
		else: _poly_fill(square, poly, 0.022)
	_add_mesh(green, _wet_mat("leafy_grass", 2.5, Color(0.9, 0.95, 0.85), 1.0, 0.25), false)
	_add_mesh(square, _wet_mat("pavement_02", 3.5, Color(0.95, 0.9, 0.86), 1.0, 0.8), false)
	var asphalt := _wet_mat("asphalt_02", 4.0, Color(0.92, 0.92, 0.95))
	var rs := { }
	for rd in roads:
		var ck := _chunk(rd[0][0])
		if not rs.has(ck): rs[ck] = SurfaceTool.new(); rs[ck].begin(Mesh.PRIMITIVE_TRIANGLES)
		var y := 0.05 if rd[1] >= 120 else (0.045 if rd[1] >= 100 else 0.04)
		_strip(rs[ck], rd[0], rd[1], y)
	for ck in rs: _add_mesh(rs[ck], asphalt, false)
	var ws := SurfaceTool.new(); ws.begin(Mesh.PRIMITIVE_TRIANGLES)
	for w in data.walks:   # footpaths lie under the streets, so a path that crosses a street does not cover it
		if w.get("cr", false): continue
		var pts := PackedVector2Array(); var arr: Array = w.p
		for i in range(0, arr.size(), 2): pts.append(Vector2(arr[i], arr[i + 1]))
		_strip(ws, pts, float(w.w) * 10.0, 0.032)
	_add_mesh(ws, _wet_mat("pavement_02", 3.5, Color(0.86, 0.8, 0.74), 1.0, 0.7), false)
	_markings()
	_buildings(rng)
	_trees_and_lamps(rng)
	_fountains()
	if hi: _park_grass(parks, rng)

## Republic Square's oval with its stone carpet.
func _carpet(poly: PackedVector2Array) -> void:
	var r := Rect2(poly[0], Vector2.ZERO)
	for q in poly: r = r.expand(q)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); _poly_fill(st, poly, 0.03)
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/square_carpet.gdshader")
	m.set_shader_parameter("centre", r.get_center() * S); m.set_shader_parameter("radius", r.size * S / 2.0)
	m.set_shader_parameter("stone", load("res://assets/tex/ph/sandstone_blocks_05_diff.jpg"))
	_add_mesh(st, m, false)
	square_centre = r.get_center(); landmarks.append([square_centre, "Հանրապետության հրապարակ"])

## Street paint and kerbs: kerbstones along both edges, white edge lines, a dashed centre line on two-way
## streets (a double solid one on the big avenues), zebra crossings where the map has them.
func _markings() -> void:
	var dashes := []; var kerbs := []; var lines := []; var zebra := []
	for k in roads.size():
		var rd: Array = roads[k]
		if rd[1] < 50: continue
		var pts: PackedVector2Array = rd[0]; var big: bool = rd[1] >= 125 and not data.roads[k].get("one", false)
		for s2 in pts.size() - 1:
			var a := pts[s2]; var b := pts[s2 + 1]; var L := a.distance_to(b)
			if L < 1: continue
			var d := (b - a) / L; var n := Vector2(-d.y, d.x); var mid := (a + b) / 2.0; var ang := -d.angle()
			for side in [-1.0, 1.0]:
				var e: Vector2 = mid + n * side * rd[1] / 2.0
				kerbs.append(Transform3D(Basis(Vector3.UP, ang) * Basis.from_scale(Vector3(L * S, 0.16, 0.3)), Vector3(e.x * S, 0.08, e.y * S)))
				var e2: Vector2 = mid + n * side * (rd[1] / 2.0 - 6)
				lines.append(Transform3D(Basis(Vector3.UP, ang) * Basis.from_scale(Vector3(L * S, 0.02, 0.15)), Vector3(e2.x * S, 0.065, e2.y * S)))
			if big:
				for side in [-1.0, 1.0]:
					var c: Vector2 = mid + n * side * 1.5
					lines.append(Transform3D(Basis(Vector3.UP, ang) * Basis.from_scale(Vector3(L * S, 0.02, 0.12)), Vector3(c.x * S, 0.066, c.y * S)))
	for w in data.walks:
		if not w.get("cr", false): continue
		var arr: Array = w.p
		for i in range(0, arr.size() - 2, 2):
			var a := Vector2(arr[i], arr[i + 1]); var b := Vector2(arr[i + 2], arr[i + 3]); var L := a.distance_to(b)
			if L < 1: continue
			var d := (b - a) / L; var t := 4.0
			while t < L - 2:   # stripes along the street, one after another across it
				var p := a + d * t
				zebra.append(Transform3D(Basis(Vector3.UP, -d.angle()) * Basis.from_scale(Vector3(0.45, 0.02, 3.0)), Vector3(p.x * S, 0.067, p.y * S)))
				t += 9.0
	var stone := _ph_mat("sandstone_blocks_05", 1.5, Color(0.55, 0.53, 0.52))
	_multi(BoxMesh.new(), stone, kerbs, false)
	var paint := _plain(Color("e9e7e1"), 0.8)
	_multi(BoxMesh.new(), paint, lines, false)
	_multi(BoxMesh.new(), paint, zebra, false)
	for k in roads.size():
		var rd: Array = roads[k]
		if rd[1] < 95 or rd[1] >= 125 or data.roads[k].get("one", false): continue
		var pts: PackedVector2Array = rd[0]; var carry := 0.0
		for s in pts.size() - 1:
			var a := pts[s]; var b := pts[s + 1]; var L := a.distance_to(b); var d := (b - a) / maxf(L, 0.01)
			var t := carry
			while t < L:
				var p := a + d * (t + 9)
				if t + 18 < L: dashes.append(Transform3D(Basis(Vector3.UP, -d.angle()) * Basis.from_scale(Vector3(1.8, 0.03, 0.15)), Vector3(p.x * S, 0.07, p.y * S)))
				t += 40
			carry = t - L
	_multi(BoxMesh.new(), _plain(Color("e9e7e1"), 0.8), dashes, false)

## Every building: walls in its tuff (or Soviet concrete), floor bands and a cornice, a flat roof, and on
## computers real windows, balconies, shop fronts and a door, set out along each wall floor by floor.
func _buildings(rng: RandomNumberGenerator) -> void:
	var wall_mat := ShaderMaterial.new(); wall_mat.shader = load("res://shaders/yfacade.gdshader")
	wall_mat.set_shader_parameter("stone", load("res://assets/tex/ph/sandstone_blocks_05_diff.jpg"))
	wall_mat.set_shader_parameter("stone_n", load("res://assets/tex/ph/sandstone_blocks_05_nor.jpg"))
	wall_mat.set_shader_parameter("stone2", load("res://assets/tex/ph/rough_block_wall_diff.jpg"))
	wall_mat.set_shader_parameter("stone2_n", load("res://assets/tex/ph/rough_block_wall_nor.jpg"))
	wall_mat.set_shader_parameter("near_windows", 140.0 if hi else 0.0)
	var roof_mat := _tex_mat("res://assets/tex/roof.jpg", Vector3(1, 1, 1) / 12.0, Color(0.8, 0.78, 0.76), 0.9)
	if hi: parts = preload("res://scripts/facade_parts.gd").new(); parts.make_kit()
	var walls := {}; var roofs := {}
	var bands := {}; var band_cols := {}
	var put := {}   # chunk -> { win: [], bal: [], shop: [], shop_cols: [], door: [], arch: [] }
	var gov_best := 1e9; var gov = null
	var special: Array = []   # outlines of the landmarks built by hand: anything mapped inside them is left out
	for e in bpolys:
		if e[2].t in ["opera", "rossia"]: special.append(e[0])
	for e in bpolys:
		if not e[2].t in ["opera", "rossia"]:
			var cc := (e[1] as Rect2).get_center(); var skip := false
			for sp: PackedVector2Array in special: if _inside(cc, sp): skip = true
			if skip: continue
		var poly: PackedVector2Array = e[0]; var b: Dictionary = e[2]
		var on_square: bool = (e[1] as Rect2).get_center().distance_to(square_centre) < 2300 and b.h >= 9 and not b.has("min")
		if on_square:   # the square's Tamanyan buildings: tall, in pink tuff, on arcades
			b.h = maxf(b.h, 20.0); b.lv = maxi(b.lv, 5); b["arcade"] = true
			if not b.has("c"): b["c"] = ["e3a58c", "d98f7a", "e8b48a"][rng.randi() % 3]
			if String(b.get("n", "")).contains("կառավարություն"):
				var dg := (e[1] as Rect2).get_center().distance_to(square_centre)
				if dg < gov_best: gov_best = dg; gov = e
		if b.t == "opera": opera = e; continue   # built on their own below
		if b.t == "rossia": rossia = e; continue
		var h: float = b.h * 10.0; var h0: float = b.get("min", 0.0) * 10.0
		var col := _colour(b, rng); var soviet: bool = b.lv >= 9 and col.s < 0.15
		col.a = 1.0 if rng.randf() < 0.6 else 0.0
		var ck := _chunk(poly[0])
		if not walls.has(ck):
			walls[ck] = SurfaceTool.new(); walls[ck].begin(Mesh.PRIMITIVE_TRIANGLES)
			roofs[ck] = SurfaceTool.new(); roofs[ck].begin(Mesh.PRIMITIVE_TRIANGLES)
			bands[ck] = []; band_cols[ck] = []
			put[ck] = { "win": [], "bal": [], "shop": [], "shop_cols": [], "door": [], "arch": [] }
		var st: SurfaceTool = walls[ck]
		var u := 0.0
		var pale := col.lerp(Color.WHITE, 0.45); pale.a = 1.0
		var tuff_style: bool = not soviet and b.t not in ["garage", "garages", "roof", "shed", "construction"]
		var has_door := false; var awn: Color = Color(["b8333f", "2f6b5a", "c99a2e", "3d5a8c", "7a3b6a", "d0d0c8"][rng.randi() % 6])
		var balc := soviet or rng.randf() < 0.4
		for i in poly.size():
			var a := poly[i]; var c := poly[(i + 1) % poly.size()]; var L := a.distance_to(c)
			if L < 0.5: continue
			var d := (c - a) / L; var n2 := Vector2(d.y, -d.x)   # outward (the ring runs counter-clockwise)
			var nrm := Vector3(n2.x, 0, n2.y)
			# the wall quad; UV in metres: along the wall, up the wall
			var v0 := Vector3(a.x * S, h0 * S, a.y * S); var v1 := Vector3(c.x * S, h0 * S, c.y * S)
			var v2 := Vector3(c.x * S, h * S, c.y * S); var v3 := Vector3(a.x * S, h * S, a.y * S)
			var u1 := u + L * S
			_tri(st, [v0, v2, v1], nrm, [Vector2(u, h0 * S), Vector2(u1, h * S), Vector2(u1, h0 * S)], col)
			_tri(st, [v0, v3, v2], nrm, [Vector2(u, h0 * S), Vector2(u, h * S), Vector2(u1, h * S)], col)
			u = u1
			if b.t == "roof" or h - h0 < 25: continue
			# a cornice under the roof, and a band at each floor on the old tuff buildings
			var mid := (a + c) / 2.0; var ang := -d.angle()
			if tuff_style:
				bands[ck].append(Transform3D(Basis(Vector3.UP, ang) * Basis.from_scale(Vector3(L * S + 0.4, 0.45, 0.7)), Vector3(mid.x * S, h * S - 0.4, mid.y * S) + nrm * 0.25)); band_cols[ck].append(pale)
				if b.lv <= 7:
					for f in range(1, b.lv):
						bands[ck].append(Transform3D(Basis(Vector3.UP, ang) * Basis.from_scale(Vector3(L * S, 0.22, 0.36)), Vector3(mid.x * S, f * 3.3 + 0.95, mid.y * S) + nrm * 0.1)); band_cols[ck].append(pale)
			if not hi or h0 > 0: continue
			var cols := int(floor((L * S - 1.4) / 3.2))
			if cols < 1: continue
			var street := (near_road(mid + n2 * 40.0)[0] as float) < 260.0
			var basis := Basis(Vector3(d.x, 0, d.y), Vector3.UP, nrm)
			var start := (L * S - (cols - 1) * 3.2) / 2.0
			for k in cols:
				var p := Vector3(a.x * S, 0, a.y * S) + Vector3(d.x, 0, d.y) * (start + k * 3.2) + nrm * 0.01
				if street and not has_door and k == cols / 2 and L * S > 8: has_door = true; put[ck].door.append(Transform3D(basis, p + Vector3(0, 1.35, 0)))
				elif street and b.lv <= 12 and tuff_style and (b.t != "apartments" or b.get("arcade", false)) and rng.randf() < 0.85:
					if (rng.randf() < 0.25 and b.lv >= 3) or b.get("arcade", false): put[ck].arch.append(Transform3D(basis, p + Vector3(0, 1.75, 0)))
					else:
						put[ck].shop.append(Transform3D(basis, p + Vector3(0, 1.75, 0))); put[ck].shop_cols.append(awn)
						if k == 1: sign_spots.append(Transform3D(basis, p + Vector3(0, 4.35, 0) + nrm * 0.12))
				else: put[ck].win.append(Transform3D(basis, p + Vector3(0, 1.9, 0)))
				for f in range(1, b.lv):
					var y := f * 3.3 + 1.9
					if y + 1.2 > h * S - 0.6: break
					put[ck].win.append(Transform3D(basis, p + Vector3(0, y, 0)))
					if balc and f >= 1 and (k % 2 == 1 or soviet): put[ck].bal.append(Transform3D(basis, p + Vector3(0, y, 0)))
		_poly_roof(roofs[ck], poly, h * S)
	for ck in walls:
		_add_mesh(walls[ck], wall_mat)
		_add_mesh(roofs[ck], roof_mat, false)
		var bm := _plain(Color.WHITE, 0.85); bm.vertex_color_use_as_albedo = true; bm.vertex_color_is_srgb = true
		if bands[ck].size(): _multi(BoxMesh.new(), bm, bands[ck], true, band_cols[ck])
		if hi:
			var kt: Dictionary = parts.kit; var pc: Dictionary = put[ck]
			for e in [["win", false], ["bal", true], ["door", true]]:
				if pc[e[0]].size(): _vis(_multi(kt[e[0]], null, pc[e[0]], e[1], []), 150.0)
			if pc.shop.size(): _vis(_multi(kt.shop, null, pc.shop, false, pc.shop_cols), 180.0)
			if pc.arch.size(): _vis(_multi(kt.arch, null, pc.arch, true, []), 180.0)
	if gov != null: _clock_tower(gov)
	if opera != null: _opera(opera)
	if rossia != null: _rossia(rossia)
	if hi:   # big buildings hide what is behind them
		for e in bpolys:
			var r: Rect2 = e[1]
			if r.size.x < 150 or r.size.y < 150 or e[2].h < 9 or e[2].get("min", 0.0) > 0: continue
			var oc := OccluderInstance3D.new(); var bo := BoxOccluder3D.new()
			bo.size = Vector3(r.size.x * 0.7, e[2].h * 10.0 - 10, r.size.y * 0.7) * S
			oc.occluder = bo; oc.position = Vector3(r.get_center().x, e[2].h * 5.0, r.get_center().y) * S; add_child(oc)

var opera = null
var rossia = null
## The Opera house (Tamanyan's Opera and Ballet Theatre) on its real outline from the map: a ring of two-storey
## arches between pilasters in pale grey-pink tuff, a cornice and an attic with small windows, and the great
## round hall rising out of the middle in two drums with tall windows, crowned by a parapet; broad steps and
## the theatre's name on the side facing Freedom Square.
func _opera(e: Array) -> void:
	var poly: PackedVector2Array = e[0]; var r: Rect2 = e[1]
	var tuff := _ph_mat("sandstone_blocks_05", 3.6, Color("e6d2c2"))
	var stone := _ph_mat("sandstone_blocks_05", 2.0, Color("efe2d6"))
	var H := 17.0
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pil := []; var beams := []; var arches := []; var attic := []
	var kt: Dictionary = parts.kit if parts else {}
	for i in poly.size():
		var a := poly[i]; var c := poly[(i + 1) % poly.size()]; var L := a.distance_to(c)
		if L < 1: continue
		var d := (c - a) / L; var n2 := Vector2(d.y, -d.x); var nrm := Vector3(n2.x, 0, n2.y)
		var v0 := Vector3(a.x * S, 0, a.y * S); var v1 := Vector3(c.x * S, 0, c.y * S); var v2 := v1 + Vector3(0, H, 0); var v3 := v0 + Vector3(0, H, 0)
		_tri(st, [v0, v2, v1], nrm, [Vector2(0, 0), Vector2(L * S, H), Vector2(L * S, 0)]); _tri(st, [v0, v3, v2], nrm, [Vector2(0, 0), Vector2(0, H), Vector2(L * S, H)])
		var mid := (a + c) / 2.0; var ang := -d.angle(); var rot := Basis(Vector3.UP, ang)
		beams.append(Transform3D(rot * Basis.from_scale(Vector3(L * S + 0.5, 0.9, 1.3)), Vector3(mid.x * S, 12.4, mid.y * S) + nrm * 0.5))   # the cornice over the arches
		beams.append(Transform3D(rot * Basis.from_scale(Vector3(L * S + 0.3, 0.5, 0.9)), Vector3(mid.x * S, H + 0.2, mid.y * S) + nrm * 0.25))   # the top of the attic
		var n := int(floor(L * S / 6.2))
		var basis := Basis(Vector3(d.x, 0, d.y), Vector3.UP, nrm)
		for k in n:
			var t := (k + 0.5) / n; var p := a.lerp(c, t)
			if kt.has("arch"): arches.append(Transform3D(basis * Basis.from_scale(Vector3(1.7, 2.75, 1.3)), Vector3(p.x * S, 0.0, p.y * S) + nrm * 0.02))
			if kt.has("win"): attic.append(Transform3D(basis * Basis.from_scale(Vector3(0.8, 0.55, 1.0)), Vector3(p.x * S, 14.6, p.y * S) + nrm * 0.02))
			var q := a.lerp(c, float(k) / n)
			pil.append(Transform3D(rot * Basis.from_scale(Vector3(1.0, 12.0, 0.7)), Vector3(q.x * S, 6.0, q.y * S) + nrm * 0.3))
	_add_mesh(st, tuff)
	var roof := SurfaceTool.new(); roof.begin(Mesh.PRIMITIVE_TRIANGLES); _poly_roof(roof, poly, H + 0.05); _add_mesh(roof, _plain(Color("9b968f"), 0.9), false)
	_multi(BoxMesh.new(), stone, pil); _multi(BoxMesh.new(), stone, beams)
	if arches.size(): _vis(_multi(kt.arch, null, arches, true, []), 400.0)
	if attic.size(): _vis(_multi(kt.win, null, attic, false, []), 300.0)
	# the great round hall in the middle: a wide drum, then a narrower one, tall windows round each, parapets
	var cen := Vector2.ZERO
	for q in poly: cen += q
	cen /= poly.size()
	var rmin := minf(r.size.x, r.size.y) * S
	for lv in [[rmin * 0.36, H, 9.0], [rmin * 0.24, H + 9.0, 7.0]]:
		var rad: float = lv[0]; var y0: float = lv[1]; var hh: float = lv[2]
		var drum := MeshInstance3D.new(); var dm := CylinderMesh.new(); dm.top_radius = rad; dm.bottom_radius = rad; dm.height = hh; dm.radial_segments = 64
		drum.mesh = dm; drum.material_override = tuff; drum.position = Vector3(cen.x * S, y0 + hh / 2.0, cen.y * S); add_child(drum)
		var rim := MeshInstance3D.new(); var rm := CylinderMesh.new(); rm.top_radius = rad + 0.7; rm.bottom_radius = rad + 0.5; rm.height = 1.0; rm.radial_segments = 64
		rim.mesh = rm; rim.material_override = stone; rim.position = Vector3(cen.x * S, y0 + hh + 0.3, cen.y * S); add_child(rim)
		var cap := MeshInstance3D.new(); var cpm := CylinderMesh.new(); cpm.top_radius = rad - 0.2; cpm.bottom_radius = rad - 0.2; cpm.height = 0.3; cpm.radial_segments = 64
		cap.mesh = cpm; cap.material_override = _plain(Color("9b968f"), 0.9); cap.position = Vector3(cen.x * S, y0 + hh + 0.05, cen.y * S); add_child(cap)
		if kt.has("win"):
			var ring_w := []; var nw := int(TAU * rad / 3.4)
			for k in nw:
				var a := k * TAU / nw; var dir := Vector3(cos(a), 0, sin(a))
				ring_w.append(Transform3D(Basis(dir.cross(Vector3.UP).normalized(), Vector3.UP, dir) * Basis.from_scale(Vector3(0.85, 1.8, 1.0)), Vector3(cen.x * S, y0 + hh * 0.5, cen.y * S) + dir * (rad + 0.02)))
			_vis(_multi(kt.win, null, ring_w, false, []), 500.0)
	# the front towards Freedom Square: steps and the name
	var front := Vector2(cen.x, r.position.y)
	var best := 1e9
	for q in poly:
		if absf(q.x - cen.x) < r.size.x * 0.25 and q.y < best: best = q.y; front = Vector2(cen.x, q.y)
	var steps := []
	for k in 4: steps.append(Transform3D(Basis.from_scale(Vector3(36.0, 0.2 * (4 - k), 1.2)), Vector3(front.x * S, 0.1 * (4 - k), front.y * S - 0.6 - k * 1.2)))
	_multi(BoxMesh.new(), stone, steps)
	var lab := Label3D.new(); lab.text = "ՕՊԵՐԱՅԻ ԵՎ ԲԱԼԵՏԻ ԱԶԳԱՅԻՆ ԱԿԱԴԵՄԻԱԿԱՆ ԹԱՏՐՈՆ"; lab.font = load("res://fonts/NotoSansArmenian.ttf")
	lab.font_size = 80; lab.pixel_size = 0.012; lab.modulate = Color("6e5440"); lab.outline_size = 0
	lab.position = Vector3(front.x * S, 15.4, front.y * S - 0.12); lab.rotation.y = PI; add_child(lab)
	landmarks.append([cen, "Օպերա"])

## Rossia Mall, the old Rossia cinema: a glass and tuff podium, and over it the two great halls whose roofs
## sweep up like wings towards the avenue, a glass atrium between them, the name over the entrance.
func _rossia(e: Array) -> void:
	var poly: PackedVector2Array = e[0]; var r: Rect2 = e[1]
	var tuff := _ph_mat("rough_block_wall", 3.0, Color("b98a7a"))
	var concrete := _plain(Color("c9c3ba"), 0.7)
	var glass := _plain(Color(0.12, 0.16, 0.2), 0.05); glass.metallic = 0.5; glass.metallic_specular = 1.0
	var podium := SurfaceTool.new(); podium.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gl := SurfaceTool.new(); gl.begin(Mesh.PRIMITIVE_TRIANGLES)
	var P := 8.0
	for i in poly.size():
		var a := poly[i]; var c := poly[(i + 1) % poly.size()]; var L := a.distance_to(c)
		if L < 1: continue
		var d := (c - a) / L; var nrm := Vector3(d.y, 0, -d.x)
		var v0 := Vector3(a.x * S, 0, a.y * S); var v1 := Vector3(c.x * S, 0, c.y * S)
		_tri(gl, [v0, v1 + Vector3(0, 4.2, 0), v1], nrm); _tri(gl, [v0, v0 + Vector3(0, 4.2, 0), v1 + Vector3(0, 4.2, 0)], nrm)
		var u0 := v0 + Vector3(0, 4.2, 0); var u1 := v1 + Vector3(0, 4.2, 0)
		_tri(podium, [u0, u1 + Vector3(0, P - 4.2, 0), u1], nrm, [Vector2(0, 4.2), Vector2(L * S, P), Vector2(L * S, 4.2)])
		_tri(podium, [u0, u0 + Vector3(0, P - 4.2, 0), u1 + Vector3(0, P - 4.2, 0)], nrm, [Vector2(0, 4.2), Vector2(0, P), Vector2(L * S, P)])
	_add_mesh(gl, glass); _add_mesh(podium, tuff)
	var roof := SurfaceTool.new(); roof.begin(Mesh.PRIMITIVE_TRIANGLES); _poly_roof(roof, poly, P); _add_mesh(roof, concrete, false)
	# the avenue side: the side of the box nearest the widest street
	var cen := r.get_center(); var long_y := r.size.y >= r.size.x
	var fwd := Vector2(0, -1) if long_y else Vector2(1, 0)
	if (near_road(cen + fwd * r.size.length() * 0.6)[1] as float) < (near_road(cen - fwd * r.size.length() * 0.6)[1] as float): fwd = -fwd
	var side := Vector2(-fwd.y, fwd.x)
	var len_f: float = (r.size.y if long_y else r.size.x) * S * 0.92; var wid: float = (r.size.x if long_y else r.size.y) * S
	for sgn in [-1.0, 1.0]:   # two wings, each a wedge rising towards the front
		var w: float = wid * 0.42; var c3: Vector3 = Vector3(cen.x * S, P, cen.y * S) + Vector3(side.x, 0, side.y) * sgn * wid * 0.26
		var f3 := Vector3(fwd.x, 0, fwd.y); var s3 := Vector3(side.x, 0, side.y)
		var back: Vector3 = c3 - f3 * len_f / 2.0; var frnt: Vector3 = c3 + f3 * len_f / 2.0
		var lo := 4.0; var hi_h := 21.0
		var pts := [back - s3 * w / 2, back + s3 * w / 2, frnt + s3 * w / 2, frnt - s3 * w / 2]
		var top := [pts[0] + Vector3(0, lo, 0), pts[1] + Vector3(0, lo, 0), pts[2] + Vector3(0, hi_h, 0), pts[3] + Vector3(0, hi_h, 0)]
		var ws := SurfaceTool.new(); ws.begin(Mesh.PRIMITIVE_TRIANGLES)
		var roofn: Vector3 = (top[1] - top[0]).cross(top[3] - top[0]).normalized()
		if roofn.y < 0: roofn = -roofn
		_tri(ws, [top[0], top[1], top[2]], roofn); _tri(ws, [top[0], top[2], top[3]], roofn)
		for k in 4:   # the sides of the wedge
			var a: Vector3 = pts[k]; var b: Vector3 = pts[(k + 1) % 4]; var ta: Vector3 = top[k]; var tb: Vector3 = top[(k + 1) % 4]
			var nn: Vector3 = (b - a).cross(Vector3.UP).normalized()
			if nn.dot(a - c3) < 0: nn = -nn
			_tri(ws, [a, b, tb], nn, [Vector2(0, 0), Vector2(a.distance_to(b), 0), Vector2(a.distance_to(b), tb.y - b.y)])
			_tri(ws, [a, tb, ta], nn, [Vector2(0, 0), Vector2(a.distance_to(b), tb.y - b.y), Vector2(0, ta.y - a.y)])
		_add_mesh(ws, tuff)
		var edge := MeshInstance3D.new(); var em := BoxMesh.new(); em.size = Vector3(w + 0.6, 0.7, 0.8); edge.mesh = em; edge.material_override = concrete   # the lip of the roof at the front
		edge.position = (top[2] + top[3]) / 2.0; edge.basis = Basis(s3, Vector3.UP, f3); add_child(edge)
	var atrium := MeshInstance3D.new(); var am := BoxMesh.new(); am.size = Vector3(wid * 0.12, 12.0, len_f * 0.95); atrium.mesh = am; atrium.material_override = glass
	atrium.position = Vector3(cen.x * S, P + 6.0, cen.y * S); atrium.basis = Basis(Vector3(side.x, 0, side.y), Vector3.UP, Vector3(fwd.x, 0, fwd.y)); add_child(atrium)
	var lab := Label3D.new(); lab.text = "ՌՈՍՍԻԱ ՄՈԼ"; lab.font = load("res://fonts/NotoSansArmenian.ttf"); lab.font_size = 120; lab.pixel_size = 0.02
	lab.modulate = Color(1.0, 0.95, 0.9); lab.outline_size = 0; lab.shaded = false
	var fp := Vector3(cen.x * S, 6.2, cen.y * S) + Vector3(fwd.x, 0, fwd.y) * (len_f / 2.0 / 0.92 + 0.15)
	lab.position = fp; lab.basis = Basis(Vector3(-side.x, 0, -side.y), Vector3.UP, Vector3(fwd.x, 0, fwd.y)); add_child(lab)
	landmarks.append([cen, "Ռոսիա Մոլ"])

var clocks: Array = []   # clock face materials, set to the game's time
## Government House's clock tower: a tall tuff tower on the side towards the square, four clock faces near the top.
func _clock_tower(e: Array) -> void:
	var poly: PackedVector2Array = e[0]; var b: Dictionary = e[2]
	var best := 1e9; var at := poly[0]
	for i in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(square_centre, poly[i], poly[(i + 1) % poly.size()])
		if q.distance_to(square_centre) < best: best = q.distance_to(square_centre); at = q
	var inward := ((e[1] as Rect2).get_center() - at).normalized()
	var c := at + inward * 60.0; var base: float = b.h
	var tuff := _ph_mat("sandstone_blocks_05", 3.6, Color("e3a58c").lerp(Color.WHITE, 0.1))
	var parts3 := [[9.0, 16.0, base + 8.0], [10.2, 0.8, base + 16.4], [7.6, 6.0, base + 19.8], [8.4, 0.6, base + 23.1], [5.0, 4.0, base + 25.4]]
	for q in parts3:
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(q[0], q[1], q[0]); mi.mesh = bm; mi.material_override = tuff
		mi.position = Vector3(c.x * S, q[2], c.y * S); add_child(mi)
	var spire := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.05; cm.bottom_radius = 2.6; cm.height = 5.0; cm.radial_segments = 4
	spire.mesh = cm; spire.material_override = _plain(Color("6b4a3a"), 0.6); spire.position = Vector3(c.x * S, base + 29.9, c.y * S); spire.rotation.y = PI / 4; add_child(spire)
	for k in 4:   # the four clock faces
		var dir := Vector2.from_angle(k * PI / 2)
		var f := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(4.2, 4.2); f.mesh = qm
		var cmat := ShaderMaterial.new(); cmat.shader = load("res://shaders/clock.gdshader"); f.material_override = cmat; clocks.append(cmat)
		f.position = Vector3(c.x * S + dir.x * 3.85, base + 20.0, c.y * S + dir.y * 3.85); f.rotation.y = -dir.angle() + PI / 2
		add_child(f)
	_solid(c, 50); landmarks.append([c, "Կառավարության տուն"])

func _process(_dt: float) -> void:
	if clocks.is_empty() or get_parent() == null: return
	var m = get_parent()
	if not m.has_method("clock_text"): return
	var hm: float = fmod(6 + m.day_t * 24, 24)
	for cm: ShaderMaterial in clocks:
		cm.set_shader_parameter("hour", floor(hm)); cm.set_shader_parameter("minute", fmod(hm * 60.0, 60.0)); cm.set_shader_parameter("night", m.night_k)

func _vis(mi: MultiMeshInstance3D, d: float) -> void:
	mi.visibility_range_end = d; mi.visibility_range_end_margin = 20; mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

func _poly_roof(st: SurfaceTool, poly: PackedVector2Array, y: float) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	for i in range(0, idx.size(), 3):
		var v := []; var uv := []
		for k in [idx[i], idx[i + 1], idx[i + 2]]: v.append(Vector3(poly[k].x * S, y, poly[k].y * S)); uv.append(poly[k] * S / 12.0)
		_tri(st, v, Vector3.UP, uv)

## The trees on the map, and street lamps along the wider streets.
func _trees_and_lamps(rng: RandomNumberGenerator) -> void:
	var spots := []
	for t in data.trees:
		var p := Vector2(t[0], t[1])
		var ins := false
		var c := Vector2i(int(floor(p.x / 300)), int(floor(p.y / 300)))
		for k in bcells.get(c, []):
			if (bpolys[k][1] as Rect2).has_point(p) and _inside(p, bpolys[k][0]): ins = true; break
		if ins: continue
		var ck := _chunk(p)
		spots.append([p.x, p.y, rng.randf_range(0.8, 1.25), ck.x + 50, ck.y + 50, 0.0])
		_solid(p, 3)
	if hi: _real_trees(spots, rng)
	else:
		var tr := []; var cr := []
		for sp in spots:
			tr.append(_box_xf(sp[0], 22, sp[1], 2.6, 44, 2.6))
			cr.append(Transform3D(Basis.from_scale(Vector3(22, 20, 22) * S), Vector3(sp[0], 52, sp[1]) * S))
		_multi(BoxMesh.new(), _plain(Color("6b4a35")), tr); _multi(_crown_mesh(), _plain(Color("4f7d45")), cr)
	var lamp := kit("lamp")
	for k in lamp.get_surface_count():
		var m = lamp.surface_get_material(k)
		if m is BaseMaterial3D and (String(m.resource_name).contains("glass") or String(m.resource_name).contains("bulb")):
			var g: BaseMaterial3D = m.duplicate(); g.emission_enabled = true; g.emission = Color("ffd9a0"); g.emission_energy_multiplier = 0.0
			lamp.surface_set_material(k, g); lamp_glow.append(g)
	var lx := []
	for rd in roads:
		if rd[1] < 95: continue
		var pts: PackedVector2Array = rd[0]; var carry := 0.0
		for s in pts.size() - 1:
			var a := pts[s]; var b := pts[s + 1]; var L := a.distance_to(b); var d := (b - a) / maxf(L, 0.01); var n := Vector2(-d.y, d.x)
			var t := carry
			while t < L:
				for side in [-1.0, 1.0]:
					var p: Vector2 = a + d * t + n * side * (rd[1] / 2.0 + 18)
					if push_out(p, 4) == p: lx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 1.2), Vector3(p.x, 0, p.y) * S)); lamps.append(p); _solid(p, 3)
				t += 340
			carry = t - L
	_multi(lamp, null, lx)
	bulb_mat = _plain(Color("fff1c9")); bulb_mat.emission_enabled = true

## Fountains: the water in their basins, and jets on computers.
func _fountains() -> void:
	var wm := ShaderMaterial.new(); wm.shader = load("res://shaders/water.gdshader")
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := []
	var polys: Array = water_areas.duplicate()
	for f in data.fountains:
		if f.has("p"):
			var poly := PackedVector2Array(); var arr: Array = f.p
			for i in range(0, arr.size() - 2, 2): poly.append(Vector2(arr[i], arr[i + 1]))
			polys.append(poly)
	for poly: PackedVector2Array in polys:
		if true:
			if poly.size() < 3: continue
			_poly_fill(st, poly, 0.35)
			for i in poly.size():
				var a := poly[i]; var b := poly[(i + 1) % poly.size()]; var L := a.distance_to(b)
				rim.append(Transform3D(Basis(Vector3.UP, -(b - a).angle()) * Basis.from_scale(Vector3(L * S + 0.3, 0.55, 0.45)), Vector3((a.x + b.x) / 2 * S, 0.27, (a.y + b.y) / 2 * S)))
			var cen := Vector2.ZERO
			for q in poly: cen += q
			cen /= poly.size(); landmarks.append([cen, "Շատրվան"])
			var r := 0.0
			for q in poly: r = maxf(r, q.distance_to(cen))
			_solid(cen, r * 0.8)
	_add_mesh(st, wm, false)
	_multi(BoxMesh.new(), _ph_mat("sandstone_blocks_05", 3.0, Color(0.85, 0.78, 0.7)), rim)

## Grass blades in the parks (computers), scattered inside each park's outline.
func _park_grass(parks: Array, rng: RandomNumberGenerator) -> void:
	var patch := _grass_patch(rng, 60)
	var gm := ShaderMaterial.new(); gm.shader = load("res://shaders/grass.gdshader")
	for poly: PackedVector2Array in parks:
		var r := Rect2(poly[0], Vector2.ZERO)
		for q in poly: r = r.expand(q)
		if r.get_area() > 4.0e6: continue
		var xs := []; var cols := []
		var y := r.position.y
		while y < r.end.y:
			var x := r.position.x
			while x < r.end.x:
				var p := Vector2(x + rng.randf_range(-4, 4), y + rng.randf_range(-4, 4))
				if _inside(p, poly):
					xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.2, rng.randf_range(0.8, 1.2), 1.2)), Vector3(p.x * S, 0.03, p.y * S)))
					cols.append(Color(rng.randf_range(0.85, 1.1), rng.randf_range(0.9, 1.1), rng.randf_range(0.8, 1.0)))
				x += 12
			y += 12
		if xs.size():
			var gi := _multi(patch, gm, xs, false, cols); grass_nodes.append(gi)
			gi.visibility_range_end = 120.0; gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

# ---------------------------------------------------------------------------- people ----------
## A walker in Yerevan follows a footpath (or the pavement along a street) to its end and turns back.
func ped_start(p) -> void:
	var line: PackedVector2Array = walk_lines[randi() % walk_lines.size()]
	p.path = line; p.seg = randi() % maxi(1, line.size() - 1); p.u = randf(); p.dir = 1 if randf() < 0.5 else -1
	var q := line[p.seg].lerp(line[mini(p.seg + 1, line.size() - 1)], p.u); p.x = q.x; p.y = q.y

func ped_step(p, dt: float) -> void:
	if p.panic_t > 0: p.panic_t -= dt
	if p.act != "":
		p.act_t -= dt
		if p.act_t <= 0 or p.panic_t > 0: p.act = ""
		else: return
	var line: PackedVector2Array = p.path
	if line.size() < 2: ped_start(p); return
	var a := line[p.seg]; var b := line[mini(p.seg + 1, line.size() - 1)]; var L := maxf(a.distance_to(b), 0.1)
	var sp: float = p.sp * (2.8 if p.panic_t > 0 else 1.0)
	p.u += p.dir * sp * dt / L
	if p.u > 1.0:
		if p.seg + 1 < line.size() - 1: p.seg += 1; p.u -= 1.0
		else: p.dir = -1; p.u = 1.0
	elif p.u < 0.0:
		if p.seg > 0: p.seg -= 1; p.u += 1.0
		else: p.dir = 1; p.u = 0.0
	a = line[p.seg]; b = line[mini(p.seg + 1, line.size() - 1)]
	var q := a.lerp(b, clampf(p.u, 0, 1)); var off: Vector2 = Vector2(-(b - a).y, (b - a).x).normalized() * (p.i % 3 - 1) * 6.0
	p.x = q.x + off.x; p.y = q.y + off.y; p.a = (b - a).angle() + (PI if p.dir < 0 else 0.0)
	if randf() < dt * 0.015: p.act = ["phone", "look", "wait", "idle"].pick_random(); p.act_t = randf_range(4, 10)

# ------------------------------------------------------------------------------ map ----------
## Draws Yerevan onto the map image: parks, squares, streets, buildings. px turns game units into pixels.
func draw_map(img: Image, px: Callable, k: float) -> void:
	img.fill(Color("bdb3a6"))
	for a in data.areas:
		var poly := PackedVector2Array(); var arr: Array = a.p
		for i in range(0, arr.size() - 2, 2): poly.append(px.call(arr[i], arr[i + 1]))
		_fill(img, poly, Color("6fa35e") if a.k in ["park", "garden", "grass", "playground", "recreation_ground"] else Color("d8c7ad"))
	for rd in roads:
		var pts: PackedVector2Array = rd[0]; var w := maxi(2, int(rd[1] * k))
		for s in pts.size() - 1:
			var a: Vector2 = px.call(pts[s].x, pts[s].y); var b: Vector2 = px.call(pts[s + 1].x, pts[s + 1].y)
			var n := int(a.distance_to(b)) + 1
			for t in n + 1:
				var c := a.lerp(b, float(t) / n); img.fill_rect(Rect2i(int(c.x) - w / 2, int(c.y) - w / 2, w, w), Color("474a52"))
	for e in bpolys:
		var poly := PackedVector2Array()
		for q in (e[0] as PackedVector2Array): poly.append(px.call(q.x, q.y))
		_fill(img, poly, Color("b98576") if e[2].lv < 9 else Color("9c9890"))

static func _fill(img: Image, poly: PackedVector2Array, col: Color) -> void:   # scanline fill of a polygon in pixels
	var r := Rect2(poly[0], Vector2.ZERO)
	for q in poly: r = r.expand(q)
	for y in range(maxi(0, int(r.position.y)), mini(img.get_height(), int(r.end.y) + 1)):
		var xs := []
		var j := poly.size() - 1
		for i in poly.size():
			var a := poly[i]; var b := poly[j]
			if (a.y > y + 0.5) != (b.y > y + 0.5): xs.append(a.x + (y + 0.5 - a.y) * (b.x - a.x) / (b.y - a.y))
			j = i
		xs.sort()
		for i in range(0, xs.size() - 1, 2):
			var x0 := maxi(0, int(xs[i])); var x1 := mini(img.get_width() - 1, int(xs[i + 1]))
			if x1 >= x0: img.fill_rect(Rect2i(x0, y, x1 - x0 + 1, 1), col)
