shader_type canvas_item;
render_mode unshaded;

uniform sampler2D old_page : source_color, repeat_disable, filter_linear;
uniform sampler2D new_page : source_color, repeat_disable, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// Each pixel's value is its reveal time. GradientTexture2D, NoiseTexture2D
// and project-authored masks all use the same threshold in linear data space.
uniform vec2 direction = vec2(1.0, 0.0);
uniform bool use_mask_texture = false;
uniform sampler2D mask_texture : hint_default_white, repeat_disable, filter_linear;
uniform float softness : hint_range(0.00001, 0.5) = 0.008;

varying vec4 canvas_tint;

void vertex() {
	canvas_tint = COLOR;
}

void fragment() {
	if (progress <= 0.0) {
		COLOR = texture(old_page, UV);
	} else if (progress >= 1.0) {
		COLOR = texture(new_page, UV);
	} else {
		vec2 axis = direction / max(abs(direction.x) + abs(direction.y), 0.00001);
		float rank = use_mask_texture ? texture(mask_texture, UV).r : dot(UV - 0.5, axis) + 0.5;
		float visible = 1.0 - smoothstep(progress - softness, progress + softness, rank);
		COLOR = mix(texture(old_page, UV), texture(new_page, UV), visible);
	}
	COLOR *= canvas_tint;
}
