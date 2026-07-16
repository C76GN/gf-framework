@tool

# GF 项目设置多语言展示元数据目录。
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_PLUGIN_PROJECT_SETTINGS_SCRIPT = preload("res://addons/gf/kernel/editor/gf_plugin_project_settings.gd")
const _GF_EXTENSION_SETTINGS_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")


# --- 私有变量 ---

var _records_by_name: Dictionary = {}
var _section_records_by_path: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init() -> void:
	configure()


# --- 框架内部方法 ---

## 配置 GF 项目设置展示记录。
##
## 内置 kernel 设置优先；贡献记录只能为各自拥有的设置补充展示元数据，不能覆盖内置设置。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param contributed_records: 标准库或其他已校验来源贡献的项目设置记录。
## [br]
## @schema contributed_records: Array[Dictionary]，每项可包含 name、editor_labels、editor_descriptions、editor_enum_labels 与 editor_enum_descriptions。
## [br]
## @param contributed_section_records: 标准库或其他已校验来源贡献的项目设置分区记录。
## [br]
## @schema contributed_section_records: Array[Dictionary]，每项包含 path、editor_labels 与 editor_descriptions。
func configure(
	contributed_records: Array[Dictionary] = [],
	contributed_section_records: Array[Dictionary] = []
) -> void:
	_records_by_name.clear()
	_section_records_by_path.clear()
	for record: Dictionary in _get_builtin_records():
		_register_record(record)
	for section_record: Dictionary in _get_builtin_section_records():
		_register_section_record(section_record)
	for record: Dictionary in contributed_records:
		_register_record(record)
	for section_record: Dictionary in contributed_section_records:
		_register_section_record(section_record)


## 获取指定设置在目标工具语言下的展示信息。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param setting_name: 稳定 ProjectSettings 键。
## [br]
## @param locale: Godot 工具语言；留空时读取当前编辑器工具语言。
## [br]
## @return 设置标签、说明、悬浮文本与枚举显示映射；未注册时返回空字典。
## [br]
## @schema return: Dictionary，包含 name、label、description、tooltip、enum_labels 与 enum_descriptions。
func get_presentation(setting_name: String, locale: String = "") -> Dictionary:
	var normalized_name: String = setting_name.strip_edges()
	if not _records_by_name.has(normalized_name):
		return {}

	var record_value: Variant = _records_by_name[normalized_name]
	if not record_value is Dictionary:
		return {}
	var record: Dictionary = record_value
	var effective_locale: String = locale.strip_edges()
	if effective_locale.is_empty():
		effective_locale = TranslationServer.get_tool_locale()

	var label: String = _resolve_localized_text(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(record, "editor_labels"),
		effective_locale
	)
	var description: String = _resolve_localized_text(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(record, "editor_descriptions"),
		effective_locale
	)
	if label.is_empty() or description.is_empty():
		return {}

	return {
		"name": normalized_name,
		"label": label,
		"description": description,
		"tooltip": _make_tooltip(description, normalized_name, effective_locale),
		"enum_labels": _resolve_localized_enum_text(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(record, "editor_enum_labels"),
			effective_locale
		),
		"enum_descriptions": _resolve_localized_enum_text(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(record, "editor_enum_descriptions"),
			effective_locale
		),
	}


## 获取当前目录拥有展示元数据的稳定项目设置键。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 按字典序排列的 ProjectSettings 键。
func get_setting_names() -> PackedStringArray:
	var setting_names: PackedStringArray = PackedStringArray()
	for setting_name_value: Variant in _records_by_name:
		if not setting_name_value is String:
			continue
		var setting_name: String = setting_name_value
		var _append_result: bool = setting_names.append(setting_name)
	setting_names.sort()
	return setting_names


## 获取指定项目设置分区在目标工具语言下的展示信息。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param section_path: 稳定 ProjectSettings 分区路径。
## [br]
## @param locale: Godot 工具语言；留空时读取当前编辑器工具语言。
## [br]
## @return 分区标签、说明与悬浮文本；未注册时返回空字典。
## [br]
## @schema return: Dictionary，包含 path、label、description 和 tooltip。
func get_section_presentation(section_path: String, locale: String = "") -> Dictionary:
	var normalized_path: String = section_path.strip_edges().trim_suffix("/")
	if not _section_records_by_path.has(normalized_path):
		return {}

	var record_value: Variant = _section_records_by_path[normalized_path]
	if not record_value is Dictionary:
		return {}
	var record: Dictionary = record_value
	var effective_locale: String = locale.strip_edges()
	if effective_locale.is_empty():
		effective_locale = TranslationServer.get_tool_locale()

	var label: String = _resolve_localized_text(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(record, "editor_labels"),
		effective_locale
	)
	var description: String = _resolve_localized_text(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(record, "editor_descriptions"),
		effective_locale
	)
	if label.is_empty() or description.is_empty():
		return {}
	return {
		"path": normalized_path,
		"label": label,
		"description": description,
		"tooltip": _make_section_tooltip(description, normalized_path, effective_locale),
	}


