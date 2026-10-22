// Glowing soul orb / spectral material. Used for soul items, ghosts and bolts.
shader_type spatial;
render_mode blend_mix, unshaded, cull_back, depth_draw_opaque;

uniform vec4 core_color : source_color = vec4(0.6, 0.95, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.45, 0.25, 1.0, 1.0);
uniform float energy = 2.5;
uniform float alpha_scale = 1.0;
uniform float swirl_speed = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float t = TIME * swirl_speed;
	float n = noise(UV * vec2(10.0, 5.0) + vec2(t * 0.4, t * 0.9));
	float swirl = sin(UV.x * 18.0 + UV.y * 9.0 + t * 3.0 + n * 6.0) * 0.5 + 0.5;
	vec3 c = mix(core_color.rgb, rim_color.rgb, clamp(fres + 0.2 * swirl, 0.0, 1.0));
	c *= 0.55 + 0.6 * swirl;
	c += rim_color.rgb * fres * 1.5;
	ALBEDO = c * energy;
	ALPHA = clamp((0.35 + fres * 0.9 + swirl * 0.25) * alpha_scale, 0.0, 1.0);
}
