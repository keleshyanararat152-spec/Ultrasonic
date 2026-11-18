extends Control
## Stage 3 screens: the round radar that turns with the camera, the big map (M or tap the radar) where a tap
## sets a waypoint, the job line, dialogue with choices, shop-style panels and the chapter card.

const CELL := 520
const N := 7

var main
var font: Font
var base: ImageTexture          # the whole city, drawn once
var WS := float(N * CELL + 120)

var job_panel: PanelContainer
var job_text: Label
var job_time: Label
var radar: Panel
var radar_draw: Control
var big: Control
var big_draw: Control
var talk_box: PanelContainer
var talk_who: Label
var talk_text: Label
var talk_btns: HBoxContainer
var talk = null                 # { q: lines left, done: Callable, choice }
var shop: PanelContainer
var shop_title: Label
var shop_text: Label
var shop_list: VBoxContainer
var card: Label
var card_kick: Label
var card_box: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = load("res://fonts/NotoSansArmenian.ttf")
	_build_base()
	# the job line
	job_panel = _panel(Color(0.08, 0.09, 0.11, 0.85)); job_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 14); job_panel.add_child(hb)
	job_text = _label(17); job_time = _label(19); job_time.add_theme_color_override("font_color", Color("ffcf4a"))
	hb.add_child(job_text); hb.add_child(job_time); add_child(job_panel)
	# the radar: a circle clips the map drawn inside it
	radar = Panel.new(); var rs := StyleBoxFlat.new(); rs.bg_color = Color("6f7d63"); rs.set_corner_radius_all(200); rs.anti_aliasing = true
	radar.add_theme_stylebox_override("panel", rs); radar.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	radar.gui_input.connect(_radar_input)
	radar_draw = Control.new(); radar_draw.set_anchors_preset(Control.PRESET_FULL_RECT); radar_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_draw.draw.connect(_draw_radar); radar.add_child(radar_draw); add_child(radar)
	var ring := Panel.new(); var bs := StyleBoxFlat.new(); bs.draw_center = false; bs.border_color = Color(0.95, 0.93, 0.9, 0.5); bs.set_border_width_all(4); bs.set_corner_radius_all(200); bs.anti_aliasing = true
	ring.add_theme_stylebox_override("panel", bs); ring.set_anchors_preset(Control.PRESET_FULL_RECT); ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar.add_child(ring)
	var north := Control.new(); north.set_anchors_preset(Control.PRESET_FULL_RECT); north.mouse_filter = Control.MOUSE_FILTER_IGNORE
	north.draw.connect(_draw_north.bind(north)); radar.add_child(north); radar.set_meta("north", north)
	# the big map
	big = Control.new(); big.set_anchors_preset(Control.PRESET_FULL_RECT); big.visible = false; big.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new(); dim.color = Color(0.05, 0.04, 0.07, 0.88); dim.set_anchors_preset(Control.PRESET_FULL_RECT); dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big.add_child(dim)
	big_draw = Control.new(); big_draw.mouse_filter = Control.MOUSE_FILTER_STOP; big_draw.draw.connect(_draw_big); big_draw.gui_input.connect(_big_input)
	big.add_child(big_draw)
	var close := Button.new(); close.text = "✕  Փակել"; close.add_theme_font_size_override("font_size", 18); close.pressed.connect(toggle_map)
	close.set_anchors_preset(Control.PRESET_TOP_RIGHT); close.position = Vector2(-150, 14); close.custom_minimum_size = Vector2(130, 44); big.add_child(close)
	var clr := Button.new(); clr.text = "Ջնջել նշանը"; clr.add_theme_font_size_override("font_size", 16); clr.pressed.connect(_clear_wp)
	clr.set_anchors_preset(Control.PRESET_TOP_RIGHT); clr.position = Vector2(-150, 66); clr.custom_minimum_size = Vector2(130, 40); big.add_child(clr); big.set_meta("clr", clr)
	var tip := _label(15); tip.text = "Սեղմիր քարտեզին՝ տեղ նշելու համար"; tip.position = Vector2(16, 14); tip.add_theme_color_override("font_color", Color("a9a59c")); big.add_child(tip)
	add_child(big)
	# dialogue
	talk_box = _panel(Color(0.07, 0.06, 0.09, 0.94)); talk_box.visible = false
	var tv := VBoxContainer.new(); tv.add_theme_constant_override("separation", 8); talk_box.add_child(tv)
	talk_who = _label(18); talk_text = _label(19); talk_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	talk_btns = HBoxContainer.new(); talk_btns.alignment = BoxContainer.ALIGNMENT_END; talk_btns.add_theme_constant_override("separation", 10)
	tv.add_child(talk_who); tv.add_child(talk_text); tv.add_child(talk_btns); add_child(talk_box)
	# panels (race, escape; shops in stage 4)
	shop = _panel(Color(0.07, 0.06, 0.09, 0.96)); shop.visible = false
	var sv := VBoxContainer.new(); sv.add_theme_constant_override("separation", 10); shop.add_child(sv)
	shop_title = _label(24); shop_text = _label(16); shop_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; shop_text.add_theme_color_override("font_color", Color("cfc9bf"))
	shop_list = VBoxContainer.new(); shop_list.add_theme_constant_override("separation", 8)
	var sc := Button.new(); sc.text = "Փակել"; sc.pressed.connect(close_panel); sc.custom_minimum_size = Vector2(0, 42)
	sv.add_child(shop_title); sv.add_child(shop_text); sv.add_child(shop_list); sv.add_child(sc); add_child(shop)
	# chapter card
	card_box = VBoxContainer.new(); card_box.set_anchors_preset(Control.PRESET_CENTER); card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE; card_box.modulate.a = 0
	card_kick = _label(18); card_kick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; card_kick.add_theme_color_override("font_color", Color("ff4fa3"))
	card = _label(46); card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; card.add_theme_constant_override("outline_size", 10); card.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	card_box.add_child(card_kick); card_box.add_child(card); add_child(card_box)

