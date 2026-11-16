shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;

uniform float visibility = 1.0;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void fragment() {
	vec3 cell = floor(NORMAL * 90.0);
	float n = hash(cell);
	float star = step(0.972, n);
	float twinkle = 0.65 + 0.35 * sin(TIME * (1.5 + n * 6.0) + n * 20.0);
	vec3 col = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.86, 0.7), step(0.99, n));
	ALBEDO = col;
	EMISSION = col * star * twinkle * visibility * 3.0;
	ALPHA = star * visibility;
}
