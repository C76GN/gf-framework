# 节点能力基类共享实现。
#
# 该脚本供 GFNodeCapability 及空间节点能力基类复用，不直接作为用户继承入口。
extends RefCounted


# --- 常量 ---

## Capability Utility 脚本资源。
## [br]
## @api private
const _CAPABILITY_UTILITY_SCRIPT = preload("res://addons/gf/extensions/capability/core/gf_capability_utility.gd")


# --- 框架内部方法 ---

## 创建架构弱引用。
## [br]
## @api framework_internal
## [br]
## @param architecture: 当前架构实例。
## [br]
## @return: 指向架构的弱引用；架构为空时返回 null。
static func make_architecture_ref(architecture: GFArchitecture) -> WeakRef:
	return weakref(architecture) if architecture != null else null


## 通过当前架构获取 Model。
## [br]
## @api framework_internal
## [br]
## @param architecture_ref: 当前架构弱引用。
## [br]
## @param model_type: 要获取的 Model 脚本类型。
## [br]
## @return: Model 实例；不可用时返回 null。
static func get_model(architecture_ref: WeakRef, model_type: Script) -> Object:
	var architecture: GFArchitecture = get_architecture_or_null(architecture_ref)
	if architecture == null:
		return null
	return architecture.get_model(model_type)


## 通过当前架构获取 System。
## [br]
## @api framework_internal
## [br]
## @param architecture_ref: 当前架构弱引用。
## [br]
## @param system_type: 目标类型。
## [br]
## @return: System 实例；不可用时返回 null。
static func get_system(architecture_ref: WeakRef, system_type: Script) -> Object:
	var architecture: GFArchitecture = get_architecture_or_null(architecture_ref)
	if architecture == null:
		return null
	return architecture.get_system(system_type)


## 通过当前架构获取 Utility。
## [br]
## @api framework_internal
## [br]
## @param architecture_ref: 当前架构弱引用。
## [br]
## @param utility_type: 要获取的 Utility 脚本类型。
## [br]
## @return: Utility 实例；不可用时返回 null。
static func get_utility(architecture_ref: WeakRef, utility_type: Script) -> Object:
	var architecture: GFArchitecture = get_architecture_or_null(architecture_ref)
	if architecture == null:
		return null
	return architecture.get_utility(utility_type)


## 获取当前 receiver 上的其他能力。
## [br]
## @api framework_internal
## [br]
## @param receiver: 当前能力所属对象。
## [br]
## @param architecture_ref: 当前架构弱引用。
## [br]
## @param capability_type: 要查询、添加或移除的能力脚本类型。
## [br]
## @return: 能力实例；不存在时返回 null。
static func get_capability(receiver: Object, architecture_ref: WeakRef, capability_type: Script) -> Object:
	if receiver == null:
		return null

	var capability_utility: GFCapabilityUtility = _get_capability_utility(architecture_ref)
	if capability_utility == null:
		return null

	return capability_utility.get_capability(receiver, capability_type)


## 获取当前架构，优先使用注入架构，失败时回退到全局架构。
## [br]
## @api framework_internal
## [br]
## @param architecture_ref: 当前架构弱引用。
## [br]
## @return: 当前架构；不可用时返回 null。
static func get_architecture_or_null(architecture_ref: WeakRef) -> GFArchitecture:
	if architecture_ref != null:
		var architecture_value: Object = architecture_ref.get_ref()
		if architecture_value is GFArchitecture:
			var architecture: GFArchitecture = architecture_value
			return architecture
	return GFAutoload.get_architecture_or_null()


# --- 私有/辅助方法 ---

## 从当前架构获取并收窄 Capability Utility。
## [br]
## @api private
static func _get_capability_utility(architecture_ref: WeakRef) -> GFCapabilityUtility:
	var utility: Object = get_utility(architecture_ref, _CAPABILITY_UTILITY_SCRIPT)
	if utility is GFCapabilityUtility:
		var capability_utility: GFCapabilityUtility = utility
		return capability_utility
	return null
