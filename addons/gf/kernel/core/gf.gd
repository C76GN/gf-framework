extends Node


# Gf: 全局入口单例，负责架构生命周期管理。


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_ASYNC_CALL_SCRIPT = preload("res://addons/gf/kernel/core/gf_async_call.gd")

## 项目级启动安装器配置。值为 GDScript 路径数组，脚本需继承 GFInstaller。
## [br]
## @api public
const INSTALLERS_SETTING: String = "gf/project/installers"

## 项目级 Installer 创建失败时是否中断架构初始化。
## [br]
## @api public
const FAIL_ON_INSTALLER_ERROR_SETTING: String = "gf/project/fail_on_installer_error"

## 项目级 Installer 单个 install()/install_bindings() 的最长等待时间。小于等于 0 时不启用超时。
## [br]
## @api public
const INSTALLER_TIMEOUT_SETTING: String = "gf/project/installer_timeout_seconds"

## 项目 Installer 基类脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
const GFInstallerBase = preload("res://addons/gf/kernel/core/gf_installer.gd")

## 依赖绑定生命周期定义脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
const GFBindingLifetimesBase = preload("res://addons/gf/kernel/core/gf_binding_lifetimes.gd")

## 扩展启用设置读取脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
const GFExtensionSettingsBase = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")


# --- 公共变量 ---

## 当前架构实例的只读访问器。
## [br]
## @api public
var architecture: GFArchitecture:
	get:
		return get_architecture()


# --- 私有变量 ---

var _architecture: GFArchitecture = null
var _architecture_assignment_serial: int = 0
var _last_project_installer_error: String = ""


# --- Godot 生命周期方法 ---

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS as Node.ProcessMode


# 每帧驱动架构的 tick 循环，由架构分发给 System 与实现 tick() 的 Utility。
func _process(delta: float) -> void:
	if _architecture != null:
		_architecture.tick(delta)


# 每物理帧驱动架构的 physics_tick 循环，由架构分发给 System 与实现 physics_tick() 的 Utility。
func _physics_process(delta: float) -> void:
	if _architecture != null:
		_architecture.physics_tick(delta)


# 节点退出树时清理架构。
func _exit_tree() -> void:
	if _architecture != null:
		_architecture_assignment_serial += 1
		_architecture.dispose()
		_architecture = null


# --- 公共方法 ---

## 检查当前是否已有架构实例。
## [br]
## @api public
## [br]
## @return 已存在架构时返回 true。
func has_architecture() -> bool:
	return _architecture != null


## 获取当前架构；若尚未创建，则自动创建一个默认 GFArchitecture。
## [br]
## @api public
## [br]
## @return 当前可用的 GFArchitecture 实例。
func create_architecture() -> GFArchitecture:
	if _architecture == null:
		_architecture_assignment_serial += 1
		_architecture = GFArchitecture.new()
	return _architecture


## 为当前架构创建声明式装配器。
## [br]
## @api public
## [br]
## @return 绑定到当前架构的装配器。
## [br]
## @schema return: GFBindBuilder-compatible binder owned by the current architecture.
func create_binder() -> Variant:
	return create_architecture().create_binder()


## 获取当前注册的架构实例。
## [br]
## @api public
## [br]
## @return GFArchitecture 实例，如果未注册则返回 null。
func get_architecture() -> GFArchitecture:
	if _architecture == null:
		push_error("[GF] 架构尚未初始化，请先注册架构。")
	return _architecture


## 设置并初始化架构实例。该方法内部使用 await，调用方应加 await。
## [br]
## @api public
## [br]
## @param architecture_instance: 要注册的 GFArchitecture 实例。
func set_architecture(architecture_instance: GFArchitecture) -> void:
	if architecture_instance == null:
		push_error("[GF] set_architecture 失败：传入的架构实例为空。")
		return

	_architecture_assignment_serial += 1
	var assignment_serial: int = _architecture_assignment_serial
	var previous_architecture: GFArchitecture = _architecture
	var installers_ready: bool = await _run_project_installers(architecture_instance)
	if not _is_architecture_assignment_serial_current(assignment_serial):
		return
	if not installers_ready:
		return
	if not architecture_instance.is_inited():
		await architecture_instance.init()
	if not _is_architecture_assignment_serial_current(assignment_serial):
		return
	if architecture_instance.has_initialization_failed():
		return
	if previous_architecture != null and previous_architecture != architecture_instance:
		previous_architecture.dispose()
	_architecture = architecture_instance


