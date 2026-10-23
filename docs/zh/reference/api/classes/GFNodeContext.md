# GFNodeContext

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_node_context.gd`
- 模块：`Kernel`
- 继承：`Node`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

场景树上的局部架构上下文。 可选择继承父级架构，或创建带父级回退的 Scoped 架构。 Scoped 架构会在节点退出树时使用无法等待的 forced/no-drain dispose fallback， 适合关卡、战斗房间、调试面板等局部模块。可控或数据关键的退出必须先 await close_async()，确认结果后再移除节点。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`context_ready`](#member-gfnodecontext-signals-context_ready) | `signal context_ready(architecture: GFArchitecture)` |
| 信号 | [`context_failed`](#member-gfnodecontext-signals-context_failed) | `signal context_failed(reason: String)` |
| 信号 | [`context_closing`](#member-gfnodecontext-signals-context_closing) | `signal context_closing()` |
| 枚举 | [`ScopeMode`](#member-gfnodecontext-enums-scopemode) | `enum ScopeMode` |
| 属性 | [`scope_mode`](#member-gfnodecontext-properties-scope_mode) | `var scope_mode: ScopeMode = ScopeMode.SCOPED` |
| 属性 | [`auto_init`](#member-gfnodecontext-properties-auto_init) | `var auto_init: bool = true` |
| 属性 | [`process_scoped_ticks`](#member-gfnodecontext-properties-process_scoped_ticks) | `var process_scoped_ticks: bool = true` |
| 属性 | [`strict_dependency_lookup`](#member-gfnodecontext-properties-strict_dependency_lookup) | `var strict_dependency_lookup: bool = false` |
| 属性 | [`module_async_init_timeout_seconds`](#member-gfnodecontext-properties-module_async_init_timeout_seconds) | `var module_async_init_timeout_seconds: float = 0.0` |
| 属性 | [`context_wait_timeout_seconds`](#member-gfnodecontext-properties-context_wait_timeout_seconds) | `var context_wait_timeout_seconds: float = 30.0` |
| 属性 | [`architecture`](#member-gfnodecontext-properties-architecture) | `var architecture: GFArchitecture:` |
| 方法 | [`bind_source_context`](#member-gfnodecontext-methods-bind_source_context) | `func bind_source_context(source: GFNodeContext) -> bool:` |
| 方法 | [`is_context_available`](#member-gfnodecontext-methods-is_context_available) | `func is_context_available() -> bool:` |
| 方法 | [`close_async`](#member-gfnodecontext-methods-close_async) | `func close_async(cancellation_token: GFCancellationToken = null, timeout_seconds: float = -1.0) -> GFContextCloseResult:` |
| 方法 | [`install`](#member-gfnodecontext-methods-install) | `func install(_architecture_instance: GFArchitecture, _scope: GFAsyncScope) -> void:` |
| 方法 | [`install_bindings`](#member-gfnodecontext-methods-install_bindings) | `func install_bindings(_binder: Variant, _scope: GFAsyncScope) -> void:` |
| 方法 | [`get_architecture`](#member-gfnodecontext-methods-get_architecture) | `func get_architecture() -> GFArchitecture:` |
| 方法 | [`is_context_ready`](#member-gfnodecontext-methods-is_context_ready) | `func is_context_ready() -> bool:` |
| 方法 | [`is_context_failed`](#member-gfnodecontext-methods-is_context_failed) | `func is_context_failed() -> bool:` |
| 方法 | [`get_context_failure_reason`](#member-gfnodecontext-methods-get_context_failure_reason) | `func get_context_failure_reason() -> String:` |
| 方法 | [`initialize_context`](#member-gfnodecontext-methods-initialize_context) | `func initialize_context() -> GFArchitecture:` |
| 方法 | [`wait_until_ready`](#member-gfnodecontext-methods-wait_until_ready) | `func wait_until_ready() -> GFArchitecture:` |
| 方法 | [`get_model`](#member-gfnodecontext-methods-get_model) | `func get_model(model_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_system`](#member-gfnodecontext-methods-get_system) | `func get_system(system_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_utility`](#member-gfnodecontext-methods-get_utility) | `func get_utility(utility_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_model`](#member-gfnodecontext-methods-get_local_model) | `func get_local_model(model_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_system`](#member-gfnodecontext-methods-get_local_system) | `func get_local_system(system_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_utility`](#member-gfnodecontext-methods-get_local_utility) | `func get_local_utility(utility_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`inject_object`](#member-gfnodecontext-methods-inject_object) | `func inject_object(instance: Object) -> void:` |
| 方法 | [`inject_node_tree`](#member-gfnodecontext-methods-inject_node_tree) | `func inject_node_tree(node: Node) -> void:` |

## 信号

<a id="member-gfnodecontext-signals-context_ready"></a>

### `context_ready`

- API：`public`
- 首次版本：`1.9.0`

```gdscript
signal context_ready(architecture: GFArchitecture)
```

当上下文 Architecture 完成 stage4 activation 并提交 READY 后发出。

参数：

| 名称 | 说明 |
|---|---|
| `architecture` | 当前上下文使用的架构实例。 |

<a id="member-gfnodecontext-signals-context_failed"></a>

### `context_failed`

- API：`public`

```gdscript
signal context_failed(reason: String)
```

当上下文无法继续等待或初始化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 失败原因。 |

<a id="member-gfnodecontext-signals-context_closing"></a>

### `context_closing`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal context_closing()
```

本地绑定停止接受新工作时发出；可用于立即撤销 Controller 事件绑定。

## 枚举

<a id="member-gfnodecontext-enums-scopemode"></a>

### `ScopeMode`

- API：`public`

```gdscript
enum ScopeMode {
	## 直接复用最近的父级上下文架构；若不存在则回退到全局 Gf 架构。
	INHERITED,
	## 创建新的局部架构，并将最近的父级或全局架构作为依赖回退来源。
	SCOPED,
}
```

上下文作用域模式。

## 属性

<a id="member-gfnodecontext-properties-scope_mode"></a>

### `scope_mode`

- API：`public`

```gdscript
var scope_mode: ScopeMode = ScopeMode.SCOPED
```

当前节点上下文的作用域模式。

<a id="member-gfnodecontext-properties-auto_init"></a>

### `auto_init`

- API：`public`

```gdscript
var auto_init: bool = true
```

是否在进入树后自动初始化 Scoped 架构。

<a id="member-gfnodecontext-properties-process_scoped_ticks"></a>

### `process_scoped_ticks`

- API：`public`

```gdscript
var process_scoped_ticks: bool = true
```

是否由该节点驱动 Scoped 架构的 tick 与 physics_tick。

<a id="member-gfnodecontext-properties-strict_dependency_lookup"></a>

### `strict_dependency_lookup`

- API：`public`

```gdscript
var strict_dependency_lookup: bool = false
```

Scoped 架构是否启用严格依赖查询。开启后本地未注册的依赖不会回退父级架构。

<a id="member-gfnodecontext-properties-module_async_init_timeout_seconds"></a>

### `module_async_init_timeout_seconds`

- API：`public`

```gdscript
var module_async_init_timeout_seconds: float = 0.0
```

Scoped 架构中单个模块 async_init() 的最长等待时间。小于等于 0 时继承架构默认行为。

<a id="member-gfnodecontext-properties-context_wait_timeout_seconds"></a>

### `context_wait_timeout_seconds`

- API：`public`

```gdscript
var context_wait_timeout_seconds: float = 30.0
```

等待父级架构或当前上下文 ready 的超时时间。小于等于 0 时禁用超时。

<a id="member-gfnodecontext-properties-architecture"></a>

### `architecture`

- API：`public`

```gdscript
var architecture: GFArchitecture:
```

当前上下文使用的架构实例。

## 方法

<a id="member-gfnodecontext-methods-bind_source_context"></a>

### `bind_source_context`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func bind_source_context(source: GFNodeContext) -> bool:
```

在进入树前为 INHERITED Context 指定业务来源。显示父节点不会改变该绑定。 来源必须已经在树中；绑定不拥有来源，来源离树、关闭或重入后本轮绑定失效。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 要借用架构的来源上下文。 |

返回：配置成功返回 true；在树中、非 INHERITED 或无效来源返回 false。

<a id="member-gfnodecontext-methods-is_context_available"></a>

### `is_context_available`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_context_available() -> bool:
```

检查本地绑定是否接受新工作。初始化中的绑定可用；关闭、失效及来源失效时不可用。

返回：当前绑定和来源身份都有效时返回 true。

<a id="member-gfnodecontext-methods-close_async"></a>

### `close_async`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func close_async(cancellation_token: GFCancellationToken = null, timeout_seconds: float = -1.0) -> GFContextCloseResult:
```

先关闭逻辑子 Context，再关闭自有架构；INHERITED 只关闭本地绑定。 首次调用立即停止新工作，并发调用共享结果与首个调用的策略。预算由子关闭共同消耗。 节点不会自动离树；无法关闭的外部依赖返回未关闭结果，保持 CLOSING，允许稍后重试。

参数：

| 名称 | 说明 |
|---|---|
| `cancellation_token` | 协作关闭的取消 token。 |
| `timeout_seconds` | 总等待预算，-1 使用自有架构默认值或 30 秒；同步释放不承诺硬时限。 |

返回：同时说明是否关闭和是否正常排空的不可变结果。

<a id="member-gfnodecontext-methods-install"></a>

### `install`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func install(_architecture_instance: GFArchitecture, _scope: GFAsyncScope) -> void:
```

安装当前上下文的局部模块。仅在 SCOPED 模式下调用。

参数：

| 名称 | 说明 |
|---|---|
| `_architecture_instance` | 当前上下文创建的局部架构。 |
| `_scope` | 当前安装流程的可取消异步作用域。 |

<a id="member-gfnodecontext-methods-install_bindings"></a>

### `install_bindings`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func install_bindings(_binder: Variant, _scope: GFAsyncScope) -> void:
```

使用声明式装配器安装当前上下文的局部模块。仅在 SCOPED 模式下调用。

参数：

| 名称 | 说明 |
|---|---|
| `_binder` | 当前上下文创建的局部架构装配器。 |
| `_scope` | 当前安装流程的可取消异步作用域。 |

结构：

- `_binder`: GFBindBuilder-compatible binder produced by GFArchitecture.create_binder().

<a id="member-gfnodecontext-methods-get_architecture"></a>

### `get_architecture`

- API：`public`

```gdscript
func get_architecture() -> GFArchitecture:
```

获取当前上下文使用的架构。

返回：架构实例；未找到时返回 null。

<a id="member-gfnodecontext-methods-is_context_ready"></a>

### `is_context_ready`

- API：`public`

```gdscript
func is_context_ready() -> bool:
```

检查上下文是否已经完成初始化。

返回：已完成初始化返回 true。

<a id="member-gfnodecontext-methods-is_context_failed"></a>

### `is_context_failed`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func is_context_failed() -> bool:
```

检查上下文是否已经进入失败终态。

返回：失败后返回 true。

<a id="member-gfnodecontext-methods-get_context_failure_reason"></a>

### `get_context_failure_reason`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_context_failure_reason() -> String:
```

获取上下文失败原因。

返回：context_failed 发出的失败原因；未失败时为空字符串。

<a id="member-gfnodecontext-methods-initialize_context"></a>

### `initialize_context`

- API：`public`

```gdscript
func initialize_context() -> GFArchitecture:
```

手动初始化当前 Scoped 上下文。适合 auto_init 为 false 时，在 install()/install_bindings() 完成后统一触发初始化与 context_ready/context_failed 信号。

返回：初始化完成的架构；上下文失效或初始化失败时返回 null。

<a id="member-gfnodecontext-methods-wait_until_ready"></a>

### `wait_until_ready`

- API：`public`

```gdscript
func wait_until_ready() -> GFArchitecture:
```

等待上下文架构完成初始化并返回该架构。

返回：当前上下文架构；上下文失效时返回 null。

<a id="member-gfnodecontext-methods-get_model"></a>

### `get_model`

- API：`public`

```gdscript
func get_model(model_type: Script, require_ready: bool = false) -> Object:
```

通过当前上下文架构获取 Model。

参数：

| 名称 | 说明 |
|---|---|
| `model_type` | 模型脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：模型实例。

<a id="member-gfnodecontext-methods-get_system"></a>

### `get_system`

- API：`public`

```gdscript
func get_system(system_type: Script, require_ready: bool = false) -> Object:
```

通过当前上下文架构获取 System。

参数：

| 名称 | 说明 |
|---|---|
| `system_type` | 系统脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：系统实例。

<a id="member-gfnodecontext-methods-get_utility"></a>

### `get_utility`

- API：`public`

```gdscript
func get_utility(utility_type: Script, require_ready: bool = false) -> Object:
```

通过当前上下文架构获取 Utility。

参数：

| 名称 | 说明 |
|---|---|
| `utility_type` | 工具脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：工具实例。

<a id="member-gfnodecontext-methods-get_local_model"></a>

### `get_local_model`

- API：`public`

```gdscript
func get_local_model(model_type: Script, require_ready: bool = false) -> Object:
```

仅从当前上下文架构获取 Model，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `model_type` | 模型脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前上下文架构中的模型实例。

<a id="member-gfnodecontext-methods-get_local_system"></a>

### `get_local_system`

- API：`public`

```gdscript
func get_local_system(system_type: Script, require_ready: bool = false) -> Object:
```

仅从当前上下文架构获取 System，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `system_type` | 系统脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前上下文架构中的系统实例。

<a id="member-gfnodecontext-methods-get_local_utility"></a>

### `get_local_utility`

- API：`public`

```gdscript
func get_local_utility(utility_type: Script, require_ready: bool = false) -> Object:
```

仅从当前上下文架构获取 Utility，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `utility_type` | 工具脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前上下文架构中的工具实例。

<a id="member-gfnodecontext-methods-inject_object"></a>

### `inject_object`

- API：`public`

```gdscript
func inject_object(instance: Object) -> void:
```

向任意对象注入当前上下文架构依赖。

参数：

| 名称 | 说明 |
|---|---|
| `instance` | 要注册、替换或注入的实例。 |

<a id="member-gfnodecontext-methods-inject_node_tree"></a>

### `inject_node_tree`

- API：`public`

```gdscript
func inject_node_tree(node: Node) -> void:
```

递归向节点树中实现注入 Hook 的节点注入当前上下文架构。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 目标节点。 |
