# 2D SAT Narrowphase 精确检测

`GFCollisionNarrowphase2D` 提供纯 2D 凸形状 SAT 精确重叠测试。它适合接在 `GFCollisionBroadphase2D` 生成的候选 pair 后面，用于判断旋转盒或凸多边形是否真正重叠，并得到相切状态、穿透深度、法线和最小平移向量。

## 定位

Narrowphase 只处理几何判定，不维护空间索引，也不执行物理响应、接触点求解、伤害、阵营、命中分发或节点生命周期。它不替代 Broadphase：Broadphase 回答“一批 AABB 中哪些 pair 需要进一步检查”，Narrowphase 回答“某一对凸形状是否精确重叠”。

首批能力只支持凸多边形和旋转盒。凹多边形、共线退化点集和少于三个顶点的 shape 会被拒绝，并在报告中返回 `invalid_shape`。

## 典型流程

```gdscript
var attacker_shape := GFCollisionNarrowphase2D.make_box(
	Vector2(12.0, 8.0),
	Vector2(4.0, 2.0),
	deg_to_rad(30.0)
)

var target_shape := GFCollisionNarrowphase2D.make_polygon(PackedVector2Array([
	Vector2(10.0, 7.0),
	Vector2(14.0, 7.0),
	Vector2(14.0, 10.0),
	Vector2(10.0, 10.0),
]))

var report := GFCollisionNarrowphase2D.test_shapes_overlap(
	attacker_shape,
	target_shape,
	{ "include_touching": false }
)

if report.overlap:
	print(report.normal, report.penetration_depth)
```

`make_box()` 会生成一个 `polygon` shape。`make_polygon()` 会复制调用方 metadata，但不会解释 metadata 字段。

## 报告字段

`test_polygon_overlap()` 和 `test_shapes_overlap()` 返回 Dictionary：

- `overlap`：是否按当前相切策略视为重叠。
- `touching`：是否仅边界相切。
- `reason`：`overlap`、`separated`、`touching` 或 `invalid_shape`。
- `penetration_depth`：最小穿透深度；仅相切时为 `0.0`。
- `normal`：从 A 指向 B 的最小平移方向。
- `minimum_translation`：`normal * penetration_depth`。
- `axis_count`：参与 SAT 测试的轴数量。

默认不把仅边界相切视为 `overlap`，但仍会返回 `touching = true` 和 `reason = touching`。需要把相切纳入重叠时传入 `{ "include_touching": true }`。

## 使用边界

- 只传入凸多边形顶点，且顶点应按顺时针或逆时针顺序排列。
- 需要大量实体时，先用 `GFCollisionBroadphase2D` 粗筛，再对候选 pair 做 SAT。
- 需要凹多边形时，项目应先把它拆成多个凸多边形，再逐个调用 Narrowphase。
- 需要接触点、反弹、摩擦或实际位移时，由 Physics 扩展或项目系统解释 `minimum_translation`，GF Foundation 不执行响应。