## 初始化当前架构。若尚未创建架构，则自动创建默认 GFArchitecture。
## [br]
## @api public
func init() -> void:
	var current_arch: GFArchitecture = create_architecture()
	var assignment_serial: int = _architecture_assignment_serial
	var installers_ready: bool = await _run_project_installers(current_arch)
	if not _is_architecture_assignment_current(current_arch, assignment_serial):
		return
	if not installers_ready:
		return
	if not current_arch.is_inited():
		await current_arch.init()


## 便捷注册 System 实例。
## [br]
## @api public
## [br]
## @param instance: 要注册、替换或注入的实例。
func register_system(instance: Object) -> void:
	await create_architecture().register_system_instance(instance)

## 便捷注册 Model 实例。
## [br]
## @api public
## [br]
## @param instance: 要注册、替换或注入的实例。
func register_model(instance: Object) -> void:
	await create_architecture().register_model_instance(instance)

## 便捷注册 Utility 实例。
## [br]
## @api public
## [br]
## @param instance: 要注册、替换或注入的实例。
func register_utility(instance: Object) -> void:
	await create_architecture().register_utility_instance(instance)

## 便捷替换 System 实例。
## [br]
## @api public
## [br]
## @param instance: 要注册、替换或注入的实例。
func replace_system(instance: Object) -> void:
	var script: Script = _get_instance_script_or_null(instance, "replace_system")
	if script != null:
		await create_architecture().replace_system(script, instance)

## 便捷替换 Model 实例。
## [br]
## @api public
## [br]
## @param instance: 要注册、替换或注入的实例。
func replace_model(instance: Object) -> void:
	var script: Script = _get_instance_script_or_null(instance, "replace_model")
	if script != null:
		await create_architecture().replace_model(script, instance)

## 便捷替换 Utility 实例。
## [br]
## @api public
## [br]
## @param instance: 要注册、替换或注入的实例。
func replace_utility(instance: Object) -> void:
	var script: Script = _get_instance_script_or_null(instance, "replace_utility")
	if script != null:
		await create_architecture().replace_utility(script, instance)

## 注册短生命周期对象工厂。
## [br]
## @api public
## [br]
## @param script_cls: 要注册、查询或创建的脚本类型。
## [br]
## @param factory: 用于创建实例的工厂绑定。
## [br]
## @param lifetime: 工厂实例生命周期策略。
func register_factory(
	script_cls: Script,
	factory: Callable,
	lifetime: int = GFBindingLifetimesBase.Lifetime.TRANSIENT
) -> void:
	create_architecture().register_factory(script_cls, factory, lifetime)

## 注册已有实例作为短生命周期工厂入口。
## [br]
## @api public
## [br]
## @param script_cls: 要注册、查询或创建的脚本类型。
## [br]
## @param instance: 要注册、替换或注入的实例。
func register_factory_instance(script_cls: Script, instance: Object) -> void:
	create_architecture().register_factory_instance(script_cls, instance)

## 替换短生命周期对象工厂。
## [br]
## @api public
## [br]
## @param script_cls: 要注册、查询或创建的脚本类型。
## [br]
## @param factory: 用于创建实例的工厂绑定。
## [br]
## @param lifetime: 工厂实例生命周期策略。
func replace_factory(
	script_cls: Script,
	factory: Callable,
	lifetime: int = GFBindingLifetimesBase.Lifetime.TRANSIENT
) -> void:
	create_architecture().replace_factory(script_cls, factory, lifetime)

## 替换已有实例工厂入口。
## [br]
## @api public
## [br]
## @param script_cls: 要注册、查询或创建的脚本类型。
## [br]
## @param instance: 要注册、替换或注入的实例。
func replace_factory_instance(script_cls: Script, instance: Object) -> void:
	create_architecture().replace_factory_instance(script_cls, instance)

## 注销短生命周期对象工厂。
## [br]
## @api public
## [br]
## @param script_cls: 要注册、查询或创建的脚本类型。
func unregister_factory(script_cls: Script) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("unregister_factory")
	if arch != null:
		arch.unregister_factory(script_cls)


