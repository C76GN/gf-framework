## GFSaveRollbackFailure: 单个 section 回滚失败证据。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFSaveRollbackFailure
extends RefCounted


# --- 私有变量 ---

var _section_id: StringName = &""
var _error_code: Error = FAILED


# --- 公共方法 ---

## 获取回滚失败的 section ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return section ID。
func get_section_id() -> StringName:
	return _section_id


## 获取回滚 Error 码。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 非 OK Error 码。
func get_error_code() -> Error:
	return _error_code


## 创建隔离副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 新失败证据对象。
func duplicate_failure() -> GFSaveRollbackFailure:
	var copy: GFSaveRollbackFailure = GFSaveRollbackFailure.new()
	var _configured: bool = copy.configure_for_framework(_section_id, _error_code)
	return copy


## 转换为可报告字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return section_id 与 error_code 字段。
## [br]
## @schema return: Dictionary with section_id and error_code fields.
func to_dict() -> Dictionary:
	return {"section_id": _section_id, "error_code": int(_error_code)}


# --- 框架内部方法 ---

## 由 Save Profile 事务协调器写入失败证据。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param section_id: 回滚失败 section ID。
## [br]
## @param error_code: 非 OK Error 码。
## [br]
## @return 输入合法且首次配置时返回 true。
func configure_for_framework(section_id: StringName, error_code: Error) -> bool:
	if _section_id != &"" or section_id == &"" or error_code == OK:
		return false
	_section_id = section_id
	_error_code = error_code
	return true
