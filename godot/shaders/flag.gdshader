shader_type spatial;
render_mode cull_disabled;
// The flag of Armenia: red, blue, apricot, waving more towards the free end.
void vertex() {
	float k = UV.x;
	VERTEX.z += sin(TIME * 4.0 - UV.x * 6.0) * 0.25 * k;
	VERTEX.y += sin(TIME * 3.0 - UV.x * 5.0) * 0.06 * k;
}
void fragment() {
	vec3 c = UV.y < 0.333 ? vec3(0.82, 0.07, 0.1) : (UV.y < 0.667 ? vec3(0.0, 0.2, 0.63) : vec3(0.95, 0.66, 0.0));
	ALBEDO = c; ROUGHNESS = 0.7; BACKLIGHT = c * 0.4;
}
