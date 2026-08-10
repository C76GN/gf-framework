# 逻辑空间查询与相关扩展

标准库提供纯逻辑空间查询工具用于轻量范围检索，也提供少量不绑定玩法语义的物理查询辅助；流程、任务和行为树能力位于对应 GF 内置扩展页面。

## 物理多命中射线 (`GFPhysicsQueryUtility`)

Godot 的 `intersect_ray()` 默认返回第一处命中。需要激光、穿透检测、遮挡层分析或编辑器拾取时，可以用 `GFPhysicsQueryUtility.raycast_all_3d()` 沿同一条 3D 射线收集多个命中结果。

```gdscript
var query := Gf.get_utility(GFPhysicsQueryUtility) as GFPhysicsQueryUtility

var hits := query.raycast_all_3d(
	get_world_3d(),
	global_position,
	global_position + -global_basis.z * 20.0,
	{
		"collision_mask": 0xffffffff,
		"max_results": 8,
		"margin": 0.02,
		"exclude": [self],
	}
)
```

每次命中后，工具会把该命中的 RID 加入本次查询的排除列表，并沿射线方向推进 `margin`，直到没有更多命中、到达终点或达到 `max_results`。返回项保留 Godot `intersect_ray()` 的原始字段，同时额外写入 `index` 和 `distance`，方便调用方排序、截断或调试。

`GFPhysicsQueryUtility` 不解释碰撞体含义，不发送 hit / interaction，不管理穿透次数消耗，也不创建可视化光束。项目需要命中分发时，可以把结果交给 Interaction 或 Combat 扩展；需要调试线条时，用 DebugDraw 或项目自己的视觉节点表达。

## 逻辑四叉树 (`GFQuadTreeUtility`)

抛开需要碰撞体积的 Godot `Area2D` 体系；对于上千同屏单位仅仅用于查询范围索敌、视野扫描或邻居列表时，可以使用这个纯代码二维空间索引加速。它只保存 `entity_id -> Rect2` 的映射，调用方仍要自己维护实体表、坐标更新和最终业务过滤。

```gdscript
var quad_tree := Gf.get_utility(GFQuadTreeUtility) as GFQuadTreeUtility

# 初始化世界边界、最大深度和单节点容量。
quad_tree.setup(Rect2(Vector2.ZERO, Vector2(4096, 4096)), 8, 8)

# entity_id 由项目层自己管理，Rect2 是实体的轴对齐包围盒。
quad_tree.insert(1001, Rect2(Vector2(128, 256), Vector2(32, 32)))
quad_tree.update(1001, Rect2(Vector2(160, 260), Vector2(32, 32)))

var nearby_ids := quad_tree.query_radius(Vector2(160, 260), 96.0)
var visible_ids := quad_tree.query_rect(Rect2(Vector2(0, 0), Vector2(512, 512)))
var clicked_ids := quad_tree.query_point(Vector2(172, 272))

quad_tree.remove(1001)
```

`query_rect()` 返回与查询矩形相交的实体 ID，`query_radius()` 会先按圆的外接矩形找候选，再按矩形到圆心的最近点做二次过滤。`query_point()` 适合点击、悬停或逻辑拾取；默认先用实体 AABB 粗筛，再执行项目通过 `set_entity_hit_test()` 或 `insert_with_hit_test()` 注册的精确命中测试。命中测试只接收 `(entity_id, point, rect)`，GF 不规定形状类型、节点来源或业务含义。需要只看 AABB 粗筛结果时，可传入 `query_point(point, false)`。

四叉树会归一化负尺寸矩形、限制无效深度和容量，并在缺少根节点时惰性重建；负半径查询直接返回空数组。给 `bounds` 或 `setup()` 传入非有限边界会在修改前失败并保留最后有效边界、实体和命中测试；合法边界收缩仍会显式裁掉不再位于新范围内的实体。重复 `insert()` 同一个 `entity_id` 会替换旧矩形，`update()` 会保留已注册的命中测试，`compact()` 可在大量移动或删除后显式重建节点结构。它不会替代 Godot 物理检测，也不会自动跟踪节点移动；实体离开世界边界、跨多个象限或需要精确形状判定时，项目层需要继续维护实体表和命中测试。

## 查询策略 facade

当项目想先写稳定查询 API，再按实体数量切换具体索引时，可以使用 `GFSpatialQueryIndex2D` 或 `GFSpatialQueryIndex3D`。2D facade 在 `linear` 与 `quadtree` 之间切换，3D facade 在 `linear` 与 `spatial_hash` 之间切换；两者都使用 `GFSpatialQueryIdentity` 规范化实体身份。

```gdscript
var index_2d := GFSpatialQueryIndex2D.new()
index_2d.configure(Rect2(Vector2.ZERO, Vector2(4096, 4096)), GFSpatialQueryIndex2D.STRATEGY_AUTO)
index_2d.upsert(&"enemy:1001", Rect2(Vector2(128, 256), Vector2(32, 32)), {
	"team": "blue",
})

var hits := index_2d.query_records_radius(Vector2(160, 260), 96.0)
var entity := hits[0]["entity"]
var identity := hits[0]["identity"]
```

```gdscript
var index_3d := GFSpatialQueryIndex3D.new()
index_3d.configure(GFSpatialQueryIndex3D.STRATEGY_AUTO, { "cell_size": 4.0 })
index_3d.upsert(&"enemy:1001", AABB(Vector3(0, 0, 0), Vector3.ONE * 2.0))

var nearby := index_3d.query_records_radius(Vector3.ZERO, 8.0)
```

facade 只输出实体值、统一 `identity` 快照和调用方 metadata。阵营过滤、可见性、伤害、交互派发和节点生命周期仍由项目或对应扩展处理。小集合可以强制 `STRATEGY_LINEAR`，需要稳定调试索引时可读取 `get_debug_snapshot()` 查看当前实际策略。

`GFSpatialQueryIdentity` 只接受 `Object`、非空 `StringName`、非空 `String` 或 `int`。`Object` 以 weakref 方式保存，不会因为进入空间索引而被强持有；`Array`、`Dictionary` 等可变复合值会被拒绝，避免索引键在插入后被调用方修改而导致删除、更新和查询结果不可预测。2D facade 会把稳定身份映射为四叉树内部 surrogate int，因此底层 `GFQuadTreeUtility` 的 `int entity_id` 限制不会泄漏到 facade API。AABB 覆盖格子时使用半开最大边界，恰好落在格子边界的盒子不会额外占用相邻格。

---


## 相关 GF 内置扩展

`GFLevelUtility` 与 `GFQuestUtility` 的完整说明见 [Domain 通用领域模型](../../extensions/domain/index.md)，`GFBehaviorTree` 的完整说明见 [BehaviorTree 纯代码行为树](../../extensions/behavior-tree/index.md)。标准库页面只交叉引用这些扩展能力，避免同一概念在多个页面重复维护。
