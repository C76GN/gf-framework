## GFInteractionFlow: 基于 GFInteractionContext 的链式交互辅助对象。
##
## 保持上下文传递与命令执行的显式类型边界，适合一次性组织交互流程。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFInteractionFlow
extends RefCounted


# --- 公共变量 ---

## 当前交互上下文。
## [br]
## @api public
var context: GFInteractionContext


# --- 私有变量 ---

var _architecture_ref: WeakRef = null


# --- Godot 生命周期方法 ---

func _init(p_context: GFInteractionContext = null) -> void:
	context = p_context if p_context != null else GFInteractionContext.new()


# --- 公共方法 ---

## 注入当前交互所属架构。
## [br]
## @api framework_internal
## [br]
## @param architecture: 用于命令或事件派发的架构实例。
func inject_dependencies(architecture: GFArchitecture) -> void:
	_architecture_ref = weakref(architecture) if architecture != null else null


## 设置交互目标。
## [br]
## @api public
## [br]
## @param target: 交互目标对象。
## [br]
## @return: 当前交互流程。
func to(target: Object) -> GFInteractionFlow:
	var _with_target_result_52: Variant = context.with_target(target)
	return self


## 设置交互 payload。
## [br]
## @api public
## [br]
## @param payload: 随事件或交互传递的数据。
## [br]
## @schema payload: 交互携带的任意项目载荷；框架只透传。
## [br]
## @return: 当前交互流程。
func with_payload(payload: Variant) -> GFInteractionFlow:
	var _with_payload_result_66: Variant = context.with_payload(payload)
	return self


## 设置交互分组。
## [br]
## @api public
## [br]
## @param group_name: 项目自定义分组名称。
## [br]
## @return: 当前交互流程。
func in_group(group_name: StringName) -> GFInteractionFlow:
	var _with_group_result_78: Variant = context.with_group(group_name)
	return self


## 执行命令。命令可通过 interaction_context 属性或 set_interaction_context(context) 接收上下文。
## [br]
## @api public
## [br]
## @param command: 要执行的命令实例。
## [br]
## @return: 命令执行结果。
## [br]
## @schema return: GFArchitecture.send_command() 或 command.execute() 返回的任意项目结果；缺少命令时返回 null。
func execute(command: Object) -> Variant:
	if command == null:
		return null

	_apply_context(command)
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		return architecture.send_command(command)
	if command.has_method("execute"):
		return command.call("execute")
	return null


## 发送事件。事件可通过 interaction_context 属性或 set_interaction_context(context) 接收上下文。
## [br]
## @api public
## [br]
## @param event_instance: 要派发的事件实例。
func send_event(event_instance: Object) -> void:
	if event_instance == null:
		return

	_apply_context(event_instance)
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		architecture.send_event(event_instance)


# --- 私有/辅助方法 ---

func _apply_context(instance: Object) -> void:
	if instance == null or context == null:
		return

	if instance.has_method("set_interaction_context"):
		instance.call("set_interaction_context", context)
	elif _has_property(instance, &"interaction_context"):
		instance.set("interaction_context", context)


func _get_architecture_or_null() -> GFArchitecture:
	if _architecture_ref != null:
		var architecture: GFArchitecture = _get_architecture_value(_architecture_ref.get_ref())
		if architecture != null:
			return architecture
	return GFAutoload.get_architecture_or_null()


func _get_architecture_value(value: Variant) -> GFArchitecture:
	if value is GFArchitecture:
		var architecture: GFArchitecture = value
		return architecture
	return null


func _has_property(instance: Object, property_name: StringName) -> bool:
	for property_info: Dictionary in instance.get_property_list():
		if StringName(GFVariantData.get_option_string(property_info, "name")) == property_name:
			return true
	return false
