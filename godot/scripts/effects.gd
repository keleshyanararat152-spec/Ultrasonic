extends Node3D
## Car effects: tyre smoke and black skid marks when the wheels slide, sparks where metal hits, a puff of
## exhaust, smoke from a battered bonnet, and a speed blur at the edges of the screen when driving fast.

var m                          # main
var smoke: Array = []          # one smoke emitter per rear wheel
var exhaust: GPUParticles3D
var sparks: GPUParticles3D
var hood: GPUParticles3D       # smoke from a damaged engine
var marks: MultiMesh           # skid marks: a ring of dark strips laid on the road
var mark_k := 0
const MARKS := 900
var last := [Vector3.INF, Vector3.INF]
var blur: ShaderMaterial
var blur_k := 0.0
var blur_rect: ColorRect

func setup(main) -> void:
	m = main
	for k in 2:
		var p := _emitter(160, 1.6, _puff_mat(Color(0.82, 0.82, 0.84, 0.5)), 0.7)
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 1, 0); pm.spread = 60; pm.initial_velocity_min = 0.6; pm.initial_velocity_max = 2.2
		pm.gravity = Vector3(0, 0.6, 0); pm.damping_min = 1.0; pm.damping_max = 2.0
		pm.scale_min = 0.6; pm.scale_max = 1.3; pm.scale_curve = _grow(); pm.color_ramp = _fade(0.55)
		p.process_material = pm; smoke.append(p)
	exhaust = _emitter(40, 0.9, _puff_mat(Color(0.6, 0.6, 0.62, 0.22)), 0.25)
	var em := ParticleProcessMaterial.new()
	em.direction = Vector3(-1, 0.2, 0); em.spread = 12; em.initial_velocity_min = 1.0; em.initial_velocity_max = 2.0
	em.gravity = Vector3(0, 0.3, 0); em.scale_curve = _grow(); em.color_ramp = _fade(0.4)
	exhaust.process_material = em
	hood = _emitter(70, 2.2, _puff_mat(Color(0.25, 0.25, 0.27, 0.55)), 0.8)
	var hm := ParticleProcessMaterial.new()
	hm.direction = Vector3(0, 1, 0); hm.spread = 20; hm.initial_velocity_min = 0.8; hm.initial_velocity_max = 1.6
	hm.gravity = Vector3(0, 0.5, 0); hm.scale_curve = _grow(); hm.color_ramp = _fade(0.6)
	hood.process_material = hm
	# sparks: short glowing streaks thrown out and falling
	sparks = GPUParticles3D.new(); sparks.amount = 90; sparks.lifetime = 0.55; sparks.one_shot = true; sparks.explosiveness = 0.95
	sparks.local_coords = false; sparks.emitting = false
	var sm := ParticleProcessMaterial.new()
	sm.direction = Vector3(0, 1, 0); sm.spread = 80; sm.initial_velocity_min = 3.0; sm.initial_velocity_max = 8.0; sm.gravity = Vector3(0, -12, 0)
	sm.particle_flag_align_y = true; sm.scale_min = 0.6; sm.scale_max = 1.2
	sparks.process_material = sm
	var q := QuadMesh.new(); q.size = Vector2(0.025, 0.16)
	var qm := StandardMaterial3D.new(); qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; qm.albedo_color = Color(3.0, 1.6, 0.5)
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y; q.material = qm; sparks.draw_pass_1 = q
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; sparks.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
	add_child(sparks)
	# skid marks
	marks = MultiMesh.new(); marks.transform_format = MultiMesh.TRANSFORM_3D; marks.use_colors = true
	var strip := QuadMesh.new(); strip.size = Vector2(1, 1); strip.orientation = PlaneMesh.FACE_Y
	marks.mesh = strip; marks.instance_count = MARKS
	for k in MARKS: marks.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	var mi := MultiMeshInstance3D.new(); mi.multimesh = marks; mi.material_override = _mark_mat(); mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-50, -5, -50), Vector3(500, 20, 500))
	add_child(mi)
	if m.hi:   # the speed blur
		var layer := CanvasLayer.new(); layer.layer = 0; add_child(layer)
		var r := ColorRect.new(); r.set_anchors_preset(Control.PRESET_FULL_RECT); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blur = ShaderMaterial.new(); blur.shader = load("res://shaders/speed_blur.gdshader"); r.material = blur; r.visible = false; blur_rect = r
		layer.add_child(r)

