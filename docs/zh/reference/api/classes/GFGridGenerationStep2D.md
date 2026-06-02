# GFGridGenerationStep2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_grid_generation_step_2d.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用 2D 网格生成步骤。 将选择器命中的格子写入或移除一个 Variant 值。它只操作字典数据， 不绑定 TileMap、GridMap、房间、碰撞或具体玩法。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`step_id`](#member-gfgridgenerationstep2d-properties-step_id) | `var step_id: StringName = &""` |
| 属性 | [`selection`](#member-gfgridgenerationstep2d-properties-selection) | `var selection: GFGridSelection2D = null` |
| 属性 | [`value`](#member-gfgridgenerationstep2d-properties-value) | `var value: Variant = true` |
| 属性 | [`erase_cells`](#member-gfgridgenerationstep2d-properties-erase_cells) | `var erase_cells: bool = false` |
| 属性 | [`metadata`](#member-gfgridgenerationstep2d-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`value_callback`](#member-gfgridgenerationstep2d-properties-value_callback) | `var value_callback: Callable = Callable()` |
| 方法 | [`apply`](#member-gfgridgenerationstep2d-methods-apply) | `func apply( grid: Dictionary, candidates: Array[Vector2i], context: Dictionary = {} ) -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfgridgenerationstep2d-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfgridgenerationstep2d-properties-step_id"></a>

### `step_id`

- API：`public`

```gdscript
var step_id: StringName = &""
```

步骤标识。

<a id="member-gfgridgenerationstep2d-properties-selection"></a>

### `selection`

- API：`public`

```gdscript
var selection: GFGridSelection2D = null
```

格子选择器；为空时作用于全部候选格子。

<a id="member-gfgridgenerationstep2d-properties-value"></a>

### `value`

- API：`public`

```gdscript
var value: Variant = true
```

要写入的值。

结构：

- `value`: Variant value written to selected cells.

<a id="member-gfgridgenerationstep2d-properties-erase_cells"></a>

### `erase_cells`

- API：`public`

```gdscript
var erase_cells: bool = false
```

为 true 时移除选中格子，而不是写入值。

<a id="member-gfgridgenerationstep2d-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

步骤元数据。

结构：

- `metadata`: Dictionary extension metadata for the generation step.

<a id="member-gfgridgenerationstep2d-properties-value_callback"></a>

### `value_callback`

- API：`public`

```gdscript
var value_callback: Callable = Callable()
```

自定义值回调，签名为 func(cell: Vector2i, previous_value: Variant, context: Dictionary) -> Variant。

## 方法

<a id="member-gfgridgenerationstep2d-methods-apply"></a>

### `apply`

- API：`public`

```gdscript
func apply( grid: Dictionary, candidates: Array[Vector2i], context: Dictionary = {} ) -> int:
```

应用生成步骤。

参数：

| 名称 | 说明 |
|---|---|
| `grid` | 目标网格字典，key 为 Vector2i。 |
| `candidates` | 候选格子。 |
| `context` | 项目自定义上下文。 |

返回：被修改的格子数量。

结构：

- `grid`: Dictionary mapping Vector2i cells to generated values; mutated in place.
- `context`: Dictionary project-defined generation context.

<a id="member-gfgridgenerationstep2d-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取步骤诊断快照。

返回：诊断字典。

结构：

- `return`: Dictionary with step_id, erase_cells, has_selection, has_value_callback, and metadata.
