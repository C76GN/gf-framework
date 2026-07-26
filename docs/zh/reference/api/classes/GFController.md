# GFController

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/base/gf_controller.gd`
- 模块：`Kernel`
- 继承：`Node`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

连接 UI/输入与架构的控制器基类。 提供访问架构的便捷代理。这里不缓存 Model/System/Utility 引用， 以避免架构切换或模块注销后保留过期对象。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`host_node_path`](#member-gfcontroller-properties-host_node_path) | `var host_node_path: NodePath = NodePath("..")` |
| 属性 | [`host`](#member-gfcontroller-properties-host) | `var host: Node:` |
| 方法 | [`get_architecture`](#member-gfcontroller-methods-get_architecture) | `func get_architecture() -> GFArchitecture:` |
| 方法 | [`get_architecture_or_null`](#member-gfcontroller-methods-get_architecture_or_null) | `func get_architecture_or_null() -> GFArchitecture:` |
| 方法 | [`wait_for_context_ready`](#member-gfcontroller-methods-wait_for_context_ready) | `func wait_for_context_ready() -> GFArchitecture:` |
| 方法 | [`get_host`](#member-gfcontroller-methods-get_host) | `func get_host() -> Node:` |
| 方法 | [`has_host`](#member-gfcontroller-methods-has_host) | `func has_host() -> bool:` |
| 方法 | [`get_host_as`](#member-gfcontroller-methods-get_host_as) | `func get_host_as(host_type: Variant) -> Node:` |
| 方法 | [`get_model`](#member-gfcontroller-methods-get_model) | `func get_model(model_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_system`](#member-gfcontroller-methods-get_system) | `func get_system(system_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_utility`](#member-gfcontroller-methods-get_utility) | `func get_utility(utility_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_model`](#member-gfcontroller-methods-get_local_model) | `func get_local_model(model_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_system`](#member-gfcontroller-methods-get_local_system) | `func get_local_system(system_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_utility`](#member-gfcontroller-methods-get_local_utility) | `func get_local_utility(utility_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`send_command`](#member-gfcontroller-methods-send_command) | `func send_command(command: Object) -> Variant:` |
| 方法 | [`send_query`](#member-gfcontroller-methods-send_query) | `func send_query(query: Object) -> Variant:` |
| 方法 | [`register_event`](#member-gfcontroller-methods-register_event) | `func register_event(event_type: Script, listener: GFEventListener, priority: int = 0) -> void:` |
| 方法 | [`unregister_event`](#member-gfcontroller-methods-unregister_event) | `func unregister_event(event_type: Script, listener: GFEventListener) -> void:` |
| 方法 | [`register_assignable_event`](#member-gfcontroller-methods-register_assignable_event) | `func register_assignable_event(base_event_type: Script, listener: GFEventListener, priority: int = 0) -> void:` |
| 方法 | [`unregister_assignable_event`](#member-gfcontroller-methods-unregister_assignable_event) | `func unregister_assignable_event(base_event_type: Script, listener: GFEventListener) -> void:` |
| 方法 | [`send_event`](#member-gfcontroller-methods-send_event) | `func send_event(event_instance: Object) -> void:` |
| 方法 | [`register_simple_event`](#member-gfcontroller-methods-register_simple_event) | `func register_simple_event(event_id: StringName, listener: GFEventListener) -> void:` |
| 方法 | [`unregister_simple_event`](#member-gfcontroller-methods-unregister_simple_event) | `func unregister_simple_event(event_id: StringName, listener: GFEventListener) -> void:` |
| 方法 | [`send_simple_event`](#member-gfcontroller-methods-send_simple_event) | `func send_simple_event(event_id: StringName, payload: Variant = null) -> void:` |

## 属性

<a id="member-gfcontroller-properties-host_node_path"></a>

### `host_node_path`

- API：`public`

```gdscript
var host_node_path: NodePath = NodePath("..")
```

Controller 控制的宿主节点路径。默认指向父节点。 当 Controller 不是宿主节点的直接子节点时，可在 Inspector 中改为目标节点路径。

<a id="member-gfcontroller-properties-host"></a>

### `host`

- API：`public`

```gdscript
var host: Node:
```

Controller 控制的宿主节点。

## 方法

<a id="member-gfcontroller-methods-get_architecture"></a>

### `get_architecture`

- API：`public`
- 首次版本：`1.9.0`

```gdscript
func get_architecture() -> GFArchitecture:
```

获取当前 Controller 所属的架构。 优先沿场景树向上寻找 GFNodeContext；若未找到，则回退到全局 Gf 架构。 若最近 Context 已失败或其架构正在/已经 dispose，则返回 null，不越过局部作用域。

返回：当前可用的架构实例。

<a id="member-gfcontroller-methods-get_architecture_or_null"></a>

### `get_architecture_or_null`

- API：`public`
- 首次版本：`1.9.2`

```gdscript
func get_architecture_or_null() -> GFArchitecture:
```

获取当前 Controller 所属的架构，找不到时返回 null 且不触发全局错误。 存在但失效的最近 Context 会阻止全局回退。

返回：当前可用的架构实例。

<a id="member-gfcontroller-methods-wait_for_context_ready"></a>

### `wait_for_context_ready`

- API：`public`

```gdscript
func wait_for_context_ready() -> GFArchitecture:
```

等待最近的 GFNodeContext 完成初始化并返回可用架构。 若当前节点不在上下文子树下，则直接返回全局架构。

返回：当前 Controller 可用的架构实例。

<a id="member-gfcontroller-methods-get_host"></a>

### `get_host`

- API：`public`

```gdscript
func get_host() -> Node:
```

获取当前 Controller 控制的宿主节点。 默认返回父节点。若宿主不是父节点，可通过 host_node_path 指定。

返回：当前宿主节点；路径为空或目标不存在时返回 null。

<a id="member-gfcontroller-methods-has_host"></a>

### `has_host`

- API：`public`

```gdscript
func has_host() -> bool:
```

判断当前 Controller 是否能解析到有效宿主节点。

返回：能解析到宿主节点时返回 true。

<a id="member-gfcontroller-methods-get_host_as"></a>

### `get_host_as`

- API：`public`

```gdscript
func get_host_as(host_type: Variant) -> Node:
```

获取指定类型的宿主节点。 可传入项目脚本类型或 Godot 原生类型。 "type": "Variant", "description": "Script、ClassDB 原生类型或 null。" }

参数：

| 名称 | 说明 |
|---|---|
| `host_type` | 宿主节点类型。 |

返回：匹配类型的宿主节点；未找到或类型不匹配时返回 null。

结构：

- `host_type {`:

<a id="member-gfcontroller-methods-get_model"></a>

### `get_model`

- API：`public`

```gdscript
func get_model(model_type: Script, require_ready: bool = false) -> Object:
```

通过类型获取 Model 实例。

参数：

| 名称 | 说明 |
|---|---|
| `model_type` | 模型的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：模型实例。

<a id="member-gfcontroller-methods-get_system"></a>

### `get_system`

- API：`public`

```gdscript
func get_system(system_type: Script, require_ready: bool = false) -> Object:
```

通过类型获取 System 实例。

参数：

| 名称 | 说明 |
|---|---|
| `system_type` | 系统的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：系统实例。

<a id="member-gfcontroller-methods-get_utility"></a>

### `get_utility`

- API：`public`

```gdscript
func get_utility(utility_type: Script, require_ready: bool = false) -> Object:
```

通过类型获取 Utility 实例。

参数：

| 名称 | 说明 |
|---|---|
| `utility_type` | 工具的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：工具实例。

<a id="member-gfcontroller-methods-get_local_model"></a>

### `get_local_model`

- API：`public`

```gdscript
func get_local_model(model_type: Script, require_ready: bool = false) -> Object:
```

仅从当前 Controller 所属架构获取 Model，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `model_type` | 模型的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前架构中的模型实例。

<a id="member-gfcontroller-methods-get_local_system"></a>

### `get_local_system`

- API：`public`

```gdscript
func get_local_system(system_type: Script, require_ready: bool = false) -> Object:
```

仅从当前 Controller 所属架构获取 System，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `system_type` | 系统的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前架构中的系统实例。

<a id="member-gfcontroller-methods-get_local_utility"></a>

### `get_local_utility`

- API：`public`

```gdscript
func get_local_utility(utility_type: Script, require_ready: bool = false) -> Object:
```

仅从当前 Controller 所属架构获取 Utility，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `utility_type` | 工具的脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前架构中的工具实例。

<a id="member-gfcontroller-methods-send_command"></a>

### `send_command`

- API：`public`

```gdscript
func send_command(command: Object) -> Variant:
```

向架构发送命令。支持 await：'await send_command(MyCommand.new())'。 "type": "Variant", "description": "命令执行结果；异步命令可返回 Signal。" }

参数：

| 名称 | 说明 |
|---|---|
| `command` | 要发送的命令实例。 |

返回：命令的执行结果（null 或 Signal）。

结构：

- `return {`:

<a id="member-gfcontroller-methods-send_query"></a>

### `send_query`

- API：`public`

```gdscript
func send_query(query: Object) -> Variant:
```

执行查询并返回结果。 "type": "Variant", "description": "查询结果；具体类型由查询对象定义。" }

参数：

| 名称 | 说明 |
|---|---|
| `query` | 要执行的查询实例。 |

返回：查询结果。

结构：

- `return {`:

<a id="member-gfcontroller-methods-register_event"></a>

### `register_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_event(event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
```

注册类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_type` | 要监听的脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |

<a id="member-gfcontroller-methods-unregister_event"></a>

### `unregister_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_event(event_type: Script, listener: GFEventListener) -> void:
```

注销类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_type` | 要注销的脚本类型。 |
| `listener` | 要移除的事件监听器契约。 |

<a id="member-gfcontroller-methods-register_assignable_event"></a>

### `register_assignable_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_assignable_event(base_event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
```

注册可赋值类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `base_event_type` | 要监听的基类脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |

<a id="member-gfcontroller-methods-unregister_assignable_event"></a>

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

<a id="member-gfcontroller-methods-send_event"></a>

### `send_event`

- API：`public`

```gdscript
func send_event(event_instance: Object) -> void:
```

通过事件系统发送类型事件。

参数：

| 名称 | 说明 |
|---|---|
| `event_instance` | 要分发的事件实例。 |

<a id="member-gfcontroller-methods-register_simple_event"></a>

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

<a id="member-gfcontroller-methods-unregister_simple_event"></a>

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

<a id="member-gfcontroller-methods-send_simple_event"></a>

### `send_simple_event`

- API：`public`

```gdscript
func send_simple_event(event_id: StringName, payload: Variant = null) -> void:
```

发送轻量级 StringName 事件，避免高频 new() 带来的 GC 压力。 "type": "Variant", "description": "事件附加数据；由事件消费者约定结构。" }

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `payload` | 可选的事件附加数据。 |

结构：

- `payload {`:
