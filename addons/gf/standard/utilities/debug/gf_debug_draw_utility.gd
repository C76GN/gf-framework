## GFDebugDrawUtility: 通用调试绘制命令缓冲。
##
## 收集 2D/3D 线段、矩形、圆、文本等即时调试绘制命令。
## Utility 只维护抽象命令和生命周期，具体渲染可由项目层 Overlay/Viewport 适配。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFDebugDrawUtility
extends GFUtility


# --- 信号 ---

## 绘制命令发生变化时发出。
## [br]
## @api public
signal items_changed


# --- 枚举 ---

## 调试绘制命令类型。
## [br]
## @api public
enum PrimitiveType {
	## 2D 线段命令。
	LINE_2D,
	## 2D 矩形命令。
	RECT_2D,
	## 2D 圆形命令。
	CIRCLE_2D,
	## 2D 文本命令。
	TEXT_2D,
	## 3D 线段命令。
	LINE_3D,
	## 3D AABB 盒命令。
	BOX_3D,
	## 3D 文本命令。
	TEXT_3D,
	## 项目自定义命令。
	CUSTOM,
}


# --- 公共变量 ---

## 是否启用调试绘制。
## [br]
## @api public
var enabled: bool = true

## 默认生命周期。小于 0 表示永久保留，0 表示等待下一次 tick 后清理。
## [br]
## @api public
var default_lifetime_seconds: float = 0.0

## 最大命令数量。小于等于 0 表示不限制。
## [br]
## @api public
var max_items: int = 2048


# --- 私有变量 ---

var _items: Array[Dictionary] = []
var _channels_enabled: Dictionary = {}
var _next_item_id: int = 1


# --- GF 生命周期方法 ---

## 初始化调试绘制缓冲。
## [br]
## @api public
func init() -> void:
	_items.clear()
	_channels_enabled.clear()
	_next_item_id = 1


## 释放并清空调试绘制命令。
## [br]
## @api public
func dispose() -> void:
	clear()


## 推进运行时逻辑。
## [br]
## @api public
## [br]
## @param delta: 本帧时间增量（秒）。
func tick(delta: float) -> void:
	_expire_items(delta)


# --- 公共方法 ---

## 绘制 2D 线段。
## [br]
## @api public
## [br]
## @param from: 起点位置。
## [br]
## @param to: 终点位置。
## [br]
## @param color: 绘制颜色。
## [br]
## @param lifetime_seconds: 调试绘制命令保留时间（秒）。
## [br]
## @param channel: 调试绘制频道。
## [br]
## @param width: 绘制线宽。
## [br]
## @return 绘制命令 id。
func draw_line_2d(
	from: Vector2,
	to: Vector2,
	color: Color = Color.WHITE,
	lifetime_seconds: float = -1.0,
	channel: StringName = &"default",
	width: float = 1.0
) -> int:
	return push_item({
		"type": PrimitiveType.LINE_2D,
		"channel": channel,
		"from": from,
		"to": to,
		"color": color,
		"width": maxf(width, 0.0),
		"lifetime_seconds": lifetime_seconds,
	})


## 绘制 2D 向量。
## [br]
## @api public
## [br]
## @param origin: 向量起点，centered 选项启用时表示中心点。
## [br]
## @param vector: 要绘制的向量。
## [br]
## @param color: 主向量颜色。
## [br]
## @param lifetime_seconds: 调试绘制命令保留时间（秒）。
## [br]
## @param channel: 调试绘制频道。
## [br]
## @param width: 绘制线宽。
## [br]
## @param options: 绘制选项。
## [br]
## @schema options: Dictionary，支持 scale、length_mode、max_length、centered、draw_components、arrowhead、arrowhead_size、x_color、y_color。
## [br]
## @return 绘制命令 id 列表。
## [br]
## @schema return: Array[int]，包含主线、可选分量线和可选箭头线的命令 id。
func draw_vector_2d(
	origin: Vector2,
	vector: Vector2,
	color: Color = Color.WHITE,
	lifetime_seconds: float = -1.0,
	channel: StringName = &"default",
	width: float = 1.0,
	options: Dictionary = {}
) -> Array[int]:
	var resolved_vector: Vector2 = _resolve_debug_vector_2d(vector, options)
	var half_vector: Vector2 = resolved_vector * 0.5
	var centered: bool = GFVariantData.get_option_bool(options, "centered")
	var begin: Vector2 = origin - half_vector if centered else origin
	var end: Vector2 = origin + half_vector if centered else origin + resolved_vector
	var result: Array[int] = []
	result.append(draw_line_2d(begin, end, color, lifetime_seconds, channel, width))

	if GFVariantData.get_option_bool(options, "draw_components"):
		var corner: Vector2 = begin + Vector2(resolved_vector.x, 0.0)
		var x_color: Color = _get_debug_color_option(options, "x_color", Color.RED)
		var y_color: Color = _get_debug_color_option(options, "y_color", Color.GREEN)
		result.append(draw_line_2d(begin, corner, x_color, lifetime_seconds, channel, width))
		result.append(draw_line_2d(corner, end, y_color, lifetime_seconds, channel, width))

	if GFVariantData.get_option_bool(options, "arrowhead"):
		_append_vector_arrowhead_2d(result, begin, end, color, lifetime_seconds, channel, width, options)
	return result


