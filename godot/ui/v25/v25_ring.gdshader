// A planet's ring in the 2.5D view: a flat disc in the ring plane, banded and lit from the Sun. It is drawn after the
// planet and hidden analytically where the planet is in front of it, and shadowed where the planet is between it and
// the Sun, so the near half passes in front of the planet and the far half behind it.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled, shadows_disabled;

uniform vec3 C;      // planet centre
uniform float R;     // planet radius
uniform vec3 N;      // ring plane normal
uniform vec3 EYE;    // camera position
uniform vec3 LS;     // unit vector towards the Sun
uniform int kind = 0;  // 0 Saturn, 1 Neptune
varying vec3 wp;

void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

float band(float x, float a, float b, float soft) { return smoothstep(a - soft, a + soft, x) * (1.0 - smoothstep(b - soft, b + soft, x)); }

void fragment() {
	vec3 P = wp;
	float rho = length(P - C) / R;
	float soft = 0.01 + fwidth(rho);
	float a = 0.0;
	vec3 col = vec3(0.6);
	if (kind == 0) {
		float cring = band(rho, 1.24, 1.53, soft) * 0.3;
		float bring = band(rho, 1.53, 1.95, soft) * (0.86 + 0.1 * sin(rho * 22.0));
		float aring = band(rho, 2.03, 2.27, soft) * (0.78 + 0.1 * sin(rho * 31.0));
		aring *= 1.0 - band(rho, 2.205, 2.222, soft) * 0.8;
		a = max(cring, max(bring, aring));
		col = mix(vec3(0.5, 0.46, 0.41), vec3(0.86, 0.78, 0.64), smoothstep(1.25, 1.8, rho));
		col *= 0.95 + 0.05 * sin(rho * 41.0);
	} else {
		float w = 0.012 + fwidth(rho);
		a = band(rho, 1.69, 1.73, w) * 0.5 + band(rho, 2.12, 2.16, w) * 0.85 + band(rho, 2.2, 2.4, 0.03) * 0.22 + band(rho, 2.53, 2.57, w) * 0.7;
		col = vec3(0.74, 0.82, 0.95);
	}
	if (a <= 0.003) discard;
	// the planet hides the part of the ring behind it
	vec3 d = P - EYE;
	float dl = length(d);
	d /= dl;
	vec3 oc = EYE - C;
	float b = dot(oc, d);
	float disc = b * b - (dot(oc, oc) - R * R);
	if (disc > 0.0) {
		float t = -b - sqrt(disc);
		if (t > 0.0 && t < dl) discard;
	}
	// the planet's shadow falls on the ring
	vec3 o2 = P - C;
	float b2 = dot(o2, LS);
	float disc2 = b2 * b2 - (dot(o2, o2) - R * R);
	float lit = 1.0;
	if (disc2 > 0.0 && -b2 - sqrt(disc2) > 0.0) lit = 0.22;
	lit *= 0.6 + 0.4 * abs(dot(N, LS));
	ALBEDO = col * lit;
	ALPHA = a;
}
