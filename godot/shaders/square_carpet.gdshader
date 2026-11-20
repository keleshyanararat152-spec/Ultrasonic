shader_type spatial;
// Republic Square's oval: a stone "carpet" laid in light and dark tuff and basalt, rings round the middle and
// a pattern of rays and lozenges between them, like the square's paving.
uniform vec2 centre = vec2(0.0);      // Godot units
uniform vec2 radius = vec2(40.0, 40.0);
uniform vec3 c_light : source_color = vec3(0.86, 0.74, 0.66);
uniform vec3 c_pink : source_color = vec3(0.78, 0.52, 0.46);
uniform vec3 c_dark : source_color = vec3(0.16, 0.15, 0.16);
uniform sampler2D stone : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
global uniform float wetness;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 q = (wp.xz - centre) / radius;
	float r = length(q); float a = atan(q.y, q.x);
	vec3 light = c_light; vec3 pink = c_pink; vec3 dark = c_dark;
	vec3 c = light;
	float ring = fract(r * 6.0);
	if (ring < 0.12) c = dark;                         // basalt rings
	else if (r < 0.5) {
		float rays = abs(fract(a / 6.2832 * 16.0 + r * 1.5) - 0.5);
		c = mix(pink, light, step(0.22, rays));        // a star of pink rays in the middle
	} else {
		float lz = abs(fract(a / 6.2832 * 32.0) - 0.5) + abs(ring - 0.56) * 1.4;
		c = mix(pink, light, step(0.42, lz));          // lozenges in the outer bands
	}
	if (r > 0.97) c = dark;                            // a dark border round the oval
	vec3 tex = texture(stone, wp.xz / 2.0).rgb;
	c *= 0.75 + 0.5 * dot(tex, vec3(0.33));
	ALBEDO = c * (1.0 - 0.35 * wetness);
	ROUGHNESS = mix(0.7, 0.15, wetness);
	SPECULAR = 0.5;
}
