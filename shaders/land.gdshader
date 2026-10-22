shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float grid_fade = 0.04;
uniform sampler2D river_map : filter_linear, repeat_disable;
uniform vec2 river_origin = vec2(0.0);
uniform vec2 river_scale = vec2(1.0);

varying vec3 v_color;
varying float v_h;
varying float v_edge;
varying float v_shore;
varying vec3 v_wpos;
varying vec3 v_wnorm;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	v_color = COLOR.rgb;
	v_h = VERTEX.y;
	v_edge = UV.x;
	v_shore = COLOR.a;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// One hash for grain. Broad patches are already in the vertex colour.
	float fine = hash21(floor(v_wpos.xz * 0.42));
	vec3 col = v_color * (0.93 + 0.08 * fine);

	float slope = clamp(1.0 - v_wnorm.y, 0.0, 1.0);
	col = mix(col, vec3(0.40, 0.38, 0.34), smoothstep(0.48, 0.84, slope) * 0.5);

	float snow = smoothstep(14.2, 17.2, v_h) * smoothstep(0.62, 0.9, v_wnorm.y);
	col = mix(col, vec3(0.76, 0.77, 0.74), snow * 0.5);

	// Sandy band on the ramp into the water. v_shore is the coast field, 0 inland, 1 water.
	float beach = smoothstep(0.05, 0.16, v_shore) * (1.0 - smoothstep(0.50, 0.68, v_shore));
	beach *= 1.0 - smoothstep(0.6, 1.8, v_h);
	beach *= 1.0 - slope;
	col = mix(col, vec3(0.72, 0.66, 0.52), beach * 0.88);

	float grid = smoothstep(0.997, 0.9998, v_edge);
	col = mix(col, col * vec3(0.78, 0.76, 0.70), grid * 0.04 * grid_fade);

	float l = dot(col, vec3(0.30, 0.50, 0.20));
	col = clamp(mix(vec3(l), col, 0.93), vec3(0.0), vec3(1.0));

	// River mask: R is distance / half-width over 0..2.4, GB is the flow direction.
	vec2 river_uv = (v_wpos.xz - river_origin) * river_scale;
	river_uv.y = 1.0 - river_uv.y;
	float water = 0.0;
	float bank = 0.0;
	vec3 water_col = col;
	if (river_uv.x > 0.0 && river_uv.y > 0.0 && river_uv.x < 1.0 && river_uv.y < 1.0) {
		vec4 riv = texture(river_map, river_uv);
		float nd = riv.r * 2.4;
		float fw = max(fwidth(nd), 0.02);
		water = 1.0 - smoothstep(1.0 - fw, 1.0 + fw, nd);
		bank = smoothstep(0.9, 1.2, nd) * (1.0 - smoothstep(1.25, 1.65, nd));
		bank *= 1.0 - water;
		// Same family as the lake and coastal-shallow shader, centre a little deeper.
		vec3 centre = vec3(0.11, 0.28, 0.34);
		vec3 shallows = vec3(0.22, 0.35, 0.34);
		water_col = mix(centre, shallows, clamp(nd, 0.0, 1.0));
		vec2 flow = riv.gb * 2.0 - 1.0;
		float fl = length(flow);
		flow = fl > 0.2 ? flow / fl : vec2(1.0, 0.0);
		float detail = 1.0 - smoothstep(0.2, 0.7, fw);
		float wave = sin(dot(v_wpos.xz, flow) * 0.18 - TIME * 0.35);
		water_col *= 1.0 + wave * 0.028 * detail;
		float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
		water_col += vec3(0.025, 0.03, 0.03) * fres * 0.35;
	}
	col = mix(col, col * vec3(0.76, 0.72, 0.64), bank * 0.65);
	col = mix(col, water_col, water);

	ALBEDO = col;
	ROUGHNESS = mix(mix(0.92, 0.74, snow), 0.58, water);
	METALLIC = 0.0;
	SPECULAR = mix(0.03, 0.045, water);
}
