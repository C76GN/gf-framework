## GFWeakMethodInvocation: 不强持有目标对象的方法调用记录。
##
## 记录只保留目标的 WeakRef、创建时实例 ID 与方法名，并在调用时接收参数。
## 它不会保存 Callable，因此目标为 RefCounted 时不会被绑定回调意外延长生命周期。
## `invoked` 只表示方法通过定义与参数数量预检且 Object.callv() 已返回；GDScript
## 无法捕获 callv 期间的类型错误或被调方法内部错误，因此这类错误不会转换为 `failed`。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
## [br]
## @layer kernel/core
class_name GFWeakMethodInvocation
extends RefCounted


# --- 常量 ---

## 方法已被调用并返回。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_INVOKED: StringName = &"invoked"

## 目标对象已释放。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_OWNER_RELEASED: StringName = &"owner_released"

## 目标对象不再提供记录的方法。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_METHOD_MISSING: StringName = &"method_missing"

## 调用记录或参数未通过显式预检。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_FAILED: StringName = &"failed"


# --- 私有变量 ---

var _owner_ref: WeakRef = null
var _initial_owner_instance_id: int = 0
var _method_name: StringName = &""


# --- Godot 生命周期方法 ---

## 创建弱方法调用记录。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param owner: 调用目标；无效目标会构造一个始终返回 failed 的记录。
## [br]
## @param method_name: 调用时解析的方法名；空名称会构造一个始终返回 failed 的记录。
func _init(owner: Object = null, method_name: StringName = &"") -> void:
	_method_name = method_name
	if owner == null or not is_instance_valid(owner):
		return
	_owner_ref = weakref(owner)
	_initial_owner_instance_id = owner.get_instance_id()


# --- 公共方法 ---

## 调用仍存活目标上的记录方法。
## [br]
## 参数只在本次调用期间使用，不会保存到调用记录。返回 `invoked` 只代表定义与参数
## 数量预检通过且 callv 已返回，不代表 callv 期间没有类型错误或被调方法内部错误。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param arguments: 传给 Object.callv() 的调用时参数数组。
## [br]
## @schema arguments: Array of invocation-time arguments; values are never retained by this record.
## [br]
## @return 调用状态、返回值与稳定目标身份。
## [br]
## @schema return: Dictionary with status, invoked, value, error_code, initial_owner_instance_id, and method_name.
func invoke(arguments: Array = []) -> Dictionary:
	if not _has_valid_definition():
		return _make_result(STATUS_FAILED, null, ERR_INVALID_PARAMETER)

	var owner_value: Variant = _owner_ref.get_ref()
	if not (owner_value is Object):
		return _make_result(STATUS_OWNER_RELEASED, null, ERR_DOES_NOT_EXIST)
	var owner: Object = owner_value
	if not is_instance_valid(owner):
		return _make_result(STATUS_OWNER_RELEASED, null, ERR_DOES_NOT_EXIST)
	if owner.get_instance_id() != _initial_owner_instance_id:
		return _make_result(STATUS_OWNER_RELEASED, null, ERR_DOES_NOT_EXIST)
	if not owner.has_method(_method_name):
		return _make_result(STATUS_METHOD_MISSING, null, ERR_DOES_NOT_EXIST)
	var argument_validation_error: Error = _validate_argument_count(owner, arguments.size())
	if argument_validation_error != OK:
		return _make_result(STATUS_FAILED, null, argument_validation_error)

	var value: Variant = owner.callv(_method_name, arguments)
	return _make_result(STATUS_INVOKED, value, OK)


# --- 私有/辅助方法 ---

func _has_valid_definition() -> bool:
	return (
		_owner_ref != null
		and _initial_owner_instance_id != 0
		and not _method_name.is_empty()
	)


func _make_result(status: StringName, value: Variant, error_code: Error) -> Dictionary:
	return {
		"status": status,
		"invoked": status == STATUS_INVOKED,
		"value": value,
		"error_code": error_code,
		"initial_owner_instance_id": _initial_owner_instance_id,
		"method_name": _method_name,
	}


func _validate_argument_count(owner: Object, argument_count: int) -> Error:
	var found_valid_signature: bool = false
	for method_record: Dictionary in owner.get_method_list():
		var raw_method_name: Variant = method_record.get("name", &"")
		var candidate_method_name: StringName = &""
		if raw_method_name is StringName:
			candidate_method_name = raw_method_name
		elif raw_method_name is String:
			var method_name_text: String = raw_method_name
			candidate_method_name = StringName(method_name_text)
		if candidate_method_name != _method_name:
			continue

		var raw_method_arguments: Variant = method_record.get("args", [])
		var raw_default_arguments: Variant = method_record.get("default_args", [])
		if not (raw_method_arguments is Array) or not (raw_default_arguments is Array):
			continue
		var method_arguments: Array = raw_method_arguments
		var default_arguments: Array = raw_default_arguments
		if default_arguments.size() > method_arguments.size():
			continue

		var required_count: int = method_arguments.size() - default_arguments.size()
		var raw_method_flags: Variant = method_record.get("flags", 0)
		if not (raw_method_flags is int):
			continue
		var method_flags: int = raw_method_flags
		var accepts_varargs: bool = (method_flags & METHOD_FLAG_VARARG) != 0
		found_valid_signature = true
		if argument_count < required_count:
			continue
		if not accepts_varargs and argument_count > method_arguments.size():
			continue
		return OK
	return ERR_INVALID_PARAMETER if found_valid_signature else ERR_INVALID_DATA
