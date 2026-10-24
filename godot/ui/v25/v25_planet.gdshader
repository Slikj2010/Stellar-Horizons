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
varying vec2 vq;

void vertex() { vq = UV2; }

void fragment() {
	vec2 q = vec2(vq.x * 2. - 1., vq.y * 2. - 1.);
	float d = length(q);
	if (d > 1.) discard;
	float lat = asin(clamp(q.y, -1., 1.));
	float cl = max(cos(lat), 1e-3);
	float lon = asin(clamp(q.x / cl, -1., 1.)) + rot;
	float u = fract((lon + 3.14159265) / 6.2831853);
	float vv = (lat + 1.5707963) / 3.14159265;
	vec3 c = texture(T, vec2(u * TW / AW, (row * TH + vv * TH) / AH)).rgb;
	vec4 m = texture(T, vec2((TW + (q.x * .5 + .5) * DS) / AW, (row * TH + (q.y * .5 + .5) * DS) / AH));
	float a = m.a * smoothstep(1., .97, d);
	vec3 n = vec3(q.x, -q.y, sqrt(max(0., 1. - d * d)));
	float lam = max(0., dot(n, normalize(L)));
	float sh = .32 + .95 * lam;
	// the web version writes premultiplied colour with straight-alpha blending: keep that look
	ALBEDO = c * m.r * 1.55 * sh * a;
	ALPHA = a;
}
