# GFVirtualListModel

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_virtual_list_model.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`4.4.0`

可变尺寸虚拟列表布局模型。 维护条目数量、估算尺寸、实测尺寸、累计偏移和可见范围，供聊天流、 日志面板、资源列表或编辑器 Dock 自行渲染可见 Control。它不创建 UI 节点， 不保存条目数据，也不规定列表视觉或交互规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`layout_changed`](#member-gfvirtuallistmodel-signals-layout_changed) | `signal layout_changed(revision: int)` |
| 常量 | [`DEFAULT_ESTIMATED_ITEM_EXTENT`](#member-gfvirtuallistmodel-constants-default_estimated_item_extent) | `const DEFAULT_ESTIMATED_ITEM_EXTENT: float = 60.0` |
| 常量 | [`DEFAULT_OVERSCAN_ITEMS`](#member-gfvirtuallistmodel-constants-default_overscan_items) | `const DEFAULT_OVERSCAN_ITEMS: int = 2` |
| 常量 | [`MIN_ITEM_EXTENT`](#member-gfvirtuallistmodel-constants-min_item_extent) | `const MIN_ITEM_EXTENT: float = 1.0` |
| 常量 | [`MAX_ITEM_EXTENT`](#member-gfvirtuallistmodel-constants-max_item_extent) | `const MAX_ITEM_EXTENT: float = 1_000_000_000_000.0` |
| 属性 | [`estimated_item_extent`](#member-gfvirtuallistmodel-properties-estimated_item_extent) | `var estimated_item_extent: float:` |
| 属性 | [`overscan_items`](#member-gfvirtuallistmodel-properties-overscan_items) | `var overscan_items: int:` |
| 属性 | [`trailing_padding`](#member-gfvirtuallistmodel-properties-trailing_padding) | `var trailing_padding: float:` |
| 方法 | [`clear`](#member-gfvirtuallistmodel-methods-clear) | `func clear() -> void:` |
| 方法 | [`set_item_count`](#member-gfvirtuallistmodel-methods-set_item_count) | `func set_item_count(item_count: int) -> void:` |
| 方法 | [`append_item`](#member-gfvirtuallistmodel-methods-append_item) | `func append_item(extent: float = -1.0, measured: bool = false) -> int:` |
| 方法 | [`remove_item`](#member-gfvirtuallistmodel-methods-remove_item) | `func remove_item(item_index: int) -> bool:` |
| 方法 | [`set_item_extent`](#member-gfvirtuallistmodel-methods-set_item_extent) | `func set_item_extent( item_index: int, extent: float, measured: bool = true, scroll_offset: float = -1.0 ) -> Dictionary:` |
| 方法 | [`reset_item_extent`](#member-gfvirtuallistmodel-methods-reset_item_extent) | `func reset_item_extent(item_index: int) -> bool:` |
| 方法 | [`get_item_count`](#member-gfvirtuallistmodel-methods-get_item_count) | `func get_item_count() -> int:` |
| 方法 | [`get_revision`](#member-gfvirtuallistmodel-methods-get_revision) | `func get_revision() -> int:` |
| 方法 | [`get_item_extent`](#member-gfvirtuallistmodel-methods-get_item_extent) | `func get_item_extent(item_index: int) -> float:` |
| 方法 | [`is_item_measured`](#member-gfvirtuallistmodel-methods-is_item_measured) | `func is_item_measured(item_index: int) -> bool:` |
| 方法 | [`get_item_offset`](#member-gfvirtuallistmodel-methods-get_item_offset) | `func get_item_offset(item_index: int) -> float:` |
| 方法 | [`get_content_extent`](#member-gfvirtuallistmodel-methods-get_content_extent) | `func get_content_extent(include_trailing_padding: bool = true) -> float:` |
| 方法 | [`get_viewport_range`](#member-gfvirtuallistmodel-methods-get_viewport_range) | `func get_viewport_range(scroll_offset: float, viewport_extent: float) -> Vector2i:` |
| 方法 | [`get_visible_range`](#member-gfvirtuallistmodel-methods-get_visible_range) | `func get_visible_range(scroll_offset: float, viewport_extent: float) -> Vector2i:` |
| 方法 | [`get_visible_items`](#member-gfvirtuallistmodel-methods-get_visible_items) | `func get_visible_items(scroll_offset: float, viewport_extent: float) -> Array[Dictionary]:` |

## 信号

<a id="member-gfvirtuallistmodel-signals-layout_changed"></a>

### `layout_changed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal layout_changed(revision: int)
```

布局状态实际变化后发出。 一次公开写操作无论影响多少条目都只推进一次 revision；无变化或被拒绝的写入不发出。

参数：

| 名称 | 说明 |
|---|---|
| `revision` | 变更后的单调递增布局版本号。 |

## 常量

<a id="member-gfvirtuallistmodel-constants-default_estimated_item_extent"></a>

### `DEFAULT_ESTIMATED_ITEM_EXTENT`

- API：`public`

```gdscript
const DEFAULT_ESTIMATED_ITEM_EXTENT: float = 60.0
```

默认条目估算尺寸。

<a id="member-gfvirtuallistmodel-constants-default_overscan_items"></a>

### `DEFAULT_OVERSCAN_ITEMS`

- API：`public`

```gdscript
const DEFAULT_OVERSCAN_ITEMS: int = 2
```

默认可见范围两端额外保留的条目数。

<a id="member-gfvirtuallistmodel-constants-min_item_extent"></a>

### `MIN_ITEM_EXTENT`

- API：`public`

```gdscript
const MIN_ITEM_EXTENT: float = 1.0
```

条目尺寸下限，避免零尺寸条目破坏二分搜索和滚动范围。

<a id="member-gfvirtuallistmodel-constants-max_item_extent"></a>

### `MAX_ITEM_EXTENT`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const MAX_ITEM_EXTENT: float = 1_000_000_000_000.0
```

单条目尺寸上限，避免异常输入放大累计布局范围。

## 属性

<a id="member-gfvirtuallistmodel-properties-estimated_item_extent"></a>

### `estimated_item_extent`

- API：`public`

```gdscript
var estimated_item_extent: float:
```

未实测条目的估算尺寸。

<a id="member-gfvirtuallistmodel-properties-overscan_items"></a>

### `overscan_items`

- API：`public`

```gdscript
var overscan_items: int:
```

可见范围前后额外保留的条目数量。

<a id="member-gfvirtuallistmodel-properties-trailing_padding"></a>

### `trailing_padding`

- API：`public`

```gdscript
var trailing_padding: float:
```

列表末尾额外报告的滚动尺寸。

## 方法

<a id="member-gfvirtuallistmodel-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空所有条目尺寸和偏移缓存。

<a id="member-gfvirtuallistmodel-methods-set_item_count"></a>

### `set_item_count`

- API：`public`

```gdscript
func set_item_count(item_count: int) -> void:
```

设置条目数量，并为新增条目填入估算尺寸。

参数：

| 名称 | 说明 |
|---|---|
| `item_count` | 目标条目数量，小于 0 时按 0 处理。 |

<a id="member-gfvirtuallistmodel-methods-append_item"></a>

### `append_item`

- API：`public`

```gdscript
func append_item(extent: float = -1.0, measured: bool = false) -> int:
```

追加一个条目。

参数：

| 名称 | 说明 |
|---|---|
| `extent` | 可选条目尺寸；小于等于 0 时使用 estimated_item_extent。 |
| `measured` | 是否把 extent 视为实测尺寸。 |

返回：新条目的索引。

<a id="member-gfvirtuallistmodel-methods-remove_item"></a>

### `remove_item`

- API：`public`

```gdscript
func remove_item(item_index: int) -> bool:
```

移除指定条目。

参数：

| 名称 | 说明 |
|---|---|
| `item_index` | 要移除的条目索引。 |

返回：移除成功返回 true。

<a id="member-gfvirtuallistmodel-methods-set_item_extent"></a>

### `set_item_extent`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func set_item_extent( item_index: int, extent: float, measured: bool = true, scroll_offset: float = -1.0 ) -> Dictionary:
```

写入条目尺寸。 返回报告中的 scroll_adjustment 可用于保持视口锚点：当被修改条目位于 scroll_offset 之前时，调用方可把当前滚动偏移加上该值。

参数：

| 名称 | 说明 |
|---|---|
| `item_index` | 条目索引。 |
| `extent` | 条目尺寸，会被限制到 MIN_ITEM_EXTENT 以上。 |
| `measured` | 是否把该尺寸视为实测尺寸。 |
| `scroll_offset` | 可选当前滚动偏移；小于 0 时不计算锚点修正。 |

返回：尺寸更新报告。

结构：

- `return`: Dictionary，包含 ok、changed、index、previous_extent、extent、delta、scroll_adjustment 与 error 字段。

<a id="member-gfvirtuallistmodel-methods-reset_item_extent"></a>

### `reset_item_extent`

- API：`public`

```gdscript
func reset_item_extent(item_index: int) -> bool:
```

把指定条目重置为估算尺寸。

参数：

| 名称 | 说明 |
|---|---|
| `item_index` | 条目索引。 |

返回：重置成功返回 true。

<a id="member-gfvirtuallistmodel-methods-get_item_count"></a>

### `get_item_count`

- API：`public`

```gdscript
func get_item_count() -> int:
```

获取条目数量。

返回：当前条目数量。

<a id="member-gfvirtuallistmodel-methods-get_revision"></a>

### `get_revision`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_revision() -> int:
```

获取布局状态的当前版本号。

返回：从 0 开始、只在布局实际变化时递增的版本号。

<a id="member-gfvirtuallistmodel-methods-get_item_extent"></a>

### `get_item_extent`

- API：`public`

```gdscript
func get_item_extent(item_index: int) -> float:
```

获取条目尺寸。

参数：

| 名称 | 说明 |
|---|---|
| `item_index` | 条目索引。 |

返回：条目尺寸；索引无效时返回 0。

<a id="member-gfvirtuallistmodel-methods-is_item_measured"></a>

### `is_item_measured`

- API：`public`

```gdscript
func is_item_measured(item_index: int) -> bool:
```

判断条目尺寸是否来自实测。

参数：

| 名称 | 说明 |
|---|---|
| `item_index` | 条目索引。 |

返回：已实测返回 true。

<a id="member-gfvirtuallistmodel-methods-get_item_offset"></a>

### `get_item_offset`

- API：`public`

```gdscript
func get_item_offset(item_index: int) -> float:
```

获取条目顶部偏移。

参数：

| 名称 | 说明 |
|---|---|
| `item_index` | 条目索引。 |

返回：条目顶部偏移；索引无效时返回 0。

<a id="member-gfvirtuallistmodel-methods-get_content_extent"></a>

### `get_content_extent`

- API：`public`

```gdscript
func get_content_extent(include_trailing_padding: bool = true) -> float:
```

获取内容总尺寸。

参数：

| 名称 | 说明 |
|---|---|
| `include_trailing_padding` | 是否包含 trailing_padding。 |

返回：内容总尺寸。

<a id="member-gfvirtuallistmodel-methods-get_viewport_range"></a>

### `get_viewport_range`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_viewport_range(scroll_offset: float, viewport_extent: float) -> Vector2i:
```

计算当前滚动窗口直接命中的条目范围，不包含 overscan。

参数：

| 名称 | 说明 |
|---|---|
| `scroll_offset` | 当前滚动偏移。 |
| `viewport_extent` | 视口尺寸。 |

返回：Vector2i(start, end)，end 为不包含的结束索引。

<a id="member-gfvirtuallistmodel-methods-get_visible_range"></a>

### `get_visible_range`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func get_visible_range(scroll_offset: float, viewport_extent: float) -> Vector2i:
```

计算当前滚动窗口内应被物化的条目范围。

参数：

| 名称 | 说明 |
|---|---|
| `scroll_offset` | 当前滚动偏移。 |
| `viewport_extent` | 视口尺寸。 |

返回：Vector2i(start, end)，end 为不包含的结束索引。

<a id="member-gfvirtuallistmodel-methods-get_visible_items"></a>

### `get_visible_items`

- API：`public`

```gdscript
func get_visible_items(scroll_offset: float, viewport_extent: float) -> Array[Dictionary]:
```

获取当前滚动窗口内的条目布局记录。

参数：

| 名称 | 说明 |
|---|---|
| `scroll_offset` | 当前滚动偏移。 |
| `viewport_extent` | 视口尺寸。 |

返回：可见条目记录数组。

结构：

- `return`: Array[Dictionary]，每项包含 index、offset、extent 与 measured 字段。
