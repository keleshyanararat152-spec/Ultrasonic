# fountain.glb: the square's fountain: a round basin with a moulded rim, and a two-tier fountain in the middle.
# Materials: "stone" (pale tuff), "water" (the game puts a rippling water shader on it). Origin at the base centre.
# Run: blender -b -P tools/blender/fountain.py -- <out_dir>
import bpy, sys, os, math
out = sys.argv[sys.argv.index("--") + 1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name, col, rough):
	m = bpy.data.materials.new(name); m.use_nodes = True
	b = m.node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value = (*col, 1); b.inputs["Roughness"].default_value = rough
	return m
stone = mat("stone", (0.82, 0.72, 0.64), 0.75); water = mat("water", (0.2, 0.35, 0.4), 0.05)
parts = []
def lathe(profile, m, segs=48):   # profile: [(radius, height)], spun round z
	verts = []; faces = []
	for k in range(segs):
		a = 2 * math.pi * k / segs
		for (r, z) in profile: verts.append((r * math.cos(a), r * math.sin(a), z))
	n = len(profile)
	for k in range(segs):
		k2 = (k + 1) % segs
		for i in range(n - 1): faces.append((k * n + i, k2 * n + i, k2 * n + i + 1, k * n + i + 1))
	me = bpy.data.meshes.new("l"); me.from_pydata(verts, [], faces); me.update()
	o = bpy.data.objects.new("l", me); bpy.context.collection.objects.link(o); me.materials.append(m)
	bpy.context.view_layer.objects.active = o; o.select_set(True)
	bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
	parts.append(o); return o
# the basin: outer wall with a base moulding, a rounded rim, the inner wall down to the floor
lathe([(8.25, 0.0), (8.25, 0.12), (8.05, 0.2), (8.05, 0.55), (8.2, 0.62), (8.15, 0.72), (7.95, 0.76), (7.6, 0.76), (7.45, 0.7), (7.4, 0.62), (7.4, 0.15), (0.0, 0.15)], stone)
lathe([(7.42, 0.5), (0.0, 0.5)], water)
# the fountain: a fluted pedestal, a wide bowl, a slimmer stem, a small bowl and a finial
lathe([(1.3, 0.15), (1.3, 0.4), (0.9, 0.5), (0.55, 0.6), (0.45, 1.3), (0.6, 1.45), (2.4, 1.6), (2.6, 1.75), (2.45, 1.82), (0.4, 1.7), (0.3, 2.4), (0.45, 2.55),
	(1.25, 2.65), (1.35, 2.78), (1.2, 2.82), (0.25, 2.75), (0.18, 3.1), (0.3, 3.25), (0.12, 3.45), (0.0, 3.5)], stone)
lathe([(2.42, 1.78), (0.0, 1.78)], water, 32)
lathe([(1.2, 2.77), (0.0, 2.77)], water, 24)
bpy.ops.object.select_all(action='DESELECT')
for p in parts: p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]; bpy.ops.object.join()
bpy.ops.object.shade_smooth()
o = bpy.context.object
print("FOUNTAIN tris", sum(len(p.vertices) - 2 for p in o.data.polygons))
bpy.ops.export_scene.gltf(filepath=os.path.join(out, "fountain.glb"), export_format='GLB')

# a pigeon: body, head, beak, tail and two wings (vertex colour red = wing, green = how far out along the wing)
bpy.ops.wm.read_factory_settings(use_empty=True)
grey = mat("pigeon", (0.45, 0.47, 0.52), 0.7)
bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=0.12, location=(0, 0, 0.14)); body = bpy.context.object; body.scale = (1.5, 0.85, 0.85)
bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5, radius=0.06, location=(0.16, 0, 0.25)); head = bpy.context.object
bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.015, depth=0.05, location=(0.23, 0, 0.245), rotation=(0, math.pi / 2, 0)); beak = bpy.context.object
bpy.ops.mesh.primitive_cube_add(size=1, location=(-0.22, 0, 0.15)); tail = bpy.context.object; tail.scale = (0.14, 0.09, 0.015)
wings = []
for s in (-1, 1):
	bpy.ops.mesh.primitive_cube_add(size=1, location=(0.0, s * 0.2, 0.19)); w = bpy.context.object; w.scale = (0.16, 0.26, 0.012); wings.append(w)
for o in [body, head, beak, tail] + wings:
	bpy.context.view_layer.objects.active = o; o.select_set(True); bpy.ops.object.transform_apply(scale=True, rotation=True)
	o.data.materials.append(grey)
	col = o.data.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
	for i, v in enumerate(o.data.vertices):
		wing = o in wings
		col.data[i].color = (1.0 if wing else 0.0, min(1.0, abs(v.co.y) / 0.33) if wing else 0.0, 0.0, 1.0)
bpy.ops.object.select_all(action='DESELECT')
for o in [body, head, beak, tail] + wings: o.select_set(True)
bpy.context.view_layer.objects.active = body; bpy.ops.object.join()
bpy.ops.export_scene.gltf(filepath=os.path.join(out, "pigeon.glb"), export_format='GLB', export_colors=True)
print("PIGEON ok")
