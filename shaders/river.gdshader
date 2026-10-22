shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

varying vec2 v_uv;
varying vec3 v_wpos;

void vertex() {
	v_uv = UV;
	vec3 p = VERTEX;
	p.y += sin(p.x * 0.8 + TIME * 1.3) * 0.02;
	VERTEX = p;
	v_wpos = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
}

void fragment() {
	float along = fract(v_uv.x * 2.0 - TIME * 0.28);
	float across = abs(v_uv.y * 2.0 - 1.0);
	vec3 mud = vec3(0.55, 0.42, 0.18);
	vec3 water = vec3(0.28, 0.48, 0.42);
	vec3 col = mix(water, mud, 0.72);
	col = mix(col, mud * 1.15, COLOR.b * 0.45);
	float crest = smoothstep(0.55, 0.92, along) * (1.0 - across);
	col += vec3(0.12, 0.1, 0.05) * crest;
	ALBEDO = col;
	ROUGHNESS = 0.35;
	METALLIC = 0.0;
	SPECULAR = 0.25;
}