## 检查当前架构或父级架构是否注册了指定工厂。
## [br]
## @api public
## [br]
## @param script_cls: 要注册、查询或创建的脚本类型。
## [br]
## @return 工厂存在时返回 true。
func has_factory(script_cls: Script) -> bool:
	var arch: GFArchitecture = _get_architecture_or_null("has_factory")
	if arch == null:
		return false
	return arch.has_factory(script_cls)


## 创建短生命周期对象实例。
## [br]
## @api public
## [br]
## @param script_cls: 要注册、查询或创建的脚本类型。
## [br]
## @return 创建出的实例；架构不可用或工厂不存在时返回 null。
func create_instance(script_cls: Script) -> Object:
	var arch: GFArchitecture = _get_architecture_or_null("create_instance")
	if arch == null:
		return null
	return arch.create_instance(script_cls)


## 向任意对象注入当前架构依赖。
## [br]
## @api public
## [br]
## @param instance: 要注册、替换或注入的实例。
func inject_object(instance: Object) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("inject_object")
	if arch != null:
		arch.inject_object(instance)


## 递归向节点树中实现注入 Hook 的节点注入当前架构。
## [br]
## @api public
## [br]
## @param node: 目标节点。
func inject_node_tree(node: Node) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("inject_node_tree")
	if arch != null:
		arch.inject_node_tree(node)


## 便捷注册 System 实例，并额外登记一个查询别名。
## [br]
## @api public
## [br]
## @param instance: 要注册、替换或注入的实例。
## [br]
## @param alias_cls: 要注册的别名脚本类型。
func register_system_as(instance: Object, alias_cls: Script) -> void:
	await create_architecture().register_system_instance_as(instance, alias_cls)

## 便捷注册 Model 实例，并额外登记一个查询别名。
## [br]
## @api public
## [br]
## @param instance: 要注册、替换或注入的实例。
## [br]
## @param alias_cls: 要注册的别名脚本类型。
func register_model_as(instance: Object, alias_cls: Script) -> void:
	await create_architecture().register_model_instance_as(instance, alias_cls)

## 便捷注册 Utility 实例，并额外登记一个查询别名。
## [br]
## @api public
## [br]
## @param instance: 要注册、替换或注入的实例。
## [br]
## @param alias_cls: 要注册的别名脚本类型。
func register_utility_as(instance: Object, alias_cls: Script) -> void:
	await create_architecture().register_utility_instance_as(instance, alias_cls)

## 为已注册 System 添加查询别名。
## [br]
## @api public
## [br]
## @param alias_cls: 要注册的别名脚本类型。
## [br]
## @param target_cls: 别名指向的目标脚本类型。
func register_system_alias(alias_cls: Script, target_cls: Script) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("register_system_alias")
	if arch != null:
		arch.register_system_alias(alias_cls, target_cls)

## 为已注册 Model 添加查询别名。
## [br]
## @api public
## [br]
## @param alias_cls: 要注册的别名脚本类型。
## [br]
## @param target_cls: 别名指向的目标脚本类型。
func register_model_alias(alias_cls: Script, target_cls: Script) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("register_model_alias")
	if arch != null:
		arch.register_model_alias(alias_cls, target_cls)

## 为已注册 Utility 添加查询别名。
## [br]
## @api public
## [br]
## @param alias_cls: 要注册的别名脚本类型。
## [br]
## @param target_cls: 别名指向的目标脚本类型。
func register_utility_alias(alias_cls: Script, target_cls: Script) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("register_utility_alias")
	if arch != null:
		arch.register_utility_alias(alias_cls, target_cls)

## 注销 System 查询别名，不影响目标实例。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param alias_cls: 要移除的别名脚本类型。
func unregister_system_alias(alias_cls: Script) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("unregister_system_alias")
	if arch != null:
		arch.unregister_system_alias(alias_cls)

## 注销 Model 查询别名，不影响目标实例。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param alias_cls: 要移除的别名脚本类型。
func unregister_model_alias(alias_cls: Script) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("unregister_model_alias")
	if arch != null:
		arch.unregister_model_alias(alias_cls)

## 注销 Utility 查询别名，不影响目标实例。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param alias_cls: 要移除的别名脚本类型。
func unregister_utility_alias(alias_cls: Script) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("unregister_utility_alias")
	if arch != null:
		arch.unregister_utility_alias(alias_cls)

