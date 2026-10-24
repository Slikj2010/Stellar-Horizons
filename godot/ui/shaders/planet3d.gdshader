// A planet or moon in the 3D view: one row of bodies.png (an equirectangular map per body) wrapped round a sphere.
shader_type spatial;
render_mode cull_back;

uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform float row = 0.0;
uniform float AW = 384.0;
uniform float AH = 2048.0;
uniform float TW = 256.0;
uniform float TH = 128.0;
uniform float glow = 0.42;  // self-light, so the night side still shows

void fragment() {
	float u = fract(UV.x);
	float v = clamp(UV.y, 0.004, 0.996);
	vec3 c = texture(atlas, vec2((u * (TW - 2.0) + 1.0) / AW, (row * TH + v * TH) / AH)).rgb;
	c = mix(vec3(dot(c, vec3(0.299, 0.587, 0.114))), c, 1.35);  // a touch more colour
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
	EMISSION = c * glow;
}
