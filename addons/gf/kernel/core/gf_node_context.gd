## GFNodeContext: 场景树上的局部架构上下文。
##
## 可选择继承父级架构，或创建带父级回退的 Scoped 架构。
## Scoped 架构会在节点退出树时自动 dispose，适合关卡、战斗房间、调试面板等局部模块。
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

## 当上下文架构完成初始化后发出。
## [br]
## @api public
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


# --- 常量 ---

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

var _architecture: GFArchitecture = null
var _owns_architecture: bool = false
var _is_context_ready: bool = false
var _is_context_installing: bool = false
var _context_ready_emitted: bool = false
var _context_failed_emitted: bool = false
var _context_failure_reason: String = ""
var _context_lifecycle_serial: int = 0
var _context_install_scope: GFAsyncScope = null


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	_context_lifecycle_serial += 1
	_context_ready_emitted = false
	_context_failed_emitted = false
	_context_failure_reason = ""
	_setup_architecture()
	if _owns_architecture:
		_is_context_installing = true
		var context_architecture: GFArchitecture = _architecture
		var install_scope: GFAsyncScope = _begin_context_install_scope()
		var parent_ready: bool = await _wait_for_parent_architecture_ready(context_architecture)
		if not parent_ready:
			_cancel_context_install_scope_if_current(install_scope, "父级架构未就绪。")
			_is_context_installing = false
			return
		if not _is_owned_architecture_current(context_architecture):
			_cancel_context_install_scope_if_current(install_scope, "上下文已退出树。")
			_is_context_installing = false
			return
		await call(&"install", context_architecture, install_scope)
		if not _is_owned_architecture_current(context_architecture):
			_cancel_context_install_scope_if_current(install_scope, "上下文已退出树。")
			_is_context_installing = false
			return
		await call(&"install_bindings", context_architecture.create_binder(), install_scope)
		if not _is_owned_architecture_current(context_architecture):
			_cancel_context_install_scope_if_current(install_scope, "上下文已退出树。")
			_is_context_installing = false
			return
		_is_context_installing = false
		_complete_context_install_scope_if_current(install_scope)
		if auto_init:
			await _initialize_owned_architecture(context_architecture)
	elif _architecture == null:
		_fail_context("未找到可继承的架构。")
	else:
		_GF_ASYNC_CALL_SCRIPT.run_detached(
			Callable(self, &"_watch_inherited_architecture_ready"),
			[_architecture, _context_lifecycle_serial]
		)


func _process(delta: float) -> void:
	if _should_tick_owned_architecture():
		_architecture.tick(delta)


func _physics_process(delta: float) -> void:
	if _should_tick_owned_architecture():
		_architecture.physics_tick(delta)


func _exit_tree() -> void:
	_context_lifecycle_serial += 1
	_cancel_context_install_scope("上下文已退出树。")
	if _owns_architecture and _architecture != null:
		_architecture.dispose()
	_architecture = null
	_owns_architecture = false
	_is_context_ready = false
	_is_context_installing = false
	_context_ready_emitted = false
	_context_failed_emitted = false
	_context_failure_reason = ""
	_context_install_scope = null


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
	return _is_context_ready


## 检查上下文是否已经进入失败终态。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 失败后返回 true。
func is_context_failed() -> bool:
	return _context_failed_emitted


## 获取上下文失败原因。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return context_failed 发出的失败原因；未失败时为空字符串。
func get_context_failure_reason() -> String:
	return _context_failure_reason


