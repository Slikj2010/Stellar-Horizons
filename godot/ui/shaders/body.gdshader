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

void fragment() {
	vec2 q = UV * 2.0 - 1.0;  // y points down, as on screen
	float d = length(q);
	if (d > 1.0) discard;
	float lat = asin(clamp(q.y, -1.0, 1.0));
	float cl = max(cos(lat), 1e-3);
	float lon = asin(clamp(q.x / cl, -1.0, 1.0)) + rot;
	float u = fract((lon + 3.14159265) / 6.2831853);
	float vv = (lat + 1.5707963) / 3.14159265;
	vec3 c = texture(TEXTURE, vec2(u * TW / AW, (row * TH + vv * TH) / AH)).rgb;
	vec4 m = texture(TEXTURE, vec2((TW + (q.x * 0.5 + 0.5) * DS) / AW, (row * TH + (q.y * 0.5 + 0.5) * DS) / AH));
	float a = m.a * smoothstep(1.0, 0.97, d);
	COLOR = vec4(c * m.r * 1.6, a);
}
