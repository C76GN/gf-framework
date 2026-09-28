## GFNodeContext: 场景树上的局部架构上下文。
##
## 可选择继承父级架构，或创建带父级回退的 Scoped 架构。
## Scoped 架构会在节点退出树时使用无法等待的 forced/no-drain dispose fallback，
## 适合关卡、战斗房间、调试面板等局部模块。可控或数据关键的退出必须先 await
## owned Architecture 的 shutdown_async()，再移除节点。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
## [br]
## @layer kernel/core
class_name GFNodeContext
extends Node


# --- 信号 ---

## 当上下文 Architecture 完成 stage4 activation 并提交 READY 后发出。
## [br]
## @api public
## [br]
## @since 1.9.0
## [br]
## @param architecture: 当前上下文使用的架构实例。
signal context_ready(architecture: GFArchitecture)

## 当上下文无法继续等待或初始化时发出。
## [br]
## @api public
## [br]
## @param reason: 失败原因。
signal context_failed(reason: String)


# --- 枚举 ---

## 上下文作用域模式。
## [br]
## @api public
enum ScopeMode {
	## 直接复用最近的父级上下文架构；若不存在则回退到全局 Gf 架构。
	INHERITED,
	## 创建新的局部架构，并将最近的父级或全局架构作为依赖回退来源。
	SCOPED,
}

## 节点上下文自身的安装、初始化、关闭与失败状态。
## [br]
## @api private
enum _ContextState {
	DETACHED,
	INSTALLING,
	WAITING_INITIALIZATION,
	INITIALIZING,
	READY,
	CLOSING,
	CLOSED,
	FAILED,
}


# --- 常量 ---

## 用于启动无需等待返回值的继承架构 ready 观察任务。
## [br]
## @api private
const _GF_ASYNC_CALL_SCRIPT = preload("res://addons/gf/kernel/core/gf_async_call.gd")


# --- 导出变量 ---

## 当前节点上下文的作用域模式。
## [br]
## @api public
@export var scope_mode: ScopeMode = ScopeMode.SCOPED

## 是否在进入树后自动初始化 Scoped 架构。
## [br]
## @api public
@export var auto_init: bool = true

## 是否由该节点驱动 Scoped 架构的 tick 与 physics_tick。
## [br]
## @api public
@export var process_scoped_ticks: bool = true

## Scoped 架构是否启用严格依赖查询。开启后本地未注册的依赖不会回退父级架构。
## [br]
## @api public
@export var strict_dependency_lookup: bool = false

## Scoped 架构中单个模块 async_init() 的最长等待时间。小于等于 0 时继承架构默认行为。
## [br]
## @api public
@export var module_async_init_timeout_seconds: float = 0.0

## 等待父级架构或当前上下文 ready 的超时时间。小于等于 0 时禁用超时。
## [br]
## @api public
@export var context_wait_timeout_seconds: float = 30.0


# --- 公共变量 ---

## 当前上下文使用的架构实例。
## [br]
## @api public
var architecture: GFArchitecture:
	get:
		return get_architecture()


# --- 私有变量 ---

## 当前上下文使用的架构；可能由本节点创建，也可能从父级继承。
## [br]
## @api private
var _architecture: GFArchitecture = null

## 标记当前上下文是否负责创建和释放 Architecture。
## [br]
## @api private
var _owns_architecture: bool = false

## 节点上下文自己的生命周期状态。
## [br]
## @api private
var _context_state: _ContextState = _ContextState.DETACHED

## 首次进入失败终态时保存的原因。
## [br]
## @api private
var _context_failure_reason: String = ""

## 节点每次进入或退出场景树时递增，用于拒绝旧异步流程的结果。
## [br]
## @api private
var _context_lifecycle_serial: int = 0

## 当前 Scoped Architecture 安装流程的异步取消作用域。
## [br]
## @api private
var _context_install_scope: GFAsyncScope = null

## 初始化时绑定的父级或继承 Architecture。
## [br]
## @api private
var _parent_architecture: GFArchitecture = null

## 绑定父架构时记录的生命周期 generation；未绑定时为 -1。
## [br]
## @api private
var _parent_architecture_initial_generation: int = -1

## 父架构首次被确认 ready 时的 generation；尚未 ready 时为 -1。
## [br]
## @api private
var _parent_architecture_ready_generation: int = -1


# --- Godot 生命周期方法 ---