func _panel(col: Color) -> PanelContainer:
	var p := PanelContainer.new(); var sb := StyleBoxFlat.new(); sb.bg_color = col; sb.set_corner_radius_all(12)
	sb.content_margin_left = 16; sb.content_margin_right = 16; sb.content_margin_top = 10; sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb); return p

func _label(fs: int) -> Label:
	var l := Label.new(); l.add_theme_font_size_override("font_size", fs); return l

func _build_base() -> void:   # the city map: streets, pavements, buildings, parks, the square
	var R := 512; var k := R / WS; var img := Image.create(R, R, false, Image.FORMAT_RGBA8)
	img.fill(Color("474a52"))
	var city = main.city if main else null
	for i in N:
		for j in N:
			img.fill_rect(Rect2i(int((i * CELL + 120) * k), int((j * CELL + 120) * k), int(400 * k) + 1, int(400 * k) + 1), Color("9b948a"))
			if city == null: continue
			var b: Dictionary = city.blocks[i][j]; var o := Vector2(i * CELL + 142, j * CELL + 142)
			if b.type == "park":
				img.fill_rect(Rect2i(int(o.x * k), int(o.y * k), int(356 * k), int(356 * k)), Color("5f9a52"))
				for t in b.trees:
					var c := Vector2(t.x, t.y) * k; var r: float = t.r * k * 1.2
					img.fill_rect(Rect2i(int(c.x - r), int(c.y - r), int(r * 2), int(r * 2)), Color("467a3e"))
			elif b.type == "plaza":
				img.fill_rect(Rect2i(int(o.x * k), int(o.y * k), int(356 * k), int(356 * k)), Color("d8c7ad"))
				var c := (o + Vector2(178, 178)) * k
				for y in range(-8, 9):
					for x in range(-8, 9):
						if x * x + y * y <= 64: img.set_pixel(int(c.x) + x, int(c.y) + y, Color("6fb5c9"))
			else:
				for r in b.rects:
					var rr := Rect2i(int(r.x * k), int(r.y * k), int(r.w * k), int(r.h * k))
					img.fill_rect(rr, Color("6b4a44"))
					img.fill_rect(rr.grow(-1), Color(r.get("c", "b98576")))
	if city:
		var m = main.missions if main else null
		if m and not m.club_rect.is_empty():
			var r: Dictionary = m.club_rect
			img.fill_rect(Rect2i(int(r.x * k), int(r.y * k), int(r.w * k), int(r.h * k)), Color("ff7ab8"))
	base = ImageTexture.create_from_image(img)

