// Full-screen post effect for the corruption system.
// intensity: 0 (pure) .. 1 (consumed), glitch: short hallucination spikes,
// soulless: grey "no soul" state, damage: red flash when hit.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float soulless : hint_range(0.0, 1.0) = 0.0;
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;

	// Horizontal tearing during glitches.
	float row = floor(uv.y * 48.0);
	float h = hash(vec2(row, floor(t * 24.0)));
	if (h < glitch * 0.35) {
		uv.x += (h - 0.5) * 0.12 * glitch;
	}

	// Slow breathing wobble with high corruption.
	uv += vec2(sin(uv.y * 11.0 + t * 1.3), cos(uv.x * 9.0 + t * 0.9)) * 0.0018 * intensity * intensity;

	vec2 dir = uv - vec2(0.5);
	float ca = 0.0015 + 0.005 * intensity + 0.025 * glitch;
	vec3 col;
	col.r = texture(screen_tex, uv + dir * ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir * ca).b;

	// Desaturate and tint toward bruised purple/red.
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l), clamp(0.3 * intensity + 0.75 * soulless, 0.0, 1.0));
	col = mix(col, col * vec3(1.12, 0.78, 1.0), 0.45 * intensity);

	// Vignette that closes in as corruption grows.
	float d = length(dir * vec2(1.0, 0.85));
	float vig = smoothstep(0.85 - 0.3 * intensity - 0.2 * soulless, 0.25, d);
	col *= mix(1.0, vig, 0.55 + 0.4 * intensity);

	// Dark veins creeping in from the edges.
	float veins = fbm(uv * vec2(7.0, 5.0) + vec2(t * 0.03, -t * 0.02));
	float vein_mask = smoothstep(0.48, 0.52, veins) * (1.0 - smoothstep(0.52, 0.6, veins));
	float edge = smoothstep(0.3, 0.75, d);
	col = mix(col, vec3(0.25, 0.0, 0.08), vein_mask * edge * intensity * 1.2);

	// Damage flash and hallucination white flash.
	col += vec3(0.7, 0.02, 0.05) * damage * (0.35 + edge);
	col = mix(col, vec3(0.9, 0.85, 1.0), flash);

	// Film grain.
	col += (hash(uv * 800.0 + t) - 0.5) * (0.02 + 0.05 * intensity + 0.1 * glitch);

	COLOR = vec4(col, 1.0);
}
