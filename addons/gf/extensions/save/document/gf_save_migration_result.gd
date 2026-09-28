## GFSaveMigrationResult: 存档迁移终态结果。
##
## 结果持有隔离文档、迁移轨迹和失败位置。失败时不暴露部分迁移文档，
## 确保调用方只能提交完整成功的迁移结果。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 9.0.0
class_name GFSaveMigrationResult
extends RefCounted


# --- 私有变量 ---

## 迁移是否完整成功。
## [br]
## @api private
## [br]
var _ok: bool = false

## 成功时可读取的目标文档。
## [br]
## @api private
## [br]
var _document: GFSaveDocument = null

## 迁移结果的 Godot Error 码。
## [br]
## @api private
## [br]
var _error_code: Error = FAILED

## 迁移失败时的说明。
## [br]
## @api private
## [br]
var _error: String = ""

## 失败迁移步骤的 ID。
## [br]
## @api private
## [br]
var _failed_step_id: StringName = &""

## 源文档 schema 版本。
## [br]
## @api private
## [br]
var _source_document_version: int = 0

## 目标文档 schema 版本。
## [br]
## @api private
## [br]
var _target_document_version: int = 0

## 源文档各分区的版本映射。
## [br]
## @api private
## [br]
var _source_section_versions: Dictionary = {}

## 目标文档各分区的版本映射。
## [br]
## @api private
## [br]
var _target_section_versions: Dictionary = {}

## 按执行顺序记录的迁移步骤轨迹。
## [br]
## @api private
## [br]
var _trace: Array[Dictionary] = []


# --- 公共方法 ---

## 检查迁移是否完整成功。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 成功时返回 true。
func is_successful() -> bool:
	return _ok


## 获取成功文档副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 完整迁移后的文档；失败时返回 null。
func get_document() -> GFSaveDocument:
	return _document.duplicate_document() if _document != null else null


## 获取错误码。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return Godot Error 码。
func get_error_code() -> Error:
	return _error_code


## 获取错误说明。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 失败说明。
func get_error() -> String:
	return _error


## 获取失败步骤 ID。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 失败步骤 ID；非步骤失败时为空。
func get_failed_step_id() -> StringName:
	return _failed_step_id


## 检查是否实际执行过迁移步骤。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 轨迹非空时返回 true。
func was_migrated() -> bool:
	return not _trace.is_empty()


## 获取迁移轨迹副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 按执行顺序排列的步骤轨迹。
## [br]
## @schema return: Array[Dictionary] with step_id, schema_id, section_id, scope, from_version, and to_version.
func get_trace() -> Array[Dictionary]:
	return _trace.duplicate(true)


## 转换为诊断字典。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return JSON-safe 迁移结果摘要。
## [br]
## @schema return: Dictionary with ok, error_code, error, failed_step_id, source_document_version, target_document_version, source_section_versions, target_section_versions, migrated, trace, and document.
func to_dict() -> Dictionary:
	return {
		"ok": _ok,
		"error_code": _error_code,
		"error": _error,
		"failed_step_id": _failed_step_id,
		"source_document_version": _source_document_version,
		"target_document_version": _target_document_version,
		"source_section_versions": _source_section_versions.duplicate(true),
		"target_section_versions": _target_section_versions.duplicate(true),
		"migrated": was_migrated(),
		"trace": _trace.duplicate(true),
		"document": _document.to_dict() if _document != null else {},
	}


## 创建结果副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 隔离结果。
func duplicate_result() -> GFSaveMigrationResult:
	var result: GFSaveMigrationResult = GFSaveMigrationResult.new()
	result._gf_configure(
		_ok,
		_document,
		_error_code,
		_error,
		_failed_step_id,
		_source_document_version,
		_target_document_version,
		_source_section_versions,
		_target_section_versions,
		_trace
	)
	return result


# --- 框架内部方法 ---

# 由 Save document 层配置终态结果。
## 由迁移注册表填充终态结果；成功时复制文档并清除失败字段，失败时不保存部分迁移文档。源目标版本、分区版本和轨迹均保留，字典与轨迹数组深复制。
## [br]
## @api framework_internal
## [br]
## @layer extensions/save
## [br]
## @param ok: 迁移是否成功。
## [br]
## @param document: 成功时复制保存的目标文档，可为 null。
## [br]
## @param error_code: 失败时保存的错误码。
## [br]
## @param error: 失败时去除两端空白后保存的错误说明。
## [br]
## @param failed_step_id: 失败步骤标识；成功时清空。
## [br]
## @param source_document_version: 迁移前文档版本。
## [br]
## @param target_document_version: 期望到达的文档版本。
## [br]
## @param source_section_versions: 迁移前分区版本映射。
## [br]
## @param target_section_versions: 目标分区版本映射。
## [br]
## @param trace: 已经执行的迁移轨迹。
## [br]
## @schema source_section_versions: 以分区标识为键、整数版本为值的字典。
## [br]
## @schema target_section_versions: 以分区标识为键、整数版本为值的字典。
## [br]
## @schema trace: 迁移注册表生成的步骤记录数组；保留每项原有字段，失败时可包含已执行步骤。
func _gf_configure(
	ok: bool,
	document: GFSaveDocument,
	error_code: Error,
	error: String,
	failed_step_id: StringName,
	source_document_version: int,
	target_document_version: int,
	source_section_versions: Dictionary,
	target_section_versions: Dictionary,
	trace: Array[Dictionary]
) -> void:
	_ok = ok
	_document = document.duplicate_document() if ok and document != null else null
	_error_code = OK if ok else error_code
	_error = "" if ok else error.strip_edges()
	_failed_step_id = &"" if ok else failed_step_id
	_source_document_version = source_document_version
	_target_document_version = target_document_version
	_source_section_versions = source_section_versions.duplicate(true)
	_target_section_versions = target_section_versions.duplicate(true)
	_trace = trace.duplicate(true)
