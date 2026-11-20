shader_type spatial;
// Yerevan walls: cut tuff (or concrete for the Soviet blocks) in the building's colour, a dark basalt plinth,
// weathering, and painted windows that only show from afar, where the real 3D windows are not drawn.
// UV is in metres: along the wall, and up it. COLOR: the stone colour; alpha picks one of two stones.
uniform sampler2D stone : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone2 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone2_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float near_windows = 140.0;   // closer than this the 3D windows are there
global uniform float wetness;
uniform float night = 0.0;
varying float dist;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz); }
void fragment() {
	vec2 uv = UV;
	bool second = COLOR.a < 0.5;
	vec3 st = second ? texture(stone2, uv / 3.0).rgb : texture(stone, uv / 3.6).rgb;
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	float lum = dot(st, vec3(0.3, 0.5, 0.2));
	vec3 c = mix(vec3(lum), st, 0.3) * tint * 1.9;
	c *= 0.86 + 0.14 * hash(floor(uv * vec2(0.5, 0.3)));
	c *= 1.0 - 0.3 * (1.0 - smoothstep(0.0, 2.2, uv.y));      // grime near the ground
	if (uv.y < 0.85) c = vec3(0.07, 0.07, 0.075) * (0.9 + 0.2 * lum);   // the basalt plinth
	float rough = 0.85;
	// painted windows, faded in with distance
	float far_k = smoothstep(near_windows - 20.0, near_windows + 10.0, dist);
	if (far_k > 0.0 && uv.y > 3.3) {
		vec2 cell = vec2(mod(uv.x, 3.2), mod(uv.y - 0.2, 3.3));
		float w = step(0.95, cell.x) * step(cell.x, 2.25) * step(1.1, cell.y) * step(cell.y, 2.75);
		vec2 id = floor(vec2(uv.x / 3.2, (uv.y - 0.2) / 3.3));
		vec3 glass = mix(vec3(0.05, 0.06, 0.08), vec3(1.0, 0.78, 0.45) * 1.6, step(0.55, hash(id + 7.0)) * night);
		c = mix(c, glass, w * far_k); rough = mix(rough, 0.1, w * far_k);
		EMISSION = glass * w * far_k * night * step(0.55, hash(id + 7.0)) * 0.8;
	}
	ALBEDO = c * (1.0 - 0.3 * wetness);
	ROUGHNESS = rough * (1.0 - 0.4 * wetness);
	NORMAL_MAP = second ? texture(stone2_n, uv / 3.0).rgb : texture(stone_n, uv / 3.6).rgb;
}
