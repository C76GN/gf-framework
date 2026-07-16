# 2D Wave Function Collapse

`GFWaveFunctionCollapse2D` 提供简单 tiled WFC 的纯数据求解入口。项目声明 tile id、权重、四向邻接规则、固定格和 seed 后，工具返回格子到 tile id 的结果、剩余 domain 和诊断信息。

它适合程序化地图草图、关卡块拼接、编辑器生成前预检和规则调试。它不读取图片、不提取样本、不创建 TileMap、不处理 tileset 资源，也不内置房间、地形、碰撞或视觉表现语义。需要旋转、镜像或对角翻转规则时，可先用纯数据 helper 展开邻接规则，再把结果传给求解器。

## 基本用法

```gdscript
var tiles: Array = [
	{ "id": &"floor", "weight": 3.0 },
	{ "id": &"wall", "weight": 1.0 },
]

var rules: Array[Dictionary] = [
	{ "from": &"floor", "to": &"wall", "direction": Vector2i.RIGHT },
	{ "from": &"wall", "to": &"floor", "direction": Vector2i.RIGHT },
	{ "from": &"floor", "to": &"wall", "direction": Vector2i.DOWN },
	{ "from": &"wall", "to": &"floor", "direction": Vector2i.DOWN },
]

var report: Dictionary = GFWaveFunctionCollapse2D.solve_grid(
	Vector2i(16, 16),
	tiles,
	rules,
	{
		"seed": 123,
		"fixed_cells": {
			Vector2i.ZERO: &"floor",
		},
	}
)

if report["ok"]:
	var grid: Dictionary = report["grid"]
	var tile_id: Variant = grid[Vector2i(4, 2)]
```

空 `adjacency_rules` 表示邻接不受限制，可作为带 seed 的加权随机格生成器使用。一旦声明任意规则，未声明的方向和 tile 组合都视为禁止。

## 规则展开

当 tile 变体可以用旋转、镜像或对角翻转表达时，可用 `expand_transformed_adjacency_rules()` 把少量基础规则展开成完整方向规则。调用方仍然负责定义 tile id 变体和重映射表。

```gdscript
var expansion := GFWaveFunctionCollapse2D.expand_transformed_adjacency_rules(
	[
		{ "from": &"road_e", "to": &"road_e", "direction": Vector2i.RIGHT },
	],
	[
		{
			"transform": GFGridTransform2D.Transform.IDENTITY,
			"tile_remaps": { &"road_e": &"road_e" },
		},
		{
			"transform": GFGridTransform2D.Transform.ROTATE_90,
			"tile_remaps": { &"road_e": &"road_s" },
		},
	]
)

if expansion["ok"]:
	var report := GFWaveFunctionCollapse2D.solve_grid(
		Vector2i(16, 16),
		[&"road_e", &"road_s"],
		expansion["rules"],
		{ "seed": 123 }
	)
```

展开报告包含 `rules`、`expanded_count`、`duplicate_count` 和 `skipped_count`。默认情况下，没有出现在 `tile_remaps` 中的 tile id 会原样保留；如果需要跳过这类规则，可设置 `preserve_unknown_remaps=false`。

## 返回结构

`solve_grid()` 返回一个 Dictionary：

- `ok` / `error`：求解是否成功。
- `status`：`complete`、`contradiction`、`step_limit` 或 `invalid_input`。
- `grid_size`、`seed`、`heuristic`、`periodic`：本次求解的核心参数。
- `cell_count`、`tile_count`、`max_cells`、`max_tiles`、`max_steps`：规模与安全上限。
- `step_count`、`collapsed_count`、`undecided_count`：求解进度统计。
- `contradiction_cell`：矛盾发生位置；无矛盾时是哨兵值。
- `grid`：已坍缩格子的 `Dictionary[Vector2i, tile id]`。
- `domains`：每个格子剩余候选 tile id 数组，便于调试规则。

文字 tile id 会归一为 `StringName`，整数 tile id 会保留为 `int`。tile 权重必须是有限正数，避免非有限值进入诊断或 JSON 入口。

`grid`、`domains` 和规则展开报告会保留 `Vector2i` key、`StringName` 与 packed 类型，方便项目内继续组合。需要跨 JSON 边界时，使用 `GFWaveFunctionCollapse2D.to_json_compatible_report(report)`；它默认编码字典 key，避免 `Vector2i` key 在普通 JSON 对象中丢失语义。

## 选项

- `seed`：确定性随机 seed。
- `heuristic`：`GFWaveFunctionCollapse2D.Heuristic.ENTROPY`、`MRV`、`SCANLINE`，或 `"entropy"` / `"mrv"` / `"scanline"`。
- `periodic`：是否把边界视为环绕。
- `fixed_cells`：`Dictionary[Vector2i, tile id]`，用于预放置或边界约束。
- `bidirectional_rules`：规则默认是否自动补反向关系，默认 `true`。
- `max_cells`、`max_tiles`、`max_steps`：纯 GDScript 求解安全上限。

## 使用边界

- 需要图片样本提取、tile 变体生成、tileset 导入或可视化编辑器时，应在项目工具或可选插件中基于本求解报告组合。
- 需要流式大地图时，应按 chunk 分批求解，并由项目层处理 chunk 接缝约束。
- WFC 只保证满足声明的局部邻接规则；房间连通、玩法可达、资源预算和美术语义仍应由项目侧校验。

## 与其他模块的关系

- `GFGridMath` 提供通用网格、路径、迷宫和细胞自动机算法；WFC 专注于 tile 邻接约束。
- `GFGridTransform2D` 提供 WFC 规则展开使用的离散方向变换语义，项目侧画刷、TileMap 片段和 WFC 邻接方向应复用同一套 Transform 枚举。
- `GFNoiseFieldTools` 可先生成权重图或区域草图，再由项目层把它转换为 WFC 的固定格或候选规则。
- `GFTileMapCache` 可在项目层消费 `grid`，把 tile id 映射为 TileMap 坐标或资源。
