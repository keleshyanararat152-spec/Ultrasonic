extends RefCounted
class_name People
## People: a skinned Rocketbox avatar posed in code (walk, stand), and the pedestrians who walk round the
## blocks, wait at crossings for the cars' red light, cross, run from fast cars and fall when hit.
## A port of walkPose / pedStep / startCross / panic from game/city/index.html.

const CELL := 520
const AVATARS := ["m07", "m04", "m08", "f05", "f13", "f02"]
const PEOPLE := ["m02", "m03", "m04", "m06", "m08", "m10", "m12", "m16", "m17", "f01", "f02", "f05", "f07", "f08", "f13", "f15", "f17"]   # who walks the streets
const H := 1.85 * 1.05     # height in Godot units
static var _scenes := {}

static func scene(id: String) -> PackedScene:   # any avatar by name, loaded once
	if not _scenes.has(id): _scenes[id] = load("res://assets/people/%s.glb" % id)
	return _scenes[id]

## A posable person. root is placed in the world; the model inside faces +x like the cars.
class Avatar:
	var root := Node3D.new()
	var skel: Skeleton3D
	var bones := {}
	var lat := Vector3.RIGHT      # axes of the model, in skeleton space
	var down := Vector3.DOWN
	var fwd := Vector3.FORWARD
	var lower := {}               # rotation that brings each upper arm down from the A-pose
	var outward := {}             # per side, the body axis pointing away from the body
	var phase := 0.0
	static var _walk_tables := {}   # per model: the walk worked out once at 16 steps, so each frame only sets rotations
	const WN := 16
	const WB := ["L Thigh", "R Thigh", "L Calf", "R Calf", "L UpperArm", "R UpperArm", "L Forearm", "R Forearm",
		"Pelvis", "Spine1", "Head", "L Foot", "R Foot", "L Hand", "R Hand",
		"L Finger1", "L Finger11", "L Finger2", "L Finger21", "L Finger3", "L Finger31", "L Finger4", "L Finger41",
		"R Finger1", "R Finger11", "R Finger2", "R Finger21", "R Finger3", "R Finger31", "R Finger4", "R Finger41", "L Finger0", "R Finger0"]
	var bob := 0.0                   # how high the body rides in the step, Godot units
	var wt = null                    # { idx: bone indices, stand: [Quaternion], step: [[Quaternion]] }

	func _init(scene: PackedScene) -> void:
		var model: Node3D = scene.instantiate()
		root.add_child(model)
		model.rotation.y = PI / 2   # the avatars face +z; turn them to face +x (checked against the bones below)
		skel = _find_skel(model)
		if skel == null: return
		var xf := Transform3D.IDENTITY   # skeleton space -> model space, by walking up to the model
		var n: Node = skel
		while n != model and n != null:
			if n is Node3D: xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var inv := xf.basis.inverse()
		lat = (inv * Vector3.RIGHT).normalized(); down = (inv * Vector3.DOWN).normalized(); fwd = (inv * Vector3.BACK).normalized()
		# read the body's own axes from its bones, so it does not matter how the importer turned the file
		var hb := skel.find_bone("Bip01 Head"); var pb := skel.find_bone("Bip01 Pelvis"); var lb := skel.find_bone("Bip01 L Thigh"); var rb := skel.find_bone("Bip01 R Thigh")
		if hb >= 0 and pb >= 0 and lb >= 0 and rb >= 0:
			var up := (skel.get_bone_global_rest(hb).origin - skel.get_bone_global_rest(pb).origin).normalized()
			var l := skel.get_bone_global_rest(lb).origin - skel.get_bone_global_rest(rb).origin; l = (l - up * l.dot(up)).normalized()
			var f := l.cross(up).normalized()
			down = -up; fwd = f; lat = l
			var fm := (xf.basis * f); model.rotation.y = atan2(fm.z, fm.x)
		# scale to a person's height, measured on the skeleton (head to toe, in model space)
		var head := skel.find_bone("Bip01 Head"); var toe := skel.find_bone("Bip01 L Toe0")
		var hgt := 1.8
		if head >= 0 and toe >= 0:
			hgt = absf((xf * skel.get_bone_global_rest(head).origin).y - (xf * skel.get_bone_global_rest(toe).origin).y) * 1.08
		model.scale = Vector3.ONE * (H / maxf(0.01, hgt))
		var foot := (xf * skel.get_bone_global_rest(toe).origin).y if toe >= 0 else 0.0
		model.position.y = -foot * model.scale.y
		_bind(model)   # newer Godot can leave the body unbound from its bones; tie it back
		for nm in WB: bones[nm] = skel.find_bone("Bip01 " + nm)
		_dress_skin(model)
		for s in ["L", "R"]:
			var ua: int = bones[s + " UpperArm"]; var fa: int = bones[s + " Forearm"]
			if ua < 0 or fa < 0: continue
			var d0 := (skel.get_bone_global_rest(fa).origin - skel.get_bone_global_rest(ua).origin).normalized()
			var side := -1.0 if s == "L" else 1.0
			var want := (down + (inv * Vector3(0, 0, side * 0.13)).normalized() * 0.13).normalized()
			lower[s] = Quaternion(d0, want)
			var pel: int = bones.get("Pelvis", -1)
			var so := skel.get_bone_global_rest(ua).origin.dot(lat) - (skel.get_bone_global_rest(pel).origin.dot(lat) if pel >= 0 else 0.0)
			outward[s] = lat * signf(so)
		var key := scene.resource_path
		if not _walk_tables.has(key): _walk_tables[key] = _make_table()
		wt = _walk_tables[key]

	func _bind(n: Node) -> void:
		if n is MeshInstance3D and (n as MeshInstance3D).skin != null:
			(n as MeshInstance3D).skeleton = (n as MeshInstance3D).get_path_to(skel)
		for c in n.get_children(): _bind(c)

	static var _dressed := {}
	func _dress_skin(n: Node) -> void:   # skin a little soft, cloth matt, faces with light under the skin on computers
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			for k in mi.get_surface_override_material_count():
				var m = mi.get_active_material(k)
				if m is BaseMaterial3D and not _dressed.has(m.get_instance_id()):
					_dressed[m.get_instance_id()] = true
					m.roughness = maxf(m.roughness, 0.62); m.metallic = 0.0
					if String(m.resource_name).ends_with("_head") and RenderingServer.get_rendering_device() != null:
						m.subsurf_scatter_enabled = true; m.subsurf_scatter_strength = 0.25; m.roughness = 0.5
		for c in n.get_children(): _dress_skin(c)

	func _make_table() -> Dictionary:
		var idx := []
		for nm in WB: idx.append(bones[nm])
		var grab := func() -> Array:
			var out := []
			for b: int in idx: out.append(skel.get_bone_pose_rotation(b) if b >= 0 else Quaternion.IDENTITY)
			return out
		_walk_raw(0.0, 0.0); var stand: Array = grab.call()
		var steps := []
		for k in WN: _walk_raw(k * TAU / WN, 1.0); steps.append(grab.call())
		_walk_raw(0.0, 0.0)
		return { "idx": idx, "stand": stand, "step": steps }

	static func _find_skel(n: Node) -> Skeleton3D:
		if n is Skeleton3D: return n
		for c in n.get_children():
			var s := _find_skel(c)
			if s: return s
		return null

	# A small bone chain of our own (rest pose plus what we set), so a bone set a moment ago is seen where it is
	var _loc := {}
	var _glob := {}
	func _fk_reset() -> void:
		_loc.clear(); _glob.clear()

	func _g(b: int) -> Transform3D:
		if b < 0: return Transform3D.IDENTITY
		if _glob.has(b): return _glob[b]
		var t: Transform3D = _g(skel.get_bone_parent(b)) * (_loc[b] if _loc.has(b) else skel.get_bone_rest(b))
		_glob[b] = t
		return t

	func _set_global(b: int, g: Transform3D) -> void:
		var pg := _g(skel.get_bone_parent(b)); var rest := skel.get_bone_rest(b)
		var q := (pg.affine_inverse() * g).basis.orthonormalized().get_rotation_quaternion()
		_loc[b] = Transform3D(Basis(q), rest.origin); _glob[b] = pg * _loc[b]
		skel.set_bone_pose_rotation(b, q); skel.set_bone_pose_position(b, rest.origin)

	func _rot(g: Transform3D, axis: Vector3, ang: float) -> Transform3D:
		return Transform3D(Basis(axis, ang) * g.basis, g.origin)

	## ph: step phase; amp: 0 standing .. 1 walking. Reads the table made at load; cheap.
	func walk(ph: float, amp: float) -> void:
		if skel == null or wt == null: return
		var f := fposmod(ph, TAU) / TAU * WN; var k0 := int(f) % WN; var k1 := (k0 + 1) % WN; var u: float = f - floorf(f)
		bob = absf(cos(ph)) * 0.035 * clampf(amp, 0, 1)
		var idx: Array = wt.idx; var a0: Array = wt.step[k0]; var a1: Array = wt.step[k1]; var st: Array = wt.stand
		for i in idx.size():
			var b: int = idx[i]
			if b < 0: continue
			var q: Quaternion = (a0[i] as Quaternion).slerp(a1[i], u)
			if amp < 0.999: q = (st[i] as Quaternion).slerp(q, clampf(amp, 0, 1))
			skel.set_bone_pose_rotation(b, q)
		if amp < 0.3:   # standing: the chest rises and falls a little
			var sp: int = idx[9]
			if sp >= 0:
				var t := Time.get_ticks_msec() * 0.001 + phase * 0.37
				var la: Vector3 = (_g_rest_basis(sp).inverse() * lat).normalized()
				skel.set_bone_pose_rotation(sp, (st[9] as Quaternion) * Quaternion(la, sin(t * 1.6) * 0.025 * (1.0 - amp / 0.3)))

	func _g_rest_basis(b: int) -> Basis:
		return skel.get_bone_global_rest(b).basis

	func _walk_raw(ph: float, amp: float) -> void:
		if skel == null: return
		for nm in WB:   # start each sample from the rest pose
			var bb: int = bones.get(nm, -1)
			if bb >= 0: skel.set_bone_pose_rotation(bb, skel.get_bone_rest(bb).basis.get_rotation_quaternion()); skel.set_bone_pose_position(bb, skel.get_bone_rest(bb).origin)
		_fk_reset()
		# the body first: hips turn with the stride, the chest turns back, the head keeps looking ahead
		var sw0 := sin(ph)
		_turn("Pelvis", down, sw0 * 0.12 * amp); _turn("Spine1", down, -sw0 * 0.17 * amp); _turn("Head", down, sw0 * 0.05 * amp)
		for k in 2:
			var s := "L" if k == 0 else "R"
			var sw := sin(ph + k * PI)
			var th: int = bones[s + " Thigh"]; var ca: int = bones[s + " Calf"]
			if th >= 0:
				_set_global(th, _rot(_g(th), lat, -sw * 0.55 * amp))
				if ca >= 0: _set_global(ca, _rot(_g(ca), lat, maxf(0, sin(ph + k * PI + 1.0)) * 0.85 * amp))
			var ua: int = bones[s + " UpperArm"]; var fa: int = bones[s + " Forearm"]
			if ua >= 0 and fa >= 0:
				var g := _g(ua)
				var dir := ((g * skel.get_bone_rest(fa)).origin - g.origin).normalized()
				var want: Vector3 = (down + outward[s] * 0.12).normalized()
				_set_global(ua, Transform3D(Basis(lat, sw * 0.45 * amp) * Basis(Quaternion(dir, want)) * g.basis, g.origin))
				_set_global(fa, _hang(s, _g(fa), 0.15 + 0.3 * amp * (0.6 + 0.4 * maxf(0, sw))))
				_wrist(s, fa)
		for k in 2:   # relaxed hands with curled fingers
			var s := "L" if k == 0 else "R"
			for fn in ["1", "2", "3", "4"]:
				_local(s + " Finger" + fn, -0.35); _local(s + " Finger" + fn + "1", -0.55)
			_local(s + " Finger0", -0.2)

	## A forearm pointing down and a little forward (bend radians), whatever the rest pose had.
	func _hang(s: String, fg: Transform3D, bend: float) -> Transform3D:
		var hb: int = bones.get(s + " Hand", -1)
		if hb < 0: return fg
		var dir := ((fg * skel.get_bone_rest(hb)).origin - fg.origin).normalized()
		var want := (down * cos(bend) + fwd * sin(bend)).normalized()
		return Transform3D(Basis(Quaternion(dir, want)) * fg.basis, fg.origin)

	## The hand in line with the forearm, the thumb forward, so the palm faces the thigh.
	func _wrist(s: String, fa: int) -> void:
		var hb: int = bones.get(s + " Hand", -1); var f2: int = bones.get(s + " Finger2", -1); var f0: int = bones.get(s + " Finger0", -1)
		if hb < 0 or f2 < 0 or f0 < 0: return
		var fg := skel.get_bone_global_pose(fa); var hg := fg * skel.get_bone_rest(hb)
		var axis := (hg.origin - fg.origin).normalized()
		var dh := ((hg * skel.get_bone_rest(f2)).origin - hg.origin).normalized()
		hg.basis = Basis(Quaternion(dh, axis)) * hg.basis
		var tv := (hg * skel.get_bone_rest(f0)).origin - hg.origin; tv = (tv - axis * tv.dot(axis)).normalized()
		var want := (fwd - axis * fwd.dot(axis)).normalized()
		if tv.length() > 0.5 and want.length() > 0.5: hg.basis = Basis(Quaternion(tv, want)) * hg.basis
		_set_global(hb, hg)

	func _turn(nm: String, axis: Vector3, ang: float) -> void:   # rotate a bone about a body axis, keeping its place
		var b: int = bones.get(nm, -1)
		if b < 0 or absf(ang) < 0.0001: return
		_set_global(b, _rot(skel.get_bone_global_pose(b), axis, ang))

	func _local(nm: String, ang: float) -> void:   # bend a finger joint about its own z axis
		var b: int = bones.get(nm, -1)
		if b < 0: return
		skel.set_bone_pose_rotation(b, skel.get_bone_rest(b).basis.get_rotation_quaternion() * Quaternion(Vector3(0, 0, 1), ang))

	## b: beats; style 0..3 picks the arm move; returns how far the body drops on the bounce (Godot units)
	func dance(b: float, style: int, amp := 1.0) -> float:
		if skel == null: return 0.0
		_fk_reset()
		var bounce := (0.5 - 0.5 * cos(b * TAU)) * amp
		for k in 2:
			var s := "L" if k == 0 else "R"
			var th: int = bones[s + " Thigh"]; var ca: int = bones[s + " Calf"]
			var side := sin(b * PI + k * PI) * 0.12 * amp   # a step from foot to foot
			if th >= 0:
				var tg := _rot(skel.get_bone_global_rest(th), lat, -(bounce * 0.42 + maxf(0, side)))
				_set_global(th, tg)
				if ca >= 0: _set_global(ca, _rot(tg * skel.get_bone_rest(ca), lat, bounce * 0.8 + maxf(0, side) * 1.4))
			var ua: int = bones[s + " UpperArm"]; var fa: int = bones[s + " Forearm"]
			if ua < 0 or not lower.has(s): continue
			var g := skel.get_bone_global_rest(ua); var up := 0.0; var bend := -0.9
			match style:
				0: up = -(0.5 + 0.7 * bounce)                                  # both arms pump forward
				1: up = sin(b * PI + k * PI) * 0.9; bend = -1.3                 # arms swing in turn
				2: up = -(1.6 + 0.9 * bounce) if k == int(b / 2) % 2 else -0.3; bend = -0.3   # one hand up, every other bar
				_: up = -0.3 - 0.35 * bounce; bend = -1.6 - 0.3 * bounce        # small boxer steps
			var ug := Transform3D(Basis(lat, up * amp) * Basis(lower[s]) * g.basis, g.origin)
			_set_global(ua, ug)
			if fa >= 0: _set_global(fa, _rot(ug * skel.get_bone_rest(fa), lat, bend * amp))
		return bounce * 0.07

