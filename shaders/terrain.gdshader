shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D detail : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 v_color;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_color = COLOR.rgb;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 blend = pow(abs(n), vec3(4.0));
	blend /= max(blend.x + blend.y + blend.z, 0.0001);
	float dx = texture(detail, world_pos.zy * 0.11).r;
	float dy = texture(detail, world_pos.xz * 0.11).r;
	float dz = texture(detail, world_pos.xy * 0.11).r;
	float noise = dx * blend.x + dy * blend.y + dz * blend.z;
	vec3 albedo = v_color * mix(0.78, 1.12, noise);
	float slope = 1.0 - clamp(n.y, 0.0, 1.0);
	albedo = mix(albedo, albedo * vec3(0.52, 0.48, 0.45), smoothstep(0.28, 0.72, slope));
	ALBEDO = albedo;
	ROUGHNESS = mix(0.94, 0.72, noise);
	SPECULAR = 0.18;
}