## 开始新的上下文代次并建立架构；自有架构先等待父就绪，再依次等待安装和绑定安装且复核代次，继承架构则启动分离就绪观察。
## [br]
## @api private
func _enter_tree() -> void:
	_context_lifecycle_serial += 1
	var lifecycle_serial: int = _context_lifecycle_serial
	_context_state = _ContextState.DETACHED
	_context_failure_reason = ""
	_setup_architecture()
	if _owns_architecture:
		var context_architecture: GFArchitecture = _architecture
		var architecture_lifecycle_generation: int = (
			context_architecture.get_lifecycle_generation()
		)
		var install_scope: GFAsyncScope = _begin_context_install_scope()
		var parent_ready: bool = await _wait_for_parent_architecture_ready(
			context_architecture,
			lifecycle_serial,
			architecture_lifecycle_generation
		)
		if not parent_ready:
			_cancel_context_install_scope_if_current(install_scope, "The parent architecture is not ready.")
			return
		if not _can_continue_context_install(
			lifecycle_serial,
			context_architecture,
			architecture_lifecycle_generation,
			install_scope
		):
			_handle_context_install_interruption(
				lifecycle_serial,
				context_architecture,
				architecture_lifecycle_generation,
				install_scope
			)
			return
		await call(&"install", context_architecture, install_scope)
		if not _can_continue_context_install(
			lifecycle_serial,
			context_architecture,
			architecture_lifecycle_generation,
			install_scope
		):
			_handle_context_install_interruption(
				lifecycle_serial,
				context_architecture,
				architecture_lifecycle_generation,
				install_scope
			)
			return
		await call(&"install_bindings", context_architecture.create_binder(), install_scope)
		if not _can_continue_context_install(
			lifecycle_serial,
			context_architecture,
			architecture_lifecycle_generation,
			install_scope
		):
			_handle_context_install_interruption(
				lifecycle_serial,
				context_architecture,
				architecture_lifecycle_generation,
				install_scope
			)
			return
		if not _finish_context_install_if_current(
			lifecycle_serial,
			context_architecture,
			architecture_lifecycle_generation,
			install_scope
		):
			_handle_context_install_interruption(
				lifecycle_serial,
				context_architecture,
				architecture_lifecycle_generation,
				install_scope
			)
			return
		if auto_init:
			await _initialize_owned_architecture(context_architecture, lifecycle_serial)
	elif _architecture == null:
		_fail_context("No architecture is available to inherit.")
	else:
		_GF_ASYNC_CALL_SCRIPT.run_detached(
			Callable(self, &"_watch_inherited_architecture_ready"),
			[_architecture, lifecycle_serial]
		)


## 先同步上下文生命周期，仅在自有架构满足驱动条件时转发渲染帧 tick。
## [br]
## @api private
func _process(delta: float) -> void:
	_synchronize_context_lifecycle()
	if _should_tick_owned_architecture():
		_architecture.tick(delta)


## 先同步上下文生命周期，仅在自有架构满足驱动条件时转发物理帧 tick。
## [br]
## @api private
func _physics_process(delta: float) -> void:
	_synchronize_context_lifecycle()
	if _should_tick_owned_architecture():
		_architecture.physics_tick(delta)


## 使上下文代次失效并取消安装，只销毁自有架构，随后清空引用、状态和父架构跟踪，令迟到协程无法继续旧安装。
## [br]
## @api private
func _exit_tree() -> void:
	_context_lifecycle_serial += 1
	_cancel_context_install_scope("The context has exited the tree.")
	if _owns_architecture and _architecture != null:
		_architecture.dispose()
	_architecture = null
	_owns_architecture = false
	_context_state = _ContextState.DETACHED
	_context_failure_reason = ""
	_context_install_scope = null
	_clear_parent_architecture_tracking()


# --- 公共方法 ---

## 安装当前上下文的局部模块。仅在 SCOPED 模式下调用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param _architecture_instance: 当前上下文创建的局部架构。
## [br]
## @param _scope: 当前安装流程的可取消异步作用域。
func install(_architecture_instance: GFArchitecture, _scope: GFAsyncScope) -> void:
	pass


## 使用声明式装配器安装当前上下文的局部模块。仅在 SCOPED 模式下调用。
## [br]
## @api public
## [br]
## @param _binder: 当前上下文创建的局部架构装配器。
## [br]
## @schema _binder: GFBindBuilder-compatible binder produced by GFArchitecture.create_binder().
## [br]
## @since 8.0.0
## [br]
## @param _scope: 当前安装流程的可取消异步作用域。
func install_bindings(_binder: Variant, _scope: GFAsyncScope) -> void:
	pass


## 获取当前上下文使用的架构。
## [br]
## @api public
## [br]
## @return 架构实例；未找到时返回 null。
func get_architecture() -> GFArchitecture:
	return _architecture