# --------------------------------------------------------------------- pedestrians ----------
class Ped:
	var i := 0
	var j := 0
	var t := 0.0
	var dir := 1
	var sp := 40.0
	var x := 0.0
	var y := 0.0
	var a := 0.0
	var down := 0.0
	var panic_t := 0.0
	var cross := {}
	var free_life := 0.0     # a driver who ran from a stolen car
	var av: Avatar

static func loop_pos(i: int, j: int, t: float) -> Vector2:
	var ox := i * CELL + 131.0; var oy := j * CELL + 131.0
	var s := int(floor(t / 378.0)); var u := t - s * 378
	var px: float = [u, 378.0, 378.0 - u, 0.0][s % 4]
	var py: float = [0.0, u, 378.0, 378.0 - u][s % 4]
	return Vector2(ox + px, oy + py)

static func start_cross(p: Ped, k: int) -> void:   # from block corner k, over the zebra to the facing corner of the next block
	var east := k == 1 or k == 2; var south := k >= 2
	var c0 := loop_pos(p.i, p.j, (k % 4) * 378.0); var horiz := randf() < 0.5
	var ni := p.i; var nj := p.j; var nk := 0
	if horiz:
		ni = p.i + (1 if east else -1); nk = (0 if k == 1 else 3) if east else (1 if k == 0 else 2)
	else:
		nj = p.j + (1 if south else -1); nk = (1 if k == 2 else 0) if south else (3 if k == 0 else 2)
	if ni < 0 or nj < 0 or ni >= 7 or nj >= 7: return
	var c1 := loop_pos(ni, nj, nk * 378.0)
	p.t = (k % 4) * 378.0; p.x = c0.x; p.y = c0.y; p.a = atan2(c1.y - c0.y, c1.x - c0.x)
	p.cross = { "x1": c1.x, "y1": c1.y, "i": ni, "j": nj, "k": nk, "I": p.i + 1 if east else p.i, "J": p.j + 1 if south else p.j, "d": 1 if horiz else 0, "wait": true, "wait_t": 0.0 }

