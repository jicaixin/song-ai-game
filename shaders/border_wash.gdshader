shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_mix, depth_draw_never;

uniform float cam_bias = 0.4;

varying vec3 v_col;
varying float v_alpha;

void vertex() {
	vec3 w = VERTEX;
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
