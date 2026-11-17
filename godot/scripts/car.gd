extends RefCounted
class_name Car
## One car: its state in game units, its physics step and its street-following driver.
## A port of carStep / aiDrive / nextLeg / resync from game/city/index.html.

const HX := 24.0      # half length of the collision box
const HY := 10.5      # half width
const DV := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

var x := 0.0
var y := 0.0
var a := 0.0          # heading: forward is (cos a, sin a)
var v := 0.0          # forward speed
var lat := 0.0        # sideways slip
var w := 0.0          # yaw rate
var spin := 0.0       # seconds of spin left after a hit
var stun := 0.0       # seconds an AI driver is knocked off course
var max_speed := 320.0
var acc := 1.0
var grip := 1.0
var kind := "civ"     # civ | police
var model := ""
var driver := false   # an AI is driving it
var ai := {}          # { i, j, d, stage, wx, wy }
var cruise := 110.0
var stuck := 0.0
var ignore := 0.0
var rev := 0.0
var slow := 0.0
var dmg := 0
var steer_in := 0.0
var hand := false
var node: Node3D = null
var anim := {}

static func ic_static(i: int) -> float:
	return i * 520.0 + 60.0

func mass() -> float:
	if kind == "police": return 1.35
	if model.find("suv") >= 0 or model == "gclass" or model == "traffic_pickup" or model == "traffic_minivan": return 1.3
	return 1.0

## One physics step. thr in [-1, 1], steer in [-1, 1]. Returns the wall impact speed (0 when no hit).
func step(city, thr: float, steer: float, handbrake: bool, dt: float) -> float:
	var vv := v
	if thr > 0:
		if vv < -5: vv += 520 * thr * dt
		else: vv += 265 * acc * thr * maxf(0.12, 1 - pow(maxf(0, vv) / max_speed, 2)) * dt
	elif thr < 0:
		if vv > 5: vv = maxf(0, vv + 440 * thr * dt)
		else: vv = maxf(-100, vv + 190 * thr * dt)
	else:
		var r := vv * 0.45 * dt + signf(vv) * 18 * dt
		vv = 0.0 if absf(r) > absf(vv) else vv - r
	if handbrake: vv -= vv * 1.5 * dt
	vv -= vv * minf(0.5, absf(lat) * 0.004) * dt * 6
	vv = clampf(vv, -100, max_speed)
	var tw := steer * (3.6 if handbrake else 2.5) * grip * clampf(vv / 90, -1, 1) * (1 - 0.25 * clampf(absf(vv) / 500, 0, 1))
	w += (tw - w) * minf(1, dt * (2.2 if spin > 0 else 7.0))
	if spin > 0: spin -= dt
	var f0 := Vector2(cos(a), sin(a)); var vel := f0 * vv + Vector2(-f0.y, f0.x) * lat
	a += w * dt
	var f := Vector2(cos(a), sin(a)); var rgt := Vector2(-f.y, f.x)
	vv = vel.dot(f); var la := vel.dot(rgt)
	la *= exp(-dt * (2.0 if handbrake else (3.5 if spin > 0 else 11.0 * grip)))
	v = vv; lat = la; steer_in = steer; hand = handbrake
	x += (f.x * v + rgt.x * lat) * dt; y += (f.y * v + rgt.y * lat) * dt
	# buildings: push out at nose, middle and tail; cancel the speed into the wall, keep the slide along it
	var push := Vector2.ZERO; var tq := 0.0; var hit := false
	for s in [17.0, 0.0, -17.0]:
		var p := Vector2(x + f.x * s, y + f.y * s)
		var q: Vector2 = city.push_out(p, 11.5)
		if q != p:
			hit = true; var d := q - p; x += d.x; y += d.y; push += d; tq += s * (f.x * d.y - f.y * d.x)
	if hit:
		var n := push.normalized()
		var wv := f * v + rgt * lat; var vn := wv.dot(n)
		if vn < 0:
			wv -= n * vn * 1.25; wv *= 0.9
			v = wv.dot(f); lat = wv.dot(rgt)
			w += clampf(signf(tq) * -vn * 0.012, -3, 3); spin = maxf(spin, minf(0.6, -vn / 400))
			return -vn
	return 0.0

func corners() -> Array:
	var f := Vector2(cos(a), sin(a)); var r := Vector2(-f.y, f.x); var out := []
	for u in [1, -1]:
		for k in [1, -1]: out.append(Vector2(x, y) + f * HX * u + r * HY * k)
	return out

