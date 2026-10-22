// Overlay for corrupted bodies: pulsing dark-red fresnel rim ("Glowing").
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never;

uniform vec4 rim_color : source_color = vec4(0.9, 0.1, 0.35, 1.0);
uniform float strength = 0.0;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float pulse = 0.75 + 0.25 * sin(TIME * 3.0);
	ALBEDO = rim_color.rgb * fres * strength * pulse * 2.0;
}
