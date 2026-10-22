shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

varying vec2 v_uv;
varying float v_edge;

void vertex() {
	v_uv = UV;
	// COLOR.r is the fraction of the ribbon that is water. The rest is bank.
	v_edge = COLOR.r;
}

void fragment() {
	// 0 at the centre, 1 at the outer bank. No along-river repeat, so a
	// strategic view stays one clean line instead of a dashed scar.
	float across = abs(v_uv.y * 2.0 - 1.0);
	float edge = clamp(v_edge, 0.4, 0.92);
	float bank = smoothstep(edge - 0.02, edge + 0.10, across);
	// Most of the width stays in the light shallows. The deeper thread is narrow
	// so a strategic view reads as one light line, not a navy stripe.
	float depth = 1.0 - smoothstep(0.0, edge * 0.55, across);
	vec3 centre = vec3(0.22, 0.40, 0.42);
	vec3 shallows = vec3(0.38, 0.56, 0.50);
	vec3 wet = vec3(0.56, 0.49, 0.36);
	vec3 col = mix(shallows, centre, depth);
	col = mix(col, wet, bank);
	ALBEDO = col;
	ROUGHNESS = mix(0.40, 0.88, bank);
	METALLIC = 0.0;
	SPECULAR = mix(0.045, 0.012, bank);
}