## 获取当前目录拥有展示元数据的稳定项目设置分区路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 按字典序排列的分区路径。
func get_section_paths() -> PackedStringArray:
	var section_paths: PackedStringArray = PackedStringArray()
	for section_path_value: Variant in _section_records_by_path:
		if not section_path_value is String:
			continue
		var section_path: String = section_path_value
		var _append_result: bool = section_paths.append(section_path)
	section_paths.sort()
	return section_paths


# --- 私有/辅助方法 ---

func _register_record(record: Dictionary) -> void:
	var setting_name: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "name").strip_edges()
	if setting_name.is_empty() or _records_by_name.has(setting_name):
		return
	if not _has_complete_presentation(record):
		return
	_records_by_name[setting_name] = record.duplicate(true)


func _register_section_record(record: Dictionary) -> void:
	var section_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		record,
		"path"
	).strip_edges().trim_suffix("/")
	if section_path.is_empty() or _section_records_by_path.has(section_path):
		return
	if not _has_complete_presentation(record):
		return
	_section_records_by_path[section_path] = record.duplicate(true)


func _has_complete_presentation(record: Dictionary) -> bool:
	var labels: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(record, "editor_labels")
	var descriptions: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(record, "editor_descriptions")
	return not labels.is_empty() and not descriptions.is_empty()


func _resolve_localized_text(localized_text: Dictionary, locale: String) -> String:
	var locale_candidates: PackedStringArray = _get_locale_candidates(locale)
	for candidate: String in locale_candidates:
		var exact_text: String = _find_localized_text(localized_text, candidate, false)
		if not exact_text.is_empty():
			return exact_text
		if candidate.contains("_"):
			continue
		var language_text: String = _find_localized_text(localized_text, candidate, true)
		if not language_text.is_empty():
			return language_text
	return ""


func _find_localized_text(
	localized_text: Dictionary,
	locale: String,
	allow_language_variant: bool
) -> String:
	var locale_keys: PackedStringArray = PackedStringArray()
	for locale_value: Variant in localized_text:
		if not locale_value is String:
			continue
		var locale_key: String = locale_value
		var _append_result: bool = locale_keys.append(locale_key)
	locale_keys.sort()
	for locale_key: String in locale_keys:
		var normalized_key: String = _normalize_locale(locale_key)
		var matches: bool = normalized_key == locale
		if allow_language_variant:
			matches = normalized_key.begins_with(locale + "_")
		if not matches:
			continue
		return _GF_VARIANT_ACCESS_SCRIPT.to_text(localized_text[locale_key]).strip_edges()
	return ""


func _resolve_localized_enum_text(localized_values: Dictionary, locale: String) -> Dictionary:
	var resolved: Dictionary = {}
	for value_key: Variant in localized_values:
		if not value_key is String:
			continue
		var localized_value: Variant = localized_values[value_key]
		if not localized_value is Dictionary:
			continue
		var localized_text: Dictionary = localized_value
		var text: String = _resolve_localized_text(localized_text, locale)
		if not text.is_empty():
			resolved[value_key] = text
	return resolved


func _get_locale_candidates(locale: String) -> PackedStringArray:
	var candidates: PackedStringArray = PackedStringArray()
	var normalized_locale: String = _normalize_locale(locale)
	_append_unique_text(candidates, normalized_locale)
	var separator_index: int = normalized_locale.find("_")
	if separator_index > 0:
		_append_unique_text(candidates, normalized_locale.left(separator_index))
	_append_unique_text(candidates, "en")
	return candidates


func _normalize_locale(locale: String) -> String:
	return locale.strip_edges().replace("-", "_").to_lower()


func _append_unique_text(values: PackedStringArray, value: String) -> void:
	if value.is_empty() or values.has(value):
		return
	var _append_result: bool = values.append(value)


