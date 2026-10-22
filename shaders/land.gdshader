shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D atlas : source_color, repeat_enable, filter_linear_mipmap;

varying vec3 v_color;
varying float v_h;
varying float v_edge;
varying float v_shore;
varying vec3 v_wpos;
varying vec3 v_wnorm;

vec3 sample_tile(int tile, vec2 wuv) {
	float col = float(tile % 4);
	float row = float(tile / 4);
	vec2 base = vec2(col, row) * vec2(0.25, 0.5);
	vec2 local = fract(wuv) * vec2(0.23, 0.46) + vec2(0.01, 0.02);
	return texture(atlas, base + local).rgb;
}

void vertex() {
	v_color = COLOR.rgb;
	v_h = VERTEX.y;
	v_edge = UV.x;
	v_shore = UV.y;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 wuv = v_wpos.xz * 0.055;
	float slope = clamp(1.0 - v_wnorm.y, 0.0, 1.0);
	float warm = clamp((v_color.r - v_color.g) * 3.2 + 0.15, 0.0, 1.0);
	float green = clamp((v_color.g - v_color.r) * 4.0, 0.0, 1.0);
	float pale = clamp(v_color.r + v_color.g - 0.9, 0.0, 1.0);

	vec3 sand = sample_tile(0, wuv);
	vec3 loess = sample_tile(1, wuv * vec2(1.0, 1.15));
	vec3 grass = sample_tile(2, wuv);
	vec3 wheat = sample_tile(3, wuv);
	vec3 rice = sample_tile(4, wuv * 0.85);
	vec3 rock = sample_tile(5, wuv * 1.35);
	vec3 forest = sample_tile(6, wuv);
	vec3 hill = sample_tile(7, wuv);

	vec3 detail = mix(wheat, grass, green);
	detail = mix(detail, forest, green * smoothstep(0.35, 0.7, v_color.g));
	detail = mix(detail, mix(loess, sand, pale), warm * (1.0 - green));
	detail = mix(detail, rice, green * (1.0 - smoothstep(0.15, 0.7, v_h)) * 0.65);
	float rock_amt = smoothstep(0.18, 0.55, slope) * smoothstep(1.6, 4.0, v_h);
	detail = mix(detail, rock, rock_amt);
	detail = mix(detail, hill, smoothstep(1.2, 2.4, v_h) * (1.0 - rock_amt) * 0.35);

	float luma = dot(detail, vec3(0.25, 0.6, 0.15));
	vec3 col = v_color * (0.42 + 0.95 * luma);

	float snow_line = 9.5;
	float snow = smoothstep(snow_line, snow_line + 2.2, v_h) * smoothstep(0.25, 0.7, v_wnorm.y);
	col = mix(col, vec3(0.9, 0.92, 0.94) * (0.85 + 0.15 * luma), snow);

	float beach = v_shore * (1.0 - smoothstep(0.05, 0.55, v_h)) * (1.0 - slope);
	col = mix(col, sand * vec3(1.05, 0.95, 0.7), beach * 0.8);

	// Faint grid, only a hairline. No trench, no bright lip.
	float grid = smoothstep(0.988, 0.999, v_edge);
	col = mix(col, col * vec3(0.82, 0.78, 0.7), grid * 0.22);

	float l = dot(col, vec3(0.3, 0.5, 0.2));
	col = clamp(mix(vec3(l), col, 1.18), vec3(0.0), vec3(1.0));

	ALBEDO = col;
	ROUGHNESS = mix(0.9, 0.62, snow);
	METALLIC = 0.0;
	SPECULAR = 0.05;
}
