# 对象池

`GFObjectPoolUtility` 适用于需要反复创建和回收的子弹、飘字、特效等节点。空闲节点完全离开场景树；借出与归还的场景树操作统一排到主线程安全点，允许从物理碰撞回调发起请求。

## 借用与归还

`GFObjectPoolAcquireResult` 记录本次借用是否成功及失败原因。成功时交付的是 `GFObjectPoolLease`，而不是永久有效的节点引用。

```gdscript
extends Node

var pool: GFObjectPoolUtility = GFObjectPoolUtility.new()

func spawn_effect(scene: PackedScene, parent: Node) -> void:
	var result: GFObjectPoolAcquireResult = await pool.acquire(
		scene, parent, self, { "position": Vector2(120, 80) }
	)
	if not result.is_successful():
		push_warning("借用失败：%s / %s" % [result.get_stage(), result.get_reason()])
		return
	var lease: GFObjectPoolLease = result.get_lease()
	var effect: Node = lease.get_node()
	# 在这里使用 effect，并把 lease 保留到本轮使用结束。
	var accepted: bool = lease.release()
	if accepted:
		var reason: StringName = await lease.wait_settled()
		print("本次借用结束：", reason)
```

`parent` 决定节点挂在哪里，必填的 `lifetime_owner` 决定谁接收这次借用，通常传调用脚本的 `self`。两者可以不同，例如临时发射器向常驻场景挂载特效。池只弱引用接收方：交付前接收方被销毁，或 Node 接收方退出场景树，请求以 `CANCELLED / owner_lost` 结束并清理候选；重新入树不会恢复已取消的请求。

成功交付后，接收方的生命周期不再自动控制 Lease。接收方应保存并归还 Lease，或把它明确转交给持续管理该节点的对象；不要依赖接收方退出时自动归还已交付节点。

`release()` 首次接纳时返回 `true`，并立即撤销使用权：之后 `get_node()` 返回 `null`。节点的实际离树在安全点完成，完成后发出一次 `settled`。重复归还返回 `false`；旧 Lease 不能归还同一节点的新借用。

需要等待结束时用 `wait_settled()`，不要直接等待可能已经发过的 `settled` 信号。前者在完成后直接返回缓存结果，支持重复等待。结束原因包括 `released`、`node_lost`、`pool_disposed` 和 `capacity_retired`。

归还不会立刻清除当前物理步已经产生的回调。项目应在回调入口检查本轮 Lease 是否仍提供节点，避免一次命中被处理两次；不要继续使用归还前保存的裸节点引用。

## 每次借用的初始化

根节点可实现一个同步准备方法。它在每次入树前运行，包括首次实例化与后续复用：

```gdscript
extends Node2D

func on_gf_pool_prepare(context: Dictionary) -> Error:
	var next_position: Variant = context.get("position", Vector2.ZERO)
	if not next_position is Vector2:
		return ERR_INVALID_PARAMETER
	position = next_position
	return OK

func _enter_tree() -> void:
	# 每次进入场景树时建立本轮监听或运行状态。
	pass

func _exit_tree() -> void:
	# 每次离树时解除外部监听，取消本轮异步工作。
	pass
```

prepare 必须返回 `Error`，不能 `await`、释放根节点或改变根节点父级。失败候选直接淘汰，不放回缓存。`context` 的嵌套容器会在接纳请求时复制；其中的 Object 保留身份，等待期间应保持只读。不要把所有权回调塞进 context。

Godot 的 `_ready()` 默认只在首次入树执行；每轮重置应放在 prepare 或 `_enter_tree()`。池不递归修改节点的 `process_mode`、可见性、碰撞属性或脚本状态，也不调用旧的池启停钩子。

离树会停止依赖场景树的常规处理，但不是所有工作都会自动取消。全局信号、独立 Timer、Tween 或已开始的协程仍需由项目清理或按本轮 Lease 验证。`GFController` 的事件注册遵循正常进入/退出生命周期，无需额外池开关。

## 预热与容量

```gdscript
pool.max_available_per_scene = 128
var result: GFObjectPoolPrewarmResult = await pool.prewarm(effect_scene, 64, 16)
print("实际新增：", result.get_created_count())
```

预热只分批创建离树节点，不执行 prepare、`_enter_tree()` 或 `_ready()`，因此不需要业务父节点。`count` 为本次希望新增的数量，零为成功空操作；`batch_size` 必须为正数。可传入第四个参数 `GFCancellationToken` 取消剩余工作，已经缓存的实例会保留。

一次安全点未处理完的请求会排在本轮新增请求和预热后续批次之前；大量预热不会让已排队的借用或归还一直等到预热全部结束。

`GFObjectPoolPrewarmResult` 区分完整成功、容量导致的部分成功、取消、输入无效与创建失败。`get_requested_count()` 和 `get_created_count()` 只描述当前请求，不是整个池的库存。

