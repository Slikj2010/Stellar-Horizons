// Rocks, moons and dwarf planets of the 2.5D view: ray-marched lumpy spheres on a camera-facing quad.
// A port of FSR in view25.js.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled, shadows_disabled;

uniform float rot;
uniform float SD;
uniform float LP;
uniform float ICE;
uniform float EL;
uniform float SC;
uniform float RG;
uniform float TT;
uniform vec3 L;
uniform vec3 C1;
uniform vec3 C2;
varying vec2 vq;

float h3(vec3 p) { p = fract(p * .3183099 + .1); p *= 17.; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float n3(vec3 x) {
	vec3 i = floor(x), f = fract(x); f = f * f * (3. - 2. * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1., 0., 0.)), f.x), mix(h3(i + vec3(0., 1., 0.)), h3(i + vec3(1., 1., 0.)), f.x), f.y),
		mix(mix(h3(i + vec3(0., 0., 1.)), h3(i + vec3(1., 0., 1.)), f.x), mix(h3(i + vec3(0., 1., 1.)), h3(i + vec3(1., 1., 1.)), f.x), f.y), f.z);
}
float fb(vec3 p) { return n3(p) * .5 + n3(p * 2.1 + 3.1) * .25 + n3(p * 4.3 + 7.7) * .125 + n3(p * 8.9 + 1.3) * .0625; }
vec3 bodyP(vec3 p) { float c = cos(rot), s = sin(rot); vec3 b = vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z); b.y /= EL; return b; }
float sdf(vec3 p) { vec3 b = bodyP(p); float l = length(b); vec3 d = b / max(l, 1e-4); return (l - (1. + LP * (fb(d * 1.6 + SD) - .5) * 1.7)) * min(1., EL + .25); }

void vertex() { vq = UV2; }

void fragment() {
	vec2 q = vec2(vq.x * 2. - 1., 1. - vq.y * 2.) * SC;
	vec3 o = vec3(q, -3.), dv = vec3(0., 0., 1.);
	float t = 0., md = 9.;
	bool hit = false;
	vec3 p = o, pb = o;
	if (length(q) < 1.6) {
		for (int i = 0; i < 56; i++) {
			p = o + dv * t; float dd = sdf(p);
			if (dd < md) { md = dd; pb = p; }
			if (dd < .003) { hit = true; pb = p; break; }
			t += dd * .62; if (t > 6.) break;
		}
	}
	float tb = hit ? t : 99.;
	vec3 Ld = normalize(vec3(L.x, L.y, -L.z));
	vec4 col = vec4(0.);
	float al = hit ? 1. : 1. - smoothstep(.003, .03, md);
	if (al > 0.) {
		vec2 e = vec2(.012, 0.);
		vec3 N = normalize(vec3(sdf(pb + e.xyy) - sdf(pb - e.xyy), sdf(pb + e.yxy) - sdf(pb - e.yxy), sdf(pb + e.yyx) - sdf(pb - e.yyx)));
		vec3 b = bodyP(pb); float n = fb(b * 2.3 + SD * 1.7);
		vec3 alb = mix(C1, C2, smoothstep(.25, .75, n));
		alb = mix(alb, mix(C1, C2, step(0., b.x * .9 + (n - .5) * .5)), TT);
		float cr = smoothstep(.2, .45, n3(b * 4.6 + SD * 3.) * n3(b * 9.1 + SD) * 2.2);
		alb *= 1. - .38 * (1. - cr) * (1. - ICE * .5);
		alb = mix(alb, vec3(.93, .97, 1.), ICE * .3 * fb(b * 3. + SD));
		float lam = max(0., dot(N, Ld)); float rim = pow(1. - max(0., -N.z), 3.);
		col = vec4(alb * (.1 + 1.2 * lam) + vec3(.5, .65, .9) * rim * .14 * (.4 + ICE), al);
	}
	if (RG > 0.) {
		vec3 n = normalize(vec3(0., cos(RG), -sin(RG) * .9)); float dn = dot(dv, n);
		if (abs(dn) > .01) {
			float tr = -dot(o, n) / dn; vec3 rp = o + dv * tr; float rr = length(rp);
			if (rr > 1.5 && rr < 2.2 && tr < tb) {
				float ra = (.5 + .5 * n3(vec3(rr * 40., SD, 0.))) * .62 * smoothstep(1.5, 1.56, rr) * smoothstep(2.2, 2.14, rr);
				vec3 rc = vec3(.6, .55, .5) * (.45 + .9 * max(0., abs(dot(n, Ld)))); float a = ra + col.a * (1. - ra);
				if (a > 0.) col = vec4((rc * ra + col.rgb * col.a * (1. - ra)) / a, a);
			}
		}
	}
	if (col.a <= 0.) discard;
	ALBEDO = col.rgb;
	ALPHA = col.a;
}
