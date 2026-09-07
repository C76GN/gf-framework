# Combat 发射体运行时

Combat 的 Projectile API 把“场景拓扑、发射输入、运动决策、宿主移动、生命周期和分配回收”拆成独立契约。它只提供可验证的通用发射体运行时，不规定弹药、伤害、阵营、穿透、特效或派生弹业务。

普通项目先配置 Definition，再调用 `await emitter.emit_pattern()`，从结果取得 Session 即可。只有自定义运动或宿主时，才需要阅读 Motion、Binding 与 BodyAdapter 协议。

## 场景定义与类型化绑定

`GFProjectileDefinition` 保存完整实例场景、唯一 runtime 的显式路径、0..N 个 impact source 路径、运动策略和可选生命周期策略。`GFProjectileDefinition2D` / `GFProjectileDefinition3D` 再增加同维度的 body adapter，并分别通过 `bind_instance(root)` 返回 `GFProjectileBinding2D` / `GFProjectileBinding3D`。

一个 2D 场景可以采用下面的拓扑：

```text
ArrowRoot (Node2D 或 CharacterBody2D)
├── View (项目视觉/动画子树)
├── ProjectileRuntime (GFProjectile2D)
├── HitBox (GFHitBox2D，可选)
└── HitScan (GFHitScan2D，可选)
```

Emitter 与 BodyAdapter 始终把 `ArrowRoot` 作为唯一分配、移动和退休单元；所以 View、HitBox、HitScan 以及其他后代会随 root 一起移动，同时保持各自局部偏移。3D 使用同构的 `Node3D` / `CharacterBody3D`、`GFProjectile3D`、`GFHitBox3D` 与 `GFHitScan3D`。

对应 Definition 至少配置：

- `scene`：实例化后得到完整的 `ArrowRoot`。
- `runtime_path = NodePath("ProjectileRuntime")`：必须指向实例树内唯一的 `GFProjectile2D`；3D 对称要求唯一 `GFProjectile3D`。
- `impact_source_paths`：显式、有序、无重复的同维 `GFHitBox2D | GFHitScan2D` 或 `GFHitBox3D | GFHitScan3D` 路径；可以为空。
- `motion`：非空 `GFProjectileMotion`。
- `body_adapter`：与完整 root 类型和维度匹配。
- `lifetime_policy`：可选；为空时不会因通用时间、距离或 impact 条件自动结束。

绑定前完整 root 必须已经进入 SceneTree。Binding 会拒绝错误维度、缺失或重复 runtime、路径越过 root、错误 impact source、缺少 Motion/Adapter、不受支持的宿主以及已经被占用的 runtime。通过 `is_valid()` 和 `get_failure_reason()` 读取首个 `GFProjectileBinding.FailureReason`，不要在失败后继续 launch。

`GFProjectileBinding` 是拓扑快照而不是永久句柄。`get_definition()`、`get_instance_root()`、`get_runtime()`、`get_impact_sources()` 和 `get_body_adapter()` 返回本次绑定内容；`is_current()` 会重新检查弱引用、节点路径、维度和 runtime 占用。实例树或 Definition 被改写后应重新绑定，不要缓存并强行复用 stale Binding。

Emitter 会完成实例化、入树、放置和绑定。只有需要绕过 Emitter 自行管理完整 root 时，才直接调用 Definition：

```gdscript
var root: Node = definition.scene.instantiate()
spawn_parent.add_child(root)

var binding := definition.bind_instance(root)
if not binding.is_valid():
    push_error("Projectile topology rejected: %s" % binding.get_failure_reason())
    root.queue_free()
    return

var launch_input := GFProjectileLaunchInput2D.new()
launch_input.set_target_position(aim_world_position)
launch_input.set_metadata({ "skill_id": &"arrow_shot" })

var session := binding.get_runtime().launch(binding, launch_input)
if session == null:
    root.queue_free()
```

直接 launch 不会替调用方回收完整 root；项目必须在 `projectile_finished` 后按自己的 fresh/pool 规则退休它。

