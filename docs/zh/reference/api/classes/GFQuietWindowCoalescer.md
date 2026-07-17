# GFQuietWindowCoalescer

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_quiet_window_coalescer.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

按 key 聚合连发消息的静默窗口协调器。 每个 key 独立收集按序消息，在最后一次提交后的静默窗口、批次最大窗口或 消息数量上限到达时关闭批次。框架不解释消息内容；项目可通过 merge_callback 定义文本拼接、状态折叠、网络载荷聚合或其它合并语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`batch_closed`](#member-gfquietwindowcoalescer-signals-batch_closed) | `signal batch_closed(report: Dictionary)` |
| 常量 | [`REASON_QUIET_WINDOW`](#member-gfquietwindowcoalescer-constants-reason_quiet_window) | `const REASON_QUIET_WINDOW: StringName = &"quiet_window"` |
| 常量 | [`REASON_MAX_WINDOW`](#member-gfquietwindowcoalescer-constants-reason_max_window) | `const REASON_MAX_WINDOW: StringName = &"max_window"` |
| 常量 | [`REASON_BATCH_LIMIT`](#member-gfquietwindowcoalescer-constants-reason_batch_limit) | `const REASON_BATCH_LIMIT: StringName = &"batch_limit"` |
| 常量 | [`REASON_MANUAL`](#member-gfquietwindowcoalescer-constants-reason_manual) | `const REASON_MANUAL: StringName = &"manual"` |
| 常量 | [`REASON_PENDING_LIMIT`](#member-gfquietwindowcoalescer-constants-reason_pending_limit) | `const REASON_PENDING_LIMIT: StringName = &"pending_limit"` |
| 属性 | [`quiet_window_msec`](#member-gfquietwindowcoalescer-properties-quiet_window_msec) | `var quiet_window_msec: int = 250:` |
| 属性 | [`max_window_msec`](#member-gfquietwindowcoalescer-properties-max_window_msec) | `var max_window_msec: int = 1000:` |
| 属性 | [`max_messages_per_batch`](#member-gfquietwindowcoalescer-properties-max_messages_per_batch) | `var max_messages_per_batch: int = 64:` |
| 属性 | [`max_pending_batches`](#member-gfquietwindowcoalescer-properties-max_pending_batches) | `var max_pending_batches: int = 128:` |
| 属性 | [`auto_flush`](#member-gfquietwindowcoalescer-properties-auto_flush) | `var auto_flush: bool = true:` |
| 属性 | [`merge_callback`](#member-gfquietwindowcoalescer-properties-merge_callback) | `var merge_callback: Callable = Callable()` |
| 方法 | [`submit`](#member-gfquietwindowcoalescer-methods-submit) | `func submit(key: StringName, message: Variant) -> int:` |
| 方法 | [`submit_at`](#member-gfquietwindowcoalescer-methods-submit_at) | `func submit_at(key: StringName, message: Variant, now_msec: int) -> int:` |
| 方法 | [`flush_ready`](#member-gfquietwindowcoalescer-methods-flush_ready) | `func flush_ready(now_msec: int = -1) -> Array[Dictionary]:` |
| 方法 | [`flush`](#member-gfquietwindowcoalescer-methods-flush) | `func flush(key: StringName, reason: StringName = REASON_MANUAL) -> Dictionary:` |
| 方法 | [`flush_all`](#member-gfquietwindowcoalescer-methods-flush_all) | `func flush_all(reason: StringName = REASON_MANUAL) -> Array[Dictionary]:` |
| 方法 | [`cancel`](#member-gfquietwindowcoalescer-methods-cancel) | `func cancel(key: StringName) -> bool:` |
| 方法 | [`clear`](#member-gfquietwindowcoalescer-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_pending_batch_count`](#member-gfquietwindowcoalescer-methods-get_pending_batch_count) | `func get_pending_batch_count() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfquietwindowcoalescer-methods-get_debug_snapshot) | `func get_debug_snapshot(max_entries: int = 32) -> Dictionary:` |

## 信号

<a id="member-gfquietwindowcoalescer-signals-batch_closed"></a>

### `batch_closed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal batch_closed(report: Dictionary)
```

一个消息批次关闭时发出。容量收缩及淘汰回调重入产生的后续容量通知会等待 后续 process frame，并按固定帧预算派发，避免单次提交被回调链无限延长。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 批次报告。 |

结构：

- `report`: Dictionary，包含 batch_id、key、reason、message_count、messages、merged_value、opened_msec、closed_msec 和 duration_msec。

## 常量

<a id="member-gfquietwindowcoalescer-constants-reason_quiet_window"></a>

### `REASON_QUIET_WINDOW`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_QUIET_WINDOW: StringName = &"quiet_window"
```

最后一条消息后的静默窗口到达。

<a id="member-gfquietwindowcoalescer-constants-reason_max_window"></a>

### `REASON_MAX_WINDOW`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_MAX_WINDOW: StringName = &"max_window"
```

批次从打开起已达到最大窗口。

<a id="member-gfquietwindowcoalescer-constants-reason_batch_limit"></a>

### `REASON_BATCH_LIMIT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_BATCH_LIMIT: StringName = &"batch_limit"
```

批次已达到消息数量上限。

<a id="member-gfquietwindowcoalescer-constants-reason_manual"></a>

### `REASON_MANUAL`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_MANUAL: StringName = &"manual"
```

调用方显式关闭批次。

<a id="member-gfquietwindowcoalescer-constants-reason_pending_limit"></a>

### `REASON_PENDING_LIMIT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_PENDING_LIMIT: StringName = &"pending_limit"
```

待处理 key 数量达到上限时，最早批次被关闭。

## 属性

<a id="member-gfquietwindowcoalescer-properties-quiet_window_msec"></a>

### `quiet_window_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var quiet_window_msec: int = 250:
```

最后一条消息后需要保持安静的毫秒数；设为 0 时提交后立即关闭。

<a id="member-gfquietwindowcoalescer-properties-max_window_msec"></a>

### `max_window_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_window_msec: int = 1000:
```

批次从打开到强制关闭的最大毫秒数；设为 0 时不启用该上限。

<a id="member-gfquietwindowcoalescer-properties-max_messages_per_batch"></a>

### `max_messages_per_batch`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_messages_per_batch: int = 64:
```

单批最多收集的消息数。

<a id="member-gfquietwindowcoalescer-properties-max_pending_batches"></a>

### `max_pending_batches`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_pending_batches: int = 128:
```

同时打开的 key 批次数量上限；达到上限时关闭最早批次。运行时降低该值会 立即按稳定顺序移除超额批次，并按跨帧预算交付关闭通知。

<a id="member-gfquietwindowcoalescer-properties-auto_flush"></a>

### `auto_flush`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var auto_flush: bool = true:
```

是否使用 SceneTree 实时时钟自动关闭到期批次。运行中关闭会撤销现有计时但保留批次， 重新开启会处理已到期批次并重建其余计时；也可关闭后由 flush_ready() 显式推进。

<a id="member-gfquietwindowcoalescer-properties-merge_callback"></a>

### `merge_callback`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var merge_callback: Callable = Callable()
```

可选合并回调，签名为 func(key: StringName, messages: Array) -> Variant。 未设置时 merged_value 是 messages 的副本。

## 方法

<a id="member-gfquietwindowcoalescer-methods-submit"></a>

### `submit`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func submit(key: StringName, message: Variant) -> int:
```

使用当前单调时钟把消息提交到 key 对应批次。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 独立合并通道的稳定标识；空值也可作为默认通道。 |
| `message` | 由项目解释的消息载荷；入队时会复制可变容器。 |

返回：当前批次 ID。

结构：

- `message`: Variant，由项目解释的消息载荷。

<a id="member-gfquietwindowcoalescer-methods-submit_at"></a>

### `submit_at`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func submit_at(key: StringName, message: Variant, now_msec: int) -> int:
```

使用显式单调时间把消息提交到 key 对应批次。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 独立合并通道的稳定标识；空值也可作为默认通道。 |
| `message` | 由项目解释的消息载荷；入队时会复制可变容器。 |
| `now_msec` | 同一单调时间域中的当前毫秒时间。 |

返回：当前批次 ID。

结构：

- `message`: Variant，由项目解释的消息载荷。

<a id="member-gfquietwindowcoalescer-methods-flush_ready"></a>

### `flush_ready`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func flush_ready(now_msec: int = -1) -> Array[Dictionary]:
```

关闭当前已经到达静默窗口或最大窗口的批次。

参数：

| 名称 | 说明 |
|---|---|
| `now_msec` | 同一单调时间域中的当前毫秒时间；小于 0 时自动读取。 |

返回：本次关闭的批次报告。

结构：

- `return`: Array[Dictionary]，每项与 batch_closed 的 report schema 相同。

<a id="member-gfquietwindowcoalescer-methods-flush"></a>

### `flush`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func flush(key: StringName, reason: StringName = REASON_MANUAL) -> Dictionary:
```

显式关闭指定 key 的批次。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 要关闭的批次 key。 |
| `reason` | 项目可提供的稳定关闭原因；为空时使用 manual。 |

返回：批次不存在时返回空字典，否则返回批次报告。

结构：

- `return`: Dictionary，与 batch_closed 的 report schema 相同。

<a id="member-gfquietwindowcoalescer-methods-flush_all"></a>

### `flush_all`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func flush_all(reason: StringName = REASON_MANUAL) -> Array[Dictionary]:
```

显式关闭调用开始时已经存在的所有批次；回调重入创建的新批次留给下一轮。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 项目可提供的稳定关闭原因；为空时使用 manual。 |

返回：所有已关闭批次报告。

结构：

- `return`: Array[Dictionary]，每项与 batch_closed 的 report schema 相同。

<a id="member-gfquietwindowcoalescer-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel(key: StringName) -> bool:
```

丢弃指定 key 的未关闭批次，不发出 batch_closed。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 要丢弃的批次 key。 |

返回：批次存在并被丢弃时返回 true。

<a id="member-gfquietwindowcoalescer-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func clear() -> void:
```

丢弃全部未关闭批次并使现有计时任务失效。

<a id="member-gfquietwindowcoalescer-methods-get_pending_batch_count"></a>

### `get_pending_batch_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_pending_batch_count() -> int:
```

获取当前打开批次数量。

返回：打开批次数量。

<a id="member-gfquietwindowcoalescer-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot(max_entries: int = 32) -> Dictionary:
```

获取不包含消息正文的有界调试快照。

参数：

| 名称 | 说明 |
|---|---|
| `max_entries` | 最多返回多少个批次摘要；小于等于 0 时不返回摘要。 |

返回：调试快照。

结构：

- `return`: Dictionary，包含配置、pending_batch_count、retained_batch_count、truncated 和 batches；batches 每项包含 batch_id、key、message_count 与时间字段。
