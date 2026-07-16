# GFPoissonDisc2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_poisson_disc_2d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`5.0.0`

通用二维 Poisson-disc 采样工具。 在矩形区域中生成最小间距受限的点集，适合程序化摆放、刷点候选、 空间采样和编辑器工具。它只返回纯数据，不创建 Node、地形、碰撞或渲染资源。 随机序列来自 GF 固定算法随机源；输出点仍是浮点几何数据，不作为定点锁步真值。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_CANDIDATE_ATTEMPTS`](#member-gfpoissondisc2d-constants-default_candidate_attempts) | `const DEFAULT_CANDIDATE_ATTEMPTS: int = 30` |
| 常量 | [`DEFAULT_MAX_POINTS`](#member-gfpoissondisc2d-constants-default_max_points) | `const DEFAULT_MAX_POINTS: int = 4096` |
| 常量 | [`DEFAULT_MAX_GRID_CELLS`](#member-gfpoissondisc2d-constants-default_max_grid_cells) | `const DEFAULT_MAX_GRID_CELLS: int = 262144` |
| 方法 | [`generate_points`](#member-gfpoissondisc2d-methods-generate_points) | `static func generate_points(area: Rect2, minimum_distance: float, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`to_json_compatible_report`](#member-gfpoissondisc2d-methods-to_json_compatible_report) | `static func to_json_compatible_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfpoissondisc2d-constants-default_candidate_attempts"></a>

### `DEFAULT_CANDIDATE_ATTEMPTS`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_CANDIDATE_ATTEMPTS: int = 30
```

默认每个活动点尝试生成候选点的次数。

<a id="member-gfpoissondisc2d-constants-default_max_points"></a>

### `DEFAULT_MAX_POINTS`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_MAX_POINTS: int = 4096
```

默认最大输出点数，避免误把超大实时采样交给纯 GDScript。

<a id="member-gfpoissondisc2d-constants-default_max_grid_cells"></a>

### `DEFAULT_MAX_GRID_CELLS`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_MAX_GRID_CELLS: int = 262144
```

默认最大空间网格单元数量，避免极小半径导致大内存分配。

## 方法

<a id="member-gfpoissondisc2d-methods-generate_points"></a>

### `generate_points`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func generate_points(area: Rect2, minimum_distance: float, options: Dictionary = {}) -> Dictionary:
```

在矩形区域中生成 Poisson-disc 采样点。

参数：

| 名称 | 说明 |
|---|---|
| `area` | 采样区域。 |
| `minimum_distance` | 任意两点之间的最小距离。 |
| `options` | 可选参数，支持 seed、candidate_attempts、max_points、max_grid_cells 和 start_point。 |

返回：采样结果字典。

结构：

- `options`: Dictionary，seed 为确定性随机种子，candidate_attempts 为每个活动点的候选尝试次数，max_points 为最大输出点数，max_grid_cells 为内部空间网格单元上限，start_point 为可选起始 Vector2。
- `return`: Dictionary，包含 ok、error、area、minimum_distance、seed、candidate_attempts、max_points、max_grid_cells、points、point_count 与 truncated 字段。

<a id="member-gfpoissondisc2d-methods-to_json_compatible_report"></a>

### `to_json_compatible_report`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func to_json_compatible_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:
```

将采样报告编码为 JSON.stringify() 安全字典。

参数：

| 名称 | 说明 |
|---|---|
| `report` | generate_points() 返回的原生报告。 |
| `options` | GFReportValueCodec 编码选项。 |

返回：JSON 兼容报告。

结构：

- `report`: Dictionary returned by generate_points().
- `options`: Dictionary with GFReportValueCodec options.
- `return`: Dictionary safe for JSON.stringify().
