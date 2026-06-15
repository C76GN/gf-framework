# GFDeque

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/collections/gf_deque.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`5.0.0`

通用双端队列。 使用环形数组保存队列内容，支持从头尾 O(1) 追加、读取和移除。 它只维护元素顺序和容量，不解释任务、历史、动画或业务载荷语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_CAPACITY`](#member-gfdeque-constants-default_capacity) | `const DEFAULT_CAPACITY: int = 8` |
| 方法 | [`from_array`](#member-gfdeque-methods-from_array) | `static func from_array(values: Array, initial_capacity: int = 0) -> RefCounted:` |
| 方法 | [`push_front`](#member-gfdeque-methods-push_front) | `func push_front(value: Variant) -> void:` |
| 方法 | [`push_back`](#member-gfdeque-methods-push_back) | `func push_back(value: Variant) -> void:` |
| 方法 | [`pop_front`](#member-gfdeque-methods-pop_front) | `func pop_front(default_value: Variant = null) -> Variant:` |
| 方法 | [`pop_back`](#member-gfdeque-methods-pop_back) | `func pop_back(default_value: Variant = null) -> Variant:` |
| 方法 | [`peek_front`](#member-gfdeque-methods-peek_front) | `func peek_front(default_value: Variant = null) -> Variant:` |
| 方法 | [`peek_back`](#member-gfdeque-methods-peek_back) | `func peek_back(default_value: Variant = null) -> Variant:` |
| 方法 | [`at`](#member-gfdeque-methods-at) | `func at(index: int, default_value: Variant = null) -> Variant:` |
| 方法 | [`set_at`](#member-gfdeque-methods-set_at) | `func set_at(index: int, value: Variant) -> bool:` |
| 方法 | [`reserve`](#member-gfdeque-methods-reserve) | `func reserve(min_capacity: int) -> void:` |
| 方法 | [`trim_front`](#member-gfdeque-methods-trim_front) | `func trim_front(max_size: int) -> int:` |
| 方法 | [`trim_back`](#member-gfdeque-methods-trim_back) | `func trim_back(max_size: int) -> int:` |
| 方法 | [`clear`](#member-gfdeque-methods-clear) | `func clear() -> void:` |
| 方法 | [`is_empty`](#member-gfdeque-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`size`](#member-gfdeque-methods-size) | `func size() -> int:` |
| 方法 | [`capacity`](#member-gfdeque-methods-capacity) | `func capacity() -> int:` |
| 方法 | [`to_array`](#member-gfdeque-methods-to_array) | `func to_array(deep: bool = false) -> Array:` |
| 方法 | [`duplicate_deque`](#member-gfdeque-methods-duplicate_deque) | `func duplicate_deque(deep: bool = false) -> RefCounted:` |
| 方法 | [`get_debug_snapshot`](#member-gfdeque-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 常量

<a id="member-gfdeque-constants-default_capacity"></a>

### `DEFAULT_CAPACITY`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_CAPACITY: int = 8
```

默认底层容量。

## 方法

<a id="member-gfdeque-methods-from_array"></a>

### `from_array`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func from_array(values: Array, initial_capacity: int = 0) -> RefCounted:
```

从数组创建双端队列。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 按队列顺序写入的初始元素。 |
| `initial_capacity` | 初始容量；小于元素数量时会自动扩容。 |

返回：新双端队列；实际对象类型为 GFDeque。

结构：

- `values`: Array of queue values copied by reference.
- `return`: RefCounted GFDeque instance.

<a id="member-gfdeque-methods-push_front"></a>

### `push_front`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func push_front(value: Variant) -> void:
```

在队头追加元素。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要追加的元素。 |

结构：

- `value`: Variant queue value.

<a id="member-gfdeque-methods-push_back"></a>

### `push_back`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func push_back(value: Variant) -> void:
```

在队尾追加元素。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要追加的元素。 |

结构：

- `value`: Variant queue value.

<a id="member-gfdeque-methods-pop_front"></a>

### `pop_front`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func pop_front(default_value: Variant = null) -> Variant:
```

移除并返回队头元素。

参数：

| 名称 | 说明 |
|---|---|
| `default_value` | 队列为空时返回的默认值。 |

返回：队头元素或默认值。

结构：

- `default_value`: Variant fallback value.
- `return`: Variant queue value or fallback value.

<a id="member-gfdeque-methods-pop_back"></a>

