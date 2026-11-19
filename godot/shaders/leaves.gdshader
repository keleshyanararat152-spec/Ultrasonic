shader_type spatial;
render_mode cull_disabled;
// Leaf cards: cut out of the leaf picture, lit through from behind, swaying in the wind (more towards the top).
uniform sampler2D leaves : source_color, filter_linear_mipmap_anisotropic;
uniform float wind = 1.0;
varying vec3 tint;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float gust = 0.6 + 0.4 * sin(TIME * 0.35 + wp.x * 0.01);
	float sway = sin(TIME * 1.2 + wp.x * 0.15 + wp.z * 0.11) * 0.012 * h * gust * wind;
	float flutter = sin(TIME * 4.7 + VERTEX.x * 3.1 + VERTEX.z * 2.3 + wp.x) * 0.025 * wind * smoothstep(1.0, 4.0, h);
	VERTEX.x += sway + flutter; VERTEX.z += sway * 0.6 - flutter * 0.5; VERTEX.y += flutter * 0.4;
	tint = COLOR.rgb;
}

void fragment() {
	vec4 c = texture(leaves, UV);
	ALBEDO = c.rgb * tint;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ROUGHNESS = 0.65;
	SPECULAR = 0.35;
	BACKLIGHT = c.rgb * 0.55;
}
