## GFArchitecture: 管理 Model、System 和 Utility 的注册与生命周期的容器。
##
## 生命周期遵循三阶段初始化协议：
##   阶段一 (init)       ：所有模块执行自身内部变量初始化。
##   阶段二 (async_init) ：所有模块串行执行异步初始化（可使用 await）。
##   阶段三 (ready)      ：所有模块均已完成 init，可安全进行跨模块依赖获取。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
## [br]
## @layer kernel/core
class_name GFArchitecture


# --- 信号 ---

## 当一次初始化流程完成或被 dispose() 中断后发出。
## [br]
## @api public
signal initialization_finished

## 当一次初始化流程因为框架级保护失败后发出。
## [br]
## @api public
## [br]
## @param reason: 初始化失败原因。
signal initialization_failed(reason: String)

## 当项目级 Installer 应用完成或被 dispose() 中断后发出。
## [br]
## @api public
signal project_installers_finished


# --- 常量 ---

## 依赖绑定记录脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
const GFBindingBase = preload("res://addons/gf/kernel/core/gf_binding.gd")

## 架构声明式装配器脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
const GFBinderBase = preload("res://addons/gf/kernel/core/gf_binder.gd")

## 工厂绑定生命周期定义脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
const GFBindingLifetimesBase = preload("res://addons/gf/kernel/core/gf_binding_lifetimes.gd")