## LaunchInput 与 Session

`GFProjectileLaunchInput2D` / `GFProjectileLaunchInput3D` 用封闭的 `TargetKind.NONE`、`NODE`、`POSITION` 表达目标。使用 `set_target_none()`、`set_target_node()` 或 `set_target_position()` 设置目标，并通过对应 getter 读取。Node 目标以弱引用保存；失效或已排队删除的目标不会被伪装成仍可追踪对象。

`set_metadata()`、`get_metadata()` 和 `duplicate_input()` 都使用深副本。metadata 只承载项目发射数据，不是 Motion、Session 或对象池的私有状态通道。Emitter 同时配置默认输入与调用输入时：

1. 先深复制 `default_launch_input`；
2. 非空调用输入的 target 覆盖默认 target；
3. metadata 按 default → call 合并，同名键由 call 覆盖；
4. 每个候选再取得彼此独立的最终快照。

`GFProjectileSession` 是 2D/3D 共用的维度中立运行句柄。`get_status()` 返回 `UNCONFIGURED`、`ACTIVE` 或 `FINISHED`，`get_dimension()` 区分 `TWO_D` / `THREE_D`；其余 getter 提供 generation、完整实例 root、runtime、累计活动秒数、累计实际位移、已接受 impact 数、首次结束原因和 metadata 深副本。单帧观测与累计值都必须保持有限；累计溢出会保留最后一份有限指标并以 `INTERNAL_FAILURE` 结束，迟到 terminal 观测的溢出则失败关闭且不消费 one-shot 记录资格。

`finish(reason)` 是 first-wins：只允许 ACTIVE Session 用非 `NONE` 原因结算一次，并会 best-effort 通过 Adapter 停止宿主运动 authority。结束原因在 stop 前已经冻结；stop 的失败结果不会改写首次 reason。重复 finish 不改变终态，也不产生额外位移。`GFProjectile2D` / `GFProjectile3D` 的 `get_active_session()` 和 `is_active()` 只描述当前 runtime，不承担完整 root 的释放。

## Motion、Intent 与 BodyAdapter

`GFProjectileMotion` 不直接接收或修改 Node。每次 Session 先通过 `create_state_2d()` / `create_state_3d()` 创建独立的 `GFProjectileMotionState`，随后用 `compute_intent_2d()` / `compute_intent_3d()` 根据 state、当前 `GFProjectileBodyResult2D` / `GFProjectileBodyResult3D` 和 delta 计算 `GFProjectileMotionIntent2D` / `GFProjectileMotionIntent3D`。

MotionState 是单个 Runtime generation 的私有运行状态：由 Motion 的 `create_state_*()` 创建，prepare 成功后由 Runtime 强持有；prepare 失败或 Session 进入终态时，Runtime 立即释放自己的 ownership，旧 state 对 Runtime 随即失效。外部保留这个 RefCounted 只会延长对象本身的存活时间，不会延长 Runtime 语义、恢复已结束 Session，也不会让旧 state 被下一次 launch 复用。

Intent 只有 `NONE`、`MOVE`、`REJECTED`、`FINISH` 四种 Kind。MOVE 携带 world-space velocity 和本次 delta；velocity、delta 及两者乘积都必须有限，否则在写宿主前转为 REJECTED。自定义 Motion 的 MOVE 必须原样回显本次 `compute_intent_*()` 收到的 delta；需要时间缩放时调整 velocity，不能另造 delta，否则 Runtime 会在 Adapter 前以 `INVALID_MOTION_INTENT` 终结。这使直接 Transform 与使用当前 physics step 的 CharacterBody 共享同一时间语义。REJECTED 携带稳定失败原因；FINISH 以 `MOTION_FINISHED` 正常结束 Session。自定义 Motion 应覆写 protected state/intent 钩子，把跨帧数据存入 Session 私有 MotionState，并保证计算同步、确定、有界、无宿主副作用。

`GFProjectileBodyAdapter2D` / `GFProjectileBodyAdapter3D` 是唯一可写宿主的协议：

