// Points of the 2.5D view (stars and belt rocks): soft round dots of PT pixels. MODE 4 of FSQ in view25.js.
// (A separate shader: in the Compatibility renderer, a material that sets the point size draws triangles as points.)
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled, shadows_disabled;

uniform float PT = 1.0;
varying vec4 vc;

void vertex() {
	vc = COLOR;
	POINT_SIZE = PT;
}

void fragment() {
	float d = length(POINT_COORD * 2. - 1.);
	float a = smoothstep(1., .2, d);
	ALBEDO = vc.rgb;
	ALPHA = vc.a * a;
}