func _clear_wp() -> void:
	main.missions.set_waypoint(null)

func _radar_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed): toggle_map()

func rebuild_base() -> void:
	_build_base()

# ------------------------------------------------------------------------ state ----------
func talking() -> bool:
	return talk != null

func busy() -> bool:
	return talk != null or shop.visible or big.visible

func toggle_map() -> void:
	if talk != null or shop.visible: return
	big.visible = not big.visible

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo): return
	var k: int = e.keycode
	if talk != null:
		if talk.choice != null and k >= KEY_1 and k <= KEY_9: _pick(k - KEY_1)
		elif talk.choice == null and k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]: _next()
		get_viewport().set_input_as_handled(); return
	if shop.visible:
		if k == KEY_ESCAPE: close_panel()
		elif k >= KEY_1 and k <= KEY_9 and k - KEY_1 < shop_list.get_child_count(): (shop_list.get_child(k - KEY_1) as Button).pressed.emit()
		get_viewport().set_input_as_handled(); return
	if k == KEY_M or (k == KEY_ESCAPE and big.visible): toggle_map(); get_viewport().set_input_as_handled()

# --------------------------------------------------------------------- dialogue ----------
## lines: [who, text]; { choice: [[label, lines]] } offers replies; a Callable in the list runs as it is reached
func say(lines: Array, done: Callable) -> void:
	talk = { "q": lines.duplicate(), "done": done, "choice": null }
	if main.pcar: main.pcar.v = 0
	talk_box.visible = true; _next()

func end_talk() -> void:
	talk = null; talk_box.visible = false

func _next() -> void:
	if talk == null: return
	var L = talk.q.pop_front() if talk.q.size() else null
	while L is Callable: L.call(); L = talk.q.pop_front() if talk.q.size() else null
	for b in talk_btns.get_children(): talk_btns.remove_child(b); b.queue_free()
	if L == null:
		var d: Callable = talk.done; end_talk(); if d.is_valid(): d.call()
		return
	if L is Dictionary:
		talk.choice = L.choice
		talk_who.text = "Դու"; talk_who.add_theme_color_override("font_color", Color("f1ede6")); talk_text.text = "Ի՞նչ ես պատասխանում"
		for n in L.choice.size(): _talk_btn("%d · %s" % [n + 1, L.choice[n][0]], _pick.bind(n))
		return
	talk.choice = null
	var c: Dictionary = main.missions.CAST[L[0]]
	talk_who.text = c.name; talk_who.add_theme_color_override("font_color", Color(c.col)); talk_text.text = L[1]
	_talk_btn("Շարունակել ›" if talk.q.size() else "Լավ", _next)

func _talk_btn(text: String, cb: Callable) -> void:
	var b := Button.new(); b.text = text; b.add_theme_font_size_override("font_size", 17); b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(cb); talk_btns.add_child(b)

func _pick(n: int) -> void:
	if talk == null or talk.choice == null or n >= talk.choice.size(): return
	var o: Array = talk.choice[n]; var front: Array = [["you", o[0]]] + o[1]
	talk.q = front + talk.q; _next()

# ------------------------------------------------------------------------ panels ----------
## items: [{ label, sub, price, go: Callable, on, disabled }]
func panel(title: String, text: String, items: Array) -> void:
	shop_title.text = title; shop_text.text = text
	for b in shop_list.get_children(): shop_list.remove_child(b); b.queue_free()
	for it in items:
		var b := Button.new(); b.text = it.label + (("   " + it.price) if it.has("price") else ""); b.add_theme_font_size_override("font_size", 18)
		b.custom_minimum_size = Vector2(0, 50); b.disabled = it.get("disabled", false); b.pressed.connect(it.go); shop_list.add_child(b)
	if main.pcar: main.pcar.v = 0
	shop.visible = true

