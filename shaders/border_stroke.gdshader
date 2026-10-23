shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_opaque;

// Mesh is baked at border_ref_m. The vertex shader opens it to border_half_m
// so the on-screen width stays constant as the camera moves.
uniform float border_half_m = 3.0;
uniform float border_ref_m = 0.5;

varying vec3 v_col;
varying float v_side;

void vertex() {
	vec3 w = VERTEX;
	w.xz += UV2 * (border_half_m - border_ref_m);
	vec3 to_cam = CAMERA_POSITION_WORLD - w;
	float d = max(length(to_cam), 0.001);
	w += to_cam / d * 0.85;
	VERTEX = w;
	v_col = COLOR.rgb;
	v_side = UV.x;
}

void fragment() {
	float a = abs(v_side);
	vec3 edge = v_col * vec3(0.18, 0.12, 0.10);
	vec3 core = mix(v_col, vec3(0.98, 0.93, 0.82), 0.22);
	ALBEDO = mix(core, edge, smoothstep(0.10, 0.86, a));
	EMISSION = core * 0.08 * (1.0 - smoothstep(0.0, 0.35, a));
}
