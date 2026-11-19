extends PanelContainer
## Settings (Esc): picture quality from Low to Ultra, render scale with FSR 2, sound and music volume,
## steering sensitivity, full screen, v-sync and an FPS counter; and the keys. Saved in user://settings.cfg.
## The city waits while it is open.

const PATH := "user://settings.cfg"
const QUALITY := ["Ցածր", "Միջին", "Բարձր", "Ուլտրա"]
const SCALE := ["100% (բնական)", "85% FSR 2 — որակ", "67% FSR 2 — արագ"]
var m
var cfg := { "quality": 2, "scale": 0, "volume": 0.8, "music": 0.8, "steer": 1.0, "fullscreen": false, "vsync": true, "fps": false }
var fps_label: Label
var _rows := {}

func setup(main, layer: CanvasLayer) -> void:
	m = main
	_load()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.07, 0.08, 0.1, 0.94); sb.set_corner_radius_all(14)
	for s in ["left", "right", "top", "bottom"]: sb.set("content_margin_" + s, 22)
	add_theme_stylebox_override("panel", sb)
	set_anchors_preset(Control.PRESET_CENTER); custom_minimum_size = Vector2(560, 0); visible = false
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); add_child(v)
	var t := Label.new(); t.text = "Կարգավորումներ"; t.add_theme_font_size_override("font_size", 28); v.add_child(t)
	_choice(v, "Գրաֆիկայի որակ", QUALITY, "quality")
	_choice(v, "Պատկերի չափ", SCALE, "scale")
	_slider(v, "Ձայն", "volume", 0.0, 1.0)
	_slider(v, "Երաժշտություն", "music", 0.0, 1.0)
	_slider(v, "Ղեկի զգայունություն", "steer", 0.5, 1.5)
	_check(v, "Ամբողջ էկրան", "fullscreen"); _check(v, "V-Sync", "vsync"); _check(v, "Ցույց տալ FPS", "fps")
	var keys := Label.new(); keys.add_theme_font_size_override("font_size", 15); keys.add_theme_color_override("font_color", Color("a9a59c"))
	keys.text = "Կառավարում՝ W/S գազ-արգելակ · A/D ղեկ · Space ձեռքի արգելակ · E նստել/իջնել · M քարտեզ\nR վթարի կրկնություն · P ֆոտոռեժիմ · Esc այս մենյուն\nԳաղտնի կոդեր (պարզապես տպիր)՝ VOSKI փող ու նորոգում · DILIJAN առանց ոստիկանի · KAYTSAK +2 աստղ · HANGIST աստղերը մաքրել · GAGAT 5 աստղ\nZINANOTS բոլոր զենքերը · HAVITYAN անվերջ փամփուշտ · ANVTANG առողջություն ու զրահ\nՄկնիկի ձախ կոճակ՝ կրակել · անիվ/Tab՝ զենք · Q՝ լիցքավորել"
	v.add_child(keys)
	var close := Button.new(); close.text = "Շարունակել (Esc)"; close.pressed.connect(toggle); v.add_child(close)
	layer.add_child(self)
	fps_label = Label.new(); fps_label.add_theme_font_size_override("font_size", 16)
	fps_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); fps_label.position = Vector2(16, -30); layer.add_child(fps_label)
	apply()

func _row(v: VBoxContainer, text: String) -> HBoxContainer:
	var h := HBoxContainer.new(); var l := Label.new(); l.text = text; l.custom_minimum_size = Vector2(230, 0); h.add_child(l); v.add_child(h); return h

func _choice(v: VBoxContainer, text: String, items: Array, key: String) -> void:
	var o := OptionButton.new()
	for it in items: o.add_item(it)
	o.selected = cfg[key]; o.item_selected.connect(_change.bind(key)); _row(v, text).add_child(o); _rows[key] = o

func _slider(v: VBoxContainer, text: String, key: String, lo: float, hi: float) -> void:
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = 0.05; s.value = cfg[key]; s.custom_minimum_size = Vector2(240, 0)
	s.value_changed.connect(_change.bind(key)); _row(v, text).add_child(s); _rows[key] = s

func _check(v: VBoxContainer, text: String, key: String) -> void:
	var c := CheckBox.new(); c.button_pressed = cfg[key]; c.toggled.connect(_change.bind(key)); _row(v, text).add_child(c); _rows[key] = c

func _change(val, key: String) -> void:
	cfg[key] = val; apply(); _save()

func toggle() -> void:
	visible = not visible

func _load() -> void:
	var f := ConfigFile.new()
	if f.load(PATH) != OK: return
	for k in cfg: cfg[k] = f.get_value("game", k, cfg[k])

func _save() -> void:
	var f := ConfigFile.new()
	for k in cfg: f.set_value("game", k, cfg[k])
	f.save(PATH)

## Picture quality: what each level turns on. Ultra is everything; Low keeps the city and lights only.
func apply() -> void:
	var q: int = cfg.quality; var env: Environment = m.env; var vp: Viewport = m.get_viewport()
	if m.hi:
		env.sdfgi_enabled = q >= 3
		env.ssil_enabled = q >= 3
		env.ssr_enabled = q >= 2
		env.ssao_enabled = q >= 1
		env.volumetric_fog_enabled = q >= 2
		env.glow_enabled = true
		m.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q >= 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		m.sun.directional_shadow_max_distance = [110.0, 170.0, 220.0, 260.0][q]
		RenderingServer.directional_shadow_atlas_set_size([2048, 2048, 4096, 4096][q], true)
		for k in m.lamp_lights.size(): (m.lamp_lights[k] as OmniLight3D).shadow_enabled = k < [0, 1, 2, 4][q]
		for g: GeometryInstance3D in m.city.grass_nodes: g.visible = q >= 1; g.visibility_range_end = [0.0, 70.0, 110.0, 150.0][q]
		if m.weather.drops: m.weather.drops.amount_ratio = [0.3, 0.6, 1.0, 1.0][q]
		vp.msaa_3d = Viewport.MSAA_2X if q >= 3 else Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
		var sc: int = cfg.scale
		if sc == 0:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR; vp.scaling_3d_scale = 1.0; vp.use_taa = q >= 1
		else:   # FSR 2 brings its own temporal anti-aliasing
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2; vp.scaling_3d_scale = 0.85 if sc == 1 else 0.67; vp.use_taa = false
		m.cam.far = [700.0, 1000.0, 1400.0, 1400.0][q]
	m.snd.master = cfg.volume
	m.interior.music_level = cfg.music
	m.steer_k = cfg.steer
	if DisplayServer.get_name() != "headless" and not m._test.get("on", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if cfg.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if cfg.vsync else DisplayServer.VSYNC_DISABLED)

func _process(_dt: float) -> void:
	if fps_label:
		fps_label.visible = cfg.fps
		if cfg.fps: fps_label.text = "%d FPS" % Engine.get_frames_per_second()
