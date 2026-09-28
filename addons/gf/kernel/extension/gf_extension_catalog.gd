## GFExtensionCatalog: GF 扩展 manifest 发现与读取辅助。
##
## 扫描 GF 内置扩展目录和项目声明的额外扩展集合根目录，
## 读取下一层扩展目录中的 `gf_extension.json`，供编辑器工具或项目侧扩展管理界面使用。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
## [br]
## @layer kernel/extension
class_name GFExtensionCatalog
extends RefCounted


# --- 常量 ---

## 扩展 manifest 类型脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
const GFExtensionManifestBase = preload("res://addons/gf/kernel/extension/gf_extension_manifest.gd")

## 规范化扩展根路径与资源路径的辅助脚本。
## [br]
## @api private
const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")

## 读取报告字典字段的 Variant 访问辅助脚本。
## [br]
## @api private
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

## 读取和预算检查扩展 JSON 文件的辅助脚本。
## [br]
## @api private
const _GF_EXTENSION_JSON_FILE_READER_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_json_file_reader.gd")

## GF 内置可选扩展根目录。
## [br]
## @api public
const EXTENSIONS_PATH: String = "res://addons/gf/extensions"


# --- 私有变量 ---

## 最近一次 manifest 扫描收集到的读取或解析错误。
## [br]
## @api private
static var _last_manifest_load_errors: Array[Dictionary] = []


# --- 公共方法 ---

## 读取 GF 内置可选扩展 manifest。
## [br]
## @api public
## [br]
## @since 3.6.0
## [br]
## @param options: 可选 JSON 预算，只能收紧框架硬上限。
## [br]
## @schema options: Dictionary，支持 max_json_file_bytes、max_json_total_bytes 和 max_json_depth。
## [br]
## @return 扩展 manifest 列表。
static func load_extension_manifests(options: Dictionary = {}) -> Array[GFExtensionManifest]:
	_clear_last_manifest_load_errors()
	var budget_state: Dictionary = _GF_EXTENSION_JSON_FILE_READER_SCRIPT.make_budget_state(options)
	return _load_manifests_in(EXTENSIONS_PATH, options, budget_state)


## 读取所有 GF 可选扩展 manifest。
## [br]
## @api public
## [br]
## @since 3.6.0
## [br]
## @param extra_root_paths: 额外扩展集合根目录列表，每个根目录下一层为独立扩展目录。
## [br]
## @param options: 可选 JSON 预算，只能收紧框架硬上限。
## [br]
## @schema options: Dictionary，支持 max_json_file_bytes、max_json_total_bytes 和 max_json_depth。
## [br]
## @return 扩展 manifest 列表。
static func load_all_manifests(
	extra_root_paths: Array[String] = [],
	options: Dictionary = {}
) -> Array[GFExtensionManifest]:
	_clear_last_manifest_load_errors()
	var budget_state: Dictionary = _get_or_make_budget_state(options)
	var manifests: Array[GFExtensionManifest] = _load_manifests_in(
		EXTENSIONS_PATH,
		options,
		budget_state
	)
	for root_path: String in _normalize_root_paths(extra_root_paths):
		manifests.append_array(_load_manifests_in(root_path, options, budget_state))
	return manifests


## 读取指定根目录下一层扩展目录中的 manifest。
## [br]
## @api public
## [br]
## @since 3.6.0
## [br]
## @param root_path: 扩展集合根目录。
## [br]
## @param options: 可选 JSON 预算，只能收紧框架硬上限。
## [br]
## @schema options: Dictionary，支持 max_json_file_bytes、max_json_total_bytes 和 max_json_depth。
## [br]
## @return 扩展 manifest 列表。
static func load_manifests_in(
	root_path: String,
	options: Dictionary = {}
) -> Array[GFExtensionManifest]:
	_clear_last_manifest_load_errors()
	var budget_state: Dictionary = _GF_EXTENSION_JSON_FILE_READER_SCRIPT.make_budget_state(options)
	return _load_manifests_in(
		_GF_PATH_TOOLS.normalize_root_path(root_path),
		options,
		budget_state
	)


## 获取最近一次 manifest 扫描中无法读取或解析的文件诊断。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @return 读取错误列表。
## [br]
## @schema return: Array of Dictionary entries with source_path and errors.
static func get_last_manifest_load_errors() -> Array[Dictionary]:
	return _last_manifest_load_errors.duplicate(true)


