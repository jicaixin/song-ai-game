shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D grain_tex : source_color, repeat_enable, filter_linear;

varying vec3 v_color;
varying float v_h;
varying float v_edge;
varying float v_shore;
varying vec3 v_wpos;
varying vec3 v_wnorm;

void vertex() {
	v_color = COLOR.rgb;
	v_h = VERTEX.y;
	v_edge = UV.x;
	v_shore = UV.y;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float g = texture(grain_tex, v_wpos.xz * 0.045).r;
	float g2 = texture(grain_tex, v_wpos.xz * 0.011 + vec2(0.37, 0.18)).r;
	float g3 = texture(grain_tex, v_wpos.xz * 0.16).r;
	float grain = g * 0.55 + g2 * 0.3 + g3 * 0.15;
	vec3 col = v_color * (0.88 + 0.16 * grain);

	float patch = g2 * 2.0 - 1.0;
	col.r += patch * 0.03;
	col.g += patch * 0.015;

	float slope = clamp(1.0 - v_wnorm.y, 0.0, 1.0);
	// Rock only on high ground, so dunes and loess hills keep their color.
	float high = smoothstep(2.2, 4.8, v_h);
	vec3 rock = vec3(0.32, 0.27, 0.24) * (0.82 + 0.28 * g3);
	vec3 cliff = vec3(0.22, 0.20, 0.19);
	col = mix(col, rock, smoothstep(0.2, 0.58, slope) * high);
	col = mix(col, cliff, smoothstep(0.5, 0.85, slope) * high);

	float snow_line = 10.2 + (g2 - 0.5) * 1.3;
	float snow = smoothstep(snow_line, snow_line + 1.6, v_h);
	snow *= smoothstep(0.28, 0.72, v_wnorm.y);
	vec3 snow_col = vec3(0.86, 0.88, 0.9) * (0.94 + 0.06 * g3);
	col = mix(col, snow_col, snow);

	vec3 sand = vec3(0.62, 0.5, 0.28) * (0.9 + 0.12 * g);
	float beach = v_shore * (1.0 - smoothstep(0.02, 0.85, v_h));
	beach *= 1.0 - smoothstep(0.35, 0.7, slope);
	col = mix(col, sand, beach * 0.85);

	// Soft hex lip, then a thin crease so the grid reads without black gaps.
	float lip = smoothstep(0.72, 0.9, v_edge) * (1.0 - smoothstep(0.9, 0.98, v_edge));
	col *= 1.0 - lip * 0.1;
	float crease = smoothstep(0.82, 0.98, v_edge);
	col = mix(col, col * vec3(0.38, 0.34, 0.28), crease * 0.62);

	float ao = mix(0.72, 1.0, smoothstep(0.0, 0.45, v_wnorm.y));
	col *= ao;

	ALBEDO = col;
	ROUGHNESS = mix(0.94, 0.72, snow);
	METALLIC = 0.0;
	SPECULAR = 0.04;
}