## 绘制 2D 矩形。
## [br]
## @api public
## [br]
## @param rect: 矩形区域。
## [br]
## @param color: 绘制颜色。
## [br]
## @param lifetime_seconds: 调试绘制命令保留时间（秒）。
## [br]
## @param channel: 调试绘制频道。
## [br]
## @param filled: 是否填充绘制图形。
## [br]
## @param width: 绘制线宽。
## [br]
## @return 绘制命令 id。
func draw_rect_2d(
	rect: Rect2,
	color: Color = Color.WHITE,
	lifetime_seconds: float = -1.0,
	channel: StringName = &"default",
	filled: bool = false,
	width: float = 1.0
) -> int:
	return push_item({
		"type": PrimitiveType.RECT_2D,
		"channel": channel,
		"rect": rect,
		"color": color,
		"filled": filled,
		"width": maxf(width, 0.0),
		"lifetime_seconds": lifetime_seconds,
	})


## 绘制 2D 圆。
## [br]
## @api public
## [br]
## @param center: 要绘制圆形的中心点。
## [br]
## @param radius: 圆形半径。
## [br]
## @param color: 绘制颜色。
## [br]
## @param lifetime_seconds: 调试绘制命令保留时间（秒）。
## [br]
## @param channel: 调试绘制频道。
## [br]
## @param filled: 是否填充绘制图形。
## [br]
## @param width: 绘制线宽。
## [br]
## @return 绘制命令 id。
func draw_circle_2d(
	center: Vector2,
	radius: float,
	color: Color = Color.WHITE,
	lifetime_seconds: float = -1.0,
	channel: StringName = &"default",
	filled: bool = false,
	width: float = 1.0
) -> int:
	return push_item({
		"type": PrimitiveType.CIRCLE_2D,
		"channel": channel,
		"center": center,
		"radius": maxf(radius, 0.0),
		"color": color,
		"filled": filled,
		"width": maxf(width, 0.0),
		"lifetime_seconds": lifetime_seconds,
	})


## 绘制 2D 文本。
## [br]
## @api public
## [br]
## @param position: 绘制文本的位置。
## [br]
## @param text: 要绘制或输出的文本。
## [br]
## @param color: 绘制颜色。
## [br]
## @param lifetime_seconds: 调试绘制命令保留时间（秒）。
## [br]
## @param channel: 调试绘制频道。
## [br]
## @param font_size: 绘制文本字号。
## [br]
## @return 绘制命令 id。
func draw_text_2d(
	position: Vector2,
	text: String,
	color: Color = Color.WHITE,
	lifetime_seconds: float = -1.0,
	channel: StringName = &"default",
	font_size: int = 16
) -> int:
	return push_item({
		"type": PrimitiveType.TEXT_2D,
		"channel": channel,
		"position": position,
		"text": text,
		"color": color,
		"font_size": maxi(font_size, 1),
		"lifetime_seconds": lifetime_seconds,
	})


## 绘制 3D 线段。
## [br]
## @api public
## [br]
## @param from: 起点位置。
## [br]
## @param to: 终点位置。
## [br]
## @param color: 绘制颜色。
## [br]
## @param lifetime_seconds: 调试绘制命令保留时间（秒）。
## [br]
## @param channel: 调试绘制频道。
## [br]
## @param width: 绘制线宽。
## [br]
## @return 绘制命令 id。
func draw_line_3d(
	from: Vector3,
	to: Vector3,
	color: Color = Color.WHITE,
	lifetime_seconds: float = -1.0,
	channel: StringName = &"default",
	width: float = 1.0
) -> int:
	return push_item({
		"type": PrimitiveType.LINE_3D,
		"channel": channel,
		"from": from,
		"to": to,
		"color": color,
		"width": maxf(width, 0.0),
		"lifetime_seconds": lifetime_seconds,
	})


