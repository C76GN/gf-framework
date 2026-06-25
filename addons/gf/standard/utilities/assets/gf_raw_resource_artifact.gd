## GFRawResourceArtifact: 原始文件数据资源。
##
## 保存一个外部或导入前源文件的相对路径、字节数据和元数据，并可显式物化到 user:// 或授权路径。
## 它不绑定任何第三方格式或运行库，只提供通用的原始资源载荷封装。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 6.0.0
class_name GFRawResourceArtifact
extends Resource


# --- 常量 ---

## 默认物化目录。
## [br]
## @api public
## [br]
## @since 6.0.0
const DEFAULT_MATERIALIZE_DIR: String = "user://gf/artifacts"


const _REASON_EMPTY_TARGET_PATH: String = "empty_target_path"
const _REASON_PATH_NOT_ALLOWED: String = "path_not_allowed"
const _REASON_EMPTY_DATA: String = "empty_data"
const _REASON_WRITE_FAILED: String = "write_failed"


# --- 导出变量 ---

## 原始源路径。可以是项目相对路径、res:// 路径或调用方自定义路径文本。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var source_path: String = ""

## 原始文件字节数据。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var data: PackedByteArray = PackedByteArray()

## 可选类型提示或格式名。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var type_hint: String = ""

## 调用方自定义元数据。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema metadata: Dictionary project-defined artifact metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置原始文件资源。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param p_source_path: 原始源路径。
## [br]
## @param p_data: 原始文件字节数据。
## [br]
## @param p_type_hint: 可选类型提示或格式名。
## [br]
## @param p_metadata: 调用方自定义元数据。
## [br]
## @return 当前资源。
## [br]
## @schema p_metadata: Dictionary project-defined artifact metadata.
func configure(
	p_source_path: String,
	p_data: PackedByteArray,
	p_type_hint: String = "",
	p_metadata: Dictionary = {}
) -> GFRawResourceArtifact:
	source_path = p_source_path.strip_edges().replace("\\", "/")
	data = p_data.duplicate()
	type_hint = p_type_hint.strip_edges()
	metadata = p_metadata.duplicate(true)
	return self


## 检查是否包含字节数据。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 包含数据时返回 true。
func has_data() -> bool:
	return data.size() > 0


## 获取数据字节数。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 数据字节数。
func get_size_bytes() -> int:
	return data.size()


## 物化到指定路径。
## [br]
## 默认只允许写入 user://，需要写入 res:// 时必须显式传入 allow_res_path。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param target_path: 输出文件路径。
## [br]
## @param options: 写入选项。
## [br]
## @return 写入报告。
## [br]
## @schema options: Dictionary，可包含 allow_user_path、allow_res_path、overwrite 和 create_directories。
## [br]
## @schema return: Dictionary with ok, path, reason, size_bytes, and metadata.
func materialize_to_path(target_path: String, options: Dictionary = {}) -> Dictionary:
	var normalized_path: String = target_path.strip_edges().replace("\\", "/")
	if normalized_path.is_empty():
		return _make_report(false, normalized_path, _REASON_EMPTY_TARGET_PATH)
	if not has_data():
		return _make_report(false, normalized_path, _REASON_EMPTY_DATA)
	if not _path_is_allowed(normalized_path, options):
		return _make_report(false, normalized_path, _REASON_PATH_NOT_ALLOWED)
	if FileAccess.file_exists(normalized_path) and not GFVariantData.get_option_bool(options, "overwrite", true):
		return _make_report(false, normalized_path, _REASON_WRITE_FAILED)

	if GFVariantData.get_option_bool(options, "create_directories", true):
		var directory_path: String = normalized_path.get_base_dir()
		var absolute_dir: String = ProjectSettings.globalize_path(directory_path)
		var _mkdir_result: Error = DirAccess.make_dir_recursive_absolute(absolute_dir)

	var file: FileAccess = FileAccess.open(normalized_path, FileAccess.WRITE)
	if file == null:
		return _make_report(false, normalized_path, _REASON_WRITE_FAILED)
	var _stored: Variant = file.store_buffer(data)
	file.close()
	return _make_report(true, normalized_path, "")


## 物化到临时 artifact 目录。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param options: 写入选项，可包含 directory_path、file_name、extension、overwrite。
## [br]
## @return 写入报告。
## [br]
## @schema options: Dictionary，可包含 directory_path、file_name、extension、overwrite、allow_user_path、allow_res_path。
## [br]
## @schema return: Dictionary with ok, path, reason, size_bytes, and metadata.
func materialize_temp(options: Dictionary = {}) -> Dictionary:
	var directory_path: String = GFVariantData.get_option_string(options, "directory_path", DEFAULT_MATERIALIZE_DIR)
	var file_name: String = GFVariantData.get_option_string(options, "file_name", _make_default_file_name(options))
	var target_path: String = directory_path.strip_edges().replace("\\", "/").path_join(_sanitize_file_name(file_name))
	var materialize_options: Dictionary = options.duplicate(true)
	materialize_options["allow_user_path"] = GFVariantData.get_option_bool(options, "allow_user_path", true)
	materialize_options["allow_res_path"] = GFVariantData.get_option_bool(options, "allow_res_path", false)
	return materialize_to_path(target_path, materialize_options)


## 转换为轻量字典，不包含完整 data。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 摘要字典。
## [br]
## @schema return: Dictionary with source_path, type_hint, size_bytes, and metadata.
func to_summary_dictionary() -> Dictionary:
	return {
		"source_path": source_path,
		"type_hint": type_hint,
		"size_bytes": get_size_bytes(),
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _path_is_allowed(path: String, options: Dictionary) -> bool:
	if path.begins_with("user://"):
		return GFVariantData.get_option_bool(options, "allow_user_path", true)
	if path.begins_with("res://"):
		return GFVariantData.get_option_bool(options, "allow_res_path", false)
	return false


func _make_report(ok: bool, path: String, reason: String) -> Dictionary:
	return {
		"ok": ok,
		"path": path,
		"reason": reason,
		"size_bytes": get_size_bytes(),
		"metadata": {
			"source_path": source_path,
			"type_hint": type_hint,
		},
	}


func _make_default_file_name(options: Dictionary) -> String:
	var base_name: String = source_path.get_file()
	if base_name.is_empty():
		base_name = "artifact"
	var extension: String = GFVariantData.get_option_string(options, "extension")
	if not extension.is_empty():
		if extension.begins_with("."):
			extension = extension.substr(1)
		base_name = base_name.get_basename() + "." + extension
	var hash_text: String = str(var_to_str(data).hash()).replace("-", "n")
	var basename: String = base_name.get_basename()
	var file_extension: String = base_name.get_extension()
	if file_extension.is_empty():
		return "%s_%s" % [basename, hash_text]
	return "%s_%s.%s" % [basename, hash_text, file_extension]


func _sanitize_file_name(file_name: String) -> String:
	var result: String = file_name.strip_edges().replace("\\", "_").replace("/", "_").replace(":", "_")
	if result.is_empty():
		return "artifact_%s.bin" % str(var_to_str(data).hash()).replace("-", "n")
	return result