## Two boxes: push apart along the shallowest axis, then trade an impulse at the contact. Returns the impact speed.
static func collide(p: Car, q: Car) -> float:
	var dx := q.x - p.x; var dy := q.y - p.y
	if absf(dx) > 56 or absf(dy) > 56: return 0.0
	var fp := Vector2(cos(p.a), sin(p.a)); var fq := Vector2(cos(q.a), sin(q.a))
	var axes := [fp, Vector2(-fp.y, fp.x), fq, Vector2(-fq.y, fq.x)]
	var best := 1e9; var n := Vector2.ZERO
	for ax: Vector2 in axes:
		var ra := HX * absf(fp.dot(ax)) + HY * absf(Vector2(-fp.y, fp.x).dot(ax))
		var rb := HX * absf(fq.dot(ax)) + HY * absf(Vector2(-fq.y, fq.x).dot(ax))
		var d := dx * ax.x + dy * ax.y; var o := ra + rb - absf(d)
		if o <= 0: return 0.0
		if o < best: best = o; n = -ax if d < 0 else ax
	var mp := p.mass(); var mq := q.mass(); var sum := mp + mq
	p.x -= n.x * best * mq / sum; p.y -= n.y * best * mq / sum; q.x += n.x * best * mp / sum; q.y += n.y * best * mp / sum
	var cp: Vector2 = p.corners()[0]; for k in p.corners(): if k.dot(n) > cp.dot(n): cp = k
	var cq: Vector2 = q.corners()[0]; for k in q.corners(): if k.dot(n) < cq.dot(n): cq = k
	var c := (cp + cq) / 2; var rp := c - Vector2(p.x, p.y); var rq := c - Vector2(q.x, q.y)
	var vp := p.world_vel() + Vector2(-p.w * rp.y, p.w * rp.x); var vq := q.world_vel() + Vector2(-q.w * rq.y, q.w * rq.x)
	var rel := vq - vp; var vn := rel.dot(n)
	if vn >= 0: return 0.0
	var ip := mp * 230; var iq := mq * 230; var rpn := rp.cross(n); var rqn := rq.cross(n)
	var j := -(1 + 0.25) * vn / (1 / mp + 1 / mq + rpn * rpn / ip + rqn * rqn / iq)
	var t := Vector2(-n.y, n.x); var jt := clampf(-rel.dot(t) / (1 / mp + 1 / mq), -0.35 * j, 0.35 * j)
	var imp := n * j + t * jt
	p.kick(-imp, mp, ip, rp, -vn); q.kick(imp, mq, iq, rq, -vn)
	return -vn

func world_vel() -> Vector2:
	var f := Vector2(cos(a), sin(a)); return f * v + Vector2(-f.y, f.x) * lat

func kick(imp: Vector2, m: float, inertia: float, r: Vector2, hard: float) -> void:
	var f := Vector2(cos(a), sin(a)); var rg := Vector2(-f.y, f.x)
	var wv := world_vel() + imp / m
	v = clampf(wv.dot(f), -140, maxf(max_speed, 200)); lat = clampf(wv.dot(rg), -260, 260)
	w = clampf(w + r.cross(imp) / inertia, -5, 5)
	if hard > 60:
		spin = maxf(spin, minf(1.2, hard / 260))
		if driver: stun = maxf(stun, 0.5 + hard / 250)

# ------------------------------------------------------------------ the AI driver ----------
func next_leg(I: int, J: int) -> void:
	var opts := []
	for d in 4:
		var nx: int = I + DV[d].x; var ny: int = J + DV[d].y
		if nx >= 0 and ny >= 0 and nx <= 7 and ny <= 7: opts.append(d)
	if ai.get("d", -1) >= 0 and opts.size() > 1: opts.erase((ai.d + 2) % 4)
	var d: int = opts.pick_random()
	var r: Vector2i = DV[(d + 1) % 4]
	ai = { "i": I, "j": J, "d": d, "stage": 1,
		"wx": 520.0 * I + 60 + DV[d].x * 85 + r.x * 28, "wy": 520.0 * J + 60 + DV[d].y * 85 + r.y * 28 }

func resync() -> void:  # head for the nearest crossroads, then follow the streets from there
	var I := clampi(roundi((x - 60) / 520.0), 0, 7); var J := clampi(roundi((y - 60) / 520.0), 0, 7)
	ai = { "i": I, "j": J, "d": -1, "stage": 2, "wx": 520.0 * I + 60, "wy": 520.0 * J + 60 }

func drive(city, cars: Array, player_pos: Vector2, player_on_foot: bool, dt: float) -> void:
	if stun > 0:
		stun -= dt; step(city, 0, 0, false, dt)
		if stun <= 0: resync()
		return
	var tx: float = ai.wx; var ty: float = ai.wy
	if Vector2(tx - x, ty - y).length() < 34:
		var d: Vector2i = DV[max(ai.d, 0)]
		if ai.stage == 2: next_leg(ai.i, ai.j)
		elif ai.stage == 1:
			var r: Vector2i = DV[(ai.d + 1) % 4]
			ai.stage = 0; ai.wx = 520.0 * (ai.i + d.x) + 60 - d.x * 85 + r.x * 28; ai.wy = 520.0 * (ai.j + d.y) + 60 - d.y * 85 + r.y * 28
		else: next_leg(ai.i + d.x, ai.j + d.y)
		tx = ai.wx; ty = ai.wy
	var diff := wrapf(atan2(ty - y, tx - x) - a, -PI, PI)
	var steer := clampf(diff * 2.2, -1, 1); var tv := cruise
	if absf(diff) > 0.6: tv = minf(tv, 75)
	if ai.stage == 1: tv = minf(tv, 85)
	var f := Vector2(cos(a), sin(a)); var blocked := false
	for o: Car in cars:
		if o == self: continue
		var rel := Vector2(o.x - x, o.y - y); var fw := rel.dot(f)
		if fw > 8 and fw < 76 and absf(rel.x * f.y - rel.y * f.x) < 18: blocked = true; break
	if not blocked and player_on_foot:
		var rel := player_pos - Vector2(x, y); var fw := rel.dot(f)
		if fw > 8 and fw < 76 and absf(rel.x * f.y - rel.y * f.x) < 18: blocked = true
	ignore -= dt
	if blocked and ignore <= 0:
		tv = 0; stuck += dt
		if stuck > 4: ignore = 1.5; stuck = 0
	elif not blocked: stuck = 0
	var thr := 0.0
	if rev > 0: rev -= dt; thr = -1; steer = -steer
	elif tv == 0:
		if v > 5: thr = -1
		else: v = 0
	elif v < tv: thr = 0.6
	elif v > tv + 15: thr = -0.6
	var hit := step(city, thr, steer, false, dt)
	if hit > 0:
		slow = slow + dt if absf(v) < 12 else 0.0
		if slow > 1.2: rev = 0.9; slow = 0
