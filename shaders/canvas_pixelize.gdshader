shader_type canvas_item;
render_mode unshaded;

/// SubViewportContainer TEXTURE üzerinde nearest pixelize.
/// SCREEN_TEXTURE kullanma — ColorRect kendi beyazını örnekleyip ekranı boyar.
uniform float pixel_size = 3.0;

void fragment() {
	float ps = max(pixel_size, 1.0);
	if (ps <= 1.01) {
		COLOR = texture(TEXTURE, UV);
		return;
	}
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 raster = 1.0 / px;
	vec2 dest = UV * raster;
	vec2 sample_at = floor(dest / ps) * ps + floor(ps * 0.5);
	sample_at = clamp(sample_at, vec2(0.0), raster - vec2(1.0));
	COLOR = texture(TEXTURE, (sample_at + 0.5) * px);
}
