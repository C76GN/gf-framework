## GFInputIconAtlasProvider: 可配置输入图标图集 Provider。
##
## 将 InputEvent 归一化为通用图标键，再通过显式映射或路径模板解析 Texture2D / RichText 图标。
## 框架不附带图标资源，也不规定项目的美术风格或平台命名。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputIconAtlasProvider
extends GFInputIconProvider


# --- 常量 ---

const _INPUT_EVENT_TOOLS = preload("res://addons/gf/standard/input/common/gf_input_event_tools.gd")
const _INPUT_EVENT_IDENTITY = preload("res://addons/gf/standard/input/common/gf_input_event_identity.gd")


# --- 导出变量 ---

## 图标根目录。路径模板中的 {root} 会使用该值。
## [br]
## @api public
@export var root_path: String = ""

## 图标风格名。路径模板中的 {style} 会使用该值。
## [br]
## @api public
@export var style: StringName = &"default"

## 平台名。为空时使用 options.platform 或 fallback_platform。
## [br]
## @api public
@export var platform: StringName = &""

## 平台回退名。
## [br]
## @api public
@export var fallback_platform: StringName = &"generic"

## 路径模板。可使用 {root}、{style}、{platform}、{icon}。
## [br]
## @api public
@export var path_pattern: String = "{root}/{style}/{platform}/{icon}.png"

## 显式路径映射，key 为 get_event_icon_candidates() 产生的图标键。
## [br]
## @api public
## [br]
## @schema icon_paths: Dictionary，以 StringName 或 String 图标键为键，值为 String Texture2D 资源路径。
@export var icon_paths: Dictionary = {}

## 显式纹理映射，key 为 get_event_icon_candidates() 产生的图标键。
## [br]
## @api public
## [br]
## @schema icon_textures: Dictionary，以 StringName 或 String 图标键为键，值为 Texture2D。
@export var icon_textures: Dictionary = {}

## RichText 输出多个图标时使用的分隔文本。
## [br]
## @api public
@export var rich_text_separator: String = " "

## 是否为带修饰键的键盘事件输出多个图标。
## [br]
## @api public
@export var split_key_modifiers: bool = true

## 是否缓存缺失的图标路径。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var cache_missing_paths: bool = true

## 成功加载纹理缓存容量；小于等于 0 表示不缓存新纹理。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var max_cached_textures: int = 128

## 缺失路径缓存容量；小于等于 0 表示不缓存缺失路径。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var max_cached_missing_paths: int = 256


# --- 私有变量 ---

var _texture_cache: Dictionary = {}
var _missing_path_cache: Dictionary = {}
var _texture_cache_order: PackedStringArray = PackedStringArray()
var _missing_path_cache_order: PackedStringArray = PackedStringArray()


# --- 公共方法 ---

## 设置图标路径映射。
## [br]
## @api public
## [br]
## @param icon_key: 图标键。
## [br]
## @param icon_resource_path: Texture2D 资源路径。
func set_icon_path(icon_key: StringName, icon_resource_path: String) -> void:
	if icon_key == &"":
		return
	if icon_resource_path.is_empty():
		_erase_dictionary_key(icon_paths, icon_key)
	else:
		icon_paths[icon_key] = icon_resource_path
	_erase_cache_entry(_texture_cache, _texture_cache_order, icon_resource_path)
	_erase_cache_entry(_missing_path_cache, _missing_path_cache_order, icon_resource_path)


## 设置图标纹理映射。
## [br]
## @api public
## [br]
## @param icon_key: 图标键。
## [br]
## @param texture: 图标纹理。
func set_icon_texture(icon_key: StringName, texture: Texture2D) -> void:
	if icon_key == &"":
		return
	if texture == null:
		_erase_dictionary_key(icon_textures, icon_key)
	else:
		icon_textures[icon_key] = texture


## 清空已加载的纹理缓存。
## [br]
## @api public
func clear_cache() -> void:
	_texture_cache.clear()
	_missing_path_cache.clear()
	_texture_cache_order.clear()
	_missing_path_cache_order.clear()