## 绘制 3D 向量。
## [br]
## @api public
## [br]
## @param origin: 向量起点，centered 选项启用时表示中心点。
## [br]
## @param vector: 要绘制的向量。
## [br]
## @param color: 主向量颜色。
## [br]
## @param lifetime_seconds: 调试绘制命令保留时间（秒）。
## [br]
## @param channel: 调试绘制频道。
## [br]
## @param width: 绘制线宽。
## [br]
## @param options: 绘制选项。
## [br]
## @schema options: Dictionary，支持 scale、length_mode、max_length、centered、draw_components、x_color、y_color、z_color。
## [br]
## @return 绘制命令 id 列表。
## [br]
## @schema return: Array[int]，包含主线和可选分量线的命令 id。
func draw_vector_3d(
	origin: Vector3,
	vector: Vector3,
	color: Color = Color.WHITE,
	lifetime_seconds: float = -1.0,
	channel: StringName = &"default",
	width: float = 1.0,
	options: Dictionary = {}
) -> Array[int]:
	var resolved_vector: Vector3 = _resolve_debug_vector_3d(vector, options)
	var half_vector: Vector3 = resolved_vector * 0.5
	var centered: bool = GFVariantData.get_option_bool(options, "centered")
	var begin: Vector3 = origin - half_vector if centered else origin
	var end: Vector3 = origin + half_vector if centered else origin + resolved_vector
	var result: Array[int] = []
	result.append(draw_line_3d(begin, end, color, lifetime_seconds, channel, width))

	if GFVariantData.get_option_bool(options, "draw_components"):
		var x_end: Vector3 = begin + Vector3(resolved_vector.x, 0.0, 0.0)
		var y_end: Vector3 = x_end + Vector3(0.0, resolved_vector.y, 0.0)
		var x_color: Color = _get_debug_color_option(options, "x_color", Color.RED)
		var y_color: Color = _get_debug_color_option(options, "y_color", Color.GREEN)
		var z_color: Color = _get_debug_color_option(options, "z_color", Color.BLUE)
		result.append(draw_line_3d(begin, x_end, x_color, lifetime_seconds, channel, width))
		result.append(draw_line_3d(x_end, y_end, y_color, lifetime_seconds, channel, width))
		result.append(draw_line_3d(y_end, end, z_color, lifetime_seconds, channel, width))
	return result


## 绘制 3D AABB。
## [br]
## @api public
## [br]
## @param box: 要绘制的 3D 包围盒。
## [br]
## @param color: 绘制颜色。
## [br]
## @param lifetime_seconds: 调试绘制命令保留时间（秒）。
## [br]
## @param channel: 调试绘制频道。
## [br]
## @param filled: 是否填充绘制图形。
## [br]
## @param width: 绘制线宽。
## [br]
## @return 绘制命令 id。
func draw_box_3d(
	box: AABB,
	color: Color = Color.WHITE,
	lifetime_seconds: float = -1.0,
	channel: StringName = &"default",
	filled: bool = false,
	width: float = 1.0
) -> int:
	return push_item({
		"type": PrimitiveType.BOX_3D,
		"channel": channel,
		"box": box,
		"color": color,
		"filled": filled,
		"width": maxf(width, 0.0),
		"lifetime_seconds": lifetime_seconds,
	})


## 绘制 3D 文本。
## [br]
## @api public
## [br]
## @param position: 绘制文本的位置。
## [br]
## @param text: 要绘制或输出的文本。
## [br]
## @param color: 绘制颜色。
## [br]
## @param lifetime_seconds: 调试绘制命令保留时间（秒）。
## [br]
## @param channel: 调试绘制频道。
## [br]
## @param font_size: 绘制文本字号。
## [br]
## @return 绘制命令 id。
func draw_text_3d(
	position: Vector3,
	text: String,
	color: Color = Color.WHITE,
	lifetime_seconds: float = -1.0,
	channel: StringName = &"default",
	font_size: int = 16
) -> int:
	return push_item({
		"type": PrimitiveType.TEXT_3D,
		"channel": channel,
		"position": position,
		"text": text,
		"color": color,
		"font_size": maxi(font_size, 1),
		"lifetime_seconds": lifetime_seconds,
	})


