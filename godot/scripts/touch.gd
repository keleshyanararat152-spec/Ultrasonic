extends Control
## Phone and keyboard controls. Each touch is tracked by its index, so two thumbs work at once.
## In a car: the left thumb steers by sliding sideways; the right thumb works gas, brake/reverse and handbrake.
## On foot: the left thumb is a stick (up walks, sideways turns). A round button gets in or out of a car.
## Keyboard: W/S or arrows, A/D, Space for the handbrake, E to get in or out.

var main: Node
var driving := false
var act_label := ""
var touched := false      # a touch was seen: show the on-screen controls
var font: Font

var left_id := -1         # the left thumb: steering in a car, a stick on foot
var left_origin := Vector2.ZERO
var steer_id: int:
	get: return left_id
	set(v): left_id = v
var steer_x := 0.0
var stick := Vector2.ZERO
var pedals := {}          # touch index -> "gas" | "rev" | "hand"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = load("res://fonts/NotoSansArmenian.ttf")
	touched = DisplayServer.is_touchscreen_available()

func _process(_dt: float) -> void:
	queue_redraw()

func _rects() -> Dictionary:
	var s := get_viewport_rect().size; var m := 18.0
	var gas := Rect2(s.x - m - 96, s.y - m - 140, 96, 140)
	var rev := Rect2(gas.position.x - 12 - 82, s.y - m - 100, 82, 100)
	var hand := Rect2(rev.position.x - 12 - 66, s.y - m - 66, 66, 66)
	var act := Rect2(s.x - m - 84, s.y - m - (140 + 14 + 70 if driving else 84), 84 if not driving else 70, 84 if not driving else 70)
	if driving: act.position.x = s.x - m - 70
	var fire := Rect2(s.x - m - 110, s.y - m - 84 - 14 - 110, 110, 110)   # on foot with a gun: hold to fire, tap to change gun
	var gun := Rect2(fire.position.x - 14 - 70, s.y - m - 84 - 14 - 70, 70, 70)
	return { "gas": gas, "rev": rev, "hand": hand, "act": act, "fire": fire, "gun": gun }

func _armed() -> bool:
	return main != null and main.weapons != null and not driving and main.weapons.owned().size() > 0 and main.interior.inside == ""

func _hit(p: Vector2) -> String:
	var r := _rects()
	if act_label != "" and (r.act as Rect2).grow(8).has_point(p): return "act"
	if driving:
		for k in ["gas", "rev", "hand"]:
			if (r[k] as Rect2).grow(10).has_point(p): return k
	elif _armed():
		for k in ["fire", "gun"]:
			if (r[k] as Rect2).grow(10).has_point(p): return k
	return ""

func _input(e: InputEvent) -> void:
	if main and main.ui and main.ui.busy():   # dialogue, a panel or the big map takes the touches
		pedals.clear(); left_id = -1; steer_x = 0; stick = Vector2.ZERO
		return
	if e is InputEventScreenTouch:
		touched = true
		if e.pressed:
			var k := _hit(e.position)
			if k == "gun":
				main.weapons.next_gun(1)
			elif k == "act":
				if main: main.act()
				if OS.has_feature("mobile"): Input.vibrate_handheld(10)
			elif k != "":
				pedals[e.index] = k
				if OS.has_feature("mobile"): Input.vibrate_handheld(8)
			elif left_id < 0 and e.position.x < get_viewport_rect().size.x * 0.6:
				left_id = e.index; left_origin = e.position; steer_x = 0; stick = Vector2.ZERO
		else:
			pedals.erase(e.index)
			if e.index == left_id: left_id = -1; steer_x = 0; stick = Vector2.ZERO
	elif e is InputEventScreenDrag:
		if e.index == left_id:
			var d: Vector2 = e.position - left_origin
			steer_x = clampf(d.x / 70.0, -1, 1)
			stick = (d / 60.0).limit_length(1.0)
		elif pedals.has(e.index):   # sliding a thumb from one pedal to another
			var k := _hit(e.position)
			if k != "" and k != "act" and k != pedals[e.index]: pedals[e.index] = k

var test_steer := 0.0   # testing aid: a steady turn of the wheel

func read_input() -> Dictionary:
	var thr := 0.0; var steer := 0.0; var hand := false
	var up := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	var dn := Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	var rt := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	var lt := Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	if up: thr += 1
	if dn: thr -= 1
	if rt: steer += 1
	if lt: steer -= 1
	if Input.is_key_pressed(KEY_SPACE): hand = true
	var move := Vector2(steer, -thr)
	var vals := pedals.values()
	if vals.has("gas") and not vals.has("rev"): thr = 1
	elif vals.has("rev"): thr = -1
	if vals.has("hand"): hand = true
	if left_id >= 0 or stick != Vector2.ZERO:
		var a := maxf(0, absf(steer_x) - 0.07) / 0.93
		if left_id >= 0: steer = signf(steer_x) * pow(a, 1.35) / 0.8
		if stick.length() > 0.2: move = stick
	if test_steer != 0.0: steer = test_steer
	return { "thr": thr, "steer": steer, "hand": hand, "move": move }

func _btn(rect: Rect2, label: String, col: Color, on: bool, round := false, fs := 15) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(col, 0.45) if on else Color(0.08, 0.09, 0.11, 0.7)
	bg.border_color = col; bg.set_border_width_all(3); bg.set_corner_radius_all(int(rect.size.x / 2) if round else 16)
	draw_style_box(bg, rect)
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, rect.get_center() + Vector2(-tw / 2, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f1ede6"))

func _draw() -> void:
	if not touched: return
	var r := _rects(); var vals := pedals.values()
	if driving:
		_btn(r.gas, "Գազ", Color("58d68d"), vals.has("gas"), false, 18)
		_btn(r.rev, "Արգելակ", Color("ff5a5f"), vals.has("rev"), false, 14)
		_btn(r.hand, "Ձեռքի", Color("f1ede6"), vals.has("hand"), true, 13)
	if act_label != "": _btn(r.act, act_label, Color("ffcf4a"), false, true, 15)
	if _armed():
		_btn(r.fire, "Կրակ", Color("ff5a5f"), vals.has("fire"), true, 18)
		_btn(r.gun, "Զենք", Color("f1ede6"), false, true, 14)
	if left_id >= 0:
		var o := left_origin
		if driving:   # the steering track under the left thumb
			draw_line(o - Vector2(70, 0), o + Vector2(70, 0), Color(1, 1, 1, 0.45), 4)
			draw_line(o - Vector2(0, 10), o + Vector2(0, 10), Color(1, 1, 1, 0.45), 3)
			draw_circle(o + Vector2(steer_x * 70, 0), 22, Color("ffcf4a", 0.8) if absf(steer_x) > 0.9 else Color(1, 1, 1, 0.75))
		else:         # the walking stick
			draw_arc(o, 60, 0, TAU, 40, Color(1, 1, 1, 0.45), 3)
			draw_circle(o + stick * 60, 24, Color(1, 1, 1, 0.7))
