extends Node3D
## Shop signs in Armenian over the shop fronts: by day painted letters on a dark board, after dusk glowing
## neon in pink, blue, yellow and green, a few of them flickering. The nearest ones cast coloured light on the
## pavement and the wet street.

const WORDS := ["ՍՐՃԱՐԱՆ", "ԴԵՂԱՏՈՒՆ", "ՀԱՑ", "ԳՐԱԽԱՆՈՒԹ", "ԾԱՂԻԿՆԵՐ", "ԲԱՐ", "ՀՅՈՒՐԱՆՈՑ", "ՄԹԵՐՔ", "ՌԵՍՏՈՐԱՆ", "ԿԻՆՈ", "ԼԱՎԱՇ",
	"ՄՐԳԵՐ", "ԺԱՄԱՑՈՒՅՑՆԵՐ", "ԳԻՆԻ", "ԽՈՐՈՎԱԾ", "ՔԱՂՑՐԵՂԵՆ", "ՕՊՏԻԿԱ", "ՎԱՐՍԱՎԻՐԱՆՈՑ", "ՊԻՑՑԱ", "ԿՈՇԻԿ", "ԽԱՂԱԼԻՔՆԵՐ", "ԳՈՐԳԵՐ",
	"ՍՈՒՐՃ", "ԺԱՆԳՈՒՄ", "ՆՎԵՐՆԵՐ", "ՀԵՌԱԽՈՍՆԵՐ", "ԳՈՀԱՐՆԵՐ", "ՏՊԱՐԱՆ"]
const NEON := [Color(1.0, 0.25, 0.65), Color(0.2, 0.85, 1.0), Color(1.0, 0.82, 0.25), Color(0.35, 1.0, 0.5), Color(1.0, 0.3, 0.25), Color(0.7, 0.45, 1.0)]

var m
var signs: Array = []     # [Label3D, colour, flicker]
var lights: Array = []
var _t := 0.0
var _sorted := -1.0
var _last: Array = []

func build(main) -> void:
	m = main
	var rng := RandomNumberGenerator.new(); rng.seed = 5150
	var font: Font = load("res://fonts/NotoSansArmenian.ttf")
	var board := StandardMaterial3D.new(); board.albedo_color = Color(0.07, 0.07, 0.08); board.roughness = 0.4; board.metallic = 0.3
	var bm := BoxMesh.new(); var xs := []
	for xf: Transform3D in m.city.sign_spots:
		if rng.randf() > 0.7: continue
		var word: String = WORDS[rng.randi() % WORDS.size()]; var col: Color = NEON[rng.randi() % NEON.size()]
		var l := Label3D.new(); l.text = word; l.font = font; l.font_size = 96; l.pixel_size = 0.0085
		l.outline_size = 18; l.outline_modulate = Color(col.r, col.g, col.b, 0.0); l.modulate = col.darkened(0.3)
		l.shaded = false; l.double_sided = false; l.transform = xf.translated_local(Vector3(0, 0, 0.09))
		l.visibility_range_end = 170.0; l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(l)
		var w: float = clampf(word.length() * 0.62 + 0.5, 2.0, 5.6)
		xs.append(Transform3D(xf.basis.scaled(Vector3(w, 0.95, 0.08)), xf.origin))
		signs.append([l, col, rng.randf() < 0.12])
	if xs.size(): m.city._multi(bm, board, xs, false)
	if m.hi:
		for k in 6:
			var o := OmniLight3D.new(); o.omni_range = 9; o.light_energy = 0; o.omni_attenuation = 1.3; add_child(o); lights.append(o)

func frame(dt: float) -> void:
	_t += dt
	var night: float = m.night_k
	var near: Array = []
	var t: Vector2 = m.target_pos()
	for s in signs:
		var l: Label3D = s[0]; var col: Color = s[1]
		var on := night > 0.15
		if s[2] and on and fmod(_t * 7.3 + l.position.x, 5.0) < 0.35: on = false   # a tired tube
		var k := 2.6 * night if on else 0.0
		l.modulate = Color(col.r * (0.55 + k), col.g * (0.55 + k), col.b * (0.55 + k))
		l.outline_modulate = Color(col.r, col.g, col.b, 0.35 * night if on else 0.0)
		if on and night > 0.3 and lights.size():
			var d := Vector2(l.global_position.x * 10.0, l.global_position.z * 10.0).distance_squared_to(t)
			if d < 250000: near.append([d, l, col])
	if _t - _sorted < 0.25 and _last.size(): near = _last
	else: near.sort_custom(func(a, b): return a[0] < b[0]); _sorted = _t; _last = near
	for k in lights.size():
		var o: OmniLight3D = lights[k]
		if k < near.size():
			var l: Label3D = near[k][1]
			o.global_position = l.global_position + l.global_transform.basis.z * 0.9 - Vector3(0, 0.6, 0)
			o.light_color = near[k][2]; o.light_energy = 2.2 * night
		else: o.light_energy = 0