## 获取 System 实例。
## [br]
## @api public
## [br]
## @param script_cls: 要注册、查询或创建的脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return System 实例；不存在或架构不可用时返回 null。
func get_system(script_cls: Script, require_ready: bool = false) -> Object:
	var arch: GFArchitecture = _get_architecture_or_null("get_system")
	if arch == null:
		return null
	return arch.get_system(script_cls, require_ready)

## 获取 Model 实例。
## [br]
## @api public
## [br]
## @param script_cls: 要注册、查询或创建的脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return Model 实例；不存在或架构不可用时返回 null。
func get_model(script_cls: Script, require_ready: bool = false) -> Object:
	var arch: GFArchitecture = _get_architecture_or_null("get_model")
	if arch == null:
		return null
	return arch.get_model(script_cls, require_ready)

## 获取 Utility 实例。
## [br]
## @api public
## [br]
## @param script_cls: 要注册、查询或创建的脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return Utility 实例；不存在或架构不可用时返回 null。
func get_utility(script_cls: Script, require_ready: bool = false) -> Object:
	var arch: GFArchitecture = _get_architecture_or_null("get_utility")
	if arch == null:
		return null
	return arch.get_utility(script_cls, require_ready)


## 仅从当前全局架构获取 System，不回退父级架构。
## [br]
## @api public
## [br]
## @param script_cls: 要注册、查询或创建的脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 当前全局架构中的 System 实例；不存在或架构不可用时返回 null。
func get_local_system(script_cls: Script, require_ready: bool = false) -> Object:
	var arch: GFArchitecture = _get_architecture_or_null("get_local_system")
	if arch == null:
		return null
	return arch.get_local_system(script_cls, require_ready)


## 仅从当前全局架构获取 Model，不回退父级架构。
## [br]
## @api public
## [br]
## @param script_cls: 要注册、查询或创建的脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 当前全局架构中的 Model 实例；不存在或架构不可用时返回 null。
func get_local_model(script_cls: Script, require_ready: bool = false) -> Object:
	var arch: GFArchitecture = _get_architecture_or_null("get_local_model")
	if arch == null:
		return null
	return arch.get_local_model(script_cls, require_ready)


## 仅从当前全局架构获取 Utility，不回退父级架构。
## [br]
## @api public
## [br]
## @param script_cls: 要注册、查询或创建的脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 当前全局架构中的 Utility 实例；不存在或架构不可用时返回 null。
func get_local_utility(script_cls: Script, require_ready: bool = false) -> Object:
	var arch: GFArchitecture = _get_architecture_or_null("get_local_utility")
	if arch == null:
		return null
	return arch.get_local_utility(script_cls, require_ready)

## 便捷发送全局命令。
## [br]
## @api public
## [br]
## @param command: 要执行的命令实例。
## [br]
## @return 命令处理结果。
## [br]
## @schema return: Variant command result returned by the registered command handler.
func send_command(command: Object) -> Variant:
	var arch: GFArchitecture = _get_architecture_or_null("send_command")
	if arch == null:
		return null
	return arch.send_command(command)

## 便捷发送查询。
## [br]
## @api public
## [br]
## @param query: 查询对象。
## [br]
## @return 查询处理结果。
## [br]
## @schema return: Variant query result returned by the registered query handler.
func send_query(query: Object) -> Variant:
	var arch: GFArchitecture = _get_architecture_or_null("send_query")
	if arch == null:
		return null
	return arch.send_query(query)

## 便捷发送带载体的强类型事件。
## [br]
## @api public
## [br]
## @param event_instance: 要派发的事件实例。
func send_event(event_instance: Object) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("send_event")
	if arch != null:
		arch.send_event(event_instance)

## 便捷发送无参数的轻量级事件。
## [br]
## @api public
## [br]
## @param event_id: 简单事件标识符。
## [br]
## @param payload: 随事件或交互传递的数据。
## [br]
## @schema payload: Variant payload passed unchanged to simple event listeners.
func send_simple_event(event_id: StringName, payload: Variant = null) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("send_simple_event")
	if arch != null:
		arch.send_simple_event(event_id, payload)

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
	var arch: GFArchitecture = _get_architecture_or_null("configure_event_debugging")
	if arch != null:
		arch.configure_event_debugging(max_dispatch_depth, trace_enabled, max_trace_entries)

