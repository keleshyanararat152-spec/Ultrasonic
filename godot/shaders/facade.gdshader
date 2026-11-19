shader_type spatial;
// Building walls: the window layout from the baked facade, and on the wall parts cut stone blocks in the
// building's own tuff colour (the multimesh instance colour), with their relief and roughness.
uniform sampler2D facade : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D facade_r : filter_linear_mipmap_anisotropic, repeat_enable;     // dark = glass, light = wall
uniform sampler2D stone : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_r : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 fac_size = vec2(56.2, 39.0);   // the area one facade image covers, in Godot units
uniform sampler2D stone2 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone2_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone2_r : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float stone_size = 3.6;
uniform float stone2_size = 3.0;
uniform float ground = 0.26;     // pavement height: grime gathers above it               // one stone image, in Godot units
uniform bool srgb_tint = true;
uniform bool windows = true;   // false: the walls are all stone; real windows are set on them
global uniform float wetness;
varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec3 an = abs(wnrm);
	bool side_x = an.x > an.z;
	float h = side_x ? -wpos.z : wpos.x;
	vec2 fuv = vec2(h / fac_size.x, -wpos.y / fac_size.y);
	vec3 fac = texture(facade, fuv).rgb;
	float wall = windows ? smoothstep(0.35, 0.7, texture(facade_r, fuv).r) : 1.0;
	vec2 suv = vec2(h, -wpos.y) / stone_size;
	vec3 tint = srgb_tint ? pow(COLOR.rgb, vec3(2.2)) : COLOR.rgb;
	bool second = COLOR.a < 0.5;   // each building one of two stones
	vec2 suv2 = vec2(h, -wpos.y) / stone2_size;
	vec3 st = second ? texture(stone2, suv2).rgb : texture(stone, suv).rgb;
	float lum = dot(st, vec3(0.3, 0.5, 0.2));
	vec3 stone_col = mix(vec3(lum), st, 0.35) * mix(tint, vec3(dot(tint, vec3(0.33))), 0.15) * 1.75 * (0.75 + 0.25 * clamp(dot(fac, vec3(0.33)) / 0.8, 0.0, 1.2));
	// weathering: large soft patches, darker and dirtier near the pavement, streaks under the roof line
	float patch = vnoise(vec2(h, wpos.y) * 0.18) * 0.6 + vnoise(vec2(h, wpos.y) * 0.7) * 0.4;
	float grime = 1.0 - 0.32 * (1.0 - smoothstep(0.0, 2.6, wpos.y - ground));
	float streak = 1.0 - 0.12 * smoothstep(0.55, 0.9, vnoise(vec2(h * 1.7, wpos.y * 0.08)));
	stone_col *= (0.86 + 0.24 * patch) * grime * streak;
	ALBEDO = mix(fac * 0.55, stone_col, wall);
	float sr = second ? texture(stone2_r, suv2).r : texture(stone_r, suv).r;
	ROUGHNESS = mix(0.06, sr, wall);
	SPECULAR = mix(0.9, 0.4, wall);
	METALLIC = 0.0;
	vec3 sn = second ? texture(stone2_n, suv2).rgb : texture(stone_n, suv).rgb;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), sn, wall);
	NORMAL_MAP_DEPTH = 1.3;
	// rain: wet stone is darker and a little glossy, more so low down where the splashes reach
	float wetk = wetness * wall * (0.55 + 0.45 * (1.0 - smoothstep(0.0, 4.0, wpos.y - ground)));
	ALBEDO *= 1.0 - 0.38 * wetk;
	ROUGHNESS = mix(ROUGHNESS, ROUGHNESS * 0.45, wetk);
}