### `pop_back`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func pop_back(default_value: Variant = null) -> Variant:
```

移除并返回队尾元素。

参数：

| 名称 | 说明 |
|---|---|
| `default_value` | 队列为空时返回的默认值。 |

返回：队尾元素或默认值。

结构：

- `default_value`: Variant fallback value.
- `return`: Variant queue value or fallback value.

<a id="member-gfdeque-methods-peek_front"></a>

### `peek_front`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func peek_front(default_value: Variant = null) -> Variant:
```

读取队头元素但不移除。

参数：

| 名称 | 说明 |
|---|---|
| `default_value` | 队列为空时返回的默认值。 |

返回：队头元素或默认值。

结构：

- `default_value`: Variant fallback value.
- `return`: Variant queue value or fallback value.

<a id="member-gfdeque-methods-peek_back"></a>

### `peek_back`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func peek_back(default_value: Variant = null) -> Variant:
```

读取队尾元素但不移除。

参数：

| 名称 | 说明 |
|---|---|
| `default_value` | 队列为空时返回的默认值。 |

返回：队尾元素或默认值。

结构：

- `default_value`: Variant fallback value.
- `return`: Variant queue value or fallback value.

<a id="member-gfdeque-methods-at"></a>

### `at`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func at(index: int, default_value: Variant = null) -> Variant:
```

按队列顺序读取元素。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 队列顺序索引；负数从队尾倒数。 |
| `default_value` | 索引越界时返回的默认值。 |

返回：对应元素或默认值。

结构：

- `default_value`: Variant fallback value.
- `return`: Variant queue value or fallback value.

<a id="member-gfdeque-methods-set_at"></a>

### `set_at`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func set_at(index: int, value: Variant) -> bool:
```

按队列顺序替换元素。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 队列顺序索引；负数从队尾倒数。 |
| `value` | 新元素。 |

返回：替换成功返回 true。

结构：

- `value`: Variant queue value.

<a id="member-gfdeque-methods-reserve"></a>

### `reserve`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func reserve(min_capacity: int) -> void:
```

至少保留指定底层容量。

参数：

| 名称 | 说明 |
|---|---|
| `min_capacity` | 最小底层容量。 |

<a id="member-gfdeque-methods-trim_front"></a>

### `trim_front`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func trim_front(max_size: int) -> int:
```

从队头裁剪多余元素，使队列最多保留 max_size 个元素。

参数：

| 名称 | 说明 |
|---|---|
| `max_size` | 保留数量；小于 0 时不裁剪。 |

返回：实际移除数量。

<a id="member-gfdeque-methods-trim_back"></a>

### `trim_back`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func trim_back(max_size: int) -> int:
```

从队尾裁剪多余元素，使队列最多保留 max_size 个元素。

参数：

| 名称 | 说明 |
|---|---|
| `max_size` | 保留数量；小于 0 时不裁剪。 |

返回：实际移除数量。

<a id="member-gfdeque-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func clear() -> void:
```

清空队列。

<a id="member-gfdeque-methods-is_empty"></a>

### `is_empty`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func is_empty() -> bool:
```

队列是否为空。

返回：为空返回 true。

<a id="member-gfdeque-methods-size"></a>

### `size`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func size() -> int:
```

获取元素数量。

返回：元素数量。

<a id="member-gfdeque-methods-capacity"></a>

### `capacity`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func capacity() -> int:
```

获取底层容量。

返回：底层容量。

<a id="member-gfdeque-methods-to_array"></a>

### `to_array`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func to_array(deep: bool = false) -> Array:
```

按队列顺序导出数组。

参数：

| 名称 | 说明 |
|---|---|
| `deep` | 为 true 时深拷贝元素中的 Array、Dictionary、Object Resource 等可复制值。 |

返回：队列元素数组。

结构：

- `return`: Array of queue values in front-to-back order.

<a id="member-gfdeque-methods-duplicate_deque"></a>

### `duplicate_deque`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func duplicate_deque(deep: bool = false) -> RefCounted:
```

复制双端队列。

参数：

| 名称 | 说明 |
|---|---|
| `deep` | 为 true 时深拷贝元素中的 Array、Dictionary、Object Resource 等可复制值。 |

返回：新双端队列；实际对象类型为 GFDeque。

结构：

- `return`: RefCounted GFDeque instance.

<a id="member-gfdeque-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary with size, capacity, and front_index.
