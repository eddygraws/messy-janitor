shader_type canvas_item;

uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.25) = 0.09;
uniform vec4 edge_color : source_color = vec4(0.65, 0.52, 0.28, 0.85);
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 col = COLOR;

	// World-space-ish noise using VERTEX for organic dissolve on polygons.
	vec2 nuv = (UV + VERTEX.xy * 0.002) * 6.5;
	float n = hash(floor(nuv)) * 0.65 + hash(nuv) * 0.35;

	if (n < dissolve) {
		discard;
	}

	float rim = smoothstep(dissolve, dissolve + edge_width, n);
	vec3 glow = edge_color.rgb * (1.0 - rim) * edge_color.a;
	glow *= 1.0 + pulse * 0.35;
	col.rgb = mix(col.rgb + glow, col.rgb, rim);

	COLOR = col;
}
