shader_type spatial;
// Fountain water: a deep green-blue mirror (SSR does the reflections), small waves and rings from the falling jets.
uniform vec3 deep : source_color = vec3(0.05, 0.16, 0.18);
uniform vec3 centre = vec3(0.0);
global uniform float rain;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 p = wp.xz;
	float r = length(p - centre.xz);
	vec2 n = vec2(sin(p.x * 3.1 + TIME * 1.7) + sin(p.y * 2.3 - TIME * 1.3), cos(p.y * 2.9 + TIME * 1.9) + cos(p.x * 2.1 - TIME * 1.1)) * 0.08;
	n += (p - centre.xz) / max(r, 0.01) * sin(r * 9.0 - TIME * 6.0) * 0.12 * exp(-r * 0.25);   // rings spreading from the middle
	vec2 cell = floor(p * 2.0); vec2 f = fract(p * 2.0) - 0.5; float ph = fract(TIME * 1.3 + hash(cell));
	float d = length(f); n += f / max(d, 0.01) * sin(clamp((d - ph * 0.45) * 40.0, -3.14, 3.14)) * (1.0 - ph) * rain * 0.4;
	ALBEDO = deep;
	ROUGHNESS = 0.03;
	METALLIC = 0.0;
	SPECULAR = 0.8;
	NORMAL_MAP = normalize(vec3(n * 0.5 + 0.5, 1.0));
}
