shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// LOCAL PATCH (v3, v5 kit/snow): continuous mountain ranges + plateau. Opaque, no alpha anywhere.
// COLOR.rgb = authored colour (land vertex-colour space). COLOR.a = foot weight (1 at the toe:
// gets the same grain/slope treatment as land.gdshader so the seam is invisible).
// UV.x = signed distance to the realm border chord, UV2/UV.y = that realm's colour: the border
// stroke is drawn on the slope itself, so the camera-biased wash never has to tint the range.
uniform float border_half_m = 3.0;

varying vec3 v_color;
varying float v_foot;
varying vec3 v_wpos;
varying vec3 v_wnorm;
varying float v_bd;
varying vec3 v_bcol;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	v_color = COLOR.rgb;

	v_foot = COLOR.a;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_bd = UV.x;
	v_bcol = vec3(UV2.x, 1.0 - UV2.y, 1.0 - UV.y);   // glTF flips V
}

void fragment() {
	float fine = hash21(floor(v_wpos.xz * 0.42));
	vec3 col = v_color * mix(1.0, 0.93 + 0.08 * fine, v_foot);
	float slope = clamp(1.0 - v_wnorm.y, 0.0, 1.0);
	col = mix(col, vec3(0.40, 0.38, 0.34), smoothstep(0.48, 0.84, slope) * 0.5 * v_foot);
	float l = dot(col, vec3(0.30, 0.50, 0.20));
	col = clamp(mix(vec3(l), col, mix(1.0, 0.93, v_foot)), vec3(0.0), vec3(1.0));
	// realm border stroke (same look as border_stroke.gdshader)
	float a = abs(v_bd) / border_half_m;
	float aa = fwidth(a) + 0.02;
	float m = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, a);
	vec3 edge = v_bcol * vec3(0.18, 0.12, 0.10);
	vec3 core = mix(v_bcol, vec3(0.98, 0.93, 0.82), 0.22);
	vec3 stroke = mix(core, edge, smoothstep(0.10, 0.86, a));
	ALBEDO = mix(col, stroke, m);
	EMISSION = core * 0.08 * (1.0 - smoothstep(0.0, 0.35, a)) * m;
	ALPHA = 1.0;
	// v5: snow (bright, unsaturated albedo) gets a fully matte response: soft volume, no glints
	float mx = max(v_color.r, max(v_color.g, v_color.b));
	float mn = min(v_color.r, min(v_color.g, v_color.b));
	float snow = smoothstep(0.40, 0.50, mn) * (1.0 - smoothstep(0.08, 0.14, mx - mn)) * step(v_color.r, v_color.b + 0.02);
	ROUGHNESS = mix(0.92, 1.0, snow);
	METALLIC = 0.0;
	SPECULAR = mix(0.03, 0.0, snow);
}
