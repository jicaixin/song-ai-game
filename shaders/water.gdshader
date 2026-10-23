shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

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
	ALBEDO = col;
	ROUGHNESS = mix(0.55, 0.22, depth);
	METALLIC = 0.0;
	SPECULAR = 0.05;
}
