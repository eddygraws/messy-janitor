shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 0.6;
uniform float pulse_speed = 2.5;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;
	vec3 glow = glow_color.rgb * intensity * pulse;
	COLOR = vec4(tex.rgb + glow * tex.a, tex.a);
}
