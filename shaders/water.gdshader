shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

varying float v_shore;
varying float v_lake;
varying vec3 v_wpos;

void vertex() {
	v_shore = COLOR.r;
	v_lake = COLOR.g;
	vec3 p = VERTEX;
	float amp = mix(0.06, 0.02, v_shore);
	float wx = p.x * 0.42 + TIME * 0.9;
	float wz = p.z * 0.37 + TIME * 0.6;
	float wave = sin(wx) * cos(wz) + 0.35 * sin(p.x * 0.9 + TIME * 1.4);
	p.y += wave * amp;
	float dwdx = cos(wx) * 0.42 * cos(wz) * amp;
	float dwdz = sin(wx) * (-sin(wz)) * 0.37 * amp;
	NORMAL = normalize(vec3(-dwdx, 1.0, -dwdz));
	VERTEX = p;
	v_wpos = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
}

void fragment() {
	vec3 deep = vec3(0.02, 0.18, 0.48);
	vec3 midc = vec3(0.05, 0.38, 0.62);
	vec3 shallow = vec3(0.18, 0.72, 0.7);
	float s = clamp(v_shore, 0.0, 1.0);
	vec3 col = mix(deep, midc, smoothstep(0.0, 0.35, s));
	col = mix(col, shallow, smoothstep(0.45, 0.95, s));
	col = mix(col, vec3(0.08, 0.42, 0.5), v_lake * 0.4);
	float rip = sin(v_wpos.x * 0.85 + TIME * 1.2) * sin(v_wpos.z * 0.7 - TIME);
	col += vec3(0.03, 0.05, 0.05) * rip;
	float foam_band = smoothstep(0.72, 0.9, s) * (1.0 - smoothstep(0.9, 0.99, s));
	float fizz = 0.65 + 0.35 * sin(TIME * 2.0 + v_wpos.x * 0.6 + v_wpos.z * 0.4);
	col = mix(col, vec3(0.92, 0.96, 0.94), foam_band * fizz);
	ALBEDO = col;
	ROUGHNESS = mix(0.18, 0.42, s);
	METALLIC = 0.0;
	SPECULAR = 0.45;
}