## 时间提供器基类脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
const GFTimeProviderBase = preload("res://addons/gf/kernel/base/gf_time_provider.gd")
const _GF_ASYNC_CALL_SCRIPT = preload("res://addons/gf/kernel/core/gf_async_call.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

## 声明式依赖聚合 Hook 名称。
## [br]
## @api public
const HOOK_GET_REQUIRED_DEPENDENCIES: StringName = &"get_required_dependencies"

## 声明式 Model 依赖 Hook 名称。
## [br]
## @api public
const HOOK_GET_REQUIRED_MODELS: StringName = &"get_required_models"

## 声明式 System 依赖 Hook 名称。
## [br]
## @api public
const HOOK_GET_REQUIRED_SYSTEMS: StringName = &"get_required_systems"

## 声明式 Utility 依赖 Hook 名称。
## [br]
## @api public
const HOOK_GET_REQUIRED_UTILITIES: StringName = &"get_required_utilities"

## 声明式工厂依赖 Hook 名称。
## [br]
## @api public
const HOOK_GET_REQUIRED_FACTORIES: StringName = &"get_required_factories"


# --- 公共变量 ---

## 单个模块 async_init() 的最长等待时间。小于等于 0 时不启用超时。
## 默认关闭；项目可按自身加载预算显式启用。
## [br]
## @api public
var module_async_init_timeout_seconds: float = 0.0:
	set(value):
		module_async_init_timeout_seconds = maxf(value, 0.0)

## 单个生命周期阶段最多扫描模块注册表的次数，避免模块在生命周期中无限注册新模块。
## [br]
## @api public
var module_lifecycle_max_stage_passes: int = 256:
	set(value):
		module_lifecycle_max_stage_passes = maxi(value, 1)

## 严格依赖查询模式。开启后本架构查询不到本地模块时不会回退父级架构。
## [br]
## @api public
var strict_dependency_lookup: bool = false

## 最近一次初始化失败原因；没有失败时为空字符串。
## [br]
## @api public
var last_initialization_error: String = ""


# --- 私有变量 ---

var _system_registry: ModuleRegistry = ModuleRegistry.new("System")
var _model_registry: ModuleRegistry = ModuleRegistry.new("Model")
var _utility_registry: ModuleRegistry = ModuleRegistry.new("Utility")
var _systems: Dictionary = _system_registry.instances
var _models: Dictionary = _model_registry.instances
var _utilities: Dictionary = _utility_registry.instances
var _factories: Dictionary = {}
var _module_lifecycle_stages: Dictionary = {}
var _event_system: GFTypeEventSystem
var _time_provider: Object
var _inited: bool = false
var _is_initializing: bool = false
var _lifecycle_serial: int = 0
var _tick_systems: Array[Object] = []
var _physics_systems: Array[Object] = []
var _tick_utilities: Array[Object] = []
var _physics_utilities: Array[Object] = []
var _is_iterating_tick_caches: bool = false
var _tick_caches_dirty: bool = false
var _parent_architecture: GFArchitecture = null
var _project_installers_applied: bool = false
var _project_installers_running: bool = false
var _initialization_failed: bool = false
var _stale_async_write_block_count: int = 0


# --- Godot 生命周期方法 ---

## 创建架构容器，可选择指定父级架构作为依赖回退来源。
## [br]
## @api public
## [br]
## @param parent_architecture: 父级架构；为空时不启用回退。
func _init(parent_architecture: GFArchitecture = null) -> void:
	_event_system = GFTypeEventSystem.new()
	_assign_parent_architecture(parent_architecture, "_init")


# --- 公共方法 ---

## 检查架构是否已初始化。
## [br]
## @api public
## [br]
## @return 已初始化返回 true，否则返回 false。
func is_inited() -> bool:
	return _inited


## 检查最近一次初始化是否因为框架级保护失败。
## [br]
## @api public
## [br]
## @return 最近一次初始化失败返回 true。
func has_initialization_failed() -> bool:
	return _initialization_failed


## 检查当前架构生命周期是否仍处于可安全继续异步写回的活动状态。
## [br]
## @api public
## [br]
## @return 正在初始化或已完成初始化，且未被 dispose() 或失败保护中断时返回 true。
func is_lifecycle_active() -> bool:
	return (_is_initializing or _inited) and not _initialization_failed


## 检查指定模块实例是否已经完成 ready 阶段。
## [br]
## @api public
## [br]
## @param instance: 由当前架构注册的模块实例。
## [br]
## @return 模块完成 ready 阶段时返回 true。
func is_module_ready(instance: Object) -> bool:
	return _is_module_ready_for_lookup(instance)


## 将当前架构标记为初始化失败，并唤醒等待初始化或 Installer 的调用方。
## [br]
## @api public
## [br]
## @param reason: 初始化失败原因。
func fail_initialization(reason: String) -> void:
	var failure_reason: String = reason
	if failure_reason.is_empty():
		failure_reason = "[GFArchitecture] 初始化失败。"
	_fail_initialization(failure_reason, _lifecycle_serial)


## 获取父级架构。Scoped 架构会在本地未找到依赖时回退到父级架构查询。
## [br]
## @api public
## [br]
## @return 父级架构实例；未设置时返回 null。
func get_parent_architecture() -> GFArchitecture:
	return _parent_architecture


## 设置父级架构。不会接管父级生命周期。
## [br]
## @api public
## [br]
## @param parent_architecture: 要作为依赖回退来源的父级架构。
func set_parent_architecture(parent_architecture: GFArchitecture) -> void:
	_assign_parent_architecture(parent_architecture, "set_parent_architecture")


## 检查项目级 Installer 是否已经应用到当前架构。
## [br]
## @api public
## [br]
## @return 已应用返回 true。
func has_project_installers_applied() -> bool:
	return _project_installers_applied


## 检查项目级 Installer 是否正在应用。
## [br]
## @api public
## [br]
## @return 正在应用返回 true。
func is_project_installers_running() -> bool:
	return _project_installers_running


## 标记项目级 Installer 已开始应用。
## [br]
## @api public
## [br]
## @return 成功开始返回 true；已经完成或正在运行时返回 false。
func begin_project_installers() -> bool:
	if _project_installers_applied or _project_installers_running:
		return false

	if _initialization_failed and _stale_async_write_block_count > 0:
		return false

	if _initialization_failed and not _inited and not _is_initializing:
		_initialization_failed = false
		last_initialization_error = ""

	_project_installers_running = true
	return true


## 标记项目级 Installer 已应用。由 Gf 启动入口调用。
## [br]
## @api public
func mark_project_installers_applied() -> void:
	var was_running: bool = _project_installers_running
	_project_installers_applied = true
	_project_installers_running = false
	if was_running:
		project_installers_finished.emit()


## 标记项目级 Installer 应用完成并唤醒等待方。
## [br]
## @api public
func finish_project_installers() -> void:
	mark_project_installers_applied()


## 创建一个声明式装配器，便于 Installer 使用 fluent API 注册模块与工厂。
## [br]
## @api public
## [br]
## @return 绑定到当前架构的装配器。
## [br]
## @schema return: GFBinder owned by this architecture.
func create_binder() -> GFBinder:
	return GFBinderBase.new(self)


## 初始化架构及所有注册的组件（三阶段）。
## 阶段一：调用所有模块的 init()，用于初始化自身内部变量。
## 阶段二：串行 await 所有模块的 async_init()，用于异步资源加载等操作。
## 阶段三：调用所有模块的 ready()，此时跨模块依赖获取是安全的。
## [br]
## @api public
func init() -> void:
	if _inited:
		return

	if _is_initializing:
		var waiting_serial: int = _lifecycle_serial
		while _is_initializing and waiting_serial == _lifecycle_serial:
			await initialization_finished
		return

	if _initialization_failed and _stale_async_write_block_count > 0:
		return

	_lifecycle_serial += 1
	var current_serial: int = _lifecycle_serial
	_is_initializing = true
	_initialization_failed = false
	last_initialization_error = ""
	_on_init()
	await _advance_all_modules_to_stage(1, current_serial)
	if not _is_lifecycle_current(current_serial) or _initialization_failed:
		return
	await _advance_all_modules_to_stage(2, current_serial)
	if not _is_lifecycle_current(current_serial) or _initialization_failed:
		return
	await _advance_all_modules_to_stage(3, current_serial)
	if not _is_lifecycle_current(current_serial) or _initialization_failed:
		return

	_refresh_cached_utility_refs()
	_inited = true
	_is_initializing = false
	initialization_finished.emit()


## 销毁架构及所有注册的组件。
## [br]
## @api public
func dispose() -> void:
	var was_initializing: bool = _is_initializing
	_lifecycle_serial += 1
	_is_initializing = false

	_on_dispose()
	_dispose_module_registry(_system_registry)
	_dispose_module_registry(_model_registry)
	_dispose_module_registry(_utility_registry)
	for binding_variant: Variant in _factories.values():
		var binding: GFBinding = _variant_to_binding(binding_variant)
		if binding != null:
			binding.dispose_cached_instance()
	_model_registry._clear()
	_system_registry._clear()
	_utility_registry._clear()
	_factories.clear()
	_module_lifecycle_stages.clear()
	_event_system.clear()
	_time_provider = null
	_inited = false
	_initialization_failed = false
	last_initialization_error = ""
	_reset_project_installers()
	_refresh_tick_caches()
	if was_initializing:
		initialization_finished.emit()


## 驱动所有参与 tick 的 System 与 Utility 的每帧更新。
## 在架构初始化完成后方可生效。
## 若已注册 GFTimeProvider，则自动将 delta 经过时间缩放/暂停处理后再传递给参与 tick 的模块。
## 设置了 ignore_pause 的模块在暂停时将接收原始 delta。
## 设置了 ignore_time_scale 的模块在未暂停时将跳过 time_scale。
## [br]
## @api public
## [br]
## @param delta: 距上一帧的时间（秒）。
func tick(delta: float) -> void:
	if not _inited:
		return
	var time_provider: Object = _get_time_provider()
	var scaled_delta: float = _get_scaled_delta(delta, time_provider)
	_is_iterating_tick_caches = true
	for system: Object in _tick_systems:
		if is_instance_valid(system) and _is_module_ready_for_tick(system):
			_call_module_void(system, &"tick", [_get_module_delta(system, delta, scaled_delta, time_provider)])
	for utility: Object in _tick_utilities:
		if is_instance_valid(utility) and _is_module_ready_for_tick(utility):
			_call_module_void(utility, &"tick", [_get_module_delta(utility, delta, scaled_delta, time_provider)])
	_is_iterating_tick_caches = false
	_flush_tick_cache_refresh()


## 驱动所有参与 physics_tick 的 System 与 Utility 的每物理帧更新。
## 在架构初始化完成后方可生效。
## 若已注册 GFTimeProvider，则自动将 delta 经过时间缩放/暂停处理后再传递给参与 physics_tick 的模块。
## 设置了 ignore_pause 的模块在暂停时将接收原始 delta。
## 设置了 ignore_time_scale 的模块在未暂停时将跳过 time_scale。
## [br]
## @api public
## [br]
## @param delta: 距上一物理帧的时间（秒）。
func physics_tick(delta: float) -> void:
	if not _inited:
		return
	var time_provider: Object = _get_time_provider()
	if time_provider != null and _GF_VARIANT_ACCESS_SCRIPT.to_bool(time_provider.call("should_substep_physics", delta)):
		var raw_scaled_steps: Variant = time_provider.call("get_physics_scaled_delta_steps", delta)
		if not raw_scaled_steps is Array:
			return
		var scaled_steps: Array = raw_scaled_steps
		if scaled_steps.is_empty():
			return
		var raw_step: float = delta / float(scaled_steps.size())
		for scaled_step_variant: Variant in scaled_steps:
			_drive_physics_tick_step(raw_step, _GF_VARIANT_ACCESS_SCRIPT.to_float(scaled_step_variant), time_provider)
		return

	var scaled_delta: float = _get_scaled_delta(delta, time_provider)
	_drive_physics_tick_step(delta, scaled_delta, time_provider)


## 执行命令实例。支持 await：'await send_command(MyCommand.new())'。
## command 缺少 execute() 方法时会输出 warning 并返回 null。
## [br]
## @api public
## [br]
## @param command: 要执行的命令实例。
## [br]
## @return 命令 execute() 的返回值；空对象或缺少 execute() 时返回 null。
## [br]
## @schema return: Variant command result returned by command.execute().
func send_command(command: Object) -> Variant:
	if command == null:
		push_error("[GFArchitecture] send_command 失败：command 为空。")
		return null

	_inject_dependencies_if_needed(command)
	if command.has_method("execute"):
		return command.call("execute")
	push_warning("[GFArchitecture] send_command 失败：command 缺少 execute() 方法，已忽略。")
	return null


## 执行查询实例并返回结果。
## query 缺少 execute() 方法时会输出 warning 并返回 null。
## [br]
## @api public
## [br]
## @param query: 要执行的查询实例。
## [br]
## @return 查询 execute() 的返回值；空对象或缺少 execute() 时返回 null。
## [br]
## @schema return: Variant query result returned by query.execute().
func send_query(query: Object) -> Variant:
	if query == null:
		push_error("[GFArchitecture] send_query 失败：query 为空。")
		return null

	_inject_dependencies_if_needed(query)
	if query.has_method("execute"):
		return query.call("execute")
	push_warning("[GFArchitecture] send_query 失败：query 缺少 execute() 方法，已忽略。")
	return null


## 通过事件系统发送类型事件实例。
## [br]
## @api public
## [br]
## @param event_instance: 要分发的事件实例。
func send_event(event_instance: Object) -> void:
	if event_instance == null:
		push_error("[GFArchitecture] send_event 失败：event_instance 为空。")
		return

	_event_system.send(event_instance)


## 为脚本类型注册事件监听器。
## [br]
## @api public
## [br]
## @param event_type: 要监听的脚本类型。
## [br]
## @param on_event: 回调函数。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
func register_event(event_type: Script, on_event: Callable, priority: int = 0) -> void:
	_event_system.register(event_type, on_event, priority)


## 为脚本类型注册带拥有者的事件监听器。
## 拥有者注销或释放后，可通过 unregister_owner_events() 一次性清理相关监听。
## [br]
## @api public
## [br]
## @param owner: 监听器拥有者。
## [br]
## @param event_type: 要监听的脚本类型。
## [br]
## @param on_event: 回调函数。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
func register_event_owned(owner: Object, event_type: Script, on_event: Callable, priority: int = 0) -> void:
	_event_system.register(event_type, on_event, priority, owner)


## 为脚本类型注册可赋值事件监听器。
## 监听基类事件时，也会收到继承自该脚本类型的事件实例。
## [br]
## @api public
## [br]
## @param base_event_type: 要监听的基类脚本类型。
## [br]
## @param on_event: 回调函数。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
func register_assignable_event(base_event_type: Script, on_event: Callable, priority: int = 0) -> void:
	_event_system.register_assignable(base_event_type, on_event, priority)


## 为脚本类型注册带拥有者的可赋值事件监听器。
## [br]
## @api public
## [br]
## @param owner: 监听器拥有者。
## [br]
## @param base_event_type: 要监听的基类脚本类型。
## [br]
## @param on_event: 回调函数。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
func register_assignable_event_owned(
	owner: Object,
	base_event_type: Script,
	on_event: Callable,
	priority: int = 0
) -> void:
	_event_system.register_assignable(base_event_type, on_event, priority, owner)


## 为脚本类型注销事件监听器。
## [br]
## @api public
## [br]
## @param event_type: 要注销的脚本类型。
## [br]
## @param on_event: 要移除的回调函数。
func unregister_event(event_type: Script, on_event: Callable) -> void:
	_event_system.unregister(event_type, on_event)


## 注销可赋值类型事件监听器。
## [br]
## @api public
## [br]
## @param base_event_type: 注册时使用的基类脚本类型。
## [br]
## @param on_event: 要移除的回调函数。
func unregister_assignable_event(base_event_type: Script, on_event: Callable) -> void:
	_event_system.unregister_assignable(base_event_type, on_event)


## 注册轻量级 StringName 事件监听器。
## [br]
## @api public
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param on_event: 回调函数，签名为 func(payload: Variant)。
func register_simple_event(event_id: StringName, on_event: Callable) -> void:
	_event_system.register_simple(event_id, on_event)


## 注册带拥有者的轻量级 StringName 事件监听器。
## [br]
## @api public
## [br]
## @param owner: 监听器拥有者。
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param on_event: 回调函数，签名为 func(payload: Variant)。
func register_simple_event_owned(owner: Object, event_id: StringName, on_event: Callable) -> void:
	_event_system.register_simple(event_id, on_event, owner)


## 注销轻量级 StringName 事件监听器。
## [br]
## @api public
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param on_event: 要移除的回调函数。
func unregister_simple_event(event_id: StringName, on_event: Callable) -> void:
	_event_system.unregister_simple(event_id, on_event)


## 注销某个拥有者注册过的所有事件监听器。
## [br]
## @api public
## [br]
## @param owner: 要清理监听器的拥有者。
func unregister_owner_events(owner: Object) -> void:
	_event_system.unregister_owner(owner)


## 发送轻量级 StringName 事件，避免高频 new() 带来的 GC 压力。
## [br]
## @api public
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param payload: 可选的事件附加数据。
## [br]
## @schema payload: Variant payload passed unchanged to simple event listeners.
func send_simple_event(event_id: StringName, payload: Variant = null) -> void:
	_event_system.send_simple(event_id, payload)


## 获取事件系统诊断统计。
## [br]
## @api public
## [br]
## @return 包含各事件轨道监听数量与 pending 操作数量的字典。
## [br]
## @schema return: Dictionary produced by GFTypeEventSystem.get_debug_stats().
func get_event_debug_stats() -> Dictionary:
	return _event_system.get_debug_stats()


## 配置事件系统调试与保护选项。
## [br]
## @api public
## [br]
## @param max_dispatch_depth: 最大嵌套派发深度；小于等于 0 表示不限制。
## [br]
## @param trace_enabled: 是否记录派发追踪。
## [br]
## @param max_trace_entries: 最多保留的追踪条目数。
func configure_event_debugging(
	max_dispatch_depth: int = GFTypeEventSystem.DEFAULT_MAX_DISPATCH_DEPTH,
	trace_enabled: bool = false,
	max_trace_entries: int = 64
) -> void:
	_event_system.max_dispatch_depth = max_dispatch_depth
	_event_system.trace_enabled = trace_enabled
	_event_system.max_trace_entries = max_trace_entries


## 获取最近事件派发追踪条目。
## [br]
## @api public
## [br]
## @return 从旧到新的追踪条目副本。
## [br]
## @schema return: Array of Dictionary trace entries with event, listener, owner, and dispatch metadata.
func get_event_dispatch_trace() -> Array[Dictionary]:
	return _event_system.get_dispatch_trace()


## 清空事件派发追踪。
## [br]
## @api public
func clear_event_dispatch_trace() -> void:
	_event_system.clear_dispatch_trace()


# --- 公共方法（注册） ---

## 注册 System 实例。
## [br]
## @api public
## [br]
## @param script_cls: 系统的脚本类。
## [br]
## @param instance: 系统实例。
func register_system(script_cls: Script, instance: Object) -> void:
	if not _register_module(_system_registry, script_cls, instance):
		return

	_refresh_tick_caches()
	if _inited:
		await _initialize_registered_module(_system_registry, instance)


## 注册 Model 实例。
## [br]
## @api public
## [br]
## @param script_cls: 模型的脚本类。
## [br]
## @param instance: 模型实例。
func register_model(script_cls: Script, instance: Object) -> void:
	if not _register_module(_model_registry, script_cls, instance):
		return

	if _inited:
		await _initialize_registered_module(_model_registry, instance)


## 注册 Utility 实例。
## [br]
## @api public
## [br]
## @param script_cls: 工具的脚本类。
## [br]
## @param instance: 工具实例。
func register_utility(script_cls: Script, instance: Object) -> void:
	if not _register_module(_utility_registry, script_cls, instance):
		return

	_refresh_cached_utility_refs()
	_refresh_tick_caches()
	if _inited:
		await _initialize_registered_module(_utility_registry, instance)
		_refresh_cached_utility_refs()


## 替换 System 实例。若旧实例存在，会先调用 dispose() 并移除相关别名。
## [br]
## @api public
## [br]
## @param script_cls: 系统的脚本类。
## [br]
## @param instance: 新系统实例。
func replace_system(script_cls: Script, instance: Object) -> void:
	if not _validate_registration(script_cls, instance, "System"):
		return
	if _system_registry._has_direct(script_cls):
		unregister_system(script_cls)
	await register_system(script_cls, instance)


## 替换 Model 实例。若旧实例存在，会先调用 dispose() 并移除相关别名。
## [br]
## @api public
## [br]
## @param script_cls: 模型的脚本类。
## [br]
## @param instance: 新模型实例。
func replace_model(script_cls: Script, instance: Object) -> void:
	if not _validate_registration(script_cls, instance, "Model"):
		return
	if _model_registry._has_direct(script_cls):
		unregister_model(script_cls)
	await register_model(script_cls, instance)


## 替换 Utility 实例。若旧实例存在，会先调用 dispose() 并移除相关别名。
## [br]
## @api public
## [br]
## @param script_cls: 工具的脚本类。
## [br]
## @param instance: 新工具实例。
func replace_utility(script_cls: Script, instance: Object) -> void:
	if not _validate_registration(script_cls, instance, "Utility"):
		return
	if _utility_registry._has_direct(script_cls):
		unregister_utility(script_cls)
	await register_utility(script_cls, instance)


## 注册短生命周期对象工厂。
## [br]
## @api public
## [br]
## @param script_cls: 要创建的脚本类型。
## [br]
## @param factory: 返回对象实例的工厂回调。
## [br]
## @param lifetime: 工厂生命周期，默认每次 create_instance() 都创建新对象。
func register_factory(
	script_cls: Script,
	factory: Callable,
	lifetime: int = GFBindingLifetimesBase.Lifetime.TRANSIENT
) -> void:
	if not _can_mutate_registration_state("register_factory"):
		return
	if script_cls == null:
		push_error("[GFArchitecture] register_factory 失败：脚本类型为空。")
		return
	if not factory.is_valid():
		push_error("[GFArchitecture] register_factory 失败：factory 无效。")
		return
	if not _validate_factory_lifetime(lifetime, "register_factory"):
		return
	if _factories.has(script_cls):
		push_warning("[GFArchitecture] register_factory：类型已注册，已忽略重复注册。若需要替换，请使用 replace_factory()。")
		return
	_factories[script_cls] = GFBindingBase.new(script_cls, factory, self, lifetime, true)


## 注册已有实例作为短生命周期工厂入口。该实例以单例方式返回。
## [br]
## @api public
## [br]
## @param script_cls: 要创建的脚本类型。
## [br]
## @param instance: 要暴露的实例。
func register_factory_instance(script_cls: Script, instance: Object) -> void:
	if not _can_mutate_registration_state("register_factory_instance"):
		return
	if script_cls == null:
		push_error("[GFArchitecture] register_factory_instance 失败：脚本类型为空。")
		return
	if instance == null:
		push_error("[GFArchitecture] register_factory_instance 失败：实例为空。")
		return
	if _factories.has(script_cls):
		push_warning("[GFArchitecture] register_factory_instance：类型已注册，已忽略重复注册。若需要替换，请使用 replace_factory_instance()。")
		return
	_factories[script_cls] = GFBindingBase.new(script_cls, instance, self, GFBindingLifetimesBase.Lifetime.SINGLETON, true, false)


## 替换短生命周期对象工厂。
## [br]
## @api public
## [br]
## @param script_cls: 要创建的脚本类型。
## [br]
## @param factory: 新工厂回调。
## [br]
## @param lifetime: 工厂生命周期。
func replace_factory(
	script_cls: Script,
	factory: Callable,
	lifetime: int = GFBindingLifetimesBase.Lifetime.TRANSIENT
) -> void:
	if not _can_mutate_registration_state("replace_factory"):
		return
	if script_cls == null:
		push_error("[GFArchitecture] replace_factory 失败：脚本类型为空。")
		return
	if not factory.is_valid():
		push_error("[GFArchitecture] replace_factory 失败：factory 无效。")
		return
	if not _validate_factory_lifetime(lifetime, "replace_factory"):
		return
	_clear_factory_binding(script_cls)
	_factories[script_cls] = GFBindingBase.new(script_cls, factory, self, lifetime, true)


## 替换已有实例工厂入口。
## [br]
## @api public
## [br]
## @param script_cls: 要创建的脚本类型。
## [br]
## @param instance: 要暴露的实例。
func replace_factory_instance(script_cls: Script, instance: Object) -> void:
	if not _can_mutate_registration_state("replace_factory_instance"):
		return
	if script_cls == null:
		push_error("[GFArchitecture] replace_factory_instance 失败：脚本类型为空。")
		return
	if instance == null:
		push_error("[GFArchitecture] replace_factory_instance 失败：实例为空。")
		return
	_clear_factory_binding(script_cls)
	_factories[script_cls] = GFBindingBase.new(script_cls, instance, self, GFBindingLifetimesBase.Lifetime.SINGLETON, true, false)


## 注销短生命周期对象工厂。
## [br]
## @api public
## [br]
## @param script_cls: 要移除的脚本类型。
func unregister_factory(script_cls: Script) -> void:
	_clear_factory_binding(script_cls)
	var _removed_factory: bool = _factories.erase(script_cls)


## 检查当前架构或父级架构是否注册了指定工厂。
## [br]
## @api public
## [br]
## @param script_cls: 要查询的脚本类型。
## [br]
## @return 工厂存在时返回 true。
func has_factory(script_cls: Script) -> bool:
	if script_cls == null:
		return false
	if _factories.has(script_cls):
		return true
	if _parent_architecture != null and not strict_dependency_lookup:
		return _parent_architecture.has_factory(script_cls)
	return false


## 为已注册 System 增加一个额外查询别名。
## 适合把具体实现以抽象基类或接口式脚本暴露给调用方。
## [br]
## @api public
## [br]
## @param alias_cls: 调用 get_system() 时使用的别名脚本类。
## [br]
## @param target_cls: 已注册 System 的实际脚本类。
func register_system_alias(alias_cls: Script, target_cls: Script) -> void:
	_register_module_alias(_system_registry, alias_cls, target_cls)


## 为已注册 Model 增加一个额外查询别名。
## [br]
## @api public
## [br]
## @param alias_cls: 调用 get_model() 时使用的别名脚本类。
## [br]
## @param target_cls: 已注册 Model 的实际脚本类。
func register_model_alias(alias_cls: Script, target_cls: Script) -> void:
	_register_module_alias(_model_registry, alias_cls, target_cls)


## 为已注册 Utility 增加一个额外查询别名。
## [br]
## @api public
## [br]
## @param alias_cls: 调用 get_utility() 时使用的别名脚本类。
## [br]
## @param target_cls: 已注册 Utility 的实际脚本类。
func register_utility_alias(alias_cls: Script, target_cls: Script) -> void:
	_register_module_alias(_utility_registry, alias_cls, target_cls)


## 便捷注册 System 实例，自动从实例获取脚本类作为注册键。
## [br]
## @api public
## [br]
## @param instance: 系统实例，必须附加有 GDScript 脚本。
func register_system_instance(instance: Object) -> void:
	if instance == null:
		push_error("[GFArchitecture] register_system_instance 失败：实例为空。")
		return
	var script: Script = _get_instance_script_or_null(instance, "register_system_instance")
	if script == null:
		return
	await register_system(script, instance)


## 便捷注册 Model 实例，自动从实例获取脚本类作为注册键。
## [br]
## @api public
## [br]
## @param instance: 模型实例，必须附加有 GDScript 脚本。
func register_model_instance(instance: Object) -> void:
	if instance == null:
		push_error("[GFArchitecture] register_model_instance 失败：实例为空。")
		return
	var script: Script = _get_instance_script_or_null(instance, "register_model_instance")
	if script == null:
		return
	await register_model(script, instance)


## 便捷注册 Utility 实例，自动从实例获取脚本类作为注册键。
## [br]
## @api public
## [br]
## @param instance: 工具实例，必须附加有 GDScript 脚本。
func register_utility_instance(instance: Object) -> void:
	if instance == null:
		push_error("[GFArchitecture] register_utility_instance 失败：实例为空。")
		return
	var script: Script = _get_instance_script_or_null(instance, "register_utility_instance")
	if script == null:
		return
	await register_utility(script, instance)


## 便捷注册 System，并同时以 alias_cls 作为额外查询键。
## [br]
## @api public
## [br]
## @param instance: System 实例。
## [br]
## @param alias_cls: 额外查询脚本类。
func register_system_instance_as(instance: Object, alias_cls: Script) -> void:
	var script: Script = _get_instance_script_or_null(instance, "register_system_instance_as")
	if script == null:
		return

	await register_system_instance(instance)
	if _system_registry._has_direct(script):
		register_system_alias(alias_cls, script)


## 便捷注册 Model，并同时以 alias_cls 作为额外查询键。
## [br]
## @api public
## [br]
## @param instance: Model 实例。
## [br]
## @param alias_cls: 额外查询脚本类。
func register_model_instance_as(instance: Object, alias_cls: Script) -> void:
	var script: Script = _get_instance_script_or_null(instance, "register_model_instance_as")
	if script == null:
		return

	await register_model_instance(instance)
	if _model_registry._has_direct(script):
		register_model_alias(alias_cls, script)


## 便捷注册 Utility，并同时以 alias_cls 作为额外查询键。
## [br]
## @api public
## [br]
## @param instance: Utility 实例。
## [br]
## @param alias_cls: 额外查询脚本类。
func register_utility_instance_as(instance: Object, alias_cls: Script) -> void:
	var script: Script = _get_instance_script_or_null(instance, "register_utility_instance_as")
	if script == null:
		return

	await register_utility_instance(instance)
	if _utility_registry._has_direct(script):
		register_utility_alias(alias_cls, script)


## 注销 System 实例。
## [br]
## @api public
## [br]
## @param script_cls: 系统的脚本类。
func unregister_system(script_cls: Script) -> void:
	if _unregister_module(_system_registry, script_cls):
		_refresh_tick_caches()


## 注销 Model 实例。
## [br]
## @api public
## [br]
## @param script_cls: 模型的脚本类。
func unregister_model(script_cls: Script) -> void:
	var _unregistered: bool = _unregister_module(_model_registry, script_cls)


## 注销 Utility 实例。
## [br]
## @api public
## [br]
## @param script_cls: 工具的脚本类。
func unregister_utility(script_cls: Script) -> void:
	if _unregister_module(_utility_registry, script_cls):
		_refresh_cached_utility_refs()
		_refresh_tick_caches()


# --- 公共方法（获取） ---

## 通过脚本类获取 System 实例。
## [br]
## @api public
## [br]
## @param script_cls: 脚本类。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 系统实例，如果未找到则返回 null。
func get_system(script_cls: Script, require_ready: bool = false) -> Object:
	var instance: Object = _get_local_registered_instance(_system_registry, script_cls)
	if instance != null:
		return instance if not require_ready or _is_module_ready_for_lookup(instance) else null
	if _parent_architecture != null and not strict_dependency_lookup and not _has_assignable_instance(_system_registry, script_cls):
		return _parent_architecture.get_system(script_cls, require_ready)
	if strict_dependency_lookup:
		_report_strict_lookup_miss(script_cls, "System")
	return null


## 通过脚本类获取 Model 实例。
## [br]
## @api public
## [br]
## @param script_cls: 脚本类。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 模型实例，如果未找到则返回 null。
func get_model(script_cls: Script, require_ready: bool = false) -> Object:
	var instance: Object = _get_local_registered_instance(_model_registry, script_cls)
	if instance != null:
		return instance if not require_ready or _is_module_ready_for_lookup(instance) else null
	if _parent_architecture != null and not strict_dependency_lookup and not _has_assignable_instance(_model_registry, script_cls):
		return _parent_architecture.get_model(script_cls, require_ready)
	if strict_dependency_lookup:
		_report_strict_lookup_miss(script_cls, "Model")
	return null


## 通过脚本类获取 Utility 实例。
## [br]
## @api public
## [br]
## @param script_cls: 脚本类。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 工具实例，如果未找到则返回 null。
func get_utility(script_cls: Script, require_ready: bool = false) -> Object:
	var instance: Object = _get_local_registered_instance(_utility_registry, script_cls)
	if instance != null:
		return instance if not require_ready or _is_module_ready_for_lookup(instance) else null
	if _parent_architecture != null and not strict_dependency_lookup and not _has_assignable_instance(_utility_registry, script_cls):
		return _parent_architecture.get_utility(script_cls, require_ready)
	if strict_dependency_lookup:
		_report_strict_lookup_miss(script_cls, "Utility")
	return null


## 仅从当前架构获取 System，不回退父级架构。
## [br]
## @api public
## [br]
## @param script_cls: 脚本类。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 当前架构中的系统实例，如果未找到则返回 null。
func get_local_system(script_cls: Script, require_ready: bool = false) -> Object:
	var instance: Object = _get_local_registered_instance(_system_registry, script_cls)
	return instance if not require_ready or _is_module_ready_for_lookup(instance) else null


## 仅从当前架构获取 Model，不回退父级架构。
## [br]
## @api public
## [br]
## @param script_cls: 脚本类。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 当前架构中的模型实例，如果未找到则返回 null。
func get_local_model(script_cls: Script, require_ready: bool = false) -> Object:
	var instance: Object = _get_local_registered_instance(_model_registry, script_cls)
	return instance if not require_ready or _is_module_ready_for_lookup(instance) else null


## 仅从当前架构获取 Utility，不回退父级架构。
## [br]
## @api public
## [br]
## @param script_cls: 脚本类。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 当前架构中的工具实例，如果未找到则返回 null。
func get_local_utility(script_cls: Script, require_ready: bool = false) -> Object:
	var instance: Object = _get_local_registered_instance(_utility_registry, script_cls)
	return instance if not require_ready or _is_module_ready_for_lookup(instance) else null


## 通过已注册工厂创建短生命周期对象。
## [br]
## @api public
## [br]
## @param script_cls: 要创建的脚本类型。
## [br]
## @return 新对象实例；没有工厂或工厂返回非对象时返回 null。
func create_instance(script_cls: Script) -> Object:
	if script_cls == null:
		push_error("[GFArchitecture] create_instance 失败：脚本类型为空。")
		return null

	return _create_instance_for_requester(script_cls, self)


## 向任意对象注入当前架构依赖。
## [br]
## @api public
## [br]
## @param instance: 需要注入的对象。
func inject_object(instance: Object) -> void:
	_inject_dependencies_if_needed(instance)


## 递归向节点树中实现注入 Hook 的节点注入当前架构。
## [br]
## @api public
## [br]
## @param node: 节点树根节点。
func inject_node_tree(node: Node) -> void:
	if node == null:
		return

	_inject_node_tree(node)


# --- 公共方法（序列化） ---

## 收集所有已注册 Model 的状态快照。
## 遍历所有 Model，调用其 to_dict() 方法，以脚本类的全局类名为键汇聚成一个字典。
## [br]
## @api public
## [br]
## @return 包含所有 Model 状态的字典，可直接用于 JSON 序列化。
## [br]
## @schema return: Dictionary keyed by stable model save key, storing each Model.to_dict() result.
func get_all_models_state() -> Dictionary:
	var state: Dictionary = {}
	for script_cls: Script in _models:
		var model: Object = _get_dictionary_object(_models, script_cls)
		if model.has_method("to_dict"):
			var class_name_key: String = _get_model_key(script_cls, model)
			if class_name_key.is_empty():
				continue
			state[class_name_key] = model.call("to_dict")
	return state


## 从状态字典恢复所有已注册 Model 的数据。
## [br]
## @api public
## [br]
## @param data: 由 get_all_models_state() 返回的状态字典。
## [br]
## @schema data: Dictionary keyed by stable model save key, storing serialized model data.
func restore_all_models_state(data: Dictionary) -> void:
	for script_cls: Script in _models:
		var model: Object = _get_dictionary_object(_models, script_cls)
		var class_name_key: String = _get_model_key(script_cls, model)
		if class_name_key.is_empty():
			continue
		if data.has(class_name_key):
			if model.has_method("from_dict"):
				var _restore_result: Variant = model.call("from_dict", data[class_name_key])


## 获取整个框架的全局快照，包含所有 Model 状态以及可选命令历史记录。
## [br]
## @api public
## [br]
## @return 包含全局快照数据的字典。可直接用于 JSON 序列化。
## [br]
## @schema return: Dictionary with models and optional command_history fields.
func get_global_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	
	# 打包所有的 Model 状态
	snapshot["models"] = get_all_models_state()
	
	# 打包命令操作历史（如果有）
	var history_util: Object = _get_command_history_store()
	if history_util != null:
		snapshot["command_history"] = history_util.call("serialize_full_history")
		
	return snapshot


## 从全局快照中恢复整个框架的状态，包含 Model 状态以及可选命令历史记录。
## 注意：恢复命令历史需要外部传入 CommandBuilder 进行控制反转，因为它涉及到具体的业务命令类实例化。
## [br]
## @api public
## [br]
## @param data: 由 get_global_snapshot() 导出的全局快照字典数据。
## [br]
## @schema data: Dictionary produced by get_global_snapshot().
## [br]
## @param command_builder: 【可选】如果需要恢复历史记录，必须传入用于反序列化具体 Command 实例的 Callable。
func restore_global_snapshot(data: Dictionary, command_builder: Callable = Callable()) -> void:
	if data.has("models"):
		var models_data: Variant = data["models"]
		if typeof(models_data) == TYPE_DICTIONARY:
			restore_all_models_state(_GF_VARIANT_ACCESS_SCRIPT.as_dictionary(models_data))
		else:
			push_warning("[GFArchitecture] restore_global_snapshot：models 必须是 Dictionary，已跳过 Model 恢复。")
		
	if data.has("command_history"):
		var history_util: Object = _get_command_history_store()
		if history_util != null:
			if command_builder.is_valid():
				var history_data: Variant = data["command_history"]
				if typeof(history_data) == TYPE_DICTIONARY and history_util.has_method("deserialize_full_history"):
					history_util.call("deserialize_full_history", history_data, command_builder)
				elif typeof(history_data) == TYPE_ARRAY and history_util.has_method("deserialize_history"):
					history_util.call("deserialize_history", history_data, command_builder)
			else:
				push_warning("[GFArchitecture] restore_global_snapshot：快照包含命令历史数据，但未提供有效的 command_builder，跳过历史恢复。")


## 获取架构模块生命周期诊断快照。
## [br]
## @api public
## [br]
## @return 包含 Model、System、Utility、Factory、Alias 与 Tick 缓存状态的字典。
## [br]
## @schema return: Dictionary containing lifecycle flags, registered module summaries, factory summaries, alias counts, and tick cache counts.
func get_debug_lifecycle_state() -> Dictionary:
	return {
		"inited": _inited,
		"is_initializing": _is_initializing,
		"models": _collect_module_debug_state(_models),
		"systems": _collect_module_debug_state(_systems),
		"utilities": _collect_module_debug_state(_utilities),
		"factories": _collect_factory_debug_state(),
		"aliases": {
			"models": _model_registry.aliases.size(),
			"systems": _system_registry.aliases.size(),
			"utilities": _utility_registry.aliases.size(),
		},
		"tick": {
			"systems": _tick_systems.size(),
			"physics_systems": _physics_systems.size(),
			"utilities": _tick_utilities.size(),
			"physics_utilities": _physics_utilities.size(),
		},
	}


## 获取架构中已注册模块的声明式依赖诊断报告。
## 模块可选择实现 get_required_dependencies() 或 get_required_models/systems/utilities/factories()。
## [br]
## @api public
## [br]
## @param options: 可选参数，支持 include_parent_lookup 与 include_factories。
## [br]
## @schema options: Dictionary with optional bool keys include_parent_lookup and include_factories.
## [br]
## @return 统一诊断报告字典。
## [br]
## @schema return: Dictionary dependency diagnostics report with modules, resolved_dependencies, missing_dependencies, issue counts, and next_action.
func get_dependency_diagnostics(options: Dictionary = {}) -> Dictionary:
	var include_parent_lookup: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_parent_lookup", not strict_dependency_lookup)
	var include_factories: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_factories", true)
	var report: DependencyDiagnosticsReport = DependencyDiagnosticsReport.new("Architecture dependencies")
	var modules: Array[Dictionary] = []
	var resolved_dependencies: Array[Dictionary] = []
	var missing_dependencies: Array[Dictionary] = []

	_collect_registry_dependency_diagnostics(
		"model",
		_model_registry,
		report,
		include_parent_lookup,
		include_factories,
		modules,
		resolved_dependencies,
		missing_dependencies
	)
	_collect_registry_dependency_diagnostics(
		"utility",
		_utility_registry,
		report,
		include_parent_lookup,
		include_factories,
		modules,
		resolved_dependencies,
		missing_dependencies
	)
	_collect_registry_dependency_diagnostics(
		"system",
		_system_registry,
		report,
		include_parent_lookup,
		include_factories,
		modules,
		resolved_dependencies,
		missing_dependencies
	)

	return report.to_dict(
		{
			"module_count": modules.size(),
			"modules": modules,
			"resolved_dependencies": resolved_dependencies,
			"missing_dependencies": missing_dependencies,
			"include_parent_lookup": include_parent_lookup,
			"include_factories": include_factories,
		},
		{
			"include_subject": false,
			"include_metadata": false,
			"include_info_count": false,
			"include_issue_count": false,
			"next_actions": _get_dependency_diagnostics_next_actions(),
			"fallback_action": "Review the first reported architecture dependency issue.",
		}
	)


# --- 可重写钩子 / 虚方法 ---

## 内部初始化回调，子类可重写。
## [br]
## @api protected
func _on_init() -> void:
	pass


## 内部销毁回调，子类可重写。
## [br]
## @api protected
func _on_dispose() -> void:
	pass


# --- 私有/辅助方法 ---

func _collect_registry_dependency_diagnostics(
	module_kind: String,
	module_registry: ModuleRegistry,
	report: DependencyDiagnosticsReport,
	include_parent_lookup: bool,
	include_factories: bool,
	modules: Array[Dictionary],
	resolved_dependencies: Array[Dictionary],
	missing_dependencies: Array[Dictionary]
) -> void:
	for script_cls: Script in module_registry.instances.keys():
		var instance: Object = _get_dictionary_object(module_registry.instances, script_cls)
		var module_key: String = _get_script_debug_key(script_cls, instance)
		var declared_dependencies: Dictionary = _collect_declared_dependencies(
			instance,
			report,
			module_key,
			include_factories
		)
		var module_record: Dictionary = {
			"kind": module_kind,
			"script": module_key,
			"instance": _get_instance_debug_key(instance),
			"dependencies": _dependency_map_to_keys(declared_dependencies),
			"resolved_dependencies": [],
			"missing_dependencies": [],
		}
		_collect_dependency_resolution_records(
			module_kind,
			module_key,
			declared_dependencies,
			report,
			include_parent_lookup,
			include_factories,
			module_record,
			resolved_dependencies,
			missing_dependencies
		)
		modules.append(module_record)


func _collect_declared_dependencies(
	instance: Object,
	report: DependencyDiagnosticsReport,
	module_key: String,
	include_factories: bool
) -> Dictionary:
	var dependencies: Dictionary = _make_dependency_map()
	if instance == null:
		return dependencies

	if instance.has_method(HOOK_GET_REQUIRED_DEPENDENCIES):
		var raw_dependencies: Variant = instance.call(HOOK_GET_REQUIRED_DEPENDENCIES)
		_merge_dependency_dictionary(
			dependencies,
			raw_dependencies,
			report,
			module_key,
			String(HOOK_GET_REQUIRED_DEPENDENCIES),
			include_factories
		)

	_append_dependency_hook_array(
		_get_dependency_script_array(dependencies, "models"),
		instance,
		HOOK_GET_REQUIRED_MODELS,
		report,
		module_key
	)
	_append_dependency_hook_array(
		_get_dependency_script_array(dependencies, "systems"),
		instance,
		HOOK_GET_REQUIRED_SYSTEMS,
		report,
		module_key
	)
	_append_dependency_hook_array(
		_get_dependency_script_array(dependencies, "utilities"),
		instance,
		HOOK_GET_REQUIRED_UTILITIES,
		report,
		module_key
	)
	if include_factories:
		_append_dependency_hook_array(
			_get_dependency_script_array(dependencies, "factories"),
			instance,
			HOOK_GET_REQUIRED_FACTORIES,
			report,
			module_key
		)
	return dependencies


func _collect_dependency_resolution_records(
	module_kind: String,
	module_key: String,
	declared_dependencies: Dictionary,
	report: DependencyDiagnosticsReport,
	include_parent_lookup: bool,
	include_factories: bool,
	module_record: Dictionary,
	resolved_dependencies: Array[Dictionary],
	missing_dependencies: Array[Dictionary]
) -> void:
	for dependency_kind: String in ["models", "systems", "utilities", "factories"]:
		if dependency_kind == "factories" and not include_factories:
			continue

		var dependency_scripts: Array = _get_dependency_script_array(declared_dependencies, dependency_kind)
		for dependency_variant: Variant in dependency_scripts:
			if not dependency_variant is Script:
				continue
			var dependency_script: Script = dependency_variant
			var dependency_record: Dictionary = _make_dependency_diagnostic_record(
				module_kind,
				module_key,
				dependency_kind,
				dependency_script,
				include_parent_lookup,
				include_factories
			)
			if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(dependency_record, "resolved", false):
				var resolved_records: Array = _GF_VARIANT_ACCESS_SCRIPT.as_array(
					_GF_VARIANT_ACCESS_SCRIPT.get_option_value(module_record, "resolved_dependencies")
				)
				resolved_records.append(dependency_record)
				resolved_dependencies.append(dependency_record)
				continue

			var missing_records: Array = _GF_VARIANT_ACCESS_SCRIPT.as_array(
				_GF_VARIANT_ACCESS_SCRIPT.get_option_value(module_record, "missing_dependencies")
			)
			missing_records.append(dependency_record)
			missing_dependencies.append(dependency_record)
			var _missing_issue: Dictionary = report.add_error(
				StringName("missing_%s_dependency" % _dependency_kind_to_singular(dependency_kind)),
				"Architecture module declares a missing %s dependency." % _dependency_kind_to_singular(dependency_kind),
				module_key,
				_get_script_debug_key(dependency_script),
				{
					"module_kind": module_kind,
					"dependency_kind": dependency_kind,
				}
			)


func _make_dependency_diagnostic_record(
	module_kind: String,
	module_key: String,
	dependency_kind: String,
	dependency_script: Script,
	include_parent_lookup: bool,
	include_factories: bool
) -> Dictionary:
	var status: Dictionary = _resolve_dependency_diagnostic_status(
		dependency_kind,
		dependency_script,
		include_parent_lookup,
		include_factories
	)
	return {
		"module_kind": module_kind,
		"module": module_key,
		"kind": dependency_kind,
		"script": _get_script_debug_key(dependency_script),
		"resolved": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(status, "resolved", false),
		"scope": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(status, "scope", "missing"),
		"architecture_depth": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(status, "architecture_depth", -1),
	}


func _resolve_dependency_diagnostic_status(
	dependency_kind: String,
	dependency_script: Script,
	include_parent_lookup: bool,
	include_factories: bool,
	architecture_depth: int = 0
) -> Dictionary:
	if dependency_script == null:
		return {
			"resolved": false,
			"scope": "invalid",
			"architecture_depth": architecture_depth,
		}

	var local_resolved: bool = false
	match dependency_kind:
		"models":
			local_resolved = _get_local_registered_instance(_model_registry, dependency_script) != null
		"systems":
			local_resolved = _get_local_registered_instance(_system_registry, dependency_script) != null
		"utilities":
			local_resolved = _get_local_registered_instance(_utility_registry, dependency_script) != null
		"factories":
			local_resolved = include_factories and _factories.has(dependency_script)

	if local_resolved:
		return {
			"resolved": true,
			"scope": _get_dependency_scope_name(architecture_depth),
			"architecture_depth": architecture_depth,
		}

	if include_parent_lookup and not strict_dependency_lookup and _parent_architecture != null:
		return _parent_architecture._resolve_dependency_diagnostic_status(
			dependency_kind,
			dependency_script,
			include_parent_lookup,
			include_factories,
			architecture_depth + 1
		)

	return {
		"resolved": false,
		"scope": "missing",
		"architecture_depth": architecture_depth,
	}


func _merge_dependency_dictionary(
	dependencies: Dictionary,
	raw_dependencies: Variant,
	report: DependencyDiagnosticsReport,
	module_key: String,
	hook_name: String,
	include_factories: bool
) -> void:
	if raw_dependencies == null:
		return
	if not raw_dependencies is Dictionary:
		var _invalid_return_issue: Dictionary = report.add_warning(
			&"invalid_dependency_hook_return",
			"%s() must return a Dictionary." % hook_name,
			module_key,
			"",
			{ "hook": hook_name }
		)
		return

	var source: Dictionary = raw_dependencies
	for raw_key: Variant in source.keys():
		var dependency_kind: String = _normalize_dependency_kind_key(_GF_VARIANT_ACCESS_SCRIPT.to_text(raw_key))
		if dependency_kind.is_empty():
			var _invalid_kind_issue: Dictionary = report.add_warning(
				&"invalid_dependency_kind",
				"Dependency declaration contains an unknown dependency kind.",
				module_key,
				"",
				{
					"hook": hook_name,
					"dependency_kind": _GF_VARIANT_ACCESS_SCRIPT.to_text(raw_key),
				}
			)
			continue
		if dependency_kind == "factories" and not include_factories:
			continue
		_append_dependency_items(
			_get_dependency_script_array(dependencies, dependency_kind),
			source[raw_key],
			report,
			module_key,
			hook_name
		)


func _get_dependency_script_array(dependencies: Dictionary, dependency_kind: String) -> Array:
	var raw_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(dependencies, dependency_kind, [])
	if raw_value is Array:
		var dependency_scripts: Array = raw_value
		return dependency_scripts
	return []


func _append_dependency_hook_array(
	target: Array,
	instance: Object,
	hook_name: StringName,
	report: DependencyDiagnosticsReport,
	module_key: String
) -> void:
	if instance == null or not instance.has_method(hook_name):
		return

	var raw_value: Variant = instance.call(hook_name)
	_append_dependency_items(target, raw_value, report, module_key, String(hook_name))


func _append_dependency_items(
	target: Array,
	raw_value: Variant,
	report: DependencyDiagnosticsReport,
	module_key: String,
	hook_name: String
) -> void:
	if raw_value == null:
		return
	if not raw_value is Array:
		var _invalid_return_issue: Dictionary = report.add_warning(
			&"invalid_dependency_hook_return",
			"%s() must return an Array of Script values." % hook_name,
			module_key,
			"",
			{ "hook": hook_name }
		)
		return

	for dependency_variant: Variant in raw_value:
		if dependency_variant is Script:
			var dependency_script: Script = dependency_variant
			_append_unique_script(target, dependency_script)
		elif dependency_variant != null:
			var _invalid_type_issue: Dictionary = report.add_warning(
				&"invalid_dependency_type",
				"Dependency declaration contains a non-Script value.",
				module_key,
				"",
				{
					"hook": hook_name,
					"value": str(dependency_variant),
				}
			)


func _make_dependency_map() -> Dictionary:
	return {
		"models": [],
		"systems": [],
		"utilities": [],
		"factories": [],
	}


func _variant_to_object(value: Variant) -> Object:
	if value is Object:
		var object_value: Object = value
		return object_value
	return null


func _variant_to_binding(value: Variant) -> GFBinding:
	if value is GFBinding:
		var binding: GFBinding = value
		return binding
	return null


func _variant_to_script(value: Variant) -> Script:
	if value is Script:
		var script_value: Script = value
		return script_value
	return null


func _get_dictionary_object(source: Dictionary, field_name: Variant) -> Object:
	return _variant_to_object(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(source, field_name))


func _get_dictionary_binding(source: Dictionary, field_name: Variant) -> GFBinding:
	return _variant_to_binding(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(source, field_name))


func _get_dictionary_script(source: Dictionary, field_name: Variant) -> Script:
	return _variant_to_script(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(source, field_name))


func _get_object_int_property(instance: Object, property_name: StringName, default_value: int) -> int:
	return _GF_VARIANT_ACCESS_SCRIPT.to_int(_get_object_property(instance, property_name, default_value), default_value)


func _get_object_bool_property(instance: Object, property_name: StringName, default_value: bool = false) -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.to_bool(_get_object_property(instance, property_name, default_value), default_value)


func _get_object_property(instance: Object, property_name: StringName, default_value: Variant = null) -> Variant:
	if instance == null:
		return default_value
	if not String(property_name) in instance:
		return default_value
	return instance.get_indexed(NodePath(String(property_name)))


func _get_instance_script(instance: Object) -> Script:
	if instance == null:
		return null
	var raw_script: Variant = instance.get_script()
	return _variant_to_script(raw_script)


func _get_scene_tree_or_null() -> SceneTree:
	var main_loop: Variant = Engine.get_main_loop()
	if main_loop is SceneTree:
		var scene_tree: SceneTree = main_loop
		return scene_tree
	return null


func _dependency_map_to_keys(dependencies: Dictionary) -> Dictionary:
	return {
		"models": _script_array_to_debug_keys(_get_dependency_script_array(dependencies, "models")),
		"systems": _script_array_to_debug_keys(_get_dependency_script_array(dependencies, "systems")),
		"utilities": _script_array_to_debug_keys(_get_dependency_script_array(dependencies, "utilities")),
		"factories": _script_array_to_debug_keys(_get_dependency_script_array(dependencies, "factories")),
	}


func _script_array_to_debug_keys(scripts: Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for script_variant: Variant in scripts:
		if not script_variant is Script:
			continue
		var script: Script = script_variant
		_append_packed_string(result, _get_script_debug_key(script))
	result.sort()
	return result


func _append_unique_script(target: Array, script: Script) -> void:
	if script != null and not target.has(script):
		target.append(script)


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var _added: bool = target.append(value)


func _call_module_void(instance: Object, method_name: StringName, arguments: Array = []) -> void:
	if instance == null or not instance.has_method(method_name):
		return
	var _result: Variant = instance.callv(method_name, arguments)


func _normalize_dependency_kind_key(key: String) -> String:
	match key.to_lower():
		"model", "models":
			return "models"
		"system", "systems":
			return "systems"
		"utility", "utilities":
			return "utilities"
		"factory", "factories":
			return "factories"
		_:
			return ""


func _dependency_kind_to_singular(dependency_kind: String) -> String:
	match dependency_kind:
		"models":
			return "model"
		"systems":
			return "system"
		"utilities":
			return "utility"
		"factories":
			return "factory"
		_:
			return "dependency"


func _get_dependency_scope_name(architecture_depth: int) -> String:
	if architecture_depth <= 0:
		return "local"
	if architecture_depth == 1:
		return "parent"
	return "ancestor"


func _get_dependency_diagnostics_next_actions() -> Dictionary:
	return {
		"missing_model_dependency": "Register the required Model locally or in an allowed parent architecture.",
		"missing_system_dependency": "Register the required System locally or in an allowed parent architecture.",
		"missing_utility_dependency": "Register the required Utility locally or in an allowed parent architecture.",
		"missing_factory_dependency": "Register the required factory before the dependent module requests it.",
		"invalid_dependency_hook_return": "Return a Dictionary or Array shape that matches the dependency hook contract.",
		"invalid_dependency_type": "Declared dependencies should contain only Script values.",
		"invalid_dependency_kind": "Use models, systems, utilities, or factories for dependency declaration keys.",
	}


func _reset_project_installers() -> void:
	var was_running: bool = _project_installers_running
	_project_installers_applied = false
	_project_installers_running = false
	if was_running:
		project_installers_finished.emit()


func _assign_parent_architecture(parent_architecture: GFArchitecture, context: String) -> void:
	if parent_architecture == null:
		_parent_architecture = null
		return
	if parent_architecture == self:
		push_error("[GFArchitecture] %s 失败：父级架构不能是自身。" % context)
		return
	if _parent_chain_contains(parent_architecture, self):
		push_error("[GFArchitecture] %s 失败：父级架构会形成循环引用。" % context)
		return
	_parent_architecture = parent_architecture


func _parent_chain_contains(parent_architecture: GFArchitecture, expected: GFArchitecture) -> bool:
	var visited: Dictionary = {}
	var current: GFArchitecture = parent_architecture
	while current != null:
		if current == expected:
			return true
		var instance_id: int = current.get_instance_id()
		if visited.has(instance_id):
			return false
		visited[instance_id] = true
		current = current.get_parent_architecture()
	return false


# 获取经过时间工具缩放后的 delta。若未注册 GFTimeProvider，则返回原始 delta。
func _get_scaled_delta(delta: float, time_provider: Object) -> float:
	if time_provider == null:
		return delta
	return _GF_VARIANT_ACCESS_SCRIPT.to_float(time_provider.call("get_scaled_delta", delta), delta)


func _drive_physics_tick_step(raw_delta: float, scaled_delta: float, time_provider: Object) -> void:
	_is_iterating_tick_caches = true
	for system: Object in _physics_systems:
		if is_instance_valid(system) and _is_module_ready_for_tick(system):
			_call_module_void(system, &"physics_tick", [_get_module_delta(system, raw_delta, scaled_delta, time_provider)])
	for utility: Object in _physics_utilities:
		if is_instance_valid(utility) and _is_module_ready_for_tick(utility):
			_call_module_void(utility, &"physics_tick", [_get_module_delta(utility, raw_delta, scaled_delta, time_provider)])
	_is_iterating_tick_caches = false
	_flush_tick_cache_refresh()


# 根据模块的 ignore_pause 设置获取本次 tick 应使用的 delta。
func _get_module_delta(instance: Object, raw_delta: float, scaled_delta: float, time_provider: Object) -> float:
	if time_provider == null:
		return raw_delta

	var ignores_pause: bool = _get_object_bool_property(instance, &"ignore_pause")
	var ignores_time_scale: bool = _get_object_bool_property(instance, &"ignore_time_scale")
	if _GF_VARIANT_ACCESS_SCRIPT.to_bool(time_provider.call("is_time_paused")):
		return raw_delta if ignores_pause else 0.0

	if ignores_time_scale:
		return raw_delta
	return scaled_delta


func _get_modules_by_lifecycle_priority(registry: Dictionary, reverse: bool = false) -> Array[Object]:
	var entries: Array[Dictionary] = []
	var order: int = 0
	for instance: Object in registry.values():
		entries.append({
			"instance": instance,
			"priority": _get_module_priority(instance, &"lifecycle_priority"),
			"order": order,
		})
		order += 1

	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_priority: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(left, "priority", 0)
		var right_priority: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(right, "priority", 0)
		if left_priority == right_priority:
			var left_order: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(left, "order", 0)
			var right_order: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(right, "order", 0)
			return left_order > right_order if reverse else left_order < right_order
		return left_priority < right_priority if reverse else left_priority > right_priority
	)

	var result: Array[Object] = []
	for entry: Dictionary in entries:
		var instance: Object = _get_dictionary_object(entry, "instance")
		if instance != null:
			result.append(instance)
	return result


func _sort_modules_for_tick(modules: Array[Object], priority_property: StringName) -> void:
	var entries: Array[Dictionary] = []
	for index: int in range(modules.size()):
		var instance: Object = modules[index]
		entries.append({
			"instance": instance,
			"priority": _get_module_priority(instance, priority_property),
			"order": index,
		})

	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_priority: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(left, "priority", 0)
		var right_priority: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(right, "priority", 0)
		if left_priority == right_priority:
			return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(left, "order", 0) < _GF_VARIANT_ACCESS_SCRIPT.get_option_int(right, "order", 0)
		return left_priority > right_priority
	)

	modules.clear()
	for entry: Dictionary in entries:
		var instance: Object = _get_dictionary_object(entry, "instance")
		if instance != null:
			modules.append(instance)


