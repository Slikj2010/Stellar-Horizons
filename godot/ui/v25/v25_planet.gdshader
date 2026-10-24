// A planet in the 2.5D view: a camera-facing disc that samples one row of bodies.png as a turning sphere, lit from
// the Sun. A port of FSP in view25.js.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled, shadows_disabled;

uniform sampler2D T : filter_linear, repeat_disable;
uniform float row;
uniform float rot;
uniform float AW;
uniform float AH;
uniform float TW;
uniform float TH;
uniform float DS;
uniform vec3 L;

// manual wrap-around bilinear lookup in one body's map (texel coordinates): no seam at the date line, no bleeding
// into the neighbouring rows of the atlas
vec3 samp(sampler2D tx, vec2 pt, float mrow, float mw, float mh) {
	vec2 q = pt - 0.5;
	vec2 i = floor(q);
	vec2 f = q - i;
	float x0 = mod(i.x, mw);
	float x1 = mod(i.x + 1.0, mw);
	float y0 = clamp(i.y, 0.0, mh - 1.0) + mrow * mh;
	float y1 = clamp(i.y + 1.0, 0.0, mh - 1.0) + mrow * mh;
	vec3 a = texelFetch(tx, ivec2(int(x0), int(y0)), 0).rgb;
	vec3 b = texelFetch(tx, ivec2(int(x1), int(y0)), 0).rgb;
	vec3 c = texelFetch(tx, ivec2(int(x0), int(y1)), 0).rgb;
	vec3 d = texelFetch(tx, ivec2(int(x1), int(y1)), 0).rgb;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
vec3 body_color(sampler2D tx, vec2 qq, float mrot, float mrow, float mw, float mh) {
	float lat = asin(clamp(qq.y, -1.0, 1.0));
	float cl = max(cos(lat), 1e-3);
	float lon = asin(clamp(qq.x / cl, -1.0, 1.0)) + mrot;
	vec2 tc = vec2((lon + 3.14159265) / 6.2831853 * mw, (lat + 1.5707963) / 3.14159265 * mh);
	vec2 g = clamp(fwidth(tc), vec2(0.0), vec2(48.0, 24.0));
	vec3 s = vec3(0.0);
	for (int ix = -1; ix <= 1; ix++) {
		for (int iy = -1; iy <= 1; iy++) {
			s += samp(tx, tc + g * vec2(float(ix), float(iy)) / 3.0, mrow, mw, mh);
		}
	}
	return s / 9.0;
}
varying vec2 vq;

void vertex() { vq = UV2; }

void fragment() {
	vec2 q = vec2(vq.x * 2. - 1., vq.y * 2. - 1.);
	float d = length(q);
	if (d > 1.) discard;
	vec3 c = body_color(T, vec2(q.x, q.y), rot, row, TW, TH);
	vec4 m = texture(T, vec2((TW + (q.x * .5 + .5) * DS) / AW, (row * TH + (q.y * .5 + .5) * DS) / AH));
	float a = m.a * smoothstep(1., .97, d);
	vec3 n = vec3(q.x, -q.y, sqrt(max(0., 1. - d * d)));
	float lam = max(0., dot(n, normalize(L)));
	float sh = .32 + .95 * lam;
	// the web version writes premultiplied colour with straight-alpha blending: keep that look
	ALBEDO = c * m.r * 1.55 * sh * a;
	ALPHA = a;
}