## 检查上下文是否已经完成初始化。
## [br]
## @api public
## [br]
## @return 已完成初始化返回 true。
func is_context_ready() -> bool:
	_synchronize_context_lifecycle()
	return _context_state == _ContextState.READY


## 检查上下文是否已经进入失败终态。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 失败后返回 true。
func is_context_failed() -> bool:
	_synchronize_context_lifecycle()
	return _context_state == _ContextState.FAILED


## 获取上下文失败原因。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return context_failed 发出的失败原因；未失败时为空字符串。
func get_context_failure_reason() -> String:
	_synchronize_context_lifecycle()
	return _context_failure_reason


## 手动初始化当前 Scoped 上下文。适合 auto_init 为 false 时，在 install()/install_bindings() 完成后统一触发初始化与 context_ready/context_failed 信号。
## [br]
## @api public
## [br]
## @return 初始化完成的架构；上下文失效或初始化失败时返回 null。
func initialize_context() -> GFArchitecture:
	_synchronize_context_lifecycle()
	if _context_state == _ContextState.FAILED or _context_state == _ContextState.DETACHED or _is_context_ending():
		return null
	if _architecture == null:
		return null
	if not _owns_architecture:
		return await wait_until_ready()
	if _context_state == _ContextState.READY:
		return _architecture

	var context_architecture: GFArchitecture = _architecture
	var lifecycle_serial: int = _context_lifecycle_serial
	var architecture_lifecycle_generation: int = (
		context_architecture.get_lifecycle_generation()
	)
	while _context_state == _ContextState.INSTALLING:
		if not is_inside_tree():
			return null
		await get_tree().process_frame
		_synchronize_context_lifecycle()
		if _context_state == _ContextState.FAILED:
			return null
		if not _is_owned_architecture_current(context_architecture, lifecycle_serial):
			return null

	if _context_state == _ContextState.FAILED or _context_state == _ContextState.DETACHED:
		return null
	if _context_state == _ContextState.READY:
		return context_architecture
	if _context_state == _ContextState.INITIALIZING:
		return await wait_until_ready()
	if not _is_owned_architecture_current(context_architecture, lifecycle_serial):
		return null
	_context_state = _ContextState.INITIALIZING
	var parent_ready: bool = await _wait_for_parent_architecture_ready(
		context_architecture,
		lifecycle_serial,
		architecture_lifecycle_generation
	)
	if not parent_ready:
		return null
	if not _is_owned_architecture_current(context_architecture, lifecycle_serial):
		return null

	await _initialize_owned_architecture(context_architecture, lifecycle_serial)
	if (
		_is_owned_architecture_current(context_architecture, lifecycle_serial)
		and _context_state == _ContextState.READY
	):
		return context_architecture
	return null


## 等待上下文架构完成初始化并返回该架构。
## [br]
## @api public
## [br]
## @return 当前上下文架构；上下文失效时返回 null。
func wait_until_ready() -> GFArchitecture:
	_synchronize_context_lifecycle()
	if _context_state == _ContextState.FAILED or _context_state == _ContextState.DETACHED or _is_context_ending():
		return null
	var start_msec: int = Time.get_ticks_msec()
	var lifecycle_serial: int = _context_lifecycle_serial
	while _architecture != null and not _architecture.is_inited():
		_synchronize_context_lifecycle()
		if _context_state == _ContextState.FAILED or _is_context_ending():
			return null
		if not is_inside_tree():
			return null
		var waiting_architecture: GFArchitecture = _architecture
		if waiting_architecture.has_initialization_failed():
			_fail_context(_get_architecture_failure_reason(waiting_architecture, "Context architecture initialization failed."))
			return null
		if waiting_architecture.is_disposed():
			_fail_context("The context architecture lifecycle has ended.")
			return null
		var timeout_reason: String = _get_wait_timeout_reason(start_msec, "Timed out waiting for context initialization.")
		if not timeout_reason.is_empty():
			_fail_context(timeout_reason)
			return null
		await get_tree().process_frame
		if (
			_context_lifecycle_serial != lifecycle_serial
			or _architecture != waiting_architecture
		):
			return null

	if _architecture != null:
		if _context_state == _ContextState.FAILED:
			return null
		_mark_context_ready(_architecture)
		if _context_state != _ContextState.READY:
			return null
	return _architecture


## 通过当前上下文架构获取 Model。
## [br]
## @api public
## [br]
## @param model_type: 模型脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 模型实例。
func get_model(model_type: Script, require_ready: bool = false) -> Object:
	if _architecture == null:
		return null
	return _architecture.get_model(model_type, require_ready)


