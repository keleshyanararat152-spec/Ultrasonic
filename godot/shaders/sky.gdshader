shader_type sky;
// A painted sky: a gradient, the sun (or the moon) with a glow, drifting clouds and stars at night.
uniform vec3 top_col = vec3(0.37, 0.6, 0.82);
uniform vec3 hor_col = vec3(0.94, 0.82, 0.71);
uniform vec3 gnd_col = vec3(0.54, 0.49, 0.45);
uniform vec3 cloud_col = vec3(1.0);
uniform vec3 sun_col = vec3(1.0, 0.9, 0.75);
uniform float night = 0.0;
uniform float cover = 0.55;
uniform float t = 0.0;
uniform float overcast = 0.0;   // grey rain clouds (weather.gd)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int k = 0; k < 5; k++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = h > 0.0 ? mix(hor_col, top_col, pow(clamp(h, 0.0, 1.0), 0.45)) : mix(hor_col, gnd_col, clamp(-h * 5.0, 0.0, 1.0));
	float sd = LIGHT0_ENABLED ? dot(d, LIGHT0_DIRECTION) : -1.0;
	if (sd > -1.0) {
		col += sun_col * (pow(max(sd, 0.0), 10.0) * 0.25 + pow(max(sd, 0.0), 300.0) * 0.8);
	}
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 1.3 + vec2(t * 0.006, t * 0.002);
		float n = fbm(uv);
		float c = smoothstep(1.0 - cover, 1.0 - cover + 0.28, n) * smoothstep(0.0, 0.18, h);
		vec3 lit = cloud_col * (0.82 + 0.25 * pow(max(sd, 0.0), 4.0)) * mix(1.0, 0.78, smoothstep(0.55, 0.9, n));
		// stars behind the clouds at night
		vec2 sp = d.xz / (h + 0.05) * 90.0;
		float star = step(0.9965, hash(floor(sp))) * night * smoothstep(0.08, 0.3, h);
		col += vec3(star) * 1.4;
		col = mix(col, lit, c * 0.9);
	}
	if (sd > -1.0) col += sun_col * smoothstep(0.99955, 0.9998, sd) * (night > 0.5 ? 1.2 : 5.0);
	float lum = dot(col, vec3(0.3, 0.55, 0.15));
	col = mix(col, vec3(lum) * vec3(0.92, 0.95, 1.0) * 0.8, overcast * 0.75);
	COLOR = col;
}