func _get_module_priority(instance: Object, property_name: StringName) -> int:
	if instance == null:
		return 0
	if String(property_name) in instance:
		return _get_object_int_property(instance, property_name, 0)
	return 0


func _collect_module_debug_state(registry: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for script_cls: Script in registry.keys():
		var instance: Object = _get_dictionary_object(registry, script_cls)
		var stage: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_module_lifecycle_stages, instance, 0)
		var ignores_pause: bool = (
			instance != null
			and _get_object_bool_property(instance, &"ignore_pause")
		)
		var ignores_time_scale: bool = (
			instance != null
			and _get_object_bool_property(instance, &"ignore_time_scale")
		)
		result[_get_script_debug_key(script_cls, instance)] = {
			"stage": stage,
			"stage_name": _get_lifecycle_stage_name(stage),
			"ready": stage >= 3,
			"has_tick": _module_participates_in_tick(instance, &"tick", &"tick_enabled"),
			"has_physics_tick": _module_participates_in_tick(instance, &"physics_tick", &"physics_tick_enabled"),
			"ignore_pause": ignores_pause,
			"ignore_time_scale": ignores_time_scale,
			"tick_enabled": _get_module_bool(instance, &"tick_enabled"),
			"physics_tick_enabled": _get_module_bool(instance, &"physics_tick_enabled"),
			"lifecycle_priority": _get_module_priority(instance, &"lifecycle_priority"),
			"tick_priority": _get_module_priority(instance, &"tick_priority"),
			"physics_tick_priority": _get_module_priority(instance, &"physics_tick_priority"),
		}
	return result