func _make_tooltip(description: String, setting_name: String, locale: String) -> String:
	if _normalize_locale(locale).begins_with("zh"):
		return "%s\n\n项目设置：%s" % [description, setting_name]
	return "%s\n\nProject setting: %s" % [description, setting_name]


func _make_section_tooltip(description: String, section_path: String, locale: String) -> String:
	if _normalize_locale(locale).begins_with("zh"):
		return "%s\n\n项目设置分区：%s" % [description, section_path]
	return "%s\n\nProject settings section: %s" % [description, section_path]


func _get_builtin_section_records() -> Array[Dictionary]:
	return [
		{
			"path": "gf",
			"editor_labels": {
				"en": "GF",
				"zh_CN": "GF",
			},
			"editor_descriptions": {
				"en": "Configuration owned by GF Framework and its installed packages.",
				"zh_CN": "GF Framework 及其已安装包提供的项目配置。",
			},
		},
		{
			"path": "gf/project",
			"editor_labels": {
				"en": "Project",
				"zh_CN": "项目",
			},
			"editor_descriptions": {
				"en": "GF project initialization and Installer behavior.",
				"zh_CN": "GF 项目初始化与 Installer 执行行为。",
			},
		},
		{
			"path": "gf/codegen",
			"editor_labels": {
				"en": "Code Generation",
				"zh_CN": "代码生成",
			},
			"editor_descriptions": {
				"en": "Output locations used by GF code generators.",
				"zh_CN": "GF 代码生成器使用的输出位置。",
			},
		},
		{
			"path": "gf/extensions",
			"editor_labels": {
				"en": "Extensions",
				"zh_CN": "扩展",
			},
			"editor_descriptions": {
				"en": "Discovery, selection, installation, and export behavior for GF extensions.",
				"zh_CN": "GF 扩展的发现、选择、安装与导出行为。",
			},
		},
	]


