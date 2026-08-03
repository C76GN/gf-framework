extends GutTest


# --- 常量 ---

const _GF_PROJECT_SETTINGS_INSPECTOR_PLUGIN_SCRIPT = preload("res://addons/gf/kernel/editor/gf_project_settings_inspector_plugin.gd")
const _GF_PROJECT_SETTING_PRESENTATION_CATALOG_SCRIPT = preload("res://addons/gf/kernel/editor/gf_project_setting_presentation_catalog.gd")
const _GF_PLUGIN_PROJECT_SETTINGS_SCRIPT = preload("res://addons/gf/kernel/editor/gf_plugin_project_settings.gd")
const _GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_contribution_registry.gd")
const _GF_EXTENSION_SETTINGS_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _STANDARD_CONTRIBUTIONS_PATH: String = "res://addons/gf/standard/editor/gf_editor_contributions.json"


# --- 测试用例 ---

func test_builtin_setting_presentation_uses_tool_locale_and_english_fallback() -> void:
	var catalog: Object = _GF_PROJECT_SETTING_PRESENTATION_CATALOG_SCRIPT.new()
	var chinese: Dictionary = _get_presentation(
		catalog,
		_GF_EXTENSION_SETTINGS_SCRIPT.EXTENSION_SELECTION_MODE_SETTING,
		"zh_CN"
	)
	var language_only_chinese: Dictionary = _get_presentation(
		catalog,
		_GF_EXTENSION_SETTINGS_SCRIPT.EXTENSION_SELECTION_MODE_SETTING,
		"zh"
	)
	var fallback: Dictionary = _get_presentation(
		catalog,
		_GF_EXTENSION_SETTINGS_SCRIPT.EXTENSION_SELECTION_MODE_SETTING,
		"fr_FR"
	)

	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(chinese, "label"),
		"扩展选择模式",
		"简体中文工具语言应显示中文设置名。"
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(chinese, "tooltip").contains(
			_GF_EXTENSION_SETTINGS_SCRIPT.EXTENSION_SELECTION_MODE_SETTING
		),
		"悬浮说明应保留稳定设置键，便于搜索和排障。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(language_only_chinese, "label"),
		"扩展选择模式",
		"仅提供语言代码时应匹配同语言的地区化展示记录。"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(fallback, "label"),
		"Extension Selection Mode",
		"未提供的工具语言应回退英文。"
	)


func test_access_policy_setting_has_builtin_presentation() -> void:
	var catalog: Object = _GF_PROJECT_SETTING_PRESENTATION_CATALOG_SCRIPT.new()
	var presentation: Dictionary = _get_presentation(
		catalog,
		_GF_PLUGIN_PROJECT_SETTINGS_SCRIPT.ACCESS_POLICIES_SETTING,
		"zh_CN"
	)

	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(presentation, "label"),
		"框架访问策略",
		"访问策略 ProjectSetting 应有内核维护的中文名称。"
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(presentation, "tooltip").contains(
			_GF_PLUGIN_PROJECT_SETTINGS_SCRIPT.ACCESS_POLICIES_SETTING
		),
		"访问策略悬浮说明应保留稳定设置键。"
	)


func test_inspector_adapter_preserves_native_editor_and_stable_enum_metadata() -> void:
	var inspector_source: String = _read_text_file(
		"res://addons/gf/kernel/editor/gf_project_settings_inspector_plugin.gd"
	)
	var inspector_script: Script = _GF_PROJECT_SETTINGS_INSPECTOR_PLUGIN_SCRIPT
	assert_eq(
		String(inspector_script.get_instance_base_type()),
		"EditorInspectorPlugin",
		"项目设置展示适配器应保持 EditorInspectorPlugin 边界。"
	)
	assert_true(
		inspector_source.contains("EditorInspector.instantiate_property_editor("),
		"适配器应复用 Godot 原生属性编辑器工厂。"
	)
	assert_true(
		inspector_source.contains("SectionedInspectorFilter"),
		"适配器必须识别项目设置窗口实际传入的分区代理。"
	)
	assert_true(
		inspector_source.contains("option_button.get_item_metadata(index)"),
		"枚举本地化应从原生控件读取稳定值。"
	)
	assert_true(
		inspector_source.contains("option_button.set_item_text(index"),
		"枚举本地化只能改写可见文本。"
	)


