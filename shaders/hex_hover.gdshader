shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

// style_id: 0 solid, 1 thick, 2 long dash, 3 dotted, 4 dash-dot,
// 5 battlement out, 6 battlement in, 7 double, 8 short dash.
// UV.x = edge index + t. UV.y = 0 inner .. 1 outer, 0.5 on the hex edge.
// The ring spans 4.8 world units across (2.4 each side of the edge).
uniform int style_id = 0;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform vec4 fill_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float hatch_alpha = 0.0;
uniform float design_w = 0.16;
uniform int zoom_band = 1;
uniform float px_per_wu = 2.5;
uniform int is_fill = 0;
uniform float pulse = 1.0;

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
}

float stroke_px(float w) {
	float raw_px = 5.0 * w;
	float sug = max(raw_px, 0.8 + 5.0 * w);
	float px = sug;
	if (zoom_band >= 2) {
		px = raw_px;
	} else if (zoom_band <= 0) {
		px = sug * 0.75;
	}
	return px;
}

void fragment() {
	if (is_fill == 1) {
		float stripe = step(0.5, fract((FRAGCOORD.x + FRAGCOORD.y) * 0.12));
		vec3 albedo = fill_color.rgb;
		float alpha = fill_color.a;
		if (hatch_alpha > 0.001 && stripe > 0.5) {
			albedo = line_color.rgb;
			alpha = max(alpha, hatch_alpha);
		}
		if (alpha < 0.01) {
			discard;
		}
		ALBEDO = albedo;
		ALPHA = alpha * pulse;
	} else {
		float t = fract(v_uv.x);
		float side = v_uv.y - 0.5;
		float world_from_edge = abs(side) * 4.8;
		float want_px = stroke_px(design_w);
		float want_world = want_px / max(px_per_wu, 0.25);
		float half_w = want_world * 0.5;
		float under_half = (want_px + 1.6) / max(px_per_wu, 0.25) * 0.5;
		float pattern = 1.0;
		float ink = 1.0 - step(half_w, world_from_edge);
		if (style_id == 2) {
			pattern = 1.0 - step(0.55, fract(t * 3.0));
		} else if (style_id == 8) {
			pattern = 1.0 - step(0.42, fract(t * 6.0));
		} else if (style_id == 3) {
			pattern = 1.0 - step(0.22, fract(t * 10.0));
		} else if (style_id == 4) {
			float u = fract(t * 3.0);
			pattern = 0.0;
			if (u < 0.42) {
				pattern = 1.0;
			} else if (u > 0.62 && u < 0.78) {
				pattern = 1.0;
			}
		} else if (style_id == 7) {
			float line_w = max(half_w * 0.28, 0.04);
			float outer = 1.0 - step(line_w, abs(world_from_edge - half_w * 0.72));
			float inner = 1.0 - step(line_w, abs(world_from_edge - half_w * 0.15));
			ink = max(outer, inner);
		} else if (style_id == 5 || style_id == 6) {
			float tooth = fract(t * 5.0);
			if (tooth < 0.46) {
				if (style_id == 5 && side < -0.015) {
					pattern = 0.0;
				}
				if (style_id == 6 && side > 0.015) {
					pattern = 0.0;
				}
			}
		}
		ink *= pattern;
		float under = (1.0 - step(under_half, world_from_edge)) * pattern;
		if (ink < 0.5 && under < 0.5) {
			discard;
		}
		if (ink > 0.5) {
			ALBEDO = line_color.rgb;
			ALPHA = line_color.a * pulse;
		} else {
			ALBEDO = vec3(0.078, 0.129, 0.122);
			ALPHA = 0.38 * pulse;
		}
	}
}
