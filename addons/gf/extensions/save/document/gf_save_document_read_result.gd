## GFSaveDocumentReadResult: 存档文档读取终态结果。
##
## 结果保留物理存储读取、文档解析、schema 校验和迁移状态，避免调用方
## 把读取失败、格式损坏、未来版本或迁移缺口都误判为空 Dictionary。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 9.0.0
class_name GFSaveDocumentReadResult
extends RefCounted


# --- 常量 ---

## 文档无需迁移并已加载。
## [br]
## @api public
## [br]
## @since 9.0.0
const STATUS_LOADED: StringName = &"loaded"

## 文档迁移后已加载。
## [br]
## @api public
## [br]
## @since 9.0.0
const STATUS_MIGRATED: StringName = &"migrated"

## 文档读取失败。
## [br]
## @api public
## [br]
## @since 9.0.0
const STATUS_FAILED: StringName = &"failed"


# --- 私有变量 ---

var _status: StringName = STATUS_FAILED
var _document: GFSaveDocument = null
var _storage_result: GFStorageReadResult = null
var _migration_result: GFSaveMigrationResult = null
var _validation_report: Dictionary = {}
var _error_code: Error = FAILED
var _error: String = ""


# --- 公共方法 ---

## 检查读取、解析、迁移和最终校验是否全部成功。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 成功时返回 true。
func is_successful() -> bool:
	return _status in [STATUS_LOADED, STATUS_MIGRATED]


## 检查是否执行过迁移。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return migrated 状态返回 true。
func was_migrated() -> bool:
	return _status == STATUS_MIGRATED


## 获取终态状态。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return loaded、migrated 或 failed。
func get_status() -> StringName:
	return _status


## 获取有效文档副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 成功文档；失败时返回 null。
func get_document() -> GFSaveDocument:
	return _document.duplicate_document() if _document != null else null


## 获取底层存储读取结果副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 底层结果；尚未进入存储读取时可为 null。
func get_storage_result() -> GFStorageReadResult:
	return _storage_result.duplicate_result() if _storage_result != null else null


## 获取迁移结果副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 运行过迁移注册表时的结果，否则为 null。
func get_migration_result() -> GFSaveMigrationResult:
	return _migration_result.duplicate_result() if _migration_result != null else null


## 获取最终校验报告副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 文档或目标 schema 校验报告。
## [br]
## @schema return: GFValidationReportDictionary-compatible report.
func get_validation_report() -> Dictionary:
	return _validation_report.duplicate(true)


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


## 转换为诊断字典。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 读取结果摘要。
## [br]
## @schema return: Dictionary with ok, status, error_code, error, migrated, document, storage_result, migration_result, and validation_report.
func to_dict() -> Dictionary:
	return {
		"ok": is_successful(),
		"status": _status,
		"error_code": _error_code,
		"error": _error,
		"migrated": was_migrated(),
		"document": _document.to_dict() if _document != null else {},
		"storage_result": _storage_result.to_dict() if _storage_result != null else {},
		"migration_result": _migration_result.to_dict() if _migration_result != null else {},
		"validation_report": _validation_report.duplicate(true),
	}


## 创建结果副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 隔离结果。
func duplicate_result() -> GFSaveDocumentReadResult:
	var result: GFSaveDocumentReadResult = GFSaveDocumentReadResult.new()
	result._gf_configure(
		_status,
		_document,
		_storage_result,
		_migration_result,
		_validation_report,
		_error_code,
		_error
	)
	return result


# --- 私有/辅助方法 ---

# 由 Save document/slot 层配置终态数据。
func _gf_configure(
	status: StringName,
	document: GFSaveDocument,
	storage_result: GFStorageReadResult,
	migration_result: GFSaveMigrationResult,
	validation_report: Dictionary,
	error_code: Error,
	error: String
) -> void:
	_status = status if status in [STATUS_LOADED, STATUS_MIGRATED] else STATUS_FAILED
	_document = document.duplicate_document() if _status != STATUS_FAILED and document != null else null
	_storage_result = storage_result.duplicate_result() if storage_result != null else null
	_migration_result = migration_result.duplicate_result() if migration_result != null else null
	_validation_report = validation_report.duplicate(true)
	_error_code = OK if _status != STATUS_FAILED else error_code
	_error = "" if _status != STATUS_FAILED else error.strip_edges()
