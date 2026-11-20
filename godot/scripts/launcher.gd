extends Control
## The first screen: pick the map — the made-up Pink City with its story, or Yerevan from the real map.
## Test runs (any command-line flag after --) go straight into the game.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		Engine.set_meta("map", "yerevan" if args.has("--yerevan") else "pink")
		_go.call_deferred(); return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = Color(0.08, 0.06, 0.1); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var v := VBoxContainer.new(); v.set_anchors_preset(Control.PRESET_CENTER); v.add_theme_constant_override("separation", 18)
	v.position = Vector2(-260, -170); v.custom_minimum_size = Vector2(520, 0); add_child(v)
	var t := Label.new(); t.text = "Ընտրիր քարտեզը"; t.add_theme_font_size_override("font_size", 40); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	for e in [["Վարդագույն քաղաք", "պատմություն, առաքումներ, ակումբ, տուն", "pink", Color("ff4fa3")],
			["Երևան", "Հանրապետության հրապարակ ու կենտրոնը՝ իսկական քարտեզով", "yerevan", Color("e3a066")]]:
		var b := Button.new(); b.text = e[0] + "\n" + e[1]; b.custom_minimum_size = Vector2(520, 96)
		b.add_theme_font_size_override("font_size", 22); b.add_theme_color_override("font_color", e[3])
		b.pressed.connect(_pick.bind(e[2])); v.add_child(b)
	var c := Label.new(); c.text = "Երևանի քարտեզը՝ © OpenStreetMap contributors"; c.add_theme_font_size_override("font_size", 13)
	c.add_theme_color_override("font_color", Color("8a8580")); c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(c)

func _pick(map: String) -> void:
	Engine.set_meta("map", map); _go()

func _go() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
