# AABB Broadphase 候选对

`GFCollisionBroadphase2D` 与 `GFCollisionBroadphase3D` 提供纯 AABB 粗筛候选对生成。它们适合服务器模拟、逻辑碰撞预筛、战斗命中候选收集、编辑器预览和不想创建 Godot 物理节点的批量空间规则。

## 核心模型

Broadphase body 是一个 Dictionary，保存调用方实体标识、AABB、碰撞层、碰撞掩码、启用状态和元数据：

```gdscript
var body := GFCollisionBroadphase2D.make_body(
	unit_id,
	Rect2(unit_position, unit_size),
	1,
	0xffffffff
)
```

2D 使用 `Rect2`，3D 使用 `AABB`。负尺寸会被归一化，disabled body 默认不参与候选对。候选 pair 只包含 `a`、`b`、输入索引和两侧 bounds；GF 不解释 entity 是节点、ID、资源还是项目自定义值。

## 算法入口

小集合可以直接使用暴力枚举；较大集合使用 SAP，2D 还提供 Quadtree：

```gdscript
var pairs := GFCollisionBroadphase2D.find_pairs_sap(bodies)

var tree_pairs := GFCollisionBroadphase2D.find_pairs_quadtree(
	bodies,
	{
		"world_bounds": Rect2(Vector2.ZERO, Vector2(4096, 4096)),
		"quadtree_capacity": 8,
		"quadtree_max_depth": 8,
	}
)

var report := GFCollisionBroadphase3D.build_pair_report(aabb_bodies)
```

`find_pairs_combined()` / `build_pair_report()` 会根据 body 数量选择算法，也可以通过 `options.algorithm` 强制为 `bruteforce`、`sap` 或 2D 的 `quadtree`。

2D Quadtree 的 `world_bounds` 只用于空间分割，不是过滤条件。调用方传入的 `world_bounds` 没覆盖全部 body 时，Quadtree 会在当前节点退回局部暴力枚举，保证 world 外 body 之间的候选 pair 不会被静默丢弃。

## 过滤规则

默认会同时检查双方 layer/mask：

```text
(a.collision_layer & b.collision_mask) != 0
and (b.collision_layer & a.collision_mask) != 0
```

需要纯几何粗筛时，可以传入 `{ "use_collision_masks": false }`。默认不把仅边界相切视为重叠；需要把相切也纳入候选时，传入 `{ "include_touching": true }`。

## 使用边界

Broadphase 只负责生成“可能相交”的候选对。需要对 2D 凸多边形或旋转盒做精确 SAT 判断时，把候选 pair 交给 [2D SAT Narrowphase 精确检测](collision-narrowphase-2d.md) 中的 `GFCollisionNarrowphase2D`。GJK、接触点、物理响应、伤害规则、阵营过滤、命中分发和节点生命周期仍应由 Physics、Combat、Interaction 扩展或项目层处理。

`GFQuadTreeUtility` 是带生命周期的 2D 范围查询工具，适合 `query_rect()`、`query_radius()` 和点拾取；`GFSpatialHash3D` 是 3D 空间哈希范围查询工具。Broadphase 与它们不互相替代：范围查询回答“某个区域内有哪些实体”，Broadphase 回答“一批 body 中哪些 pair 需要后续精确检测”。
