shader_type canvas_item;
// Speed blur: the picture smeared out from the middle, only towards the edges, stronger the faster you drive.
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
uniform vec2 centre = vec2(0.5, 0.45);

void fragment() {
	vec2 d = SCREEN_UV - centre;
	float edge = smoothstep(0.12, 0.6, length(d * vec2(1.6, 1.0)));
	vec2 stepv = d * 0.035 * amount * edge;
	vec3 acc = vec3(0.0);
	for (int k = 0; k < 8; k++) acc += textureLod(screen, SCREEN_UV - stepv * float(k), 0.0).rgb;
	COLOR = vec4(acc / 8.0, 1.0);
}
