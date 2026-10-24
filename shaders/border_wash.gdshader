shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_mix, depth_draw_never;

// The band is baked on the ground. Loess terraces and ridges sit several metres
// above that, so the pass steps toward the camera along the view ray (the
// screen position does not move) until it clears them. wash_inset pulls the
// outer lip inside the stroke so the 30% tint does not grey the line.
// LOCAL PATCH (v3): the depth buffer tells how high the visible surface is above the
// band's own ground; tall mountain slopes (continuous ranges) are left untinted.
uniform float cam_bias = 40.0;
uniform float wash_inset = 2.0;
uniform float tint_max_h = 7.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 v_col;
varying float v_alpha;
varying float v_ground_y;

void vertex() {
	vec3 w = VERTEX;
	v_ground_y = (MODEL_MATRIX * vec4(w, 1.0)).y;
	w.xz += UV2 * wash_inset * (1.0 - UV.x);
	vec3 to_cam = CAMERA_POSITION_WORLD - w;
	float d = max(length(to_cam), 0.001);
	w += to_cam / d * cam_bias;
	VERTEX = w;
	v_col = COLOR.rgb;
	v_alpha = COLOR.a;
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).x;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float above = world.y / world.w - v_ground_y;
	ALBEDO = v_col;
	ALPHA = v_alpha * (1.0 - smoothstep(tint_max_h * 0.45, tint_max_h, above));
}
