shader_type spatial;
// The river: green-grey water flowing south (+z), waves carried by the current, mirrors the banks (SSR).
uniform vec3 deep : source_color = vec3(0.06, 0.13, 0.13);
global uniform float rain;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wp.z * 0.35 - TIME * 1.2) * 0.04 + sin(wp.x * 0.9 + TIME * 0.7) * 0.02;
}
void fragment() {
	vec2 p = wp.xz + vec2(0.0, -TIME * 1.1);
	vec2 n = vec2(sin(p.x * 1.7 + p.y * 0.6) + sin(p.x * 0.6 - p.y * 2.3 + TIME * 0.8), cos(p.y * 1.9 + p.x * 0.4) + cos(p.y * 0.7 - p.x * 1.3)) * 0.12;
	n += vec2(sin(p.y * 6.0 + p.x * 3.0), cos(p.x * 5.0 - p.y * 4.0)) * 0.03 * (1.0 + rain * 3.0);
	ALBEDO = deep;
	ROUGHNESS = 0.05 + rain * 0.1;
	SPECULAR = 0.7;
	NORMAL_MAP = normalize(vec3(n * 0.5 + 0.5, 1.0));
}
