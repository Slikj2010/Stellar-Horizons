// The sun below the edge of its map section: corona, a body that fades into space, granulation and flares
// lifting off the limb. Drawn on a rectangle in board coordinates. Ported from paintSun in index.html.
shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec2 origin;   // board position of the rectangle's top-left
uniform vec2 size;     // its size
uniform vec2 center;   // the sun's centre
uniform float r;       // its radius
uniform float edge;    // the bottom edge of the map section
uniform float t = 0.0; // time, from the script

vec4 over(vec4 dst, vec4 src) { return src + dst * (1.0 - src.a); }  // premultiplied "source over"

void fragment() {
	vec2 p = origin + UV * size;
	float d = length(p - center);
	vec4 col = vec4(0.0);
	// corona
	float pulse = 1.0 + 0.035 * sin(t * 0.7);
	float r0 = r * 0.97, r1 = r * 1.17 * pulse;
	if (d < r * 1.2 && d > r0 && d < r1) {
		float k = (d - r0) / (r1 - r0);
		vec4 a = vec4(1.0, 170.0 / 255.0, 80.0 / 255.0, 0.45), b = vec4(1.0, 125.0 / 255.0, 45.0 / 255.0, 0.17), e = vec4(1.0, 90.0 / 255.0, 20.0 / 255.0, 0.0);
		vec4 g = k < 0.3 ? mix(a, b, k / 0.3) : mix(b, e, (k - 0.3) / 0.7);
		col = over(col, vec4(g.rgb * g.a, g.a));
	} else if (d <= r0) {
		col = over(col, vec4(vec3(1.0, 170.0 / 255.0, 80.0 / 255.0) * 0.45, 0.45));
	}
	// body below the cut
	if (d < r && p.y > edge - 8.0) {
		float y0 = edge - 8.0, y1 = edge + 60.0;
		float k = clamp((p.y - y0) / (y1 - y0), 0.0, 1.0);
		vec3 c1 = vec3(208.0, 88.0, 40.0) / 255.0, c2 = vec3(176.0, 64.0, 28.0) / 255.0;
		float al = k < 0.12 ? k / 0.12 : 1.0;
		vec3 c = k < 0.12 ? c1 : mix(c1, c2, (k - 0.12) / 0.88);
		col = over(col, vec4(c * al, al));
		// granulation: soft bright cells that flicker
		vec3 add = vec3(0.0);
		for (int i = 0; i < 30; i++) {
			float fi = float(i);
			float a = -1.5707963 + (fi - 15.0) * 0.045;
			float rr = r * (0.93 + 0.05 * sin(fi * 7.1));
			vec2 q = vec2(center.x + cos(a) * rr, max(center.y + sin(a) * rr, edge + 10.0 + mod(fi, 4.0) * 18.0));
			float fl = 0.5 + 0.5 * sin(t * (0.5 + mod(fi, 5.0) * 0.15) + fi);
			float dd = length(p - q);
			if (dd < 30.0) add += vec3(1.0, 185.0 / 255.0, 90.0 / 255.0) * 0.07 * fl * (1.0 - dd / 30.0);
		}
		col.rgb += add * col.a;
	}
	// flares lifting off the limb
	vec3 fla = vec3(0.0);
	for (int i = 0; i < 9; i++) {
		float fi = float(i);
		float base = -1.5707963 + (fi - 4.0) * 0.085 + 0.02 * sin(t * 0.13 + fi);
		float life = fract(t * (0.06 + fi * 0.01) + fi * 0.37);
		float s = sin(life * 3.14159265);
		float h = r * (0.02 + 0.05 * s) * (0.6 + 0.4 * abs(sin(fi * 3.3)));
		vec2 p0 = center + vec2(cos(base), sin(base)) * r;
		vec2 p1 = center + vec2(cos(base), sin(base)) * (r + h);
		vec2 mid = (p0 + p1) * 0.5;
		float ang = base + 1.5707963;
		vec2 lp = p - mid;
		vec2 rp = vec2(lp.x * cos(-ang) - lp.y * sin(-ang), lp.x * sin(-ang) + lp.y * cos(-ang));
		vec2 rad = vec2(h * 0.8 + 5.0, h * 0.4 + 3.0);
		if (dot(rp / rad, rp / rad) < 1.0) {
			float gr = h * 1.1 + 5.0;
			float k = clamp(length(p - p1) / gr, 0.0, 1.0);
			vec3 c = mix(vec3(1.0, 205.0 / 255.0, 130.0 / 255.0), vec3(1.0, 120.0 / 255.0, 40.0 / 255.0), k);
			fla += c * 0.22 * s * (1.0 - k);
		}
	}
	col.rgb += fla;
	// fade the whole layer out below the board edge
	float y0 = edge - 10.0, y1 = edge + 165.0;
	float f = 1.0;
	if (p.y > y0) {
		float k = clamp((p.y - y0) / (y1 - y0), 0.0, 1.0);
		f = k < 0.3 ? mix(1.0, 0.75, k / 0.3) : mix(0.75, 0.0, (k - 0.3) / 0.7);
	}
	COLOR = col * f;
}
