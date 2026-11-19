shader_type sky;
// Photographed skies (Poly Haven, the Qwantani series: one place at six times of day), two blended by the
// hour, each turned so its sun sits where the game's sun is; light clouds drift over them.
uniform sampler2D sky_a : source_color, filter_linear, repeat_enable;
uniform sampler2D sky_b : source_color, filter_linear, repeat_enable;
uniform float mixk = 0.0;
uniform float sun_u_a = 0.6;   // where the sun is in each photo (0..1 across)
uniform float sun_u_b = 0.6;
uniform float bright = 1.0;
uniform vec3 cloud_col = vec3(1.0);
uniform float cover = 0.32;
uniform float night = 0.0;
uniform float t = 0.0;

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
vec3 pano(sampler2D s, vec3 d, float rot) {
	float u = atan(d.x, -d.z) / (2.0 * PI) + 0.5 + rot;
	float v = acos(clamp(d.y, -1.0, 1.0)) / PI;
	return texture(s, vec2(u, v)).rgb;
}

void sky() {
	vec3 d = EYEDIR;
	float us = 0.5;
	if (LIGHT0_ENABLED) us = atan(LIGHT0_DIRECTION.x, -LIGHT0_DIRECTION.z) / (2.0 * PI) + 0.5;
	vec3 col = mix(pano(sky_a, d, sun_u_a - us), pano(sky_b, d, sun_u_b - us), mixk) * bright;
	if (d.y > 0.0) {
		vec2 uv = d.xz / (d.y + 0.12) * 1.3 + vec2(t * 0.006, t * 0.002);
		float n = fbm(uv);
		float c = smoothstep(1.0 - cover, 1.0 - cover + 0.3, n) * smoothstep(0.0, 0.2, d.y);
		float sd = LIGHT0_ENABLED ? max(dot(d, LIGHT0_DIRECTION), 0.0) : 0.0;
		vec3 lit = cloud_col * (0.85 + 0.3 * pow(sd, 4.0)) * mix(1.0, 0.75, smoothstep(0.55, 0.9, n));
		col = mix(col, lit, c * 0.8);
	}
	COLOR = col;
}