## 获取事件系统诊断统计。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 事件系统诊断统计。
## [br]
## @schema return: Dictionary produced by GFTypeEventSystem.get_debug_stats().
func get_event_debug_stats() -> Dictionary:
	var arch: GFArchitecture = _get_architecture_or_null("get_event_debug_stats")
	if arch == null:
		return {}
	return arch.get_event_debug_stats()

## 获取事件监听器诊断明细。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 诊断选项，支持 include_entries。
## [br]
## @schema options: Dictionary，可包含 include_entries。
## [br]
## @return 监听器诊断报告。
## [br]
## @schema return: Dictionary produced by GFTypeEventSystem.get_listener_diagnostics().
func get_event_listener_diagnostics(options: Dictionary = {}) -> Dictionary:
	var arch: GFArchitecture = _get_architecture_or_null("get_event_listener_diagnostics")
	if arch == null:
		return {}
	return arch.get_event_listener_diagnostics(options)

## 清理 owner 已释放的事件监听器。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 本次立即移除或排队清理的监听器数量。
func compact_event_listeners() -> int:
	var arch: GFArchitecture = _get_architecture_or_null("compact_event_listeners")
	if arch == null:
		return 0
	return arch.compact_event_listeners()

## 获取最近事件派发追踪条目。
## [br]
## @api public
## [br]
## @return 从旧到新的追踪条目副本。
## [br]
## @schema return: Array of Dictionary trace entries with event, listener, owner, and dispatch metadata.
func get_event_dispatch_trace() -> Array[Dictionary]:
	var arch: GFArchitecture = _get_architecture_or_null("get_event_dispatch_trace")
	if arch == null:
		return []
	return arch.get_event_dispatch_trace()

## 清空事件派发追踪。
## [br]
## @api public
func clear_event_dispatch_trace() -> void:
	var arch: GFArchitecture = _get_architecture_or_null("clear_event_dispatch_trace")
	if arch != null:
		arch.clear_event_dispatch_trace()

## 快捷注册类型事件监听（别名：listen）。
## [br]
## @api public
## [br]
## @param event_type: 要监听或取消监听的事件脚本类型。
## [br]
## @param on_event: 事件触发时执行的回调。
## [br]
## @param priority: 监听器优先级，数值越大越先执行。
func listen(event_type: Script, on_event: Callable, priority: int = 0) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("listen")
	if arch != null:
		arch.register_event(event_type, on_event, priority)

## 快捷注册带拥有者的类型事件监听。
## [br]
## @api public
## [br]
## @param listener_owner: 监听回调的拥有者，用于批量注销。
## [br]
## @param event_type: 要监听或取消监听的事件脚本类型。
## [br]
## @param on_event: 事件触发时执行的回调。
## [br]
## @param priority: 监听器优先级，数值越大越先执行。
func listen_owned(listener_owner: Object, event_type: Script, on_event: Callable, priority: int = 0) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("listen_owned")
	if arch != null:
		arch.register_event_owned(listener_owner, event_type, on_event, priority)

## 快捷注册可赋值类型事件监听。
## [br]
## @api public
## [br]
## @param base_event_type: 要监听或取消监听的基类事件脚本类型。
## [br]
## @param on_event: 事件触发时执行的回调。
## [br]
## @param priority: 监听器优先级，数值越大越先执行。
func listen_assignable(base_event_type: Script, on_event: Callable, priority: int = 0) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("listen_assignable")
	if arch != null:
		arch.register_assignable_event(base_event_type, on_event, priority)

## 快捷注册带拥有者的可赋值类型事件监听。
## [br]
## @api public
## [br]
## @param listener_owner: 监听回调的拥有者，用于批量注销。
## [br]
## @param base_event_type: 要监听或取消监听的基类事件脚本类型。
## [br]
## @param on_event: 事件触发时执行的回调。
## [br]
## @param priority: 监听器优先级，数值越大越先执行。
func listen_assignable_owned(
	listener_owner: Object,
	base_event_type: Script,
	on_event: Callable,
	priority: int = 0
) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("listen_assignable_owned")
	if arch != null:
		arch.register_assignable_event_owned(listener_owner, base_event_type, on_event, priority)