func _clear_factory_binding(script_cls: Script) -> void:
	if script_cls == null or not _factories.has(script_cls):
		return

	var binding: GFBinding = _get_dictionary_binding(_factories, script_cls)
	if binding != null:
		binding.dispose_cached_instance()


func _clear_failed_initialization_state() -> void:
	_dispose_module_registry(_system_registry)
	_dispose_module_registry(_model_registry)
	_dispose_module_registry(_utility_registry)
	for binding_variant: Variant in _factories.values():
		var binding: GFBinding = _variant_to_binding(binding_variant)
		if binding != null:
			binding.dispose_cached_instance()

	_model_registry._clear()
	_system_registry._clear()
	_utility_registry._clear()
	_factories.clear()
	_module_lifecycle_stages.clear()
	_event_system.clear()
	_time_provider = null
	_refresh_tick_caches()


func _collect_factory_debug_state() -> Dictionary:
	var result: Dictionary = {}
	for script_cls: Script in _factories.keys():
		var binding: Object = _get_dictionary_object(_factories, script_cls)
		var lifetime: int = -1
		if binding != null and "lifetime" in binding:
			lifetime = _get_object_int_property(binding, &"lifetime", -1)
		result[_get_script_debug_key(script_cls)] = {
			"lifetime": lifetime,
			"lifetime_name": _get_binding_lifetime_name(lifetime),
			"valid": binding != null,
		}
	return result


