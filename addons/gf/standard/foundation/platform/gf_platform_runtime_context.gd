## GFPlatformRuntimeContext: 平台运行时上下文。
##
## 聚合平台标识、adapter 标识、能力集合、显示信息、存储根和启动参数。该资源只
## 记录 adapter 提供的事实，不调用 SDK、不执行登录、不创建网络连接。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 8.0.0
class_name GFPlatformRuntimeContext
extends Resource


# --- 导出变量 ---

## 平台标识。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var platform_id: StringName = &""

## Adapter 标识。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var adapter_id: StringName = &""

## 平台展示名。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var display_name: String = ""

## 能力集合。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var capabilities: GFPlatformCapabilitySet = GFPlatformCapabilitySet.new()

## Godot locale。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var locale: String = ""

## fallback Godot locale。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var fallback_locale: String = ""

## 平台像素比。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var pixel_ratio: float = 1.0

## 逻辑窗口尺寸。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var window_size: Vector2i = Vector2i.ZERO

## 物理屏幕尺寸。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var screen_size: Vector2i = Vector2i.ZERO

## 平台安全区域。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var safe_area: Rect2i = Rect2i()

## 逻辑存储根映射。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema storage_roots: Dictionary[String, String]，key 为逻辑 root_id。
@export var storage_roots: Dictionary = {}

## 启动参数。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema launch_options: Dictionary adapter-defined launch options.
@export var launch_options: Dictionary = {}

## 调用方元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema metadata: Dictionary caller-defined runtime metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置运行时上下文。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_platform_id: 平台标识。
## [br]
## @param options: 上下文选项。
## [br]
## @schema options: Dictionary，可包含 adapter_id、display_name、locale、fallback_locale、capabilities、capability_ids、window_size、screen_size、safe_area、pixel_ratio、storage_roots、launch_options 和 metadata。
## [br]
## @return 当前上下文。
func configure(p_platform_id: StringName, options: Dictionary = {}) -> GFPlatformRuntimeContext:
	platform_id = p_platform_id
	adapter_id = GFVariantData.get_option_string_name(options, "adapter_id")
	display_name = GFVariantData.get_option_string(options, "display_name").strip_edges()
	locale = GFVariantData.get_option_string(options, "locale").strip_edges()
	fallback_locale = GFVariantData.get_option_string(options, "fallback_locale").strip_edges()
	pixel_ratio = maxf(GFVariantData.get_option_float(options, "pixel_ratio", 1.0), 0.0)
	window_size = _to_vector2i(GFVariantData.get_option_value(options, "window_size"), Vector2i.ZERO)
	screen_size = _to_vector2i(GFVariantData.get_option_value(options, "screen_size"), Vector2i.ZERO)
	safe_area = _to_rect2i(GFVariantData.get_option_value(options, "safe_area"), Rect2i())
	storage_roots = _normalize_storage_roots(GFVariantData.get_option_dictionary(options, "storage_roots"))
	launch_options = GFVariantData.get_option_dictionary(options, "launch_options")
	metadata = GFVariantData.get_option_dictionary(options, "metadata")
	capabilities = _make_capability_set_from_options(p_platform_id, options)
	return self


## 设置能力集合。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_capabilities: 能力集合。
## [br]
## @return 当前上下文。
func set_capabilities(p_capabilities: GFPlatformCapabilitySet) -> GFPlatformRuntimeContext:
	if p_capabilities == null:
		capabilities = GFPlatformCapabilitySet.new().configure(platform_id, PackedStringArray(), {}, adapter_id)
	else:
		capabilities = p_capabilities.duplicate_set()
		if capabilities.platform_id == &"":
			capabilities.platform_id = platform_id
		if capabilities.adapter_id == &"":
			capabilities.adapter_id = adapter_id
	return self


## 添加能力。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param capability_id: 能力 ID。
## [br]
## @param capability_limits: 能力限制字段。
## [br]
## @schema capability_limits: Dictionary capability limits.
## [br]
## @return 成功添加或已存在时返回 true。
func add_capability(capability_id: StringName, capability_limits: Dictionary = {}) -> bool:
	_ensure_capabilities()
	return capabilities.add_capability(capability_id, capability_limits)


## 检查能力是否存在。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param capability_id: 能力 ID。
## [br]
## @return 存在返回 true。
func has_capability(capability_id: StringName) -> bool:
	_ensure_capabilities()
	return capabilities.has_capability(capability_id)


## 设置窗口与显示信息。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_window_size: 逻辑窗口尺寸。
## [br]
## @param p_screen_size: 物理屏幕尺寸。
## [br]
## @param p_pixel_ratio: 平台像素比。
## [br]
## @param p_safe_area: 平台安全区域。
## [br]
## @return 当前上下文。
func set_window_info(
	p_window_size: Vector2i,
	p_screen_size: Vector2i = Vector2i.ZERO,
	p_pixel_ratio: float = 1.0,
	p_safe_area: Rect2i = Rect2i()
) -> GFPlatformRuntimeContext:
	window_size = _clamp_vector2i(p_window_size)
	screen_size = _clamp_vector2i(p_screen_size)
	pixel_ratio = maxf(p_pixel_ratio, 0.0)
	safe_area = p_safe_area
	return self


