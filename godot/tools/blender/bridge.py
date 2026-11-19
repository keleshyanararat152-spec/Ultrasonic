# bridge.glb: a stone bridge over the river, three round arches, a road deck and parapets with lamp posts.
# 40 m long along +X (from x = -20 to 20), 12 m wide; the road surface is at z = 0, the arches go down to z = -6.
# Materials: "stone" (pale tuff), "road" (asphalt, the game puts its own street material on it), "iron".
# Run: blender -b -P tools/blender/bridge.py -- <out_dir>
import bpy, sys, os, math
out = sys.argv[sys.argv.index("--") + 1]; os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name, col, rough, metal=0.0):
	m = bpy.data.materials.new(name); m.use_nodes = True
	b = m.node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value = (*col, 1); b.inputs["Roughness"].default_value = rough; b.inputs["Metallic"].default_value = metal
	return m
stone = mat("stone", (0.78, 0.66, 0.58), 0.85); road = mat("road", (0.2, 0.2, 0.21), 0.9); iron = mat("iron", (0.08, 0.08, 0.09), 0.4, 0.8)
def box(c, s, m):
	bpy.ops.mesh.primitive_cube_add(size=1, location=c); o = bpy.context.object; o.scale = s
	bpy.ops.object.transform_apply(scale=True); o.data.materials.append(m); return o
# the body: a solid wall of stone under the deck, with three arches cut through it
body = box((0, 0, -3.2), (40, 12, 6.0), stone)
for x in (-13, 0, 13):
	bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=5.2, depth=14, location=(x, 0, -6.2), rotation=(math.pi / 2, 0, 0)); c = bpy.context.object
	md = body.modifiers.new("arch", 'BOOLEAN'); md.object = c; md.operation = 'DIFFERENCE'
	bpy.context.view_layer.objects.active = body; bpy.ops.object.modifier_apply(modifier="arch"); bpy.data.objects.remove(c)
parts = [body, box((0, 0, -0.08), (40, 10.2, 0.16), road)]
for y in (-5.6, 5.6):   # parapets with a coping stone, posts with lanterns at the ends and middle
	parts.append(box((0, y, 0.5), (40, 0.6, 1.0), stone)); parts.append(box((0, y, 1.05), (40.4, 0.8, 0.12), stone))
	for x in (-19.5, 0, 19.5):
		parts.append(box((x, y, 0.9), (1.0, 1.0, 1.8), stone))
		parts.append(box((x, y, 2.6), (0.12, 0.12, 1.8), iron)); parts.append(box((x, y, 3.6), (0.36, 0.36, 0.45), iron))
	for x in range(-18, 19, 3): parts.append(box((x, y, -0.5), (0.5, 0.7, 0.5), stone))   # corbels under the cornice
for x in (-6.5, 6.5):   # cutwaters on the two piers, against the current
	for y in (-6.4, 6.4): parts.append(box((x, y, -4.5), (2.4, 1.0, 3.0), stone))
bpy.ops.object.select_all(action='DESELECT')
for p in parts: p.select_set(True)
bpy.context.view_layer.objects.active = body; bpy.ops.object.join()
print("BRIDGE tris", sum(len(p.vertices) - 2 for p in bpy.context.object.data.polygons))
bpy.ops.export_scene.gltf(filepath=os.path.join(out, "bridge.glb"), export_format='GLB')