func close_panel() -> void:
	shop.visible = false

func chapter_card(kick: String, title: String) -> void:
	card_kick.text = kick; card.text = title
	var tw := create_tween(); card_box.modulate.a = 0
	tw.tween_property(card_box, "modulate:a", 1.0, 0.4); tw.tween_interval(2.0); tw.tween_property(card_box, "modulate:a", 0.0, 0.8)

# ------------------------------------------------------------------------ per frame ----------
func _process(_dt: float) -> void:
	if main == null: return
	var s := get_viewport_rect().size; var small := minf(s.x, s.y) < 500
	var D := 140.0 if small else 180.0
	radar.size = Vector2(D, D); radar.position = Vector2(s.x - D - 16, 12); radar.visible = not big.visible
	var line: Array = main.missions.hud_line()
	job_panel.visible = line[0] != "" and not busy() and main.interior.inside == ""
	job_text.text = line[0]; job_time.text = line[1]; job_text.add_theme_color_override("font_color", line[2])
	job_panel.reset_size(); job_panel.position = Vector2((s.x - job_panel.size.x) / 2, 12)
	if big.visible:
		var B := minf(s.x - 32, s.y - 32); big_draw.size = Vector2(B, B); big_draw.position = Vector2((s.x - B) / 2, (s.y - B) / 2)
		(big.get_meta("clr") as Control).visible = main.missions.wp != null
		big_draw.queue_redraw()
	var tw := minf(760, s.x - 32); talk_box.size = Vector2(tw, 0); talk_box.reset_size(); talk_box.size.x = tw
	talk_box.position = Vector2((s.x - tw) / 2, s.y - talk_box.size.y - 18)
	var sw := minf(520, s.x - 32); shop.size.x = sw; shop.reset_size(); shop.size.x = sw; shop.position = (s - shop.size) / 2
	card_box.reset_size(); card_box.position = Vector2((s.x - card_box.size.x) / 2, s.y * 0.3)
	radar_draw.queue_redraw(); (radar.get_meta("north") as Control).queue_redraw()

func _th() -> float:
	return -PI / 2 - main.cam_a

