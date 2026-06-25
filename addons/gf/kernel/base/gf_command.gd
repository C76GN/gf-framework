## GFCommand: 命令抽象基类。
##
## 子类必须实现 'execute' 方法来定义命令逻辑。
## 'execute' 可返回 null（同步命令）或一个 Signal（异步命令）。
## 调用方可使用 'await send_command(MyCommand.new())' 等待异步命令完成。
## 提供对 Model、System、Utility 的访问以及发送命令和事件的能力。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFCommand


# --- 常量 ---

const _DEPENDENCY_SCOPE_SUPPORT = preload("res://addons/gf/kernel/base/gf_dependency_scope_support.gd")


# --- 私有变量 ---

var _dependency_scope: Dictionary = _DEPENDENCY_SCOPE_SUPPORT._make_scope()
var _execution_started: bool = false


# --- 公共方法 ---

## 注入当前命令执行所在的架构实例。
## [br]
## @api framework_internal
## [br]
## @param architecture: 当前执行命令的架构。
func inject_dependencies(architecture: GFArchitecture) -> void:
	_gf_set_dependency_scope(architecture)


## 执行命令逻辑。子类必须重写此方法。
## [br]
## @api public
## [br]
## @return 同步命令返回 null；异步命令可返回一个 Signal 供外部 await。
## [br]
## @schema return {
##   "type": "Variant",
##   "description": "同步命令返回 null；异步命令可返回 Signal。"
## }
func execute() -> Variant:
	return null


## 检查命令所属架构生命周期是否仍可安全继续异步写回。
## [br]
## @api public
## [br]
## @return 所属架构仍处于活动生命周期时返回 true。
func is_lifecycle_active() -> bool:
	return _DEPENDENCY_SCOPE_SUPPORT._is_lifecycle_active(_dependency_scope, "GFCommand")


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


## 向架构发送命令。支持 await：'await send_command(MyCommand.new())'。
## [br]
## @api public
## [br]
## @param command: 要发送的命令实例。
## [br]
## @return 命令的执行结果（null 或 Signal）。
## [br]
## @schema return {
##   "type": "Variant",
##   "description": "命令执行结果；异步命令可返回 Signal。"
## }
func send_command(command: Object) -> Variant:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.send_command(command)


## 向架构发送类型事件。
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

func _gf_begin_execution_scope(architecture: GFArchitecture, lifecycle_serial: int) -> bool:
	if _execution_started:
		push_error("[GFCommand] 命令实例已经进入过执行作用域，请为每次发送创建新的命令实例。")
		return false
	_execution_started = true
	_gf_set_dependency_scope(architecture, lifecycle_serial)
	return true


func _gf_set_dependency_scope(architecture: GFArchitecture, lifecycle_serial: int = -1) -> void:
	_DEPENDENCY_SCOPE_SUPPORT._bind_scope(_dependency_scope, architecture, lifecycle_serial)


func _get_architecture() -> GFArchitecture:
	var raw_architecture: Variant = _DEPENDENCY_SCOPE_SUPPORT._get_architecture_or_global(_dependency_scope, "GFCommand")
	if raw_architecture is GFArchitecture:
		return raw_architecture
	return null


func _release_dependency_scope() -> void:
	_DEPENDENCY_SCOPE_SUPPORT._release_scope(_dependency_scope)


func _get_architecture_or_null() -> GFArchitecture:
	var raw_architecture: Variant = _DEPENDENCY_SCOPE_SUPPORT._get_architecture_or_null(_dependency_scope, "GFCommand")
	if raw_architecture is GFArchitecture:
		return raw_architecture
	return null