## 判断是否支持指定输入事件。
## [br]
## @api public
## [br]
## @param input_event: 输入事件。
## [br]
## @param options: 调用选项。
## [br]
## @schema options: Dictionary，可包含 allow_missing_paths、root_path、style、platform、path_pattern、split_key_modifiers 和 include_key_modifier_combo。
## [br]
## @return 支持返回 true。
func supports_event(input_event: InputEvent, options: Dictionary = {}) -> bool:
	if input_event == null:
		return false
	if _resolve_texture_for_candidates(get_event_icon_candidates(input_event, options)) != null:
		return true
	return not get_event_icon_path(input_event, options).is_empty()


## 获取输入事件图标。
## [br]
## @api public
## [br]
## @param input_event: 输入事件。
## [br]
## @param options: 调用选项。
## [br]
## @schema options: Dictionary，可包含 allow_missing_paths、root_path、style、platform、path_pattern、split_key_modifiers 和 include_key_modifier_combo。
## [br]
## @return 图标纹理；不存在时返回 null。
func get_event_icon(input_event: InputEvent, options: Dictionary = {}) -> Texture2D:
	if input_event == null:
		return null

	var candidates: PackedStringArray = get_event_icon_candidates(input_event, options)
	var mapped_texture: Texture2D = _resolve_texture_for_candidates(candidates)
	if mapped_texture != null:
		return mapped_texture

	var icon_path: String = _resolve_path_for_candidates(candidates, options)
	if icon_path.is_empty():
		return null
	if _texture_cache.has(icon_path):
		var cached_texture: Variant = _texture_cache[icon_path]
		return cached_texture if cached_texture is Texture2D else null
	if _path_is_known_missing(icon_path, options):
		return null
	if not ResourceLoader.exists(icon_path, "Texture2D"):
		_remember_missing_path(icon_path, options)
		return null

	var texture: Texture2D = _load_texture(icon_path)
	if texture != null:
		_remember_texture(icon_path, texture)
	else:
		_remember_missing_path(icon_path, options)
	return texture


## 获取输入事件 RichTextLabel BBCode。
## [br]
## @api public
## [br]
## @param input_event: 输入事件。
## [br]
## @param options: 调用选项。
## [br]
## @schema options: Dictionary，可包含 allow_missing_paths、icon_size、rich_text_separator、root_path、style、platform、path_pattern、split_key_modifiers 和 include_key_modifier_combo。
## [br]
## @return BBCode；无法解析时返回空字符串。
func get_event_rich_text(input_event: InputEvent, options: Dictionary = {}) -> String:
	if input_event == null:
		return ""

	var paths: PackedStringArray = _get_rich_text_icon_paths(input_event, options)
	if paths.is_empty():
		return ""

	var parts: PackedStringArray = PackedStringArray()
	var size: int = GFVariantData.get_option_int(options, "icon_size", icon_size)
	for icon_path: String in paths:
		_append_packed_string(parts, _make_image_tag(icon_path, size))
	return GFVariantData.get_option_string(options, "rich_text_separator", rich_text_separator).join(parts)


## 获取输入事件的首选图标路径。
## [br]
## @api public
## [br]
## @param input_event: 输入事件。
## [br]
## @param options: 调用选项。
## [br]
## @schema options: Dictionary，可包含 allow_missing_paths、root_path、style、platform、path_pattern、split_key_modifiers 和 include_key_modifier_combo。
## [br]
## @return 图标路径；无法解析时返回空字符串。
func get_event_icon_path(input_event: InputEvent, options: Dictionary = {}) -> String:
	if input_event == null:
		return ""
	return _resolve_path_for_candidates(get_event_icon_candidates(input_event, options), options)


## 获取输入事件的首选图标键。
## [br]
## @api public
## [br]
## @param input_event: 输入事件。
## [br]
## @param options: 调用选项。
## [br]
## @schema options: Dictionary，可包含 split_key_modifiers 和 include_key_modifier_combo。
## [br]
## @return 图标键；无法解析时返回空 StringName。
func resolve_event_icon_key(input_event: InputEvent, options: Dictionary = {}) -> StringName:
	var candidates: PackedStringArray = get_event_icon_candidates(input_event, options)
	return StringName(candidates[0]) if not candidates.is_empty() else &""