## 手动初始化当前 Scoped 上下文。适合 auto_init 为 false 时，在 install()/install_bindings() 完成后统一触发初始化与 context_ready/context_failed 信号。
## [br]
## @api public
## [br]
## @return 初始化完成的架构；上下文失效或初始化失败时返回 null。
func initialize_context() -> GFArchitecture:
	if _context_failed_emitted:
		return null
	if _architecture == null:
		return null
	if not _owns_architecture:
		return await wait_until_ready()
	if _is_context_ready:
		return _architecture

	var context_architecture: GFArchitecture = _architecture
	while _is_context_installing:
		if not is_inside_tree():
			return null
		await get_tree().process_frame
		if _architecture != context_architecture:
			return null

	if not _is_owned_architecture_current(context_architecture):
		return null
	var parent_ready: bool = await _wait_for_parent_architecture_ready(context_architecture)
	if not parent_ready:
		return null
	if not _is_owned_architecture_current(context_architecture):
		return null

	await _initialize_owned_architecture(context_architecture)
	if _is_owned_architecture_current(context_architecture) and context_architecture.is_inited():
		return context_architecture
	return null


## 等待上下文架构完成初始化并返回该架构。
## [br]
## @api public
## [br]
## @return 当前上下文架构；上下文失效时返回 null。
func wait_until_ready() -> GFArchitecture:
	if _context_failed_emitted:
		return null
	var start_msec: int = Time.get_ticks_msec()
	while _architecture != null and not _architecture.is_inited():
		if _context_failed_emitted:
			return null
		if not is_inside_tree():
			return null
		var waiting_architecture: GFArchitecture = _architecture
		if waiting_architecture.has_initialization_failed():
			_fail_context(_get_architecture_failure_reason(waiting_architecture, "上下文架构初始化失败。"))
			return null
		var timeout_reason: String = _get_wait_timeout_reason(start_msec, "等待上下文初始化超时。")
		if not timeout_reason.is_empty():
			_fail_context(timeout_reason)
			return null
		await get_tree().process_frame
		if _architecture != waiting_architecture:
			return null

	if _architecture != null:
		if _context_failed_emitted:
			return null
		_mark_context_ready(_architecture)
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

func _setup_architecture() -> void:
	var parent_architecture: GFArchitecture = _find_parent_architecture()

	match scope_mode:
		ScopeMode.INHERITED:
			_architecture = parent_architecture
			_owns_architecture = false
			_is_context_ready = _architecture != null and _architecture.is_inited()

		ScopeMode.SCOPED:
			_architecture = GFArchitecture.new(parent_architecture)
			_architecture.strict_dependency_lookup = strict_dependency_lookup
			if module_async_init_timeout_seconds > 0.0:
				_architecture.module_async_init_timeout_seconds = module_async_init_timeout_seconds
			_owns_architecture = true
			_is_context_ready = false


func _initialize_owned_architecture(architecture_instance: GFArchitecture = null) -> void:
	if _context_failed_emitted:
		return
	var initializing_architecture: GFArchitecture = architecture_instance
	if initializing_architecture == null:
		initializing_architecture = _architecture
	if initializing_architecture == null:
		return

	var initialized: bool = await initializing_architecture.init()
	if _is_owned_architecture_current(initializing_architecture) and initialized:
		_mark_context_ready(initializing_architecture)
	elif _is_owned_architecture_current(initializing_architecture) and initializing_architecture.has_initialization_failed():
		_fail_context(_get_architecture_failure_reason(initializing_architecture, "上下文架构初始化失败。"))


func _watch_inherited_architecture_ready(inherited_architecture: GFArchitecture, lifecycle_serial: int) -> void:
	await get_tree().process_frame
	if _context_failed_emitted:
		return
	var start_msec: int = Time.get_ticks_msec()
	while _is_inherited_architecture_current(inherited_architecture, lifecycle_serial):
		if _context_failed_emitted:
			return
		if inherited_architecture.is_inited():
			_mark_context_ready(inherited_architecture)
			return
		if inherited_architecture.has_initialization_failed():
			_fail_context(_get_architecture_failure_reason(inherited_architecture, "上下文架构初始化失败。"))
			return
		var timeout_reason: String = _get_wait_timeout_reason(start_msec, "等待上下文初始化超时。")
		if not timeout_reason.is_empty():
			_fail_context(timeout_reason)
			return
		await get_tree().process_frame