## 快捷注销类型事件监听（别名：unlisten）。
## [br]
## @api public
## [br]
## @param event_type: 要监听或取消监听的事件脚本类型。
## [br]
## @param on_event: 事件触发时执行的回调。
func unlisten(event_type: Script, on_event: Callable) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("unlisten")
	if arch != null:
		arch.unregister_event(event_type, on_event)

## 快捷注销带拥有者的类型事件监听。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param listener_owner: 注册监听时使用的拥有者。
## [br]
## @param event_type: 要取消监听的事件脚本类型。
## [br]
## @param on_event: 要移除的回调。
func unlisten_owned(listener_owner: Object, event_type: Script, on_event: Callable) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("unlisten_owned")
	if arch != null:
		arch.unregister_event_owned(listener_owner, event_type, on_event)

## 快捷注销可赋值类型事件监听。
## [br]
## @api public
## [br]
## @param base_event_type: 要监听或取消监听的基类事件脚本类型。
## [br]
## @param on_event: 事件触发时执行的回调。
func unlisten_assignable(base_event_type: Script, on_event: Callable) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("unlisten_assignable")
	if arch != null:
		arch.unregister_assignable_event(base_event_type, on_event)

## 快捷注销带拥有者的可赋值类型事件监听。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param listener_owner: 注册监听时使用的拥有者。
## [br]
## @param base_event_type: 要取消监听的基类事件脚本类型。
## [br]
## @param on_event: 要移除的回调。
func unlisten_assignable_owned(listener_owner: Object, base_event_type: Script, on_event: Callable) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("unlisten_assignable_owned")
	if arch != null:
		arch.unregister_assignable_event_owned(listener_owner, base_event_type, on_event)

## 快捷注册轻量事件监听（别名：listen_simple）。
## [br]
## @api public
## [br]
## @param event_id: 简单事件标识符。
## [br]
## @param on_event: 事件触发时执行的回调。
func listen_simple(event_id: StringName, on_event: Callable) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("listen_simple")
	if arch != null:
		arch.register_simple_event(event_id, on_event)

## 快捷注册带拥有者的轻量事件监听。
## [br]
## @api public
## [br]
## @param listener_owner: 监听回调的拥有者，用于批量注销。
## [br]
## @param event_id: 简单事件标识符。
## [br]
## @param on_event: 事件触发时执行的回调。
func listen_simple_owned(listener_owner: Object, event_id: StringName, on_event: Callable) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("listen_simple_owned")
	if arch != null:
		arch.register_simple_event_owned(listener_owner, event_id, on_event)

## 快捷注销轻量事件监听（别名：unlisten_simple）。
## [br]
## @api public
## [br]
## @param event_id: 简单事件标识符。
## [br]
## @param on_event: 事件触发时执行的回调。
func unlisten_simple(event_id: StringName, on_event: Callable) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("unlisten_simple")
	if arch != null:
		arch.unregister_simple_event(event_id, on_event)

## 快捷注销带拥有者的轻量事件监听。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param listener_owner: 注册监听时使用的拥有者。
## [br]
## @param event_id: 简单事件标识符。
## [br]
## @param on_event: 要移除的回调。
func unlisten_simple_owned(listener_owner: Object, event_id: StringName, on_event: Callable) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("unlisten_simple_owned")
	if arch != null:
		arch.unregister_simple_event_owned(listener_owner, event_id, on_event)

## 快捷注销某个拥有者注册过的所有事件监听。
## [br]
## @api public
## [br]
## @param listener_owner: 监听回调的拥有者，用于批量注销。
func unlisten_owner(listener_owner: Object) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("unlisten_owner")
	if arch != null:
		arch.unregister_owner_events(listener_owner)

## 注销 System 实例。
## [br]
## @api public
## [br]
## @param script_cls: 要注册、查询或创建的脚本类型。
func unregister_system(script_cls: Script) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("unregister_system")
	if arch != null:
		arch.unregister_system(script_cls)

## 注销 Model 实例。
## [br]
## @api public
## [br]
## @param script_cls: 要注册、查询或创建的脚本类型。
func unregister_model(script_cls: Script) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("unregister_model")
	if arch != null:
		arch.unregister_model(script_cls)

## 注销 Utility 实例。
## [br]
## @api public
## [br]
## @param script_cls: 要注册、查询或创建的脚本类型。
func unregister_utility(script_cls: Script) -> void:
	var arch: GFArchitecture = _get_architecture_or_null("unregister_utility")
	if arch != null:
		arch.unregister_utility(script_cls)


