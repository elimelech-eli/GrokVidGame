shader_type canvas_item;
render_mode blend_mix;

uniform float intensity = 0.0;
uniform vec4 hurt_color : source_color = vec4(0.85, 0.08, 0.1, 1.0);

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = smoothstep(0.25, 1.05, length(uv));
	COLOR = vec4(hurt_color.rgb, d * intensity * hurt_color.a);
}
