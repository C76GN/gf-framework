# GFPriorityWorkQueue

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/collections/gf_priority_work_queue.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

带等待加成的稳定优先级工作队列。 以基础优先级、入队时间和稳定顺序选择下一个值。等待加成不设上限， 因此在新任务优先级有限的前提下，旧低优先级任务最终能够获得执行机会。 队列只负责仲裁顺序，不执行任务，也不解释载荷或业务优先级。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`aging_interval_msec`](#member-gfpriorityworkqueue-properties-aging_interval_msec) | `var aging_interval_msec: int = 1000:` |
| 属性 | [`aging_step`](#member-gfpriorityworkqueue-properties-aging_step) | `var aging_step: float = 1.0:` |
| 属性 | [`max_size`](#member-gfpriorityworkqueue-properties-max_size) | `var max_size: int = 0:` |
| 方法 | [`push`](#member-gfpriorityworkqueue-methods-push) | `func push(value: Variant, priority: float = 0.0, front: bool = false) -> bool:` |
| 方法 | [`push_at`](#member-gfpriorityworkqueue-methods-push_at) | `func push_at( value: Variant, priority: float, enqueued_msec: int, front: bool = false ) -> bool:` |
| 方法 | [`pop`](#member-gfpriorityworkqueue-methods-pop) | `func pop(default_value: Variant = null) -> Variant:` |
| 方法 | [`pop_at`](#member-gfpriorityworkqueue-methods-pop_at) | `func pop_at(now_msec: int, default_value: Variant = null) -> Variant:` |
| 方法 | [`peek`](#member-gfpriorityworkqueue-methods-peek) | `func peek(default_value: Variant = null) -> Variant:` |
| 方法 | [`peek_at`](#member-gfpriorityworkqueue-methods-peek_at) | `func peek_at(now_msec: int, default_value: Variant = null) -> Variant:` |
| 方法 | [`remove_value`](#member-gfpriorityworkqueue-methods-remove_value) | `func remove_value(value: Variant) -> bool:` |
| 方法 | [`set_priority`](#member-gfpriorityworkqueue-methods-set_priority) | `func set_priority(value: Variant, priority: float) -> bool:` |
| 方法 | [`clear`](#member-gfpriorityworkqueue-methods-clear) | `func clear() -> void:` |
| 方法 | [`is_empty`](#member-gfpriorityworkqueue-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`size`](#member-gfpriorityworkqueue-methods-size) | `func size() -> int:` |
| 方法 | [`to_array`](#member-gfpriorityworkqueue-methods-to_array) | `func to_array(now_msec: int = -1, deep: bool = false) -> Array:` |
| 方法 | [`to_entry_array`](#member-gfpriorityworkqueue-methods-to_entry_array) | `func to_entry_array(now_msec: int = -1, deep: bool = false) -> Array[Dictionary]:` |
| 方法 | [`get_debug_snapshot`](#member-gfpriorityworkqueue-methods-get_debug_snapshot) | `func get_debug_snapshot(now_msec: int = -1) -> Dictionary:` |

## 属性

<a id="member-gfpriorityworkqueue-properties-aging_interval_msec"></a>

### `aging_interval_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var aging_interval_msec: int = 1000:
```

每经过多少毫秒增加一次等待优先级。

<a id="member-gfpriorityworkqueue-properties-aging_step"></a>

### `aging_step`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var aging_step: float = 1.0:
```

每个等待区间增加的优先级；始终保持为正有限值。

<a id="member-gfpriorityworkqueue-properties-max_size"></a>

### `max_size`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_size: int = 0:
```

最大队列长度；小于等于 0 表示不限制。

## 方法

<a id="member-gfpriorityworkqueue-methods-push"></a>

### `push`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func push(value: Variant, priority: float = 0.0, front: bool = false) -> bool:
```

使用当前单调时钟推入一个值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 工作载荷。 |
| `priority` | 基础优先级，数值越大越先执行。 |
| `front` | 为 true 时排在相同有效优先级的既有值之前。 |

返回：参数有效且未超过 max_size 时返回 true。

结构：

- `value`: Variant，由调用方持有语义的工作载荷。

<a id="member-gfpriorityworkqueue-methods-push_at"></a>

### `push_at`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func push_at( value: Variant, priority: float, enqueued_msec: int, front: bool = false ) -> bool:
```

使用显式入队时间推入一个值，适合确定性模拟、恢复或测试。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 工作载荷。 |
| `priority` | 基础优先级，数值越大越先执行。 |
| `enqueued_msec` | 同一单调时间域中的入队毫秒时间。 |
| `front` | 为 true 时排在相同有效优先级的既有值之前。 |

返回：参数有效且未超过 max_size 时返回 true。

结构：

- `value`: Variant，由调用方持有语义的工作载荷。

<a id="member-gfpriorityworkqueue-methods-pop"></a>

### `pop`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func pop(default_value: Variant = null) -> Variant:
```

使用当前单调时钟弹出有效优先级最高的值。

参数：

| 名称 | 说明 |
|---|---|
| `default_value` | 队列为空时的返回值。 |

返回：下一个工作载荷或 default_value。

结构：

- `default_value`: Variant，队列为空时的回退值。
- `return`: Variant，工作载荷或回退值。

<a id="member-gfpriorityworkqueue-methods-pop_at"></a>

### `pop_at`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func pop_at(now_msec: int, default_value: Variant = null) -> Variant:
```

使用显式当前时间弹出有效优先级最高的值。

参数：

| 名称 | 说明 |
|---|---|
| `now_msec` | 与入队时间相同时间域中的当前毫秒时间。 |
| `default_value` | 队列为空时的返回值。 |

返回：下一个工作载荷或 default_value。

结构：

- `default_value`: Variant，队列为空时的回退值。
- `return`: Variant，工作载荷或回退值。

<a id="member-gfpriorityworkqueue-methods-peek"></a>

### `peek`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func peek(default_value: Variant = null) -> Variant:
```

使用当前单调时钟读取下一个值但不移除。

参数：

| 名称 | 说明 |
|---|---|
| `default_value` | 队列为空时的返回值。 |

返回：下一个工作载荷或 default_value。

结构：

- `default_value`: Variant，队列为空时的回退值。
- `return`: Variant，工作载荷或回退值。

<a id="member-gfpriorityworkqueue-methods-peek_at"></a>

### `peek_at`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func peek_at(now_msec: int, default_value: Variant = null) -> Variant:
```

使用显式当前时间读取下一个值但不移除。

参数：

| 名称 | 说明 |
|---|---|
| `now_msec` | 与入队时间相同时间域中的当前毫秒时间。 |
| `default_value` | 队列为空时的返回值。 |

返回：下一个工作载荷或 default_value。

结构：

- `default_value`: Variant，队列为空时的回退值。
- `return`: Variant，工作载荷或回退值。

<a id="member-gfpriorityworkqueue-methods-remove_value"></a>

### `remove_value`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func remove_value(value: Variant) -> bool:
```

移除第一个等于 value 的等待值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要移除的工作载荷。 |

返回：找到并移除时返回 true。

结构：

- `value`: Variant，要匹配的工作载荷。

<a id="member-gfpriorityworkqueue-methods-set_priority"></a>

### `set_priority`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func set_priority(value: Variant, priority: float) -> bool:
```

更新第一个等于 value 的等待值基础优先级。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要更新的工作载荷。 |
| `priority` | 新基础优先级。 |

返回：找到且 priority 有效时返回 true。

结构：

- `value`: Variant，要匹配的工作载荷。

<a id="member-gfpriorityworkqueue-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func clear() -> void:
```

清空队列。

<a id="member-gfpriorityworkqueue-methods-is_empty"></a>

### `is_empty`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_empty() -> bool:
```

队列是否为空。

返回：为空时返回 true。

<a id="member-gfpriorityworkqueue-methods-size"></a>

### `size`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func size() -> int:
```

获取等待值数量。

返回：等待值数量。

<a id="member-gfpriorityworkqueue-methods-to_array"></a>

### `to_array`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_array(now_msec: int = -1, deep: bool = false) -> Array:
```

按指定时刻的弹出顺序导出值，不修改队列。

参数：

| 名称 | 说明 |
|---|---|
| `now_msec` | 与入队时间相同时间域中的当前毫秒时间；小于 0 时自动读取。 |
| `deep` | 为 true 时深拷贝可复制载荷。 |

返回：工作载荷数组。

结构：

- `return`: Array，按有效优先级排列的工作载荷。

<a id="member-gfpriorityworkqueue-methods-to_entry_array"></a>

### `to_entry_array`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_entry_array(now_msec: int = -1, deep: bool = false) -> Array[Dictionary]:
```

按指定时刻的弹出顺序导出结构化条目，不修改队列。

参数：

| 名称 | 说明 |
|---|---|
| `now_msec` | 与入队时间相同时间域中的当前毫秒时间；小于 0 时自动读取。 |
| `deep` | 为 true 时深拷贝可复制载荷。 |

返回：工作条目数组。

结构：

- `return`: Array[Dictionary]，每项包含 value、priority、effective_priority、enqueued_msec、waited_msec 和 order。

<a id="member-gfpriorityworkqueue-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot(now_msec: int = -1) -> Dictionary:
```

获取有界配置与当前排序的调试快照。

参数：

| 名称 | 说明 |
|---|---|
| `now_msec` | 与入队时间相同时间域中的当前毫秒时间；小于 0 时自动读取。 |

返回：调试快照。

结构：

- `return`: Dictionary，包含 size、max_size、aging_interval_msec、aging_step 和 entries。
