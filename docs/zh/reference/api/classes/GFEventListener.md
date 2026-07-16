# GFEventListener

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_event_listener.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：事件契约 (`event_contract`)
- 首次版本：`8.0.0`

显式描述事件监听回调、参数契约与可选 owner 的监听器记录。 事件系统不再把裸 Callable 当作稳定契约；项目代码需要通过该类型声明监听器可接收的派发参数数量。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`from_callable`](#member-gfeventlistener-methods-from_callable) | `static func from_callable( callback: Callable, dispatch_argument_count: int, debug_label: String = "" ) -> GFEventListener:` |
| 方法 | [`from_method`](#member-gfeventlistener-methods-from_method) | `static func from_method( owner: Object, method_name: StringName, dispatch_argument_count: int, debug_label: String = "" ) -> GFEventListener:` |
| 方法 | [`with_owner`](#member-gfeventlistener-methods-with_owner) | `func with_owner(owner: Object) -> GFEventListener:` |
| 方法 | [`duplicate_listener`](#member-gfeventlistener-methods-duplicate_listener) | `func duplicate_listener() -> GFEventListener:` |
| 方法 | [`get_callback`](#member-gfeventlistener-methods-get_callback) | `func get_callback() -> Callable:` |
| 方法 | [`get_owner`](#member-gfeventlistener-methods-get_owner) | `func get_owner() -> Object:` |
| 方法 | [`get_owner_id`](#member-gfeventlistener-methods-get_owner_id) | `func get_owner_id() -> int:` |
| 方法 | [`get_dispatch_argument_count`](#member-gfeventlistener-methods-get_dispatch_argument_count) | `func get_dispatch_argument_count() -> int:` |
| 方法 | [`get_debug_label`](#member-gfeventlistener-methods-get_debug_label) | `func get_debug_label() -> String:` |
| 方法 | [`is_valid`](#member-gfeventlistener-methods-is_valid) | `func is_valid() -> bool:` |

## 方法

<a id="member-gfeventlistener-methods-from_callable"></a>

### `from_callable`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_callable( callback: Callable, dispatch_argument_count: int, debug_label: String = "" ) -> GFEventListener:
```

创建显式声明派发参数数量的监听器。

参数：

| 名称 | 说明 |
|---|---|
| `callback` | 事件触发时执行的回调。 |
| `dispatch_argument_count` | 事件系统会主动传入的参数数量；类型事件和简单事件均为 1。 |
| `debug_label` | 可选诊断标签，错误报告为空时会回退到 Callable 方法名。 |

返回：新监听器契约。

<a id="member-gfeventlistener-methods-from_method"></a>

### `from_method`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_method( owner: Object, method_name: StringName, dispatch_argument_count: int, debug_label: String = "" ) -> GFEventListener:
```

通过 owner 与方法名创建监听器。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 监听方法所属对象，同时作为监听 owner。 |
| `method_name` | 监听方法名。 |
| `dispatch_argument_count` | 事件系统会主动传入的参数数量；类型事件和简单事件均为 1。 |
| `debug_label` | 可选诊断标签，错误报告为空时会回退到 Callable 方法名。 |

返回：新监听器契约。

<a id="member-gfeventlistener-methods-with_owner"></a>

### `with_owner`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func with_owner(owner: Object) -> GFEventListener:
```

返回带 owner 的监听器副本。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 监听器 owner；释放后事件系统会清理该监听器。 |

返回：当前监听器的带 owner 副本。

<a id="member-gfeventlistener-methods-duplicate_listener"></a>

### `duplicate_listener`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_listener() -> GFEventListener:
```

返回监听器副本。

返回：当前监听器副本。

<a id="member-gfeventlistener-methods-get_callback"></a>

### `get_callback`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_callback() -> Callable:
```

返回监听回调。

返回：监听回调。

<a id="member-gfeventlistener-methods-get_owner"></a>

### `get_owner`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_owner() -> Object:
```

返回监听 owner；未设置或已释放时返回 null。

返回：监听 owner 或 null。

<a id="member-gfeventlistener-methods-get_owner_id"></a>

### `get_owner_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_owner_id() -> int:
```

返回监听 owner 的实例 ID；未设置时为 0。

返回：owner 实例 ID。

<a id="member-gfeventlistener-methods-get_dispatch_argument_count"></a>

### `get_dispatch_argument_count`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_dispatch_argument_count() -> int:
```

返回事件系统会主动传入的参数数量。

返回：派发参数数量。

<a id="member-gfeventlistener-methods-get_debug_label"></a>

### `get_debug_label`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_label() -> String:
```

返回诊断标签。

返回：诊断标签。

<a id="member-gfeventlistener-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_valid() -> bool:
```

返回监听器当前是否有基本有效的 Callable 和参数契约。

返回：监听器是否有效。
