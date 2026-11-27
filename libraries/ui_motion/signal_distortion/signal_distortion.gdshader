shader_type canvas_item;
render_mode unshaded;

uniform sampler2D old_page : source_color, repeat_disable, filter_linear;
uniform sampler2D new_page : source_color, repeat_disable, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

uniform float band_height_pixels : hint_range(1.0, 128.0) = 14.0;
uniform float band_shift_pixels : hint_range(0.0, 128.0) = 18.0;
uniform vec2 channel_offset_pixels = vec2(5.0, 0.0);
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.22;
uniform float seed = 2.0;

vec4 distort(sampler2D page, vec2 uv, float phase) {
	vec2 size = vec2(textureSize(page, 0));
	float strength = 1.0 - abs(2.0 * phase - 1.0);
	float row = floor(uv.y * size.y);
	float band = floor(row / max(band_height_pixels, 1.0));
	// Drive noise from local progress so seeking reconstructs the same frame.
	float tick = floor(phase * 24.0);
	float noise = fract(sin(dot(vec2(band, tick), vec2(31.3, 13.7)) + seed) * 4375.67);
	uv.x += (noise * 2.0 - 1.0) * band_shift_pixels * strength / size.x;
	vec4 color = texture(page, uv);
	if (any(notEqual(channel_offset_pixels, vec2(0.0)))) {
		vec2 shift = channel_offset_pixels * strength / size;
		color.r = texture(page, uv + shift).r;
		color.b = texture(page, uv - shift).b;
	}
	color.rgb *= 1.0 - scanline_strength * strength * mod(row, 2.0);
	return color;
}

varying vec4 canvas_tint;

void vertex() {
	canvas_tint = COLOR;
}

void fragment() {
	if (progress <= 0.0) {
		COLOR = texture(old_page, UV);
	} else if (progress >= 1.0) {
		COLOR = texture(new_page, UV);
	} else if (progress < 0.5) {
		COLOR = distort(old_page, UV, progress);
	} else {
		COLOR = distort(new_page, UV, progress);
	}
	COLOR *= canvas_tint;
}