# --- 私有/辅助方法 ---

func _get_architecture_or_null(context: String) -> GFArchitecture:
	if _architecture == null:
		push_error("[GF] %s 失败：架构尚未初始化，请先注册架构。" % context)
		return null
	return _architecture


func _get_instance_script_or_null(instance: Object, context: String) -> Script:
	if instance == null:
		push_error("[GF] %s 失败：实例为空。" % context)
		return null
	var raw_script: Variant = instance.get_script()
	if not raw_script is Script:
		push_error("[GF] %s 失败：实例未附加脚本。" % context)
		return null
	var script: Script = raw_script
	return script


func _run_project_installers(architecture_instance: GFArchitecture) -> bool:
	if architecture_instance == null:
		return false
	if architecture_instance.has_project_installers_applied():
		return true

	if architecture_instance.is_project_installers_running():
		await architecture_instance.project_installers_finished
		return not architecture_instance.has_initialization_failed() and architecture_instance.has_project_installers_applied()

	if not architecture_instance.begin_project_installers():
		return architecture_instance.has_project_installers_applied()

	var installer_paths: Array[String] = _get_project_installer_paths()
	if not _last_project_installer_error.is_empty():
		if _should_fail_on_project_installer_error():
			architecture_instance.fail_initialization(_last_project_installer_error)
			return false

	for path: String in installer_paths:
		var installer: GFInstaller = _create_installer(path)
		if installer == null:
			if _should_fail_on_project_installer_error():
				architecture_instance.fail_initialization(_last_project_installer_error)
				return false
			continue
		if installer != null:
			var install_completed: bool = await _await_project_installer_install(installer, architecture_instance, path)
			if not install_completed or not architecture_instance.is_project_installers_running():
				return false
			if installer.has_method("install_bindings"):
				var bindings_completed: bool = await _await_project_installer_bindings(installer, architecture_instance, path)
				if not bindings_completed:
					return false
		if not architecture_instance.is_project_installers_running():
			return false

	architecture_instance.finish_project_installers()
	return true


func _await_project_installer_install(
	installer: GFInstaller,
	architecture_instance: GFArchitecture,
	path: String
) -> bool:
	var timeout_seconds: float = _get_project_installer_timeout_seconds()
	var scene_tree: SceneTree = _get_scene_tree_or_null()
	if timeout_seconds <= 0.0 or scene_tree == null:
		await installer.call(&"install", architecture_instance)
		return not architecture_instance.has_initialization_failed()

	var completion_state: Dictionary = {
		"done": false,
		"write_blocked": false,
	}
	_GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_complete_project_installer_install"),
		[installer, architecture_instance, completion_state]
	)
	return await _wait_for_project_installer_step(
		completion_state,
		architecture_instance,
		path,
		"install",
		timeout_seconds,
		scene_tree
	)


func _await_project_installer_bindings(
	installer: GFInstaller,
	architecture_instance: GFArchitecture,
	path: String
) -> bool:
	var timeout_seconds: float = _get_project_installer_timeout_seconds()
	var scene_tree: SceneTree = _get_scene_tree_or_null()
	if timeout_seconds <= 0.0 or scene_tree == null:
		await installer.call(&"install_bindings", architecture_instance.create_binder())
		return not architecture_instance.has_initialization_failed()

	var completion_state: Dictionary = {
		"done": false,
		"write_blocked": false,
	}
	_GF_ASYNC_CALL_SCRIPT.run_detached(
		Callable(self, &"_complete_project_installer_bindings"),
		[installer, architecture_instance, completion_state]
	)
	return await _wait_for_project_installer_step(
		completion_state,
		architecture_instance,
		path,
		"install_bindings",
		timeout_seconds,
		scene_tree
	)


func _complete_project_installer_install(
	installer: GFInstaller,
	architecture_instance: GFArchitecture,
	completion_state: Dictionary
) -> void:
	await installer.call(&"install", architecture_instance)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(completion_state, "write_blocked", false):
		architecture_instance._end_stale_async_write_block()
	completion_state["done"] = true


