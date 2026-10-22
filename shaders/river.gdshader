shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

varying vec2 v_uv;
varying vec3 v_wpos;

void vertex() {
	v_uv = UV;
	vec3 p = VERTEX;
	p.y += sin(p.x * 0.55 + TIME * 1.6) * 0.025;
	VERTEX = p;
	v_wpos = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
}

void fragment() {
	float along = fract(v_uv.x * 3.0 - TIME * 0.35);
	float across = abs(v_uv.y * 2.0 - 1.0);
	vec3 deep = vec3(0.08, 0.28, 0.52);
	vec3 midc = vec3(0.2, 0.5, 0.68);
	vec3 silt = vec3(0.55, 0.48, 0.26);
	vec3 col = mix(midc, deep, smoothstep(0.0, 0.85, across));
	// COLOR.b carries silt (Yellow River) vs clearer water.
	col = mix(col, silt, COLOR.b * 0.55);
	float crest = smoothstep(0.62, 0.95, along) * (1.0 - across);
	col += vec3(0.22, 0.26, 0.24) * crest;
	float bank = smoothstep(0.72, 1.0, across);
	col = mix(col, vec3(0.9, 0.94, 0.92), bank * 0.35);
	ALBEDO = col;
	ROUGHNESS = 0.18;
	METALLIC = 0.0;
	SPECULAR = 0.5;
}
