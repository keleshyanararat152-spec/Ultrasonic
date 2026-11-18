# Builds the facade parts for Pink City in Blender and exports them as glTF:
#   window.glb   a window with a bevelled frame, a sill, a lintel and a cross bar; glass is its own material
#   balcony.glb  a stone slab with a railing
#   shop.glb     a ground-floor shop window with a frame and an awning
# Run: blender -b -P tools/blender/facade_parts.py -- <out_dir>
# Each part faces -Y in Blender (+Z in Godot), with its origin at the centre of the opening on the wall face.
import bpy, sys, os, math

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
os.makedirs(out, exist_ok=True)


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


def mat(name, col, rough=0.6, metal=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*col, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def box(name, size, loc, material, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        md = o.modifiers.new("bevel", "BEVEL")
        md.width = bevel
        md.segments = 2
        md.limit_method = "ANGLE"
    o.data.materials.append(material)
    return o


def cyl(name, r, h, loc, material, seg=8):
    bpy.ops.mesh.primitive_cylinder_add(vertices=seg, radius=r, depth=h, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    return o


def export(path):
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    for o in objs:   # bake modifiers before joining
        bpy.context.view_layer.objects.active = o
        for md in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.context.view_layer.objects.active = objs[0]
    for o in objs:
        o.select_set(True)
    bpy.ops.object.join()
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_materials="EXPORT", export_normals=True)


# ------------------------------------------------------------------ window ----------
reset()
frame = mat("frame", (0.93, 0.9, 0.85), 0.55)
glass = mat("glass", (0.08, 0.1, 0.12), 0.05)
stone = mat("trim", (0.85, 0.8, 0.74), 0.85)
W, H, D = 1.4, 1.9, 0.12          # opening, frame depth
t = 0.08                          # frame bar thickness
box("top", (W + 2 * t, t, D), (0, -D / 2, H / 2 + t / 2), frame, 0.01)
box("bottom", (W + 2 * t, t, D), (0, -D / 2, -H / 2 - t / 2), frame, 0.01)
box("left", (t, D, H), (-W / 2 - t / 2, -D / 2, 0), frame, 0.01)
box("right", (t, D, H), (W / 2 + t / 2, -D / 2, 0), frame, 0.01)
box("mull", (0.05, 0.06, H), (0, -0.05, 0), frame, 0.0)
box("trans", (W, 0.06, 0.05), (0, -0.05, H * 0.22), frame, 0.0)
box("sill", (W + 0.4, 0.22, 0.07), (0, -0.11, -H / 2 - t - 0.035), stone, 0.012)
box("lintel", (W + 0.36, 0.1, 0.16), (0, -0.05, H / 2 + t + 0.08), stone, 0.01)
box("glass", (W, 0.01, H), (0, -0.02, 0), glass)
export(os.path.join(out, "window.glb"))

# ------------------------------------------------------------------ balcony ----------
reset()
stone = mat("trim", (0.85, 0.8, 0.74), 0.85)
iron = mat("iron", (0.12, 0.12, 0.13), 0.4, 0.8)
BW, BD = 2.4, 0.9
box("slab", (BW, BD, 0.14), (0, -BD / 2, -1.05), stone, 0.02)
box("rail", (BW, 0.05, 0.05), (0, -BD + 0.03, -0.0), iron)
for s in (-1, 1):
    box("side%d" % s, (0.05, BD, 0.05), (s * (BW / 2 - 0.03), -BD / 2, 0.0), iron)
n = 15
for k in range(n):
    x = -BW / 2 + 0.06 + k * (BW - 0.12) / (n - 1)
    cyl("bar%d" % k, 0.012, 0.95, (x, -BD + 0.03, -0.5), iron, 6)
for k in range(5):
    y = -0.06 - k * (BD - 0.1) / 4
    for s in (-1, 1):
        cyl("sbar%d_%d" % (k, s), 0.012, 0.95, (s * (BW / 2 - 0.03), y, -0.5), iron, 6)
export(os.path.join(out, "balcony.glb"))

# ------------------------------------------------------------------ shop front ----------
reset()
frame = mat("frame", (0.16, 0.16, 0.17), 0.45, 0.6)
glass = mat("glass", (0.08, 0.1, 0.12), 0.05)
awning = mat("awning", (0.75, 0.2, 0.25), 0.8)
SW, SH = 2.6, 2.6
for nm, sz, loc in [("top", (SW + 0.2, 0.14, 0.1), (0, -0.07, SH / 2 + 0.05)), ("bottom", (SW + 0.2, 0.14, 0.3), (0, -0.07, -SH / 2 - 0.15)),
                    ("left", (0.1, 0.14, SH), (-SW / 2 - 0.05, -0.07, 0)), ("right", (0.1, 0.14, SH), (SW / 2 + 0.05, -0.07, 0)),
                    ("mid", (0.06, 0.08, SH), (SW * 0.18, -0.05, 0))]:
    box(nm, sz, loc, frame, 0.008)
box("glass", (SW, 0.01, SH), (0, -0.02, 0), glass)
# a sloping awning: a thin box tilted down and out
a = box("awning", (SW + 0.5, 1.1, 0.04), (0, -0.5, SH / 2 + 0.35), awning)
a.rotation_euler = (math.radians(-22), 0, 0)
bpy.ops.object.transform_apply(rotation=True)
box("valance", (SW + 0.5, 0.03, 0.22), (0, -1.02, SH / 2 + 0.05), awning)
export(os.path.join(out, "shop.glb"))
print("facade parts written to", out)
