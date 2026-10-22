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
	float along = fract(v_uv.x * 1.4 - TIME * 0.18);
	float across = abs(v_uv.y * 2.0 - 1.0);
	vec3 center = vec3(0.28, 0.46, 0.55);
	vec3 edge = vec3(0.12, 0.26, 0.36);
	vec3 col = mix(center, edge, smoothstep(0.15, 0.95, across));
	float crest = smoothstep(0.55, 0.9, along) * (1.0 - across);
	col += vec3(0.06, 0.08, 0.07) * crest;
	ALBEDO = col;
	ROUGHNESS = 0.32;
	METALLIC = 0.0;
	SPECULAR = 0.16;
}
