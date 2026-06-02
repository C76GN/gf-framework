# GFPattern2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_pattern_2d.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

可复用的二维格子模式资源。 用 Array[Vector2i] 描述范围、形状、阵型或 tile pattern。它不规定格子语义， 只负责尺寸、去重、边界过滤和常用查询。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`pattern_dimensions`](#member-gfpattern2d-properties-pattern_dimensions) | `var pattern_dimensions: Vector2i = Vector2i(7, 7):` |
| 属性 | [`cells`](#member-gfpattern2d-properties-cells) | `var cells: Array[Vector2i] = []:` |
| 方法 | [`is_in_bounds`](#member-gfpattern2d-methods-is_in_bounds) | `func is_in_bounds(cell: Vector2i) -> bool:` |
| 方法 | [`has_cell`](#member-gfpattern2d-methods-has_cell) | `func has_cell(cell: Vector2i) -> bool:` |
| 方法 | [`set_cell`](#member-gfpattern2d-methods-set_cell) | `func set_cell(cell: Vector2i, enabled: bool) -> bool:` |
| 方法 | [`add_cell`](#member-gfpattern2d-methods-add_cell) | `func add_cell(cell: Vector2i) -> bool:` |
| 方法 | [`remove_cell`](#member-gfpattern2d-methods-remove_cell) | `func remove_cell(cell: Vector2i) -> bool:` |
| 方法 | [`clear_cells`](#member-gfpattern2d-methods-clear_cells) | `func clear_cells() -> void:` |
| 方法 | [`get_cells`](#member-gfpattern2d-methods-get_cells) | `func get_cells() -> Array[Vector2i]:` |
| 方法 | [`normalize_cells`](#member-gfpattern2d-methods-normalize_cells) | `func normalize_cells() -> void:` |
| 方法 | [`duplicate_pattern`](#member-gfpattern2d-methods-duplicate_pattern) | `func duplicate_pattern() -> GFPattern2D:` |

## 属性

<a id="member-gfpattern2d-properties-pattern_dimensions"></a>

### `pattern_dimensions`

- API：`public`

```gdscript
var pattern_dimensions: Vector2i = Vector2i(7, 7):
```

模式编辑尺寸。小于 1 的分量会被钳制到 1。

<a id="member-gfpattern2d-properties-cells"></a>

### `cells`

- API：`public`

```gdscript
var cells: Array[Vector2i] = []:
```

启用的格子坐标列表。

## 方法

<a id="member-gfpattern2d-methods-is_in_bounds"></a>

### `is_in_bounds`

- API：`public`

```gdscript
func is_in_bounds(cell: Vector2i) -> bool:
```

检查格子是否在 pattern 尺寸内。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格子坐标。 |

返回：在范围内返回 true。

<a id="member-gfpattern2d-methods-has_cell"></a>

### `has_cell`

- API：`public`

```gdscript
func has_cell(cell: Vector2i) -> bool:
```

检查格子是否启用。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格子坐标。 |

返回：启用返回 true。

<a id="member-gfpattern2d-methods-set_cell"></a>

### `set_cell`

- API：`public`

```gdscript
func set_cell(cell: Vector2i, enabled: bool) -> bool:
```

设置格子是否启用。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格子坐标。 |
| `enabled` | 是否启用。 |

返回：实际发生变化返回 true。

<a id="member-gfpattern2d-methods-add_cell"></a>

### `add_cell`

- API：`public`

```gdscript
func add_cell(cell: Vector2i) -> bool:
```

添加格子。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格子坐标。 |

返回：实际添加返回 true。

<a id="member-gfpattern2d-methods-remove_cell"></a>

### `remove_cell`

- API：`public`

```gdscript
func remove_cell(cell: Vector2i) -> bool:
```

移除格子。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格子坐标。 |

返回：实际移除返回 true。

<a id="member-gfpattern2d-methods-clear_cells"></a>

### `clear_cells`

- API：`public`

```gdscript
func clear_cells() -> void:
```

清空所有格子。

<a id="member-gfpattern2d-methods-get_cells"></a>

### `get_cells`

- API：`public`

```gdscript
func get_cells() -> Array[Vector2i]:
```

获取格子列表副本。

返回：格子列表副本。

<a id="member-gfpattern2d-methods-normalize_cells"></a>

### `normalize_cells`

- API：`public`

```gdscript
func normalize_cells() -> void:
```

归一化格子列表，去重、排序并移除越界格子。

<a id="member-gfpattern2d-methods-duplicate_pattern"></a>

### `duplicate_pattern`

- API：`public`

```gdscript
func duplicate_pattern() -> GFPattern2D:
```

创建深拷贝。

返回：新 pattern 资源。