## 通过当前上下文架构获取 System。
## [br]
## @api public
## [br]
## @param system_type: 系统脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 系统实例。
func get_system(system_type: Script, require_ready: bool = false) -> Object:
	if _architecture == null:
		return null
	return _architecture.get_system(system_type, require_ready)


## 通过当前上下文架构获取 Utility。
## [br]
## @api public
## [br]
## @param utility_type: 工具脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 工具实例。
func get_utility(utility_type: Script, require_ready: bool = false) -> Object:
	if _architecture == null:
		return null
	return _architecture.get_utility(utility_type, require_ready)


## 仅从当前上下文架构获取 Model，不回退父级架构。
## [br]
## @api public
## [br]
## @param model_type: 模型脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 当前上下文架构中的模型实例。
func get_local_model(model_type: Script, require_ready: bool = false) -> Object:
	if _architecture == null:
		return null
	return _architecture.get_local_model(model_type, require_ready)


## 仅从当前上下文架构获取 System，不回退父级架构。
## [br]
## @api public
## [br]
## @param system_type: 系统脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 当前上下文架构中的系统实例。
func get_local_system(system_type: Script, require_ready: bool = false) -> Object:
	if _architecture == null:
		return null
	return _architecture.get_local_system(system_type, require_ready)


## 仅从当前上下文架构获取 Utility，不回退父级架构。
## [br]
## @api public
## [br]
## @param utility_type: 工具脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 当前上下文架构中的工具实例。
func get_local_utility(utility_type: Script, require_ready: bool = false) -> Object:
	if _architecture == null:
		return null
	return _architecture.get_local_utility(utility_type, require_ready)


## 向任意对象注入当前上下文架构依赖。
## [br]
## @api public
## [br]
## @param instance: 要注册、替换或注入的实例。
func inject_object(instance: Object) -> void:
	if _architecture != null:
		_architecture.inject_object(instance)


## 递归向节点树中实现注入 Hook 的节点注入当前上下文架构。
## [br]
## @api public
## [br]
## @param node: 目标节点。
func inject_node_tree(node: Node) -> void:
	if _architecture != null:
		_architecture.inject_node_tree(node)


# --- 私有/辅助方法 ---

## 捕获最近父架构，并按 scope_mode 选择继承该架构或创建一个 owned child 架构。
## [br]
## @api private
func _setup_architecture() -> void:
	var parent_architecture: GFArchitecture = _find_parent_architecture()
	_capture_parent_architecture(parent_architecture)

	match scope_mode:
		ScopeMode.INHERITED:
			_architecture = parent_architecture
			_owns_architecture = false
			_context_state = _ContextState.WAITING_INITIALIZATION

		ScopeMode.SCOPED:
			_architecture = GFArchitecture.new(parent_architecture)
			_architecture.strict_dependency_lookup = strict_dependency_lookup
			if module_async_init_timeout_seconds > 0.0:
				_architecture.module_async_init_timeout_seconds = module_async_init_timeout_seconds
			_owns_architecture = true
			_context_state = _ContextState.INSTALLING


## 仅为仍属当前上下文代次的自有架构执行初始化，等待前后校验父架构和自身身份；成功发出就绪，失败或未完成转入上下文失败。
## [br]
## @api private
func _initialize_owned_architecture(
	architecture_instance: GFArchitecture = null,
	lifecycle_serial: int = -1
) -> void:
	if _context_state == _ContextState.FAILED or _context_state == _ContextState.DETACHED:
		return
	var initializing_architecture: GFArchitecture = architecture_instance
	if initializing_architecture == null:
		initializing_architecture = _architecture
	if initializing_architecture == null:
		return
	var initializing_serial: int = lifecycle_serial
	if initializing_serial < 0:
		initializing_serial = _context_lifecycle_serial
	if not _is_owned_architecture_current(initializing_architecture, initializing_serial):
		return
	if (
		_context_state != _ContextState.WAITING_INITIALIZATION
		and _context_state != _ContextState.INITIALIZING
	):
		return
	if not _validate_parent_architecture_lifecycle(false):
		return
	_context_state = _ContextState.INITIALIZING

	var initialized: bool = await initializing_architecture.init()
	if not _is_owned_architecture_current(initializing_architecture, initializing_serial):
		return
	if _context_state == _ContextState.FAILED:
		return
	if initializing_architecture.is_disposed():
		_fail_context("The context architecture lifecycle has ended.")
		return
	if not _validate_parent_architecture_lifecycle(false):
		return
	if initialized:
		_mark_context_ready(initializing_architecture)
	elif initializing_architecture.has_initialization_failed():
		_fail_context(_get_architecture_failure_reason(initializing_architecture, "Context architecture initialization failed."))
	else:
		_fail_context("Context architecture initialization did not complete.")


