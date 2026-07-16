# Combat 发射体与移动策略

这一页说明发射体节点、移动策略、生命周期策略、发射器和资源化生成模式。它们只负责发射体实例、运动和通用命中协议，不规定弹药、伤害、穿透或特效。

## 发射体节点与移动策略

`GFProjectile2D` / `GFProjectile3D` 是可选的发射体桥接节点，分别继承 `GFHitBox2D` / `GFHitBox3D`。它们复用同一套 `GFCombatHitContext` 与 `receive_hit(context)` 协议，只额外负责三件事：按移动策略推进位置、按生命周期策略结束、碰到可接收对象时发送命中。若发射体配置了 `sender_path`，且业务发送者实现了 `send_to(receiver, payload_override, hit_id_override)`，自动命中会交给业务发送者接管；否则仍使用发射体自身的 `send_to()`。它们不内置伤害字段、阵营判断、穿透规则、目标筛选或特效生成。

`GFProjectileMotion` 是移动策略协议基类，`GFLinearProjectileMotion` 提供 2D/3D 通用直线移动，`GFHomingProjectileMotion` 可从发射上下文或相对节点路径读取目标对象/目标位置，并按通用速度朝目标推进。`GFProjectileLifetimePolicy` 默认支持按最大秒数、最大距离和成功命中次数结束；`finish_on_impact` 只会在目标接收并返回 `ok = true` 的命中后结束，rejected 或校验失败的尝试不会让发射体误消失。需要对象池时，把 `queue_free_on_finish` 设为 `false`，在 `projectile_finished` 信号中归还节点即可。

需要把“创建发射体”也抽象出来时，可以使用 `GFProjectileEmitter2D` / `GFProjectileEmitter3D`。发射器只负责解析场景、计算生成变换、实例化节点并调用 `launch(context)`；它仍然不规定弹药、冷却、阵营、伤害、分裂或特效。发射场景可以直接挂在 `projectile_scene`，也可以通过 `GFProjectileCatalog` 与 `GFProjectileCatalogEntry` 用稳定 ID 管理。生成点由资源化模式提供：`GFProjectileSpawnPattern2D` / `GFProjectileSpawnPattern3D` 是基类，内置 `GFProjectileBurstPattern2D`、`GFProjectileLineSpawnPattern2D`、`GFProjectileConePattern3D` 和 `GFProjectileLineSpawnPattern3D`，覆盖常见扇形、线段、多炮口和水平锥形分布。

```gdscript
var emitter := GFProjectileEmitter2D.new()
emitter.projectile_scene = preload("res://combat/arrow_projectile.tscn")

var pattern := GFProjectileBurstPattern2D.new()
pattern.projectile_count = 5
pattern.spread_degrees = 45.0
emitter.spawn_pattern = pattern

var projectiles := emitter.emit_projectiles({
	"owner": actor,
	"skill_id": &"multi_shot",
})
```

如果项目使用 `GFObjectPoolUtility`，发射器可通过 `use_object_pool` 从池中获取节点，并在 `projectile_finished` 后自动归还；发射器会在节点入树前关闭常见发射体的 `auto_launch_on_ready`，让本次上下文先准备好再启动。仍建议池化发射体场景默认把 `auto_launch_on_ready` 设为 `false`，这样即使被项目代码直接实例化，也不会用空上下文提前启动。对象池依赖不会由发射器主动从全局 `Gf` 获取：项目可以给 `object_pool_utility` 显式赋值，也可以通过 `GFArchitecture.inject_node_tree()` 注入架构，或把发射器放在 `GFNodeContext` 子树下让它从局部上下文查询对象池。发射器会给每次准备运行态写入新的 emission token，旧的完成信号回调不会释放已经复用到下一轮的发射体。

如果只需要通用发射请求门禁，可以给发射器挂 `GFProjectileEmissionPolicy`，用于限制启用状态、冷却、单次数量和抽象 charge 容量。每次发射由 `GFProjectileEmissionTask` 先冻结时间与上下文，在任何生成点计算或节点分配前执行策略门控和 `hard_projectile_limit_per_request`，生成完成后只提交一次实际数量；中途失败会回滚策略预留，避免失败请求消耗冷却或 charge。它不解释弹药、换弹、技能消耗或 UI 文案；这些语义以及命中后的派生发射、穿透次数和目标过滤仍应由项目技能、能力、状态机或自定义策略资源表达。

发射器、生成模式、移动策略和命中上下文会在写入场景变换前拒绝或归一化非有限数值。项目自定义模式也应只返回有限的 `Transform2D` / `Transform3D`，并把数量限制看作硬边界，而不是仅用于 UI 的建议值。

```gdscript
var projectile := GFProjectile2D.new()
projectile.hit_id = &"arrow"
projectile.payload = { "amount": 12 }
projectile.queue_free_on_finish = false

var motion := GFLinearProjectileMotion.new()
motion.speed = 480.0
motion.direction_2d = Vector2.RIGHT
motion.use_local_direction = true
projectile.motion = motion

var lifetime := GFProjectileLifetimePolicy.new()
lifetime.max_seconds = 2.0
lifetime.max_distance = 900.0
lifetime.max_impacts = 1
projectile.lifetime_policy = lifetime

projectile.launch({ "owner_id": "player" })
```

`motion` 与 `lifetime_policy` 在发射时会收到本次发射的上下文字典。自定义策略应把跨帧数据写入这个字典，而不是写入共享 Resource 字段，避免多个发射体复用同一资源时互相污染状态。追踪移动会读取 `target`、`target_position`、`target_position_2d` 或 `target_position_3d`，已释放的目标会被视为缺失目标，并写入 `velocity_2d` / `velocity_3d`、`target_distance_2d` / `target_distance_3d` 和 `target_reached` 等通用调试字段。复杂弹道、分裂、穿透、命中后生成子弹等规则，推荐在项目自己的策略资源、状态机或对象池编排里表达。