func _get_lifecycle_stage_name(stage: int) -> String:
	match stage:
		0:
			return "registered"
		1:
			return "init"
		2:
			return "async_init"
		3:
			return "ready"
		_:
			return "unknown"


func _get_binding_lifetime_name(lifetime: int) -> String:
	match lifetime:
		GFBindingLifetimesBase.Lifetime.TRANSIENT:
			return "transient"
		GFBindingLifetimesBase.Lifetime.SINGLETON:
			return "singleton"
		_:
			return "unknown"


func _validate_factory_lifetime(lifetime: int, context: String) -> bool:
	if (
		lifetime == GFBindingLifetimesBase.Lifetime.TRANSIENT
		or lifetime == GFBindingLifetimesBase.Lifetime.SINGLETON
	):
		return true

	push_error("[GFArchitecture] %s 失败：未知工厂生命周期：%s。" % [context, str(lifetime)])
	return false


func _get_script_debug_key(script_cls: Script, instance: Object = null) -> String:
	if script_cls != null:
		var global_name: StringName = script_cls.get_global_name()
		if global_name != &"":
			return String(global_name)
		if not script_cls.resource_path.is_empty():
			return script_cls.resource_path
	if instance != null:
		var instance_script: Script = _get_instance_script(instance)
		if instance_script != null and not instance_script.resource_path.is_empty():
			return instance_script.resource_path
		return "Instance:%d" % instance.get_instance_id()
	return ""


