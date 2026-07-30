# GFArchitecture

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_architecture.gd`
- 模块：`Kernel`
- 继承：`Object`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

管理 Model、System 和 Utility 的注册与生命周期的容器。 生命周期遵循三阶段初始化协议： 阶段一 (init)       ：所有模块执行自身内部变量初始化。 阶段二 (async_init) ：所有模块串行执行异步初始化（可使用 await）。 阶段三 (ready)      ：所有模块均已完成 init，可安全进行跨模块依赖获取。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`initialization_finished`](#member-gfarchitecture-signals-initialization_finished) | `signal initialization_finished` |
| 信号 | [`initialization_failed`](#member-gfarchitecture-signals-initialization_failed) | `signal initialization_failed(reason: String)` |
| 信号 | [`project_installers_finished`](#member-gfarchitecture-signals-project_installers_finished) | `signal project_installers_finished` |
| 常量 | [`SERVICE_COMMAND_HISTORY_STORE`](#member-gfarchitecture-constants-service_command_history_store) | `const SERVICE_COMMAND_HISTORY_STORE: StringName = &"gf.kernel.command_history_store"` |
| 常量 | [`HOOK_GET_REQUIRED_DEPENDENCIES`](#member-gfarchitecture-constants-hook_get_required_dependencies) | `const HOOK_GET_REQUIRED_DEPENDENCIES: StringName = &"get_required_dependencies"` |
| 常量 | [`HOOK_GET_REQUIRED_MODELS`](#member-gfarchitecture-constants-hook_get_required_models) | `const HOOK_GET_REQUIRED_MODELS: StringName = &"get_required_models"` |
| 常量 | [`HOOK_GET_REQUIRED_SYSTEMS`](#member-gfarchitecture-constants-hook_get_required_systems) | `const HOOK_GET_REQUIRED_SYSTEMS: StringName = &"get_required_systems"` |
| 常量 | [`HOOK_GET_REQUIRED_UTILITIES`](#member-gfarchitecture-constants-hook_get_required_utilities) | `const HOOK_GET_REQUIRED_UTILITIES: StringName = &"get_required_utilities"` |
| 常量 | [`HOOK_GET_REQUIRED_FACTORIES`](#member-gfarchitecture-constants-hook_get_required_factories) | `const HOOK_GET_REQUIRED_FACTORIES: StringName = &"get_required_factories"` |
| 常量 | [`DEFAULT_SNAPSHOT_MODELS_PER_FRAME`](#member-gfarchitecture-constants-default_snapshot_models_per_frame) | `const DEFAULT_SNAPSHOT_MODELS_PER_FRAME: int = 8` |
| 属性 | [`module_async_init_timeout_seconds`](#member-gfarchitecture-properties-module_async_init_timeout_seconds) | `var module_async_init_timeout_seconds: float = 0.0:` |
| 属性 | [`module_lifecycle_max_stage_passes`](#member-gfarchitecture-properties-module_lifecycle_max_stage_passes) | `var module_lifecycle_max_stage_passes: int = 256:` |
| 属性 | [`strict_dependency_lookup`](#member-gfarchitecture-properties-strict_dependency_lookup) | `var strict_dependency_lookup: bool = false` |
| 属性 | [`fail_on_missing_declared_dependencies`](#member-gfarchitecture-properties-fail_on_missing_declared_dependencies) | `var fail_on_missing_declared_dependencies: bool = false` |
| 属性 | [`last_initialization_error`](#member-gfarchitecture-properties-last_initialization_error) | `var last_initialization_error: String = ""` |
| 方法 | [`_init`](#member-gfarchitecture-methods-_init) | `func _init(parent_architecture: GFArchitecture = null) -> void:` |
| 方法 | [`is_inited`](#member-gfarchitecture-methods-is_inited) | `func is_inited() -> bool:` |
| 方法 | [`has_initialization_failed`](#member-gfarchitecture-methods-has_initialization_failed) | `func has_initialization_failed() -> bool:` |
| 方法 | [`is_lifecycle_active`](#member-gfarchitecture-methods-is_lifecycle_active) | `func is_lifecycle_active() -> bool:` |
| 方法 | [`is_disposed`](#member-gfarchitecture-methods-is_disposed) | `func is_disposed() -> bool:` |
| 方法 | [`is_disposing`](#member-gfarchitecture-methods-is_disposing) | `func is_disposing() -> bool:` |
| 方法 | [`get_lifecycle_generation`](#member-gfarchitecture-methods-get_lifecycle_generation) | `func get_lifecycle_generation() -> int:` |
| 方法 | [`is_lifecycle_generation_active`](#member-gfarchitecture-methods-is_lifecycle_generation_active) | `func is_lifecycle_generation_active(lifecycle_generation: int) -> bool:` |
| 方法 | [`is_module_ready`](#member-gfarchitecture-methods-is_module_ready) | `func is_module_ready(instance: Object) -> bool:` |
| 方法 | [`fail_initialization`](#member-gfarchitecture-methods-fail_initialization) | `func fail_initialization(reason: String) -> void:` |
| 方法 | [`get_parent_architecture`](#member-gfarchitecture-methods-get_parent_architecture) | `func get_parent_architecture() -> GFArchitecture:` |
| 方法 | [`set_parent_architecture`](#member-gfarchitecture-methods-set_parent_architecture) | `func set_parent_architecture(parent_architecture: GFArchitecture) -> void:` |
| 方法 | [`has_project_installers_applied`](#member-gfarchitecture-methods-has_project_installers_applied) | `func has_project_installers_applied() -> bool:` |
| 方法 | [`is_project_installers_running`](#member-gfarchitecture-methods-is_project_installers_running) | `func is_project_installers_running() -> bool:` |
| 方法 | [`begin_project_installers`](#member-gfarchitecture-methods-begin_project_installers) | `func begin_project_installers() -> bool:` |
| 方法 | [`mark_project_installers_applied`](#member-gfarchitecture-methods-mark_project_installers_applied) | `func mark_project_installers_applied() -> void:` |
| 方法 | [`finish_project_installers`](#member-gfarchitecture-methods-finish_project_installers) | `func finish_project_installers() -> void:` |
| 方法 | [`create_binder`](#member-gfarchitecture-methods-create_binder) | `func create_binder() -> GFBinder:` |
| 方法 | [`init`](#member-gfarchitecture-methods-init) | `func init() -> bool:` |
| 方法 | [`dispose`](#member-gfarchitecture-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`tick`](#member-gfarchitecture-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`physics_tick`](#member-gfarchitecture-methods-physics_tick) | `func physics_tick(delta: float) -> void:` |
| 方法 | [`send_command`](#member-gfarchitecture-methods-send_command) | `func send_command(command: Object) -> Variant:` |
| 方法 | [`send_query`](#member-gfarchitecture-methods-send_query) | `func send_query(query: Object) -> Variant:` |
| 方法 | [`send_event`](#member-gfarchitecture-methods-send_event) | `func send_event(event_instance: Object) -> void:` |
| 方法 | [`register_event`](#member-gfarchitecture-methods-register_event) | `func register_event(event_type: Script, listener: GFEventListener, priority: int = 0) -> void:` |
| 方法 | [`register_event_owned`](#member-gfarchitecture-methods-register_event_owned) | `func register_event_owned(owner: Object, event_type: Script, listener: GFEventListener, priority: int = 0) -> void:` |
| 方法 | [`subscribe_event`](#member-gfarchitecture-methods-subscribe_event) | `func subscribe_event( event_type: Script, listener: GFEventListener, priority: int = 0, once: bool = false ) -> GFSubscriptionToken:` |
| 方法 | [`register_assignable_event`](#member-gfarchitecture-methods-register_assignable_event) | `func register_assignable_event(base_event_type: Script, listener: GFEventListener, priority: int = 0) -> void:` |
| 方法 | [`register_assignable_event_owned`](#member-gfarchitecture-methods-register_assignable_event_owned) | `func register_assignable_event_owned( owner: Object, base_event_type: Script, listener: GFEventListener, priority: int = 0 ) -> void:` |
| 方法 | [`subscribe_assignable_event`](#member-gfarchitecture-methods-subscribe_assignable_event) | `func subscribe_assignable_event( base_event_type: Script, listener: GFEventListener, priority: int = 0, once: bool = false ) -> GFSubscriptionToken:` |
| 方法 | [`unregister_event`](#member-gfarchitecture-methods-unregister_event) | `func unregister_event(event_type: Script, listener: GFEventListener) -> void:` |
| 方法 | [`unregister_event_owned`](#member-gfarchitecture-methods-unregister_event_owned) | `func unregister_event_owned(owner: Object, event_type: Script, listener: GFEventListener) -> void:` |
| 方法 | [`unregister_assignable_event`](#member-gfarchitecture-methods-unregister_assignable_event) | `func unregister_assignable_event(base_event_type: Script, listener: GFEventListener) -> void:` |
| 方法 | [`unregister_assignable_event_owned`](#member-gfarchitecture-methods-unregister_assignable_event_owned) | `func unregister_assignable_event_owned(owner: Object, base_event_type: Script, listener: GFEventListener) -> void:` |
| 方法 | [`register_simple_event`](#member-gfarchitecture-methods-register_simple_event) | `func register_simple_event(event_id: StringName, listener: GFEventListener) -> void:` |
| 方法 | [`register_simple_event_owned`](#member-gfarchitecture-methods-register_simple_event_owned) | `func register_simple_event_owned(owner: Object, event_id: StringName, listener: GFEventListener) -> void:` |
| 方法 | [`subscribe_simple_event`](#member-gfarchitecture-methods-subscribe_simple_event) | `func subscribe_simple_event( event_id: StringName, listener: GFEventListener, once: bool = false ) -> GFSubscriptionToken:` |
| 方法 | [`unregister_simple_event`](#member-gfarchitecture-methods-unregister_simple_event) | `func unregister_simple_event(event_id: StringName, listener: GFEventListener) -> void:` |
| 方法 | [`unregister_simple_event_owned`](#member-gfarchitecture-methods-unregister_simple_event_owned) | `func unregister_simple_event_owned(owner: Object, event_id: StringName, listener: GFEventListener) -> void:` |
| 方法 | [`unregister_owner_events`](#member-gfarchitecture-methods-unregister_owner_events) | `func unregister_owner_events(owner: Object) -> void:` |
| 方法 | [`send_simple_event`](#member-gfarchitecture-methods-send_simple_event) | `func send_simple_event(event_id: StringName, payload: Variant = null) -> void:` |
| 方法 | [`get_event_debug_stats`](#member-gfarchitecture-methods-get_event_debug_stats) | `func get_event_debug_stats() -> Dictionary:` |
| 方法 | [`get_event_listener_diagnostics`](#member-gfarchitecture-methods-get_event_listener_diagnostics) | `func get_event_listener_diagnostics(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`compact_event_listeners`](#member-gfarchitecture-methods-compact_event_listeners) | `func compact_event_listeners() -> int:` |
| 方法 | [`configure_event_debugging`](#member-gfarchitecture-methods-configure_event_debugging) | `func configure_event_debugging( max_dispatch_depth: int = GFTypeEventSystem.DEFAULT_MAX_DISPATCH_DEPTH, trace_enabled: bool = false, max_trace_entries: int = 64 ) -> void:` |
| 方法 | [`get_event_dispatch_trace`](#member-gfarchitecture-methods-get_event_dispatch_trace) | `func get_event_dispatch_trace() -> Array[Dictionary]:` |
| 方法 | [`clear_event_dispatch_trace`](#member-gfarchitecture-methods-clear_event_dispatch_trace) | `func clear_event_dispatch_trace() -> void:` |
| 方法 | [`register_system`](#member-gfarchitecture-methods-register_system) | `func register_system(script_cls: Script, instance: Object) -> bool:` |
| 方法 | [`register_model`](#member-gfarchitecture-methods-register_model) | `func register_model(script_cls: Script, instance: Object) -> bool:` |
| 方法 | [`register_utility`](#member-gfarchitecture-methods-register_utility) | `func register_utility(script_cls: Script, instance: Object) -> bool:` |
| 方法 | [`replace_system`](#member-gfarchitecture-methods-replace_system) | `func replace_system(script_cls: Script, instance: Object) -> bool:` |
| 方法 | [`replace_model`](#member-gfarchitecture-methods-replace_model) | `func replace_model(script_cls: Script, instance: Object) -> bool:` |
| 方法 | [`replace_utility`](#member-gfarchitecture-methods-replace_utility) | `func replace_utility(script_cls: Script, instance: Object) -> bool:` |
| 方法 | [`register_factory`](#member-gfarchitecture-methods-register_factory) | `func register_factory( script_cls: Script, factory: Callable, lifetime: int = GFBindingLifetimesBase.Lifetime.TRANSIENT ) -> bool:` |
| 方法 | [`register_factory_instance`](#member-gfarchitecture-methods-register_factory_instance) | `func register_factory_instance(script_cls: Script, instance: Object) -> bool:` |
| 方法 | [`replace_factory`](#member-gfarchitecture-methods-replace_factory) | `func replace_factory( script_cls: Script, factory: Callable, lifetime: int = GFBindingLifetimesBase.Lifetime.TRANSIENT ) -> bool:` |
| 方法 | [`replace_factory_instance`](#member-gfarchitecture-methods-replace_factory_instance) | `func replace_factory_instance(script_cls: Script, instance: Object) -> bool:` |
| 方法 | [`unregister_factory`](#member-gfarchitecture-methods-unregister_factory) | `func unregister_factory(script_cls: Script) -> bool:` |
| 方法 | [`has_factory`](#member-gfarchitecture-methods-has_factory) | `func has_factory(script_cls: Script) -> bool:` |
| 方法 | [`register_service`](#member-gfarchitecture-methods-register_service) | `func register_service(service_key: StringName, provider: Object) -> bool:` |
| 方法 | [`unregister_service`](#member-gfarchitecture-methods-unregister_service) | `func unregister_service(service_key: StringName, provider: Object = null) -> bool:` |
| 方法 | [`get_service`](#member-gfarchitecture-methods-get_service) | `func get_service(service_key: StringName, include_parent: bool = true) -> Object:` |
| 方法 | [`has_service`](#member-gfarchitecture-methods-has_service) | `func has_service(service_key: StringName, include_parent: bool = true) -> bool:` |
| 方法 | [`register_system_alias`](#member-gfarchitecture-methods-register_system_alias) | `func register_system_alias(alias_cls: Script, target_cls: Script) -> void:` |
| 方法 | [`register_model_alias`](#member-gfarchitecture-methods-register_model_alias) | `func register_model_alias(alias_cls: Script, target_cls: Script) -> void:` |
| 方法 | [`register_utility_alias`](#member-gfarchitecture-methods-register_utility_alias) | `func register_utility_alias(alias_cls: Script, target_cls: Script) -> void:` |
| 方法 | [`unregister_system_alias`](#member-gfarchitecture-methods-unregister_system_alias) | `func unregister_system_alias(alias_cls: Script) -> void:` |
| 方法 | [`unregister_model_alias`](#member-gfarchitecture-methods-unregister_model_alias) | `func unregister_model_alias(alias_cls: Script) -> void:` |
| 方法 | [`unregister_utility_alias`](#member-gfarchitecture-methods-unregister_utility_alias) | `func unregister_utility_alias(alias_cls: Script) -> void:` |
| 方法 | [`register_system_instance`](#member-gfarchitecture-methods-register_system_instance) | `func register_system_instance(instance: Object) -> bool:` |
| 方法 | [`register_model_instance`](#member-gfarchitecture-methods-register_model_instance) | `func register_model_instance(instance: Object) -> bool:` |
| 方法 | [`register_utility_instance`](#member-gfarchitecture-methods-register_utility_instance) | `func register_utility_instance(instance: Object) -> bool:` |
| 方法 | [`register_system_instance_as`](#member-gfarchitecture-methods-register_system_instance_as) | `func register_system_instance_as(instance: Object, alias_cls: Script) -> bool:` |
| 方法 | [`register_model_instance_as`](#member-gfarchitecture-methods-register_model_instance_as) | `func register_model_instance_as(instance: Object, alias_cls: Script) -> bool:` |
| 方法 | [`register_utility_instance_as`](#member-gfarchitecture-methods-register_utility_instance_as) | `func register_utility_instance_as(instance: Object, alias_cls: Script) -> bool:` |
| 方法 | [`unregister_system`](#member-gfarchitecture-methods-unregister_system) | `func unregister_system(script_cls: Script) -> void:` |
| 方法 | [`unregister_model`](#member-gfarchitecture-methods-unregister_model) | `func unregister_model(script_cls: Script) -> void:` |
| 方法 | [`unregister_utility`](#member-gfarchitecture-methods-unregister_utility) | `func unregister_utility(script_cls: Script) -> void:` |
| 方法 | [`get_system`](#member-gfarchitecture-methods-get_system) | `func get_system(script_cls: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_model`](#member-gfarchitecture-methods-get_model) | `func get_model(script_cls: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_utility`](#member-gfarchitecture-methods-get_utility) | `func get_utility(script_cls: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`find_system`](#member-gfarchitecture-methods-find_system) | `func find_system(script_cls: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`find_model`](#member-gfarchitecture-methods-find_model) | `func find_model(script_cls: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`find_utility`](#member-gfarchitecture-methods-find_utility) | `func find_utility(script_cls: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_system`](#member-gfarchitecture-methods-get_local_system) | `func get_local_system(script_cls: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_model`](#member-gfarchitecture-methods-get_local_model) | `func get_local_model(script_cls: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_utility`](#member-gfarchitecture-methods-get_local_utility) | `func get_local_utility(script_cls: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`create_instance`](#member-gfarchitecture-methods-create_instance) | `func create_instance(script_cls: Script) -> Object:` |
| 方法 | [`inject_object`](#member-gfarchitecture-methods-inject_object) | `func inject_object(instance: Object) -> void:` |
| 方法 | [`inject_node_tree`](#member-gfarchitecture-methods-inject_node_tree) | `func inject_node_tree(node: Node) -> void:` |
| 方法 | [`get_all_models_state`](#member-gfarchitecture-methods-get_all_models_state) | `func get_all_models_state() -> Dictionary:` |
| 方法 | [`get_all_models_state_async`](#member-gfarchitecture-methods-get_all_models_state_async) | `func get_all_models_state_async(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`restore_all_models_state`](#member-gfarchitecture-methods-restore_all_models_state) | `func restore_all_models_state(data: Dictionary) -> Dictionary:` |
| 方法 | [`restore_all_models_state_async`](#member-gfarchitecture-methods-restore_all_models_state_async) | `func restore_all_models_state_async( data: Dictionary, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`get_global_snapshot`](#member-gfarchitecture-methods-get_global_snapshot) | `func get_global_snapshot() -> Dictionary:` |
| 方法 | [`get_global_snapshot_async`](#member-gfarchitecture-methods-get_global_snapshot_async) | `func get_global_snapshot_async(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`restore_global_snapshot`](#member-gfarchitecture-methods-restore_global_snapshot) | `func restore_global_snapshot( data: Dictionary, command_builder: Callable = Callable() ) -> Dictionary:` |
| 方法 | [`restore_global_snapshot_async`](#member-gfarchitecture-methods-restore_global_snapshot_async) | `func restore_global_snapshot_async( data: Dictionary, command_builder: Callable = Callable(), options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`get_debug_lifecycle_state`](#member-gfarchitecture-methods-get_debug_lifecycle_state) | `func get_debug_lifecycle_state() -> Dictionary:` |
| 方法 | [`get_binding_diagnostics`](#member-gfarchitecture-methods-get_binding_diagnostics) | `func get_binding_diagnostics(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_dependency_diagnostics`](#member-gfarchitecture-methods-get_dependency_diagnostics) | `func get_dependency_diagnostics(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`_on_init`](#member-gfarchitecture-methods-_on_init) | `func _on_init() -> void:` |
| 方法 | [`_on_dispose`](#member-gfarchitecture-methods-_on_dispose) | `func _on_dispose() -> void:` |

## 信号

<a id="member-gfarchitecture-signals-initialization_finished"></a>

### `initialization_finished`

- API：`public`

```gdscript
signal initialization_finished
```

当一次初始化流程完成或被 dispose() 中断后发出。

<a id="member-gfarchitecture-signals-initialization_failed"></a>

### `initialization_failed`

- API：`public`

```gdscript
signal initialization_failed(reason: String)
```

当一次初始化流程因为框架级保护失败后发出。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 初始化失败原因。 |

<a id="member-gfarchitecture-signals-project_installers_finished"></a>

### `project_installers_finished`

- API：`public`

```gdscript
signal project_installers_finished
```

当项目级 Installer 应用完成或被 dispose() 中断后发出。

## 常量

<a id="member-gfarchitecture-constants-service_command_history_store"></a>

### `SERVICE_COMMAND_HISTORY_STORE`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const SERVICE_COMMAND_HISTORY_STORE: StringName = &"gf.kernel.command_history_store"
```

命令历史服务 capability key。

<a id="member-gfarchitecture-constants-hook_get_required_dependencies"></a>

### `HOOK_GET_REQUIRED_DEPENDENCIES`

- API：`public`

```gdscript
const HOOK_GET_REQUIRED_DEPENDENCIES: StringName = &"get_required_dependencies"
```

声明式依赖聚合 Hook 名称。

<a id="member-gfarchitecture-constants-hook_get_required_models"></a>

### `HOOK_GET_REQUIRED_MODELS`

- API：`public`

```gdscript
const HOOK_GET_REQUIRED_MODELS: StringName = &"get_required_models"
```

声明式 Model 依赖 Hook 名称。

<a id="member-gfarchitecture-constants-hook_get_required_systems"></a>

### `HOOK_GET_REQUIRED_SYSTEMS`

- API：`public`

```gdscript
const HOOK_GET_REQUIRED_SYSTEMS: StringName = &"get_required_systems"
```

声明式 System 依赖 Hook 名称。

<a id="member-gfarchitecture-constants-hook_get_required_utilities"></a>

### `HOOK_GET_REQUIRED_UTILITIES`

- API：`public`

```gdscript
const HOOK_GET_REQUIRED_UTILITIES: StringName = &"get_required_utilities"
```

声明式 Utility 依赖 Hook 名称。

<a id="member-gfarchitecture-constants-hook_get_required_factories"></a>

### `HOOK_GET_REQUIRED_FACTORIES`

- API：`public`

```gdscript
const HOOK_GET_REQUIRED_FACTORIES: StringName = &"get_required_factories"
```

声明式工厂依赖 Hook 名称。

<a id="member-gfarchitecture-constants-default_snapshot_models_per_frame"></a>

### `DEFAULT_SNAPSHOT_MODELS_PER_FRAME`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_SNAPSHOT_MODELS_PER_FRAME: int = 8
```

分帧快照 API 默认每帧处理的 Model 数量。

## 属性

<a id="member-gfarchitecture-properties-module_async_init_timeout_seconds"></a>

### `module_async_init_timeout_seconds`

- API：`public`

```gdscript
var module_async_init_timeout_seconds: float = 0.0:
```

单个模块 async_init() 的最长等待时间。小于等于 0 时不启用超时。 默认关闭；项目可按自身加载预算显式启用。

<a id="member-gfarchitecture-properties-module_lifecycle_max_stage_passes"></a>

### `module_lifecycle_max_stage_passes`

- API：`public`

```gdscript
var module_lifecycle_max_stage_passes: int = 256:
```

单个生命周期阶段最多扫描模块注册表的次数，避免模块在生命周期中无限注册新模块。

<a id="member-gfarchitecture-properties-strict_dependency_lookup"></a>

### `strict_dependency_lookup`

- API：`public`

```gdscript
var strict_dependency_lookup: bool = false
```

严格依赖查询模式。开启后本架构查询不到本地模块时不会回退父级架构。

<a id="member-gfarchitecture-properties-fail_on_missing_declared_dependencies"></a>

### `fail_on_missing_declared_dependencies`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
var fail_on_missing_declared_dependencies: bool = false
```

声明式依赖缺失时是否直接使初始化失败。 模块可通过 get_required_dependencies() 或 get_required_models/systems/utilities/factories() 声明依赖。 开启后，init() 会在模块生命周期推进前校验依赖图，缺失依赖会中止本次初始化。

<a id="member-gfarchitecture-properties-last_initialization_error"></a>

### `last_initialization_error`

- API：`public`

```gdscript
var last_initialization_error: String = ""
```

最近一次初始化失败原因；没有失败时为空字符串。

## 方法

<a id="member-gfarchitecture-methods-_init"></a>

### `_init`

- API：`public`

```gdscript
func _init(parent_architecture: GFArchitecture = null) -> void:
```

创建架构容器，可选择指定父级架构作为依赖回退来源。

参数：

| 名称 | 说明 |
|---|---|
| `parent_architecture` | 父级架构；为空时不启用回退。 |

<a id="member-gfarchitecture-methods-is_inited"></a>

### `is_inited`

- API：`public`

```gdscript
func is_inited() -> bool:
```

检查架构是否已初始化。

返回：已初始化返回 true，否则返回 false。

<a id="member-gfarchitecture-methods-has_initialization_failed"></a>

### `has_initialization_failed`

- API：`public`

```gdscript
func has_initialization_failed() -> bool:
```

检查最近一次初始化是否因为框架级保护失败。

返回：最近一次初始化失败返回 true。

<a id="member-gfarchitecture-methods-is_lifecycle_active"></a>

### `is_lifecycle_active`

- API：`public`

```gdscript
func is_lifecycle_active() -> bool:
```

检查当前架构生命周期是否仍处于可安全继续异步写回的活动状态。

返回：正在初始化或已完成初始化，且未被 dispose() 或失败保护中断时返回 true。

<a id="member-gfarchitecture-methods-is_disposed"></a>

### `is_disposed`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_disposed() -> bool:
```

检查架构是否已经完成释放并进入不可恢复终态。

返回：dispose() 已完成时返回 true。

<a id="member-gfarchitecture-methods-is_disposing"></a>

### `is_disposing`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_disposing() -> bool:
```

检查架构是否正在执行释放回调。

返回：dispose() 已开始但尚未完成时返回 true。

<a id="member-gfarchitecture-methods-get_lifecycle_generation"></a>

### `get_lifecycle_generation`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_lifecycle_generation() -> int:
```

获取当前架构生命周期 generation。 每次 init()、dispose() 或初始化失败都会推进 generation，用于异步流程判断自身是否仍属于当前生命周期。

返回：当前生命周期 generation。

<a id="member-gfarchitecture-methods-is_lifecycle_generation_active"></a>

### `is_lifecycle_generation_active`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func is_lifecycle_generation_active(lifecycle_generation: int) -> bool:
```

检查指定生命周期 generation 是否仍是当前活动生命周期。

参数：

| 名称 | 说明 |
|---|---|
| `lifecycle_generation` | 由 get_lifecycle_generation() 读取到的 generation。 |

返回：generation 匹配且架构生命周期仍活动时返回 true。

<a id="member-gfarchitecture-methods-is_module_ready"></a>

### `is_module_ready`

- API：`public`

```gdscript
func is_module_ready(instance: Object) -> bool:
```

检查指定模块实例是否已经完成 ready 阶段。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | 由当前架构注册的模块实例。 |

返回：模块完成 ready 阶段时返回 true。

<a id="member-gfarchitecture-methods-fail_initialization"></a>

### `fail_initialization`

- API：`public`
- 首次版本：`1.23.2`

```gdscript
func fail_initialization(reason: String) -> void:
```

将当前架构标记为初始化失败，并唤醒等待初始化或 Installer 的调用方。 DISPOSING / DISPOSED 是不可恢复终态，迟到调用不会改写其状态或 generation。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 初始化失败原因。 |

<a id="member-gfarchitecture-methods-get_parent_architecture"></a>

### `get_parent_architecture`

- API：`public`

```gdscript
func get_parent_architecture() -> GFArchitecture:
```

获取父级架构。Scoped 架构会在本地未找到依赖时回退到父级架构查询。

返回：父级架构实例；未设置时返回 null。

<a id="member-gfarchitecture-methods-set_parent_architecture"></a>

### `set_parent_architecture`

- API：`public`

```gdscript
func set_parent_architecture(parent_architecture: GFArchitecture) -> void:
```

设置父级架构。不会接管父级生命周期。

参数：

| 名称 | 说明 |
|---|---|
| `parent_architecture` | 要作为依赖回退来源的父级架构。 |

<a id="member-gfarchitecture-methods-has_project_installers_applied"></a>

### `has_project_installers_applied`

- API：`public`

```gdscript
func has_project_installers_applied() -> bool:
```

检查项目级 Installer 是否已经应用到当前架构。

返回：已应用返回 true。

<a id="member-gfarchitecture-methods-is_project_installers_running"></a>

### `is_project_installers_running`

- API：`public`

```gdscript
func is_project_installers_running() -> bool:
```

检查项目级 Installer 是否正在应用。

返回：正在应用返回 true。

<a id="member-gfarchitecture-methods-begin_project_installers"></a>

### `begin_project_installers`

- API：`public`

```gdscript
func begin_project_installers() -> bool:
```

标记项目级 Installer 已开始应用。

返回：成功开始返回 true；已经完成或正在运行时返回 false。

<a id="member-gfarchitecture-methods-mark_project_installers_applied"></a>

### `mark_project_installers_applied`

- API：`public`

```gdscript
func mark_project_installers_applied() -> void:
```

标记项目级 Installer 已应用。由 Gf 启动入口调用。

<a id="member-gfarchitecture-methods-finish_project_installers"></a>

### `finish_project_installers`

- API：`public`

```gdscript
func finish_project_installers() -> void:
```

标记项目级 Installer 应用完成并唤醒等待方。

<a id="member-gfarchitecture-methods-create_binder"></a>

### `create_binder`

- API：`public`

```gdscript
func create_binder() -> GFBinder:
```

创建一个声明式装配器，便于 Installer 使用 fluent API 注册模块与工厂。

返回：绑定到当前架构的装配器。

结构：

- `return`: GFBinder owned by this architecture.

<a id="member-gfarchitecture-methods-init"></a>

### `init`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func init() -> bool:
```

初始化架构及所有注册的组件（三阶段）。 阶段一：调用所有模块的 init()，用于初始化自身内部变量。 阶段二：串行 await 所有模块的 async_init()，用于异步资源加载等操作。 阶段三：调用所有模块的 ready()，此时跨模块依赖获取是安全的。

返回：初始化完成且架构处于 ready 状态时返回 true。

<a id="member-gfarchitecture-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

销毁架构及所有注册的组件。

<a id="member-gfarchitecture-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(delta: float) -> void:
```

驱动所有参与 tick 的 System 与 Utility 的每帧更新。 在架构初始化完成后方可生效。 若已注册 GFTimeProvider，则自动将 delta 经过时间缩放/暂停处理后再传递给参与 tick 的模块。 设置了 ignore_pause 的模块在暂停时将接收原始 delta。 设置了 ignore_time_scale 的模块在未暂停时将跳过 time_scale。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 距上一帧的时间（秒）。 |

<a id="member-gfarchitecture-methods-physics_tick"></a>

### `physics_tick`

- API：`public`

```gdscript
func physics_tick(delta: float) -> void:
```

驱动所有参与 physics_tick 的 System 与 Utility 的每物理帧更新。 在架构初始化完成后方可生效。 若已注册 GFTimeProvider，则自动将 delta 经过时间缩放/暂停处理后再传递给参与 physics_tick 的模块。 设置了 ignore_pause 的模块在暂停时将接收原始 delta。 设置了 ignore_time_scale 的模块在未暂停时将跳过 time_scale。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 距上一物理帧的时间（秒）。 |

<a id="member-gfarchitecture-methods-send_command"></a>

### `send_command`

- API：`public`

```gdscript
func send_command(command: Object) -> Variant:
```

执行命令实例。支持 await：'await send_command(MyCommand.new())'。 command 缺少 execute() 方法时会输出 warning 并返回 null。

参数：

| 名称 | 说明 |
|---|---|
| `command` | 要执行的命令实例。 |

返回：命令 execute() 的返回值；空对象或缺少 execute() 时返回 null。

结构：

- `return`: Variant command result returned by command.execute().

<a id="member-gfarchitecture-methods-send_query"></a>

### `send_query`

- API：`public`

```gdscript
func send_query(query: Object) -> Variant:
```

执行查询实例并返回结果。 query 缺少 execute() 方法时会输出 warning 并返回 null。

参数：

| 名称 | 说明 |
|---|---|
| `query` | 要执行的查询实例。 |

返回：查询 execute() 的返回值；空对象或缺少 execute() 时返回 null。

结构：

- `return`: Variant query result returned by query.execute().

<a id="member-gfarchitecture-methods-send_event"></a>

### `send_event`

- API：`public`

```gdscript
func send_event(event_instance: Object) -> void:
```

通过事件系统发送类型事件实例。

参数：

| 名称 | 说明 |
|---|---|
| `event_instance` | 要分发的事件实例。 |

<a id="member-gfarchitecture-methods-register_event"></a>

### `register_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_event(event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
```

为脚本类型注册事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_type` | 要监听的脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |

<a id="member-gfarchitecture-methods-register_event_owned"></a>

### `register_event_owned`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_event_owned(owner: Object, event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
```

为脚本类型注册带拥有者的事件监听器。 拥有者注销或释放后，可通过 unregister_owner_events() 一次性清理相关监听。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 监听器拥有者。 |
| `event_type` | 要监听的脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |

<a id="member-gfarchitecture-methods-subscribe_event"></a>

### `subscribe_event`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func subscribe_event( event_type: Script, listener: GFEventListener, priority: int = 0, once: bool = false ) -> GFSubscriptionToken:
```

订阅脚本类型事件并返回可取消句柄。 listener 携带 owner 时返回的句柄会绑定该 owner 生命周期。`once` 订阅会在 首个回调开始前失效，保证嵌套事件派发不会重复进入同一订阅。

参数：

| 名称 | 说明 |
|---|---|
| `event_type` | 要订阅的脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |
| `once` | 是否在首个回调开始前自动取消订阅。 |

返回：可幂等取消的订阅句柄；架构不可修改或参数无效时返回非活动句柄。

<a id="member-gfarchitecture-methods-register_assignable_event"></a>

### `register_assignable_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_assignable_event(base_event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
```

为脚本类型注册可赋值事件监听器。 监听基类事件时，也会收到继承自该脚本类型的事件实例。

参数：

| 名称 | 说明 |
|---|---|
| `base_event_type` | 要监听的基类脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |

<a id="member-gfarchitecture-methods-register_assignable_event_owned"></a>

### `register_assignable_event_owned`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_assignable_event_owned( owner: Object, base_event_type: Script, listener: GFEventListener, priority: int = 0 ) -> void:
```

为脚本类型注册带拥有者的可赋值事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 监听器拥有者。 |
| `base_event_type` | 要监听的基类脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |

<a id="member-gfarchitecture-methods-subscribe_assignable_event"></a>

### `subscribe_assignable_event`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func subscribe_assignable_event( base_event_type: Script, listener: GFEventListener, priority: int = 0, once: bool = false ) -> GFSubscriptionToken:
```

订阅可赋值类型事件并返回可取消句柄。 listener 携带 owner 时返回的句柄会绑定该 owner 生命周期。监听基类脚本时， 订阅也会收到其派生脚本实例；`once` 在首个匹配回调开始前生效。

参数：

| 名称 | 说明 |
|---|---|
| `base_event_type` | 要订阅的基类脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |
| `once` | 是否在首个匹配回调开始前自动取消订阅。 |

返回：可幂等取消的订阅句柄；架构不可修改或参数无效时返回非活动句柄。

<a id="member-gfarchitecture-methods-unregister_event"></a>

### `unregister_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_event(event_type: Script, listener: GFEventListener) -> void:
```

为脚本类型注销事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_type` | 要注销的脚本类型。 |
| `listener` | 要移除的事件监听器契约。 |

<a id="member-gfarchitecture-methods-unregister_event_owned"></a>

### `unregister_event_owned`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unregister_event_owned(owner: Object, event_type: Script, listener: GFEventListener) -> void:
```

注销带拥有者的脚本类型事件监听器。 只移除 owner 与监听器回调都匹配的监听，不影响其它 owner 使用同一 Callable 注册的监听。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 注册监听时使用的拥有者。 |
| `event_type` | 要注销的脚本类型。 |
| `listener` | 要移除的事件监听器契约。 |

<a id="member-gfarchitecture-methods-unregister_assignable_event"></a>

### `unregister_assignable_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_assignable_event(base_event_type: Script, listener: GFEventListener) -> void:
```

注销可赋值类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `base_event_type` | 注册时使用的基类脚本类型。 |
| `listener` | 要移除的事件监听器契约。 |

<a id="member-gfarchitecture-methods-unregister_assignable_event_owned"></a>

### `unregister_assignable_event_owned`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unregister_assignable_event_owned(owner: Object, base_event_type: Script, listener: GFEventListener) -> void:
```

注销带拥有者的可赋值类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 注册监听时使用的拥有者。 |
| `base_event_type` | 注册时使用的基类脚本类型。 |
| `listener` | 要移除的事件监听器契约。 |

<a id="member-gfarchitecture-methods-register_simple_event"></a>

### `register_simple_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_simple_event(event_id: StringName, listener: GFEventListener) -> void:
```

注册轻量级 StringName 事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `listener` | 简单事件监听器契约。 |

<a id="member-gfarchitecture-methods-register_simple_event_owned"></a>

### `register_simple_event_owned`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_simple_event_owned(owner: Object, event_id: StringName, listener: GFEventListener) -> void:
```

注册带拥有者的轻量级 StringName 事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 监听器拥有者。 |
| `event_id` | StringName 事件标识符。 |
| `listener` | 简单事件监听器契约。 |

<a id="member-gfarchitecture-methods-subscribe_simple_event"></a>

### `subscribe_simple_event`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func subscribe_simple_event( event_id: StringName, listener: GFEventListener, once: bool = false ) -> GFSubscriptionToken:
```

订阅轻量级 StringName 事件并返回可取消句柄。 listener 携带 owner 时返回的句柄会绑定该 owner 生命周期。`once` 订阅会在 首个回调开始前失效，保证嵌套事件派发不会重复进入同一订阅。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `listener` | 简单事件监听器契约。 |
| `once` | 是否在首个回调开始前自动取消订阅。 |

返回：可幂等取消的订阅句柄；架构不可修改或参数无效时返回非活动句柄。

<a id="member-gfarchitecture-methods-unregister_simple_event"></a>

### `unregister_simple_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_simple_event(event_id: StringName, listener: GFEventListener) -> void:
```

注销轻量级 StringName 事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `listener` | 要移除的简单事件监听器契约。 |

<a id="member-gfarchitecture-methods-unregister_simple_event_owned"></a>

### `unregister_simple_event_owned`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unregister_simple_event_owned(owner: Object, event_id: StringName, listener: GFEventListener) -> void:
```

注销带拥有者的轻量级 StringName 事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 注册监听时使用的拥有者。 |
| `event_id` | StringName 事件标识符。 |
| `listener` | 要移除的简单事件监听器契约。 |

<a id="member-gfarchitecture-methods-unregister_owner_events"></a>

### `unregister_owner_events`

- API：`public`

```gdscript
func unregister_owner_events(owner: Object) -> void:
```

注销某个拥有者注册过的所有事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 要清理监听器的拥有者。 |

<a id="member-gfarchitecture-methods-send_simple_event"></a>

### `send_simple_event`

- API：`public`

```gdscript
func send_simple_event(event_id: StringName, payload: Variant = null) -> void:
```

发送轻量级 StringName 事件，避免高频 new() 带来的 GC 压力。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `payload` | 可选的事件附加数据。 |

结构：

- `payload`: Variant payload passed unchanged to simple event listeners.

<a id="member-gfarchitecture-methods-get_event_debug_stats"></a>

### `get_event_debug_stats`

- API：`public`

```gdscript
func get_event_debug_stats() -> Dictionary:
```

获取事件系统诊断统计。

返回：包含各事件轨道监听数量与 pending 操作数量的字典。

结构：

- `return`: Dictionary produced by GFTypeEventSystem.get_debug_stats().

<a id="member-gfarchitecture-methods-get_event_listener_diagnostics"></a>

### `get_event_listener_diagnostics`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_event_listener_diagnostics(options: Dictionary = {}) -> Dictionary:
```

获取事件监听器诊断明细。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 诊断选项，支持 include_entries。 |

返回：监听器诊断报告。

结构：

- `options`: Dictionary，可包含 include_entries。
- `return`: Dictionary produced by GFTypeEventSystem.get_listener_diagnostics().

<a id="member-gfarchitecture-methods-compact_event_listeners"></a>

### `compact_event_listeners`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func compact_event_listeners() -> int:
```

清理 owner 已释放的事件监听器。

返回：本次立即移除或排队清理的监听器数量。

<a id="member-gfarchitecture-methods-configure_event_debugging"></a>

### `configure_event_debugging`

- API：`public`

```gdscript
func configure_event_debugging( max_dispatch_depth: int = GFTypeEventSystem.DEFAULT_MAX_DISPATCH_DEPTH, trace_enabled: bool = false, max_trace_entries: int = 64 ) -> void:
```

配置事件系统调试与保护选项。

参数：

| 名称 | 说明 |
|---|---|
| `max_dispatch_depth` | 最大嵌套派发深度；小于等于 0 表示不限制。 |
| `trace_enabled` | 是否记录派发追踪。 |
| `max_trace_entries` | 最多保留的追踪条目数。 |

<a id="member-gfarchitecture-methods-get_event_dispatch_trace"></a>

### `get_event_dispatch_trace`

- API：`public`

```gdscript
func get_event_dispatch_trace() -> Array[Dictionary]:
```

获取最近事件派发追踪条目。

返回：从旧到新的追踪条目副本。

结构：

- `return`: Array of Dictionary trace entries with event, listener, owner, and dispatch metadata.

<a id="member-gfarchitecture-methods-clear_event_dispatch_trace"></a>

### `clear_event_dispatch_trace`

- API：`public`

```gdscript
func clear_event_dispatch_trace() -> void:
```

清空事件派发追踪。

<a id="member-gfarchitecture-methods-register_system"></a>

### `register_system`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_system(script_cls: Script, instance: Object) -> bool:
```

注册 System 实例。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 系统的脚本类。 |
| `instance` | 系统实例。 |

返回：注册成功、且运行时热注册完成生命周期推进时返回 true。

<a id="member-gfarchitecture-methods-register_model"></a>

### `register_model`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_model(script_cls: Script, instance: Object) -> bool:
```

注册 Model 实例。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 模型的脚本类。 |
| `instance` | 模型实例。 |

返回：注册成功、且运行时热注册完成生命周期推进时返回 true。

<a id="member-gfarchitecture-methods-register_utility"></a>

### `register_utility`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_utility(script_cls: Script, instance: Object) -> bool:
```

注册 Utility 实例。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 工具的脚本类。 |
| `instance` | 工具实例。 |

返回：注册成功、且运行时热注册完成生命周期推进时返回 true。

<a id="member-gfarchitecture-methods-replace_system"></a>

### `replace_system`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func replace_system(script_cls: Script, instance: Object) -> bool:
```

替换 System 实例。新实例成功完成当前生命周期阶段后才会提交替换。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 系统的脚本类。 |
| `instance` | 新系统实例。 |

返回：替换成功时返回 true。

<a id="member-gfarchitecture-methods-replace_model"></a>

### `replace_model`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func replace_model(script_cls: Script, instance: Object) -> bool:
```

替换 Model 实例。新实例成功完成当前生命周期阶段后才会提交替换。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 模型的脚本类。 |
| `instance` | 新模型实例。 |

返回：替换成功时返回 true。

<a id="member-gfarchitecture-methods-replace_utility"></a>

### `replace_utility`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func replace_utility(script_cls: Script, instance: Object) -> bool:
```

替换 Utility 实例。新实例成功完成当前生命周期阶段后才会提交替换。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 工具的脚本类。 |
| `instance` | 新工具实例。 |

返回：替换成功时返回 true。

<a id="member-gfarchitecture-methods-register_factory"></a>

### `register_factory`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_factory( script_cls: Script, factory: Callable, lifetime: int = GFBindingLifetimesBase.Lifetime.TRANSIENT ) -> bool:
```

注册短生命周期对象工厂。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要创建的脚本类型。 |
| `factory` | 返回对象实例的工厂回调。 |
| `lifetime` | 工厂生命周期，默认每次 create_instance() 都创建新对象。 |

返回：工厂注册成功时返回 true。

<a id="member-gfarchitecture-methods-register_factory_instance"></a>

### `register_factory_instance`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_factory_instance(script_cls: Script, instance: Object) -> bool:
```

注册已有实例作为短生命周期工厂入口。该实例以单例方式返回。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要创建的脚本类型。 |
| `instance` | 要暴露的实例。 |

返回：工厂入口注册成功时返回 true。

<a id="member-gfarchitecture-methods-replace_factory"></a>

### `replace_factory`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func replace_factory( script_cls: Script, factory: Callable, lifetime: int = GFBindingLifetimesBase.Lifetime.TRANSIENT ) -> bool:
```

替换短生命周期对象工厂。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要创建的脚本类型。 |
| `factory` | 新工厂回调。 |
| `lifetime` | 工厂生命周期。 |

返回：工厂替换成功时返回 true。

<a id="member-gfarchitecture-methods-replace_factory_instance"></a>

### `replace_factory_instance`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func replace_factory_instance(script_cls: Script, instance: Object) -> bool:
```

替换已有实例工厂入口。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要创建的脚本类型。 |
| `instance` | 要暴露的实例。 |

返回：工厂入口替换成功时返回 true。

<a id="member-gfarchitecture-methods-unregister_factory"></a>

### `unregister_factory`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unregister_factory(script_cls: Script) -> bool:
```

注销短生命周期对象工厂。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要移除的脚本类型。 |

返回：存在并成功注销工厂时返回 true。

<a id="member-gfarchitecture-methods-has_factory"></a>

### `has_factory`

- API：`public`

```gdscript
func has_factory(script_cls: Script) -> bool:
```

检查当前架构或父级架构是否注册了指定工厂。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要查询的脚本类型。 |

返回：工厂存在时返回 true。

<a id="member-gfarchitecture-methods-register_service"></a>

### `register_service`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_service(service_key: StringName, provider: Object) -> bool:
```

注册运行时服务 capability。 同一 service_key 在同一架构内只能有一个 provider；子架构可通过父级回退读取父级服务。

参数：

| 名称 | 说明 |
|---|---|
| `service_key` | 稳定服务键。 |
| `provider` | 服务提供对象。 |

返回：注册成功时返回 true。

<a id="member-gfarchitecture-methods-unregister_service"></a>

### `unregister_service`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_service(service_key: StringName, provider: Object = null) -> bool:
```

注销运行时服务 capability。

参数：

| 名称 | 说明 |
|---|---|
| `service_key` | 稳定服务键。 |
| `provider` | 可选的当前服务提供对象；传入时必须与已注册 provider 匹配。 |

返回：注销成功时返回 true。

<a id="member-gfarchitecture-methods-get_service"></a>

### `get_service`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_service(service_key: StringName, include_parent: bool = true) -> Object:
```

获取运行时服务 capability。

参数：

| 名称 | 说明 |
|---|---|
| `service_key` | 稳定服务键。 |
| `include_parent` | 为 true 时允许沿父级架构查找。 |

返回：服务提供对象；不存在时返回 null。

<a id="member-gfarchitecture-methods-has_service"></a>

### `has_service`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_service(service_key: StringName, include_parent: bool = true) -> bool:
```

检查运行时服务 capability 是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `service_key` | 稳定服务键。 |
| `include_parent` | 为 true 时允许沿父级架构查找。 |

返回：服务存在时返回 true。

<a id="member-gfarchitecture-methods-register_system_alias"></a>

### `register_system_alias`

- API：`public`

```gdscript
func register_system_alias(alias_cls: Script, target_cls: Script) -> void:
```

为已注册 System 增加一个额外查询别名。 适合把具体实现以抽象基类或接口式脚本暴露给调用方。

参数：

| 名称 | 说明 |
|---|---|
| `alias_cls` | 调用 get_system() 时使用的别名脚本类。 |
| `target_cls` | 已注册 System 的实际脚本类。 |

<a id="member-gfarchitecture-methods-register_model_alias"></a>

### `register_model_alias`

- API：`public`

```gdscript
func register_model_alias(alias_cls: Script, target_cls: Script) -> void:
```

为已注册 Model 增加一个额外查询别名。

参数：

| 名称 | 说明 |
|---|---|
| `alias_cls` | 调用 get_model() 时使用的别名脚本类。 |
| `target_cls` | 已注册 Model 的实际脚本类。 |

<a id="member-gfarchitecture-methods-register_utility_alias"></a>

### `register_utility_alias`

- API：`public`

```gdscript
func register_utility_alias(alias_cls: Script, target_cls: Script) -> void:
```

为已注册 Utility 增加一个额外查询别名。

参数：

| 名称 | 说明 |
|---|---|
| `alias_cls` | 调用 get_utility() 时使用的别名脚本类。 |
| `target_cls` | 已注册 Utility 的实际脚本类。 |

<a id="member-gfarchitecture-methods-unregister_system_alias"></a>

### `unregister_system_alias`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unregister_system_alias(alias_cls: Script) -> void:
```

注销 System 查询别名，不影响目标 System 实例。

参数：

| 名称 | 说明 |
|---|---|
| `alias_cls` | 要移除的别名脚本类。 |

<a id="member-gfarchitecture-methods-unregister_model_alias"></a>

### `unregister_model_alias`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unregister_model_alias(alias_cls: Script) -> void:
```

注销 Model 查询别名，不影响目标 Model 实例。

参数：

| 名称 | 说明 |
|---|---|
| `alias_cls` | 要移除的别名脚本类。 |

<a id="member-gfarchitecture-methods-unregister_utility_alias"></a>

### `unregister_utility_alias`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unregister_utility_alias(alias_cls: Script) -> void:
```

注销 Utility 查询别名，不影响目标 Utility 实例。

参数：

| 名称 | 说明 |
|---|---|
| `alias_cls` | 要移除的别名脚本类。 |

<a id="member-gfarchitecture-methods-register_system_instance"></a>

### `register_system_instance`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_system_instance(instance: Object) -> bool:
```

便捷注册 System 实例，自动从实例获取脚本类作为注册键。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | 系统实例，必须附加有 GDScript 脚本。 |

返回：注册成功时返回 true。

<a id="member-gfarchitecture-methods-register_model_instance"></a>

### `register_model_instance`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_model_instance(instance: Object) -> bool:
```

便捷注册 Model 实例，自动从实例获取脚本类作为注册键。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | 模型实例，必须附加有 GDScript 脚本。 |

返回：注册成功时返回 true。

<a id="member-gfarchitecture-methods-register_utility_instance"></a>

### `register_utility_instance`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_utility_instance(instance: Object) -> bool:
```

便捷注册 Utility 实例，自动从实例获取脚本类作为注册键。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | 工具实例，必须附加有 GDScript 脚本。 |

返回：注册成功时返回 true。

<a id="member-gfarchitecture-methods-register_system_instance_as"></a>

### `register_system_instance_as`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_system_instance_as(instance: Object, alias_cls: Script) -> bool:
```

便捷注册 System，并同时以 alias_cls 作为额外查询键。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | System 实例。 |
| `alias_cls` | 额外查询脚本类。 |

返回：注册成功并写入 alias 时返回 true。

<a id="member-gfarchitecture-methods-register_model_instance_as"></a>

### `register_model_instance_as`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_model_instance_as(instance: Object, alias_cls: Script) -> bool:
```

便捷注册 Model，并同时以 alias_cls 作为额外查询键。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | Model 实例。 |
| `alias_cls` | 额外查询脚本类。 |

返回：注册成功并写入 alias 时返回 true。

<a id="member-gfarchitecture-methods-register_utility_instance_as"></a>

### `register_utility_instance_as`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_utility_instance_as(instance: Object, alias_cls: Script) -> bool:
```

便捷注册 Utility，并同时以 alias_cls 作为额外查询键。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | Utility 实例。 |
| `alias_cls` | 额外查询脚本类。 |

返回：注册成功并写入 alias 时返回 true。

<a id="member-gfarchitecture-methods-unregister_system"></a>

### `unregister_system`

- API：`public`

```gdscript
func unregister_system(script_cls: Script) -> void:
```

注销 System 实例。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 系统的脚本类。 |

<a id="member-gfarchitecture-methods-unregister_model"></a>

### `unregister_model`

- API：`public`

```gdscript
func unregister_model(script_cls: Script) -> void:
```

注销 Model 实例。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 模型的脚本类。 |

<a id="member-gfarchitecture-methods-unregister_utility"></a>

### `unregister_utility`

- API：`public`

```gdscript
func unregister_utility(script_cls: Script) -> void:
```

注销 Utility 实例。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 工具的脚本类。 |

<a id="member-gfarchitecture-methods-get_system"></a>

### `get_system`

- API：`public`

```gdscript
func get_system(script_cls: Script, require_ready: bool = false) -> Object:
```

通过脚本类获取 System 实例。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 脚本类。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：系统实例，如果未找到则返回 null。

<a id="member-gfarchitecture-methods-get_model"></a>

### `get_model`

- API：`public`

```gdscript
func get_model(script_cls: Script, require_ready: bool = false) -> Object:
```

通过脚本类获取 Model 实例。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 脚本类。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：模型实例，如果未找到则返回 null。

<a id="member-gfarchitecture-methods-get_utility"></a>

### `get_utility`

- API：`public`

```gdscript
func get_utility(script_cls: Script, require_ready: bool = false) -> Object:
```

通过脚本类获取 Utility 实例。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 脚本类。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：工具实例，如果未找到则返回 null。

<a id="member-gfarchitecture-methods-find_system"></a>

### `find_system`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func find_system(script_cls: Script, require_ready: bool = false) -> Object:
```

可选查找 System 实例，未找到时不输出严格依赖缺失错误。 非严格模式沿用普通查询的父级回退与 alias 遮蔽规则；严格模式只检查当前架构。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 脚本类。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：系统实例；可选依赖不存在或尚未 ready 时返回 null。

<a id="member-gfarchitecture-methods-find_model"></a>

### `find_model`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func find_model(script_cls: Script, require_ready: bool = false) -> Object:
```

可选查找 Model 实例，未找到时不输出严格依赖缺失错误。 非严格模式沿用普通查询的父级回退与 alias 遮蔽规则；严格模式只检查当前架构。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 脚本类。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：模型实例；可选依赖不存在或尚未 ready 时返回 null。

<a id="member-gfarchitecture-methods-find_utility"></a>

### `find_utility`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func find_utility(script_cls: Script, require_ready: bool = false) -> Object:
```

可选查找 Utility 实例，未找到时不输出严格依赖缺失错误。 非严格模式沿用普通查询的父级回退与 alias 遮蔽规则；严格模式只检查当前架构。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 脚本类。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：工具实例；可选依赖不存在或尚未 ready 时返回 null。

<a id="member-gfarchitecture-methods-get_local_system"></a>

### `get_local_system`

- API：`public`

```gdscript
func get_local_system(script_cls: Script, require_ready: bool = false) -> Object:
```

仅从当前架构获取 System，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 脚本类。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前架构中的系统实例，如果未找到则返回 null。

<a id="member-gfarchitecture-methods-get_local_model"></a>

### `get_local_model`

- API：`public`

```gdscript
func get_local_model(script_cls: Script, require_ready: bool = false) -> Object:
```

仅从当前架构获取 Model，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 脚本类。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前架构中的模型实例，如果未找到则返回 null。

<a id="member-gfarchitecture-methods-get_local_utility"></a>

### `get_local_utility`

- API：`public`

```gdscript
func get_local_utility(script_cls: Script, require_ready: bool = false) -> Object:
```

仅从当前架构获取 Utility，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 脚本类。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前架构中的工具实例，如果未找到则返回 null。

<a id="member-gfarchitecture-methods-create_instance"></a>

### `create_instance`

- API：`public`

```gdscript
func create_instance(script_cls: Script) -> Object:
```

通过已注册工厂创建短生命周期对象。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要创建的脚本类型。 |

返回：新对象实例；没有工厂或工厂返回非对象时返回 null。

<a id="member-gfarchitecture-methods-inject_object"></a>

### `inject_object`

- API：`public`

```gdscript
func inject_object(instance: Object) -> void:
```

向任意对象注入当前架构依赖。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | 需要注入的对象。 |

<a id="member-gfarchitecture-methods-inject_node_tree"></a>

### `inject_node_tree`

- API：`public`

```gdscript
func inject_node_tree(node: Node) -> void:
```

递归向节点树中实现注入 Hook 的节点注入当前架构。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 节点树根节点。 |

<a id="member-gfarchitecture-methods-get_all_models_state"></a>

### `get_all_models_state`

- API：`public`
- 首次版本：`3.0.0`

```gdscript
func get_all_models_state() -> Dictionary:
```

收集所有已注册 Model 的状态快照。 捕获前会验证每个 Model 都有唯一稳定存档键；任一目标无效时整个捕获失败， 且失败 Result 不包含 `snapshot`，持久化层不得提交失败结果。

返回：显式捕获 Result；成功时需取 `result.snapshot` 交给存储或恢复接口。

结构：

- `return`: Dictionary with ok: bool, optional snapshot: Dictionary keyed by stable model save key, and error: String. A failed result never contains snapshot.

<a id="member-gfarchitecture-methods-get_all_models_state_async"></a>

### `get_all_models_state_async`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_all_models_state_async(options: Dictionary = {}) -> Dictionary:
```

分帧收集所有已注册 Model 的状态快照。 为保证耦合 Model 的默认持久化一致性，所有 `Model.to_dict()` 会在首次让帧前 同步冻结；`max_models_per_frame` 只分摊冻结数据的物化，不分摊 `to_dict()` 本身。 等待期间若 Model 注册表身份或稳定键发生变化，捕获会显式失败且不返回 snapshot。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选参数，支持 max_models_per_frame；小于等于 0 时不主动让出帧。 |

返回：显式捕获 Result；成功时需取 `result.snapshot` 交给存储或恢复接口。

结构：

- `options`: Dictionary，可包含 max_models_per_frame: int。
- `return`: Dictionary with ok: bool, optional snapshot: Dictionary keyed by stable model save key, and error: String. A failed result never contains snapshot.

<a id="member-gfarchitecture-methods-restore_all_models_state"></a>

### `restore_all_models_state`

- API：`public`
- 首次版本：`3.0.0`

```gdscript
func restore_all_models_state(data: Dictionary) -> Dictionary:
```

从状态字典恢复所有已注册 Model 的数据。 `data` 必须是成功捕获 Result 的 `snapshot` 字段，而不是 Result 外壳。 恢复会先验证全部目标并保存基线，再应用并核对每个 Model；任一步失败会回滚 本事务已应用的全部 Model。快照键集合必须与当前直接注册的 Model 精确匹配； 未知键或缺少任一已注册 Model 都会在写入前被拒绝。 失败时 `phase` 标记 validate/apply/commit；`rolled_back` 表示失败前的已应用状态 是否全部通过基线核对，validate 零写入失败固定为 false。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 由 get_all_models_state() 成功 Result 的 `snapshot` 字段。 |

返回：原子恢复 Result；任一步失败时回滚已应用 Model。

结构：

- `data`: Inner snapshot Dictionary keyed by stable model save key, storing serialized model data; do not pass the outer capture Result.
- `return`: Dictionary with ok: bool, phase: StringName, rolled_back: bool, and error: String.

<a id="member-gfarchitecture-methods-restore_all_models_state_async"></a>

### `restore_all_models_state_async`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func restore_all_models_state_async( data: Dictionary, options: Dictionary = {} ) -> Dictionary:
```

分帧恢复所有已注册 Model 的数据。 与同步版本使用相同的 validate/apply/commit 事务；Model 会按 `max_models_per_frame` 分帧应用和核对，失败时回滚本事务已应用的全部 Model。 快照键集合必须与当前直接注册的 Model 精确匹配。 失败时 `phase` 标记 validate/apply/commit；`rolled_back` 表示失败前的已应用状态 是否全部通过基线核对，validate 零写入失败固定为 false。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 由 get_all_models_state() 或 get_all_models_state_async() 成功 Result 的 `snapshot` 字段。 |
| `options` | 可选参数，支持 max_models_per_frame；小于等于 0 时不主动让出帧。 |

返回：原子恢复 Result；任一步失败时回滚已应用 Model。

结构：

- `data`: Inner snapshot Dictionary keyed by stable model save key, storing serialized model data; do not pass the outer capture Result.
- `options`: Dictionary，可包含 max_models_per_frame: int。
- `return`: Dictionary with ok: bool, phase: StringName, rolled_back: bool, and error: String.

<a id="member-gfarchitecture-methods-get_global_snapshot"></a>

### `get_global_snapshot`

- API：`public`
- 首次版本：`3.0.0`

```gdscript
func get_global_snapshot() -> Dictionary:
```

获取整个框架的全局快照，包含所有 Model 状态以及可选命令历史记录。 捕获成功的 snapshot 固定包含 `format_version` 与 `models`，注册完整命令历史 服务时还包含 Dictionary 形式的 `command_history`。任一捕获步骤失败时 Result 不包含 snapshot，持久化层不得提交失败结果。

返回：显式捕获 Result；成功时需取 `result.snapshot` 交给存储或恢复接口。

结构：

- `return`: Dictionary with ok: bool, optional snapshot: Dictionary with format_version: int, models: Dictionary, and optional command_history: Dictionary, and error: String. A failed result never contains snapshot.

<a id="member-gfarchitecture-methods-get_global_snapshot_async"></a>

### `get_global_snapshot_async`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_global_snapshot_async(options: Dictionary = {}) -> Dictionary:
```

分帧获取整个框架的全局快照。 为保证 Model 与命令历史属于同一默认捕获点，全部 `Model.to_dict()` 与命令历史 会在首次让帧前同步冻结；`max_models_per_frame` 只分摊冻结 Model 数据的物化。 等待期间若 Model 注册表身份或稳定键发生变化，捕获会显式失败且不返回 snapshot。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选参数，支持 max_models_per_frame；小于等于 0 时不主动让出帧。 |

返回：显式捕获 Result；成功时需取 `result.snapshot` 交给存储或恢复接口。

结构：

- `options`: Dictionary，可包含 max_models_per_frame: int。
- `return`: Dictionary with ok: bool, optional snapshot: Dictionary with format_version: int, models: Dictionary, and optional command_history: Dictionary, and error: String. A failed result never contains snapshot.

<a id="member-gfarchitecture-methods-restore_global_snapshot"></a>

### `restore_global_snapshot`

- API：`public`
- 首次版本：`3.0.0`

```gdscript
func restore_global_snapshot( data: Dictionary, command_builder: Callable = Callable() ) -> Dictionary:
```

从全局快照中恢复整个框架的状态，包含 Model 状态以及可选命令历史记录。 `data` 必须是成功捕获 Result 的 `snapshot` 字段。仅接受当前 `format_version`、Dictionary `models` 与可选 Dictionary `command_history`； `models` 键集合必须与当前直接注册的 Model 精确匹配；不兼容旧式无版本快照、 缺项/未知 Model 键或 Array 命令历史。 恢复会先验证全部输入并保存 Model/历史基线，再应用 Model，最后提交并核对历史。 validate 不写入；apply 或 commit 失败时会回滚全部已应用 Model 与命令历史。 恢复命令历史必须传入可实例化具体业务命令的 `command_builder`。 `rolled_back` 表示失败前的已应用状态是否全部通过基线核对； validate 零写入失败固定为 false。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 由 get_global_snapshot() 成功 Result 的 `snapshot` 字段。 |
| `command_builder` | 【可选】如果需要恢复历史记录，必须传入用于反序列化具体 Command 实例的 Callable。 |

返回：原子恢复 Result；validate、apply 或 commit 失败时回滚全部 Model 与命令历史。

结构：

- `data`: Inner snapshot Dictionary with the current format_version, models, and optional command_history fields; do not pass the outer capture Result.
- `return`: Dictionary with ok: bool, phase: StringName, rolled_back: bool, and error: String.

<a id="member-gfarchitecture-methods-restore_global_snapshot_async"></a>

### `restore_global_snapshot_async`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func restore_global_snapshot_async( data: Dictionary, command_builder: Callable = Callable(), options: Dictionary = {} ) -> Dictionary:
```

分帧恢复整个框架的全局快照。 与同步版本使用相同的 validate/apply/commit 事务；Model 会分帧应用并逐项核对， 命令历史只在全部 Model 成功后提交。任一阶段失败都会回滚全部已应用状态。 `models` 键集合必须与当前直接注册的 Model 精确匹配。 `rolled_back` 表示失败前的已应用状态是否全部通过基线核对； validate 零写入失败固定为 false。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 由 get_global_snapshot() 或 get_global_snapshot_async() 成功 Result 的 `snapshot` 字段。 |
| `command_builder` | 【可选】如果需要恢复历史记录，必须传入用于反序列化具体 Command 实例的 Callable。 |
| `options` | 可选参数，支持 max_models_per_frame；小于等于 0 时不主动让出帧。 |

返回：原子恢复 Result；validate、apply 或 commit 失败时回滚全部 Model 与命令历史。

结构：

- `data`: Inner snapshot Dictionary with the current format_version, models, and optional command_history fields; do not pass the outer capture Result.
- `options`: Dictionary，可包含 max_models_per_frame: int。
- `return`: Dictionary with ok: bool, phase: StringName, rolled_back: bool, and error: String.

<a id="member-gfarchitecture-methods-get_debug_lifecycle_state"></a>

### `get_debug_lifecycle_state`

- API：`public`

```gdscript
func get_debug_lifecycle_state() -> Dictionary:
```

获取架构模块生命周期诊断快照。

返回：包含 Model、System、Utility、Factory、Alias 与 Tick 缓存状态的字典。

结构：

- `return`: Dictionary containing lifecycle flags, registered module summaries, factory summaries, alias counts, and tick cache counts.

<a id="member-gfarchitecture-methods-get_binding_diagnostics"></a>

### `get_binding_diagnostics`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_binding_diagnostics(options: Dictionary = {}) -> Dictionary:
```

获取架构绑定图诊断。 该报告只读取当前注册表、别名、工厂和父级链摘要，不触发依赖解析或生命周期推进。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选参数，支持 include_entries、include_parent_chain 与 max_parent_depth。 |

返回：绑定图诊断报告。

结构：

- `options`: Dictionary with optional bool keys include_entries/include_parent_chain and int key max_parent_depth.
- `return`: Dictionary containing ok, registry counts, registry entries, factory bindings, parent_chain, parent_chain_cycle_detected, parent_chain_truncated, lifecycle flags, and issues.

<a id="member-gfarchitecture-methods-get_dependency_diagnostics"></a>

### `get_dependency_diagnostics`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_dependency_diagnostics(options: Dictionary = {}) -> Dictionary:
```

获取架构中已注册模块的声明式依赖诊断报告。 模块可选择实现 get_required_dependencies() 或 get_required_models/systems/utilities/factories()。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选参数，支持 include_parent_lookup 与 include_factories。 |

返回：统一诊断报告字典。

结构：

- `options`: Dictionary with optional bool keys include_parent_lookup and include_factories.
- `return`: Dictionary dependency diagnostics report with modules, resolved_dependencies, missing_dependencies, parent-chain cycle issue records, issue counts, and next_action.

<a id="member-gfarchitecture-methods-_on_init"></a>

### `_on_init`

- API：`protected`

```gdscript
func _on_init() -> void:
```

内部初始化回调，子类可重写。

<a id="member-gfarchitecture-methods-_on_dispose"></a>

### `_on_dispose`

- API：`protected`

```gdscript
func _on_dispose() -> void:
```

内部销毁回调，子类可重写。