func _get_builtin_records() -> Array[Dictionary]:
	return [
		{
			"name": _GF_PLUGIN_PROJECT_SETTINGS_SCRIPT.INSTALLERS_SETTING,
			"editor_labels": {
				"en": "Startup Installers",
				"zh_CN": "启动安装器",
			},
			"editor_descriptions": {
				"en": "Installer script paths executed in order while the GF runtime initializes.",
				"zh_CN": "GF 运行时初始化期间按顺序执行的 Installer 脚本路径列表。",
			},
		},
		{
			"name": _GF_PLUGIN_PROJECT_SETTINGS_SCRIPT.FAIL_ON_INSTALLER_ERROR_SETTING,
			"editor_labels": {
				"en": "Abort on Installer Error",
				"zh_CN": "安装器失败时中止初始化",
			},
			"editor_descriptions": {
				"en": "Stops GF initialization and rolls back the active initialization scope when an Installer fails.",
				"zh_CN": "任一 Installer 失败时中止 GF 初始化，并回滚当前初始化作用域。",
			},
		},
		{
			"name": _GF_PLUGIN_PROJECT_SETTINGS_SCRIPT.INSTALLER_TIMEOUT_SETTING,
			"editor_labels": {
				"en": "Installer Timeout (Seconds)",
				"zh_CN": "安装器超时（秒）",
			},
			"editor_descriptions": {
				"en": "Maximum duration for one initialization Installer. Set to 0 to disable the timeout.",
				"zh_CN": "单个初始化 Installer 的最长执行时间；设为 0 表示不启用超时。",
			},
		},
		{
			"name": _GF_PLUGIN_PROJECT_SETTINGS_SCRIPT.ACCESS_OUTPUT_SETTING,
			"editor_labels": {
				"en": "Framework Accessor Output Path",
				"zh_CN": "框架访问器输出路径",
			},
			"editor_descriptions": {
				"en": "Output script path used when generating accessors for GF framework types.",
				"zh_CN": "生成 GF 框架类型访问器时写入的脚本路径。",
			},
		},
		{
			"name": _GF_PLUGIN_PROJECT_SETTINGS_SCRIPT.PROJECT_ACCESS_OUTPUT_SETTING,
			"editor_labels": {
				"en": "Project Accessor Output Path",
				"zh_CN": "项目访问器输出路径",
			},
			"editor_descriptions": {
				"en": "Output script path used when generating accessors for project-owned architecture types.",
				"zh_CN": "生成项目侧架构类型访问器时写入的脚本路径。",
			},
		},
		{
			"name": _GF_EXTENSION_SETTINGS_SCRIPT.ENABLED_EXTENSIONS_SETTING,
			"editor_labels": {
				"en": "Explicitly Enabled Extensions",
				"zh_CN": "显式启用的扩展",
			},
			"editor_descriptions": {
				"en": "Extension IDs used only in Explicit Selection mode. GF resolves required dependencies when saving a selection.",
				"zh_CN": "仅在“扩展选择模式”为“显式选择”时使用的扩展 ID 列表；GF 保存选择时会补齐必需依赖。",
			},
		},
		{
			"name": _GF_EXTENSION_SETTINGS_SCRIPT.EXTENSION_SELECTION_MODE_SETTING,
			"editor_labels": {
				"en": "Extension Selection Mode",
				"zh_CN": "扩展选择模式",
			},
			"editor_descriptions": {
				"en": "Chooses whether enabled extensions follow each manifest default or the explicit extension ID list.",
				"zh_CN": "决定启用扩展是跟随各扩展清单的默认声明，还是读取显式扩展 ID 列表。",
			},
			"editor_enum_labels": {
				"default": {
					"en": "Follow Manifest Defaults",
					"zh_CN": "跟随清单默认值",
				},
				"explicit": {
					"en": "Explicit Selection",
					"zh_CN": "显式选择",
				},
			},
			"editor_enum_descriptions": {
				"default": {
					"en": "Derive the selection from enabled_by_default in every discovered extension manifest.",
					"zh_CN": "根据每个已发现扩展清单中的 enabled_by_default 自动派生启用列表。",
				},
				"explicit": {
					"en": "Use the IDs stored in Explicitly Enabled Extensions.",
					"zh_CN": "使用“显式启用的扩展”中保存的扩展 ID。",
				},
			},
		},
		{
			"name": _GF_EXTENSION_SETTINGS_SCRIPT.EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING,
			"editor_labels": {
				"en": "Fail Export on Disabled References",
				"zh_CN": "引用禁用扩展时导出失败",
			},
			"editor_descriptions": {
				"en": "Fails export when project files still reference an extension that is currently disabled.",
				"zh_CN": "项目文件仍引用当前禁用的扩展时，让导出审计以错误结束。",
			},
		},
		{
			"name": _GF_EXTENSION_SETTINGS_SCRIPT.AUTO_INSTALL_ENABLED_INSTALLERS_SETTING,
			"editor_labels": {
				"en": "Run Enabled Extension Installers",
				"zh_CN": "运行启用扩展的安装器",
			},
			"editor_descriptions": {
				"en": "Runs installer_paths declared by enabled extension manifests during GF initialization.",
				"zh_CN": "GF 初始化期间自动运行已启用扩展清单中声明的 installer_paths。",
			},
		},
		{
			"name": _GF_EXTENSION_SETTINGS_SCRIPT.EXTERNAL_EXTENSION_ROOTS_SETTING,
			"editor_labels": {
				"en": "External Extension Roots",
				"zh_CN": "外部扩展根目录",
			},
			"editor_descriptions": {
				"en": "Additional directories scanned for extension folders. Each direct child is treated as one extension candidate.",
				"zh_CN": "额外扫描的扩展集合目录；每个目录的直接子目录会被视为一个扩展候选。",
			},
		},
		{
			"name": _GF_EXTENSION_SETTINGS_SCRIPT.EXTENSION_PRESET_PATHS_SETTING,
			"editor_labels": {
				"en": "Extension Preset Paths",
				"zh_CN": "扩展组合文件路径",
			},
			"editor_descriptions": {
				"en": "Project-owned extension preset JSON files available to the GF extension manager.",
				"zh_CN": "提供给 GF 扩展管理器使用的项目侧扩展组合 JSON 文件路径。",
			},
		},
		{
			"name": _GF_EXTENSION_SETTINGS_SCRIPT.EXPORT_EXCLUDE_DISABLED_SETTING,
			"editor_labels": {
				"en": "Exclude Disabled Extensions from Export",
				"zh_CN": "导出时排除禁用扩展",
			},
			"editor_descriptions": {
				"en": "Skips files under disabled extension roots while building an export package.",
				"zh_CN": "构建导出包时跳过禁用扩展根目录下的文件。",
			},
		},
	]