## 推入自定义调试绘制命令。
## [br]
## @api public
## [br]
## @param item: 命令字典。
## [br]
## @return 命令 id。
## [br]
## @schema item: Dictionary，至少可包含 type、channel、lifetime_seconds 以及项目自定义绘制载荷。
func push_item(item: Dictionary) -> int:
	var stored_item: Dictionary = item.duplicate(true)
	var item_id: int = _next_item_id
	var resolved_lifetime: float = _resolve_lifetime(GFVariantData.get_option_float(stored_item, "lifetime_seconds", -1.0))
	stored_item["id"] = item_id
	stored_item["channel"] = GFVariantData.get_option_string_name(stored_item, "channel", &"default")
	stored_item["created_at_msec"] = Time.get_ticks_msec()
	stored_item["lifetime_seconds"] = resolved_lifetime
	stored_item["remaining_seconds"] = resolved_lifetime
	_next_item_id += 1

	_items.append(stored_item)
	_trim_to_max_items()
	items_changed.emit()
	return item_id


## 清理命令。
## [br]
## @api public
## [br]
## @param channel: 指定频道；为空时清空全部。
func clear(channel: StringName = &"") -> void:
	if channel == &"":
		if _items.is_empty():
			return
		_items.clear()
		items_changed.emit()
		return

	var changed: bool = false
	for index: int in range(_items.size() - 1, -1, -1):
		if _get_item_channel(_items[index]) == channel:
			_items.remove_at(index)
			changed = true
	if changed:
		items_changed.emit()


## 设置频道启用状态。
## [br]
## @api public
## [br]
## @param channel: 频道。
## [br]
## @param channel_enabled: 是否启用。
func set_channel_enabled(channel: StringName, channel_enabled: bool) -> void:
	_channels_enabled[channel] = channel_enabled
	items_changed.emit()


## 检查频道是否启用。
## [br]
## @api public
## [br]
## @param channel: 频道。
## [br]
## @return 启用返回 true。
func is_channel_enabled(channel: StringName) -> bool:
	return GFVariantData.get_option_bool(_channels_enabled, channel, true)


## 获取绘制命令。
## [br]
## @api public
## [br]
## @param channel: 指定频道；为空时返回全部频道。
## [br]
## @param include_disabled: 是否包含已禁用频道或全局禁用状态下的命令。
## [br]
## @return 命令副本列表。
## [br]
## @schema return: Array[Dictionary]，每个元素为调试绘制命令，包含 id、type、channel、created_at_msec、lifetime_seconds、remaining_seconds 和图元载荷。
func get_items(channel: StringName = &"", include_disabled: bool = false) -> Array[Dictionary]:
	if not enabled and not include_disabled:
		return []

	var result: Array[Dictionary] = []
	for item: Dictionary in _items:
		var item_channel: StringName = _get_item_channel(item)
		if channel != &"" and item_channel != channel:
			continue
		if not include_disabled and not is_channel_enabled(item_channel):
			continue
		result.append(item.duplicate(true))
	return result


## 获取命令数量。
## [br]
## @api public
## [br]
## @param channel: 指定频道；为空时返回全部。
## [br]
## @return 数量。
func get_item_count(channel: StringName = &"") -> int:
	if channel == &"":
		return _items.size()
	var count: int = 0
	for item: Dictionary in _items:
		if _get_item_channel(item) == channel:
			count += 1
	return count


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 快照字典。
## [br]
## @schema return: Dictionary，包含 enabled、item_count、channels、primitive_types 和 max_items。
func get_debug_snapshot() -> Dictionary:
	var channels: Dictionary = {}
	var primitive_types: Dictionary = {}
	for item: Dictionary in _items:
		var channel: StringName = _get_item_channel(item)
		var primitive_type: int = _get_item_primitive_type(item)
		_increment_dictionary_int(channels, channel)
		_increment_dictionary_int(primitive_types, primitive_type)
	return {
		"enabled": enabled,
		"item_count": _items.size(),
		"channels": channels,
		"primitive_types": primitive_types,
		"max_items": max_items,
	}


