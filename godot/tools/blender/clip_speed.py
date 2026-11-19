# How fast each walking/running clip moves over the ground (m/s): the foot that is down slides backwards at the
# body's speed, since the root motion was taken out. Written into the clip JSON as "speed" so the game turns
# the legs at the rate that keeps the feet from sliding.
# usage: blender -b -P clip_speed.py -- anim_dir name=file.fbx ...
import bpy, sys, json, os
argv = sys.argv[sys.argv.index("--") + 1:]
out = argv[0]
for item in argv[1:]:
	name, path = item.split("=", 1)
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.fbx(filepath=path)
	arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
	W = arm.matrix_world; sc = bpy.context.scene
	def P(n): return W @ arm.pose.bones["Bip01 " + n].head
	f0, f1 = [int(v) for v in arm.animation_data.action.frame_range]
	sc.frame_set(f0)
	up = (P("Head") - P("Pelvis")).normalized()
	lat = P("L Thigh") - P("R Thigh"); lat = (lat - up * lat.dot(up)).normalized(); fwd = lat.cross(up).normalized()
	fps = sc.render.fps / sc.render.fps_base
	track = {"L": [], "R": []}
	for f in range(f0, f1 + 1):
		sc.frame_set(f)
		for s in "LR": track[s].append((P(s + " Foot").dot(up), P(s + " Foot").dot(fwd) - P("Pelvis").dot(fwd)))
	floor = min(h for s in "LR" for h, _ in track[s])
	tot = 0.0; n = 0; tol = 0.025
	while n < 3 and tol < 0.2:   # only frames where that foot is flat on the ground (a little looser for runs)
		tot = 0.0; n = 0
		for s in "LR":
			t = track[s]
			for i in range(1, len(t)):
				if t[i][0] < floor + tol and t[i - 1][0] < floor + tol: tot += (t[i - 1][1] - t[i][1]) * fps; n += 1
		tol += 0.02
	speed = tot / max(1, n)
	p = os.path.join(out, name + ".json"); d = json.load(open(p)); d["speed"] = round(speed, 3)
	json.dump(d, open(p, "w"), separators=(",", ":"))
	print("SPEED", name, round(speed, 3))