## 先让出一帧再观察继承架构，在上下文代次有效期间等待其就绪；逐帧检查父生命周期及超时，身份改变后退出旧观察。
## [br]
## @api private
func _watch_inherited_architecture_ready(inherited_architecture: GFArchitecture, lifecycle_serial: int) -> void:
	await get_tree().process_frame
	if _context_state == _ContextState.FAILED:
		return
	var start_msec: int = Time.get_ticks_msec()
	while _is_inherited_architecture_current(inherited_architecture, lifecycle_serial):
		if _context_state == _ContextState.FAILED:
			return
		if not _validate_parent_architecture_lifecycle(true):
			return
		if inherited_architecture.is_inited():
			_mark_context_ready(inherited_architecture)
			return
		var timeout_reason: String = _get_wait_timeout_reason(start_msec, "Timed out waiting for context initialization.")
		if not timeout_reason.is_empty():
			_fail_context(timeout_reason)
			return
		await get_tree().process_frame


## 等待父架构就绪并在每次让帧前后校验自有架构代次；超时或任一生命周期失效令上下文失败，没有关联架构时直接成功。
## [br]
## @api private
func _wait_for_parent_architecture_ready(
	architecture_instance: GFArchitecture = null,
	lifecycle_serial: int = -1,
	architecture_lifecycle_generation: int = -1
) -> bool:
	if _context_state == _ContextState.FAILED:
		return false
	var scoped_architecture: GFArchitecture = architecture_instance
	if scoped_architecture == null:
		scoped_architecture = _architecture
	if scoped_architecture == null:
		return true
	var waiting_serial: int = lifecycle_serial
	if waiting_serial < 0:
		waiting_serial = _context_lifecycle_serial
	var waiting_architecture_generation: int = architecture_lifecycle_generation
	if waiting_architecture_generation < 0:
		waiting_architecture_generation = scoped_architecture.get_lifecycle_generation()
	if not _validate_owned_architecture_wait_target(
		scoped_architecture,
		waiting_serial,
		waiting_architecture_generation
	):
		return false
	if not _validate_parent_architecture_lifecycle(true):
		return false

	var parent_architecture: GFArchitecture = _parent_architecture
	var start_msec: int = Time.get_ticks_msec()
	while parent_architecture != null and not parent_architecture.is_inited():
		if _context_state == _ContextState.FAILED:
			return false
		if not _validate_owned_architecture_wait_target(
			scoped_architecture,
			waiting_serial,
			waiting_architecture_generation
		):
			return false
		if not _validate_parent_architecture_lifecycle(true):
			return false
		var timeout_reason: String = _get_wait_timeout_reason(start_msec, "Timed out waiting for parent architecture initialization.")
		if not timeout_reason.is_empty():
			_fail_context(timeout_reason)
			return false
		await get_tree().process_frame
		if not _validate_owned_architecture_wait_target(
			scoped_architecture,
			waiting_serial,
			waiting_architecture_generation
		):
			return false
		if not _validate_parent_architecture_lifecycle(true):
			return false
	if not _validate_owned_architecture_wait_target(
		scoped_architecture,
		waiting_serial,
		waiting_architecture_generation
	):
		return false
	return _validate_parent_architecture_lifecycle(false)


## 从最近的父 GFNodeContext 查找可用 Architecture，未找到时回退到 GFAutoload。
## [br]
## @api private
func _find_parent_architecture() -> GFArchitecture:
	var current_node: Node = get_parent()
	while current_node != null:
		if current_node is GFNodeContext:
			var parent_context: GFNodeContext = current_node
			var context_architecture: GFArchitecture = parent_context.get_architecture()
			if context_architecture != null:
				return context_architecture
		current_node = current_node.get_parent()

	return GFAutoload.get_architecture_or_null()


## 仅当开关开启、上下文拥有已初始化且 READY 的架构时允许驱动 tick。
## [br]
## @api private
func _should_tick_owned_architecture() -> bool:
	return (
		process_scoped_ticks
		and _owns_architecture
		and _architecture != null
		and _context_state == _ContextState.READY
		and _architecture.is_inited()
	)


## 超时未启用或等待未超时时返回空字符串，否则返回传入的失败原因。
## [br]
## @api private
func _get_wait_timeout_reason(start_msec: int, reason: String) -> String:
	if context_wait_timeout_seconds <= 0.0:
		return ""
	var elapsed_msec: int = Time.get_ticks_msec() - start_msec
	if elapsed_msec >= int(context_wait_timeout_seconds * 1000.0):
		return reason
	return ""