`max_available_per_scene` 只限制每种场景的空闲缓存，不限制正在使用的节点。`0` 表示不限制，正数表示上限，`-1` 表示归还后直接淘汰。`get_available_count()`、`get_active_count()` 与 `get_debug_snapshot()` 用于诊断，不暴露可修改的池内节点清单。

## 生命周期与失败处理

- 所有操作只接受主线程调用。`parent` 必须在运行中的场景树内；`lifetime_owner` 必须有效，若为 Node，还必须在树内且未排队删除。`null`、离树或排队删除的 Node 接收方返回 `INVALID / validation / invalid_owner`；已释放或类型不匹配的入参由 Godot 的类型检查拒绝，不会进入该结果分支。等待期间丢失父节点或接收方时请求取消，未交付实例由池清理。
- 节点由池拥有。业务只持有本轮使用权，不应手动 `free()`、`queue_free()` 或 reparent 池节点；意外离树会撤销 Lease，并在安全点淘汰该实例。即使业务在离树回调中先调用 `release()`，结束原因仍为 `node_lost`，不会把异常离树改成正常归还。
- 保留池到使用结束。独立使用时显式调用 `dispose()`：它立即拒绝新借用并撤销现有 Lease，随后在安全点清理空闲和活动节点。注册到架构的池会在正常异步关停或替换 Utility 时先完成清理和终态通知，再释放架构依赖。
- 池本身是 `RefCounted`，包括传给发射器的共享池；不要对池调用 `free()`。使用 `dispose()` 和 `wait_disposed()` 完成清理后，再释放持有它的引用；强行释放仍被引用的池不属于受支持的生命周期。
- `await pool.wait_disposed()` 表示节点已经离树或提交删除，已接纳请求与 Lease 的终态通知也已完成；实际 `queue_free()` 仍由引擎在帧尾完成。已完成后重复等待不会挂起。架构关停若被取消或超时，强制销毁不保证优雅清理已经完成，仍需用该等待确认池清理结束。
- 调用方自己的节点若在协程等待期间被销毁，不能依赖已销毁脚本继续执行 await 之后的逻辑；必填的接收方绑定负责取消尚未交付的请求。

需要实时同步返回的低成本对象，未必适合这个池。音频服务使用自己的播放器缓存，普通 `play` 调用仍保持同步。

## 从旧接口迁移

这是下一主版本的破坏性变更，不提供旧接口包装。除了给调用增加 `await`，还需更新预热结果的分支与池配置：

| 旧接口或行为 | 新用法 |
| --- | --- |
| 只传场景、父节点与初始化数据的借用 | `await acquire(scene, parent, lifetime_owner, context)`；通常以 `self` 为接收方，初始化数据移到第四个参数 |
| `Status.COMPLETED` / `completed` | `Status.SUCCEEDED` / `prewarmed` |
| `Status.REJECTED` / `capacity_unavailable` | `Status.PARTIAL` / `capacity_limited`，实际创建数可能为零 |
| `Status.DISPOSED` / `utility_disposed` | `Status.CANCELLED` / `pool_disposed` |
| `REASON_*` 常量、`get_error_code()` | 检查 `get_status()` 与 `get_reason()` 的文档化值 |
| request ID、scene identity、admitted/skipped/cancelled/failed 计数、`to_dict()` | 仅保留请求数与创建数；业务统计由调用方记录 |
| `get_active_nodes()` / `prune_invalid_nodes()` | 保存自己取得的 Lease；诊断使用计数快照，失效实例由池处理 |
| `manage_descendant_active_state` / `prune_invalid_on_each_operation` | 删除设置；每轮初始化用根节点 prepare，池不再遍历启停子节点 |
| 再次 `init()` 重置或复活池 | 对旧池 `dispose()`，需要新生命周期时创建新池 |

旧预热的 owner、parent、任意准备回调、时间预算与进度观察入口不再保留。普通预热只接受数量、每批数量和可选取消令牌；场景根的 prepare 在实际借用时才执行。不要持久化旧状态枚举的整数值或依赖旧调试快照字段。

## RefCounted 池

纯数据临时对象不进入场景树，仍使用独立的 `GFRefCountedPool`。它保留同步工厂、`acquire()`、`release()` 与 `max_available` 容量控制；本次节点池迁移不改变这套接口。

```gdscript
var data_pool: GFRefCountedPool = GFRefCountedPool.new(func() -> RefCounted:
	return MyReusableContext.new()
)
var context: RefCounted = data_pool.acquire()
# 使用 context 后归还。
var released: bool = data_pool.release(context)
```

可复用数据对象通过 `on_gf_pool_acquire()`、`on_gf_pool_release()`、`reset_for_pool()` 或配置的 `reset_callback` 清理状态。工厂必须返回未被同一池追踪的实例；不要把需要场景树生命周期的 Node 放进这个池。它适合短期且能明确重置的上下文，不适合无法可靠清理外部监听的长期对象。