func _mark_mat() -> StandardMaterial3D:
	var mm := StandardMaterial3D.new(); mm.albedo_color = Color(0.03, 0.03, 0.03, 1); mm.vertex_color_use_as_albedo = true
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mm.roughness = 0.7; mm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return mm

func _emitter(n: int, life: float, mat: Material, size: float) -> GPUParticles3D:
	var p := GPUParticles3D.new(); p.amount = n; p.lifetime = life; p.local_coords = false; p.emitting = false
	var q := QuadMesh.new(); q.size = Vector2(size, size); q.material = mat; p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; p.visibility_aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 20, 40))
	add_child(p)
	return p

var _puff_tex: Texture2D
func _puff_mat(c: Color) -> StandardMaterial3D:
	if _puff_tex == null:   # a soft round puff
		var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill = GradientTexture2D.FILL_RADIAL; gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64; gt.height = 64; _puff_tex = gt
	var mt := StandardMaterial3D.new(); mt.albedo_texture = _puff_tex; mt.albedo_color = c; mt.vertex_color_use_as_albedo = true
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mt.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.disable_receive_shadows = true
	return mt

func _grow() -> CurveTexture:
	var c := Curve.new(); c.add_point(Vector2(0, 0.4)); c.add_point(Vector2(1, 2.6))
	var t := CurveTexture.new(); t.curve = c; return t

func _fade(a0: float) -> GradientTexture1D:
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, a0)); g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture1D.new(); t.gradient = g; return t

## A shower of sparks where a car scraped or hit something (game units).
func spark(at: Vector2, strength: float) -> void:
	if at == Vector2.INF: return
	sparks.global_position = Vector3(at.x, m.city.ground_y(at.x, at.y) + 5, at.y) * m.S
	sparks.amount_ratio = clampf(strength, 0.2, 1.0); sparks.restart(); sparks.emitting = true

func tick(dt: float) -> void:
	var c: Car = m.pcar
	for p in smoke: p.emitting = false
	exhaust.emitting = false; hood.emitting = false
	if blur: blur_k += ((clampf((absf(c.v) - 220) / 260.0, 0, 1) if c else 0.0) - blur_k) * minf(1, dt * 3)
	if blur: blur.set_shader_parameter("amount", blur_k); blur_rect.visible = blur_k > 0.01
	if c == null or m.interior.inside != "":
		last = [Vector3.INF, Vector3.INF]; return
	var f := Vector3(cos(c.a), 0, sin(c.a)); var r := Vector3(-sin(c.a), 0, cos(c.a))
	var base: Vector3 = Vector3(c.x, m.city.ground_y(c.x, c.y), c.y) * m.S
	var slide: bool = absf(c.lat) > 55 or (c.hand and absf(c.v) > 60) or (m.touch_ui.read_input().thr > 0.5 and c.v < 60 and c.v > 2)
	for k in 2:
		var wp: Vector3 = base - f * 1.45 + r * (0.78 if k == 0 else -0.78)
		var p: GPUParticles3D = smoke[k]; p.global_position = wp + Vector3(0, 0.2, 0); p.emitting = slide
		if slide:
			if last[k] != Vector3.INF and last[k].distance_to(wp) > 0.25: _lay(last[k], wp); last[k] = wp
			elif last[k] == Vector3.INF: last[k] = wp
		else: last[k] = Vector3.INF
	exhaust.emitting = absf(c.v) < 200
	exhaust.global_position = base - f * 2.35 + r * 0.45 + Vector3(0, 0.35, 0)
	exhaust.rotation.y = -c.a
	if c.dmg >= 4:   # a battered car smokes from under the bonnet, darker the worse it is
		hood.emitting = true; hood.global_position = base + f * 1.5 + Vector3(0, 1.0, 0)
		hood.amount_ratio = clampf((c.dmg - 3) / 6.0, 0.2, 1.0)
		var q: QuadMesh = hood.draw_pass_1; (q.material as StandardMaterial3D).albedo_color = Color(0.55, 0.55, 0.57, 0.5).lerp(Color(0.12, 0.12, 0.13, 0.7), clampf((c.dmg - 4) / 6.0, 0, 1))