## 设置逻辑存储根路径。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param root_id: 逻辑 root ID。
## [br]
## @param root_path: 平台路径。
## [br]
## @return 写入成功返回 true。
func set_storage_root(root_id: StringName, root_path: String) -> bool:
	var normalized_id: String = String(root_id).strip_edges()
	var normalized_path: String = root_path.strip_edges()
	if normalized_id.is_empty() or normalized_path.is_empty():
		return false
	storage_roots[normalized_id] = normalized_path
	return true


## 读取逻辑存储根路径。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param root_id: 逻辑 root ID。
## [br]
## @param default_value: 缺失时返回的默认路径。
## [br]
## @return 平台路径。
func get_storage_root(root_id: StringName, default_value: String = "") -> String:
	var normalized_id: String = String(root_id).strip_edges()
	if normalized_id.is_empty() or not storage_roots.has(normalized_id):
		return default_value
	return str(storage_roots[normalized_id])


## 移除逻辑存储根路径。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param root_id: 逻辑 root ID。
## [br]
## @return 找到并移除时返回 true。
func erase_storage_root(root_id: StringName) -> bool:
	var normalized_id: String = String(root_id).strip_edges()
	if normalized_id.is_empty() or not storage_roots.has(normalized_id):
		return false
	var _erased: bool = storage_roots.erase(normalized_id)
	return true


## 创建兼容性 Profile。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param profile_id: Profile ID；为空时使用 platform_id。
## [br]
## @return 兼容性 Profile。
func make_compatibility_profile(profile_id: StringName = &"") -> GFCompatibilityProfile:
	_ensure_capabilities()
	var resolved_profile_id: StringName = profile_id if profile_id != &"" else platform_id
	var profile: GFCompatibilityProfile = GFCompatibilityProfile.new()
	var _configured_profile: GFCompatibilityProfile = profile.configure(
		resolved_profile_id,
		"",
		"",
		PackedStringArray([String(platform_id)]),
		capabilities.capabilities,
		{
			"adapter_id": adapter_id,
			"display_name": display_name,
			"locale": locale,
			"fallback_locale": fallback_locale,
			"runtime_metadata": metadata.duplicate(true),
		}
	)
	return profile


## 转换为字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 平台上下文字典。
## [br]
## @schema return: Dictionary platform runtime context.
func to_dict() -> Dictionary:
	_ensure_capabilities()
	return {
		"platform_id": platform_id,
		"adapter_id": adapter_id,
		"display_name": display_name,
		"capabilities": capabilities.to_dict(),
		"locale": locale,
		"fallback_locale": fallback_locale,
		"pixel_ratio": pixel_ratio,
		"window_size": window_size,
		"screen_size": screen_size,
		"safe_area": safe_area,
		"storage_roots": storage_roots.duplicate(true),
		"launch_options": launch_options.duplicate(true),
		"metadata": metadata.duplicate(true),
	}


## 从字典应用平台上下文字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 平台上下文字典。
## [br]
## @schema data: Dictionary platform runtime context.
func apply_dict(data: Dictionary) -> void:
	platform_id = GFVariantData.get_option_string_name(data, "platform_id")
	adapter_id = GFVariantData.get_option_string_name(data, "adapter_id")
	display_name = GFVariantData.get_option_string(data, "display_name").strip_edges()
	var capability_data: Dictionary = GFVariantData.get_option_dictionary(data, "capabilities")
	capabilities = GFPlatformCapabilitySet.from_dict(capability_data)
	if capabilities.platform_id == &"":
		capabilities.platform_id = platform_id
	if capabilities.adapter_id == &"":
		capabilities.adapter_id = adapter_id
	locale = GFVariantData.get_option_string(data, "locale").strip_edges()
	fallback_locale = GFVariantData.get_option_string(data, "fallback_locale").strip_edges()
	pixel_ratio = maxf(GFVariantData.get_option_float(data, "pixel_ratio", 1.0), 0.0)
	window_size = _to_vector2i(GFVariantData.get_option_value(data, "window_size"), Vector2i.ZERO)
	screen_size = _to_vector2i(GFVariantData.get_option_value(data, "screen_size"), Vector2i.ZERO)
	safe_area = _to_rect2i(GFVariantData.get_option_value(data, "safe_area"), Rect2i())
	storage_roots = _normalize_storage_roots(GFVariantData.get_option_dictionary(data, "storage_roots"))
	launch_options = GFVariantData.get_option_dictionary(data, "launch_options")
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 创建运行时上下文深拷贝。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 新运行时上下文。
func duplicate_context() -> GFPlatformRuntimeContext:
	return from_dict(to_dict())


