shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

varying vec2 v_uv;
varying vec3 v_wpos;

void vertex() {
	v_uv = UV;
	vec3 p = VERTEX;
	p.y += sin(p.x * 0.35 + TIME * 0.8) * 0.015;
	VERTEX = p;
	v_wpos = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
}

void fragment() {
	float along = fract(v_uv.x * 0.35 - TIME * 0.12);
	float across = abs(v_uv.y * 2.0 - 1.0);
	vec3 center = vec3(0.15, 0.30, 0.38);
	vec3 edge = vec3(0.09, 0.20, 0.28);
	vec3 col = mix(center, edge, smoothstep(0.2, 0.95, across));
	float crest = smoothstep(0.72, 0.95, along) * (1.0 - across);
	col += vec3(0.025, 0.035, 0.03) * crest;
	ALBEDO = col;
	ROUGHNESS = 0.55;
	METALLIC = 0.0;
	SPECULAR = 0.03;
}