- `validate_root(root)` 在 launch 前验证完整 root。
- `capture_body(root)` 返回当前 transform 和零位移快照。
- `apply_intent(root, intent)` 应用一次 intent，并返回实际 world displacement。
- `stop(root)` 停止运动 authority，不产生额外位移。

`GFProjectileBodyResult2D` / `GFProjectileBodyResult3D` 通过 `is_successful()`、`get_failure_reason()`、`get_transform()`、`get_position()` 和 `get_actual_displacement()` 提供闭合结果。

内置 Adapter 保持 2D/3D 对称：

- `GFProjectileTransformBodyAdapter2D` / `GFProjectileTransformBodyAdapter3D` 直接更新普通 `Node2D` / `Node3D`，并明确拒绝 PhysicsBody。
- `GFProjectileCharacterBodyAdapter2D` / `GFProjectileCharacterBodyAdapter3D` 只接受对应 CharacterBody，使用 `move_and_slide()`，并在 stop 时清零 velocity。

四个内置 Adapter 都会在写入前验证 intent 位移与候选 world position；乘法或加法溢出会返回稳定失败并保持 root transform 与 CharacterBody velocity 不变。CharacterBody 路径从真实 `move_and_slide()` 结果报告实际位移，不用 intent 位移冒充碰撞后的运动。

`GFLinearProjectileMotion` 提供直线 world-space intent，可从初始 body basis 转换局部方向；`GFHomingProjectileMotion` 读取 typed LaunchInput target，按目标位置计算追踪 intent。`track_target=true` 时每帧刷新 node 目标；关闭且目标仍存活时，方向和 arrival clamp 都冻结到 launch 快照，目标后来移动也不会改写本次弹道；目标失效后则沿锁定方向继续并禁用旧位置 clamp。Homing 的 `arrival_distance` 必须是有限值：`stop_when_reached` 启用时，非负值参与 arrival clamp，有限负值保持兼容语义并禁用 clamp；NaN/Inf 会在 state/intent 边界被拒绝。两者都不会自行写 root。自定义物理宿主应实现新的 Adapter，而不是让 Motion 通过 duck typing 操作节点。

## 距离、Impact 与生命周期

`GFProjectileLifetimePolicy` 可按 `max_seconds`、`max_distance`、`max_impacts` 或 protected 自定义钩子返回稳定的 `GFProjectileSession.EndReason`。距离不是“起点到当前位置”的净距离，而是逐次累计每个 BodyResult 的 `actual_displacement.length()`；曲线、折返和碰撞滑动因此按真实已移动路程结算。

LifetimePolicy 是 launch-time 强快照：Definition 后续替换或清空策略、项目释放外部引用，都不会改写 ACTIVE Session 的生命周期语义；Session 到达终态后 Runtime 会释放这份快照。不要尝试对 Resource 使用 `free()` 模拟失效。

Runtime 只监听 Definition 显式绑定的同维 `GFHitBox2D | GFHitScan2D` 或 `GFHitBox3D | GFHitScan3D` source 的 `hit_accepted`。0 个 impact source 是合法拓扑；多个 source 按声明路径绑定。只有 accepted impact 增加 Session 计数，rejected 命中不会触发 `max_impacts`。回调携带当前 generation，旧实例轮次或旧绑定的迟到回调不会结算新 Session。

Projectile 不再继承 impact source。命中 payload、sender 分发、阵营与伤害仍由绑定的 HitBox/HitScan、HurtBox 和项目战斗逻辑负责；Runtime 只观察 accepted 结果并更新生命周期。

## Emitter、Catalog 与 SpawnPattern

`GFProjectileEmitter2D` / `GFProjectileEmitter3D` 是推荐入口。它们通过同维度的 `projectile_definition` 直接解析 Definition，或用 `GFProjectileCatalog`、`GFProjectileCatalogEntry` 和稳定 ID 查找 Definition。Catalog 的公开写读入口是 `set_definition()`、`get_definition()`、`has_definition()` 和 `remove_definition()`；不再保存或返回裸 PackedScene。

