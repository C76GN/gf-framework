# GFTypeEventSystem

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_type_event_system.gd`
- 模块：`Kernel`
- 继承：`Object`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

基于类型和 StringName 的双轨事件系统。 轨道一（类型事件）：使用 Script 类型作为键，以对象实例为载体分发事件。 轨道二（简单事件）：使用 StringName 作为键，以 Variant 为 payload 分发事件。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_DISPATCH_DEPTH`](#member-gftypeeventsystem-constants-default_max_dispatch_depth) | `const DEFAULT_MAX_DISPATCH_DEPTH: int = 64` |
| 属性 | [`max_dispatch_depth`](#member-gftypeeventsystem-properties-max_dispatch_depth) | `var max_dispatch_depth: int = DEFAULT_MAX_DISPATCH_DEPTH:` |
| 属性 | [`trace_enabled`](#member-gftypeeventsystem-properties-trace_enabled) | `var trace_enabled: bool = false` |
| 属性 | [`max_trace_entries`](#member-gftypeeventsystem-properties-max_trace_entries) | `var max_trace_entries: int = 64:` |
| 方法 | [`register`](#member-gftypeeventsystem-methods-register) | `func register(event_type: Script, on_event: Callable, priority: int = 0, owner: Object = null) -> void:` |
| 方法 | [`unregister`](#member-gftypeeventsystem-methods-unregister) | `func unregister(event_type: Script, on_event: Callable) -> void:` |
| 方法 | [`unregister_owned`](#member-gftypeeventsystem-methods-unregister_owned) | `func unregister_owned(owner: Object, event_type: Script, on_event: Callable) -> void:` |
| 方法 | [`register_assignable`](#member-gftypeeventsystem-methods-register_assignable) | `func register_assignable(base_event_type: Script, on_event: Callable, priority: int = 0, owner: Object = null) -> void:` |
| 方法 | [`unregister_assignable`](#member-gftypeeventsystem-methods-unregister_assignable) | `func unregister_assignable(base_event_type: Script, on_event: Callable) -> void:` |
| 方法 | [`unregister_assignable_owned`](#member-gftypeeventsystem-methods-unregister_assignable_owned) | `func unregister_assignable_owned(owner: Object, base_event_type: Script, on_event: Callable) -> void:` |
| 方法 | [`send`](#member-gftypeeventsystem-methods-send) | `func send(event_instance: Object) -> void:` |
| 方法 | [`register_simple`](#member-gftypeeventsystem-methods-register_simple) | `func register_simple(event_id: StringName, on_event: Callable, owner: Object = null) -> void:` |
| 方法 | [`unregister_simple`](#member-gftypeeventsystem-methods-unregister_simple) | `func unregister_simple(event_id: StringName, on_event: Callable) -> void:` |
| 方法 | [`unregister_simple_owned`](#member-gftypeeventsystem-methods-unregister_simple_owned) | `func unregister_simple_owned(owner: Object, event_id: StringName, on_event: Callable) -> void:` |
| 方法 | [`send_simple`](#member-gftypeeventsystem-methods-send_simple) | `func send_simple(event_id: StringName, payload: Variant = null) -> void:` |
| 方法 | [`unregister_owner`](#member-gftypeeventsystem-methods-unregister_owner) | `func unregister_owner(owner: Object) -> void:` |
| 方法 | [`get_debug_stats`](#member-gftypeeventsystem-methods-get_debug_stats) | `func get_debug_stats() -> Dictionary:` |
| 方法 | [`get_dispatch_trace`](#member-gftypeeventsystem-methods-get_dispatch_trace) | `func get_dispatch_trace() -> Array[Dictionary]:` |
| 方法 | [`clear_dispatch_trace`](#member-gftypeeventsystem-methods-clear_dispatch_trace) | `func clear_dispatch_trace() -> void:` |
| 方法 | [`clear`](#member-gftypeeventsystem-methods-clear) | `func clear() -> void:` |

## 常量

<a id="member-gftypeeventsystem-constants-default_max_dispatch_depth"></a>

### `DEFAULT_MAX_DISPATCH_DEPTH`

- API：`public`

```gdscript
const DEFAULT_MAX_DISPATCH_DEPTH: int = 64
```

默认最大事件嵌套派发深度。

## 属性

<a id="member-gftypeeventsystem-properties-max_dispatch_depth"></a>

### `max_dispatch_depth`

- API：`public`

```gdscript
var max_dispatch_depth: int = DEFAULT_MAX_DISPATCH_DEPTH:
```

最大事件嵌套派发深度。小于等于 0 时不限制。

<a id="member-gftypeeventsystem-properties-trace_enabled"></a>

### `trace_enabled`

- API：`public`

```gdscript
var trace_enabled: bool = false
```

是否记录事件派发追踪。默认关闭，避免调试数据持有过多运行时引用。

<a id="member-gftypeeventsystem-properties-max_trace_entries"></a>

### `max_trace_entries`

- API：`public`

```gdscript
var max_trace_entries: int = 64:
```

最多保留的事件派发追踪条目数。

## 方法

<a id="member-gftypeeventsystem-methods-register"></a>

### `register`

- API：`public`

```gdscript
func register(event_type: Script, on_event: Callable, priority: int = 0, owner: Object = null) -> void:
```

注册特定脚本类型的事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_type` | 要监听的脚本类型。 |
| `on_event` | 事件发送时执行的回调函数。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |
| `owner` | 可选监听拥有者，用于批量注销。 |

<a id="member-gftypeeventsystem-methods-unregister"></a>

### `unregister`

- API：`public`

```gdscript
func unregister(event_type: Script, on_event: Callable) -> void:
```

注销特定脚本类型的事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_type` | 要注销的脚本类型。 |
| `on_event` | 要移除的回调函数。 |

<a id="member-gftypeeventsystem-methods-unregister_owned"></a>

### `unregister_owned`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unregister_owned(owner: Object, event_type: Script, on_event: Callable) -> void:
```

注销带拥有者的特定脚本类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 注册监听时使用的拥有者。 |
| `event_type` | 要注销的脚本类型。 |
| `on_event` | 要移除的回调函数。 |

<a id="member-gftypeeventsystem-methods-register_assignable"></a>

### `register_assignable`

- API：`public`

```gdscript
func register_assignable(base_event_type: Script, on_event: Callable, priority: int = 0, owner: Object = null) -> void:
```

注册可赋值类型事件监听器。 监听 base_event_type 时，也会收到继承自该脚本类型的事件实例。

参数：

| 名称 | 说明 |
|---|---|
| `base_event_type` | 要监听的基类脚本类型。 |
| `on_event` | 事件发送时执行的回调函数。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |
| `owner` | 可选监听拥有者，用于批量注销。 |

<a id="member-gftypeeventsystem-methods-unregister_assignable"></a>

### `unregister_assignable`

- API：`public`

```gdscript
func unregister_assignable(base_event_type: Script, on_event: Callable) -> void:
```

注销可赋值类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `base_event_type` | 注册时使用的基类脚本类型。 |
| `on_event` | 要移除的回调函数。 |

<a id="member-gftypeeventsystem-methods-unregister_assignable_owned"></a>

### `unregister_assignable_owned`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unregister_assignable_owned(owner: Object, base_event_type: Script, on_event: Callable) -> void:
```

注销带拥有者的可赋值类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 注册监听时使用的拥有者。 |
| `base_event_type` | 注册时使用的基类脚本类型。 |
| `on_event` | 要移除的回调函数。 |

<a id="member-gftypeeventsystem-methods-send"></a>

### `send`

- API：`public`

```gdscript
func send(event_instance: Object) -> void:
```

将事件实例发送给其脚本类型的所有注册监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_instance` | 要分发的事件实例。 |

<a id="member-gftypeeventsystem-methods-register_simple"></a>

### `register_simple`

- API：`public`

```gdscript
func register_simple(event_id: StringName, on_event: Callable, owner: Object = null) -> void:
```

注册轻量级 StringName 事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `on_event` | 回调函数，签名为 func(payload: Variant)。 |
| `owner` | 可选监听拥有者，用于批量注销。 |

<a id="member-gftypeeventsystem-methods-unregister_simple"></a>

### `unregister_simple`

- API：`public`

```gdscript
func unregister_simple(event_id: StringName, on_event: Callable) -> void:
```

注销轻量级 StringName 事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `on_event` | 要移除的回调函数。 |

<a id="member-gftypeeventsystem-methods-unregister_simple_owned"></a>

### `unregister_simple_owned`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unregister_simple_owned(owner: Object, event_id: StringName, on_event: Callable) -> void:
```

注销带拥有者的轻量级 StringName 事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 注册监听时使用的拥有者。 |
| `event_id` | StringName 事件标识符。 |
| `on_event` | 要移除的回调函数。 |

<a id="member-gftypeeventsystem-methods-send_simple"></a>

### `send_simple`

- API：`public`

```gdscript
func send_simple(event_id: StringName, payload: Variant = null) -> void:
```

将 payload 发送给指定 StringName 事件的所有注册监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `payload` | 传递给监听器的数据，可为任意类型。 |

结构：

- `payload`: Variant payload passed unchanged to simple event listeners.

<a id="member-gftypeeventsystem-methods-unregister_owner"></a>

### `unregister_owner`

- API：`public`

```gdscript
func unregister_owner(owner: Object) -> void:
```

注销指定拥有者注册过的所有事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 监听拥有者。 |

<a id="member-gftypeeventsystem-methods-get_debug_stats"></a>

### `get_debug_stats`

- API：`public`

```gdscript
func get_debug_stats() -> Dictionary:
```

获取事件系统诊断统计。

返回：包含类型事件、可赋值事件和简单事件监听数量的字典。

结构：

- `return`: Dictionary containing listener counts, pending operation counts, dispatch counters, depth limits, and trace counters.

<a id="member-gftypeeventsystem-methods-get_dispatch_trace"></a>

### `get_dispatch_trace`

- API：`public`

```gdscript
func get_dispatch_trace() -> Array[Dictionary]:
```

获取最近事件派发追踪条目。

返回：从旧到新的追踪条目副本。

结构：

- `return`: Array of Dictionary trace entries with event, listener, owner, and dispatch metadata.

<a id="member-gftypeeventsystem-methods-clear_dispatch_trace"></a>

### `clear_dispatch_trace`

- API：`public`

```gdscript
func clear_dispatch_trace() -> void:
```

清空事件派发追踪。

<a id="member-gftypeeventsystem-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空所有已注册的事件监听器（包括类型事件和简单事件）。