func _get_instance_debug_key(instance: Object) -> String:
	if instance == null:
		return "null"
	var script: Script = _get_instance_script(instance)
	if script != null:
		return _get_script_debug_key(script, instance)
	return "Instance:%d" % instance.get_instance_id()


# 从脚本类获取用于序列化的稳定字符串键。
# 优先使用 Model.get_save_key()，其次使用 class_name（全局类名），最后回退到资源路径。
func _get_model_key(script_cls: Script, model: Object = null) -> String:
	if model != null and model.has_method("get_save_key"):
		var raw_save_key: Variant = model.call("get_save_key")
		if typeof(raw_save_key) == TYPE_STRING or typeof(raw_save_key) == TYPE_STRING_NAME:
			var save_key: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(raw_save_key)
			if not save_key.is_empty():
				return save_key

	var global_name: StringName = script_cls.get_global_name()
	if global_name != &"":
		return String(global_name)
	if not script_cls.resource_path.is_empty():
		return script_cls.resource_path
	push_error("[GFArchitecture] 可序列化 Model 缺少稳定标识：请为脚本声明 class_name 或提供可用的资源路径。")
	return ""


func _initialize_registered_module(module_registry: ModuleRegistry, instance: Object) -> void:
	if instance == null:
		return
	var current_serial: int = _lifecycle_serial
	await _advance_module_to_stage(module_registry, instance, 3, current_serial)


func _create_instance_for_requester(script_cls: Script, requesting_architecture: GFArchitecture) -> Object:
	if _factories.has(script_cls):
		var binding: GFBinding = _get_dictionary_binding(_factories, script_cls)
		if binding == null:
			push_error("[GFArchitecture] create_instance 失败：工厂绑定无效。")
			return null
		return binding.get_instance(requesting_architecture)

	if _parent_architecture != null and not strict_dependency_lookup:
		return _parent_architecture._create_instance_for_requester(script_cls, requesting_architecture)

	if strict_dependency_lookup:
		push_error("[GFArchitecture] strict_dependency_lookup：当前架构未注册工厂：%s" % script_cls.resource_path)
	else:
		push_error("[GFArchitecture] create_instance 失败：未注册工厂。")
	return null


func _advance_all_modules_to_stage(target_stage: int, lifecycle_serial: int) -> void:
	var pass_count: int = 0
	while true:
		if not _is_lifecycle_current(lifecycle_serial) or _initialization_failed:
			return
		if pass_count >= module_lifecycle_max_stage_passes:
			_fail_initialization(
				"[GFArchitecture] 生命周期阶段推进超过上限：stage=%d, max_passes=%d。" % [
					target_stage,
					module_lifecycle_max_stage_passes,
				],
				lifecycle_serial
			)
			return

		var progressed: bool = false
		if await _advance_module_registry_to_stage(_model_registry, target_stage, lifecycle_serial):
			progressed = true
		if await _advance_module_registry_to_stage(_utility_registry, target_stage, lifecycle_serial):
			progressed = true
		if await _advance_module_registry_to_stage(_system_registry, target_stage, lifecycle_serial):
			progressed = true
		if not progressed:
			return
		pass_count += 1


func _advance_module_registry_to_stage(module_registry: ModuleRegistry, target_stage: int, lifecycle_serial: int) -> bool:
	var progressed: bool = false
	for instance: Object in _get_modules_by_lifecycle_priority(module_registry.instances):
		if not _is_lifecycle_current(lifecycle_serial) or _initialization_failed:
			return progressed
		if not _module_registry_contains_instance(module_registry, instance):
			continue

		var current_stage: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_module_lifecycle_stages, instance, 0)
		if current_stage < target_stage:
			var advanced: bool = await _advance_module_to_stage(module_registry, instance, target_stage, lifecycle_serial)
			if advanced:
				progressed = true
	return progressed


func _advance_module_to_stage(
	module_registry: ModuleRegistry,
	instance: Object,
	target_stage: int,
	lifecycle_serial: int
) -> bool:
	if instance == null:
		return false

	var current_stage: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_module_lifecycle_stages, instance, 0)
	var advanced: bool = false
	while current_stage < target_stage:
		if not _is_lifecycle_current(lifecycle_serial) or _initialization_failed:
			return advanced
		if not _module_registry_contains_instance(module_registry, instance):
			return advanced

		current_stage += 1
		match current_stage:
			1:
				if instance.has_method("init"):
					_call_module_void(instance, &"init")
			2:
				if instance.has_method("async_init"):
					var async_completed: bool = await _await_module_async_init(instance, lifecycle_serial)
					if not async_completed:
						return advanced
			3:
				if instance.has_method("ready"):
					_call_module_void(instance, &"ready")

		if not _is_lifecycle_current(lifecycle_serial) or _initialization_failed:
			return advanced
		if not _module_registry_contains_instance(module_registry, instance):
			return advanced

		_module_lifecycle_stages[instance] = current_stage
		advanced = true
	return advanced


