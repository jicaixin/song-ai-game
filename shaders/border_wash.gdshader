shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_mix, depth_draw_never;

// The band is baked on the ground. Loess terraces and ridges sit several metres
// above that, so the pass steps toward the camera along the view ray (the
// screen position does not move) until it clears them. wash_inset pulls the
// outer lip inside the stroke so the 30% tint does not grey the line.
uniform float cam_bias = 40.0;
uniform float wash_inset = 2.0;

varying vec3 v_col;
varying float v_alpha;

void vertex() {
	vec3 w = VERTEX;
	w.xz += UV2 * wash_inset * (1.0 - UV.x);
	vec3 to_cam = CAMERA_POSITION_WORLD - w;
	float d = max(length(to_cam), 0.001);
	w += to_cam / d * cam_bias;
	VERTEX = w;
	v_col = COLOR.rgb;
	v_alpha = COLOR.a;
}

void fragment() {
	ALBEDO = v_col;
	ALPHA = v_alpha;
}
