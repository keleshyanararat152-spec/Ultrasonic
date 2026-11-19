shader_type spatial;
// The hills: grass on the gentle slopes, bare rock where it is steep and on the high tops, laid in world space.
uniform sampler2D grass_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
global uniform float wetness;
varying vec3 wp;
varying vec3 wn;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	vec2 g = wp.xz / 3.0; vec2 r = wp.xz / 6.0;
	float slope = 1.0 - wn.y;
	float n = vnoise(wp.xz * 0.05);
	float rk = smoothstep(0.22, 0.42, slope + n * 0.12) + smoothstep(50.0, 75.0, wp.y + n * 10.0);
	rk = clamp(rk, 0.0, 1.0);
	vec3 gc = texture(grass_diff, g).rgb * mix(vec3(0.85, 0.95, 0.75), vec3(1.05, 1.0, 0.8), n);
	vec3 rc = texture(rock_diff, r).rgb;
	ALBEDO = mix(gc, rc, rk) * (1.0 - 0.25 * wetness);
	ROUGHNESS = mix(texture(grass_rough, g).r, texture(rock_rough, r).r, rk) * (1.0 - 0.4 * wetness);
	NORMAL_MAP = mix(texture(grass_nor, g).rgb, texture(rock_nor, r).rgb, rk);
}
