shader_type canvas_item;
render_mode blend_mix;

void fragment() {
	float shade = smoothstep(0.72, 0.22, UV.x);
	float vignette = smoothstep(1.15, 0.35, length(UV - vec2(0.35, 0.5)));
	float alpha = max(shade * 0.92, (1.0 - vignette) * 0.35);
	COLOR = vec4(0.012, 0.018, 0.024, alpha);
}
