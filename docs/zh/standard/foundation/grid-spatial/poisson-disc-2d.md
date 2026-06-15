# 2D Poisson-disc 采样

`GFPoissonDisc2D` 在矩形区域内生成最小距离受限的二维点集。它适合程序化摆放、刷点候选、地图装饰、采样分布和编辑器工具，但不创建节点、地形、碰撞、材质或渲染资源。

## 适用场景

- 需要让资源点、装饰点、候选交互点或调试采样点保持自然间距。
- 需要固定随机序列生成，可用同一个 `seed` 在同一 GF 算法版本中复现点集。
- 需要把采样结果交给项目层自己的地形、网格、导航、对象生成或可视化流程。

不适合把它作为大型运行时世界流式生成的完整方案。分块生命周期、LOD、对象池、地形高度、碰撞和内容语义应留在项目侧或专门扩展中。

采样随机源使用 `GFDeterministicRandom`，不会依赖 Godot `RandomNumberGenerator` 的内部算法。输出点是 `Vector2` 浮点几何数据，适合工具、生成候选和 golden 测试；如果项目需要锁步真值或长期稳定 hash，应把最终状态转换为整数网格、`GFFixedDecimal` 或定点向量后再进入确定性序列化。

## 基本用法

```gdscript
var result := GFPoissonDisc2D.generate_points(
	Rect2(Vector2.ZERO, Vector2(128.0, 128.0)),
	8.0,
	{
		"seed": 42,
		"candidate_attempts": 24,
		"max_points": 512,
	}
)

if result["ok"]:
	var points: PackedVector2Array = result["points"]
	for point: Vector2 in points:
		_spawn_candidate_at(point)
```

`start_point` 可用于指定第一个采样点，便于围绕玩家、房间中心或工具光标生成稳定分布：

```gdscript
var around_center := GFPoissonDisc2D.generate_points(
	Rect2(Vector2(-64.0, -64.0), Vector2(128.0, 128.0)),
	6.0,
	{ "seed": 11, "start_point": Vector2.ZERO }
)
```

## 返回结构

`generate_points()` 返回一个 Dictionary：

- `ok` / `error`：输入是否有效。
- `area`：采样区域。
- `minimum_distance`：实际使用的最小距离。
- `seed`：GF 固定随机源种子。
- `candidate_attempts`：每个活动点最多尝试的候选次数。
- `max_points`：最大输出点数。
- `max_grid_cells`：内部空间网格单元上限。
- `points`：生成的 `PackedVector2Array`。
- `point_count`：输出点数量。
- `truncated`：达到 `max_points` 时是否仍存在可继续扩展的活动点。

## 选项

- `seed`：GF 固定随机源种子，默认 `0`。
- `candidate_attempts`：每个活动点的候选尝试次数，默认 `GFPoissonDisc2D.DEFAULT_CANDIDATE_ATTEMPTS`。
- `max_points`：最大输出点数，默认 `GFPoissonDisc2D.DEFAULT_MAX_POINTS`。
- `max_grid_cells`：内部空间网格单元上限，默认 `GFPoissonDisc2D.DEFAULT_MAX_GRID_CELLS`。当区域很大且 `minimum_distance` 很小时，这个上限会阻止大内存分配。
- `start_point`：可选起始 `Vector2`，必须位于 `area` 内。

## 与其他模块的关系

- `GFVoronoi2D` 可消费采样点，生成区域 cell 或邻接关系。
- `GFDeterministicRandom` 提供采样所需的固定随机序列；`GFPoissonDisc2D` 只消费它，不管理项目全局随机流。
- `GFGraphMath` 可把采样点派生出的边转换为项目层路径图。
- `GFSpatialHash3D`、`GFQuadTreeUtility` 关注运行时空间查询；`GFPoissonDisc2D` 只负责生成候选点。
