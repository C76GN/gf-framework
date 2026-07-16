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


# --- 私有/辅助方法 ---

static func _inject_if_possible(instance: Object, architecture: GFArchitecture = null) -> void:
	var resolved_architecture: GFArchitecture = architecture
	if resolved_architecture == null:
		resolved_architecture = GFAutoload.get_architecture_or_null()

	if resolved_architecture != null and instance.has_method("inject_dependencies"):
		instance.call("inject_dependencies", resolved_architecture)