## 获取指定根目录下一层扩展目录中的 manifest 路径。
## [br]
## @api public
## [br]
## @param root_path: 扩展集合根目录。
## [br]
## @return manifest 路径列表。
static func get_manifest_paths(root_path: String) -> Array[String]:
	var paths: Array[String] = []
	var normalized_root: String = _GF_PATH_TOOLS.normalize_root_path(root_path)
	if normalized_root.is_empty():
		return paths

	var dir: DirAccess = DirAccess.open(normalized_root)
	if dir == null:
		return paths

	var _list_dir_begin_result_84: Variant = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if dir.current_is_dir() and not entry.begins_with("."):
			var manifest_path: String = normalized_root.path_join(entry).path_join(GFExtensionManifestBase.FILE_NAME)
			if FileAccess.file_exists(manifest_path):
				paths.append(manifest_path)
		entry = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths


# --- 私有/辅助方法 ---

## 清空前一次 manifest 扫描的错误列表。
## [br]
## @api private
static func _clear_last_manifest_load_errors() -> void:
	_last_manifest_load_errors.clear()


## 读取根目录直接子目录中的 manifest，并跳过读取失败的条目。
## [br]
## @api private
static func _load_manifests_in(
	root_path: String,
	options: Dictionary,
	budget_state: Dictionary
) -> Array[GFExtensionManifest]:
	var manifests: Array[GFExtensionManifest] = []
	for manifest_path: String in get_manifest_paths(root_path):
		var manifest: GFExtensionManifest = _read_manifest_with_diagnostics(
			manifest_path,
			options,
			budget_state
		)
		if manifest != null:
			manifests.append(manifest)
	return manifests


## 读取并解析 manifest；失败时记录各项错误并返回 null。
## [br]
## @api private
static func _read_manifest_with_diagnostics(
	path: String,
	options: Dictionary,
	budget_state: Dictionary
) -> GFExtensionManifest:
	var json_report: Dictionary = _GF_EXTENSION_JSON_FILE_READER_SCRIPT.read_object_report(
		path,
		_make_manifest_json_reader_options(options),
		budget_state
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(json_report, "ok", false):
		var errors: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(
			json_report,
			"errors"
		)
		if errors.is_empty():
			errors.append("could not read manifest")
		for error: String in errors:
			_record_manifest_load_error(path, error)
		return null
	var parsed_dictionary: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
		json_report,
		"data"
	)
	return GFExtensionManifestBase.from_dictionary(parsed_dictionary, path.get_base_dir(), path)


## 以规范化资源路径和单条错误消息追加 manifest 读取诊断。
## [br]
## @api private
static func _record_manifest_load_error(path: String, message: String) -> void:
	_last_manifest_load_errors.append({
		"source_path": _GF_PATH_TOOLS.normalize_resource_path(path),
		"errors": [message],
	})


## 若 options 中的 json_budget_state 是 Dictionary 则返回它，否则创建新预算状态。
## [br]
## @api private
static func _get_or_make_budget_state(options: Dictionary) -> Dictionary:
	var raw_budget_state: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		options,
		"json_budget_state"
	)
	if raw_budget_state is Dictionary:
		var budget_state: Dictionary = raw_budget_state
		return budget_state
	return _GF_EXTENSION_JSON_FILE_READER_SCRIPT.make_budget_state(options)


## 深复制读取选项，并以 manifest 专用错误文本覆盖对应读取器选项。
## [br]
## @api private
static func _make_manifest_json_reader_options(options: Dictionary) -> Dictionary:
	var reader_options: Dictionary = options.duplicate(true)
	reader_options.merge({
		"empty_path_error": "manifest path is empty",
		"open_error_prefix": "could not open manifest",
		"read_error_prefix": "could not read manifest",
		"parse_error_prefix": "could not parse manifest JSON",
		"root_type_error": "manifest JSON root must be an object",
	}, true)
	return reader_options


## 规范化根目录列表并移除与 GF 内置扩展根目录相同的项。
## [br]
## @api private
static func _normalize_root_paths(root_paths: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var normalized_paths: PackedStringArray = _GF_PATH_TOOLS.normalize_root_paths(PackedStringArray(root_paths))
	for normalized_path: String in normalized_paths:
		if normalized_path == EXTENSIONS_PATH:
			continue
		result.append(normalized_path)
	return result