手写或反序列化的 Catalog 可以暂时包含 null definition 或重复 ID。查找、`has_definition()`、ID 枚举和 Emitter 解析都会跳过无效条目并采用同 ID 的首个有效 Definition；`prune_invalid_entries()` 保留同一首个有效条目，`set_definition()` 规范为一条，`remove_definition()` 则移除该 ID 的全部条目。

```gdscript
@onready var emitter: GFProjectileEmitter2D = $ProjectileEmitter2D

func fire(target: Node2D) -> void:
    var launch_input := GFProjectileLaunchInput2D.new()
    launch_input.set_target_node(target)
    launch_input.set_metadata({
        "owner_id": actor_id,
        "skill_id": &"multi_shot",
    })

    var result: GFProjectileEmissionResult = await emitter.emit_pattern(
        launch_input,
        &"arrow",
        5
    )
    if not result.is_successful():
        push_warning("发射失败：%s / %s" % [result.get_stage(), result.get_reason()])
        return
    for session: GFProjectileSession in result.get_sessions():
        print(session.get_instance_root())
```

2D 与 3D 共享一个异步入口：`emit_pattern(launch_input, projectile_id, emit_count) -> GFProjectileEmissionResult`。单发使用 `emit_count = 1`；省略数量则由 SpawnPattern 决定。不要在每个弹体上逐个 await，同一批次只排队一次。

`GFProjectileEmissionResult` 提供 `is_successful()`、`get_status()`、`get_stage()`、`get_reason()`、`get_requested_count()`、`get_emitted_count()` 与 `get_sessions()`。失败结果的 Session 数组为空；成功数组按生成顺序排列，数量可能被策略或硬上限限制。结果描述一次已经完成的发射，不延长弹体生命周期：信号回调可以立即结束 Session，使用前仍应检查 `session.is_active()`。

`projectile_emitted(projectile_root, session, launch_input)` 在 started 已发布后发出。`projectile_emit_failed(reason, details)` 用于集中诊断，普通调用直接检查 Result 即可。`binding_failed` 的 `details.binding_failure_reason` 是 `GFProjectileBinding.FailureReason`，可区分场景拓扑错误。

`GFProjectileSpawnPattern2D` / `GFProjectileSpawnPattern3D` 的 `get_spawn_transforms(emitter, launch_input, emit_count)` 只计算变换，不实例化节点。内置模式包括 `GFProjectileBurstPattern2D`、`GFProjectileLineSpawnPattern2D`、`GFProjectileConePattern3D` 和 `GFProjectileLineSpawnPattern3D`。自定义模式必须返回有限变换，并把请求数量与 Emitter 硬上限视为真实预算。

不提供共享池时，Emitter 使用私有、不缓存的对象池，Session 结束后释放完整 root。给 `object_pool_utility` 赋值后，Emitter 会复用共享池中的场景；无需额外开关，也不会从全局自动查找池。预热直接使用 `await pool.prewarm(definition.scene, count)`。

每个 Session 的场景借用由 Emitter 私有的 Lease 管理。结束 Session 会立即请求归还、撤销该次借用，实际离树在安全点完成。空闲节点不留在 SceneTree 中；重新借出后重新绑定 runtime，不会把预期的出入树过程当成意外销毁。旧 Session、旧命中或旧回收回调不能归还新一轮借用。项目不要另行 free、reparent 或重复归还 Emitter 管理的 root。

发射器离树会结束自己的 Session 并归还借用；共享池本身不会因此销毁。共享池由项目负责 `dispose()`，需要等待清账时使用 `await pool.wait_disposed()`。池销毁不可通过 `init()` 重启，需要新生命周期时创建新的池。

## 两阶段批次与收费边界

`GFProjectileEmissionPolicy` 表达 enabled、单次数量、总次数、cooldown 和 charge。事务编排保持框架内部实现，项目不需要创建或管理任务对象。

