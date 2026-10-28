// A planet's ring on the 2D map. The printed ring art lies behind the planet sprite, so this draws the ring's near half
// over the planet (and, for Saturn, the bands the print leaves out, with the far half hidden behind the planet).
shader_type canvas_item;

uniform float tilt = -0.35;  // ring plane's tilt on screen (radians)
uniform float k = 0.5;       // minor / major axis ratio of the ring's ellipse
uniform float lim = 1.0;     // the square's half size in planet radii
uniform int kind = 0;        // 0 Saturn, 1 Neptune

float band(float x, float a, float b, float soft) { return smoothstep(a - soft, a + soft, x) * (1.0 - smoothstep(b - soft, b + soft, x)); }

void fragment() {
	vec2 q = (UV * 2.0 - 1.0) * lim;  // in planet radii, y down
	float d = length(q);
	float c = cos(tilt), s = sin(tilt);
	vec2 p = vec2(c * q.x + s * q.y, -s * q.x + c * q.y);
	bool near = p.y > 0.0;
	float rho = length(vec2(p.x, p.y / k));
	float soft = 0.006 + fwidth(rho);
	float a = 0.0;
	vec3 col = vec3(0.6);
	if (kind == 0) {
		if (!near && d < 0.985) discard;  // behind the planet
		float cring = band(rho, 1.42, 1.66, soft) * 0.3;
		float bring = band(rho, 1.66, 2.2, soft) * (0.9 + 0.08 * sin(rho * 95.0));
		a = max(cring, bring);
		col = mix(vec3(0.42, 0.4, 0.37), vec3(0.7, 0.65, 0.57), smoothstep(1.4, 1.9, rho));
		col *= 0.93 + 0.07 * sin(rho * 150.0);
	} else {
		if (!near || d > 1.0) discard;
		float w = 0.014 + fwidth(rho);
		a = max(max(band(rho, 1.93, 1.96, w), band(rho, 2.1, 2.13, w)), max(band(rho, 2.28, 2.31, w), max(band(rho, 2.45, 2.48, w), band(rho, 2.59, 2.62, w)))) * 0.85;
		col = vec3(0.82, 0.86, 0.93);
	}
	if (kind == 1) a *= smoothstep(1.0, 0.97, d);
	COLOR = vec4(col, a);
}