func _await_module_async_init(instance: Object, lifecycle_serial: int) -> bool:
	if module_async_init_timeout_seconds <= 0.0:
		await instance.call("async_init")
		return _is_lifecycle_current(lifecycle_serial) and not _initialization_failed

	var scene_tree: SceneTree = _get_scene_tree_or_null()
	if scene_tree == null:
		await instance.call("async_init")
		return _is_lifecycle_current(lifecycle_serial) and not _initialization_failed

	var completion_state: Dictionary = {
		"done": false,
		"write_blocked": false,
	}
	_GF_ASYNC_CALL_SCRIPT.run_detached(Callable(self, &"_complete_module_async_init"), [instance, completion_state])
	var start_msec: int = Time.get_ticks_msec()
	var timeout_msec: int = int(module_async_init_timeout_seconds * 1000.0)
	while not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(completion_state, "done", false):
		if not _is_lifecycle_current(lifecycle_serial) or _initialization_failed:
			return false
		var elapsed_msec: int = Time.get_ticks_msec() - start_msec
		if elapsed_msec >= timeout_msec:
			completion_state["write_blocked"] = true
			_begin_stale_async_write_block()
			_fail_initialization(
				"[GFArchitecture] async_init 超时：%s 超过 %.2f 秒。" % [
					_get_instance_debug_key(instance),
					module_async_init_timeout_seconds,
				],
				lifecycle_serial
			)
			return false
		await scene_tree.process_frame
	return _is_lifecycle_current(lifecycle_serial) and not _initialization_failed


func _complete_module_async_init(instance: Object, completion_state: Dictionary) -> void:
	await instance.call("async_init")
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(completion_state, "write_blocked", false):
		_end_stale_async_write_block()
	completion_state["done"] = true


func _dispose_module_registry(module_registry: ModuleRegistry) -> void:
	for instance: Object in _get_modules_by_lifecycle_priority(module_registry.instances, true):
		if instance.has_method("dispose"):
			_call_module_void(instance, &"dispose")
		_clear_injected_scope(instance)


func _fail_initialization(reason: String, lifecycle_serial: int) -> void:
	if _initialization_failed or not _is_lifecycle_current(lifecycle_serial):
		return

	_initialization_failed = true
	last_initialization_error = reason
	_lifecycle_serial += 1
	_is_initializing = false
	_inited = false
	_stop_project_installers_after_failure()
	_clear_failed_initialization_state()
	push_error(reason)
	initialization_failed.emit(reason)
	initialization_finished.emit()


func _track_registered_module(instance: Object) -> void:
	if instance == null:
		return
	if not _module_lifecycle_stages.has(instance):
		_module_lifecycle_stages[instance] = 0


func _module_registry_contains_instance(module_registry: ModuleRegistry, instance: Object) -> bool:
	if instance == null:
		return false
	for registered_instance: Object in module_registry.instances.values():
		if registered_instance == instance:
			return true
	return false


func _register_module(module_registry: ModuleRegistry, script_cls: Script, instance: Object) -> bool:
	if not _can_mutate_registration_state("register_%s" % module_registry._label_key()):
		return false
	if not _validate_registration(script_cls, instance, module_registry.label):
		return false
	if module_registry._has_direct(script_cls):
		var method_name: String = "register_%s" % module_registry._label_key()
		var replacement_name: String = "replace_%s" % module_registry._label_key()
		push_warning("[GFArchitecture] %s：类型已注册，已忽略重复注册。启用扩展的 Installer 会先于项目 Installer 自动装配其模块；项目通常只注册自身模块。若需要替换，请使用 %s()。" % [
			method_name,
			replacement_name,
		])
		return false

	_inject_dependencies_if_needed(instance)
	module_registry.instances[script_cls] = instance
	module_registry._clear_assignable_cache()
	_track_registered_module(instance)
	return true


func _can_mutate_registration_state(context: String) -> bool:
	if _initialization_failed:
		push_error("[GFArchitecture] %s 失败：架构初始化已失败，已拒绝迟到写入。" % context)
		return false
	if _stale_async_write_block_count > 0:
		push_error("[GFArchitecture] %s 失败：架构存在已超时的异步流程尚未结束，已拒绝迟到写入。" % context)
		return false
	return true


func _begin_stale_async_write_block() -> void:
	_stale_async_write_block_count += 1


func _end_stale_async_write_block() -> void:
	_stale_async_write_block_count = maxi(_stale_async_write_block_count - 1, 0)


func _unregister_module(module_registry: ModuleRegistry, script_cls: Script) -> bool:
	var registered_key: Script = _resolve_registered_key(module_registry, script_cls)
	if registered_key != null and module_registry._has_direct(registered_key):
		var instance: Object = _get_dictionary_object(module_registry.instances, registered_key)
		if instance != null and instance.has_method("dispose"):
			_call_module_void(instance, &"dispose")
		if instance != null:
			_event_system.unregister_owner(instance)
			_clear_injected_scope(instance)
		var _removed_stage: bool = _module_lifecycle_stages.erase(instance)
		var _removed_instance: bool = module_registry.instances.erase(registered_key)
		_remove_aliases_for(module_registry, registered_key)
		module_registry._clear_assignable_cache()
		return true

	var _removed_alias: bool = module_registry.aliases.erase(script_cls)
	module_registry._clear_assignable_cache()
	return false


func _inject_dependencies_if_needed(instance: Object) -> void:
	if instance != null and instance.has_method("_gf_set_dependency_scope"):
		instance.call("_gf_set_dependency_scope", self)
	if instance != null and instance.has_method("inject_dependencies"):
		var _inject_dependencies_result: Variant = instance.call("inject_dependencies", self)
	if instance != null and instance.has_method("inject"):
		var _inject_result: Variant = instance.call("inject", self)


func _clear_injected_scope(instance: Object) -> void:
	if instance != null and instance.has_method("_gf_set_dependency_scope"):
		instance.call("_gf_set_dependency_scope", null)
	elif instance != null and instance.has_method("_release_dependency_scope"):
		instance.call("_release_dependency_scope")


func _stop_project_installers_after_failure() -> void:
	var was_running: bool = _project_installers_running
	_project_installers_running = false
	if was_running:
		project_installers_finished.emit()


func _inject_node_tree(node: Node) -> void:
	_inject_dependencies_if_needed(node)
	for child: Node in node.get_children(true):
		_inject_node_tree(child)


func _validate_registration(script_cls: Script, instance: Object, label: String) -> bool:
	if script_cls == null:
		push_error("[GFArchitecture] register_%s 失败：脚本类型为空。" % label.to_lower())
		return false
	if instance == null:
		push_error("[GFArchitecture] register_%s 失败：实例为空。" % label.to_lower())
		return false
	if not _instance_matches_registration_label(instance, label):
		push_error("[GFArchitecture] register_%s 失败：实例类型必须继承 GF%s。" % [label.to_lower(), label])
		return false

	var instance_script: Script = _get_instance_script(instance)
	if instance_script == null:
		push_error("[GFArchitecture] register_%s 失败：实例未附加脚本。" % label.to_lower())
		return false
	if not GFScriptTypeInspector.script_extends_or_equals(instance_script, script_cls):
		push_error("[GFArchitecture] register_%s 失败：实例脚本必须继承或等于注册脚本类型。" % label.to_lower())
		return false

	return true


func _get_instance_script_or_null(instance: Object, context: String) -> Script:
	if instance == null:
		push_error("[GFArchitecture] %s 失败：实例为空。" % context)
		return null

	var script: Script = _get_instance_script(instance)
	if script == null:
		push_error("[GFArchitecture] %s 失败：实例未附加脚本。" % context)
		return null

	return script


func _instance_matches_registration_label(instance: Object, label: String) -> bool:
	match label:
		"Model":
			return instance is GFModel

		"System":
			return instance is GFSystem

		"Utility":
			return instance is GFUtility

		_:
			return true


func _refresh_cached_utility_refs() -> void:
	_time_provider = _get_local_registered_instance(_utility_registry, GFTimeProviderBase)


func _get_time_provider() -> Object:
	if _time_provider == null:
		_refresh_cached_utility_refs()
	if _time_provider != null:
		return _time_provider
	if _parent_architecture != null and not strict_dependency_lookup:
		return _parent_architecture._get_time_provider()
	return null


func _get_command_history_store() -> Object:
	var history_store: Object = _find_local_utility_with_methods(PackedStringArray([
		"serialize_full_history",
	]))
	if history_store != null:
		return history_store
	if _parent_architecture != null and not strict_dependency_lookup:
		return _parent_architecture._get_command_history_store()
	return null


func _find_local_utility_with_methods(method_names: PackedStringArray) -> Object:
	for utility: Object in _utilities.values():
		if _object_has_methods(utility, method_names):
			return utility
	return null


func _object_has_methods(instance: Object, method_names: PackedStringArray) -> bool:
	if instance == null:
		return false
	for method_name: String in method_names:
		if not instance.has_method(method_name):
			return false
	return true


func _refresh_tick_caches() -> void:
	if _is_iterating_tick_caches:
		_tick_caches_dirty = true
		return

	_rebuild_tick_caches()


func _rebuild_tick_caches() -> void:
	_tick_systems.clear()
	_physics_systems.clear()
	_tick_utilities.clear()
	_physics_utilities.clear()
	_tick_caches_dirty = false

	for system: Object in _systems.values():
		if _module_participates_in_tick(system, &"tick", &"tick_enabled"):
			_tick_systems.append(system)
		if _module_participates_in_tick(system, &"physics_tick", &"physics_tick_enabled"):
			_physics_systems.append(system)

	for utility: Object in _utilities.values():
		if _module_participates_in_tick(utility, &"tick", &"tick_enabled"):
			_tick_utilities.append(utility)
		if _module_participates_in_tick(utility, &"physics_tick", &"physics_tick_enabled"):
			_physics_utilities.append(utility)

	_sort_modules_for_tick(_tick_systems, &"tick_priority")
	_sort_modules_for_tick(_physics_systems, &"physics_tick_priority")
	_sort_modules_for_tick(_tick_utilities, &"tick_priority")
	_sort_modules_for_tick(_physics_utilities, &"physics_tick_priority")


func _flush_tick_cache_refresh() -> void:
	if _tick_caches_dirty:
		_rebuild_tick_caches()


func _is_lifecycle_current(lifecycle_serial: int) -> bool:
	return _lifecycle_serial == lifecycle_serial


func _is_module_ready_for_tick(instance: Object) -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_module_lifecycle_stages, instance, 0) >= 3


func _is_module_ready_for_lookup(instance: Object) -> bool:
	return (
		instance != null
		and _inited
		and not _initialization_failed
		and _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_module_lifecycle_stages, instance, 0) >= 3
	)


func _module_participates_in_tick(instance: Object, method_name: StringName, explicit_property: StringName) -> bool:
	if instance == null:
		return false
	if not instance.has_method(method_name):
		return false
	if _get_module_bool(instance, explicit_property):
		return true
	if _script_chain_declares_method_before_framework_base(instance, method_name):
		return true
	return not (instance is GFSystem or instance is GFUtility)


func _get_module_bool(instance: Object, property_name: StringName) -> bool:
	if instance == null:
		return false
	if String(property_name) in instance:
		return _get_object_bool_property(instance, property_name)
	return false


func _script_chain_declares_method_before_framework_base(instance: Object, method_name: StringName) -> bool:
	var script: Script = _get_instance_script(instance)
	var framework_method_count: int = _get_framework_module_method_count(instance, method_name)
	while script != null:
		if _is_framework_module_base_script(script):
			return false
		if _count_script_methods(script, method_name) > framework_method_count:
			return true
		script = script.get_base_script()
	return false


