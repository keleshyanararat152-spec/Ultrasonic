# Grows street trees for Pink City with Blender's Sapling add-on and exports them as glTF:
#   tree_a.glb, tree_b.glb   a trunk and branches ("bark") and leaf cards ("leaves"), origin at the foot of the trunk
# Run: blender -b -P tools/blender/trees.py -- <out_dir>
import bpy, sys, os, addon_utils, random

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
os.makedirs(out, exist_ok=True)
addon_utils.enable("add_curve_sapling", default_set=True)


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for m in list(bpy.data.meshes) + list(bpy.data.curves):
        try:
            (bpy.data.meshes if isinstance(m, bpy.types.Mesh) else bpy.data.curves).remove(m)
        except Exception:
            pass


def mat(name, col):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*col, 1)
    return m


def grow(name, seed, height, branches, leaves):
    reset()
    bpy.ops.curve.tree_add(
        do_update=True, seed=seed, levels=3, scale=height, scaleV=1.0,
        length=(1.0, 0.42, 0.55, 0.45), lengthV=(0.0, 0.15, 0.1, 0.0),
        branches=branches, curveRes=(6, 4, 3, 1), curve=(0.0, -15.0, -10.0, 0.0), curveV=(15.0, 30.0, 40.0, 0.0),
        downAngle=(90.0, 55.0, 45.0, 45.0), downAngleV=(0.0, -25.0, 10.0, 10.0), rotate=(99.5, 137.5, 137.5, 137.5),
        baseSize=0.38, ratio=0.022, ratioPower=1.25, shape="7", segSplits=(0.0, 0.25, 0.1, 0.0), splitAngle=(12.0, 18.0, 15.0, 0.0),
        taper=(1.0, 1.0, 1.0, 1.0), bevel=True, bevelRes=1, resU=2, handleType="0",
        showLeaves=True, leaves=leaves, leafShape="rect", leafScale=0.75, leafScaleX=1.0, leafDist="6", leafangle=0.0, horzLeaves=True,
        useArm=False, prune=False)
    trunk = [o for o in bpy.context.scene.objects if o.type == "CURVE"][0]
    leafobj = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    # the branches as a mesh
    bpy.ops.object.select_all(action="DESELECT")
    trunk.select_set(True)
    bpy.context.view_layer.objects.active = trunk
    bpy.ops.object.convert(target="MESH")
    trunk = bpy.context.active_object
    trunk.data.materials.clear()
    trunk.data.materials.append(mat("bark", (0.45, 0.4, 0.35)))
    # a bark UV: around the branch and along it, from a cylinder projection is enough at this size
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cylinder_project(direction="ALIGN_TO_OBJECT", scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    md = trunk.modifiers.new("decimate", "DECIMATE")
    md.ratio = 0.5
    bpy.ops.object.modifier_apply(modifier="decimate")
    objs = [trunk]
    for lo in leafobj:
        lo.data.materials.clear()
        lo.data.materials.append(mat("leaves", (0.3, 0.5, 0.2)))
        if not lo.data.uv_layers:   # one card, one whole image
            uv = lo.data.uv_layers.new()
            for poly in lo.data.polygons:
                for k, li in enumerate(poly.loop_indices):
                    uv.data[li].uv = [(0, 0), (1, 0), (1, 1), (0, 1)][k % 4]
        objs.append(lo)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = trunk
    bpy.ops.object.join()
    t = bpy.context.active_object
    tris = sum(len(p.vertices) - 2 for p in t.data.polygons)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + ".glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True)
    print("tree", name, "triangles", tris)


grow("tree_a", 3, 10.0, (0, 30, 16, 8), 14)
grow("tree_b", 11, 8.5, (0, 26, 14, 8), 12)
