shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D detail : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float h = world_pos.y;
	vec3 lowland = vec3(0.36, 0.16, 0.11);
	vec3 midland = vec3(0.62, 0.34, 0.16);
	vec3 highland = vec3(0.55, 0.42, 0.28);
	vec3 rock = vec3(0.28, 0.25, 0.23);
	vec3 pool = vec3(0.04, 0.22, 0.24);
	vec3 vein = vec3(0.08, 0.45, 0.42);
	float t = clamp((h + 1.2) / 7.5, 0.0, 1.0);
	vec3 albedo = mix(lowland, midland, smoothstep(0.05, 0.45, t));
	albedo = mix(albedo, highland, smoothstep(0.4, 0.85, t));
	albedo = mix(albedo, rock, smoothstep(0.72, 1.0, t));
	albedo = mix(albedo, pool, clamp((-h - 0.2) * 1.4, 0.0, 1.0));
	float n = texture(detail, world_pos.xz * 0.08).r;
	albedo *= mix(0.82, 1.08, n);
	float mineral = texture(detail, world_pos.xz * 0.03 + vec2(0.37, 0.11)).r;
	albedo = mix(albedo, vein, smoothstep(0.68, 0.9, mineral) * 0.65);
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	albedo = mix(albedo, albedo * vec3(0.55, 0.5, 0.48), smoothstep(0.25, 0.7, slope));
	ALBEDO = albedo;
	ROUGHNESS = mix(0.92, 0.7, n);
	SPECULAR = 0.12;
}
