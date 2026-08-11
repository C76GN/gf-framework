## GFInventoryRuleCallableSupport: 库存规则回调的反射预检与安全调用边界。
##
## Godot 不公开匿名 GDScript lambda 的参数类型；直接调用不兼容的强类型
## Callable 会产生无法捕获的 SCRIPT ERROR。因此库存规则只调用可从目标方法元数据
## 完整验证参数数量与类型的具名方法，并对不透明 Callable 失败关闭。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
class_name GFInventoryRuleCallableSupport
extends RefCounted


# --- 常量 ---

const _MAX_EFFECTIVE_ARGUMENTS: int = 16
const _MAX_METHOD_RECORDS: int = 2048


# --- 框架内部方法 ---

## 在调用前验证 Callable 的具名目标、有效参数数量与固定参数类型。
## [br]
## @api framework_internal
## [br]
## @param callback: 待调用的库存规则 Callable。
## [br]
## @param arguments: 调用方提供的实参数组。
## [br]
## @schema arguments: Array of positional Variant arguments in caller order.
## [br]
## @param result_output: 成功调用时写入唯一返回值的调用方数组。
## [br]
## @schema result_output: Caller-owned Array receiving exactly one Variant result after a successful call.
## [br]
## @return: 预检完整且回调已经返回时为 true；不透明或不兼容时为 false。
static func try_call_for_framework(
	callback: Callable,
	arguments: Array,
	result_output: Array
) -> bool:
	result_output.clear()
	if not callback.is_valid():
		return false

	var effective_arguments_output: Array = []
	if not _build_effective_arguments(callback, arguments, effective_arguments_output):
		return false
	var effective_arguments: Array = effective_arguments_output[0]
	var target: Object = callback.get_object()
	var method_name: StringName = callback.get_method()
	if (
		target == null
		or not is_instance_valid(target)
		or method_name == &""
		or not target.has_method(method_name)
	):
		return false
	if not _target_method_accepts(target, method_name, effective_arguments):
		return false

	result_output.append(callback.callv(arguments))
	return true


# --- 私有/辅助方法 ---

static func _build_effective_arguments(
	callback: Callable,
	arguments: Array,
	effective_arguments_output: Array
) -> bool:
	effective_arguments_output.clear()
	var unbound_count: int = callback.get_unbound_arguments_count()
	var bound_count: int = callback.get_bound_arguments_count()
	if (
		unbound_count < 0
		or bound_count < 0
		or unbound_count > arguments.size()
		or arguments.size() - unbound_count + bound_count > _MAX_EFFECTIVE_ARGUMENTS
	):
		return false

	var bound_arguments: Array = callback.get_bound_arguments()
	if bound_arguments.size() != bound_count:
		return false
	var effective_arguments: Array = arguments.slice(0, arguments.size() - unbound_count)
	effective_arguments.append_array(bound_arguments)
	effective_arguments_output.append(effective_arguments)
	return true


static func _target_method_accepts(
	target: Object,
	method_name: StringName,
	arguments: Array
) -> bool:
	var inspected_count: int = 0
	for method_info: Dictionary in target.get_method_list():
		inspected_count += 1
		if inspected_count > _MAX_METHOD_RECORDS:
			return false
		if _method_record_accepts(method_info, method_name, arguments):
			return true

	if target is Script:
		var target_script: Script = target
		for method_info: Dictionary in target_script.get_script_method_list():
			inspected_count += 1
			if inspected_count > _MAX_METHOD_RECORDS:
				return false
			if _method_record_accepts(method_info, method_name, arguments):
				return true
	return false


static func _method_record_accepts(
	method_info: Dictionary,
	method_name: StringName,
	arguments: Array
) -> bool:
	if GFVariantData.get_option_string_name(method_info, "name") != method_name:
		return false
	var raw_method_arguments: Variant = method_info.get("args", [])
	var raw_default_arguments: Variant = method_info.get("default_args", [])
	if not (raw_method_arguments is Array) or not (raw_default_arguments is Array):
		return false
	var method_arguments: Array = raw_method_arguments
	var default_arguments: Array = raw_default_arguments
	if default_arguments.size() > method_arguments.size():
		return false
	var required_count: int = method_arguments.size() - default_arguments.size()
	var method_flags: int = GFVariantData.to_int(method_info.get("flags", 0), 0)
	var accepts_varargs: bool = (method_flags & METHOD_FLAG_VARARG) != 0
	if (
		arguments.size() < required_count
		or (arguments.size() > method_arguments.size() and not accepts_varargs)
	):
		return false

	var fixed_argument_count: int = mini(arguments.size(), method_arguments.size())
	for index: int in range(fixed_argument_count):
		var raw_argument_info: Variant = method_arguments[index]
		if not (raw_argument_info is Dictionary):
			return false
		var argument_info: Dictionary = raw_argument_info
		if not _argument_accepts_value(argument_info, arguments[index]):
			return false
	return true


static func _argument_accepts_value(argument_info: Dictionary, value: Variant) -> bool:
	var expected_type: int = GFVariantData.to_int(argument_info.get("type", TYPE_NIL), TYPE_NIL)
	if expected_type == TYPE_NIL:
		return true
	if value == null:
		return expected_type == TYPE_OBJECT

	var actual_type: int = typeof(value)
	if expected_type == TYPE_FLOAT and actual_type == TYPE_INT:
		return true
	if (
		(expected_type == TYPE_STRING and actual_type == TYPE_STRING_NAME)
		or (expected_type == TYPE_STRING_NAME and actual_type == TYPE_STRING)
	):
		return true
	if actual_type != expected_type:
		return false
	if expected_type != TYPE_OBJECT:
		return true

	var expected_class_name: StringName = GFVariantData.get_option_string_name(
		argument_info,
		"class_name"
	)
	if expected_class_name == &"":
		return true
	var object_value: Object = value
	return _object_matches_class_name(object_value, expected_class_name)


static func _object_matches_class_name(
	value: Object,
	expected_class_name: StringName
) -> bool:
	if value == null or not is_instance_valid(value):
		return false
	if value.is_class(String(expected_class_name)):
		return true

	var script_value: Variant = value.get_script()
	while script_value is Script:
		var script: Script = script_value
		if (
			StringName(script.get_global_name()) == expected_class_name
			or StringName(script.resource_path) == expected_class_name
		):
			return true
		script_value = script.get_base_script()
	return false
