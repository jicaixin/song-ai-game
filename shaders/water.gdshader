shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

varying float v_shore;
varying float v_lake;
varying vec3 v_wpos;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	v_shore = COLOR.r;
	v_lake = COLOR.g;
	vec3 p = VERTEX;
	float amp = mix(0.045, 0.018, clamp(v_shore, 0.0, 1.0));
	float wx = p.x * 0.22 + TIME * 0.55;
	float wz = p.z * 0.19 + TIME * 0.37;
	float wave = sin(wx) * cos(wz);
	p.y += wave * amp;
	float dwdx = cos(wx) * 0.22 * cos(wz) * amp;
	float dwdz = sin(wx) * (-sin(wz)) * 0.19 * amp;
	NORMAL = normalize(vec3(-dwdx, 1.0, -dwdz));
	VERTEX = p;
	v_wpos = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
}

void fragment() {
	float s = clamp(v_shore, 0.0, 1.0);
	vec3 deep = vec3(0.08, 0.22, 0.34);
	vec3 midc = vec3(0.14, 0.38, 0.46);
	vec3 shallow = vec3(0.34, 0.58, 0.54);
	vec3 col = mix(deep, midc, smoothstep(0.05, 0.45, s));
	col = mix(col, shallow, smoothstep(0.40, 0.92, s));
	col = mix(col, vec3(0.16, 0.36, 0.40), v_lake * 0.35);
	float rip = sin(v_wpos.x * 0.31 + TIME * 0.7) * sin(v_wpos.z * 0.27 - TIME * 0.45);
	col += vec3(0.015, 0.02, 0.018) * rip;
	float foam = smoothstep(0.62, 0.84, s) * (1.0 - smoothstep(0.84, 0.98, s));
	float fizz = 0.75 + 0.25 * hash21(floor(v_wpos.xz * 0.35));
	col = mix(col, vec3(0.78, 0.82, 0.78), foam * fizz * 0.55);
	ALBEDO = col;
	ROUGHNESS = mix(0.22, 0.48, s);
	METALLIC = 0.0;
	SPECULAR = 0.18;
}
