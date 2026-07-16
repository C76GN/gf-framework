## GFPlatformLocaleMap: 平台语言键到 Godot locale 的映射表。
##
## 该资源用于让 Steam、微信、主机平台或自建启动器等 adapter 把自身语言键转换为
## Godot TranslationServer 使用的 locale。GF 不内置任何具体平台表。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 8.0.0
class_name GFPlatformLocaleMap
extends Resource


# --- 导出变量 ---

## 映射表条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema entries: Array[Dictionary]，每项包含 platform_id、platform_locale、locale、fallback_locale 和 display_name。
@export var entries: Array[Dictionary] = []

## 未命中时返回的默认 locale。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var default_locale: String = ""


# --- 公共方法 ---

## 设置或替换映射条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param platform_id: 平台标识。
## [br]
## @param platform_locale: 平台语言键。
## [br]
## @param locale: Godot locale。
## [br]
## @param fallback_locale: fallback Godot locale。
## [br]
## @param display_name: 展示名。
## [br]
## @return 写入后的条目副本。
## [br]
## @schema return: Dictionary locale mapping entry.
func set_mapping(
	platform_id: StringName,
	platform_locale: String,
	locale: String,
	fallback_locale: String = "",
	display_name: String = ""
) -> Dictionary:
	var entry: Dictionary = make_entry(platform_id, platform_locale, locale, fallback_locale, display_name)
	if entry.is_empty():
		return {}
	var index: int = _find_entry_index(platform_id, platform_locale)
	if index >= 0:
		entries[index] = entry
	else:
		entries.append(entry)
	return entry.duplicate(true)


## 获取映射条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param platform_id: 平台标识。
## [br]
## @param platform_locale: 平台语言键。
## [br]
## @return 映射条目副本；不存在时为空字典。
## [br]
## @schema return: Dictionary locale mapping entry.
func get_mapping(platform_id: StringName, platform_locale: String) -> Dictionary:
	var index: int = _find_entry_index(platform_id, platform_locale)
	if index < 0:
		return {}
	return entries[index].duplicate(true)


## 映射到 Godot locale。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param platform_id: 平台标识。
## [br]
## @param platform_locale: 平台语言键。
## [br]
## @param fallback_value: 未命中时的调用方 fallback。
## [br]
## @return Godot locale。
func map_locale(platform_id: StringName, platform_locale: String, fallback_value: String = "") -> String:
	var entry: Dictionary = get_mapping(platform_id, platform_locale)
	if not entry.is_empty():
		return GFVariantData.get_option_string(entry, "locale")
	if not fallback_value.strip_edges().is_empty():
		return fallback_value.strip_edges()
	return default_locale.strip_edges()


## 映射到 fallback Godot locale。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param platform_id: 平台标识。
## [br]
## @param platform_locale: 平台语言键。
## [br]
## @param fallback_value: 未命中时的调用方 fallback。
## [br]
## @return fallback Godot locale。
func map_fallback_locale(platform_id: StringName, platform_locale: String, fallback_value: String = "") -> String:
	var entry: Dictionary = get_mapping(platform_id, platform_locale)
	if not entry.is_empty():
		var mapped_fallback: String = GFVariantData.get_option_string(entry, "fallback_locale").strip_edges()
		if not mapped_fallback.is_empty():
			return mapped_fallback
		return GFVariantData.get_option_string(entry, "locale")
	if not fallback_value.strip_edges().is_empty():
		return fallback_value.strip_edges()
	return default_locale.strip_edges()


## 移除映射条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param platform_id: 平台标识。
## [br]
## @param platform_locale: 平台语言键。
## [br]
## @return 找到并移除时返回 true。
func erase_mapping(platform_id: StringName, platform_locale: String) -> bool:
	var index: int = _find_entry_index(platform_id, platform_locale)
	if index < 0:
		return false
	entries.remove_at(index)
	return true


## 转换为字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 映射表字典。
## [br]
## @schema return: Dictionary with entries and default_locale.
func to_dict() -> Dictionary:
	return {
		"entries": _copy_entries(entries),
		"default_locale": default_locale,
	}


## 从字典应用映射表。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 映射表字典。
## [br]
## @schema data: Dictionary with entries and default_locale.
func apply_dict(data: Dictionary) -> void:
	entries = _copy_entries_from_array(GFVariantData.get_option_array(data, "entries"))
	default_locale = GFVariantData.get_option_string(data, "default_locale").strip_edges()


## 创建映射表深拷贝。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 新映射表。
func duplicate_map() -> GFPlatformLocaleMap:
	return from_dict(to_dict())


## 创建映射条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param platform_id: 平台标识。
## [br]
## @param platform_locale: 平台语言键。
## [br]
## @param locale: Godot locale。
## [br]
## @param fallback_locale: fallback Godot locale。
## [br]
## @param display_name: 展示名。
## [br]
## @return 映射条目。
## [br]
## @schema return: Dictionary locale mapping entry.
static func make_entry(
	platform_id: StringName,
	platform_locale: String,
	locale: String,
	fallback_locale: String = "",
	display_name: String = ""
) -> Dictionary:
	var normalized_platform_locale: String = _normalize_platform_locale(platform_locale)
	var normalized_locale: String = locale.strip_edges()
	if platform_id == &"" or normalized_platform_locale.is_empty() or normalized_locale.is_empty():
		return {}
	return {
		"platform_id": platform_id,
		"platform_locale": normalized_platform_locale,
		"locale": normalized_locale,
		"fallback_locale": fallback_locale.strip_edges(),
		"display_name": display_name.strip_edges(),
	}


## 从字典创建映射表。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 映射表字典。
## [br]
## @schema data: Dictionary with entries and default_locale.
## [br]
## @return 新映射表。
static func from_dict(data: Dictionary) -> GFPlatformLocaleMap:
	var result: GFPlatformLocaleMap = GFPlatformLocaleMap.new()
	result.apply_dict(data)
	return result


# --- 私有/辅助方法 ---

func _find_entry_index(platform_id: StringName, platform_locale: String) -> int:
	var normalized_platform_locale: String = _normalize_platform_locale(platform_locale)
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		if (
			GFVariantData.get_option_string_name(entry, "platform_id") == platform_id
			and GFVariantData.get_option_string(entry, "platform_locale") == normalized_platform_locale
		):
			return index
	return -1


static func _copy_entries(source_entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in source_entries:
		result.append(entry.duplicate(true))
	return result


static func _copy_entries_from_array(source_entries: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_value: Variant in source_entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var normalized_entry: Dictionary = make_entry(
			GFVariantData.get_option_string_name(entry, "platform_id"),
			GFVariantData.get_option_string(entry, "platform_locale"),
			GFVariantData.get_option_string(entry, "locale"),
			GFVariantData.get_option_string(entry, "fallback_locale"),
			GFVariantData.get_option_string(entry, "display_name")
		)
		if not normalized_entry.is_empty():
			result.append(normalized_entry)
	return result


static func _normalize_platform_locale(platform_locale: String) -> String:
	return platform_locale.strip_edges().to_lower()
