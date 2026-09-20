# 验证框架诊断、项目日志与编辑器本地化展示之间的语言边界。
extends GutTest


# --- 常量 ---

const _PRESENTATION_CATALOG_SCRIPT = preload("res://addons/gf/kernel/editor/gf_project_setting_presentation_catalog.gd")
const _EXTENSION_SETTINGS_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")
const _FRAMEWORK_DIAGNOSTIC: String = "[GFProjectSettingsTools][project_settings_tools.setting_name_empty] setting_name must not be empty."
const _TRANSLATED_DIAGNOSTIC: String = "测试翻译：设置名不能为空。"
const _PROJECT_MESSAGE: String = "任务资源尚未准备好。"
const _TRANSLATED_PROJECT_MESSAGE: String = "Rewritten project message."
const _PROJECT_PATH: String = "res://关卡/第三章/存档.tres"


# --- 私有变量 ---

var _original_locale: String = ""
var _original_pseudolocalization_enabled: bool = false
var _test_translations: Array[Translation] = []
var _log_utility: GFLogUtility = null


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_original_locale = TranslationServer.get_locale()
	_original_pseudolocalization_enabled = TranslationServer.pseudolocalization_enabled
	TranslationServer.pseudolocalization_enabled = false
	_add_test_translation("en", _FRAMEWORK_DIAGNOSTIC, _TRANSLATED_PROJECT_MESSAGE)
	_add_test_translation("zh_CN", _TRANSLATED_DIAGNOSTIC, _PROJECT_MESSAGE)


func after_each() -> void:
	if _log_utility != null:
		_log_utility.dispose()
		_log_utility = null
	for translation: Translation in _test_translations:
		TranslationServer.remove_translation(translation)
	_test_translations.clear()
	TranslationServer.pseudolocalization_enabled = _original_pseudolocalization_enabled
	TranslationServer.set_locale(_original_locale)


# --- 测试用例 ---

func test_framework_diagnostic_ignores_project_translation_while_tool_labels_localize() -> void:
	var catalog: RefCounted = _PRESENTATION_CATALOG_SCRIPT.new()
	for project_locale: String in ["en", "zh_CN"]:
		TranslationServer.set_locale(project_locale)
		var translated: String = String(TranslationServer.translate(StringName(_FRAMEWORK_DIAGNOSTIC)))
		assert_eq(
			translated,
			_TRANSLATED_DIAGNOSTIC if project_locale == "zh_CN" else _FRAMEWORK_DIAGNOSTIC,
			"测试翻译资源必须生效，才能证明框架诊断没有使用项目翻译。"
		)

		var wrote_setting: bool = GFProjectSettingsTools.ensure_setting(" \t", 0)

		assert_false(wrote_setting, "空设置名必须被拒绝，不应写入 ProjectSettings。")
		assert_push_error(_FRAMEWORK_DIAGNOSTIC)
		for tool_locale: String in ["en", "zh_CN", "fr_FR"]:
			var presentation: Dictionary = _get_setting_presentation(catalog, tool_locale)
			assert_eq(
				GFVariantData.get_option_string(presentation, "name"),
				_EXTENSION_SETTINGS_SCRIPT.EXTENSION_SELECTION_MODE_SETTING,
				"工具语言与项目语言的任意组合都必须保留稳定设置键。"
			)
			assert_eq(
				GFVariantData.get_option_string(presentation, "label"),
				"扩展选择模式" if tool_locale == "zh_CN" else "Extension Selection Mode",
				"工具展示独立选择中英文；缺少翻译的工具语言应回退英文。"
			)

	assert_push_error_count(2, "每种项目语言只应发出一次相同的原生错误。")
	assert_push_warning_count(0, "切换语言不能改变框架诊断的严重性。")


func test_project_log_preserves_chinese_message_and_path_in_native_warning() -> void:
	TranslationServer.set_locale("en")
	assert_eq(
		String(TranslationServer.translate(StringName(_PROJECT_MESSAGE))),
		_TRANSLATED_PROJECT_MESSAGE,
		"项目消息的测试翻译必须生效，才能证明日志转发保留调用方原文。"
	)
	_log_utility = GFLogUtility.new()
	_log_utility.warn("项目任务", _PROJECT_MESSAGE, { "path": _PROJECT_PATH })

	var entries: Array[Dictionary] = _log_utility.get_recent_entries()
	assert_eq(entries.size(), 1, "原生警告应同时产生一条内存日志。")
	if entries.size() != 1:
		return
	var entry: Dictionary = entries[0]
	var context: Dictionary = GFVariantData.get_option_dictionary(entry, "context")
	var output_text: String = GFVariantData.get_option_string(entry, "text")
	assert_eq(GFVariantData.get_option_string(entry, "tag"), "项目任务")
	assert_eq(GFVariantData.get_option_string(entry, "message"), _PROJECT_MESSAGE)
	assert_eq(GFVariantData.get_option_int(entry, "level", -1), GFLogUtility.LogLevel.WARN)
	assert_eq(GFVariantData.get_option_string(context, "path"), _PROJECT_PATH)
	assert_true(output_text.contains(_PROJECT_MESSAGE))
	assert_true(output_text.contains(_PROJECT_PATH))
	assert_push_warning(output_text, "GUT 必须捕获包含中文原文与路径的真实 push_warning。")
	assert_push_warning_count(1)
	assert_push_error_count(0)


# --- 私有/辅助方法 ---

func _add_test_translation(locale: String, diagnostic: String, project_message: String) -> void:
	var translation: Translation = Translation.new()
	translation.set_locale(locale)
	translation.add_message(StringName(_FRAMEWORK_DIAGNOSTIC), StringName(diagnostic))
	translation.add_message(StringName(_PROJECT_MESSAGE), StringName(project_message))
	TranslationServer.add_translation(translation)
	_test_translations.append(translation)


func _get_setting_presentation(catalog: RefCounted, tool_locale: String) -> Dictionary:
	var value: Variant = catalog.call(
		&"get_presentation",
		_EXTENSION_SETTINGS_SCRIPT.EXTENSION_SELECTION_MODE_SETTING,
		tool_locale
	)
	if value is Dictionary:
		var presentation: Dictionary = value
		return presentation
	return {}
