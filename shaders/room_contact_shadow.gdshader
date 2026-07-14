shader_type canvas_item;
render_mode unshaded, blend_mix;

/// İzometrik oda altına yumuşak temas gölgesi.
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.55);
uniform float softness : hint_range(0.1, 0.9) = 0.42;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	// İzometrik elips
	uv.x *= 1.35;
	uv.y *= 0.85;
	float d = length(uv);
	float a = (1.0 - smoothstep(softness, 1.0, d)) * shadow_color.a;
	COLOR = vec4(shadow_color.rgb, a);
}
