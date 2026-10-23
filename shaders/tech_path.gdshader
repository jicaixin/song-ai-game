shader_type canvas_item;

// One static dash along UV.x (1 unit = 16 px, 10 on / 6 off). TIME scrolls it.
// UV.y >= 1.5 keeps the arrowhead solid.
void fragment() {
	float along = UV.x - TIME * 1.25;
	float dash = 1.0 - step(0.625, fract(along));
	float solid = step(1.5, UV.y);
	float mask = mix(dash, 1.0, solid);
	COLOR.a *= mask;
}
