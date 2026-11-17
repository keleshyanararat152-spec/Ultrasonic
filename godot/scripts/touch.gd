extends Control
## Driving controls. Phone: the left thumb steers by sliding sideways anywhere on the left side;
## the right thumb works three pedals (gas, brake/reverse, handbrake). Each touch is tracked by its index,
## so both thumbs work at once. Keyboard: W/S or arrows, A/D, Space for the handbrake.

var steer_id := -1
var steer_origin := Vector2.ZERO
var steer_x := 0.0
var pedals := {}          # touch index -> "gas" | "rev" | "hand"
var touched := false      # a touch was seen: show the pedals
var font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = load("res://fonts/NotoSansArmenian.ttf")
	touched = DisplayServer.is_touchscreen_available()

func _rects() -> Dictionary:
	var s := get_viewport_rect().size; var m := 18.0
	var gas := Rect2(s.x - m - 96, s.y - m - 140, 96, 140)
	var rev := Rect2(gas.position.x - 12 - 82, s.y - m - 100, 82, 100)
	var hand := Rect2(rev.position.x - 12 - 66, s.y - m - 66, 66, 66)
	return { "gas": gas, "rev": rev, "hand": hand }

func _pedal_at(p: Vector2) -> String:
	var r := _rects()
	for k in r:
		if (r[k] as Rect2).grow(10).has_point(p): return k
	return ""

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		touched = true
		if e.pressed:
			var k := _pedal_at(e.position)
			if k != "":
				pedals[e.index] = k
				if OS.has_feature("mobile"): Input.vibrate_handheld(8)
			elif steer_id < 0 and e.position.x < get_viewport_rect().size.x * 0.6:
				steer_id = e.index; steer_origin = e.position; steer_x = 0
		else:
			pedals.erase(e.index)
			if e.index == steer_id: steer_id = -1; steer_x = 0
		queue_redraw()
	elif e is InputEventScreenDrag:
		if e.index == steer_id:
			steer_x = clampf((e.position.x - steer_origin.x) / 70.0, -1, 1); queue_redraw()
		elif pedals.has(e.index):   # sliding a thumb from one pedal to another
			var k := _pedal_at(e.position)
			if k != "" and k != pedals[e.index]: pedals[e.index] = k; queue_redraw()

func read_input() -> Dictionary:
	var thr := 0.0; var steer := 0.0; var hand := false
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): thr += 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): thr -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): steer += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): steer -= 1
	if Input.is_key_pressed(KEY_SPACE): hand = true
	var vals := pedals.values()
	if vals.has("gas") and not vals.has("rev"): thr = 1
	elif vals.has("rev"): thr = -1
	if vals.has("hand"): hand = true
	if steer_id >= 0:
		var a := maxf(0, absf(steer_x) - 0.07) / 0.93
		steer = signf(steer_x) * pow(a, 1.35) / 0.8
	return { "thr": thr, "steer": steer, "hand": hand }

func _draw() -> void:
	if not touched: return
	var vals := pedals.values()
	var cols := { "gas": Color("58d68d"), "rev": Color("ff5a5f"), "hand": Color("f1ede6") }
	var labels := { "gas": "Գազ", "rev": "Արգելակ", "hand": "Ձեռքի" }
	var r := _rects()
	for k in r:
		var rect: Rect2 = r[k]; var on: bool = vals.has(k)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(cols[k], 0.45) if on else Color(0.08, 0.09, 0.11, 0.7)
		bg.border_color = cols[k]; bg.set_border_width_all(3); bg.set_corner_radius_all(33 if k == "hand" else 16)
		draw_style_box(bg, rect)
		var fs := 18 if k == "gas" else 14
		var tw := font.get_string_size(labels[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, rect.get_center() + Vector2(-tw / 2, fs * 0.35), labels[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f1ede6"))
	if steer_id >= 0:   # the steering track under the left thumb
		var o := steer_origin
		draw_line(o - Vector2(70, 0), o + Vector2(70, 0), Color(1, 1, 1, 0.45), 4)
		draw_line(o - Vector2(0, 10), o + Vector2(0, 10), Color(1, 1, 1, 0.45), 3)
		draw_circle(o + Vector2(steer_x * 70, 0), 22, Color("ffcf4a", 0.8) if absf(steer_x) > 0.9 else Color(1, 1, 1, 0.75))
