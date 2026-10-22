shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
	EMISSION = COLOR.rgb * 0.6;
}
