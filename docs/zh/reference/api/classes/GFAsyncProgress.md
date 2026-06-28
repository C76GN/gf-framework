# GFAsyncProgress

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_async_progress.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`7.0.0`

可节流的通用异步进度句柄。 用于把下载、预热、导入、后台任务或项目流程的进度更新统一为 0 到 1 的值、 可选消息和元数据。它不决定 UI 样式，也不绑定具体任务类型。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`progressed`](#member-gfasyncprogress-signals-progressed) | `signal progressed(value: float, message: String, metadata: Dictionary)` |
| 属性 | [`min_delta`](#member-gfasyncprogress-properties-min_delta) | `var min_delta: float = 0.0:` |
| 属性 | [`min_interval_msec`](#member-gfasyncprogress-properties-min_interval_msec) | `var min_interval_msec: int = 0:` |
| 属性 | [`emit_on_message_change`](#member-gfasyncprogress-properties-emit_on_message_change) | `var emit_on_message_change: bool = true` |
| 方法 | [`_init`](#member-gfasyncprogress-methods-_init) | `func _init(initial_value: float = 0.0, initial_message: String = "", initial_metadata: Dictionary = {}) -> void:` |
| 方法 | [`update`](#member-gfasyncprogress-methods-update) | `func update(value: float, message: String = "", metadata: Dictionary = {}) -> bool:` |
| 方法 | [`force_emit`](#member-gfasyncprogress-methods-force_emit) | `func force_emit() -> bool:` |
| 方法 | [`complete`](#member-gfasyncprogress-methods-complete) | `func complete(message: String = "", metadata: Dictionary = {}) -> bool:` |
| 方法 | [`reset`](#member-gfasyncprogress-methods-reset) | `func reset(value: float = 0.0, message: String = "", metadata: Dictionary = {}) -> void:` |
| 方法 | [`get_value`](#member-gfasyncprogress-methods-get_value) | `func get_value() -> float:` |
| 方法 | [`get_message`](#member-gfasyncprogress-methods-get_message) | `func get_message() -> String:` |
| 方法 | [`get_metadata`](#member-gfasyncprogress-methods-get_metadata) | `func get_metadata() -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfasyncprogress-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfasyncprogress-signals-progressed"></a>

### `progressed`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal progressed(value: float, message: String, metadata: Dictionary)
```

进度通过节流条件并对外发布时发出。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 当前进度，范围 0 到 1。 |
| `message` | 当前进度消息。 |
| `metadata` | 当前进度元数据。 |

结构：

- `metadata`: Dictionary，调用方定义的进度上下文。

## 属性

<a id="member-gfasyncprogress-properties-min_delta"></a>

### `min_delta`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var min_delta: float = 0.0:
```

触发进度信号的最小数值变化。设为 0 时任意数值变化都会触发。

<a id="member-gfasyncprogress-properties-min_interval_msec"></a>

### `min_interval_msec`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var min_interval_msec: int = 0:
```

触发进度信号的最小时间间隔，单位毫秒。设为 0 时不按时间节流。

<a id="member-gfasyncprogress-properties-emit_on_message_change"></a>

### `emit_on_message_change`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var emit_on_message_change: bool = true
```

消息变化时是否允许触发信号，即使数值变化小于 min_delta。

## 方法

<a id="member-gfasyncprogress-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func _init(initial_value: float = 0.0, initial_message: String = "", initial_metadata: Dictionary = {}) -> void:
```

创建进度句柄。

参数：

| 名称 | 说明 |
|---|---|
| `initial_value` | 初始进度，范围会被夹到 0 到 1。 |
| `initial_message` | 初始消息。 |
| `initial_metadata` | 初始元数据。 |

结构：

- `initial_metadata`: Dictionary，调用方定义的进度上下文。

<a id="member-gfasyncprogress-methods-update"></a>

### `update`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func update(value: float, message: String = "", metadata: Dictionary = {}) -> bool:
```

更新进度，并在满足节流条件时发出 progressed。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 新进度值，范围会被夹到 0 到 1。 |
| `message` | 进度消息。 |
| `metadata` | 进度元数据。 |

返回：本次更新是否发出了 progressed。

结构：

- `metadata`: Dictionary，调用方定义的进度上下文。

<a id="member-gfasyncprogress-methods-force_emit"></a>

### `force_emit`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func force_emit() -> bool:
```

强制发布当前进度。

返回：是否成功发出 progressed。

<a id="member-gfasyncprogress-methods-complete"></a>

### `complete`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func complete(message: String = "", metadata: Dictionary = {}) -> bool:
```

将进度更新为 1.0 并强制发布。

参数：

| 名称 | 说明 |
|---|---|
| `message` | 完成消息。 |
| `metadata` | 完成元数据。 |

返回：是否成功发出 progressed。

结构：

- `metadata`: Dictionary，调用方定义的进度上下文。

<a id="member-gfasyncprogress-methods-reset"></a>

### `reset`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func reset(value: float = 0.0, message: String = "", metadata: Dictionary = {}) -> void:
```

重置进度状态，不发出信号。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 新进度值。 |
| `message` | 新消息。 |
| `metadata` | 新元数据。 |

结构：

- `metadata`: Dictionary，调用方定义的进度上下文。

<a id="member-gfasyncprogress-methods-get_value"></a>

### `get_value`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_value() -> float:
```

获取当前进度值。

返回：当前进度值。

<a id="member-gfasyncprogress-methods-get_message"></a>

### `get_message`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_message() -> String:
```

获取当前消息。

返回：当前消息。

<a id="member-gfasyncprogress-methods-get_metadata"></a>

### `get_metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_metadata() -> Dictionary:
```

获取当前元数据副本。

返回：当前元数据副本。

结构：

- `return`: Dictionary，调用方定义的进度上下文。

<a id="member-gfasyncprogress-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取进度状态快照。

返回：进度状态快照。

结构：

- `return`: Dictionary，包含 value、message、metadata、min_delta、min_interval_msec、has_emitted 和 last_emitted_value。
