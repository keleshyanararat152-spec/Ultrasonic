extends RefCounted
## 3D windows, balconies and shop fronts (made in Blender: tools/blender/facade_parts.py) set out on every
## building in rows and floors. One multimesh per part per block, so the blocks out of view are skipped.
## At night some windows are lit: each glass pane carries a random room in its instance data.

const S := 0.1
const COL := 3.2          # window spacing along a wall, Godot units (about metres)
const FLOOR := 3.2        # storey height
const AWNINGS := [Color("b8333f"), Color("2f6b5a"), Color("c99a2e"), Color("3d5a8c"), Color("7a3b6a"), Color("d0d0c8")]

var glass_mat: ShaderMaterial

static func _mesh(path: String) -> ArrayMesh:
	var root: Node = load(path).instantiate()
	var found: ArrayMesh = null
	var stack := [root]
	while stack.size():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and found == null: found = (n as MeshInstance3D).mesh
		stack.append_array(n.get_children())
	root.free()
	return found

## Give each surface its material by the name it had in Blender.
func _dress(mesh: ArrayMesh, mats: Dictionary) -> void:
	for k in mesh.get_surface_count():
		var m := mesh.surface_get_material(k)
		var nm := m.resource_name if m else ""
		if mats.has(nm): mesh.surface_set_material(k, mats[nm])

func build(city) -> void:
	glass_mat = ShaderMaterial.new(); glass_mat.shader = load("res://shaders/window_glass.gdshader")
	var frame := StandardMaterial3D.new(); frame.albedo_color = Color(0.93, 0.9, 0.85); frame.roughness = 0.5
	var trim := StandardMaterial3D.new(); trim.albedo_color = Color(0.86, 0.8, 0.74); trim.roughness = 0.85
	var iron := StandardMaterial3D.new(); iron.albedo_color = Color(0.1, 0.1, 0.11); iron.roughness = 0.4; iron.metallic = 0.8
	var shop_frame := StandardMaterial3D.new(); shop_frame.albedo_color = Color(0.16, 0.16, 0.17); shop_frame.roughness = 0.4; shop_frame.metallic = 0.6
	var awning := StandardMaterial3D.new(); awning.vertex_color_use_as_albedo = true; awning.vertex_color_is_srgb = true; awning.roughness = 0.85
	var win := _mesh("res://assets/facade/window.glb"); _dress(win, { "frame": frame, "glass": glass_mat, "trim": trim })
	var bal := _mesh("res://assets/facade/balcony.glb"); _dress(bal, { "trim": trim, "iron": iron })
	var shop := _mesh("res://assets/facade/shop.glb"); _dress(shop, { "frame": shop_frame, "glass": glass_mat, "awning": awning })
	var rng := RandomNumberGenerator.new(); rng.seed = 90210
	var gy: float = city.CURB * S
	for i in city.N:
		for j in city.N:
			var b: Dictionary = city.blocks[i][j]
			if b.type != "b": continue
			var wins := []; var bals := []; var shops := []; var shop_cols := []
			var bx0: float = (i * city.CELL + 142) * S; var bz0: float = (j * city.CELL + 142) * S; var bx1 := bx0 + 35.6; var bz1 := bz0 + 35.6
			for r in b.rects:
				var f: float = [1.0, 0.77, 0.62, 0.85][int(r.z) % 4]
				var H: float = city.FULL * f * S
				var x0: float = r.x * S; var z0: float = r.y * S; var w: float = r.w * S; var d: float = r.h * S
				var balc := rng.randf() < 0.6; var awn: Color = AWNINGS[rng.randi() % AWNINGS.size()]
				# the four walls: middle, outward normal, length, does it face a street
				for face in [[Vector3(x0 + w / 2, 0, z0), Vector3(0, 0, -1), w, z0 - bz0 < 3], [Vector3(x0 + w / 2, 0, z0 + d), Vector3(0, 0, 1), w, bz1 - (z0 + d) < 3],
						[Vector3(x0, 0, z0 + d / 2), Vector3(-1, 0, 0), d, x0 - bx0 < 3], [Vector3(x0 + w, 0, z0 + d / 2), Vector3(1, 0, 0), d, bx1 - (x0 + w) < 3]]:
					var nrm: Vector3 = face[1]; var L: float = face[2]; var street: bool = face[3]
					var along := Vector3.UP.cross(nrm)
					var p0: Vector3 = face[0] - along * (L / 2)
					var basis := Basis(along, Vector3.UP, nrm)   # the part's +x along the wall, +z out of it
					var n := int(floor((L - 1.6) / COL))
					if n < 1: continue
					var start := (L - (n - 1) * COL) / 2
					for c in n:
						var p := p0 + along * (start + c * COL)
						if street:   # a shop front on the ground floor
							shops.append(Transform3D(basis, p + Vector3(0, gy + 1.75, 0) + nrm * 0.01)); shop_cols.append(awn)
						var k := 1
						while true:
							var y := gy + 0.9 + k * FLOOR + 1.0
							if y + 1.4 > H - 1.2: break
							wins.append(Transform3D(basis, p + Vector3(0, y, 0) + nrm * 0.01))
							if balc and street and k >= 2 and c % 2 == 1: bals.append(Transform3D(basis, p + Vector3(0, y, 0) + nrm * 0.01))
							k += 1
						if not street:   # a plain window down below too
							wins.append(Transform3D(basis, p + Vector3(0, gy + 1.9, 0) + nrm * 0.01))
			_multi(city, win, wins, false, rng)
			_multi(city, bal, bals, true, null)
			_multi(city, shop, shops, false, rng, shop_cols)

func _multi(city, mesh: Mesh, xforms: Array, shadows: bool, rng, cols := []) -> void:
	if xforms.is_empty(): return
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = rng != null; mm.use_colors = cols.size() > 0
	mm.mesh = mesh; mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
		if rng != null: mm.set_instance_custom_data(k, Color(rng.randf(), rng.randf(), 0, 0))
		if cols.size(): mm.set_instance_color(k, cols[k])
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 700.0; mi.visibility_range_end_margin = 60.0; mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	city.add_child(mi)