func _complete_project_installer_bindings(
	installer: GFInstaller,
	architecture_instance: GFArchitecture,
	completion_state: Dictionary
) -> void:
	await installer.call(&"install_bindings", architecture_instance.create_binder())
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(completion_state, "write_blocked", false):
		architecture_instance._end_stale_async_write_block()
	completion_state["done"] = true


func _wait_for_project_installer_step(
	completion_state: Dictionary,
	architecture_instance: GFArchitecture,
	path: String,
	stage: String,
	timeout_seconds: float,
	scene_tree: SceneTree
) -> bool:
	var start_msec: int = Time.get_ticks_msec()
	var timeout_msec: int = int(timeout_seconds * 1000.0)
	while not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(completion_state, "done", false):
		if architecture_instance.has_initialization_failed() or not architecture_instance.is_project_installers_running():
			return false
		var elapsed_msec: int = Time.get_ticks_msec() - start_msec
		if elapsed_msec >= timeout_msec:
			completion_state["write_blocked"] = true
			architecture_instance._begin_stale_async_write_block()
			architecture_instance.fail_initialization(
				"[GF] 项目 Installer 超时：%s 的 %s() 超过 %.2f 秒。" % [
					path,
					stage,
					timeout_seconds,
				]
			)
			return false
		await scene_tree.process_frame
	return not architecture_instance.has_initialization_failed()


func _get_project_installer_paths() -> Array[String]:
	_last_project_installer_error = ""
	var raw_paths: Variant = ProjectSettings.get_setting(INSTALLERS_SETTING, [])
	var installer_paths: Array[String] = GFExtensionSettingsBase.get_enabled_installer_paths()

	if raw_paths is PackedStringArray:
		for path: String in raw_paths:
			_append_unique_installer_path(installer_paths, path)
		return installer_paths

	if raw_paths is Array:
		for path_variant: Variant in raw_paths:
			if typeof(path_variant) == TYPE_STRING:
				_append_unique_installer_path(installer_paths, _GF_VARIANT_ACCESS_SCRIPT.to_text(path_variant, ""))
			else:
				push_warning("[GF] 项目 Installer 配置包含非字符串项，已跳过。")
		return installer_paths

	_report_project_installer_error("[GF] 项目 Installer 配置必须是路径数组。")
	return installer_paths


func _get_scene_tree_or_null() -> SceneTree:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var scene_tree: SceneTree = main_loop
		return scene_tree
	return null


func _append_unique_installer_path(installer_paths: Array[String], path: String) -> void:
	if path.is_empty() or installer_paths.has(path):
		return
	installer_paths.append(path)


func _create_installer(path: String) -> GFInstaller:
	_last_project_installer_error = ""
	if path.is_empty():
		_report_project_installer_error("[GF] 项目 Installer 路径为空。")
		return null

	var raw_installer_script: Variant = load(path)
	if not raw_installer_script is Script:
		_report_project_installer_error("[GF] 无法加载项目 Installer：%s" % path)
		return null
	var installer_script: Script = raw_installer_script

	if not installer_script.can_instantiate():
		_report_project_installer_error("[GF] 项目 Installer 无法实例化：%s" % path)
		return null

	var instance: GFInstaller = _instantiate_installer(installer_script)
	if instance == null:
		_report_project_installer_error("[GF] 项目 Installer 必须继承 GFInstaller：%s" % path)
		return null

	return instance


static func _instantiate_installer(installer_script: Script) -> GFInstaller:
	var raw_instance: Variant = installer_script.call("new")
	if raw_instance is GFInstaller:
		var installer: GFInstaller = raw_instance
		return installer
	return null


func _should_fail_on_project_installer_error() -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.to_bool(ProjectSettings.get_setting(FAIL_ON_INSTALLER_ERROR_SETTING, true), true)


func _get_project_installer_timeout_seconds() -> float:
	return maxf(_GF_VARIANT_ACCESS_SCRIPT.to_float(ProjectSettings.get_setting(INSTALLER_TIMEOUT_SETTING, 0.0), 0.0), 0.0)


func _report_project_installer_error(message: String) -> void:
	_last_project_installer_error = message
	push_error(message)


func _is_architecture_assignment_current(architecture_instance: GFArchitecture, assignment_serial: int) -> bool:
	return _architecture == architecture_instance and _architecture_assignment_serial == assignment_serial


func _is_architecture_assignment_serial_current(assignment_serial: int) -> bool:
	return _architecture_assignment_serial == assignment_serial
