## GFCapability: 可挂载到任意 Object 的能力组件基类。
##
## 适合承载可复用的实体能力，例如 Health、Interactable、Selectable 等。
## 能力实例由 GFCapabilityUtility 挂载、查询与移除。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFCapability
extends RefCounted


# --- 常量 ---

const _CAPABILITY_UTILITY_SCRIPT = preload("res://addons/gf/extensions/capability/core/gf_capability_utility.gd")


# --- 导出变量 ---

## 当前能力依赖的其他能力类型。运行时挂载前会先确保这些能力存在。
## [br]
## @api public
@export var required_capabilities: Array[Script] = []


# --- 公共变量 ---

## 当前能力所属对象。由 GFCapabilityUtility 挂载时写入。
## [br]
## @api public
## [br]
## @since 8.0.0
var receiver: Object:
	get:
		return _get_receiver_or_null()
	set(value):
		_receiver_ref = weakref(value) if value != null else null

## 当前能力是否启用。请优先通过 GFCapabilityUtility.set_capability_active() 修改。
## [br]
## @api public
var active: bool = true


# --- 私有变量 ---

var _architecture_ref: WeakRef = null
var _receiver_ref: WeakRef = null


# --- 公共方法 ---

## 注入当前能力所属架构。
## [br]
## @api framework_internal
## [br]
## @param architecture: 当前架构实例。
func inject_dependencies(architecture: GFArchitecture) -> void:
	_architecture_ref = weakref(architecture) if architecture != null else null


## 返回当前能力依赖的其他能力类型。
## 默认返回 required_capabilities；只有运行时动态依赖才建议在子类中重写。
## GFCapabilityUtility 会在挂载当前能力前先确保这些能力存在。
## [br]
## @api public
## [br]
## @return: 当前能力依赖的能力脚本类型列表。
func get_required_capabilities() -> Array[Script]:
	return required_capabilities


## 返回移除当前能力时对自动补齐依赖能力的处理策略。
## [br]
## @api public
## [br]
## @return: DependencyRemovalPolicy 枚举值。
func get_dependency_removal_policy() -> int:
	return GFCapabilityUtility.DependencyRemovalPolicy.REMOVE_AUTO_DEPENDENCIES


## 能力挂载到对象后调用。
## [br]
## @api public
## [br]
## @param target: 当前能力所属对象。
func on_gf_capability_added(target: Object) -> void:
	receiver = target


## 能力从对象移除前调用。
## [br]
## @api public
## [br]
## @param _target: 当前能力所属对象。
func on_gf_capability_removed(_target: Object) -> void:
	receiver = null


## 能力启停状态变化后调用。
## [br]
## @api public
## [br]
## @param _target: 当前能力所属对象。
## [br]
## @param _active: 当前启停状态。
func on_gf_capability_active_changed(_target: Object, _active: bool) -> void:
	pass


## 通过当前架构获取 Model。
## [br]
## @api public
## [br]
## @param model_type: 要获取的 Model 脚本类型。
## [br]
## @return: Model 实例；不可用时返回 null。
func get_model(model_type: Script) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_model(model_type)


## 通过当前架构获取 System。
## [br]
## @api public
## [br]
## @param system_type: 目标类型。
## [br]
## @return: System 实例；不可用时返回 null。
func get_system(system_type: Script) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_system(system_type)


## 通过当前架构获取 Utility。
## [br]
## @api public
## [br]
## @param utility_type: 要获取的 Utility 脚本类型。
## [br]
## @return: Utility 实例；不可用时返回 null。
func get_utility(utility_type: Script) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_utility(utility_type)


## 获取当前 receiver 上的其他能力。
## [br]
## @api public
## [br]
## @param capability_type: 要查询、添加或移除的能力脚本类型。
## [br]
## @return: 能力实例；不存在时返回 null。
func get_capability(capability_type: Script) -> Object:
	if receiver == null:
		return null

	var capability_utility: GFCapabilityUtility = _get_capability_utility()
	if capability_utility == null:
		return null

	return capability_utility.get_capability(receiver, capability_type)


# --- 私有/辅助方法 ---

func _get_architecture_or_null() -> GFArchitecture:
	if _architecture_ref != null:
		var architecture_value: Object = _architecture_ref.get_ref()
		if architecture_value is GFArchitecture:
			var architecture: GFArchitecture = architecture_value
			return architecture
	return GFAutoload.get_architecture_or_null()


func _get_receiver_or_null() -> Object:
	if _receiver_ref == null:
		return null
	var value: Variant = _receiver_ref.get_ref()
	if value is Object and is_instance_valid(value):
		var receiver_object: Object = value
		return receiver_object
	return null


func _get_capability_utility() -> GFCapabilityUtility:
	var utility: Object = get_utility(_CAPABILITY_UTILITY_SCRIPT)
	if utility is GFCapabilityUtility:
		var capability_utility: GFCapabilityUtility = utility
		return capability_utility
	return null
