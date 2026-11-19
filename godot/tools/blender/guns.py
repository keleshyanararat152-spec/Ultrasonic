# Four simple guns for the game (assets/weapons/*.glb): pistol, smg, shotgun, rifle. Each points along +X with the
# grip at the origin (where the hand holds it); the muzzle is at the far +X end. Run: blender -b -P guns.py -- out_dir
import bpy, sys, os, math
out = sys.argv[sys.argv.index("--") + 1]; os.makedirs(out, exist_ok=True)

def mat(name, col, rough, metal):
	m = bpy.data.materials.new(name); m.use_nodes = True
	b = m.node_tree.nodes["Principled BSDF"]
	b.inputs["Base Color"].default_value = (*col, 1); b.inputs["Roughness"].default_value = rough; b.inputs["Metallic"].default_value = metal
	return m

def gun(name, parts):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	steel = mat("steel", (0.08, 0.08, 0.09), 0.35, 0.9); poly = mat("polymer", (0.05, 0.05, 0.05), 0.7, 0.0); wood = mat("wood", (0.35, 0.2, 0.1), 0.55, 0.0)
	mats = {"s": steel, "p": poly, "w": wood}
	objs = []
	for kind, m, loc, size, rot in parts:
		if kind == "box": bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
		else: bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=1, depth=1, location=loc, rotation=(0, math.pi / 2, 0))
		o = bpy.context.object; o.scale = size
		if rot: o.rotation_euler = rot
		bpy.ops.object.transform_apply(scale=True, rotation=True); o.data.materials.append(mats[m]); objs.append(o)
	bpy.ops.object.select_all(action='DESELECT')
	for o in objs: o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]; bpy.ops.object.join()
	bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + ".glb"), export_format='GLB')
	print("GUN", name, [round(v, 2) for v in bpy.context.object.dimensions])

# (shape, material, centre, size, rotation)
gun("pistol", [("box", "s", (0.07, 0, 0.07), (0.19, 0.03, 0.035), None), ("box", "p", (0.0, 0, -0.01), (0.035, 0.028, 0.11), (0, -0.25, 0)),
	("box", "p", (0.04, 0, 0.035), (0.09, 0.026, 0.035), None), ("cyl", "s", (0.17, 0, 0.075), (0.007, 0.007, 0.03), None)])
gun("smg", [("box", "s", (0.1, 0, 0.06), (0.3, 0.04, 0.06), None), ("box", "p", (0.0, 0, -0.03), (0.035, 0.03, 0.12), (0, -0.2, 0)),
	("box", "s", (0.06, 0, -0.07), (0.03, 0.025, 0.17), None), ("cyl", "s", (0.29, 0, 0.065), (0.012, 0.012, 0.1), None),
	("box", "p", (-0.13, 0, 0.05), (0.16, 0.025, 0.04), None)])
gun("shotgun", [("cyl", "s", (0.35, 0, 0.06), (0.016, 0.016, 0.62), None), ("cyl", "w", (0.3, 0, 0.025), (0.02, 0.02, 0.22), None),
	("box", "s", (0.0, 0, 0.045), (0.16, 0.04, 0.06), None), ("box", "w", (-0.24, 0, 0.0), (0.34, 0.04, 0.08), (0, 0.12, 0)),
	("box", "w", (-0.02, 0, -0.04), (0.035, 0.03, 0.09), (0, -0.3, 0))])
gun("rifle", [("box", "s", (0.12, 0, 0.06), (0.36, 0.045, 0.08), None), ("cyl", "s", (0.43, 0, 0.07), (0.011, 0.011, 0.3), None),
	("box", "p", (0.0, 0, -0.03), (0.035, 0.03, 0.11), (0, -0.25, 0)), ("box", "s", (0.1, 0, -0.06), (0.04, 0.025, 0.16), (0, 0.25, 0)),
	("box", "p", (-0.24, 0, 0.03), (0.3, 0.035, 0.09), None), ("box", "s", (0.1, 0, 0.12), (0.16, 0.02, 0.02), None)])
