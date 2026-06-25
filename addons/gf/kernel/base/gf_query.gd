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

const _DEPENDENCY_SCOPE_SUPPORT = preload("res://addons/gf/kernel/base/gf_dependency_scope_support.gd")


# --- 私有变量 ---

var _dependency_scope: Dictionary = _DEPENDENCY_SCOPE_SUPPORT._make_scope()
var _execution_started: bool = false


# --- 公共方法 ---

## 注入当前查询执行所在的架构实例。
## [br]
## @api framework_internal
## [br]
## @param architecture: 当前执行查询的架构。
func inject_dependencies(architecture: GFArchitecture) -> void:
	_gf_set_dependency_scope(architecture)


## 执行查询并返回结果。子类必须重写此方法。
## [br]
## @api public
## [br]
## @return 查询结果。
## [br]
## @schema return {
##   "type": "Variant",
##   "description": "查询结果；具体类型由查询子类定义。"
## }
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


# --- 私有/辅助方法 ---

func _gf_begin_execution_scope(architecture: GFArchitecture, lifecycle_serial: int) -> bool:
	if _execution_started:
		push_error("[GFQuery] 查询实例已经进入过执行作用域，请为每次发送创建新的查询实例。")
		return false
	_execution_started = true
	_gf_set_dependency_scope(architecture, lifecycle_serial)
	return true


func _gf_set_dependency_scope(architecture: GFArchitecture, lifecycle_serial: int = -1) -> void:
	_DEPENDENCY_SCOPE_SUPPORT._bind_scope(_dependency_scope, architecture, lifecycle_serial)


func _get_architecture() -> GFArchitecture:
	var raw_architecture: Variant = _DEPENDENCY_SCOPE_SUPPORT._get_architecture_or_global(_dependency_scope, "GFQuery")
	if raw_architecture is GFArchitecture:
		return raw_architecture
	return null


func _release_dependency_scope() -> void:
	_DEPENDENCY_SCOPE_SUPPORT._release_scope(_dependency_scope)


func _get_architecture_or_null() -> GFArchitecture:
	var raw_architecture: Variant = _DEPENDENCY_SCOPE_SUPPORT._get_architecture_or_null(_dependency_scope, "GFQuery")
	if raw_architecture is GFArchitecture:
		return raw_architecture
	return null
