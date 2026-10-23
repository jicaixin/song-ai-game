shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec4 albedo : source_color = vec4(0.8, 0.75, 0.65, 1.0);

void fragment() {
	ALBEDO = albedo.rgb * COLOR.rgb;
	ROUGHNESS = 0.78;
	SPECULAR = 0.08;
}
