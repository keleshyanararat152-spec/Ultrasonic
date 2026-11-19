# Street furniture for the game (assets/street/*.glb), each one mesh standing on its base at the origin, +x forward.
# Poly Haven models (CC0) trimmed and lightened: bench, bin, hydrant, street lamp, planter; and made here from
# scratch: a bus stop, a newspaper kiosk and a traffic light.
# usage: blender -b -P street_kit.py -- polyhaven_gltf_dir out_dir
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
os.makedirs(out, exist_ok=True)

def reset():
	bpy.ops.wm.read_factory_settings(use_empty=True)

def finish(name, objs, ratio=1.0, height=None, turn=0.0):
	bpy.ops.object.select_all(action='DESELECT')
	for o in objs: o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	if len(objs) > 1: bpy.ops.object.join()
	o = bpy.context.view_layer.objects.active
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	if ratio < 1.0:
		m = o.modifiers.new("dec", 'DECIMATE'); m.ratio = ratio
		bpy.ops.object.modifier_apply(modifier="dec")
	bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
	lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
	hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
	o.data.transform(Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))))
	if height: o.data.transform(Matrix.Scale(height / (hi.z - lo.z), 4))
	if turn: o.data.transform(Matrix.Rotation(turn, 4, 'Z'))
	o.location = (0, 0, 0); o.name = name
	for ob in list(bpy.data.objects):
		if ob != o: bpy.data.objects.remove(ob)
	tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
	bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + ".glb"), export_format='GLB', export_image_format='JPEG', export_jpeg_quality=82)
	print("KIT", name, "tris", tris, "size", [round(v, 2) for v in o.dimensions])

def poly(aid, keep, name, ratio=1.0, height=None, turn=0.0):
	reset()
	g = [f for f in os.listdir(os.path.join(src, aid)) if f.endswith(".gltf")][0]
	bpy.ops.import_scene.gltf(filepath=os.path.join(src, aid, g))
	objs = [o for o in bpy.data.objects if o.type == 'MESH' and keep(o.name)]
	for o in bpy.data.objects:
		if o.type != 'MESH': o.select_set(False)
	finish(name, objs, ratio, height, turn)

poly("painted_wooden_bench", lambda n: True, "bench", turn=-math.pi / 2)   # its seat faces +y
poly("metal_trash_can", lambda n: "rust" not in n, "bin", 0.35)
poly("fire_hydrant", lambda n: "aged" not in n, "hydrant", 0.06)
poly("street_lamp_01", lambda n: True, "lamp", 0.25)
poly("planter_box_01", lambda n: True, "planter", 0.3)

# ---------------------------------------------------------------- made here ----------
def mat(name, col, rough=0.5, metal=0.0, alpha=1.0, emit=None):
	m = bpy.data.materials.new(name); m.use_nodes = True
	b = m.node_tree.nodes["Principled BSDF"]
	b.inputs["Base Color"].default_value = (*col, 1); b.inputs["Roughness"].default_value = rough; b.inputs["Metallic"].default_value = metal
	if alpha < 1:
		b.inputs["Alpha"].default_value = alpha; m.blend_method = 'BLEND'
	if emit:
		b.inputs["Emission Color"].default_value = (*emit, 1); b.inputs["Emission Strength"].default_value = 1.0
	return m

def box(c, s, m, bevel=0.0):
	bpy.ops.mesh.primitive_cube_add(size=1, location=c)
	o = bpy.context.object; o.scale = s
	bpy.ops.object.transform_apply(scale=True)
	if bevel:
		md = o.modifiers.new("b", 'BEVEL'); md.width = bevel; md.segments = 2; bpy.ops.object.modifier_apply(modifier="b")
	o.data.materials.append(m)
	return o

def cyl(c, r, h, m, verts=12, rot=None):
	bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=c)
	o = bpy.context.object
	if rot: o.rotation_euler = rot; bpy.ops.object.transform_apply(rotation=True)
	o.data.materials.append(m)
	return o