## 从字典创建运行时上下文。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 平台上下文字典。
## [br]
## @schema data: Dictionary platform runtime context.
## [br]
## @return 新运行时上下文。
static func from_dict(data: Dictionary) -> GFPlatformRuntimeContext:
	var result: GFPlatformRuntimeContext = GFPlatformRuntimeContext.new()
	result.apply_dict(data)
	return result


# --- 私有/辅助方法 ---

func _ensure_capabilities() -> void:
	if capabilities != null:
		return
	capabilities = GFPlatformCapabilitySet.new().configure(platform_id, PackedStringArray(), {}, adapter_id)


static func _make_capability_set_from_options(
	p_platform_id: StringName,
	options: Dictionary
) -> GFPlatformCapabilitySet:
	var adapter: StringName = GFVariantData.get_option_string_name(options, "adapter_id")
	var capability_value: Variant = GFVariantData.get_option_value(options, "capabilities")
	if capability_value is GFPlatformCapabilitySet:
		var source: GFPlatformCapabilitySet = capability_value
		var capability_copy: GFPlatformCapabilitySet = source.duplicate_set()
		if capability_copy.platform_id == &"":
			capability_copy.platform_id = p_platform_id
		if capability_copy.adapter_id == &"":
			capability_copy.adapter_id = adapter
		return capability_copy
	if capability_value is Dictionary:
		var capability_data: Dictionary = capability_value
		var result_from_dict: GFPlatformCapabilitySet = GFPlatformCapabilitySet.from_dict(capability_data)
		if result_from_dict.platform_id == &"":
			result_from_dict.platform_id = p_platform_id
		if result_from_dict.adapter_id == &"":
			result_from_dict.adapter_id = adapter
		return result_from_dict
	var capability_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(options, "capability_ids")
	return GFPlatformCapabilitySet.new().configure(p_platform_id, capability_ids, {}, adapter)


static func _normalize_storage_roots(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source.keys():
		var normalized_key: String = str(key).strip_edges()
		var normalized_path: String = str(source[key]).strip_edges()
		if normalized_key.is_empty() or normalized_path.is_empty():
			continue
		result[normalized_key] = normalized_path
	return result


static func _to_vector2i(value: Variant, default_value: Vector2i) -> Vector2i:
	if value is Vector2i:
		var value_vector2i: Vector2i = value
		return _clamp_vector2i(value_vector2i)
	if value is Vector2:
		var value_vector2: Vector2 = value
		return _clamp_vector2i(Vector2i(roundi(value_vector2.x), roundi(value_vector2.y)))
	if value is Dictionary:
		var data: Dictionary = value
		var dictionary_x: int = GFVariantData.get_option_int(data, "x", default_value.x)
		var dictionary_y: int = GFVariantData.get_option_int(data, "y", default_value.y)
		return _clamp_vector2i(Vector2i(dictionary_x, dictionary_y))
	if value is Array:
		var values: Array = value
		if values.size() >= 2:
			var array_x: int = GFVariantData.to_int(values[0], default_value.x)
			var array_y: int = GFVariantData.to_int(values[1], default_value.y)
			return _clamp_vector2i(Vector2i(array_x, array_y))
	return default_value


static func _to_rect2i(value: Variant, default_value: Rect2i) -> Rect2i:
	if value is Rect2i:
		var value_rect2i: Rect2i = value
		return value_rect2i
	if value is Rect2:
		var value_rect2: Rect2 = value
		return Rect2i(value_rect2)
	if value is Dictionary:
		var data: Dictionary = value
		var dictionary_x: int = GFVariantData.get_option_int(data, "x", default_value.position.x)
		var dictionary_y: int = GFVariantData.get_option_int(data, "y", default_value.position.y)
		var dictionary_width: int = max(GFVariantData.get_option_int(data, "width", default_value.size.x), 0)
		var dictionary_height: int = max(GFVariantData.get_option_int(data, "height", default_value.size.y), 0)
		return Rect2i(dictionary_x, dictionary_y, dictionary_width, dictionary_height)
	if value is Array:
		var values: Array = value
		if values.size() >= 4:
			var array_x: int = GFVariantData.to_int(values[0], default_value.position.x)
			var array_y: int = GFVariantData.to_int(values[1], default_value.position.y)
			var array_width: int = max(GFVariantData.to_int(values[2], default_value.size.x), 0)
			var array_height: int = max(GFVariantData.to_int(values[3], default_value.size.y), 0)
			return Rect2i(array_x, array_y, array_width, array_height)
	return default_value


static func _clamp_vector2i(value: Vector2i) -> Vector2i:
	var clamped_x: int = max(value.x, 0)
	var clamped_y: int = max(value.y, 0)
	return Vector2i(clamped_x, clamped_y)