## 在允许的状态下先写入失败并取消安装，再销毁自有架构；取消或销毁回调改变上下文后抑制旧代次的失败信号。
## [br]
## @api private
func _fail_context(reason: String, allow_ready_transition: bool = false) -> void:
	if reason.is_empty():
		return
	if (
		(_context_state == _ContextState.READY and not allow_ready_transition)
		or _context_state == _ContextState.FAILED
		or _context_state == _ContextState.DETACHED
	):
		return
	var failure_lifecycle_serial: int = _context_lifecycle_serial
	var failure_architecture: GFArchitecture = _architecture
	var should_dispose_architecture: bool = _owns_architecture
	_context_state = _ContextState.FAILED
	_context_failure_reason = reason
	_cancel_context_install_scope(reason)
	if should_dispose_architecture and failure_architecture != null:
		failure_architecture.dispose()
	if (
		_context_lifecycle_serial != failure_lifecycle_serial
		or _context_state != _ContextState.FAILED
		or _architecture != failure_architecture
	):
		return
	push_warning("[GFNodeContext][node_context.failed] Context failed.\n%s" % reason)
	context_failed.emit(reason)


## 上下文处于 CLOSING 或 CLOSED 时返回 true。
## [br]
## @api private
func _is_context_ending() -> bool:
	return _context_state == _ContextState.CLOSING or _context_state == _ContextState.CLOSED


## 将自有架构的关闭、静默及失败状态同步到上下文；正常关闭进入 CLOSED，强制终止或就绪生命周期失效转为失败。
## [br]
## @api private
func _synchronize_context_lifecycle() -> void:
	if (
		_context_state == _ContextState.DETACHED
		or _context_state == _ContextState.FAILED
		or _context_state == _ContextState.CLOSED
		or _architecture == null
	):
		return
	var allow_ready_transition: bool = _context_state == _ContextState.READY
	if _owns_architecture and _architecture.is_disposed():
		var shutdown_result: GFArchitectureShutdownResult = _architecture.get_last_shutdown_result()
		if shutdown_result != null and shutdown_result.get_status() != GFArchitectureShutdownResult.Status.FORCED:
			_context_state = _ContextState.CLOSED
			return
		_fail_context("The context architecture lifecycle has ended.", allow_ready_transition)
		return
	if _owns_architecture and _architecture.has_initialization_failed():
		_fail_context(
			_get_architecture_failure_reason(
				_architecture,
				"Context architecture initialization failed."
			),
			allow_ready_transition
		)
		return
	if not _validate_parent_architecture_lifecycle(true):
		return
	if _owns_architecture and _architecture.is_quiescing():
		_context_state = _ContextState.CLOSING
		return
	if _context_state == _ContextState.READY and not _architecture.is_inited():
		_fail_context("The context architecture lifecycle is no longer valid.", true)


## 保存父架构身份和初始 generation；若它已初始化，同时记录 ready generation。
## [br]
## @api private
func _capture_parent_architecture(parent_architecture: GFArchitecture) -> void:
	_parent_architecture = parent_architecture
	_parent_architecture_initial_generation = -1
	_parent_architecture_ready_generation = -1
	if parent_architecture == null:
		return
	var lifecycle_generation: int = parent_architecture.get_lifecycle_generation()
	_parent_architecture_initial_generation = lifecycle_generation
	if parent_architecture.is_inited():
		_parent_architecture_ready_generation = lifecycle_generation


## 清空父架构引用及其两个 generation 快照。
## [br]
## @api private
func _clear_parent_architecture_tracking() -> void:
	_parent_architecture = null
	_parent_architecture_initial_generation = -1
	_parent_architecture_ready_generation = -1