func _lay(a: Vector3, b: Vector3) -> void:   # one strip of rubber from a to b
	var d := b - a; d.y = 0; var L := d.length()
	if L < 0.01 or L > 3.0: return
	var ang := atan2(-d.z, d.x)
	var xf := Transform3D(Basis(Vector3.UP, ang) * Basis.from_scale(Vector3(L + 0.05, 1, 0.24)), (a + b) / 2 + Vector3(0, 0.025, 0))
	marks.set_instance_transform(mark_k, xf); marks.set_instance_color(mark_k, Color(0.02, 0.02, 0.02, 0.55))
	mark_k = (mark_k + 1) % MARKS

# ------------------------------------------------------------------ heavy damage ----------
var _crack_tex: ImageTexture
var glass_burst: GPUParticles3D

## A spider-web of cracks drawn once: white lines out from a few impact points.
func _cracks() -> ImageTexture:
	if _crack_tex: return _crack_tex
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8); img.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new(); rng.seed = 77
	for hit in 3:
		var c := Vector2(rng.randf_range(50, 206), rng.randf_range(50, 206))
		for k in 14:
			var a := k * TAU / 14 + rng.randf_range(-0.2, 0.2); var p := c
			for s in 40:
				a += rng.randf_range(-0.25, 0.25); p += Vector2.from_angle(a) * 3.0
				if p.x < 0 or p.y < 0 or p.x > 255 or p.y > 255: break
				img.set_pixelv(Vector2i(p), Color(1, 1, 1, 0.85))
		for ring in [10.0, 22.0, 38.0]:
			for k in 60:
				var p: Vector2 = c + Vector2.from_angle(k * TAU / 60) * ring * rng.randf_range(0.85, 1.15)
				if p.x >= 0 and p.y >= 0 and p.x < 256 and p.y < 256: img.set_pixelv(Vector2i(p), Color(1, 1, 1, 0.7))
	_crack_tex = ImageTexture.create_from_image(img)
	return _crack_tex

## Called after each hit on your car: past a few hits the glass cracks, after many it is gone, in a shower of bits.
func damage_look(c: Car) -> void:
	if c == null or c.node == null: return
	var stage := 2 if c.dmg >= 9 else (1 if c.dmg >= 4 else 0)
	if stage <= int(c.anim.get("glass", 0)): return
	c.anim.glass = stage
	var stack := [c.node]
	while stack.size():
		var n: Node = stack.pop_back(); stack.append_array(n.get_children())
		if not (n is MeshInstance3D): continue
		var mi := n as MeshInstance3D
		for k in mi.get_surface_override_material_count():
			var mt = mi.get_active_material(k)
			if not (mt is BaseMaterial3D): continue
			var nm := String(mt.resource_name).to_lower()
			if not (nm.contains("glass") or nm.contains("window")) or nm.contains("police_glass_"): continue
			if stage == 1:
				var cr: BaseMaterial3D = mt.duplicate(); cr.albedo_texture = _cracks(); cr.albedo_color = Color(0.75, 0.78, 0.8, 0.75)
				cr.roughness = 0.35; cr.uv1_triplanar = true; cr.uv1_scale = Vector3(0.9, 0.9, 0.9); cr.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mi.set_surface_override_material(k, cr)
			else:
				var gone := StandardMaterial3D.new(); gone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gone.albedo_color = Color(0, 0, 0, 0)
				mi.set_surface_override_material(k, gone)
	if glass_burst == null:
		glass_burst = GPUParticles3D.new(); glass_burst.amount = 120; glass_burst.lifetime = 1.2; glass_burst.one_shot = true; glass_burst.explosiveness = 1.0
		glass_burst.local_coords = false
		var pm := ParticleProcessMaterial.new(); pm.direction = Vector3(0, 1, 0); pm.spread = 75; pm.initial_velocity_min = 2; pm.initial_velocity_max = 5
		pm.gravity = Vector3(0, -9.8, 0); pm.angular_velocity_min = -500; pm.angular_velocity_max = 500; pm.scale_min = 0.4; pm.scale_max = 1.0
		glass_burst.process_material = pm
		var q := BoxMesh.new(); q.size = Vector3(0.04, 0.005, 0.03)
		var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.8, 0.9, 0.95); gm.metallic = 0.8; gm.roughness = 0.05; q.material = gm
		glass_burst.draw_pass_1 = q; glass_burst.visibility_aabb = AABB(Vector3(-10, -5, -10), Vector3(20, 15, 20)); add_child(glass_burst)
	glass_burst.global_position = c.node.global_position + Vector3(0, 1.1, 0); glass_burst.restart(); glass_burst.emitting = true
