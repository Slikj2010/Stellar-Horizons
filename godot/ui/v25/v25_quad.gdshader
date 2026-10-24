// The 2.5D view's general shader (points use v25_points.gdshader): a port of FSQ in view25.js. The vertex data is the same as the web version's
// (position, uv, q = corner coordinates, colour); MODE picks the look. Drawn in painter's order without depth test.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled, shadows_disabled;

uniform sampler2D T : filter_linear, repeat_enable;
uniform int MODE = 0;
uniform float TM = 0.0;
varying vec2 vuv;
varying vec2 vq;
varying vec4 vc;

float hh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f); return mix(mix(hh(i), hh(i + vec2(1., 0.)), f.x), mix(hh(i + vec2(0., 1.)), hh(i + vec2(1., 1.)), f.x), f.y); }

void vertex() {
	vuv = UV;
	vq = UV2;
	vc = COLOR;
}

void fragment() {
	vec4 o;
	if (MODE == 0) { vec4 t = texture(T, vuv); o = vec4(t.rgb * vc.rgb, t.a * vc.a); }
	else if (MODE == 1) { o = vc; }
	else if (MODE == 2) { float d = length(vq * 2. - 1.); float a = smoothstep(1., .8, d); o = vec4(vc.rgb, vc.a * a); }
	else if (MODE == 3) { float d = length(vq * 2. - 1.); float a = pow(max(0., 1. - d), 2.); o = vec4(vc.rgb, vc.a * a); }
	else if (MODE == 6) { vec4 t = texture(T, vuv); float f = smoothstep(0., .06, min(min(vq.x, 1. - vq.x), min(vq.y, 1. - vq.y))); o = vec4(t.rgb, t.a * f); }
	else if (MODE == 8) {
		vec2 g = abs(fract(vuv) - .5); float line = smoothstep(.44, .5, max(g.x, g.y));
		float scan = smoothstep(.2, 1., sin(TM * 1.3 + vuv.x * .45 + vuv.y * .3)) * .16;
		vec3 c = vc.rgb + vec3(.02, .22, .32) * (line * .55 + scan); o = vec4(c, vc.a);
	}
	else if (MODE == 7) {
		vec2 q = vq * 2. - 1.; float d = length(q); if (d > 1.) discard;
		float n = vn(q * 4. + TM * .05) * .5 + vn(q * 9. - TM * .08) * .3 + vn(q * 21. + TM * .03) * .2;
		vec3 c = mix(vec3(1., .55, .14), vec3(1., .93, .6), n); c = mix(c, vec3(1., .97, .8), .35 * (1. - d)); c *= 1. - .35 * pow(d, 2.5);
		c += vec3(.45, .18, .02) * smoothstep(.8, 1., d);
		o = vec4(c * vc.rgb, smoothstep(1., .97, d));
	}
	else if (MODE == 10) {
		float g = max(step(.988, fract(vuv.x)), step(.988, fract(vuv.y))) * .7;
		float f = smoothstep(0., .025, min(min(vq.x, 1. - vq.x), min(vq.y, 1. - vq.y)));
		o = vec4(mix(vc.rgb, vec3(.2, .5, .65), g * .5), vc.a * f);
	}
	else { o = vc; }
	ALBEDO = o.rgb;
	ALPHA = o.a;
}