func _is_framework_module_base_script(script: Script) -> bool:
	return script == GFSystem or script == GFUtility


func _get_framework_module_method_count(instance: Object, method_name: StringName) -> int:
	if instance is GFSystem:
		return _count_script_methods(GFSystem, method_name)
	if instance is GFUtility:
		return _count_script_methods(GFUtility, method_name)
	return 0


func _count_script_methods(script: Script, method_name: StringName) -> int:
	var count: int = 0
	for method: Dictionary in script.get_script_method_list():
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(method, "name", "") == String(method_name):
			count += 1
	return count


func _register_module_alias(module_registry: ModuleRegistry, alias_cls: Script, target_cls: Script) -> void:
	if not _can_mutate_registration_state("register_%s_alias" % module_registry._label_key()):
		return
	if alias_cls == null or target_cls == null:
		push_error("[GFArchitecture] register_%s_alias 失败：alias 或 target 为空。" % module_registry._label_key())
		return
	if not GFScriptTypeInspector.script_extends_or_equals(target_cls, alias_cls):
		push_error("[GFArchitecture] register_%s_alias 失败：target 必须继承或等于 alias。" % module_registry._label_key())
		return
	if not module_registry._has_direct(target_cls):
		push_warning("[GFArchitecture] register_%s_alias：目标类型尚未注册，仍会记录别名。" % module_registry._label_key())
	module_registry.aliases[alias_cls] = target_cls
	module_registry._clear_assignable_cache()


func _resolve_registered_key(module_registry: ModuleRegistry, script_cls: Script) -> Script:
	if script_cls == null:
		return null
	if module_registry._has_direct(script_cls):
		return script_cls
	if module_registry.aliases.has(script_cls):
		var target_cls: Script = _get_dictionary_script(module_registry.aliases, script_cls)
		if target_cls != null and module_registry._has_direct(target_cls):
			return target_cls
	return null


func _get_local_registered_instance(module_registry: ModuleRegistry, script_cls: Script) -> Object:
	var registered_key: Script = _resolve_registered_key(module_registry, script_cls)
	if registered_key != null:
		return _get_dictionary_object(module_registry.instances, registered_key)
	registered_key = _resolve_assignable_cached_key(module_registry, script_cls)
	if registered_key != null:
		return _get_dictionary_object(module_registry.instances, registered_key)
	registered_key = _find_assignable_registered_key(module_registry, script_cls)
	if registered_key != null:
		module_registry.assignable_cache[script_cls] = registered_key
		return _get_dictionary_object(module_registry.instances, registered_key)
	return null


func _report_strict_lookup_miss(script_cls: Script, label: String) -> void:
	push_error("[GFArchitecture] strict_dependency_lookup：当前架构未注册 %s：%s" % [
		label,
		_get_script_debug_key(script_cls),
	])


func _remove_aliases_for(module_registry: ModuleRegistry, registered_key: Script) -> void:
	var keys_to_remove: Array = []
	for alias_cls: Script in module_registry.aliases:
		if module_registry.aliases[alias_cls] == registered_key:
			keys_to_remove.append(alias_cls)
	for alias_cls: Script in keys_to_remove:
		var _removed_alias: bool = module_registry.aliases.erase(alias_cls)


func _resolve_assignable_cached_key(module_registry: ModuleRegistry, script_cls: Script) -> Script:
	if script_cls == null or not module_registry.assignable_cache.has(script_cls):
		return null
	var cached_key: Script = _get_dictionary_script(module_registry.assignable_cache, script_cls)
	if cached_key != null and module_registry._has_direct(cached_key):
		return cached_key
	var _removed_cached_key: bool = module_registry.assignable_cache.erase(script_cls)
	return null


func _find_assignable_registered_key(module_registry: ModuleRegistry, script_cls: Script) -> Script:
	if script_cls == null:
		return null
	var matches: Array[Script] = []
	for registered_script: Script in module_registry.instances:
		if GFScriptTypeInspector.script_extends_or_equals(registered_script, script_cls):
			matches.append(registered_script)
	if matches.size() == 1:
		return matches[0]
	if matches.size() > 1:
		push_warning("[GFArchitecture] get_%s(%s) 匹配到多个本地实例，本次查询不会回退父架构；请使用显式 alias 注册以消除歧义。" % [
			module_registry._label_key(),
			script_cls.resource_path,
		])
	return null


func _has_assignable_instance(module_registry: ModuleRegistry, script_cls: Script) -> bool:
	if script_cls == null:
		return false
	for registered_script: Script in module_registry.instances:
		if GFScriptTypeInspector.script_extends_or_equals(registered_script, script_cls):
			return true
	return false


# --- 内部类 ---

## DependencyDiagnosticsReport: 架构依赖诊断报告构建器。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
class DependencyDiagnosticsReport:
	extends RefCounted

	const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

	## 诊断报告主体名称。
	## [br]
	## @api framework_internal
	var subject: String = ""

	## 诊断条目列表。
	## [br]
	## @api framework_internal
	## [br]
	## @schema issues: Array of Dictionary dependency diagnostic entries.
	var issues: Array[Dictionary] = []

	func _init(p_subject: String = "") -> void:
		subject = p_subject

	## 添加一个 warning 级别的依赖诊断条目。
	## [br]
	## @api framework_internal
	## [br]
	## @param kind: 诊断类型。
	## [br]
	## @param message: 面向维护者的诊断说明。
	## [br]
	## @param key: 可选的关联键，例如脚本类、别名或设置名。
	## [br]
	## @schema key: Variant diagnostic key stored unchanged when present.
	## [br]
	## @param path: 可选的关联资源路径。
	## [br]
	## @param metadata: 可选的附加诊断数据。
	## [br]
	## @schema metadata: Dictionary copied into the metadata field when not empty.
	## [br]
	## @return 新增的诊断条目。
	## [br]
	## @schema return: Dictionary issue entry appended to issues.
	func add_warning(
		kind: StringName,
		message: String,
		key: Variant = null,
		path: String = "",
		metadata: Dictionary = {}
	) -> Dictionary:
		return _add_issue("warning", kind, message, key, path, metadata)

	## 添加一个 error 级别的依赖诊断条目。
	## [br]
	## @api framework_internal
	## [br]
	## @param kind: 诊断类型。
	## [br]
	## @param message: 面向维护者的诊断说明。
	## [br]
	## @param key: 可选的关联键，例如脚本类、别名或设置名。
	## [br]
	## @schema key: Variant diagnostic key stored unchanged when present.
	## [br]
	## @param path: 可选的关联资源路径。
	## [br]
	## @param metadata: 可选的附加诊断数据。
	## [br]
	## @schema metadata: Dictionary copied into the metadata field when not empty.
	## [br]
	## @return 新增的诊断条目。
	## [br]
	## @schema return: Dictionary issue entry appended to issues.
	func add_error(
		kind: StringName,
		message: String,
		key: Variant = null,
		path: String = "",
		metadata: Dictionary = {}
	) -> Dictionary:
		return _add_issue("error", kind, message, key, path, metadata)

	## 汇总诊断条目并转换为可序列化字典。
	## [br]
	## @api framework_internal
	## [br]
	## @param additional_fields: 合并到结果中的额外字段。
	## [br]
	## @schema additional_fields: Dictionary copied into the output before summary fields are added.
	## [br]
	## @param options: 可选输出控制项，例如 include_info_count、include_issue_count、next_action。
	## [br]
	## @schema options: Dictionary controlling summary fields and next action text.
	## [br]
	## @return 诊断报告字典。
	## [br]
	## @schema return: Dictionary containing ok, healthy, counts, summary, next_action, and issues.
	func to_dict(additional_fields: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
		var result: Dictionary = additional_fields.duplicate(true)
		var error_count: int = 0
		var warning_count: int = 0
		var info_count: int = 0
		var issue_counts_by_kind: Dictionary = {}
		for issue: Dictionary in issues:
			var severity: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "severity", "error")
			match severity:
				"error":
					error_count += 1
				"warning":
					warning_count += 1
				"info":
					info_count += 1

			var kind_key: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "kind", "unknown")
			issue_counts_by_kind[kind_key] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(issue_counts_by_kind, kind_key, 0) + 1

		var include_info_count: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_info_count", true)
		var include_issue_count: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_issue_count", true)
		result["ok"] = error_count == 0
		result["healthy"] = error_count == 0 and warning_count == 0
		result["error_count"] = error_count
		result["warning_count"] = warning_count
		if include_info_count:
			result["info_count"] = info_count
		if include_issue_count:
			result["issue_count"] = issues.size()
		result["issue_counts_by_kind"] = issue_counts_by_kind
		result["summary"] = _make_summary(error_count, warning_count)
		result["next_action"] = _get_next_action(options)
		result["issues"] = issues.duplicate(true)
		return result

	func _add_issue(
		severity: String,
		kind: StringName,
		message: String,
		key: Variant,
		path: String,
		metadata: Dictionary
	) -> Dictionary:
		var issue: Dictionary = {
			"severity": severity,
			"kind": String(kind),
			"message": message,
		}
		if key != null:
			issue["key"] = key
		if not path.is_empty():
			issue["path"] = path
		if not metadata.is_empty():
			issue["metadata"] = metadata.duplicate(true)
		issues.append(issue)
		return issue

	func _make_summary(error_count: int, warning_count: int) -> String:
		var label: String = subject
		if label.is_empty():
			label = "Validation report"
		if error_count > 0:
			return "%s has %d error(s) and %d warning(s)." % [label, error_count, warning_count]
		if warning_count > 0:
			return "%s has %d warning(s)." % [label, warning_count]
		return "%s is healthy." % label

	func _get_next_action(options: Dictionary) -> String:
		var next_actions: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "next_actions", {})
		var fallback_action: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "fallback_action", "Review the first reported issue.")
		var no_action: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "no_action", "No action required.")
		var issue: Dictionary = _get_first_issue_by_priority()
		if issue.is_empty():
			return no_action
		var kind_key: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "kind", "unknown")
		if next_actions.has(kind_key):
			return _GF_VARIANT_ACCESS_SCRIPT.to_text(next_actions[kind_key])
		var kind_name: StringName = StringName(kind_key)
		if next_actions.has(kind_name):
			return _GF_VARIANT_ACCESS_SCRIPT.to_text(next_actions[kind_name])
		return fallback_action

	func _get_first_issue_by_priority() -> Dictionary:
		for issue: Dictionary in issues:
			if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "severity", "") == "error":
				return issue
		for issue: Dictionary in issues:
			if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "severity", "") == "warning":
				return issue
		if not issues.is_empty():
			return issues[0]
		return {}


## ModuleRegistry: 架构模块注册表。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
class ModuleRegistry:
	## 注册表显示名称。
	## [br]
	## @api framework_internal
	var label: String = ""

	## 直接注册的模块实例映射。
	## [br]
	## @api framework_internal
	## [br]
	## @schema instances: Dictionary keyed by Script, storing registered module instances.
	var instances: Dictionary = {}

	## 别名到直接注册脚本的映射。
	## [br]
	## @api framework_internal
	## [br]
	## @schema aliases: Dictionary keyed by alias Script, storing target Script.
	var aliases: Dictionary = {}

	## 可赋值查询缓存。
	## [br]
	## @api framework_internal
	## [br]
	## @schema assignable_cache: Dictionary keyed by requested Script, storing resolved registered Script.
	var assignable_cache: Dictionary = {}

	func _init(p_label: String) -> void:
		label = p_label

	func _label_key() -> String:
		return label.to_lower()

	func _has_direct(script_cls: Script) -> bool:
		return script_cls != null and instances.has(script_cls)

	func _clear_assignable_cache() -> void:
		assignable_cache.clear()

	func _clear() -> void:
		instances.clear()
		aliases.clear()
		assignable_cache.clear()