## 获取输入事件可能使用的图标键列表。
## [br]
## @api public
## [br]
## @param input_event: 输入事件。
## [br]
## @param options: 调用选项。
## [br]
## @schema options: Dictionary，可包含 split_key_modifiers 和 include_key_modifier_combo。
## [br]
## @return 图标键列表，按优先级排序。
func get_event_icon_candidates(input_event: InputEvent, options: Dictionary = {}) -> PackedStringArray:
	return _INPUT_EVENT_IDENTITY.get_icon_candidates(input_event, options)


# --- 私有/辅助方法 ---

func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var removed: bool = target.erase(key)
	if removed:
		return


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _get_rich_text_icon_paths(input_event: InputEvent, options: Dictionary) -> PackedStringArray:
	var key_event: InputEventKey = _INPUT_EVENT_TOOLS.get_key_event(input_event)
	if key_event != null and GFVariantData.get_option_bool(options, "split_key_modifiers", split_key_modifiers):
		var paths: PackedStringArray = PackedStringArray()
		for modifier: String in _get_key_modifier_names(key_event):
			var modifier_path: String = _resolve_path_for_candidates(PackedStringArray(["key:%s" % modifier]), options)
			if modifier_path.is_empty():
				return PackedStringArray()
			_append_packed_string(paths, modifier_path)

		var key_only: InputEventKey = _duplicate_key_event(key_event)
		if key_only == null:
			return PackedStringArray()
		key_only.ctrl_pressed = false
		key_only.alt_pressed = false
		key_only.shift_pressed = false
		key_only.meta_pressed = false
		var key_path: String = get_event_icon_path(key_only, options)
		if key_path.is_empty():
			return PackedStringArray()
		_append_packed_string(paths, key_path)
		return paths

	var icon_path: String = get_event_icon_path(input_event, options)
	if icon_path.is_empty():
		return PackedStringArray()
	return PackedStringArray([icon_path])


func _resolve_texture_for_candidates(candidates: PackedStringArray) -> Texture2D:
	for candidate: String in candidates:
		var texture: Variant = _get_mapping_value(icon_textures, candidate)
		if texture is Texture2D:
			return texture
	return null


func _resolve_path_for_candidates(candidates: PackedStringArray, options: Dictionary) -> String:
	for candidate: String in candidates:
		var mapped_path: String = GFVariantData.to_text(_get_mapping_value(icon_paths, candidate))
		if not mapped_path.is_empty() and _path_is_allowed(mapped_path, options):
			return mapped_path

	for candidate: String in candidates:
		var generated_path: String = _build_icon_path(candidate, options)
		if not generated_path.is_empty() and _path_is_allowed(generated_path, options):
			return generated_path
	return ""


func _build_icon_path(icon_key: String, options: Dictionary) -> String:
	var root: String = GFVariantData.get_option_string(options, "root_path", root_path)
	var selected_style: String = GFVariantData.get_option_string(options, "style", str(style))
	var selected_platform: String = GFVariantData.get_option_string(options, "platform", str(platform))
	if selected_platform.is_empty():
		selected_platform = str(fallback_platform)
	var icon_name: String = _sanitize_icon_name(icon_key.replace(":", "_").replace("+", "_"))
	var resolved_path: String = GFVariantData.get_option_string(options, "path_pattern", path_pattern)
	resolved_path = resolved_path.replace("{root}", root.trim_suffix("/"))
	resolved_path = resolved_path.replace("{style}", selected_style)
	resolved_path = resolved_path.replace("{platform}", selected_platform)
	resolved_path = resolved_path.replace("{icon}", icon_name)
	return resolved_path


func _path_is_allowed(icon_resource_path: String, options: Dictionary) -> bool:
	if icon_resource_path.is_empty():
		return false
	if not _path_has_allowed_scheme(icon_resource_path):
		return false
	if GFVariantData.get_option_bool(options, "allow_missing_paths", false):
		return true
	if _path_is_known_missing(icon_resource_path, options):
		return false
	if ResourceLoader.exists(icon_resource_path, "Texture2D"):
		return true
	_remember_missing_path(icon_resource_path, options)
	return false


