## GFQuery: 查询抽象基类。
##
## 用于从架构中查询数据。子类必须返回结果。
## 子类必须实现 'execute' 方法来定义查询逻辑。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFQuery


# --- 常量 ---

## 提供本类依赖作用域的创建、绑定、查询与释放实现。
## [br]
## @api private
const _DEPENDENCY_SCOPE_SUPPORT = preload("res://addons/gf/kernel/base/gf_dependency_scope_support.gd")


# --- 私有变量 ---

## 当前查询实例的架构引用、释放状态和可选生命周期代次。
## [br]
## @api private
var _dependency_scope: Dictionary = _DEPENDENCY_SCOPE_SUPPORT._make_scope()

## 首次成功进入执行作用域后保持为 true，阻止同一查询实例再次提交。
## [br]
## @api private
var _execution_started: bool = false


# --- 公共方法 ---

## 执行查询并返回结果。子类必须重写此方法。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 查询结果。
## [br]
## @schema return: {"type": "Variant", "description": "查询结果；具体类型由查询子类定义。"}
func execute() -> Variant:
	return null


## 检查查询所属架构生命周期是否仍可安全继续异步写回。
## [br]
## @api public
## [br]
## @return 所属架构仍处于活动生命周期时返回 true。
func is_lifecycle_active() -> bool:
	return _DEPENDENCY_SCOPE_SUPPORT._is_lifecycle_active(_dependency_scope, "GFQuery")


## 通过类型获取 Model 实例。
## [br]
## @api public
## [br]
## @param model_type: 模型的脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 模型实例。
func get_model(model_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_model(model_type, require_ready)


## 通过类型获取 System 实例。
## [br]
## @api public
## [br]
## @param system_type: 系统的脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 系统实例。
func get_system(system_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_system(system_type, require_ready)


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


# --- 框架内部方法 ---

## 注入当前查询执行所在的架构实例。
## [br]
## @api framework_internal
## [br]
## @param architecture: 当前执行查询的架构。
func inject_dependencies(architecture: GFArchitecture) -> void:
	_gf_set_dependency_scope(architecture)


## 由架构在执行前占用一次性执行资格；资格一经占用不因作用域释放而恢复。
## [br]
## @api framework_internal
## [br]
## @param architecture: 本次执行所属架构。
## [br]
## @param lifecycle_serial: 用于拒绝过期异步访问的架构生命周期代次。
## [br]
## @return: 首次进入返回 true；重复提交记录错误并返回 false。
func _gf_begin_execution_scope(architecture: GFArchitecture, lifecycle_serial: int) -> bool:
	if _execution_started:
		push_error("[GFQuery][query.already_executed] A query instance can only enter one execution scope; create a new query for each send.")
		return false
	_execution_started = true
	_gf_set_dependency_scope(architecture, lifecycle_serial)
	return true


## 由架构绑定或清除本实例的依赖作用域，弱引用不会延长架构生命周期。
## [br]
## @api framework_internal
## [br]
## @param architecture: 所属架构；null 释放已有绑定。
## [br]
## @param lifecycle_serial: 非负值限定架构代次；-1 沿用共享作用域的默认绑定规则。
func _gf_set_dependency_scope(architecture: GFArchitecture, lifecycle_serial: int = -1) -> void:
	_DEPENDENCY_SCOPE_SUPPORT._bind_scope(_dependency_scope, architecture, lifecycle_serial)


## 清除架构引用并保留已释放标记，阻止曾绑定对象重新回退全局架构。
## [br]
## @api framework_internal
func _release_dependency_scope() -> void:
	_DEPENDENCY_SCOPE_SUPPORT._release_scope(_dependency_scope)


# --- 私有/辅助方法 ---

## 读取依赖作用域中的架构；仅在作用域从未绑定且未释放时允许回退全局架构。
## [br]
## @api private
func _get_architecture() -> GFArchitecture:
	var raw_architecture: Variant = _DEPENDENCY_SCOPE_SUPPORT._get_architecture_or_global(_dependency_scope, "GFQuery")
	if raw_architecture is GFArchitecture:
		return raw_architecture
	return null


## 读取依赖作用域中的架构；已绑定但失效或已释放时返回 null，不回退全局架构。
## [br]
## @api private
func _get_architecture_or_null() -> GFArchitecture:
	var raw_architecture: Variant = _DEPENDENCY_SCOPE_SUPPORT._get_architecture_or_null(_dependency_scope, "GFQuery")
	if raw_architecture is GFArchitecture:
		return raw_architecture
	return null
