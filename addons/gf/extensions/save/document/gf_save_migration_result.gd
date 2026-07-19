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

var _ok: bool = false
var _document: GFSaveDocument = null
var _error_code: Error = FAILED
var _error: String = ""
var _failed_step_id: StringName = &""
var _source_document_version: int = 0
var _target_document_version: int = 0
var _source_section_versions: Dictionary = {}
var _target_section_versions: Dictionary = {}
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


# --- 私有/辅助方法 ---

# 由 Save document 层配置终态结果。
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