Emitter 的一批发射采用两阶段事务：

1. 冻结 LaunchInput、生成位置、Definition 配置身份、policy 时间和请求数量。
2. 等待一次安全点批量借用，再为全部候选放置、typed bind、预检并建立 launch reservation。
3. 全部候选成功后才一次性提交实际数量，原子结算 cooldown/charge；用户 commit hook 尚未发布。
4. 在无用户回调区消费全部 reservation，使所有 Session 先进入 ACTIVE。
5. 按稳定候选顺序发布 policy commit hook、runtime `projectile_started` 和 emitter `projectile_emitted`，最后释放 finished/retirement 通知屏障。

在任何 Session ACTIVE 前失败时，policy 状态会精确补偿，调用方不被收费，fresh/pool 候选各自恰好退休一次。一旦任一 Session ACTIVE，收费保持提交；后续失效会用稳定 EndReason 结束已激活 Session，而不是伪装成未发生的发射。

用户 hook 或信号可以同步结束 Session、`remove_child()` Emitter，或用 `queue_free()` / `call_deferred("free")` 安排节点删除。框架会在每个回调边界复核 generation、liveness 和 ownership；批次仍保证已发布 Session 的 `projectile_started` 先于延迟的 `projectile_finished`。若发布期间 Emitter 离树，结果失败、仍 ACTIVE 的 Session 以 `EMITTER_RELEASED` 收敛且完整 root 仍只退休一次；已经 first-wins 结束的 Session 保留原原因。失败结果不一定表示“policy 未提交”，可结合 `get_stage()` 区分激活前与发布阶段。

Godot 原生禁止在对象仍处于自身公开方法调用栈或 signal emission 锁内同步 `free()` 该对象；这类输入会由引擎报错，不属于 Emitter 的支持契约。回调内需要销毁 Emitter 时应使用 `queue_free()` 或 `call_deferred("free")`。公开调用和 signal emission 均已结束后，外部同步 `free()` root、Emitter 或其 ancestor 仍由独立 retirement record 精确收敛。

同一 Emitter 同时只接受一个在途请求，重入返回 `emission_in_progress`。等待期间输入和生成位置不会跟随原对象变化；Definition 配置被改写则取消该次请求。等待期间父节点或 Emitter 离树会取消交付。调用协程所属节点本身被 Godot 销毁时，不应继续依赖该节点上的协程；需要跨场景等待的流程应由存活时间更长的节点持有。

## 迁移检查

从同步 Emitter 迁移时：

- `emit_projectile()` / `emit_projectiles()` 改为 `await emit_pattern()`，从 Result 获取 Session 和 root。
- 删除 `use_object_pool`；只通过 `object_pool_utility` 是否非空选择共享复用。
- `prewarm_projectiles()` 改为直接 `await pool.prewarm(definition.scene, count)`。
- 不再直接创建发射任务对象；收费策略仍通过 EmissionPolicy 配置。


从旧 Projectile API 迁移时，逐项删除下面的假设：

- 不再把 `GFProjectile2D` / `GFProjectile3D` 当作 impact source 或空间 root；把 runtime 放到完整实例树的显式路径，并单独列出同维 HitBox/HitScan sources。
- 不再写 `projectile_scene`、`default_context`、`launch(Dictionary)`、`auto_launch_on_ready`、`queue_free_on_finish` 或共享 context 私钥；改为 Definition、typed LaunchInput、Session 与 Emitter retirement。
- 不再使用 Catalog 的 scene 入口；改为 Definition 四件套。
- 不再让 Motion 直接改 Node；改为 per-session MotionState → typed Intent → BodyAdapter。
- 不再按起点到当前位置的净位移计算生命周期距离；读取 Session 的累计实际位移。
- 不再在 runtime finish 信号中重复 free/release Emitter 管理的 root；只观察 Session 终态，allocator ownership 由 Emitter 保持。

完整类、方法、信号、枚举和属性清单见 [Combat API Reference](../../reference/api/extensions-combat.md)。