# --- 私有/辅助方法 ---

func _resolve_debug_vector_2d(vector: Vector2, options: Dictionary) -> Vector2:
	var scale: float = GFVariantData.get_option_float(options, "scale", 1.0)
	var scaled: Vector2 = vector * scale
	return _apply_debug_vector_length_mode_2d(scaled, options)


func _resolve_debug_vector_3d(vector: Vector3, options: Dictionary) -> Vector3:
	var scale: float = GFVariantData.get_option_float(options, "scale", 1.0)
	var scaled: Vector3 = vector * scale
	return _apply_debug_vector_length_mode_3d(scaled, options)


func _apply_debug_vector_length_mode_2d(vector: Vector2, options: Dictionary) -> Vector2:
	var length_mode: String = GFVariantData.get_option_string(options, "length_mode", "normal").to_lower()
	var max_length: float = GFVariantData.get_option_float(options, "max_length")
	match length_mode:
		"clamp":
			return vector.limit_length(max_length) if max_length > 0.0 else vector
		"normalize":
			return vector.normalized() * max_length if max_length > 0.0 and not vector.is_zero_approx() else Vector2.ZERO
		_:
			return vector


func _apply_debug_vector_length_mode_3d(vector: Vector3, options: Dictionary) -> Vector3:
	var length_mode: String = GFVariantData.get_option_string(options, "length_mode", "normal").to_lower()
	var max_length: float = GFVariantData.get_option_float(options, "max_length")
	match length_mode:
		"clamp":
			return vector.limit_length(max_length) if max_length > 0.0 else vector
		"normalize":
			return vector.normalized() * max_length if max_length > 0.0 and not vector.is_zero_approx() else Vector3.ZERO
		_:
			return vector


func _append_vector_arrowhead_2d(
	result: Array[int],
	begin: Vector2,
	end: Vector2,
	color: Color,
	lifetime_seconds: float,
	channel: StringName,
	width: float,
	options: Dictionary
) -> void:
	var direction: Vector2 = end - begin
	if direction.is_zero_approx():
		return
	var size: float = maxf(GFVariantData.get_option_float(options, "arrowhead_size", width * 4.0), 0.0)
	if size <= 0.0:
		return
	var normal: Vector2 = direction.normalized()
	result.append(draw_line_2d(end, end - normal.rotated(PI / 6.0) * size, color, lifetime_seconds, channel, width))
	result.append(draw_line_2d(end, end - normal.rotated(-PI / 6.0) * size, color, lifetime_seconds, channel, width))


func _get_debug_color_option(options: Dictionary, key: String, fallback: Color) -> Color:
	if not options.has(key):
		return fallback
	var value: Variant = options[key]
	return value if value is Color else fallback


func _resolve_lifetime(lifetime_seconds: float) -> float:
	if lifetime_seconds < 0.0:
		return default_lifetime_seconds
	return lifetime_seconds


func _expire_items(delta: float) -> void:
	if _items.is_empty():
		return

	var changed: bool = false
	for index: int in range(_items.size() - 1, -1, -1):
		var item: Dictionary = _items[index]
		var lifetime_seconds: float = GFVariantData.get_option_float(item, "lifetime_seconds")
		if lifetime_seconds < 0.0:
			continue
		var remaining_seconds: float = GFVariantData.get_option_float(item, "remaining_seconds", lifetime_seconds) - maxf(delta, 0.0)
		_items[index]["remaining_seconds"] = remaining_seconds
		if remaining_seconds <= 0.0:
			_items.remove_at(index)
			changed = true
	if changed:
		items_changed.emit()


func _trim_to_max_items() -> void:
	if max_items <= 0:
		return
	var overflow: int = _items.size() - max_items
	if overflow <= 0:
		return
	var retained_items: Array[Dictionary] = []
	var resize_error: Error = retained_items.resize(max_items) as Error
	if resize_error != OK:
		return
	for index: int in range(max_items):
		retained_items[index] = _items[index + overflow]
	_items = retained_items


func _get_item_channel(item: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(item, "channel", &"default")


func _get_item_primitive_type(item: Dictionary) -> int:
	return GFVariantData.get_option_int(item, "type", PrimitiveType.CUSTOM)


func _increment_dictionary_int(target: Dictionary, key: Variant) -> void:
	target[key] = GFVariantData.get_option_int(target, key) + 1
