## GFInteractions: 创建交互上下文与链式交互流程的静态入口。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFInteractions
extends RefCounted


# --- 公共方法 ---

## 创建以 sender 为发起者的交互流程。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param sender: 交互发起者。
## [br]
## @param architecture: 用于命令或事件派发的架构实例。
## [br]
## @return: 新交互流程。
static func with_sender(sender: Object, architecture: GFArchitecture = null) -> GFInteractionFlow:
	var context: GFInteractionContext = GFInteractionContext.new(sender)
	var flow: GFInteractionFlow = GFInteractionFlow.new(context)
	_inject_if_possible(flow, architecture)
	return flow


## 创建一次 sender 到 target 的交互上下文。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param sender: 交互发起者。
## [br]
## @param target: 交互目标对象。
## [br]
## @param payload: 随事件或交互传递的数据。
## [br]
## @schema payload: 交互携带的任意项目载荷；框架只透传。
## [br]
## @param group_name: 项目自定义分组名称。
## [br]
## @return: 新交互上下文。
static func between(
	sender: Object,
	target: Object,
	payload: Variant = null,
	group_name: StringName = &""
) -> GFInteractionContext:
	return GFInteractionContext.new(sender, target, payload, group_name)


# --- 框架内部方法 ---

## 判断对象方法是否能安全接收给定实参。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param instance: 待调用对象。
## [br]
## @param method_name: 方法名称。
## [br]
## @param arguments: 计划传入的实参数组。
## [br]
## @schema arguments: Array of positional Variant arguments in call order.
## [br]
## @return: 方法存在，参数数量、固定参数 Variant 类型及 Object 类约束均兼容时返回 true。
static func is_method_call_compatible_for_framework(
	instance: Object,
	method_name: StringName,
	arguments: Array
) -> bool:
	if instance == null or not is_instance_valid(instance) or not instance.has_method(method_name):
		return false

	for method_info: Dictionary in instance.get_method_list():
		if GFVariantData.get_option_string_name(method_info, "name") != method_name:
			continue
		if not _method_accepts_argument_count(method_info, arguments.size()):
			continue
		var method_arguments: Array = GFVariantData.get_option_array(method_info, "args")
		var fixed_argument_count: int = mini(arguments.size(), method_arguments.size())
		var arguments_are_compatible: bool = true
		for index: int in range(fixed_argument_count):
			var argument_info: Dictionary = GFVariantData.as_dictionary(method_arguments[index])
			if _method_argument_accepts_value(argument_info, arguments[index]):
				continue
			arguments_are_compatible = false
			break
		if arguments_are_compatible:
			return true
	return false


# --- 私有/辅助方法 ---

static func _method_accepts_argument_count(
	method_info: Dictionary,
	argument_count: int
) -> bool:
	var method_arguments: Array = GFVariantData.get_option_array(method_info, "args")
	var default_arguments: Array = GFVariantData.get_option_array(method_info, "default_args")
	if default_arguments.size() > method_arguments.size():
		return false
	var required_count: int = method_arguments.size() - default_arguments.size()
	var method_flags: int = GFVariantData.get_option_int(method_info, "flags", 0)
	var accepts_varargs: bool = (method_flags & METHOD_FLAG_VARARG) != 0
	return (
		required_count <= argument_count
		and (argument_count <= method_arguments.size() or accepts_varargs)
	)


static func _method_argument_accepts_value(
	argument_info: Dictionary,
	value: Variant
) -> bool:
	var expected_type: int = GFVariantData.get_option_int(argument_info, "type", TYPE_NIL)
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

static func _inject_if_possible(instance: Object, architecture: GFArchitecture = null) -> void:
	var resolved_architecture: GFArchitecture = architecture
	if resolved_architecture == null:
		resolved_architecture = GFAutoload.get_architecture_or_null()

	if resolved_architecture != null and instance.has_method("inject_dependencies"):
		instance.call("inject_dependencies", resolved_architecture)
