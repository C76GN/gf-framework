# GFWaveFunctionCollapse2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_wave_function_collapse_2d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

二维格子 Wave Function Collapse 约束求解工具。 该工具实现简单 tiled WFC 的纯数据核心：调用方声明 tile id、权重、四向邻接规则、 固定格和 seed，工具输出格子到 tile id 的结果、剩余 domain 和诊断报告。它不创建 TileMap、图片、场景节点、资源文件或项目业务对象。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Heuristic`](#member-gfwavefunctioncollapse2d-enums-heuristic) | `enum Heuristic` |
| 常量 | [`STATUS_COMPLETE`](#member-gfwavefunctioncollapse2d-constants-status_complete) | `const STATUS_COMPLETE: StringName = &"complete"` |
| 常量 | [`STATUS_CONTRADICTION`](#member-gfwavefunctioncollapse2d-constants-status_contradiction) | `const STATUS_CONTRADICTION: StringName = &"contradiction"` |
| 常量 | [`STATUS_STEP_LIMIT`](#member-gfwavefunctioncollapse2d-constants-status_step_limit) | `const STATUS_STEP_LIMIT: StringName = &"step_limit"` |
| 常量 | [`STATUS_INVALID_INPUT`](#member-gfwavefunctioncollapse2d-constants-status_invalid_input) | `const STATUS_INVALID_INPUT: StringName = &"invalid_input"` |
| 常量 | [`DEFAULT_MAX_CELLS`](#member-gfwavefunctioncollapse2d-constants-default_max_cells) | `const DEFAULT_MAX_CELLS: int = 4096` |
| 常量 | [`DEFAULT_MAX_TILES`](#member-gfwavefunctioncollapse2d-constants-default_max_tiles) | `const DEFAULT_MAX_TILES: int = 128` |
| 方法 | [`solve_grid`](#member-gfwavefunctioncollapse2d-methods-solve_grid) | `static func solve_grid( grid_size: Vector2i, tiles: Array, adjacency_rules: Array[Dictionary], options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`to_json_compatible_report`](#member-gfwavefunctioncollapse2d-methods-to_json_compatible_report) | `static func to_json_compatible_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`expand_transformed_adjacency_rules`](#member-gfwavefunctioncollapse2d-methods-expand_transformed_adjacency_rules) | `static func expand_transformed_adjacency_rules( adjacency_rules: Array[Dictionary], transform_specs: Array[Dictionary], options: Dictionary = {} ) -> Dictionary:` |

## 枚举

<a id="member-gfwavefunctioncollapse2d-enums-heuristic"></a>

### `Heuristic`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
enum Heuristic {
	## 使用加权 Shannon entropy，优先处理信息量最低的未决格。
	ENTROPY,
	## 使用 minimum remaining values，优先处理候选 tile 数量最少的未决格。
	MRV,
	## 使用稳定的 y/x 行优先顺序，便于调试规则。
	SCANLINE,
}
```

选择下一个待坍缩格子的启发式。

## 常量

<a id="member-gfwavefunctioncollapse2d-constants-status_complete"></a>

### `STATUS_COMPLETE`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const STATUS_COMPLETE: StringName = &"complete"
```

有效完成状态。

<a id="member-gfwavefunctioncollapse2d-constants-status_contradiction"></a>

### `STATUS_CONTRADICTION`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const STATUS_CONTRADICTION: StringName = &"contradiction"
```

规则或固定格导致 domain 为空的状态。

<a id="member-gfwavefunctioncollapse2d-constants-status_step_limit"></a>

### `STATUS_STEP_LIMIT`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const STATUS_STEP_LIMIT: StringName = &"step_limit"
```

达到 `max_steps` 但仍有未决格的状态。

<a id="member-gfwavefunctioncollapse2d-constants-status_invalid_input"></a>

### `STATUS_INVALID_INPUT`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const STATUS_INVALID_INPUT: StringName = &"invalid_input"
```

输入无效状态。

<a id="member-gfwavefunctioncollapse2d-constants-default_max_cells"></a>

### `DEFAULT_MAX_CELLS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_CELLS: int = 4096
```

默认最大格子数，避免误把超大 WFC 任务交给单帧纯 GDScript。

<a id="member-gfwavefunctioncollapse2d-constants-default_max_tiles"></a>

### `DEFAULT_MAX_TILES`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_TILES: int = 128
```

默认最大 tile 数。简单 tiled WFC 的传播成本随 tile 数增长。

## 方法

<a id="member-gfwavefunctioncollapse2d-methods-solve_grid"></a>

### `solve_grid`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func solve_grid( grid_size: Vector2i, tiles: Array, adjacency_rules: Array[Dictionary], options: Dictionary = {} ) -> Dictionary:
```

求解二维格子的简单 tiled Wave Function Collapse。 空 `adjacency_rules` 表示邻接不受限制；一旦声明任意规则，未声明的方向和组合视为禁止。 文字 tile id 会归一为 `StringName`，整数 tile id 会保留为 `int`。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 网格尺寸。 |
| `tiles` | tile 声明数组。 |
| `adjacency_rules` | 四向邻接规则数组。 |
| `options` | 求解选项。 |

返回：求解报告。

结构：

- `tiles`: Array，每项可以是 int/String/StringName tile id，或包含 id 与可选 weight 的 Dictionary。weight 必须是有限正数。
- `adjacency_rules`: Array[Dictionary]，每项包含 from、to、direction，可选 bidirectional。direction 支持 Vector2i.RIGHT/LEFT/DOWN/UP 或 right/east/left/west/down/south/up/north。
- `options`: Dictionary 支持 seed: int、heuristic: Heuristic|StringName、periodic: bool、fixed_cells: Dictionary[Vector2i, tile id]、bidirectional_rules: bool、max_cells: int、max_tiles: int、max_steps: int。
- `return`: Dictionary，包含 ok、error、status、algorithm、grid_size、seed、heuristic、periodic、cell_count、max_cells、tile_count、max_tiles、max_steps、step_count、collapsed_count、undecided_count、contradiction_cell、grid 和 domains。

<a id="member-gfwavefunctioncollapse2d-methods-to_json_compatible_report"></a>

### `to_json_compatible_report`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func to_json_compatible_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:
```

将 WFC 求解报告转换为 JSON.stringify() 安全的结构。

参数：

| 名称 | 说明 |
|---|---|
| `report` | solve_grid() 返回的报告。 |
| `options` | 报告编码选项，透传给 GFReportValueCodec。 |

返回：JSON 兼容报告。

结构：

- `report`: GFWaveFunctionCollapse2D 返回的求解或规则展开报告。
- `options`: GFReportValueCodec 编码选项字典。
- `return`: 可安全交给 JSON.stringify() 的 Dictionary。

<a id="member-gfwavefunctioncollapse2d-methods-expand_transformed_adjacency_rules"></a>

### `expand_transformed_adjacency_rules`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func expand_transformed_adjacency_rules( adjacency_rules: Array[Dictionary], transform_specs: Array[Dictionary], options: Dictionary = {} ) -> Dictionary:
```

按 2D 网格变换和 tile id 重映射展开邻接规则。 用于把少量方向性规则扩展为旋转、镜像或对角翻转后的规则集合。该方法只处理 `from`、`to`、`direction` 与可选 `bidirectional` 字段，不创建 tile 变体、不读取资源， 也不假设 tile 的业务含义。

参数：

| 名称 | 说明 |
|---|---|
| `adjacency_rules` | 基础四向邻接规则数组。 |
| `transform_specs` | 规则变换声明数组。 |
| `options` | 展开选项。 |

返回：展开报告。

结构：

- `adjacency_rules`: Array[Dictionary]，每项包含 from、to、direction，可选 bidirectional。tile id 归一规则与 solve_grid() 一致。
- `transform_specs`: Array[Dictionary]，每项包含 transform: GFGridTransform2D.Transform，可选 tile_remaps: Dictionary[原 tile id, 变换后 tile id]。空数组表示只做 identity 归一化与去重。
- `options`: Dictionary 支持 preserve_unknown_remaps: bool，默认为 true；为 false 时缺少 tile_remaps 的规则会被跳过。
- `return`: Dictionary，包含 ok、error、rules、input_rule_count、transform_count、expanded_count、duplicate_count 和 skipped_count。
