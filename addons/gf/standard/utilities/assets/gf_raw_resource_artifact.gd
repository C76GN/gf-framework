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
const _REASON_INVALID_FILE_NAME: String = "invalid_file_name"
const _REASON_EMPTY_DATA: String = "empty_data"
const _REASON_WRITE_FAILED: String = "write_failed"
const _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT = preload(
	"res://addons/gf/kernel/editor/gf_artifact_write_transaction.gd"
)


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
## @schema options: Dictionary，可包含 allow_user_path、allow_res_path、overwrite、create_directories、max_file_bytes、max_total_bytes、max_backup_bytes 和 scan_filesystem。
## [br]
## @schema return: Dictionary with ok, path, reason, size_bytes, metadata, recovery_required, recovery_action, and recovery_transaction. recovery_required 为 true 时，调用方必须按 recovery_action 将 recovery_transaction 原样交给 GFArtifactWriteTransaction.rollback() 或 complete()。
func materialize_to_path(target_path: String, options: Dictionary = {}) -> Dictionary:
	var normalized_path: String = GFPathTools.normalize_resource_path(target_path)
	if normalized_path.is_empty():
		return _make_report(false, normalized_path, _REASON_EMPTY_TARGET_PATH)
	if not has_data():
		return _make_report(false, normalized_path, _REASON_EMPTY_DATA)
	if not _path_is_allowed(normalized_path, options):
		return _make_report(false, normalized_path, _REASON_PATH_NOT_ALLOWED)
	var create_directories: bool = GFVariantData.get_option_bool(
		options,
		"create_directories",
		true
	)
	if (
		not create_directories
		and not DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(normalized_path.get_base_dir())
		)
	):
		return _make_report(false, normalized_path, _REASON_WRITE_FAILED)

	var entry: Dictionary = _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.make_bytes_entry(
		normalized_path,
		data,
		{
			"overwrite": GFVariantData.get_option_bool(options, "overwrite", true),
			"metadata": {
				"source_path": source_path,
				"type_hint": type_hint,
			},
		}
	)
	var transaction_options: Dictionary = {
		"allowed_roots": PackedStringArray([
			normalized_path.get_base_dir(),
		]),
		"max_file_count": 1,
		"max_file_bytes": GFVariantData.get_option_int(
			options,
			"max_file_bytes",
			_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.DEFAULT_MAX_FILE_BYTES
		),
		"max_total_bytes": GFVariantData.get_option_int(
			options,
			"max_total_bytes",
			_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.DEFAULT_MAX_TOTAL_BYTES
		),
		"max_backup_bytes": GFVariantData.get_option_int(
			options,
			"max_backup_bytes",
			_GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.DEFAULT_MAX_BACKUP_BYTES
		),
		"scan_filesystem": GFVariantData.get_option_bool(
			options,
			"scan_filesystem",
			true
		),
	}
	var transaction_entries: Array[Dictionary] = [entry]
	var transaction_report: Dictionary = _commit_materialization(
		transaction_entries,
		transaction_options
	)
	if not GFVariantData.get_option_bool(transaction_report, "ok"):
		var recovery_required: bool = GFVariantData.get_option_bool(
			transaction_report,
			"recovery_required"
		)
		var recovery_action: StringName = &""
		var recovery_transaction: Dictionary = {}
		if recovery_required:
			recovery_action = GFVariantData.get_option_string_name(
				transaction_report,
				"recovery_action"
			)
			recovery_transaction = GFVariantData.get_option_dictionary(
				transaction_report,
				"recovery_transaction"
			)
		return _make_report(
			false,
			normalized_path,
			_REASON_WRITE_FAILED,
			recovery_required,
			recovery_action,
			recovery_transaction
		)
	return _make_report(true, normalized_path, "")


## 物化到临时 artifact 目录。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param options: 写入选项，可包含 directory_path、file_name、extension、overwrite；file_name 必须是非空 portable leaf，不能是 .、.. 或包含路径分隔符。
## [br]
## @return 写入报告。
## [br]
## @schema options: Dictionary，可包含 directory_path、file_name、extension、overwrite、allow_user_path、allow_res_path、max_file_bytes、max_total_bytes、max_backup_bytes 和 scan_filesystem；file_name 必须是 ASCII portable leaf，禁止 .、..、控制字符、路径分隔符、Windows 保留字符和设备名。
## [br]
## @schema return: Dictionary with ok, path, reason, size_bytes, metadata, recovery_required, recovery_action, and recovery_transaction.
func materialize_temp(options: Dictionary = {}) -> Dictionary:
	var directory_path: String = GFVariantData.get_option_string(options, "directory_path", DEFAULT_MATERIALIZE_DIR)
	var file_name: String = GFVariantData.get_option_string(options, "file_name", _make_default_file_name(options))
	if not _is_portable_file_name(file_name):
		return _make_report(false, "", _REASON_INVALID_FILE_NAME)
	var target_path: String = (
		directory_path.strip_edges().replace("\\", "/").path_join(file_name)
	)
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


func _commit_materialization(
	entries: Array[Dictionary],
	options: Dictionary
) -> Dictionary:
	return _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.commit(entries, options)


func _make_report(
	ok: bool,
	path: String,
	reason: String,
	recovery_required: bool = false,
	recovery_action: StringName = &"",
	recovery_transaction: Dictionary = {}
) -> Dictionary:
	return {
		"ok": ok,
		"path": path,
		"reason": reason,
		"size_bytes": get_size_bytes(),
		"recovery_required": recovery_required,
		"recovery_action": recovery_action if recovery_required else &"",
		"recovery_transaction": recovery_transaction.duplicate(true),
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


func _is_portable_file_name(file_name: String) -> bool:
	if (
		file_name.is_empty()
		or file_name != file_name.strip_edges()
		or file_name == "."
		or file_name == ".."
		or file_name != file_name.rstrip(" .")
		or not _string_is_ascii(file_name)
		or _string_has_control_character(file_name)
	):
		return false
	for invalid_character: String in [
		"<",
		">",
		":",
		"\"",
		"/",
		"\\",
		"|",
		"?",
		"*",
	]:
		if file_name.contains(invalid_character):
			return false
	var device_stem: String = file_name.split(".", true)[0].to_upper()
	if ["CON", "PRN", "AUX", "NUL"].has(device_stem):
		return false
	if device_stem.length() == 4:
		var device_prefix: String = device_stem.substr(0, 3)
		var device_number: String = device_stem.substr(3, 1)
		if (
			(device_prefix == "COM" or device_prefix == "LPT")
			and "123456789".contains(device_number)
		):
			return false
	return true


func _string_is_ascii(value: String) -> bool:
	for index: int in range(value.length()):
		if value.unicode_at(index) > 0x7f:
			return false
	return true


func _string_has_control_character(value: String) -> bool:
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		if codepoint < 32 or codepoint == 127:
			return true
	return false
