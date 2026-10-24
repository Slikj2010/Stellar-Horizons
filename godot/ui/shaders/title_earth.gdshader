// The title screen's Earth: a cloud-free globe plus an equirectangular cloud map re-projected onto the visible
// hemisphere at a slowly turning longitude (a port of menuClouds in index.html).
shader_type canvas_item;

uniform sampler2D clouds : filter_linear, repeat_enable;
uniform vec2 region = vec2(764.0, 693.0);   // size of this quad in title-image pixels
uniform vec2 center = vec2(412.0, 412.0);   // the globe's centre, relative to the quad
uniform float radius = 410.0;
uniform vec3 sun = vec3(0.62, -0.66, 0.42);
uniform float rot = 2.1;
uniform vec2 moon_c = vec2(-98.0, 472.0);   // the Moon in front of the globe, relative to the quad
uniform float moon_r = 148.0;

void fragment() {
	vec4 b = texture(TEXTURE, UV);
	vec2 px = UV * region;
	vec2 q = (px - center) / radius;
	float d2 = dot(q, q);
	vec3 col = b.rgb;
	if (d2 < 0.985 && length(px - moon_c) > moon_r) {
		float v = q.y;
		float u = q.x;
		float nz = sqrt(1.0 - d2);
		float lat = asin(clamp(v, -1.0, 1.0));
		float lon = asin(clamp(u / sqrt(max(1.0 - v * v, 1e-4)), -1.0, 1.0));
		float cu = fract((lon + 3.14159265 - rot) / 6.2831853);
		float dens = texture(clouds, vec2(cu, (lat + 1.5707963) / 3.14159265)).r;
		float L = clamp((u * sun.x + v * sun.y + nz * sun.z) * 1.15 + 0.2, 0.0, 1.0);
		float edge = min(1.0, (0.992 - sqrt(d2)) / 0.04) * (0.55 + 0.45 * nz);
		float sh = 0.8 + 0.2 * dens;
		vec3 cc = vec3(16.0 + 234.0 * L * sh, 22.0 + 232.0 * L * sh, 38.0 + 220.0 * L * sh) / 255.0;
		float a = min(1.0, dens * 1.15) * edge * (0.28 + 0.72 * L);
		col = mix(col, cc, a);
	}
	COLOR = vec4(col, b.a);
}
