shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

// Coating tint and glancing reflections, with no screen-space distortion of targets.
void fragment() {
	float grazing = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 5.0);
	ALBEDO = vec3(0.23, 0.38, 0.41);
	ROUGHNESS = 0.08;
	METALLIC = 0.05;
	SPECULAR = 0.85;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.08;
	ALPHA = mix(0.055, 0.28, grazing);
}
