shader_type spatial;
render_mode cull_disabled;
// A clock face: pale stone dial, twelve marks, two hands that show the game's time (hour, minute uniforms).
uniform float hour = 10.0;
uniform float minute = 10.0;
uniform float night = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0; float r = length(p);
	if (r > 1.0) discard;
	vec3 c = vec3(0.93, 0.9, 0.82);
	float a = atan(p.x, -p.y);                       // 0 at twelve, clockwise
	float tick = abs(fract(a / 6.2832 * 12.0 + 0.5) - 0.5);
	if (r > 0.78 && r < 0.92 && tick < 0.04) c = vec3(0.08);
	if (r > 0.94) c = vec3(0.55, 0.45, 0.25);
	float ah = (mod(hour, 12.0) + minute / 60.0) / 12.0 * 6.2832; float am = minute / 60.0 * 6.2832;
	vec2 dh = vec2(sin(ah), -cos(ah)); vec2 dm = vec2(sin(am), -cos(am));
	float hh = length(p - dh * clamp(dot(p, dh), 0.0, 0.5)); float mm = length(p - dm * clamp(dot(p, dm), 0.0, 0.75));
	if (hh < 0.045 || mm < 0.03) c = vec3(0.06);
	ALBEDO = c; ROUGHNESS = 0.6;
	EMISSION = c * night * 0.9;
}
