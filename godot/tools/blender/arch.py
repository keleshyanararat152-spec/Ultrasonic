# arch.glb: a ground-floor stone arch for the facades (a deep frame round a round-headed opening with a keystone,
# glass and a door set back inside). Same conventions as facade_parts.py: faces -Y in Blender, origin at the
# middle of the ground-floor bay on the wall face, 1.75 m above the pavement.
# Run: blender -b -P tools/blender/arch.py -- <out_dir>
import bpy, sys, os, math
out = sys.argv[sys.argv.index("--") + 1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name, col, rough=0.6, metal=0.0):
	m = bpy.data.materials.new(name); m.use_nodes = True
	b = m.node_tree.nodes["Principled BSDF"]
	b.inputs["Base Color"].default_value = (*col, 1); b.inputs["Roughness"].default_value = rough; b.inputs["Metallic"].default_value = metal
	return m

stone = mat("stone", (0.85, 0.78, 0.7), 0.8); glass = mat("glass", (0.1, 0.12, 0.14), 0.05); frame = mat("frame", (0.15, 0.15, 0.16), 0.4, 0.6)
D = 0.5
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -D / 2, 0.15)); f = bpy.context.object; f.scale = (3.1, D, 3.8)
bpy.ops.object.transform_apply(scale=True)
# the opening: a box and a cylinder cut out together
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -D / 2, -0.55)); c1 = bpy.context.object; c1.scale = (2.0, D * 3, 2.7)
bpy.ops.object.transform_apply(scale=True)
bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=1.0, depth=D * 3, location=(0, -D / 2, 0.8), rotation=(math.pi / 2, 0, 0)); c2 = bpy.context.object
bpy.context.view_layer.objects.active = c1; c1.select_set(True); c2.select_set(True); bpy.ops.object.join()
md = f.modifiers.new("cut", 'BOOLEAN'); md.object = c1; md.operation = 'DIFFERENCE'
bpy.context.view_layer.objects.active = f; bpy.ops.object.modifier_apply(modifier="cut")
bpy.data.objects.remove(c1)
f.data.materials.append(stone)
parts = [f]
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -D - 0.04, 1.86)); k = bpy.context.object; k.scale = (0.34, 0.16, 0.42)
bpy.ops.object.transform_apply(scale=True); k.data.materials.append(stone); parts.append(k)
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -D - 0.05, 2.12)); cap = bpy.context.object; cap.scale = (3.3, 0.18, 0.16)
bpy.ops.object.transform_apply(scale=True); cap.data.materials.append(stone); parts.append(cap)
# set back inside: a shop window in a dark frame, its top round too
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.03, -0.55)); g = bpy.context.object; g.scale = (2.0, 0.02, 2.7)
bpy.ops.object.transform_apply(scale=True); g.data.materials.append(glass); parts.append(g)
bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=1.0, depth=0.02, location=(0, -0.03, 0.8), rotation=(math.pi / 2, 0, 0)); g2 = bpy.context.object
g2.data.materials.append(glass); parts.append(g2)
for x in (-0.35, 0.35):
	bpy.ops.mesh.primitive_cube_add(size=1, location=(x, -0.06, -0.2)); b = bpy.context.object; b.scale = (0.05, 0.04, 3.1)
	bpy.ops.object.transform_apply(scale=True); b.data.materials.append(frame); parts.append(b)
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.06, 0.8)); b = bpy.context.object; b.scale = (2.0, 0.04, 0.05)
bpy.ops.object.transform_apply(scale=True); b.data.materials.append(frame); parts.append(b)
bpy.ops.object.select_all(action='DESELECT')
for p in parts: p.select_set(True)
bpy.context.view_layer.objects.active = f; bpy.ops.object.join()
print("ARCH tris", sum(len(p.vertices) - 2 for p in f.data.polygons))
bpy.ops.export_scene.gltf(filepath=os.path.join(out, "arch.glb"), export_format='GLB')
