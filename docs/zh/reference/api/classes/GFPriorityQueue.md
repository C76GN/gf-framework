# GFPriorityQueue

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/collections/gf_priority_queue.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`7.0.0`

稳定优先队列。 用二叉堆保存带数值优先级的值，支持高优先级优先或低优先级优先， 并在相同优先级下保持稳定顺序。它只管理排序和弹出顺序，不解释任务、 通知、AI 行为或项目业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`high_priority_first`](#member-gfpriorityqueue-properties-high_priority_first) | `var high_priority_first: bool = true:` |
| 方法 | [`_init`](#member-gfpriorityqueue-methods-_init) | `func _init(p_high_priority_first: bool = true) -> void:` |
| 方法 | [`from_array`](#member-gfpriorityqueue-methods-from_array) | `static func from_array( values: Array, priority: float = 0.0, p_high_priority_first: bool = true ) -> RefCounted:` |
| 方法 | [`push`](#member-gfpriorityqueue-methods-push) | `func push(value: Variant, priority: float = 0.0, front: bool = false) -> bool:` |
| 方法 | [`push_with_order`](#member-gfpriorityqueue-methods-push_with_order) | `func push_with_order(value: Variant, priority: float = 0.0, order: int = 0) -> bool:` |
| 方法 | [`pop`](#member-gfpriorityqueue-methods-pop) | `func pop(default_value: Variant = null) -> Variant:` |
| 方法 | [`peek`](#member-gfpriorityqueue-methods-peek) | `func peek(default_value: Variant = null) -> Variant:` |
| 方法 | [`peek_priority`](#member-gfpriorityqueue-methods-peek_priority) | `func peek_priority(default_value: float = 0.0) -> float:` |
| 方法 | [`remove_value`](#member-gfpriorityqueue-methods-remove_value) | `func remove_value(value: Variant) -> bool:` |
| 方法 | [`remove_all`](#member-gfpriorityqueue-methods-remove_all) | `func remove_all(value: Variant) -> int:` |
| 方法 | [`has_value`](#member-gfpriorityqueue-methods-has_value) | `func has_value(value: Variant) -> bool:` |
| 方法 | [`set_priority`](#member-gfpriorityqueue-methods-set_priority) | `func set_priority(value: Variant, priority: float, front: bool = false) -> bool:` |
| 方法 | [`clear`](#member-gfpriorityqueue-methods-clear) | `func clear() -> void:` |
| 方法 | [`is_empty`](#member-gfpriorityqueue-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`size`](#member-gfpriorityqueue-methods-size) | `func size() -> int:` |
| 方法 | [`to_array`](#member-gfpriorityqueue-methods-to_array) | `func to_array(deep: bool = false) -> Array:` |
| 方法 | [`to_entry_array`](#member-gfpriorityqueue-methods-to_entry_array) | `func to_entry_array(deep: bool = false) -> Array[Dictionary]:` |
| 方法 | [`duplicate_priority_queue`](#member-gfpriorityqueue-methods-duplicate_priority_queue) | `func duplicate_priority_queue(deep: bool = false) -> RefCounted:` |
| 方法 | [`get_debug_snapshot`](#member-gfpriorityqueue-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfpriorityqueue-properties-high_priority_first"></a>

### `high_priority_first`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var high_priority_first: bool = true:
```

是否优先弹出较大的 priority。设为 false 时较小的 priority 优先。

## 方法

<a id="member-gfpriorityqueue-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func _init(p_high_priority_first: bool = true) -> void:
```

构造函数。

参数：

| 名称 | 说明 |
|---|---|
| `p_high_priority_first` | 为 true 时 priority 数值越大越先弹出。 |

<a id="member-gfpriorityqueue-methods-from_array"></a>

### `from_array`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func from_array( values: Array, priority: float = 0.0, p_high_priority_first: bool = true ) -> RefCounted:
```

从值数组创建优先队列。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 初始值数组。 |
| `priority` | 所有初始值使用的优先级。 |
| `p_high_priority_first` | 为 true 时 priority 数值越大越先弹出。 |

返回：新优先队列。

结构：

- `values`: Array of queue values copied by reference.

<a id="member-gfpriorityqueue-methods-push"></a>

### `push`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func push(value: Variant, priority: float = 0.0, front: bool = false) -> bool:
```

推入一个值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要入队的值。 |
| `priority` | 数值优先级。 |
| `front` | 为 true 时会排在相同 priority 的既有元素之前。 |

返回：priority 有限并成功入队时返回 true。

结构：

- `value`: Variant queue value.

<a id="member-gfpriorityqueue-methods-push_with_order"></a>

### `push_with_order`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func push_with_order(value: Variant, priority: float = 0.0, order: int = 0) -> bool:
```

按显式稳定顺序推入一个值。 相同 priority 和 order 的条目按本次队列实例中的入队先后保持稳定。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要入队的值。 |
| `priority` | 数值优先级。 |
| `order` | 相同 priority 下的稳定排序值，数值越小越先弹出。 |

返回：priority 有限并成功入队时返回 true。

结构：

- `value`: Variant queue value.

<a id="member-gfpriorityqueue-methods-pop"></a>

### `pop`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func pop(default_value: Variant = null) -> Variant:
```

弹出当前最高优先级值。

参数：

| 名称 | 说明 |
|---|---|
| `default_value` | 队列为空时返回的值。 |

返回：队列值或 default_value。

结构：

- `default_value`: Variant fallback value.
- `return`: Variant queue value or fallback value.

<a id="member-gfpriorityqueue-methods-peek"></a>

### `peek`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func peek(default_value: Variant = null) -> Variant:
```

读取当前最高优先级值但不移除。

参数：

| 名称 | 说明 |
|---|---|
| `default_value` | 队列为空时返回的值。 |

返回：队列值或 default_value。

结构：

- `default_value`: Variant fallback value.
- `return`: Variant queue value or fallback value.

<a id="member-gfpriorityqueue-methods-peek_priority"></a>

### `peek_priority`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func peek_priority(default_value: float = 0.0) -> float:
```

读取当前最高优先级。

参数：

| 名称 | 说明 |
|---|---|
| `default_value` | 队列为空时返回的值。 |

返回：当前最高优先级或 default_value。

<a id="member-gfpriorityqueue-methods-remove_value"></a>

### `remove_value`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func remove_value(value: Variant) -> bool:
```

移除第一个等于 value 的队列值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要移除的值。 |

返回：找到并移除时返回 true。

结构：

- `value`: Variant queue value.

<a id="member-gfpriorityqueue-methods-remove_all"></a>

### `remove_all`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func remove_all(value: Variant) -> int:
```

移除所有等于 value 的队列值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要移除的值。 |

返回：移除数量。

结构：

- `value`: Variant queue value.

<a id="member-gfpriorityqueue-methods-has_value"></a>

### `has_value`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_value(value: Variant) -> bool:
```

检查队列是否包含指定值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要查找的值。 |

返回：包含时返回 true。

结构：

- `value`: Variant queue value.

<a id="member-gfpriorityqueue-methods-set_priority"></a>

### `set_priority`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func set_priority(value: Variant, priority: float, front: bool = false) -> bool:
```

更新第一个等于 value 的队列值优先级。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要更新的值。 |
| `priority` | 新优先级。 |
| `front` | 为 true 时排到相同 priority 的既有元素之前。 |

返回：找到并更新时返回 true。

结构：

- `value`: Variant queue value.

<a id="member-gfpriorityqueue-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空队列。

<a id="member-gfpriorityqueue-methods-is_empty"></a>

### `is_empty`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_empty() -> bool:
```

队列是否为空。

返回：为空返回 true。

<a id="member-gfpriorityqueue-methods-size"></a>

### `size`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func size() -> int:
```

获取元素数量。

返回：元素数量。

<a id="member-gfpriorityqueue-methods-to_array"></a>

### `to_array`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func to_array(deep: bool = false) -> Array:
```

按弹出顺序导出值数组，不修改当前队列。

参数：

| 名称 | 说明 |
|---|---|
| `deep` | 为 true 时深拷贝元素中的 Array、Dictionary、Object Resource 等可复制值。 |

返回：队列值数组。

结构：

- `return`: Array of queue values in pop order.

<a id="member-gfpriorityqueue-methods-to_entry_array"></a>

### `to_entry_array`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func to_entry_array(deep: bool = false) -> Array[Dictionary]:
```

按弹出顺序导出队列条目，不修改当前队列。

参数：

| 名称 | 说明 |
|---|---|
| `deep` | 为 true 时深拷贝条目中的 value。 |

返回：条目数组。

结构：

- `return`: Array[Dictionary]，每项包含 value、priority 和 order。

<a id="member-gfpriorityqueue-methods-duplicate_priority_queue"></a>

### `duplicate_priority_queue`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func duplicate_priority_queue(deep: bool = false) -> RefCounted:
```

复制优先队列。

参数：

| 名称 | 说明 |
|---|---|
| `deep` | 为 true 时深拷贝元素中的 Array、Dictionary、Object Resource 等可复制值。 |

返回：新优先队列；实际对象类型为 GFPriorityQueue。

结构：

- `return`: RefCounted GFPriorityQueue instance.

<a id="member-gfpriorityqueue-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary with size, high_priority_first, and entries.
