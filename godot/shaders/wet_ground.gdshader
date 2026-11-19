shader_type spatial;
// Streets and pavements that get wet in the rain: darker, glossier stone, puddles in the hollows that
// mirror the city (SSR) and rings where the drops land. wetness / rain are set by weather.gd.
uniform sampler2D diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pnoise : filter_linear, repeat_enable;   // where the puddles gather
uniform vec3 tint : source_color = vec3(1.0);
uniform float size = 4.0;          // one texture image, in Godot units
uniform float nscale = 1.0;
uniform float keeps_water = 1.0;   // how readily this surface holds puddles
global uniform float wetness;
global uniform float rain;
varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// rain rings: one drop per cell at a random moment, a ring spreading and fading
vec2 ripples(vec2 p, float t) {
	vec2 acc = vec2(0.0);
	for (int layer = 0; layer < 2; layer++) {
		vec2 q = p * (layer == 0 ? 2.2 : 3.1) + float(layer) * 7.3;
		vec2 cell = floor(q);
		vec2 f = fract(q) - 0.5 - (vec2(hash(cell), hash(cell + 3.7)) - 0.5) * 0.5;
		float ph = fract(t * 1.4 + hash(cell + 1.3));
		float d = length(f) + 1e-4;
		float r = ph * 0.45;
		float w = sin(clamp((d - r) * 45.0, -PI, PI)) * (1.0 - ph) * (1.0 - ph) * step(abs(d - r), 0.07);
		acc += f / d * w;
	}
	return acc;
}

void fragment() {
	vec3 an = abs(wn);
	vec2 uv = an.y > 0.5 ? wp.xz : (an.x > an.z ? wp.zy : wp.xy);
	uv /= size;
	vec3 base = texture(diff, uv).rgb * tint;
	float r = texture(rough, uv).r;
	vec3 nm = texture(nor, uv).rgb;
	float top = step(0.5, wn.y);
	// puddles: big soft patches, filling up as the city gets wetter
	float pn = texture(pnoise, wp.xz * 0.018).r * 0.7 + texture(pnoise, wp.xz * 0.07 + 0.37).r * 0.3;
	float thr = mix(1.2, 0.57, wetness * keeps_water);
	float pud = smoothstep(thr, thr + 0.06, pn) * top;
	float damp = wetness * (0.6 + 0.4 * top);
	// wet stone darkens and turns glossy, puddles are a dark mirror
	base *= mix(1.0, 0.55, damp);
	base = mix(base, base * 0.35 + vec3(0.01), pud);
	r = mix(r, r * 0.35 + 0.08, damp);
	r = mix(r, 0.02, pud);
	nm = mix(nm, vec3(0.5, 0.5, 1.0), max(pud, damp * 0.5));
	vec2 rip = ripples(wp.xz, TIME) * rain * (0.08 + 0.92 * pud) * top;
	nm.xy += rip * 0.22;
	ALBEDO = base;
	ROUGHNESS = r;
	SPECULAR = mix(0.5, 0.9, max(damp, pud));
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = nscale;
}