# bus stop: 4 m long shelter, glass back and sides, a roof, a bench, a lit advert at one end. Open side faces +x.
reset()
steel = mat("steel", (0.18, 0.2, 0.22), 0.35, 0.8)
glass = mat("glass", (0.6, 0.7, 0.75), 0.05, 0.0, 0.25)
roof = mat("roof", (0.12, 0.13, 0.15), 0.4, 0.5)
wood = mat("bench_wood", (0.45, 0.28, 0.16), 0.6)
ad = mat("advert", (0.9, 0.35, 0.55), 0.3, 0.0, 1.0, (1.0, 0.55, 0.75))
o = []
for x in (-1.95, 1.95):
	for y in (-0.7, 0.65): o.append(box((y, x, 1.25), (0.07, 0.07, 2.5), steel))
o.append(box((-0.72, 0, 1.3), (0.02, 3.8, 2.1), glass))
for x in (-1.95, 1.95): o.append(box((0, x, 1.3), (1.3, 0.02, 2.1), glass))
o.append(box((-0.05, 0, 2.55), (1.75, 4.3, 0.1), roof, 0.02))
o.append(box((-0.4, -0.3, 0.46), (0.42, 2.6, 0.06), wood))
for x in (-1.4, 0.8): o.append(box((-0.4, x, 0.22), (0.35, 0.05, 0.44), steel))
o.append(box((-0.69, 1.4, 1.3), (0.06, 1.0, 1.6), ad))
o.append(box((-0.69, 1.4, 1.3), (0.08, 1.06, 1.66), steel))
o.append(cyl((0.75, -2.3, 1.4), 0.04, 2.8, steel))
o.append(box((0.75, -2.3, 2.75), (0.04, 0.5, 0.5), mat("sign", (0.1, 0.45, 0.25), 0.4)))
finish("busstop", o)

# kiosk: a small green booth with a window and counter on the front (+x), a striped awning and a sign board.
reset()
green = mat("kiosk_green", (0.13, 0.32, 0.24), 0.45, 0.3)
cream = mat("kiosk_cream", (0.88, 0.84, 0.74), 0.6)
glass2 = mat("kiosk_glass", (0.3, 0.38, 0.42), 0.05, 0.0, 0.5)
awn = mat("awning", (0.75, 0.2, 0.24), 0.7)
o = [box((0, 0, 1.2), (2.0, 2.4, 2.4), cream, 0.03), box((0, 0, 0.15), (2.06, 2.46, 0.3), green)]
o.append(box((1.0, 0, 1.45), (0.04, 1.9, 1.1), glass2))
o.append(box((1.18, 0, 0.92), (0.38, 2.1, 0.06), green))
o.append(box((0, 0, 2.5), (2.3, 2.7, 0.2), green, 0.02))
o.append(box((0, 0, 2.85), (0.12, 2.0, 0.5), green))
for k in range(5):
	bpy.ops.mesh.primitive_cube_add(size=1, location=(1.35, -1.0 + k * 0.5, 2.15))
	a = bpy.context.object; a.scale = (0.8, 0.48, 0.03); a.rotation_euler = (0, 0.42, 0)
	bpy.ops.object.transform_apply(scale=True, rotation=True); a.data.materials.append(awn if k % 2 == 0 else cream); o.append(a)
for y in (-0.9, 0.9): o.append(box((1.3, y, 0.55), (0.3, 0.5, 1.1), mat("rack", (0.25, 0.25, 0.28), 0.5, 0.6) if y < 0 else green))
finish("kiosk", o)

# traffic light: a pole and a housing with three lenses under visors, facing +x. The lenses are coloured in the game.
reset()
pole = mat("pole", (0.16, 0.17, 0.19), 0.45, 0.7)
house = mat("housing", (0.08, 0.085, 0.09), 0.5, 0.3)
o = [cyl((0, 0, 1.75), 0.06, 3.5, pole, 10), cyl((0, 0, 0.06), 0.12, 0.12, pole, 10)]
o.append(box((0.08, 0, 3.4), (0.26, 0.32, 0.95), house, 0.02))
for k in range(3):
	z = 3.72 - k * 0.31
	bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.135, depth=0.2, location=(0.3, 0, z + 0.02), rotation=(0, math.pi / 2, 0))
	v = bpy.context.object
	bm = bmesh.new(); bm.from_mesh(v.data)   # keep only the upper half of the tube: a visor
	for f in list(bm.faces):
		if f.calc_center_median().z < -0.02 or abs(f.normal.x) > 0.9: bm.faces.remove(f)
	bm.to_mesh(v.data); bm.free(); v.data.materials.append(house); o.append(v)
o.append(box((0.08, 0, 2.85), (0.1, 0.1, 0.2), pole))
finish("signal", o)
