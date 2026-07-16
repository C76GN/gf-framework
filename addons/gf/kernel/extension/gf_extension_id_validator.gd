## GFExtensionIdValidator: GF 扩展 ID 语法校验辅助。
##
## 维护扩展 ID 的唯一正则事实来源，并缓存编译结果，避免 manifest、preset 和设置入口重复构造 RegEx。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
class_name GFExtensionIdValidator
extends RefCounted


# --- 常量 ---

const _EXTENSION_ID_PATTERN: String = "^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$"


# --- 私有变量 ---

static var _extension_id_regex: RegEx = null
static var _has_compile_attempt: bool = false
static var _compile_error: Error = OK


# --- 框架内部方法 ---

## 判断文本是否是合法 GF 扩展 ID。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @param extension_id: 要检查的扩展 ID。
## [br]
## @return 满足扩展 ID 语法时返回 true。
static func is_valid_extension_id(extension_id: String) -> bool:
	return get_extension_id_validation_error(extension_id).is_empty()


## 获取扩展 ID 语法错误。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @param extension_id: 要检查的扩展 ID。
## [br]
## @param field_name: 报错中使用的字段名。
## [br]
## @return ID 合法时返回空字符串，否则返回错误说明。
static func get_extension_id_validation_error(extension_id: String, field_name: String = "id") -> String:
	var normalized_id: String = extension_id.strip_edges()
	if normalized_id.is_empty():
		return "%s is required" % field_name

	var regex: RegEx = _get_extension_id_regex()
	if regex == null:
		return "%s validator failed to compile" % field_name
	if regex.search(normalized_id) == null:
		return "%s must use lowercase dotted identifier segments: %s" % [field_name, normalized_id]
	return ""


# --- 私有/辅助方法 ---

static func _get_extension_id_regex() -> RegEx:
	if not _has_compile_attempt:
		_has_compile_attempt = true
		_extension_id_regex = RegEx.new()
		_compile_error = _extension_id_regex.compile(_EXTENSION_ID_PATTERN)
		if _compile_error != OK:
			_extension_id_regex = null
	return _extension_id_regex
