# GFTableSelectionModel

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_table_selection_model.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`5.2.0`

稳定行 ID 驱动的表格选择模型。 只维护选中行 ID、锚点和选择模式，不关心行如何渲染、排序或过滤。 表格视图排序、过滤或重建可见行时，只要 row_id 稳定，选择状态就能保留。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`selection_changed`](#member-gftableselectionmodel-signals-selection_changed) | `signal selection_changed(selected_ids: Array)` |
| 枚举 | [`SelectionMode`](#member-gftableselectionmodel-enums-selectionmode) | `enum SelectionMode` |
| 属性 | [`selection_mode`](#member-gftableselectionmodel-properties-selection_mode) | `var selection_mode: SelectionMode:` |
| 属性 | [`anchor_row_id`](#member-gftableselectionmodel-properties-anchor_row_id) | `var anchor_row_id: Variant = null` |
| 方法 | [`clear_selection`](#member-gftableselectionmodel-methods-clear_selection) | `func clear_selection() -> void:` |
| 方法 | [`set_selected`](#member-gftableselectionmodel-methods-set_selected) | `func set_selected(row_id: Variant, selected: bool) -> bool:` |
| 方法 | [`toggle_selected`](#member-gftableselectionmodel-methods-toggle_selected) | `func toggle_selected(row_id: Variant) -> bool:` |
| 方法 | [`select_single`](#member-gftableselectionmodel-methods-select_single) | `func select_single(row_id: Variant) -> bool:` |
| 方法 | [`replace_selection`](#member-gftableselectionmodel-methods-replace_selection) | `func replace_selection(row_ids: Array) -> bool:` |
| 方法 | [`select_range`](#member-gftableselectionmodel-methods-select_range) | `func select_range( ordered_row_ids: Array, from_row_id: Variant, to_row_id: Variant, additive: bool = false ) -> bool:` |
| 方法 | [`prune_to_row_ids`](#member-gftableselectionmodel-methods-prune_to_row_ids) | `func prune_to_row_ids(row_ids: Array) -> bool:` |
| 方法 | [`is_selected`](#member-gftableselectionmodel-methods-is_selected) | `func is_selected(row_id: Variant) -> bool:` |
| 方法 | [`get_selected_ids`](#member-gftableselectionmodel-methods-get_selected_ids) | `func get_selected_ids() -> Array:` |
| 方法 | [`get_selected_count`](#member-gftableselectionmodel-methods-get_selected_count) | `func get_selected_count() -> int:` |
| 方法 | [`is_empty`](#member-gftableselectionmodel-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gftableselectionmodel-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gftableselectionmodel-signals-selection_changed"></a>

### `selection_changed`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
signal selection_changed(selected_ids: Array)
```

选择集合变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `selected_ids` | 当前选中行 ID 副本。 |

结构：

- `selected_ids`: Array，当前选中行 ID。

## 枚举

<a id="member-gftableselectionmodel-enums-selectionmode"></a>

### `SelectionMode`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
enum SelectionMode {
	## 不允许选择。
	NONE,
	## 只允许单选。
	SINGLE,
	## 允许多选。
	MULTIPLE,
}
```

选择模式。

## 属性

<a id="member-gftableselectionmodel-properties-selection_mode"></a>

### `selection_mode`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var selection_mode: SelectionMode:
```

当前选择模式。

<a id="member-gftableselectionmodel-properties-anchor_row_id"></a>

### `anchor_row_id`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var anchor_row_id: Variant = null
```

当前范围选择锚点。

结构：

- `anchor_row_id`: Variant，最近一次显式选择的行 ID。

## 方法

<a id="member-gftableselectionmodel-methods-clear_selection"></a>

### `clear_selection`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func clear_selection() -> void:
```

清空选择。

<a id="member-gftableselectionmodel-methods-set_selected"></a>

### `set_selected`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func set_selected(row_id: Variant, selected: bool) -> bool:
```

设置单个行 ID 的选择状态。

参数：

| 名称 | 说明 |
|---|---|
| `row_id` | 稳定行 ID。 |
| `selected` | 是否选中。 |

返回：状态发生变化时返回 true。

结构：

- `row_id`: Variant，调用方提供的稳定行 ID。

<a id="member-gftableselectionmodel-methods-toggle_selected"></a>

### `toggle_selected`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func toggle_selected(row_id: Variant) -> bool:
```

切换单个行 ID 的选择状态。

参数：

| 名称 | 说明 |
|---|---|
| `row_id` | 稳定行 ID。 |

返回：状态发生变化时返回 true。

结构：

- `row_id`: Variant，调用方提供的稳定行 ID。

<a id="member-gftableselectionmodel-methods-select_single"></a>

### `select_single`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func select_single(row_id: Variant) -> bool:
```

用单个行 ID 替换当前选择。

参数：

| 名称 | 说明 |
|---|---|
| `row_id` | 稳定行 ID。 |

返回：状态发生变化时返回 true。

结构：

- `row_id`: Variant，调用方提供的稳定行 ID。

<a id="member-gftableselectionmodel-methods-replace_selection"></a>

### `replace_selection`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func replace_selection(row_ids: Array) -> bool:
```

用一组行 ID 替换当前选择。

参数：

| 名称 | 说明 |
|---|---|
| `row_ids` | 稳定行 ID 列表。 |

返回：状态发生变化时返回 true。

结构：

- `row_ids`: Array，调用方提供的稳定行 ID。

<a id="member-gftableselectionmodel-methods-select_range"></a>

### `select_range`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func select_range( ordered_row_ids: Array, from_row_id: Variant, to_row_id: Variant, additive: bool = false ) -> bool:
```

在有序行 ID 列表中选择范围。

参数：

| 名称 | 说明 |
|---|---|
| `ordered_row_ids` | 当前可见顺序或项目指定顺序中的行 ID。 |
| `from_row_id` | 范围起点。 |
| `to_row_id` | 范围终点。 |
| `additive` | 为 true 时保留现有选择并叠加范围。 |

返回：状态发生变化时返回 true。

结构：

- `ordered_row_ids`: Array，当前顺序中的稳定行 ID。
- `from_row_id`: Variant，范围起点行 ID。
- `to_row_id`: Variant，范围终点行 ID。

<a id="member-gftableselectionmodel-methods-prune_to_row_ids"></a>

### `prune_to_row_ids`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func prune_to_row_ids(row_ids: Array) -> bool:
```

移除不存在于 row_ids 中的选择。

参数：

| 名称 | 说明 |
|---|---|
| `row_ids` | 仍然有效的行 ID 列表。 |

返回：状态发生变化时返回 true。

结构：

- `row_ids`: Array，有效稳定行 ID。

<a id="member-gftableselectionmodel-methods-is_selected"></a>

### `is_selected`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func is_selected(row_id: Variant) -> bool:
```

判断行 ID 是否已选中。

参数：

| 名称 | 说明 |
|---|---|
| `row_id` | 稳定行 ID。 |

返回：已选中返回 true。

结构：

- `row_id`: Variant，调用方提供的稳定行 ID。

<a id="member-gftableselectionmodel-methods-get_selected_ids"></a>

### `get_selected_ids`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_selected_ids() -> Array:
```

获取选中行 ID 列表副本。

返回：选中行 ID 列表。

结构：

- `return`: Array，当前选中行 ID。

<a id="member-gftableselectionmodel-methods-get_selected_count"></a>

### `get_selected_count`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_selected_count() -> int:
```

获取选中数量。

返回：选中行数量。

<a id="member-gftableselectionmodel-methods-is_empty"></a>

### `is_empty`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func is_empty() -> bool:
```

判断当前是否没有选择。

返回：没有选择时返回 true。

<a id="member-gftableselectionmodel-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：选择模型状态字典。

结构：

- `return`: Dictionary，包含 selection_mode、selected_count、selected_ids 和 anchor_row_id。
