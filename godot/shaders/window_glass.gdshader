shader_type spatial;
// Window glass: dark and mirror-like by day; at night some rooms are lit (INSTANCE_CUSTOM.x), each a little
// different (INSTANCE_CUSTOM.y), brighter towards the ceiling.
uniform float night = 0.0;
varying vec2 room;
void vertex() {
	room = INSTANCE_CUSTOM.xy;
}
void fragment() {
	float lit = step(0.62, room.x) * night;
	vec3 warm = mix(vec3(1.0, 0.62, 0.3), vec3(1.0, 0.85, 0.62), room.y * room.y);
	float grad = 0.55 + 0.45 * UV.y;
	ALBEDO = mix(vec3(0.05, 0.065, 0.08), warm * 0.25, lit);
	ROUGHNESS = 0.04;
	SPECULAR = 0.9;
	EMISSION = warm * lit * (0.5 + 0.7 * room.y) * grad;
}
