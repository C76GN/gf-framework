## GFModel: 数据层抽象基类。
##
## 负责管理应用数据和业务状态。
## 子类可以实现 'init'、'async_init'、'ready'、'dispose' 来管理其生命周期。
##
## 三阶段初始化约定：
##   - 'init'       阶段：只允许初始化自身内部变量，禁止跨模块获取依赖。
##   - 'async_init' 阶段：可使用 await，用于异步资源加载等操作。
##   - 'ready'      阶段：架构内所有模块均已完成 'init'，可安全跨模块获取依赖。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFModel


# --- 常量 ---

const _DEPENDENCY_SCOPE_SUPPORT = preload("res://addons/gf/kernel/base/gf_dependency_scope_support.gd")


# --- 公共变量 ---

## 生命周期优先级。数值越大越早执行 init/async_init/ready，dispose 时越晚释放。
## 默认 0 表示同优先级下按注册顺序执行；只有存在明确依赖顺序时才建议设置。
## [br]
## @api public
var lifecycle_priority: int = 0


# --- 私有变量 ---

var _dependency_scope: Dictionary = _DEPENDENCY_SCOPE_SUPPORT._make_scope()


# --- Godot 生命周期方法 ---

## 第一阶段初始化。子类可以重写此方法。
## 约束：只允许初始化自身内部变量，不得跨模块获取依赖。
## [br]
## @api public
func init() -> void:
	pass


## 异步初始化阶段。子类可以重写此方法并在其中使用 await。
## Godot 4 支持在 void 函数内部使用 await，框架的 Gf.init() 会串行且安全地 await 每个模块的 async_init()。
## 约束：在 init() 之后、ready() 之前执行；首个 await 前仍运行在主线程，
## 不应放入长同步工作。需要耗时处理时应在 await 或外部回调之间检查 scope。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param _scope: 当前模块异步初始化的取消作用域。
func async_init(_scope: GFAsyncScope) -> void:
	pass


## 第三阶段初始化。子类可以重写此方法。
## 约束：此时所有模块已完成 'init'，可安全跨模块获取依赖。
## [br]
## @api public
func ready() -> void:
	pass


## 销毁模型。子类可以重写此方法。
## [br]
## @api public
func dispose() -> void:
	pass


## 释放架构注入作用域和模块缓存的外部依赖引用。
## 架构会在 dispose() 之后调用该方法；子类重写时应先释放自身缓存的 Model/System/Utility 引用，再调用 super.release_dependencies()。
## [br]
## @api public
## [br]
## @since 4.4.0
func release_dependencies() -> void:
	_release_dependency_scope()


## 获取架构级存档使用的稳定键。
## 默认返回空字符串，表示由 GFArchitecture 使用 class_name。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 稳定存档键；为空时使用框架默认规则。
func get_save_key() -> StringName:
	return &""


## 将此模型的状态序列化为字典，用于存档、状态快照等。
## 子类应重写此方法以包含所有需要持久化的字段。
## [br]
## @api public
## [br]
## @return 包含模型状态数据的字典。
## [br]
## @schema return {
##   "type": "Dictionary",
##   "additional_properties": true
## }
func to_dict() -> Dictionary:
	return {}


## 从字典反序列化并恢复此模型的状态。
## 子类应重写此方法以恢复所有相关字段。
## [br]
## @api public
## [br]
## @param _data: 包含状态数据的字典（通常来自 to_dict() 的结果）。
## [br]
## @schema _data {
##   "type": "Dictionary",
##   "additional_properties": true
## }
func from_dict(_data: Dictionary) -> void:
	pass


# --- 公共方法 ---

## 注入当前模块所属的架构实例。由 GFArchitecture 在注册模块时自动调用。
## [br]
## @api framework_internal
## [br]
## @param architecture: 当前注册该模块的架构。
func inject_dependencies(architecture: GFArchitecture) -> void:
	_gf_set_dependency_scope(architecture)


## 检查所属架构生命周期是否仍可安全继续异步写回。
## async_init() 或其他 await 之后写入状态前建议检查该值。
## [br]
## @api public
## [br]
## @return 所属架构仍处于活动生命周期时返回 true。
func is_lifecycle_active() -> bool:
	return _DEPENDENCY_SCOPE_SUPPORT._is_lifecycle_active(_dependency_scope, "GFModel")


## 检查当前模块是否已经完成 ready 阶段。
## [br]
## @api public
## [br]
## @return 当前模块完成 ready 阶段时返回 true。
func is_ready_in_architecture() -> bool:
	var architecture: GFArchitecture = _get_architecture_or_null()
	return architecture != null and architecture.is_module_ready(self)


## 通过类型获取 Utility 实例。
## [br]
## @api public
## [br]
## @param utility_type: 工具的脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 工具实例。
func get_utility(utility_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_utility(utility_type, require_ready)


## 向架构发送事件。
## [br]
## @api public
## [br]
## @param event_instance: 要分发的事件实例。
func send_event(event_instance: Object) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		architecture.send_event(event_instance)


## 发送轻量级 StringName 事件，避免高频 new() 带来的 GC 压力。
## [br]
## @api public
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param payload: 可选的事件附加数据。
## [br]
## @schema payload {
##   "type": "Variant",
##   "description": "事件附加数据；由事件消费者约定结构。"
## }
func send_simple_event(event_id: StringName, payload: Variant = null) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		architecture.send_simple_event(event_id, payload)


# --- 私有/辅助方法 ---

func _gf_set_dependency_scope(architecture: GFArchitecture, lifecycle_serial: int = -1) -> void:
	_DEPENDENCY_SCOPE_SUPPORT._bind_scope(_dependency_scope, architecture, lifecycle_serial)


func _get_architecture() -> GFArchitecture:
	var raw_architecture: Variant = _DEPENDENCY_SCOPE_SUPPORT._get_architecture_or_global(_dependency_scope, "GFModel")
	if raw_architecture is GFArchitecture:
		return raw_architecture
	return null


func _release_dependency_scope() -> void:
	_DEPENDENCY_SCOPE_SUPPORT._release_scope(_dependency_scope)


func _get_architecture_or_null() -> GFArchitecture:
	var raw_architecture: Variant = _DEPENDENCY_SCOPE_SUPPORT._get_architecture_or_null(_dependency_scope, "GFModel")
	if raw_architecture is GFArchitecture:
		return raw_architecture
	return null