func test_standard_setting_presentation_is_loaded_from_data_only_manifest() -> void:
	var manifest_records: Dictionary = _GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT.load_manifest_records(
		_STANDARD_CONTRIBUTIONS_PATH
	)
	var project_setting_records: Array[Dictionary] = _to_record_array(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(manifest_records, "project_setting_records", [])
	)
	var section_records: Array[Dictionary] = _to_record_array(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(
			manifest_records,
			"project_setting_section_records",
			[]
		)
	)
	var catalog: Object = _GF_PROJECT_SETTING_PRESENTATION_CATALOG_SCRIPT.new()
	var _configure_result: Variant = catalog.call(
		&"configure",
		project_setting_records,
		section_records
	)
	var presentation: Dictionary = _get_presentation(
		catalog,
		"gf/build/export/write_metadata",
		"zh_CN"
	)

	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(presentation, "label"),
		"写入构建元数据",
		"标准库设置展示信息应来自数据清单，不应写死在 kernel Inspector。"
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(presentation, "description").contains("导出"),
		"标准库设置应提供可操作的悬浮说明。"
	)
	var section_presentation: Dictionary = _get_section_presentation(
		catalog,
		"gf/build",
		"zh_CN"
	)
	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(section_presentation, "label"),
		"构建",
		"标准库设置分区展示信息应来自同一份 data-only manifest。"
	)


func test_builtin_project_settings_sections_have_labels_and_tooltips() -> void:
	var catalog: Object = _GF_PROJECT_SETTING_PRESENTATION_CATALOG_SCRIPT.new()
	var codegen: Dictionary = _get_section_presentation(catalog, "gf/codegen", "zh_CN")
	var root: Dictionary = _get_section_presentation(catalog, "gf", "zh_CN")

	assert_eq(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(codegen, "label"),
		"代码生成"
	)
	assert_true(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(codegen, "tooltip").contains(
			"gf/codegen"
		),
		"分区悬浮说明应保留稳定 section path。"
	)
	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(root, "label"), "GF")


func test_contribution_registry_rejects_incomplete_locale_metadata() -> void:
	var manifest_path: String = "user://gf_invalid_setting_presentation.json"
	var manifest: Dictionary = {
		"schema_version": _GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT.SCHEMA_VERSION,
		"package_id": "gf.test.editor",
		"project_setting_records": [
			{
				"owner_package_id": "gf.test.editor",
				"source_id": "setting.invalid_presentation",
				"name": "gf/test/invalid_presentation",
				"default_value": false,
				"type_name": "bool",
				"editor_labels": {
					"zh_CN": "缺少英文兜底",
				},
				"editor_descriptions": {
					"en": "Description",
				},
			},
		],
	}
	_write_json(manifest_path, manifest)

	var report: Dictionary = _GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT.load_manifest_report(manifest_path)
	_remove_path_if_exists(manifest_path)

	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok"), "缺失英文兜底的展示元数据应被严格拒绝。")
	assert_eq(
		_count_issue_kind(report, "missing_setting_presentation_fallback"),
		1,
		"报告应明确指出本地化兜底缺失。"
	)


# --- 私有/辅助方法 ---

func _get_presentation(catalog: Object, setting_name: String, locale: String) -> Dictionary:
	var value: Variant = catalog.call(&"get_presentation", setting_name, locale)
	return _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(value)


func _get_section_presentation(catalog: Object, section_path: String, locale: String) -> Dictionary:
	var value: Variant = catalog.call(&"get_section_presentation", section_path, locale)
	return _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(value)


func _to_record_array(value: Variant) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if not value is Array:
		return records
	var values: Array = value
	for record_value: Variant in values:
		if record_value is Dictionary:
			var record: Dictionary = record_value
			records.append(record.duplicate(true))
	return records


func _write_json(path: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建临时 JSON 清单。")
	if file == null:
		return
	var _store_result: bool = file.store_string(JSON.stringify(value))
	file.close()


func _read_text_file(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "测试应能读取目标脚本。")
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _remove_path_if_exists(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		var _remove_result: Error = DirAccess.remove_absolute(absolute_path)


func _count_issue_kind(report: Dictionary, issue_kind: String) -> int:
	var count: int = 0
	for issue_value: Variant in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(report, "issues"):
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "kind") == issue_kind:
			count += 1
	return count
