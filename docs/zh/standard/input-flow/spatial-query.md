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

2D facade 在记录与配置稳定时复用四叉树。变更后的首次四叉树查询会根据当前记录重新计算边界并尝试建树。边界无法建树或建树失败时采用线性查询，直到下一次记录或配置变化。查询前只检查以弱引用存储的 `Object` 身份，适合在主要使用值 ID 的画布或战术地图上反复点查。

3D facade 在某次查询超过空间哈希的格子预算时，会仅对该次查询使用线性扫描，保留完整结果；后续可承受的查询仍使用已有哈希索引。零半径查询使用闭边界点语义，包含 AABB 最大面、棱和角上的命中。

`GFSpatialQueryIdentity` 只接受 `Object`、非空 `StringName`、非空 `String` 或 `int`。`Object` 以 weakref 方式保存，不会因为进入空间索引而被强持有；`Array`、`Dictionary` 等可变复合值会被拒绝，避免索引键在插入后被调用方修改而导致删除、更新和查询结果不可预测。2D facade 会把稳定身份映射为四叉树内部 surrogate int，因此底层 `GFQuadTreeUtility` 的 `int entity_id` 限制不会泄漏到 facade API。AABB 覆盖格子时使用半开最大边界，恰好落在格子边界的盒子不会额外占用相邻格。

## 两点之间的分层可见性 {#segment-visibility-masks}

`gf.standard.spatial` 的 `GFSegmentVisibility2D` 用整数坐标上的闭线段计算视线。每个图层独立判定。查询从 `valid_mask` 开始，每条命中的障碍扣除自己的 `blocked_mask`。项目可以复用同一份只读拓扑查询一条边，或一次计算所有无序点对。

```gdscript
var ids := PackedInt64Array([0, 1, 2, 3, 4])
var points: Array[Vector2i] = [
    Vector2i(0, 0), Vector2i(0, 3), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 1),
]
var walls: Array[Dictionary] = [{
    "from": points[0], "to": points[1],
    "from_id": 0, "to_id": 1, "blocked_mask": 6,
}]
var topology := GFSegmentVisibility2D.create(ids, points, walls, 7)
assert(topology != null)
assert(topology.get_visible_mask(0, 2) == 7)  # 仅接触墙上已命名的 0 号端点
assert(topology.get_visible_mask(2, 3) == 1)  # 视线中途碰到墙端
assert(topology.get_visible_mask(0, 4) == 1)  # 沿墙重叠一段
var result := topology.compute_pair_masks()
if result.ok:
    var masks: PackedInt64Array = result.masks
    assert(masks[topology.get_pair_index(3, 2)] == 1)
```

每条障碍必须给出 `from` 和 `to`。省略 `blocked_mask` 会遮挡全部有效图层，设为 `0` 会放行全部图层。只有填入 `from_id` 或 `to_id` 且与查询端点身份相同，单点接触才放行。仅坐标相同的两个 ID 仍是不同端点。正长度共线重叠始终按障碍掩码处理。查询点重合、查询同一 ID 或障碍退化为点时，都遵循同一条单点接触规则。

| 约束 | 行为 |
| --- | --- |
| 点和坐标 | 最多 2,048 个唯一的有符号 64 位 ID 和 4,096 条障碍。每个坐标分量的绝对值最大为 `2^30 - 1`，保证叉积能用有符号 64 位整数精确计算。 |
| 图层和输入 | 低 63 位可用，可稀疏或全零。遮挡位必须是有效位的子集。重复 ID、端点 ID 与坐标不符、未知字段和非法值均使 `create()` 返回 `null`。 |
| 单对与索引 | 交换两端结果相同。查询未知 ID 返回 `-1`，完全遮挡返回 `0`。批量按输入行 `(0,1), (0,2), …, (1,2), …` 打包，同一 ID 或未知 ID 的批量索引为 `-1`。 |
| 批量预算 | 可用参数收紧预算。硬上限为 262,144 个点对（2 MiB 输出）和 1,048,576 次潜在相交测试（点对数 × 障碍数）。先检查预算再分配。失败时 `ok == false`、`error` 给出原因、`masks` 为空。零或一个点成功返回空数组。 |

创建时复制输入，每次批量查询返回独立数组。安装 GF Native 后，主线程以及 Windows x64 的工作线程会自动加速非零图层且至少有 8 次潜在线段测试的批次。纯脚本安装、其他平台的工作线程和小批次走 GDScript。读取结果的 `backend` 可确认本次执行路径，值为 `native` 或 `gdscript`。预算等准入检查失败时此字段为空。

项目可以在工作线程上创建拓扑并同步调用批处理。调度方持有拓扑至调用结束，接收结果时核对提交时的修订号。取消后丢弃过期结果，退出时等待在途任务结束。坐标、端点身份或图层发生变化时创建新拓扑。

## Environment Query 组合边界

需要把空间候选交给 Decision 评分时，先把查询记录冻结成有界的 data-only 候选；`query_records_*()` 返回的 `entity` 可能是实时 Object，不能进入异步任务、持久化或诊断快照。只保留稳定 `identity`、位置或 bounds，以及项目白名单允许的 metadata，随后在项目层完成过滤、测试和评分。完整流程见 [Decision 的 Environment Query 组合配方](../../extensions/decision/index.md)。

当前 `GFSpatialQueryIndex2D` / `GFSpatialQueryIndex3D` 查询没有 `max_results` 或取消参数，单次调用不会被 `GFExecutionBudget` 抢占。需要硬延迟上限时，应在调用前限制索引人口、世界分区、查询半径和调用频率；不要先扫描无界世界，再对返回数组做截断。

---


## 相关 GF 内置扩展

`GFLevelUtility` 与 `GFQuestUtility` 的完整说明见 [Domain 通用领域模型](../../extensions/domain/index.md)，`GFBehaviorTree` 的完整说明见 [BehaviorTree 纯代码行为树](../../extensions/behavior-tree/index.md)。标准库页面只交叉引用这些扩展能力，避免同一概念在多个页面重复维护。