## 验证当前绑定父架构的身份、失败状态与初始化代次；首次就绪时锁定其代次，之后不接受重新初始化，必要时令已就绪上下文失败。
## [br]
## @api private
func _validate_parent_architecture_lifecycle(allow_pending: bool) -> bool:
	var bound_parent_architecture: GFArchitecture = _get_bound_parent_architecture()
	var relationship_name: String = "Parent architecture" if _owns_architecture else "Inherited architecture"
	var allow_ready_transition: bool = _context_state == _ContextState.READY
	if _parent_architecture != null and _parent_architecture.is_disposed():
		_fail_context("%s lifecycle has ended." % relationship_name, allow_ready_transition)
		return false
	if _parent_architecture != null and _parent_architecture.has_initialization_failed():
		_fail_context(
			_get_architecture_failure_reason(
				_parent_architecture,
				"%s initialization failed." % relationship_name
			),
			allow_ready_transition
		)
		return false
	if bound_parent_architecture != _parent_architecture:
		_fail_context("%s identity changed." % relationship_name, allow_ready_transition)
		return false
	if _parent_architecture == null:
		return true

	var lifecycle_generation: int = _parent_architecture.get_lifecycle_generation()
	if _parent_architecture_ready_generation >= 0:
		if (
			lifecycle_generation != _parent_architecture_ready_generation
			or not _parent_architecture.is_inited()
		):
			_fail_context("%s lifecycle is no longer valid." % relationship_name, allow_ready_transition)
			return false
		return true
	if not _is_parent_architecture_wait_generation_valid(lifecycle_generation):
		_fail_context("%s lifecycle is no longer valid." % relationship_name, allow_ready_transition)
		return false
	if _parent_architecture.is_inited():
		_parent_architecture_ready_generation = lifecycle_generation
		return true
	if not allow_pending:
		_fail_context("%s is not ready." % relationship_name, allow_ready_transition)
		return false
	return true


## 返回当前绑定的父架构；owned 模式读取 Architecture parent，其余模式重新查找父级。
## [br]
## @api private
func _get_bound_parent_architecture() -> GFArchitecture:
	if not _owns_architecture:
		return _find_parent_architecture()
	if _architecture == null:
		return null
	return _architecture.get_parent_architecture()


## 等待期接受记录的初始代次，或恰好递增一次且生命周期仍活跃的代次；更大的跳变视为父架构已换生命周期。
## [br]
## @api private
func _is_parent_architecture_wait_generation_valid(lifecycle_generation: int) -> bool:
	if lifecycle_generation == _parent_architecture_initial_generation:
		return true
	return (
		lifecycle_generation == _parent_architecture_initial_generation + 1
		and _parent_architecture != null
		and _parent_architecture.is_lifecycle_active()
	)


## 优先返回 Architecture 保存的初始化错误；没有时返回调用方提供的原因。
## [br]
## @api private
func _get_architecture_failure_reason(architecture_instance: GFArchitecture, fallback_reason: String) -> String:
	if architecture_instance != null and not architecture_instance.last_initialization_error.is_empty():
		return architecture_instance.last_initialization_error
	return fallback_reason


## 检查节点仍在树内、仍拥有同一架构，并可选地匹配捕获的 context serial。
## [br]
## @api private
func _is_owned_architecture_current(
	architecture_instance: GFArchitecture,
	lifecycle_serial: int = -1
) -> bool:
	return (
		is_inside_tree()
		and _owns_architecture
		and _architecture == architecture_instance
		and (
			lifecycle_serial < 0
			or _context_lifecycle_serial == lifecycle_serial
		)
	)


## 确认父架构等待仍指向本轮自有架构；上下文已失效时返回 false，架构销毁、初始化失败或代次改变时同时记录上下文失败。
## [br]
## @api private
func _validate_owned_architecture_wait_target(
	architecture_instance: GFArchitecture,
	lifecycle_serial: int,
	architecture_lifecycle_generation: int
) -> bool:
	if architecture_instance == null:
		return false
	if _context_state == _ContextState.FAILED or _context_state == _ContextState.DETACHED:
		return false
	if not _is_owned_architecture_current(architecture_instance, lifecycle_serial):
		return false
	if architecture_instance.is_disposed():
		_fail_context("The context architecture lifecycle has ended.")
		return false
	if architecture_instance.has_initialization_failed():
		_fail_context(
			_get_architecture_failure_reason(
				architecture_instance,
				"Context architecture initialization failed while waiting for the parent."
			)
		)
		return false
	if (
		architecture_instance.get_lifecycle_generation()
		!= architecture_lifecycle_generation
	):
		_fail_context("The context architecture lifecycle became invalid while waiting for the parent.")
		return false
	return true


## 检查节点仍在树内、未拥有架构，且架构身份、serial 与非 DETACHED/FAILED 状态匹配。
## [br]
## @api private
func _is_inherited_architecture_current(architecture_instance: GFArchitecture, lifecycle_serial: int) -> bool:
	return (
		is_inside_tree()
		and not _owns_architecture
		and _architecture == architecture_instance
		and _context_lifecycle_serial == lifecycle_serial
		and _context_state != _ContextState.DETACHED
		and _context_state != _ContextState.FAILED
	)


