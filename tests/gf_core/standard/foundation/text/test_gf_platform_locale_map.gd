## 测试平台语言键到 Godot locale 的中立映射表。
extends GutTest


# --- 测试方法 ---

func test_platform_locale_map_round_trips_entries_and_fallbacks() -> void:
	var locale_map: GFPlatformLocaleMap = GFPlatformLocaleMap.new()
	locale_map.default_locale = "en"
	var _entry: Dictionary = locale_map.set_mapping(&"sample_platform", "ZH-CN", "zh_CN", "zh", "Simplified Chinese")

	var mapped_locale: String = locale_map.map_locale(&"sample_platform", "zh-cn")
	var mapped_fallback: String = locale_map.map_fallback_locale(&"sample_platform", "zh-cn")
	var missing_locale: String = locale_map.map_locale(&"sample_platform", "missing")
	var copy: GFPlatformLocaleMap = GFPlatformLocaleMap.from_dict(locale_map.to_dict())

	assert_eq(mapped_locale, "zh_CN", "平台语言 key 应大小写不敏感地映射到 Godot locale。")
	assert_eq(mapped_fallback, "zh", "fallback locale 应保留。")
	assert_eq(missing_locale, "en", "未命中时应回退 default_locale。")
	assert_eq(copy.map_locale(&"sample_platform", "zh-cn"), "zh_CN", "映射表应能字典往返。")


func test_platform_locale_map_replaces_entries_by_platform_and_key() -> void:
	var locale_map: GFPlatformLocaleMap = GFPlatformLocaleMap.new()
	var _first: Dictionary = locale_map.set_mapping(&"sample_platform", "english", "en")
	var _second: Dictionary = locale_map.set_mapping(&"sample_platform", "English", "en_US")

	assert_eq(locale_map.entries.size(), 1, "相同平台和语言 key 应替换旧条目。")
	assert_eq(locale_map.map_locale(&"sample_platform", "english"), "en_US", "替换后的 locale 应生效。")
	assert_true(locale_map.erase_mapping(&"sample_platform", "english"), "已存在映射应可移除。")
	assert_true(locale_map.entries.is_empty(), "移除后映射表应为空。")