func _draw_north(c: Control) -> void:
	var R := c.size.x / 2; var th := _th()
	var p := Vector2(R + sin(th) * (R - 15), R - cos(th) * (R - 15))
	c.draw_circle(p, 12, Color(0.05, 0.05, 0.07, 0.9))
	c.draw_string(font, p + Vector2(-6, 6), "Հ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

func _draw_radar() -> void:
	var c := radar_draw; var C := c.size.x; var R := C / 2; var th := _th(); var z := C / 1500.0
	var ctr: Vector2 = main.map_pos()
	var X := Transform2D(th, Vector2(z, z), 0, Vector2(R, R)) * Transform2D(0, -ctr)
	c.draw_set_transform_matrix(X)
	c.draw_texture_rect(base, Rect2(0, 0, WS, WS), false)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	var ms = main.missions
	if ms.wp != null:
		var pts := PackedVector2Array()
		for p in ms.route(ctr): pts.append(X * p)
		_stroke(c, pts, 5)
	var flash := int(main.time * 6) % 2 == 0
	for car in main.cars:
		if car.kind == "police" and car.chase: c.draw_circle(X * Vector2(car.x, car.y), 6, Color("ff5a5f") if flash else Color("4d8dff"))
	for it in ms.map_items():
		var q: Vector2 = X * it.p; var d := q - Vector2(R, R); var lim := R - 16
		if d.length() > lim: q = Vector2(R, R) + d.normalized() * lim
		_badge(c, it.kind, q, 13 if it.get("big", false) else 10, it.get("n", 0))
	var head: float = main.pcar.a if main.pcar else main.me.a
	_arrow(c, Vector2(R, R), head + th, 13)

func _draw_big() -> void:
	var c := big_draw; var S := c.size.x; var k := S / WS
	c.draw_texture_rect(base, Rect2(0, 0, S, S), false)
	var ms = main.missions; var flash := int(main.time * 6) % 2 == 0
	if ms.wp != null:
		var pts := PackedVector2Array()
		for p in ms.route(main.map_pos()): pts.append(p * k)
		_stroke(c, pts, 7)
	for car in main.cars:
		if car.kind == "police" and car.chase: c.draw_circle(Vector2(car.x, car.y) * k, 7, Color("ff5a5f") if flash else Color("4d8dff"))
	if ms.act != null and ms.act.get("cps"):
		var cur: int = ms.act.ci if ms.story_on() else ms.act.k
		for n in ms.act.cps.size():
			if n > cur: _badge(c, "cp", Vector2(ms.act.cps[n].x, ms.act.cps[n].y) * k, 12, n + 1)
	for it in ms.map_items():
		var q: Vector2 = it.p * k
		_badge(c, it.kind, q, 17 if it.get("big", false) else 14, it.get("n", 0))
		if it.has("name"):
			var w := font.get_string_size(it.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			c.draw_string_outline(font, q + Vector2(-w / 2, 34), it.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0.05, 0.05, 0.07, 0.9))
			c.draw_string(font, q + Vector2(-w / 2, 34), it.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	var head: float = main.pcar.a if main.pcar else main.me.a
	_arrow(c, main.map_pos() * k, head, 16)

func _big_input(e: InputEvent) -> void:
	var pos := Vector2.INF
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: pos = e.position
	elif e is InputEventScreenTouch and e.pressed: pos = e.position
	if pos == Vector2.INF: return
	var ms = main.missions; var k := big_draw.size.x / WS
	if ms.wp != null and (ms.wp * k).distance_to(pos) < 26: ms.set_waypoint(null); return
	for it in ms.map_items():
		if it.kind != "wp" and (it.p * k).distance_to(pos) < 26: ms.set_waypoint(it.p); return
	ms.set_waypoint(ms.snap_road(pos / k).p)

func _stroke(c: Control, pts: PackedVector2Array, w: float) -> void:
	if pts.size() < 2: return
	c.draw_polyline(pts, Color(0.05, 0.05, 0.07, 0.85), w + 4, true)
	c.draw_polyline(pts, Color("ff9f1c"), w, true)

func _arrow(c: Control, p: Vector2, a: float, s: float) -> void:
	var pts := PackedVector2Array([Vector2(s, 0), Vector2(-s * 0.7, -s * 0.7), Vector2(-s * 0.35, 0), Vector2(-s * 0.7, s * 0.7)])
	var xf := Transform2D(a, p); var out := PackedVector2Array()
	for q in pts: out.append(xf * q)
	var ol := out.duplicate(); ol.append(out[0])
	c.draw_colored_polygon(out, Color.WHITE); c.draw_polyline(ol, Color(0.05, 0.05, 0.07, 0.9), 2.5, true)

const GLYPH := { "club": "Ն", "race": "Մ", "escape": "Փ", "story": "!", "rival": "Լ", "square": "Հ" }
func _badge(c: Control, kind: String, p: Vector2, r: float, n: int) -> void:
	var col := Color(main.missions.ICON.get(kind, "ffffff"))
	c.draw_circle(p, r + 2.5, Color(0.05, 0.05, 0.07, 0.85))
	c.draw_circle(p, r, col)
	var fs := int(r * 1.15)
	var g := ""
	if kind == "cp": g = str(n)
	elif GLYPH.has(kind): g = GLYPH[kind]
	if g != "":
		var w := font.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		c.draw_string(font, p + Vector2(-w / 2, fs * 0.36), g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	elif kind == "pickup": c.draw_rect(Rect2(p - Vector2(r, r) * 0.5, Vector2(r, r)), Color.WHITE)
	else: c.draw_circle(p, r * 0.4, Color.WHITE)
