shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

varying float v_shore;
varying float v_lake;
varying vec3 v_wpos;

void vertex() {
	v_shore = COLOR.r;
	v_lake = COLOR.g;
	vec3 p = VERTEX;
	float amp = mix(0.1, 0.028, v_shore);
	float wx = p.x * 0.16 + TIME * 1.05;
	float wz = p.z * 0.14 + TIME * 0.72;
	float wave = sin(wx) * cos(wz);
	p.y += wave * amp;
	float dwdx = cos(wx) * 0.16 * cos(wz) * amp;
	float dwdz = sin(wx) * (-sin(wz)) * 0.14 * amp;
	NORMAL = normalize(vec3(-dwdx, 1.0, -dwdz));
	VERTEX = p;
	v_wpos = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
}

void fragment() {
	vec3 deep = vec3(0.025, 0.1, 0.24);
	vec3 midc = vec3(0.04, 0.24, 0.42);
	vec3 shallow = vec3(0.12, 0.4, 0.4);
	vec3 lagoon = vec3(0.08, 0.32, 0.36);
	float s = clamp(v_shore, 0.0, 1.0);
	vec3 col = mix(deep, midc, smoothstep(0.0, 0.42, s));
	col = mix(col, shallow, smoothstep(0.38, 1.0, s));
	col = mix(col, lagoon, v_lake * 0.55);
	float rip = sin(v_wpos.x * 0.42 + TIME * 1.3) * sin(v_wpos.z * 0.37 - TIME * 0.9);
	col += vec3(0.05, 0.08, 0.09) * rip * (1.0 - s * 0.4);
	float foam = smoothstep(0.55, 0.92, s);
	float band = 0.5 + 0.5 * sin(TIME * 1.8 + v_wpos.x * 0.31 + v_wpos.z * 0.27);
	foam *= 0.45 + 0.55 * band;
	col = mix(col, vec3(0.92, 0.96, 0.94), foam * 0.78);
	ALBEDO = col;
	ROUGHNESS = mix(0.28, 0.5, s);
	METALLIC = 0.0;
	SPECULAR = 0.28;
}
