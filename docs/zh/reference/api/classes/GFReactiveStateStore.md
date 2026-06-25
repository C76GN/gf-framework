# GFReactiveStateStore

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/state/gf_reactive_state_store.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`5.0.0`

运行时 Dictionary 状态树与路径订阅容器。 管理一份纯 Variant Dictionary 状态，提供路径读写、批量 dirty 派发、 路径订阅和 owner 生命周期清理。它不定义业务字段含义，也不替代 `GFBindableProperty` 的单值响应式协议。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`state_changed`](#member-gfreactivestatestore-signals-state_changed) | `signal state_changed(changes: Array[Dictionary], snapshot: Dictionary)` |
| 信号 | [`path_changed`](#member-gfreactivestatestore-signals-path_changed) | `signal path_changed(path: String, change: Dictionary)` |
| 常量 | [`SUBSCRIBE_EXACT`](#member-gfreactivestatestore-constants-subscribe_exact) | `const SUBSCRIBE_EXACT: int = 0` |
| 常量 | [`SUBSCRIBE_PREFIX`](#member-gfreactivestatestore-constants-subscribe_prefix) | `const SUBSCRIBE_PREFIX: int = 1` |
| 常量 | [`SUBSCRIBE_ANY`](#member-gfreactivestatestore-constants-subscribe_any) | `const SUBSCRIBE_ANY: int = 2` |
| 方法 | [`_init`](#member-gfreactivestatestore-methods-_init) | `func _init(initial_state: Dictionary = {}) -> void:` |
| 方法 | [`normalize_path`](#member-gfreactivestatestore-methods-normalize_path) | `static func normalize_path(path: Variant) -> Array:` |
| 方法 | [`format_path`](#member-gfreactivestatestore-methods-format_path) | `static func format_path(path: Variant) -> String:` |
| 方法 | [`get_state`](#member-gfreactivestatestore-methods-get_state) | `func get_state(copy_value: bool = true) -> Dictionary:` |
| 方法 | [`set_state`](#member-gfreactivestatestore-methods-set_state) | `func set_state(new_state: Dictionary, options: Dictionary = {}) -> bool:` |
| 方法 | [`get_value`](#member-gfreactivestatestore-methods-get_value) | `func get_value(path: Variant, fallback: Variant = null, copy_value: bool = true) -> Variant:` |
| 方法 | [`has_value`](#member-gfreactivestatestore-methods-has_value) | `func has_value(path: Variant) -> bool:` |
| 方法 | [`set_value`](#member-gfreactivestatestore-methods-set_value) | `func set_value(path: Variant, value: Variant) -> bool:` |
| 方法 | [`set_values`](#member-gfreactivestatestore-methods-set_values) | `func set_values(values_by_path: Dictionary) -> int:` |
| 方法 | [`erase_value`](#member-gfreactivestatestore-methods-erase_value) | `func erase_value(path: Variant) -> bool:` |
| 方法 | [`begin_batch`](#member-gfreactivestatestore-methods-begin_batch) | `func begin_batch() -> void:` |
| 方法 | [`end_batch`](#member-gfreactivestatestore-methods-end_batch) | `func end_batch() -> Array[Dictionary]:` |
| 方法 | [`is_batching`](#member-gfreactivestatestore-methods-is_batching) | `func is_batching() -> bool:` |
| 方法 | [`flush`](#member-gfreactivestatestore-methods-flush) | `func flush() -> Array[Dictionary]:` |
| 方法 | [`get_dirty_changes`](#member-gfreactivestatestore-methods-get_dirty_changes) | `func get_dirty_changes() -> Array[Dictionary]:` |
| 方法 | [`subscribe`](#member-gfreactivestatestore-methods-subscribe) | `func subscribe(path: Variant, callback: Callable, options: Dictionary = {}) -> Callable:` |
| 方法 | [`unsubscribe`](#member-gfreactivestatestore-methods-unsubscribe) | `func unsubscribe(subscription_id: int) -> bool:` |
| 方法 | [`clear_subscriptions`](#member-gfreactivestatestore-methods-clear_subscriptions) | `func clear_subscriptions(owner: Object = null) -> void:` |
| 方法 | [`get_subscription_count`](#member-gfreactivestatestore-methods-get_subscription_count) | `func get_subscription_count() -> int:` |
| 方法 | [`dispose`](#member-gfreactivestatestore-methods-dispose) | `func dispose() -> void:` |

## 信号

<a id="member-gfreactivestatestore-signals-state_changed"></a>

### `state_changed`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
signal state_changed(changes: Array[Dictionary], snapshot: Dictionary)
```

状态变更 flush 后发出。

参数：

| 名称 | 说明 |
|---|---|
| `changes` | 本次派发的变更记录。 |
| `snapshot` | 当前状态快照。 |

结构：

- `changes`: Array[Dictionary]，每项包含 kind、path、path_segments、old_value、new_value、old_exists、new_exists、old_type、new_type。
- `snapshot`: Dictionary，当前状态深拷贝。

<a id="member-gfreactivestatestore-signals-path_changed"></a>

### `path_changed`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
signal path_changed(path: String, change: Dictionary)
```

单条路径变更派发时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 变更路径。 |
| `change` | 变更记录。 |

结构：

- `change`: Dictionary，包含 kind、path、path_segments、old_value、new_value、old_exists、new_exists、old_type、new_type。

## 常量

<a id="member-gfreactivestatestore-constants-subscribe_exact"></a>

### `SUBSCRIBE_EXACT`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const SUBSCRIBE_EXACT: int = 0
```

只接收完全相同路径的变更。

<a id="member-gfreactivestatestore-constants-subscribe_prefix"></a>

### `SUBSCRIBE_PREFIX`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const SUBSCRIBE_PREFIX: int = 1
```

接收指定路径及其子路径的变更。

<a id="member-gfreactivestatestore-constants-subscribe_any"></a>

### `SUBSCRIBE_ANY`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const SUBSCRIBE_ANY: int = 2
```

接收所有路径变更。

## 方法

<a id="member-gfreactivestatestore-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func _init(initial_state: Dictionary = {}) -> void:
```

构造函数。

参数：

| 名称 | 说明 |
|---|---|
| `initial_state` | 初始状态字典。 |

结构：

- `initial_state`: Dictionary，初始状态会被深拷贝保存。

<a id="member-gfreactivestatestore-methods-normalize_path"></a>

### `normalize_path`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func normalize_path(path: Variant) -> Array:
```

将路径归一为路径段数组。

参数：

| 名称 | 说明 |
|---|---|
| `path` | String、StringName、NodePath、PackedStringArray 或 Array 路径。 |

返回：路径段数组。String 路径使用点号分段，Array 路径允许 int 段表示数组索引。

结构：

- `path`: Variant，路径表达。
- `return`: Array，路径段数组。

<a id="member-gfreactivestatestore-methods-format_path"></a>

### `format_path`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func format_path(path: Variant) -> String:
```

将路径格式化为稳定文本。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 路径表达。 |

返回：路径文本。

结构：

- `path`: Variant，路径表达。

<a id="member-gfreactivestatestore-methods-get_state"></a>

### `get_state`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_state(copy_value: bool = true) -> Dictionary:
```

获取当前状态快照。

参数：

| 名称 | 说明 |
|---|---|
| `copy_value` | 为 true 时返回深拷贝。 |

返回：状态字典。

结构：

- `return`: Dictionary，当前状态。

<a id="member-gfreactivestatestore-methods-set_state"></a>

### `set_state`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func set_state(new_state: Dictionary, options: Dictionary = {}) -> bool:
```

替换整份状态，并按 GFVariantData.diff_variant() 生成路径级变更。

参数：

| 名称 | 说明 |
|---|---|
| `new_state` | 新状态字典。 |
| `options` | 可选项。支持 copy_values、max_changes。 |

返回：状态发生变化时返回 true。

结构：

- `new_state`: Dictionary，新状态会被深拷贝保存。
- `options`: Dictionary，可选字段 copy_values 默认为 true，max_changes 控制路径级 diff 上限；diff 截断时会发根级 state_replaced 变更。

<a id="member-gfreactivestatestore-methods-get_value"></a>

### `get_value`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_value(path: Variant, fallback: Variant = null, copy_value: bool = true) -> Variant:
```

读取路径值。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 路径表达。 |
| `fallback` | 路径不存在时返回的值。 |
| `copy_value` | 为 true 时深拷贝集合结果。 |

返回：路径值或 fallback。

结构：

- `path`: Variant，路径表达。
- `fallback`: Variant，路径不存在时的回退值。
- `return`: Variant，路径值。

<a id="member-gfreactivestatestore-methods-has_value"></a>

### `has_value`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func has_value(path: Variant) -> bool:
```

检查路径是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 路径表达。 |

返回：路径存在时返回 true。

结构：

- `path`: Variant，路径表达。

<a id="member-gfreactivestatestore-methods-set_value"></a>

### `set_value`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func set_value(path: Variant, value: Variant) -> bool:
```

写入路径值。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 路径表达。空路径要求 value 为 Dictionary，并替换整份状态。 |
| `value` | 新值。 |

返回：成功写入且发生变化时返回 true。

结构：

- `path`: Variant，路径表达。
- `value`: Variant，要写入的值。

<a id="member-gfreactivestatestore-methods-set_values"></a>

### `set_values`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func set_values(values_by_path: Dictionary) -> int:
```

批量写入多个路径值。

参数：

| 名称 | 说明 |
|---|---|
| `values_by_path` | 路径到值的字典。 |

返回：实际发生变化的路径数量。

结构：

- `values_by_path`: Dictionary，键为路径表达，值为要写入的 Variant。

<a id="member-gfreactivestatestore-methods-erase_value"></a>

### `erase_value`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func erase_value(path: Variant) -> bool:
```

删除路径值。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 路径表达。 |

返回：成功删除时返回 true。

结构：

- `path`: Variant，路径表达。

<a id="member-gfreactivestatestore-methods-begin_batch"></a>

### `begin_batch`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func begin_batch() -> void:
```

进入批量写入模式。

<a id="member-gfreactivestatestore-methods-end_batch"></a>

### `end_batch`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func end_batch() -> Array[Dictionary]:
```

结束一层批量写入模式。最外层结束时自动 flush。

返回：本次 flush 派发的变更。

结构：

- `return`: Array[Dictionary]，派发的变更记录。

<a id="member-gfreactivestatestore-methods-is_batching"></a>

### `is_batching`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func is_batching() -> bool:
```

当前是否处于批量写入模式。

返回：正在批量写入时返回 true。

<a id="member-gfreactivestatestore-methods-flush"></a>

### `flush`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func flush() -> Array[Dictionary]:
```

立即派发 dirty queue。flush 期间产生的新 dirty change 会在当前订阅者批次结束后继续派发， 不会重入当前订阅者列表。

返回：本次派发的变更。

结构：

- `return`: Array[Dictionary]，派发的变更记录。

<a id="member-gfreactivestatestore-methods-get_dirty_changes"></a>

### `get_dirty_changes`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_dirty_changes() -> Array[Dictionary]:
```

获取尚未派发的 dirty changes。

返回：dirty changes 副本。

结构：

- `return`: Array[Dictionary]，等待派发的变更记录。

<a id="member-gfreactivestatestore-methods-subscribe"></a>

### `subscribe`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func subscribe(path: Variant, callback: Callable, options: Dictionary = {}) -> Callable:
```

订阅指定路径变化。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 路径表达。空路径配合 SUBSCRIBE_PREFIX 或 SUBSCRIBE_ANY 可观察整棵状态树。 |
| `callback` | 回调签名为 func(change: Dictionary, store: GFReactiveStateStore)。 |
| `options` | 可选项。支持 mode、owner、emit_current。 |

返回：取消订阅 Callable；callback 无效时返回空 Callable。

结构：

- `path`: Variant，路径表达。
- `options`: Dictionary，可选字段：mode 为 SUBSCRIBE_EXACT/SUBSCRIBE_PREFIX/SUBSCRIBE_ANY，owner 为 Object，emit_current 默认为 false。

<a id="member-gfreactivestatestore-methods-unsubscribe"></a>

### `unsubscribe`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unsubscribe(subscription_id: int) -> bool:
```

按订阅 ID 取消订阅。

参数：

| 名称 | 说明 |
|---|---|
| `subscription_id` | 订阅 ID。 |

返回：找到并移除订阅时返回 true。

<a id="member-gfreactivestatestore-methods-clear_subscriptions"></a>

### `clear_subscriptions`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func clear_subscriptions(owner: Object = null) -> void:
```

清理订阅。owner 为空时清理全部订阅。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 可选订阅 owner。 |

<a id="member-gfreactivestatestore-methods-get_subscription_count"></a>

### `get_subscription_count`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_subscription_count() -> int:
```

获取有效订阅数量。

返回：有效订阅数量。

<a id="member-gfreactivestatestore-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func dispose() -> void:
```

释放 store 持有的订阅和 dirty queue。