func _path_is_known_missing(icon_resource_path: String, options: Dictionary) -> bool:
	if not GFVariantData.get_option_bool(options, "cache_missing_paths", cache_missing_paths):
		return false
	return _missing_path_cache.has(icon_resource_path)


func _remember_texture(icon_resource_path: String, texture: Texture2D) -> void:
	if icon_resource_path.is_empty() or texture == null or max_cached_textures <= 0:
		return
	_texture_cache[icon_resource_path] = texture
	_append_cache_key(_texture_cache_order, icon_resource_path)
	_prune_cache_to_capacity(_texture_cache, _texture_cache_order, max_cached_textures)
	_erase_cache_entry(_missing_path_cache, _missing_path_cache_order, icon_resource_path)


func _remember_missing_path(icon_resource_path: String, options: Dictionary) -> void:
	if icon_resource_path.is_empty() or max_cached_missing_paths <= 0:
		return
	if not GFVariantData.get_option_bool(options, "cache_missing_paths", cache_missing_paths):
		return
	_missing_path_cache[icon_resource_path] = true
	_append_cache_key(_missing_path_cache_order, icon_resource_path)
	_prune_cache_to_capacity(_missing_path_cache, _missing_path_cache_order, max_cached_missing_paths)


func _append_cache_key(order: PackedStringArray, icon_resource_path: String) -> void:
	if order.has(icon_resource_path):
		return
	var _append_result: bool = order.append(icon_resource_path)


func _erase_cache_entry(cache: Dictionary, order: PackedStringArray, icon_resource_path: String) -> void:
	_erase_dictionary_key(cache, icon_resource_path)
	var index: int = order.find(icon_resource_path)
	if index >= 0:
		order.remove_at(index)


func _prune_cache_to_capacity(cache: Dictionary, order: PackedStringArray, capacity: int) -> void:
	while order.size() > capacity:
		var oldest_key: String = order[0]
		order.remove_at(0)
		_erase_dictionary_key(cache, oldest_key)


func _path_has_allowed_scheme(icon_resource_path: String) -> bool:
	return (
		icon_resource_path.begins_with("res://")
		or icon_resource_path.begins_with("uid://")
		or icon_resource_path.begins_with("user://")
	)


func _make_image_tag(icon_resource_path: String, size: int) -> String:
	var escaped_path: String = _escape_bbcode(icon_resource_path)
	if size > 0:
		return "[img=%d]%s[/img]" % [size, escaped_path]
	return "[img]%s[/img]" % escaped_path


func _escape_bbcode(text: String) -> String:
	var result: String = ""
	for index: int in range(text.length()):
		var character: String = text[index]
		if character == "[":
			result += "[lb]"
		elif character == "]":
			result += "[rb]"
		else:
			result += character
	return result


func _get_mapping_value(mapping: Dictionary, key: String) -> Variant:
	var string_name_key: StringName = StringName(key)
	if mapping.has(string_name_key):
		return mapping[string_name_key]
	if mapping.has(key):
		return mapping[key]
	return null


func _get_texture(value: Variant) -> Texture2D:
	if value is Texture2D:
		var texture: Texture2D = value
		return texture
	return null


func _load_texture(icon_path: String) -> Texture2D:
	var resource: Resource = ResourceLoader.load(icon_path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	return _get_texture(resource)


func _duplicate_key_event(event: InputEventKey) -> InputEventKey:
	var duplicate_event: Resource = event.duplicate()
	return _INPUT_EVENT_TOOLS.get_key_event(duplicate_event)


func _get_key_modifier_names(event: InputEventKey) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if event.ctrl_pressed:
		_append_packed_string(result, "ctrl")
	if event.alt_pressed:
		_append_packed_string(result, "alt")
	if event.shift_pressed:
		_append_packed_string(result, "shift")
	if event.meta_pressed:
		_append_packed_string(result, "meta")
	return result


func _sanitize_icon_name(value: String) -> String:
	var result: String = value.strip_edges().to_lower()
	result = result.replace(" ", "_")
	result = result.replace("/", "_")
	result = result.replace("\\", "_")
	result = result.replace(".", "_")
	return result
