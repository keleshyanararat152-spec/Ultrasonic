shader_type spatial;
render_mode cull_disabled;
// Grass blades: dark at the root, lighter and yellower at the tip, bending in the wind (more at the top),
// lit through from behind. COLOR.a is how far up the blade a vertex is.
uniform vec3 root_col : source_color = vec3(0.13, 0.22, 0.07);
uniform vec3 tip_col : source_color = vec3(0.52, 0.66, 0.26);
uniform float wind = 1.0;
global uniform float wetness;
varying float hgt;
varying vec3 tint;

void vertex() {
	hgt = COLOR.a;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = 0.55 + 0.45 * sin(TIME * 0.7 + wp.x * 0.08 + wp.z * 0.05);
	float b = (sin(TIME * 2.1 + wp.x * 0.9 + wp.z * 0.7) * 0.6 + sin(TIME * 3.3 + wp.z * 1.3) * 0.25) * gust * wind;
	VERTEX.x += b * 0.12 * hgt * hgt;
	VERTEX.z += b * 0.06 * hgt * hgt;
	tint = COLOR.rgb;
}

void fragment() {
	vec3 c = mix(root_col, tip_col, hgt) * tint;
	ALBEDO = c * (1.0 - 0.25 * wetness);
	ROUGHNESS = mix(0.75, 0.3, wetness);
	SPECULAR = 0.3;
	BACKLIGHT = c * 0.6;
	AO = mix(0.35, 1.0, hgt);
	AO_LIGHT_AFFECT = 0.5;
}