func _wait_for_parent_architecture_ready(architecture_instance: GFArchitecture = null) -> bool:
	if _context_failed_emitted:
		return false
	var scoped_architecture: GFArchitecture = architecture_instance
	if scoped_architecture == null:
		scoped_architecture = _architecture
	if scoped_architecture == null:
		return true

	var parent_architecture: GFArchitecture = scoped_architecture.get_parent_architecture()
	var start_msec: int = Time.get_ticks_msec()
	while parent_architecture != null and not parent_architecture.is_inited():
		if _context_failed_emitted:
			return false
		if not _is_owned_architecture_current(scoped_architecture):
			return false
		if parent_architecture.has_initialization_failed():
			_fail_context(_get_architecture_failure_reason(parent_architecture, "父级架构初始化失败。"))
			return false
		var timeout_reason: String = _get_wait_timeout_reason(start_msec, "等待父级架构初始化超时。")
		if not timeout_reason.is_empty():
			_fail_context(timeout_reason)
			return false
		await get_tree().process_frame
		if not _is_owned_architecture_current(scoped_architecture):
			return false
		parent_architecture = scoped_architecture.get_parent_architecture()
	return true


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


func _should_tick_owned_architecture() -> bool:
	return (
		process_scoped_ticks
		and _owns_architecture
		and _architecture != null
	)


func _get_wait_timeout_reason(start_msec: int, reason: String) -> String:
	if context_wait_timeout_seconds <= 0.0:
		return ""
	var elapsed_msec: int = Time.get_ticks_msec() - start_msec
	if elapsed_msec >= int(context_wait_timeout_seconds * 1000.0):
		return reason
	return ""


func _fail_context(reason: String) -> void:
	if reason.is_empty():
		return
	_cancel_context_install_scope(reason)
	_is_context_ready = false
	_context_failure_reason = reason
	if _context_failed_emitted:
		return
	_context_failed_emitted = true
	push_warning("[GFNodeContext] %s" % reason)
	context_failed.emit(reason)


func _get_architecture_failure_reason(architecture_instance: GFArchitecture, fallback_reason: String) -> String:
	if architecture_instance != null and not architecture_instance.last_initialization_error.is_empty():
		return architecture_instance.last_initialization_error
	return fallback_reason


func _is_owned_architecture_current(architecture_instance: GFArchitecture) -> bool:
	return (
		is_inside_tree()
		and _owns_architecture
		and _architecture == architecture_instance
	)


func _is_inherited_architecture_current(architecture_instance: GFArchitecture, lifecycle_serial: int) -> bool:
	return (
		is_inside_tree()
		and not _owns_architecture
		and _architecture == architecture_instance
		and _context_lifecycle_serial == lifecycle_serial
	)


func _mark_context_ready(architecture_instance: GFArchitecture) -> void:
	if architecture_instance == null:
		return
	_is_context_ready = true
	if _context_ready_emitted:
		return
	if _architecture != architecture_instance:
		return
	_context_ready_emitted = true
	context_ready.emit(architecture_instance)


func _begin_context_install_scope() -> GFAsyncScope:
	_cancel_context_install_scope("新的上下文安装流程已开始。")
	var install_scope: GFAsyncScope = GFAsyncScope.new()
	_context_install_scope = install_scope
	return install_scope


func _complete_context_install_scope_if_current(install_scope: GFAsyncScope) -> void:
	if install_scope == null:
		return
	if _context_install_scope != install_scope:
		return
	_context_install_scope = null
	install_scope.complete()


func _cancel_context_install_scope(reason: String) -> void:
	if _context_install_scope == null:
		return
	var install_scope: GFAsyncScope = _context_install_scope
	_context_install_scope = null
	var _cancelled: bool = install_scope.cancel(reason)


func _cancel_context_install_scope_if_current(install_scope: GFAsyncScope, reason: String) -> void:
	if install_scope == null:
		return
	if _context_install_scope != install_scope:
		return
	_cancel_context_install_scope(reason)
