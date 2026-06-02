# GFGridSelection2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_grid_selection_2d.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

通用 2D 网格格子选择器。 从候选格子中筛选一批坐标。可通过显式包含/排除、矩形边界、 自定义回调或子类重写组合出项目自己的生成规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`included_cells`](#member-gfgridselection2d-properties-included_cells) | `var included_cells: Array[Vector2i] = []` |
| 属性 | [`excluded_cells`](#member-gfgridselection2d-properties-excluded_cells) | `var excluded_cells: Array[Vector2i] = []` |
| 属性 | [`use_bounds`](#member-gfgridselection2d-properties-use_bounds) | `var use_bounds: bool = false` |
| 属性 | [`bounds_position`](#member-gfgridselection2d-properties-bounds_position) | `var bounds_position: Vector2i = Vector2i.ZERO` |
| 属性 | [`bounds_size`](#member-gfgridselection2d-properties-bounds_size) | `var bounds_size: Vector2i = Vector2i.ZERO` |
| 属性 | [`invert`](#member-gfgridselection2d-properties-invert) | `var invert: bool = false` |
| 属性 | [`filter_callback`](#member-gfgridselection2d-properties-filter_callback) | `var filter_callback: Callable = Callable()` |
| 方法 | [`select_cells`](#member-gfgridselection2d-methods-select_cells) | `func select_cells(candidates: Array[Vector2i], context: Dictionary = {}) -> Array[Vector2i]:` |
| 方法 | [`matches_cell`](#member-gfgridselection2d-methods-matches_cell) | `func matches_cell(cell: Vector2i, context: Dictionary = {}) -> bool:` |

## 属性

<a id="member-gfgridselection2d-properties-included_cells"></a>

### `included_cells`

- API：`public`

```gdscript
var included_cells: Array[Vector2i] = []
```

显式包含的格子；为空时不限制。

<a id="member-gfgridselection2d-properties-excluded_cells"></a>

### `excluded_cells`

- API：`public`

```gdscript
var excluded_cells: Array[Vector2i] = []
```

显式排除的格子。

<a id="member-gfgridselection2d-properties-use_bounds"></a>

### `use_bounds`

- API：`public`

```gdscript
var use_bounds: bool = false
```

是否启用矩形边界过滤。

<a id="member-gfgridselection2d-properties-bounds_position"></a>

### `bounds_position`

- API：`public`

```gdscript
var bounds_position: Vector2i = Vector2i.ZERO
```

边界起点。

<a id="member-gfgridselection2d-properties-bounds_size"></a>

### `bounds_size`

- API：`public`

```gdscript
var bounds_size: Vector2i = Vector2i.ZERO
```

边界尺寸。

<a id="member-gfgridselection2d-properties-invert"></a>

### `invert`

- API：`public`

```gdscript
var invert: bool = false
```

是否反转最终选择结果。

<a id="member-gfgridselection2d-properties-filter_callback"></a>

### `filter_callback`

- API：`public`

```gdscript
var filter_callback: Callable = Callable()
```

自定义过滤回调，签名为 func(cell: Vector2i, context: Dictionary) -> bool。

## 方法

<a id="member-gfgridselection2d-methods-select_cells"></a>

### `select_cells`

- API：`public`

```gdscript
func select_cells(candidates: Array[Vector2i], context: Dictionary = {}) -> Array[Vector2i]:
```

从候选格子中选择坐标。

参数：

| 名称 | 说明 |
|---|---|
| `candidates` | 候选格子。 |
| `context` | 项目自定义上下文。 |

返回：选中的格子。

结构：

- `context`: Dictionary project-defined selection context.

<a id="member-gfgridselection2d-methods-matches_cell"></a>

### `matches_cell`

- API：`public`

```gdscript
func matches_cell(cell: Vector2i, context: Dictionary = {}) -> bool:
```

检查格子是否会被选择。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格子坐标。 |
| `context` | 项目自定义上下文。 |

返回：会被选择时返回 true。

结构：

- `context`: Dictionary project-defined selection context.
