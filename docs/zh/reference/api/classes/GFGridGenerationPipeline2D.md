# GFGridGenerationPipeline2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_grid_generation_pipeline_2d.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用 2D 网格生成管线。 以候选格子为输入，按步骤输出 `Dictionary[Vector2i, Variant]`。 适合程序化生成的中间数据层，不绑定任何具体节点、资源或玩法类型。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`steps`](#member-gfgridgenerationpipeline2d-properties-steps) | `var steps: Array[GFGridGenerationStep2D] = []` |
| 属性 | [`fill_default_value`](#member-gfgridgenerationpipeline2d-properties-fill_default_value) | `var fill_default_value: bool = false` |
| 属性 | [`default_value`](#member-gfgridgenerationpipeline2d-properties-default_value) | `var default_value: Variant = null` |
| 属性 | [`metadata`](#member-gfgridgenerationpipeline2d-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`make_rect_candidates`](#member-gfgridgenerationpipeline2d-methods-make_rect_candidates) | `static func make_rect_candidates(position: Vector2i, size: Vector2i) -> Array[Vector2i]:` |
| 方法 | [`generate`](#member-gfgridgenerationpipeline2d-methods-generate) | `func generate(candidates: Array[Vector2i], context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`generate_with_report`](#member-gfgridgenerationpipeline2d-methods-generate_with_report) | `func generate_with_report(candidates: Array[Vector2i], context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply_to_grid`](#member-gfgridgenerationpipeline2d-methods-apply_to_grid) | `func apply_to_grid( grid: Dictionary, candidates: Array[Vector2i], context: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`apply_to_grid_with_report`](#member-gfgridgenerationpipeline2d-methods-apply_to_grid_with_report) | `func apply_to_grid_with_report( grid: Dictionary, candidates: Array[Vector2i], context: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`add_step`](#member-gfgridgenerationpipeline2d-methods-add_step) | `func add_step(step: GFGridGenerationStep2D) -> void:` |
| 方法 | [`clear_steps`](#member-gfgridgenerationpipeline2d-methods-clear_steps) | `func clear_steps() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfgridgenerationpipeline2d-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfgridgenerationpipeline2d-properties-steps"></a>

### `steps`

- API：`public`

```gdscript
var steps: Array[GFGridGenerationStep2D] = []
```

生成步骤。

<a id="member-gfgridgenerationpipeline2d-properties-fill_default_value"></a>

### `fill_default_value`

- API：`public`

```gdscript
var fill_default_value: bool = false
```

是否在执行步骤前为全部候选格子写入默认值。

<a id="member-gfgridgenerationpipeline2d-properties-default_value"></a>

### `default_value`

- API：`public`

```gdscript
var default_value: Variant = null
```

默认值。

结构：

- `default_value`: Variant value written before steps when fill_default_value is enabled.

<a id="member-gfgridgenerationpipeline2d-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

管线元数据。

结构：

- `metadata`: Dictionary extension metadata for the generation pipeline.

## 方法

<a id="member-gfgridgenerationpipeline2d-methods-make_rect_candidates"></a>

### `make_rect_candidates`

- API：`public`

```gdscript
static func make_rect_candidates(position: Vector2i, size: Vector2i) -> Array[Vector2i]:
```

从矩形范围生成候选格子。

参数：

| 名称 | 说明 |
|---|---|
| `position` | 范围起点。 |
| `size` | 范围尺寸。 |

返回：候选格子。

<a id="member-gfgridgenerationpipeline2d-methods-generate"></a>

### `generate`

- API：`public`

```gdscript
func generate(candidates: Array[Vector2i], context: Dictionary = {}) -> Dictionary:
```

执行生成管线。

参数：

| 名称 | 说明 |
|---|---|
| `candidates` | 候选格子。 |
| `context` | 项目自定义上下文。 |

返回：生成结果字典，key 为 Vector2i。

结构：

- `context`: Dictionary project-defined generation context.
- `return`: Dictionary mapping Vector2i cells to generated values.

<a id="member-gfgridgenerationpipeline2d-methods-generate_with_report"></a>

### `generate_with_report`

- API：`public`
- 首次版本：`4.2.0`

```gdscript
func generate_with_report(candidates: Array[Vector2i], context: Dictionary = {}) -> Dictionary:
```

执行生成管线，并返回执行报告。

参数：

| 名称 | 说明 |
|---|---|
| `candidates` | 候选格子。 |
| `context` | 项目自定义上下文。 |

返回：执行报告，包含生成结果和步骤统计。

结构：

- `context`: Dictionary project-defined generation context.
- `return`: Dictionary with ok, grid, candidate_count, initial_grid_count, default_filled_count, final_grid_count, configured_step_count, applied_step_count, skipped_step_count, changed_count, elapsed_usec, metadata, and steps.

<a id="member-gfgridgenerationpipeline2d-methods-apply_to_grid"></a>

### `apply_to_grid`

- API：`public`

```gdscript
func apply_to_grid( grid: Dictionary, candidates: Array[Vector2i], context: Dictionary = {} ) -> Dictionary:
```

在已有网格上执行生成管线。

参数：

| 名称 | 说明 |
|---|---|
| `grid` | 目标网格字典，key 为 Vector2i。 |
| `candidates` | 候选格子。 |
| `context` | 项目自定义上下文。 |

返回：目标网格本身。

结构：

- `grid`: Dictionary mapping Vector2i cells to generated values; mutated in place.
- `context`: Dictionary project-defined generation context.
- `return`: Dictionary same grid instance passed to the method.

<a id="member-gfgridgenerationpipeline2d-methods-apply_to_grid_with_report"></a>

### `apply_to_grid_with_report`

- API：`public`
- 首次版本：`4.2.0`

```gdscript
func apply_to_grid_with_report( grid: Dictionary, candidates: Array[Vector2i], context: Dictionary = {} ) -> Dictionary:
```

在已有网格上执行生成管线，并返回执行报告。

参数：

| 名称 | 说明 |
|---|---|
| `grid` | 目标网格字典，key 为 Vector2i。 |
| `candidates` | 候选格子。 |
| `context` | 项目自定义上下文。 |

返回：执行报告，grid 字段为传入的目标网格。

结构：

- `grid`: Dictionary mapping Vector2i cells to generated values; mutated in place.
- `context`: Dictionary project-defined generation context.
- `return`: Dictionary with ok, grid, candidate_count, initial_grid_count, default_filled_count, final_grid_count, configured_step_count, applied_step_count, skipped_step_count, changed_count, elapsed_usec, metadata, and steps.

<a id="member-gfgridgenerationpipeline2d-methods-add_step"></a>

### `add_step`

- API：`public`

```gdscript
func add_step(step: GFGridGenerationStep2D) -> void:
```

添加生成步骤。

参数：

| 名称 | 说明 |
|---|---|
| `step` | 生成步骤。 |

<a id="member-gfgridgenerationpipeline2d-methods-clear_steps"></a>

### `clear_steps`

- API：`public`

```gdscript
func clear_steps() -> void:
```

清空生成步骤。

<a id="member-gfgridgenerationpipeline2d-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取诊断快照。

返回：诊断字典。

结构：

- `return`: Dictionary with step_count, fill_default_value, metadata, and steps.
