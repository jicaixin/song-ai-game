shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D border_map : source_color, filter_linear, repeat_disable;
uniform vec2 border_origin = vec2(0.0);
uniform vec2 border_scale = vec2(1.0);
uniform float border_px = 7.0;

varying float v_coast;
varying float v_lake;
varying vec3 v_wpos;

void vertex() {
	v_coast = COLOR.r;
	v_lake = COLOR.g;
	vec3 p = VERTEX;
	float depth = smoothstep(0.36, 0.8, clamp(v_coast, 0.0, 1.0));
	float amp = mix(0.01, 0.035, depth);
	float wx = p.x * 0.18 + TIME * 0.45;
	float wz = p.z * 0.16 + TIME * 0.32;
	float wave = sin(wx) * cos(wz);
	p.y += wave * amp;
	float dwdx = cos(wx) * 0.18 * cos(wz) * amp;
	float dwdz = sin(wx) * (-sin(wz)) * 0.16 * amp;
	NORMAL = normalize(vec3(-dwdx, 1.0, -dwdz));
	VERTEX = p;
	v_wpos = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
}

void fragment() {
	float coast = clamp(v_coast, 0.0, 1.0);
	float depth = smoothstep(0.34, 0.82, coast);
	vec3 deep = vec3(0.07, 0.17, 0.26);
	vec3 midc = vec3(0.11, 0.28, 0.34);
	vec3 shallow = vec3(0.24, 0.36, 0.34);
	vec3 col = mix(shallow, midc, smoothstep(0.0, 0.45, depth));
	col = mix(col, deep, smoothstep(0.4, 1.0, depth));
	col = mix(col, vec3(0.14, 0.28, 0.30), v_lake * 0.25);
	float rip = sin(v_wpos.x * 0.25 + TIME * 0.6) * sin(v_wpos.z * 0.22 - TIME * 0.4);
	col += vec3(0.008, 0.012, 0.01) * rip * depth;
	// Thin foam just seaward of the waterline. Not a glow.
	float foam = smoothstep(0.30, 0.38, coast) * (1.0 - smoothstep(0.40, 0.50, coast));
	col = mix(col, vec3(0.70, 0.73, 0.68), foam * 0.32);
	vec3 border_emit = vec3(0.0);
	vec2 border_uv = (v_wpos.xz - border_origin) * border_scale;
	border_uv.y = 1.0 - border_uv.y;
	if (border_uv.x > 0.0 && border_uv.y > 0.0 && border_uv.x < 1.0 && border_uv.y < 1.0) {
		vec4 brim = texture(border_map, border_uv);
		float chroma = max(brim.r, max(brim.g, brim.b));
		float dist = brim.a * 24.0;
		float dpx = dist / max(fwidth(dist), 0.08);
		float edge_px = max(border_px, 4.0);
		float line = (1.0 - smoothstep(edge_px * 0.58, edge_px, dpx)) * step(0.04, chroma);
		float along = clamp(dpx / edge_px, 0.0, 1.0);
		vec3 edge_col = brim.rgb * vec3(0.28, 0.20, 0.16);
		vec3 core_col = mix(brim.rgb, vec3(1.0, 0.95, 0.86), 0.52);
		vec3 stroke = mix(core_col, edge_col, smoothstep(0.08, 0.88, along));
		col = mix(col, stroke, line);
		border_emit = core_col * (1.0 - smoothstep(0.0, 0.5, along)) * line * 0.4;
	}
	ALBEDO = col;
	EMISSION = border_emit;
	ROUGHNESS = mix(0.55, 0.22, depth);
	METALLIC = 0.0;
	SPECULAR = 0.05;
}