static func step(p: Ped, world, dt: float) -> void:
	if p.panic_t > 0: p.panic_t -= dt
	var run := 2.8 if p.panic_t > 0 else 1.0
	if not p.cross.is_empty():
		var cr := p.cross
		if cr.wait:
			cr.wait_t += dt
			if world.light_at(cr.I, cr.J, cr.d) == "r" or cr.wait_t > 24: cr.wait = false
			return
		var d := Vector2(cr.x1 - p.x, cr.y1 - p.y); var L := d.length(); var st := p.sp * 1.25 * run * dt
		p.a = atan2(d.y, d.x)
		if L <= st:
			p.i = cr.i; p.j = cr.j; p.t = fposmod(cr.k * 378.0 + p.dir * 0.5, 1512.0); p.cross = {}
		else: p.x += d.x / L * st; p.y += d.y / L * st
		return
	var s0 := int(floor(p.t / 378.0))
	p.t = fposmod(p.t + p.dir * p.sp * run * dt, 1512.0)
	var s1 := int(floor(p.t / 378.0))
	if s1 != s0 and run == 1.0 and randf() < 0.45:
		start_cross(p, s1 if p.dir > 0 else s0)
		if not p.cross.is_empty(): return
	var q := loop_pos(p.i, p.j, p.t); p.x = q.x; p.y = q.y
	p.a = floor(p.t / 378.0) * PI / 2 + (PI if p.dir < 0 else 0.0)

static func panic(p: Ped, from: Vector2) -> void:   # run away from a fast car or a car-jacking
	if p.down > 0: return
	p.panic_t = 2.2
	if p.cross.is_empty():
		var fa := loop_pos(p.i, p.j, fposmod(p.t + 6, 1512.0)); var fb := loop_pos(p.i, p.j, fposmod(p.t - 6, 1512.0))
		p.dir = 1 if fa.distance_to(from) > fb.distance_to(from) else -1
	elif p.cross.wait: p.cross.wait = false
