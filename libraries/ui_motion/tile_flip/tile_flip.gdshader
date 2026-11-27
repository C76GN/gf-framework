shader_type canvas_item;
render_mode unshaded;

uniform sampler2D old_page : source_color, repeat_disable, filter_linear;
uniform sampler2D new_page : source_color, repeat_disable, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

uniform ivec2 grid = ivec2(12, 7);
uniform vec2 order_direction = vec2(1.0, 0.5);
uniform bool use_order_mask = false;
uniform sampler2D order_mask : hint_default_white, repeat_disable, filter_linear;
uniform float stagger : hint_range(0.0, 0.98) = 0.7;
uniform bool flip_vertical = false;
uniform float shading : hint_range(0.0, 1.0) = 0.35;
uniform vec4 gap_color : source_color = vec4(0.05, 0.06, 0.08, 1.0);

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
		vec2 count = max(vec2(grid), vec2(1.0));
		vec2 center = (floor(UV * count) + 0.5) / count;
		vec2 direction = order_direction / max(abs(order_direction.x) + abs(order_direction.y), 0.00001);
		float order = use_order_mask ? texture(order_mask, center).r : dot(center - 0.5, direction) + 0.5;
		float delay = clamp(stagger, 0.0, 0.98);
		float phase = clamp((progress - order * delay) / (1.0 - delay), 0.0, 1.0);
		float width = abs(cos(PI * phase));
		vec2 offset = UV - center;
		float along = flip_vertical ? offset.y * count.y : offset.x * count.x;
		if (width < 0.0001 || abs(along) * 2.0 > width) {
			COLOR = gap_color;
		} else {
			vec2 face_uv = UV;
			if (flip_vertical) {
				face_uv.y = center.y + offset.y / width;
			} else {
				face_uv.x = center.x + offset.x / width;
			}
			vec4 face = phase < 0.5 ? texture(old_page, face_uv) : texture(new_page, face_uv);
			face.rgb *= 1.0 - shading * (1.0 - width);
			COLOR = face;
		}
	}
	COLOR *= canvas_tint;
}