## 仅为树内且仍在等待或初始化的当前架构标记就绪，先验证父链；发出信号后再同步生命周期以接住监听器造成的状态变化。
## [br]
## @api private
func _mark_context_ready(architecture_instance: GFArchitecture) -> void:
	if architecture_instance == null:
		return
	if _architecture != architecture_instance:
		return
	if architecture_instance.has_initialization_failed() or architecture_instance.is_disposed():
		return
	if not architecture_instance.is_inited():
		return
	if not is_inside_tree():
		return
	if (
		_context_state == _ContextState.READY
		or _context_state == _ContextState.FAILED
		or _context_state == _ContextState.DETACHED
	):
		return
	if (
		_context_state != _ContextState.WAITING_INITIALIZATION
		and _context_state != _ContextState.INITIALIZING
	):
		return
	if not _validate_parent_architecture_lifecycle(false):
		return
	_context_state = _ContextState.READY
	context_ready.emit(architecture_instance)
	_synchronize_context_lifecycle()


## 取消并替换旧安装作用域，返回并保存新的 GFAsyncScope。
## [br]
## @api private
func _begin_context_install_scope() -> GFAsyncScope:
	_cancel_context_install_scope("A new context installation has started.")
	var install_scope: GFAsyncScope = GFAsyncScope.new()
	_context_install_scope = install_scope
	return install_scope


## 仅在安装的架构、上下文代次及作用域仍有效时完成作用域并转入等待初始化；旧协程不能结算新一轮安装。
## [br]
## @api private
func _finish_context_install_if_current(
	lifecycle_serial: int,
	architecture_instance: GFArchitecture,
	architecture_lifecycle_generation: int,
	install_scope: GFAsyncScope
) -> bool:
	if not _can_continue_context_install(
		lifecycle_serial,
		architecture_instance,
		architecture_lifecycle_generation,
		install_scope
	):
		return false
	_context_install_scope = null
	install_scope.complete()
	_context_state = _ContextState.WAITING_INITIALIZATION
	return true


## 先清空当前作用域字段，再以给定原因取消已保存的作用域。
## [br]
## @api private
func _cancel_context_install_scope(reason: String) -> void:
	if _context_install_scope == null:
		return
	var install_scope: GFAsyncScope = _context_install_scope
	_context_install_scope = null
	var _cancelled: bool = install_scope.cancel(reason)


## 仅当参数与当前作用域为同一对象时取消当前安装作用域。
## [br]
## @api private
func _cancel_context_install_scope_if_current(install_scope: GFAsyncScope, reason: String) -> void:
	if install_scope == null:
		return
	if _context_install_scope != install_scope:
		return
	_cancel_context_install_scope(reason)


## 检查安装状态、架构身份与 generation、作用域身份和取消状态，以及父架构准入状态。
## [br]
## @api private
func _can_continue_context_install(
	lifecycle_serial: int,
	architecture_instance: GFArchitecture,
	architecture_lifecycle_generation: int,
	install_scope: GFAsyncScope
) -> bool:
	if _context_state != _ContextState.INSTALLING:
		return false
	if not _is_owned_architecture_current(architecture_instance, lifecycle_serial):
		return false
	if install_scope == null or _context_install_scope != install_scope:
		return false
	if install_scope.is_cancel_requested():
		return false
	if architecture_instance.is_disposed():
		return false
	if architecture_instance.has_initialization_failed():
		return false
	if architecture_instance.get_lifecycle_generation() != architecture_lifecycle_generation:
		return false
	return _validate_parent_architecture_lifecycle(false)


## 只为仍处于安装阶段的当前自有架构解释中断，按取消、销毁、初始化失败、代次或作用域失效选择原因并转入失败。
## [br]
## @api private
func _handle_context_install_interruption(
	lifecycle_serial: int,
	architecture_instance: GFArchitecture,
	architecture_lifecycle_generation: int,
	install_scope: GFAsyncScope
) -> void:
	if _context_state != _ContextState.INSTALLING:
		return
	if not _is_owned_architecture_current(architecture_instance, lifecycle_serial):
		return

	var failure_reason: String = ""
	if install_scope != null and install_scope.is_cancel_requested():
		failure_reason = String(install_scope.get_cancel_reason())
	elif architecture_instance.is_disposed():
		failure_reason = "The context architecture lifecycle ended during installation."
	elif architecture_instance.has_initialization_failed():
		failure_reason = _get_architecture_failure_reason(
			architecture_instance,
			"Context architecture initialization failed during installation."
		)
	elif architecture_instance.get_lifecycle_generation() != architecture_lifecycle_generation:
		failure_reason = "The context architecture lifecycle became invalid during installation."
	elif _context_install_scope != install_scope:
		failure_reason = "The context installation scope is no longer valid."
	else:
		failure_reason = "Context installation did not complete."
	_fail_context(failure_reason)
