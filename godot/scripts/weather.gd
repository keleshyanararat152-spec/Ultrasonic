extends Node3D
## Weather: clear, cloudy, rainy and foggy spells that follow one another by themselves. Clouds cover the
## photographed sky, the sun dims, fog thickens; in the rain drops fall round the camera, splash on the ground
## and the streets and walls get wet (the `wetness` / `rain` shader globals), drying slowly afterwards.

const KINDS := {   # cloud cover, sun, extra fog, rain, haze in the light
	"clear":  { "cover": 0.28, "sun": 1.0,  "fog": 0.0,    "rain": 0.0, "vfog": 0.0,   "name": "Պարզ եղանակ" },
	"cloudy": { "cover": 0.72, "sun": 0.55, "fog": 0.0006, "rain": 0.0, "vfog": 0.002, "name": "Ամպամած է" },
	"rain":   { "cover": 0.95, "sun": 0.28, "fog": 0.0018, "rain": 1.0, "vfog": 0.006, "name": "Անձրև է գալիս" },
	"fog":    { "cover": 0.6,  "sun": 0.45, "fog": 0.009,  "rain": 0.0, "vfog": 0.03,  "name": "Մառախուղ է" },
}
const NEXT := { "clear": ["clear", "cloudy", "cloudy", "fog"], "cloudy": ["clear", "rain", "rain", "fog"], "rain": ["cloudy", "clear"], "fog": ["clear", "cloudy"] }

var m                      # main
var kind := "clear"
var cur := {}              # the blended values now
var spell := 150.0         # seconds left of this spell
var wet := 0.0             # how wet the city is, 0..1
var auto := true
var drops: GPUParticles3D
var splash: GPUParticles3D
var rain_mat: ParticleProcessMaterial

func setup(main) -> void:
	m = main
	for k in ["cover", "sun", "fog", "rain", "vfog"]: cur[k] = KINDS.clear[k]
	if not m.hi: return
	drops = GPUParticles3D.new(); drops.amount = 9000; drops.lifetime = 1.1; drops.local_coords = false
	drops.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80)); drops.preprocess = 1.0
	rain_mat = ParticleProcessMaterial.new()
	rain_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX; rain_mat.emission_box_extents = Vector3(32, 1, 32)
	rain_mat.direction = Vector3(0.08, -1, 0.04); rain_mat.spread = 2.0; rain_mat.initial_velocity_min = 22; rain_mat.initial_velocity_max = 28
	rain_mat.gravity = Vector3(0, -9.8, 0)
	drops.process_material = rain_mat
	var q := QuadMesh.new(); q.size = Vector2(0.012, 0.6)
	var dm := StandardMaterial3D.new(); dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.78, 0.82, 0.9, 0.28); dm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y; dm.disable_receive_shadows = true
	q.material = dm; drops.draw_pass_1 = q
	drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; drops.emitting = false
	add_child(drops)
	splash = GPUParticles3D.new(); splash.amount = 2500; splash.lifetime = 0.28; splash.local_coords = false
	splash.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 10, 60))
	var sm := ParticleProcessMaterial.new()
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX; sm.emission_box_extents = Vector3(22, 0.01, 22)
	sm.direction = Vector3(0, 1, 0); sm.spread = 35; sm.initial_velocity_min = 0.6; sm.initial_velocity_max = 1.4; sm.gravity = Vector3(0, -9.8, 0)
	sm.scale_min = 0.5; sm.scale_max = 1.2
	splash.process_material = sm
	var sq := QuadMesh.new(); sq.size = Vector2(0.03, 0.03)
	var smat := StandardMaterial3D.new(); smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(0.85, 0.9, 0.95, 0.45); smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sq.material = smat; splash.draw_pass_1 = sq; splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; splash.emitting = false
	add_child(splash)

func set_kind(k: String, instant := false) -> void:
	kind = k; spell = randf_range(110, 240)
	if instant:
		for key in cur: cur[key] = KINDS[k][key]
		wet = 1.0 if k == "rain" else 0.0

func tick(dt: float) -> void:
	if auto:
		spell -= dt
		if spell <= 0:
			var was := kind
			set_kind(NEXT[kind].pick_random())
			if kind != was and m.interior.inside == "": m.toast(KINDS[kind].name, 2.5)
	var f := minf(1.0, dt / 25.0)   # spells change over about half a minute
	for key in cur: cur[key] += (KINDS[kind][key] - cur[key]) * f
	var r: float = cur.rain
	if r > 0.3: wet = minf(1.0, wet + dt / 35.0 * r)
	else: wet = maxf(0.0, wet - dt / 120.0)
	var indoors: bool = m.interior.inside != ""
	RenderingServer.global_shader_parameter_set("wetness", wet)
	RenderingServer.global_shader_parameter_set("rain", 0.0 if indoors else r)
	if drops:
		var on := r > 0.05 and not indoors
		drops.emitting = on; splash.emitting = on and wet > 0.2
		drops.amount_ratio = clampf(r, 0.05, 1.0); splash.amount_ratio = clampf(r * wet, 0.05, 1.0)
		var c: Vector3 = m.cam.global_position
		var ahead: Vector3 = -(m.cam.global_transform.basis.z as Vector3); ahead.y = 0
		drops.global_position = c + ahead.normalized() * 14 + Vector3(0, 18, 0)
		splash.global_position = Vector3(c.x, 0.02, c.z) + ahead.normalized() * 12

## Called after the day/night sets the sky and light: the weather dims, covers and fogs on top.
func apply(night: float) -> void:
	if m.interior.inside != "": return
	m.sun.light_energy *= cur.sun
	m.env.fog_density = (0.0015 if m.hi else 0.0022) + cur.fog
	var grey: float = clampf((cur.cover - 0.3) / 0.65, 0.0, 1.0)
	m.env.fog_light_color = m.env.fog_light_color.lerp(Color(0.55, 0.58, 0.62) * (1.0 - night * 0.8), grey * 0.6)
	m.env.ambient_light_color = m.env.ambient_light_color.lerp(Color(0.5, 0.54, 0.6) * (1.0 - night * 0.7), grey * 0.4)
	if m.hi: m.env.volumetric_fog_density += cur.vfog
	m.sky_mat.set_shader_parameter("cover", cur.cover)
	m.sky_mat.set_shader_parameter("overcast", grey)
	m.sky_mat.set_shader_parameter("cloud_col", (m.sky_mat.get_shader_parameter("cloud_col") as Color).lerp(Color(0.6, 0.62, 0.66) * (1.0 - night * 0.8), grey * 0.7))
