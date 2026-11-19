# Rocketbox motion-capture clips (MIT, github.com/microsoft/Microsoft-Rocketbox, Assets/Animations) turned into
# small JSON clips the game retargets onto its avatars (scripts/people.gd, Avatar.clip_pose).
# For every bone and frame it stores, in the body frame (x: to the left hip, y: up, z: forward):
#   q: the bone's world rotation from the clip's own rest, and d: where the bone points (to its child joint).
# The game applies q to its own rest and then swings the bone onto d, so a different rest pose does not matter.
# usage: blender -b -P rocketbox_anims.py -- out_dir name=file.fbx [name=file.fbx ...]
import bpy, sys, json, os
from mathutils import Vector, Matrix, Quaternion

argv = sys.argv[sys.argv.index("--") + 1:]
out = argv[0]
os.makedirs(out, exist_ok=True)
FPS = 15
CHILD = {"Pelvis": None, "Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head", "Head": None,
	"L Clavicle": "L UpperArm", "R Clavicle": "R UpperArm", "L UpperArm": "L Forearm", "R UpperArm": "R Forearm",
	"L Forearm": "L Hand", "R Forearm": "R Hand", "L Hand": "L Finger2", "R Hand": "R Finger2",
	"L Thigh": "L Calf", "R Thigh": "R Calf", "L Calf": "L Foot", "R Calf": "R Foot", "L Foot": "L Toe0", "R Foot": "R Toe0"}
for s in "LR":
	for f in "01234":
		CHILD[s + " Finger" + f] = s + " Finger" + f + "1"
		CHILD[s + " Finger" + f + "1"] = None

for item in argv[1:]:
	name, path = item.split("=", 1)
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.fbx(filepath=path)
	arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
	W = arm.matrix_world; WR = W.to_3x3().normalized()
	def rest_p(n): return W @ arm.data.bones["Bip01 " + n].head_local
	up = (rest_p("Head") - rest_p("Pelvis")).normalized()
	lat = rest_p("L Thigh") - rest_p("R Thigh"); lat = (lat - up * lat.dot(up)).normalized()
	fwd = lat.cross(up).normalized()
	B = Matrix((lat, up, fwd))   # rows: world -> body
	Bq = B.to_quaternion(); Bi = Bq.inverted()
	leg = (rest_p("L Thigh") - rest_p("L Foot")).length
	act = arm.animation_data.action
	f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
	scene = bpy.context.scene; src_fps = scene.render.fps / scene.render.fps_base
	step = src_fps / FPS
	names = [n for n in CHILD if ("Bip01 " + n) in arm.pose.bones]
	rest_rot = {n: (WR @ arm.data.bones["Bip01 " + n].matrix_local.to_3x3()).to_quaternion() for n in names}
	clip = {"fps": FPS, "bones": {n: {"q": [], "d": []} for n in names}, "pel": [], "leg": leg}
	pel0 = None
	t = float(f0)
	while t <= f1 + 0.001:
		scene.frame_set(int(t), subframe=t - int(t))
		for n in names:
			pb = arm.pose.bones["Bip01 " + n]
			wq = (WR @ pb.matrix.to_3x3()).to_quaternion()
			dq = Bq @ (wq @ rest_rot[n].inverted()) @ Bi
			clip["bones"][n]["q"].append([round(v, 4) for v in (dq.x, dq.y, dq.z, dq.w)])
			c = CHILD[n]
			if c and ("Bip01 " + c) in arm.pose.bones:
				d = (W @ arm.pose.bones["Bip01 " + c].head) - (W @ pb.head)
				d = (B @ d).normalized()
				clip["bones"][n]["d"].append([round(v, 4) for v in d])
		p = B @ (W @ arm.pose.bones["Bip01 Pelvis"].head)
		if pel0 is None: pel0 = p.copy()
		clip["pel"].append([round(v / leg, 4) for v in (p - pel0)])
		t += step
	for n in names:
		if not clip["bones"][n]["d"]: del clip["bones"][n]["d"]
	clip["frames"] = len(clip["pel"])
	with open(os.path.join(out, name + ".json"), "w") as fh: json.dump(clip, fh, separators=(",", ":"))
	print("CLIP", name, clip["frames"], "frames", len(names), "bones", "src fps", src_fps)
