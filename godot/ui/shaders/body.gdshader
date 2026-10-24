// A spinning planet or moon: samples one row of bodies.png (an equirectangular map per body, with a round
// shading mask beside it) as a sphere turning about its axis. Ported from the WebGL body spinner in index.html.
shader_type canvas_item;
render_mode blend_mix;

uniform float row = 0.0;
uniform float rot = 0.0;   // turned by the script (radians)
uniform float AW = 384.0;  // atlas size
uniform float AH = 2048.0;
uniform float TW = 256.0;  // map tile size
uniform float TH = 128.0;
uniform float DS = 128.0;  // mask tile size


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

void fragment() {
	vec2 q = UV * 2.0 - 1.0;  // y points down, as on screen
	float d = length(q);
	if (d > 1.0) discard;
	vec3 c = body_color(TEXTURE, q, rot, row, TW, TH);
	vec4 m = texture(TEXTURE, vec2((TW + (q.x * 0.5 + 0.5) * DS) / AW, (row * TH + (q.y * 0.5 + 0.5) * DS) / AH));
	float a = m.a * smoothstep(1.0, 0.97, d);
	COLOR = vec4(c * m.r * 1.6, a);
}
