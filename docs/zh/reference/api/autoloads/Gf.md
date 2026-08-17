# Gf

[API Reference](../index.md) / [Kernel](../kernel.md) / [AutoLoad 索引](index.md)

- Owner 类型：`autoload`
- 路径：`addons/gf/kernel/core/gf.gd`
- 模块：`Kernel`
- 包：`gf.kernel`
- 继承：`Node`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`1.0.0`

GF Framework 的全局运行时入口。 负责项目架构的安装、初始化、查询、替换与释放，并作为受控 AutoLoad 注册到场景树根节点。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`INSTALLERS_SETTING`](#member-gf-constants-installers_setting) | `const INSTALLERS_SETTING: String = "gf/project/installers"` |
| 常量 | [`FAIL_ON_INSTALLER_ERROR_SETTING`](#member-gf-constants-fail_on_installer_error_setting) | `const FAIL_ON_INSTALLER_ERROR_SETTING: String = "gf/project/fail_on_installer_error"` |
| 常量 | [`INSTALLER_TIMEOUT_SETTING`](#member-gf-constants-installer_timeout_setting) | `const INSTALLER_TIMEOUT_SETTING: String = "gf/project/installer_timeout_seconds"` |
| 属性 | [`architecture`](#member-gf-properties-architecture) | `var architecture: GFArchitecture:` |
| 方法 | [`has_architecture`](#member-gf-methods-has_architecture) | `func has_architecture() -> bool:` |
| 方法 | [`create_architecture`](#member-gf-methods-create_architecture) | `func create_architecture() -> GFArchitecture:` |
| 方法 | [`create_binder`](#member-gf-methods-create_binder) | `func create_binder() -> Variant:` |
| 方法 | [`get_architecture`](#member-gf-methods-get_architecture) | `func get_architecture() -> GFArchitecture:` |
| 方法 | [`set_architecture`](#member-gf-methods-set_architecture) | `func set_architecture(architecture_instance: GFArchitecture) -> bool:` |
| 方法 | [`init`](#member-gf-methods-init) | `func init() -> bool:` |
| 方法 | [`register_system`](#member-gf-methods-register_system) | `func register_system(instance: Object) -> bool:` |
| 方法 | [`register_model`](#member-gf-methods-register_model) | `func register_model(instance: Object) -> bool:` |
| 方法 | [`register_utility`](#member-gf-methods-register_utility) | `func register_utility(instance: Object) -> bool:` |
| 方法 | [`replace_system`](#member-gf-methods-replace_system) | `func replace_system(instance: Object) -> bool:` |
| 方法 | [`replace_model`](#member-gf-methods-replace_model) | `func replace_model(instance: Object) -> bool:` |
| 方法 | [`replace_utility`](#member-gf-methods-replace_utility) | `func replace_utility(instance: Object) -> bool:` |
| 方法 | [`register_factory`](#member-gf-methods-register_factory) | `func register_factory( script_cls: Script, factory: Callable, lifetime: int = GFBindingLifetimesBase.Lifetime.TRANSIENT ) -> bool:` |
| 方法 | [`register_factory_instance`](#member-gf-methods-register_factory_instance) | `func register_factory_instance(script_cls: Script, instance: Object) -> bool:` |
| 方法 | [`replace_factory`](#member-gf-methods-replace_factory) | `func replace_factory( script_cls: Script, factory: Callable, lifetime: int = GFBindingLifetimesBase.Lifetime.TRANSIENT ) -> bool:` |
| 方法 | [`replace_factory_instance`](#member-gf-methods-replace_factory_instance) | `func replace_factory_instance(script_cls: Script, instance: Object) -> bool:` |
| 方法 | [`unregister_factory`](#member-gf-methods-unregister_factory) | `func unregister_factory(script_cls: Script) -> bool:` |
| 方法 | [`has_factory`](#member-gf-methods-has_factory) | `func has_factory(script_cls: Script) -> bool:` |
| 方法 | [`create_instance`](#member-gf-methods-create_instance) | `func create_instance(script_cls: Script) -> Object:` |
| 方法 | [`inject_object`](#member-gf-methods-inject_object) | `func inject_object(instance: Object) -> void:` |
| 方法 | [`inject_node_tree`](#member-gf-methods-inject_node_tree) | `func inject_node_tree(node: Node) -> void:` |
| 方法 | [`register_system_as`](#member-gf-methods-register_system_as) | `func register_system_as(instance: Object, alias_cls: Script) -> bool:` |
| 方法 | [`register_model_as`](#member-gf-methods-register_model_as) | `func register_model_as(instance: Object, alias_cls: Script) -> bool:` |
| 方法 | [`register_utility_as`](#member-gf-methods-register_utility_as) | `func register_utility_as(instance: Object, alias_cls: Script) -> bool:` |
| 方法 | [`register_system_alias`](#member-gf-methods-register_system_alias) | `func register_system_alias(alias_cls: Script, target_cls: Script) -> void:` |
| 方法 | [`register_model_alias`](#member-gf-methods-register_model_alias) | `func register_model_alias(alias_cls: Script, target_cls: Script) -> void:` |
| 方法 | [`register_utility_alias`](#member-gf-methods-register_utility_alias) | `func register_utility_alias(alias_cls: Script, target_cls: Script) -> void:` |
| 方法 | [`unregister_system_alias`](#member-gf-methods-unregister_system_alias) | `func unregister_system_alias(alias_cls: Script) -> void:` |
| 方法 | [`unregister_model_alias`](#member-gf-methods-unregister_model_alias) | `func unregister_model_alias(alias_cls: Script) -> void:` |
| 方法 | [`unregister_utility_alias`](#member-gf-methods-unregister_utility_alias) | `func unregister_utility_alias(alias_cls: Script) -> void:` |
| 方法 | [`get_system`](#member-gf-methods-get_system) | `func get_system(script_cls: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_model`](#member-gf-methods-get_model) | `func get_model(script_cls: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_utility`](#member-gf-methods-get_utility) | `func get_utility(script_cls: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_system`](#member-gf-methods-get_local_system) | `func get_local_system(script_cls: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_model`](#member-gf-methods-get_local_model) | `func get_local_model(script_cls: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_utility`](#member-gf-methods-get_local_utility) | `func get_local_utility(script_cls: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`send_command`](#member-gf-methods-send_command) | `func send_command(command: Object) -> Variant:` |
| 方法 | [`send_query`](#member-gf-methods-send_query) | `func send_query(query: Object) -> Variant:` |
| 方法 | [`send_event`](#member-gf-methods-send_event) | `func send_event(event_instance: Object) -> void:` |
| 方法 | [`send_simple_event`](#member-gf-methods-send_simple_event) | `func send_simple_event(event_id: StringName, payload: Variant = null) -> void:` |
| 方法 | [`configure_event_debugging`](#member-gf-methods-configure_event_debugging) | `func configure_event_debugging( max_dispatch_depth: int = GFTypeEventSystem.DEFAULT_MAX_DISPATCH_DEPTH, trace_enabled: bool = false, max_trace_entries: int = 64 ) -> void:` |
| 方法 | [`get_event_debug_stats`](#member-gf-methods-get_event_debug_stats) | `func get_event_debug_stats() -> Dictionary:` |
| 方法 | [`get_event_listener_diagnostics`](#member-gf-methods-get_event_listener_diagnostics) | `func get_event_listener_diagnostics(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`compact_event_listeners`](#member-gf-methods-compact_event_listeners) | `func compact_event_listeners() -> int:` |
| 方法 | [`get_event_dispatch_trace`](#member-gf-methods-get_event_dispatch_trace) | `func get_event_dispatch_trace() -> Array[Dictionary]:` |
| 方法 | [`clear_event_dispatch_trace`](#member-gf-methods-clear_event_dispatch_trace) | `func clear_event_dispatch_trace() -> void:` |
| 方法 | [`listen`](#member-gf-methods-listen) | `func listen(event_type: Script, listener: GFEventListener, priority: int = 0) -> void:` |
| 方法 | [`listen_owned`](#member-gf-methods-listen_owned) | `func listen_owned(listener_owner: Object, event_type: Script, listener: GFEventListener, priority: int = 0) -> void:` |
| 方法 | [`subscribe`](#member-gf-methods-subscribe) | `func subscribe( event_type: Script, listener: GFEventListener, priority: int = 0, once: bool = false ) -> GFSubscriptionToken:` |
| 方法 | [`listen_assignable`](#member-gf-methods-listen_assignable) | `func listen_assignable(base_event_type: Script, listener: GFEventListener, priority: int = 0) -> void:` |
| 方法 | [`listen_assignable_owned`](#member-gf-methods-listen_assignable_owned) | `func listen_assignable_owned( listener_owner: Object, base_event_type: Script, listener: GFEventListener, priority: int = 0 ) -> void:` |
| 方法 | [`subscribe_assignable`](#member-gf-methods-subscribe_assignable) | `func subscribe_assignable( base_event_type: Script, listener: GFEventListener, priority: int = 0, once: bool = false ) -> GFSubscriptionToken:` |
| 方法 | [`unlisten`](#member-gf-methods-unlisten) | `func unlisten(event_type: Script, listener: GFEventListener) -> void:` |
| 方法 | [`unlisten_owned`](#member-gf-methods-unlisten_owned) | `func unlisten_owned(listener_owner: Object, event_type: Script, listener: GFEventListener) -> void:` |
| 方法 | [`unlisten_assignable`](#member-gf-methods-unlisten_assignable) | `func unlisten_assignable(base_event_type: Script, listener: GFEventListener) -> void:` |
| 方法 | [`unlisten_assignable_owned`](#member-gf-methods-unlisten_assignable_owned) | `func unlisten_assignable_owned(listener_owner: Object, base_event_type: Script, listener: GFEventListener) -> void:` |
| 方法 | [`listen_simple`](#member-gf-methods-listen_simple) | `func listen_simple(event_id: StringName, listener: GFEventListener) -> void:` |
| 方法 | [`listen_simple_owned`](#member-gf-methods-listen_simple_owned) | `func listen_simple_owned(listener_owner: Object, event_id: StringName, listener: GFEventListener) -> void:` |
| 方法 | [`subscribe_simple`](#member-gf-methods-subscribe_simple) | `func subscribe_simple( event_id: StringName, listener: GFEventListener, once: bool = false ) -> GFSubscriptionToken:` |
| 方法 | [`unlisten_simple`](#member-gf-methods-unlisten_simple) | `func unlisten_simple(event_id: StringName, listener: GFEventListener) -> void:` |
| 方法 | [`unlisten_simple_owned`](#member-gf-methods-unlisten_simple_owned) | `func unlisten_simple_owned(listener_owner: Object, event_id: StringName, listener: GFEventListener) -> void:` |
| 方法 | [`unlisten_owner`](#member-gf-methods-unlisten_owner) | `func unlisten_owner(listener_owner: Object) -> void:` |
| 方法 | [`unregister_system`](#member-gf-methods-unregister_system) | `func unregister_system(script_cls: Script) -> bool:` |
| 方法 | [`unregister_model`](#member-gf-methods-unregister_model) | `func unregister_model(script_cls: Script) -> bool:` |
| 方法 | [`unregister_utility`](#member-gf-methods-unregister_utility) | `func unregister_utility(script_cls: Script) -> bool:` |

## 常量

<a id="member-gf-constants-installers_setting"></a>

### `INSTALLERS_SETTING`

- API：`public`
- 首次版本：`3.0.0`

```gdscript
const INSTALLERS_SETTING: String = "gf/project/installers"
```

项目级启动安装器配置。值为 GDScript 资源路径数组，脚本需继承 GFInstaller。

<a id="member-gf-constants-fail_on_installer_error_setting"></a>

### `FAIL_ON_INSTALLER_ERROR_SETTING`

- API：`public`

```gdscript
const FAIL_ON_INSTALLER_ERROR_SETTING: String = "gf/project/fail_on_installer_error"
```

项目级 Installer 创建失败时是否中断架构初始化。

<a id="member-gf-constants-installer_timeout_setting"></a>

### `INSTALLER_TIMEOUT_SETTING`

- API：`public`

```gdscript
const INSTALLER_TIMEOUT_SETTING: String = "gf/project/installer_timeout_seconds"
```

项目级 Installer 单个 install()/install_bindings() 的最长等待时间。小于等于 0 时不启用超时。

## 属性

<a id="member-gf-properties-architecture"></a>

### `architecture`

- API：`public`

```gdscript
var architecture: GFArchitecture:
```

当前架构实例的只读访问器。

## 方法

<a id="member-gf-methods-has_architecture"></a>

### `has_architecture`

- API：`public`
- 首次版本：`1.5.0`

```gdscript
func has_architecture() -> bool:
```

检查当前架构 identity 是否仍可供 facade 使用。

返回：identity 已存在且未进入 quiesce 或 dispose 阶段时返回 true。

<a id="member-gf-methods-create_architecture"></a>

### `create_architecture`

- API：`public`
- 首次版本：`1.5.0`

```gdscript
func create_architecture() -> GFArchitecture:
```

获取当前架构；若尚未创建，则自动创建一个默认 GFArchitecture。 若同步取消旧 assignment 的 cleanup 触发更新架构操作，较新的操作拥有提交权， 本次调用返回其最终提交结果，不会用陈旧默认实例覆盖。Gf 正在退出场景树， 或当前 identity 正在 quiesce/dispose 时返回 null；已完成 dispose 的 identity 会先被清除，再创建新的默认架构。

返回：当前可用的 GFArchitecture 实例；退出树、同步释放或 listener 使提交失效时返回 null。

<a id="member-gf-methods-create_binder"></a>

### `create_binder`

- API：`public`
- 首次版本：`1.9.1`

```gdscript
func create_binder() -> Variant:
```

为当前架构创建声明式装配器。

返回：绑定到当前架构的装配器。

结构：

- `return`: GFBindBuilder-compatible binder owned by the current architecture.

<a id="member-gf-methods-get_architecture"></a>

### `get_architecture`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_architecture() -> GFArchitecture:
```

获取当前注册的架构实例。

返回：当前可用的 GFArchitecture；未注册或 identity 正在 quiesce/dispose 时返回 null。

<a id="member-gf-methods-set_architecture"></a>

### `set_architecture`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func set_architecture(architecture_instance: GFArchitecture) -> bool:
```

设置并初始化架构实例。该方法内部使用 await，调用方应加 await。 候选架构只有在 Installer 与初始化完整成功后才会原子提交；提交前 Gf facade 继续指向既有已提交架构，若尚无已提交架构则保持为空。Installer 必须使用传入的 architecture 参数或 binder，不得通过 Gf facade 隐式访问候选架构。 若本次赋值被更新赋值、尚无已提交架构时由 create_architecture() 创建的默认架构， 或 Gf 退出场景树替代，框架会取消本次异步作用域并 dispose 未提交候选； 调用方不得假定该候选仍可复用。 替换已有架构时会先等待旧架构的 shutdown_async()；只有 typed shutdown 结果成功， 才会发布候选。失败结果会拒绝候选、强制清理候选并清除已经终结的旧 identity。 同一候选已有 pending 赋值时，并发重复调用会返回 false，且不会取消首个赋值。 已进入 QUIESCING、DISPOSING 或 DISPOSED 的候选会在事务开始前被拒绝，也不会 改变当前 pending 赋值。

参数：

| 名称 | 说明 |
|---|---|
| `architecture_instance` | 要注册的 GFArchitecture 实例。 |

返回：架构设置并初始化成功时返回 true。

<a id="member-gf-methods-init"></a>

### `init`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func init() -> bool:
```

初始化当前架构。若尚未创建架构，则自动创建默认 GFArchitecture。 只有 init、async_init、ready 与 activation 四阶段全部提交后才返回成功。

返回：当前架构初始化成功时返回 true。

<a id="member-gf-methods-register_system"></a>

### `register_system`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_system(instance: Object) -> bool:
```

便捷注册 System 实例。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | 要注册、替换或注入的实例。 |

返回：注册成功时返回 true。

<a id="member-gf-methods-register_model"></a>

### `register_model`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_model(instance: Object) -> bool:
```

便捷注册 Model 实例。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | 要注册、替换或注入的实例。 |

返回：注册成功时返回 true。

<a id="member-gf-methods-register_utility"></a>

### `register_utility`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_utility(instance: Object) -> bool:
```

便捷注册 Utility 实例。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | 要注册、替换或注入的实例。 |

返回：注册成功时返回 true。

<a id="member-gf-methods-replace_system"></a>

### `replace_system`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func replace_system(instance: Object) -> bool:
```

便捷替换 System 实例。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | 要注册、替换或注入的实例。 |

返回：替换成功时返回 true。

<a id="member-gf-methods-replace_model"></a>

### `replace_model`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func replace_model(instance: Object) -> bool:
```

便捷替换 Model 实例。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | 要注册、替换或注入的实例。 |

返回：替换成功时返回 true。

<a id="member-gf-methods-replace_utility"></a>

### `replace_utility`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func replace_utility(instance: Object) -> bool:
```

便捷替换 Utility 实例。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | 要注册、替换或注入的实例。 |

返回：替换成功时返回 true。

<a id="member-gf-methods-register_factory"></a>

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
| `script_cls` | 工厂绑定使用的脚本类型键。 |
| `factory` | 用于创建实例的工厂绑定。 |
| `lifetime` | 工厂实例生命周期策略。 |

返回：工厂注册成功时返回 true。

<a id="member-gf-methods-register_factory_instance"></a>

### `register_factory_instance`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_factory_instance(script_cls: Script, instance: Object) -> bool:
```

注册已有实例作为短生命周期工厂入口。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 工厂入口使用的脚本类型键。 |
| `instance` | 要注册、替换或注入的实例。 |

返回：工厂入口注册成功时返回 true。

<a id="member-gf-methods-replace_factory"></a>

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
| `script_cls` | 要替换的工厂绑定脚本类型键。 |
| `factory` | 用于创建实例的工厂绑定。 |
| `lifetime` | 工厂实例生命周期策略。 |

返回：工厂替换成功时返回 true。

<a id="member-gf-methods-replace_factory_instance"></a>

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
| `script_cls` | 要注册、查询或创建的脚本类型。 |
| `instance` | 要注册、替换或注入的实例。 |

返回：工厂入口替换成功时返回 true。

<a id="member-gf-methods-unregister_factory"></a>

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
| `script_cls` | 要注册、查询或创建的脚本类型。 |

返回：存在并成功注销工厂时返回 true。

<a id="member-gf-methods-has_factory"></a>

### `has_factory`

- API：`public`

```gdscript
func has_factory(script_cls: Script) -> bool:
```

检查当前架构或父级架构是否注册了指定工厂。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要注册、查询或创建的脚本类型。 |

返回：工厂存在时返回 true。

<a id="member-gf-methods-create_instance"></a>

### `create_instance`

- API：`public`
- 首次版本：`1.9.0`

```gdscript
func create_instance(script_cls: Script) -> Object:
```

创建短生命周期对象实例。 只有当前架构已提交 READY 且仍开放运行时准入时才会调用工厂 provider。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要注册、查询或创建的脚本类型。 |

返回：创建出的实例；架构未开放准入或工厂不存在时返回 null。

<a id="member-gf-methods-inject_object"></a>

### `inject_object`

- API：`public`

```gdscript
func inject_object(instance: Object) -> void:
```

向任意对象注入当前架构依赖。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | 要注册、替换或注入的实例。 |

<a id="member-gf-methods-inject_node_tree"></a>

### `inject_node_tree`

- API：`public`

```gdscript
func inject_node_tree(node: Node) -> void:
```

递归向节点树中实现注入 Hook 的节点注入当前架构。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 目标节点。 |

<a id="member-gf-methods-register_system_as"></a>

### `register_system_as`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_system_as(instance: Object, alias_cls: Script) -> bool:
```

便捷注册 System 实例，并额外登记一个查询别名。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | 要注册、替换或注入的实例。 |
| `alias_cls` | 要注册的别名脚本类型。 |

返回：注册成功并写入 alias 时返回 true。

<a id="member-gf-methods-register_model_as"></a>

### `register_model_as`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_model_as(instance: Object, alias_cls: Script) -> bool:
```

便捷注册 Model 实例，并额外登记一个查询别名。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | 要注册、替换或注入的实例。 |
| `alias_cls` | 要注册的别名脚本类型。 |

返回：注册成功并写入 alias 时返回 true。

<a id="member-gf-methods-register_utility_as"></a>

### `register_utility_as`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func register_utility_as(instance: Object, alias_cls: Script) -> bool:
```

便捷注册 Utility 实例，并额外登记一个查询别名。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | 要注册、替换或注入的实例。 |
| `alias_cls` | 要注册的别名脚本类型。 |

返回：注册成功并写入 alias 时返回 true。

<a id="member-gf-methods-register_system_alias"></a>

### `register_system_alias`

- API：`public`

```gdscript
func register_system_alias(alias_cls: Script, target_cls: Script) -> void:
```

为已注册 System 添加查询别名。

参数：

| 名称 | 说明 |
|---|---|
| `alias_cls` | 要注册的别名脚本类型。 |
| `target_cls` | 别名指向的目标脚本类型。 |

<a id="member-gf-methods-register_model_alias"></a>

### `register_model_alias`

- API：`public`

```gdscript
func register_model_alias(alias_cls: Script, target_cls: Script) -> void:
```

为已注册 Model 添加查询别名。

参数：

| 名称 | 说明 |
|---|---|
| `alias_cls` | 要注册的别名脚本类型。 |
| `target_cls` | 别名指向的目标脚本类型。 |

<a id="member-gf-methods-register_utility_alias"></a>

### `register_utility_alias`

- API：`public`

```gdscript
func register_utility_alias(alias_cls: Script, target_cls: Script) -> void:
```

为已注册 Utility 添加查询别名。

参数：

| 名称 | 说明 |
|---|---|
| `alias_cls` | 要注册的别名脚本类型。 |
| `target_cls` | 别名指向的目标脚本类型。 |

<a id="member-gf-methods-unregister_system_alias"></a>

### `unregister_system_alias`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unregister_system_alias(alias_cls: Script) -> void:
```

注销 System 查询别名，不影响目标实例。

参数：

| 名称 | 说明 |
|---|---|
| `alias_cls` | 要移除的别名脚本类型。 |

<a id="member-gf-methods-unregister_model_alias"></a>

### `unregister_model_alias`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unregister_model_alias(alias_cls: Script) -> void:
```

注销 Model 查询别名，不影响目标实例。

参数：

| 名称 | 说明 |
|---|---|
| `alias_cls` | 要移除的别名脚本类型。 |

<a id="member-gf-methods-unregister_utility_alias"></a>

### `unregister_utility_alias`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unregister_utility_alias(alias_cls: Script) -> void:
```

注销 Utility 查询别名，不影响目标实例。

参数：

| 名称 | 说明 |
|---|---|
| `alias_cls` | 要移除的别名脚本类型。 |

<a id="member-gf-methods-get_system"></a>

### `get_system`

- API：`public`

```gdscript
func get_system(script_cls: Script, require_ready: bool = false) -> Object:
```

获取 System 实例。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要注册、查询或创建的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：System 实例；不存在或架构不可用时返回 null。

<a id="member-gf-methods-get_model"></a>

### `get_model`

- API：`public`

```gdscript
func get_model(script_cls: Script, require_ready: bool = false) -> Object:
```

获取 Model 实例。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要注册、查询或创建的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：Model 实例；不存在或架构不可用时返回 null。

<a id="member-gf-methods-get_utility"></a>

### `get_utility`

- API：`public`

```gdscript
func get_utility(script_cls: Script, require_ready: bool = false) -> Object:
```

获取 Utility 实例。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要注册、查询或创建的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：Utility 实例；不存在或架构不可用时返回 null。

<a id="member-gf-methods-get_local_system"></a>

### `get_local_system`

- API：`public`

```gdscript
func get_local_system(script_cls: Script, require_ready: bool = false) -> Object:
```

仅从当前全局架构获取 System，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要注册、查询或创建的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前全局架构中的 System 实例；不存在或架构不可用时返回 null。

<a id="member-gf-methods-get_local_model"></a>

### `get_local_model`

- API：`public`

```gdscript
func get_local_model(script_cls: Script, require_ready: bool = false) -> Object:
```

仅从当前全局架构获取 Model，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要注册、查询或创建的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前全局架构中的 Model 实例；不存在或架构不可用时返回 null。

<a id="member-gf-methods-get_local_utility"></a>

### `get_local_utility`

- API：`public`

```gdscript
func get_local_utility(script_cls: Script, require_ready: bool = false) -> Object:
```

仅从当前全局架构获取 Utility，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要注册、查询或创建的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前全局架构中的 Utility 实例；不存在或架构不可用时返回 null。

<a id="member-gf-methods-send_command"></a>

### `send_command`

- API：`public`

```gdscript
func send_command(command: Object) -> Variant:
```

便捷发送全局命令。

参数：

| 名称 | 说明 |
|---|---|
| `command` | 要执行的命令实例。 |

返回：命令处理结果。

结构：

- `return`: Variant command result returned by the registered command handler.

<a id="member-gf-methods-send_query"></a>

### `send_query`

- API：`public`

```gdscript
func send_query(query: Object) -> Variant:
```

便捷发送查询。

参数：

| 名称 | 说明 |
|---|---|
| `query` | 查询对象。 |

返回：查询处理结果。

结构：

- `return`: Variant query result returned by the registered query handler.

<a id="member-gf-methods-send_event"></a>

### `send_event`

- API：`public`

```gdscript
func send_event(event_instance: Object) -> void:
```

便捷发送带载体的强类型事件。

参数：

| 名称 | 说明 |
|---|---|
| `event_instance` | 要派发的事件实例。 |

<a id="member-gf-methods-send_simple_event"></a>

### `send_simple_event`

- API：`public`

```gdscript
func send_simple_event(event_id: StringName, payload: Variant = null) -> void:
```

便捷发送无参数的轻量级事件。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 简单事件标识符。 |
| `payload` | 随事件或交互传递的数据。 |

结构：

- `payload`: Variant payload passed unchanged to simple event listeners.

<a id="member-gf-methods-configure_event_debugging"></a>

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

<a id="member-gf-methods-get_event_debug_stats"></a>

### `get_event_debug_stats`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_event_debug_stats() -> Dictionary:
```

获取事件系统诊断统计。

返回：事件系统诊断统计。

结构：

- `return`: Dictionary produced by GFTypeEventSystem.get_debug_stats().

<a id="member-gf-methods-get_event_listener_diagnostics"></a>

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

<a id="member-gf-methods-compact_event_listeners"></a>

### `compact_event_listeners`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func compact_event_listeners() -> int:
```

清理 owner 已释放的事件监听器。

返回：本次立即移除或排队清理的监听器数量。

<a id="member-gf-methods-get_event_dispatch_trace"></a>

### `get_event_dispatch_trace`

- API：`public`

```gdscript
func get_event_dispatch_trace() -> Array[Dictionary]:
```

获取最近事件派发追踪条目。

返回：从旧到新的追踪条目副本。

结构：

- `return`: Array of Dictionary trace entries with event, listener, owner, and dispatch metadata.

<a id="member-gf-methods-clear_event_dispatch_trace"></a>

### `clear_event_dispatch_trace`

- API：`public`

```gdscript
func clear_event_dispatch_trace() -> void:
```

清空事件派发追踪。

<a id="member-gf-methods-listen"></a>

### `listen`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func listen(event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
```

快捷注册类型事件监听（别名：listen）。

参数：

| 名称 | 说明 |
|---|---|
| `event_type` | 要监听或取消监听的事件脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 监听器优先级，数值越大越先执行。 |

<a id="member-gf-methods-listen_owned"></a>

### `listen_owned`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func listen_owned(listener_owner: Object, event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
```

快捷注册带拥有者的类型事件监听。

参数：

| 名称 | 说明 |
|---|---|
| `listener_owner` | 监听回调的拥有者，用于批量注销。 |
| `event_type` | 要监听或取消监听的事件脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 监听器优先级，数值越大越先执行。 |

<a id="member-gf-methods-subscribe"></a>

### `subscribe`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func subscribe( event_type: Script, listener: GFEventListener, priority: int = 0, once: bool = false ) -> GFSubscriptionToken:
```

快捷订阅类型事件并返回可取消句柄。 listener 携带 owner 时句柄会绑定该 owner 生命周期。`once` 订阅会在首个 回调开始前失效，保证嵌套事件派发不会重复进入同一订阅。

参数：

| 名称 | 说明 |
|---|---|
| `event_type` | 要订阅的事件脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 监听器优先级，数值越大越先执行。 |
| `once` | 是否在首个回调开始前自动取消订阅。 |

返回：可幂等取消的订阅句柄；全局架构不可用时返回非活动句柄。

<a id="member-gf-methods-listen_assignable"></a>

### `listen_assignable`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func listen_assignable(base_event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
```

快捷注册可赋值类型事件监听。

参数：

| 名称 | 说明 |
|---|---|
| `base_event_type` | 要监听或取消监听的基类事件脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 监听器优先级，数值越大越先执行。 |

<a id="member-gf-methods-listen_assignable_owned"></a>

### `listen_assignable_owned`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func listen_assignable_owned( listener_owner: Object, base_event_type: Script, listener: GFEventListener, priority: int = 0 ) -> void:
```

快捷注册带拥有者的可赋值类型事件监听。

参数：

| 名称 | 说明 |
|---|---|
| `listener_owner` | 监听回调的拥有者，用于批量注销。 |
| `base_event_type` | 要监听或取消监听的基类事件脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 监听器优先级，数值越大越先执行。 |

<a id="member-gf-methods-subscribe_assignable"></a>

### `subscribe_assignable`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func subscribe_assignable( base_event_type: Script, listener: GFEventListener, priority: int = 0, once: bool = false ) -> GFSubscriptionToken:
```

快捷订阅可赋值类型事件并返回可取消句柄。 listener 携带 owner 时句柄会绑定该 owner 生命周期。监听基类脚本时也会 收到其派生脚本实例；`once` 在首个匹配回调开始前生效。

参数：

| 名称 | 说明 |
|---|---|
| `base_event_type` | 要订阅的基类事件脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 监听器优先级，数值越大越先执行。 |
| `once` | 是否在首个匹配回调开始前自动取消订阅。 |

返回：可幂等取消的订阅句柄；全局架构不可用时返回非活动句柄。

<a id="member-gf-methods-unlisten"></a>

### `unlisten`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unlisten(event_type: Script, listener: GFEventListener) -> void:
```

快捷注销类型事件监听（别名：unlisten）。

参数：

| 名称 | 说明 |
|---|---|
| `event_type` | 要监听或取消监听的事件脚本类型。 |
| `listener` | 要移除的事件监听器契约。 |

<a id="member-gf-methods-unlisten_owned"></a>

### `unlisten_owned`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unlisten_owned(listener_owner: Object, event_type: Script, listener: GFEventListener) -> void:
```

快捷注销带拥有者的类型事件监听。

参数：

| 名称 | 说明 |
|---|---|
| `listener_owner` | 注册监听时使用的拥有者。 |
| `event_type` | 要取消监听的事件脚本类型。 |
| `listener` | 要移除的事件监听器契约。 |

<a id="member-gf-methods-unlisten_assignable"></a>

### `unlisten_assignable`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unlisten_assignable(base_event_type: Script, listener: GFEventListener) -> void:
```

快捷注销可赋值类型事件监听。

参数：

| 名称 | 说明 |
|---|---|
| `base_event_type` | 要监听或取消监听的基类事件脚本类型。 |
| `listener` | 要移除的事件监听器契约。 |

<a id="member-gf-methods-unlisten_assignable_owned"></a>

### `unlisten_assignable_owned`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unlisten_assignable_owned(listener_owner: Object, base_event_type: Script, listener: GFEventListener) -> void:
```

快捷注销带拥有者的可赋值类型事件监听。

参数：

| 名称 | 说明 |
|---|---|
| `listener_owner` | 注册监听时使用的拥有者。 |
| `base_event_type` | 要取消监听的基类事件脚本类型。 |
| `listener` | 要移除的事件监听器契约。 |

<a id="member-gf-methods-listen_simple"></a>

### `listen_simple`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func listen_simple(event_id: StringName, listener: GFEventListener) -> void:
```

快捷注册轻量事件监听（别名：listen_simple）。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 简单事件标识符。 |
| `listener` | 简单事件监听器契约。 |

<a id="member-gf-methods-listen_simple_owned"></a>

### `listen_simple_owned`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func listen_simple_owned(listener_owner: Object, event_id: StringName, listener: GFEventListener) -> void:
```

快捷注册带拥有者的轻量事件监听。

参数：

| 名称 | 说明 |
|---|---|
| `listener_owner` | 监听回调的拥有者，用于批量注销。 |
| `event_id` | 简单事件标识符。 |
| `listener` | 简单事件监听器契约。 |

<a id="member-gf-methods-subscribe_simple"></a>

### `subscribe_simple`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func subscribe_simple( event_id: StringName, listener: GFEventListener, once: bool = false ) -> GFSubscriptionToken:
```

快捷订阅轻量事件并返回可取消句柄。 listener 携带 owner 时句柄会绑定该 owner 生命周期。`once` 订阅会在首个 回调开始前失效，保证嵌套事件派发不会重复进入同一订阅。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 简单事件标识符。 |
| `listener` | 简单事件监听器契约。 |
| `once` | 是否在首个回调开始前自动取消订阅。 |

返回：可幂等取消的订阅句柄；全局架构不可用时返回非活动句柄。

<a id="member-gf-methods-unlisten_simple"></a>

### `unlisten_simple`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unlisten_simple(event_id: StringName, listener: GFEventListener) -> void:
```

快捷注销轻量事件监听（别名：unlisten_simple）。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 简单事件标识符。 |
| `listener` | 要移除的简单事件监听器契约。 |

<a id="member-gf-methods-unlisten_simple_owned"></a>

### `unlisten_simple_owned`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unlisten_simple_owned(listener_owner: Object, event_id: StringName, listener: GFEventListener) -> void:
```

快捷注销带拥有者的轻量事件监听。

参数：

| 名称 | 说明 |
|---|---|
| `listener_owner` | 注册监听时使用的拥有者。 |
| `event_id` | 简单事件标识符。 |
| `listener` | 要移除的简单事件监听器契约。 |

<a id="member-gf-methods-unlisten_owner"></a>

### `unlisten_owner`

- API：`public`

```gdscript
func unlisten_owner(listener_owner: Object) -> void:
```

快捷注销某个拥有者注册过的所有事件监听。

参数：

| 名称 | 说明 |
|---|---|
| `listener_owner` | 监听回调的拥有者，用于批量注销。 |

<a id="member-gf-methods-unregister_system"></a>

### `unregister_system`

- API：`public`
- 首次版本：`1.9.0`

```gdscript
func unregister_system(script_cls: Script) -> bool:
```

注销 System 实例。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要注册、查询或创建的脚本类型。 |

返回：模块完成 quiesce 并从活动拓扑移除时返回 true。

<a id="member-gf-methods-unregister_model"></a>

### `unregister_model`

- API：`public`
- 首次版本：`1.9.0`

```gdscript
func unregister_model(script_cls: Script) -> bool:
```

注销 Model 实例。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要注册、查询或创建的脚本类型。 |

返回：模块完成 quiesce 并从活动拓扑移除时返回 true。

<a id="member-gf-methods-unregister_utility"></a>

### `unregister_utility`

- API：`public`
- 首次版本：`1.9.0`

```gdscript
func unregister_utility(script_cls: Script) -> bool:
```

注销 Utility 实例。

参数：

| 名称 | 说明 |
|---|---|
| `script_cls` | 要注册、查询或创建的脚本类型。 |

返回：模块完成 quiesce 并从活动拓扑移除时返回 true。
