shader_type spatial;
// Pigeons: the wings (vertex colour red) beat while flying (INSTANCE_CUSTOM.r) and lie folded when walking.
uniform vec3 col : source_color = vec3(0.45, 0.47, 0.52);
varying float wing;
void vertex() {
	wing = COLOR.r;
	float fly = INSTANCE_CUSTOM.r; float ph = INSTANCE_CUSTOM.g * 6.283;
	if (COLOR.r > 0.5) {
		float side = sign(VERTEX.z);
		float flap = sin(TIME * 22.0 + ph) * 0.9 * fly;
		float out_ = abs(VERTEX.z) * mix(0.35, 1.0, fly);   // folded against the body when not flying
		VERTEX.y += sin(flap) * out_ * 1.2 + (1.0 - fly) * -0.01;
		VERTEX.z = side * out_ * cos(flap);
	}
}
void fragment() {
	ALBEDO = col * mix(1.0, 0.75, wing);
	ROUGHNESS = 0.75;
}
