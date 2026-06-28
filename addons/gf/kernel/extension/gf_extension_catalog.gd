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
const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")

## GF 内置可选扩展根目录。
## [br]
## @api public
const EXTENSIONS_PATH: String = "res://addons/gf/extensions"


# --- 私有变量 ---

static var _last_manifest_load_errors: Array[Dictionary] = []


# --- 公共方法 ---

## 读取 GF 内置可选扩展 manifest。
## [br]
## @api public
## [br]
## @return 扩展 manifest 列表。
static func load_extension_manifests() -> Array[GFExtensionManifest]:
	_clear_last_manifest_load_errors()
	return _load_manifests_in(EXTENSIONS_PATH)


## 读取所有 GF 可选扩展 manifest。
## [br]
## @api public
## [br]
## @param extra_root_paths: 额外扩展集合根目录列表，每个根目录下一层为独立扩展目录。
## [br]
## @return 扩展 manifest 列表。
static func load_all_manifests(extra_root_paths: Array[String] = []) -> Array[GFExtensionManifest]:
	_clear_last_manifest_load_errors()
	var manifests: Array[GFExtensionManifest] = _load_manifests_in(EXTENSIONS_PATH)
	for root_path: String in _normalize_root_paths(extra_root_paths):
		manifests.append_array(_load_manifests_in(root_path))
	return manifests


## 读取指定根目录下一层扩展目录中的 manifest。
## [br]
## @api public
## [br]
## @param root_path: 扩展集合根目录。
## [br]
## @return 扩展 manifest 列表。
static func load_manifests_in(root_path: String) -> Array[GFExtensionManifest]:
	_clear_last_manifest_load_errors()
	return _load_manifests_in(root_path)


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
	if root_path.is_empty():
		return paths

	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return paths

	var _list_dir_begin_result_84: Variant = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if dir.current_is_dir() and not entry.begins_with("."):
			var manifest_path: String = root_path.path_join(entry).path_join(GFExtensionManifestBase.FILE_NAME)
			if FileAccess.file_exists(manifest_path):
				paths.append(manifest_path)
		entry = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths


# --- 私有/辅助方法 ---

static func _clear_last_manifest_load_errors() -> void:
	_last_manifest_load_errors.clear()


static func _load_manifests_in(root_path: String) -> Array[GFExtensionManifest]:
	var manifests: Array[GFExtensionManifest] = []
	for manifest_path: String in get_manifest_paths(root_path):
		var manifest: GFExtensionManifest = _read_manifest_with_diagnostics(manifest_path)
		if manifest != null:
			manifests.append(manifest)
	return manifests


static func _read_manifest_with_diagnostics(path: String) -> GFExtensionManifest:
	if path.is_empty():
		_record_manifest_load_error(path, "manifest path is empty")
		return null

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_record_manifest_load_error(path, "could not open manifest: %s" % error_string(FileAccess.get_open_error()))
		return null

	var text: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(text)
	if parse_error != OK:
		_record_manifest_load_error(
			path,
			"could not parse manifest JSON at line %d: %s" % [
				parser.get_error_line(),
				parser.get_error_message(),
			]
		)
		return null

	var parsed: Variant = parser.data
	if not (parsed is Dictionary):
		_record_manifest_load_error(path, "manifest JSON root must be an object")
		return null

	var parsed_dictionary: Dictionary = parsed
	return GFExtensionManifestBase.from_dictionary(parsed_dictionary, path.get_base_dir(), path)


static func _record_manifest_load_error(path: String, message: String) -> void:
	_last_manifest_load_errors.append({
		"source_path": _GF_PATH_TOOLS.normalize_resource_path(path),
		"errors": [message],
	})


static func _normalize_root_paths(root_paths: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var normalized_paths: PackedStringArray = _GF_PATH_TOOLS.normalize_root_paths(PackedStringArray(root_paths))
	for normalized_path: String in normalized_paths:
		if normalized_path == EXTENSIONS_PATH:
			continue
		result.append(normalized_path)
	return result
