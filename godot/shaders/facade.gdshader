shader_type spatial;
// Building walls: the window layout from the baked facade, and on the wall parts cut stone blocks in the
// building's own tuff colour (the multimesh instance colour), with their relief and roughness.
uniform sampler2D facade : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D facade_r : filter_linear_mipmap_anisotropic, repeat_enable;     // dark = glass, light = wall
uniform sampler2D stone : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_r : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 fac_size = vec2(56.2, 39.0);   // the area one facade image covers, in Godot units
uniform float stone_size = 3.6;               // one stone image, in Godot units
uniform bool srgb_tint = true;
varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 an = abs(wnrm);
	bool side_x = an.x > an.z;
	float h = side_x ? -wpos.z : wpos.x;
	vec2 fuv = vec2(h / fac_size.x, -wpos.y / fac_size.y);
	vec3 fac = texture(facade, fuv).rgb;
	float wall = smoothstep(0.35, 0.7, texture(facade_r, fuv).r);
	vec2 suv = vec2(h, -wpos.y) / stone_size;
	vec3 tint = srgb_tint ? pow(COLOR.rgb, vec3(2.2)) : COLOR.rgb;
	vec3 st = texture(stone, suv).rgb;
	float lum = dot(st, vec3(0.3, 0.5, 0.2));
	vec3 stone_col = mix(vec3(lum), st, 0.35) * mix(tint, vec3(dot(tint, vec3(0.33))), 0.15) * 1.75 * (0.75 + 0.25 * clamp(dot(fac, vec3(0.33)) / 0.8, 0.0, 1.2));
	ALBEDO = mix(fac * 0.55, stone_col, wall);
	ROUGHNESS = mix(0.06, texture(stone_r, suv).r, wall);
	SPECULAR = mix(0.9, 0.4, wall);
	METALLIC = 0.0;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), texture(stone_n, suv).rgb, wall);
	NORMAL_MAP_DEPTH = 1.3;
}
