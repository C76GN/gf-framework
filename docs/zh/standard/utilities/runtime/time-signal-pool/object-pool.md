# 对象池

子弹、伤害飘字、特效等短生命周期节点需要反复创建和回收时，可以使用 `GFObjectPoolUtility` 降低实例化和释放成本。

## 节点池

```gdscript
var pool := Gf.get_utility(GFObjectPoolUtility) as GFObjectPoolUtility

# 借出一个实例（传入资源以及它的父节点）
var bullet = pool.acquire(bullet_scene, get_tree().root) as Node2D

# 归还它进入休眠
pool.release(bullet, bullet_scene)
```

首次使用前可以预热，避免战斗开始时一次性实例化大量节点：

```gdscript
pool.max_available_per_scene = 128
pool.prewarm(bullet_scene, get_tree().root, 64)
await pool.prewarm_async_budget(explosion_scene, get_tree().root, 40, 4.0)
```

需要区分单次请求、观察进度或精确取消时，使用类型化预热入口：

```gdscript
var operation := pool.prewarm_request_async(
	bullet_scene,
	get_tree().root,
	64,
	16,
	self,
	cancellation_token,
	func(node: Node) -> Error:
		node.set_meta(&"spawn_profile", &"player")
		return OK
)

var result := operation.get_result()
if operation.is_pending():
	result = await operation.completed

if not result.is_successful():
	push_warning("对象池预热未完成：%s" % result.get_reason())
```

`prewarm_request_async()` 按每帧批量推进，`prewarm_budget_request_async()` 按毫秒预算推进；两者都立即返回请求专属的 `GFObjectPoolPrewarmOperation`。这两个类型化入口只接受主线程调用；其他线程会得到同步完成的 `INVALID/main_thread_required` 结果，且不会改变池状态。无效输入、零工作和小于等于零的批量/时间预算也可能在入口返回前同步结束，所以应先读取 `get_result()` 或检查 `is_pending()`，再决定是否等待 `completed`。`progressed` 信号以及 created、skipped、cancelled、failed 计数可用于进度展示；终态结果固定满足 `requested = created + skipped + cancelled + failed`。

Operation 的 `cancel()`、`owner`、`GFCancellationToken` 与 parent 生命周期只终结当前请求尚未创建的准入单位，不回滚已经提交到池中的节点，也不会释放其他并发请求的容量预留。`prepare_callback` 在候选加入父节点前运行，必须返回 `Error`；非 `OK` 返回会让该请求进入类型化失败终态。`GFObjectPoolPrewarmResult.Status` 区分完整/部分成功、容量拒绝、取消、Utility 生命周期终结、输入无效和执行失败，`get_reason()` 与 `get_error_code()` 提供闭合原因。

`acquire()` 与 `prewarm()` / `prewarm_async*()` 都支持可选 `before_add` 回调。这个回调会在节点加入业务父节点、触发 `_ready()` 之前运行，适合关闭 `auto_launch_on_ready`、写入必要 meta、设置一次性上下文或配置必须先于入树完成的节点属性：

```gdscript
var projectile = pool.acquire(projectile_scene, projectile_parent, func(node: Node) -> void:
	if "auto_launch_on_ready" in node:
		node.set("auto_launch_on_ready", false)
)
```

`prewarm_async_budget()` 会按帧预算让出执行权，因此调用方如果还要等待宿主节点的 `ready` 信号，应先等待 `ready`，或在等待前用 `is_node_ready()` 判断宿主是否已经就绪。

同一 `PackedScene` 的同步、旧异步和类型化预热入口共享在途容量准入。`max_available_per_scene` 为正数时，并发或回调重入的预热请求不会分别占用同一批空余名额；运行中缩小上限或归还节点填满容量时，尚未提交的预留会转为 skipped，并相应收窄终态 `admitted_count`。对象池进入新生命周期则按生命周期终态收敛尚未创建的准入单位。旧 `prewarm_async()` / `prewarm_async_budget()` 签名与等待语义保持兼容；它们不返回句柄，需要请求身份、进度、取消或类型化失败时改用新的 request-scoped 入口。

Godot 的 `ready` 是一次性信号；长时间预热跨过宿主就绪帧后再 `await host.ready`，后续初始化代码会停在调用方自己的等待语句上，这不是对象池预热卡死。

## 池化 Hook

池化节点可以选择实现两个 hook，让节点自己清理旧状态：

```gdscript
func on_gf_pool_release() -> void:
	# 清理 Tween、临时信号连接、运行时 meta、动态子节点等
	pass

func on_gf_pool_acquire() -> void:
	# 重置本次使用需要的状态
	pass
```

归还时节点会被移动到内部 `GFObjectPoolRoot`，并恢复/关闭 `process_mode`、`CanvasItem.visible` 和常见 `disabled` 属性；正常运行中超过 `max_available_per_scene` 或对象池 `dispose()` 时，节点会先从当前父节点移除，再进入释放队列，避免同一帧在业务父节点下残留。Gf AutoLoad 正在执行 `_exit_tree()` 的同步释放作用域时不主动脱树，只登记释放并让当前拆树流程收束节点。

`manage_descendant_active_state` 控制是否递归处理子节点。对象池不会猜测项目在借出期间动态添加的子节点、Timer、AnimationPlayer 或其他业务状态该如何复原，这些清理应放进 `on_gf_pool_release()` / `on_gf_pool_acquire()`，或由项目把这类一次性对象放在池化根节点外管理。

`release()` 会校验节点是否确实来自对应池，避免把外部节点或其他 `PackedScene` 的实例混入。

`before_add`、`on_gf_pool_acquire()` 和 `on_gf_pool_release()` 都是允许项目代码重入对象池的同步边界。对象池会先提交过渡所有权，并在回调后复核实例与生命周期 generation；如果回调已经归还、再次借出、重置或释放对象池，外层操作不会重复发布同一节点或覆盖更新后的状态。项目 hook 仍应保持短小，且不能假定回调返回后对象仍由当前调用持有。

继承 `GFController` 的池化节点会在归还或预热时自动暂停由基类 `register_event()` / `register_simple_event()` 记录的事件监听，并在再次 `acquire()` 后恢复；这避免 `_ready()` 只执行一次的控制器复用后丢监听，也避免休眠节点继续接收事件。

默认 `prune_invalid_on_each_operation = true` 会在高频接口前清理已释放节点引用，换取更稳的计数；极端热路径可在项目层确认生命周期后关闭，并在低频点主动调用 `prune_invalid_nodes()`。

`get_available_count()`、`get_active_count()`、`get_debug_snapshot()` 可用于调试池容量。

## RefCounted 池

纯数据临时对象不需要进入场景树时，使用 `GFRefCountedPool`。它只要求提供一个返回 `RefCounted` 的工厂，并在归还时调用对象 hook 或 `reset_callback` 清理状态。

```gdscript
var pool := GFRefCountedPool.new(func():
	return MyReusableContext.new()
)

var context := pool.acquire() as MyReusableContext
# 写入本次使用状态
pool.release(context)
```

可复用对象可以实现这些可选方法：

```gdscript
func on_gf_pool_acquire() -> void:
	pass

func on_gf_pool_release() -> void:
	pass

func reset_for_pool() -> void:
	pass
```

每个借出中的 `RefCounted` 都有唯一活动所有权；工厂不能返回已经由同一池追踪的实例。acquire/release/reset hook 可以重入池，但过渡 generation 会确保回调中的归还或再次借出获胜，外层操作不会把同一实例同时放入 available 与 active，也不会对同一次借出重复执行归还。

`GFRefCountedPool` 适合短生命周期、可明确重置的上下文、报告、查询结果或临时列表包装；不适合长期所有权复杂、带外部信号连接且无法可靠清理的对象。`max_available` 可限制保留数量，超过容量的归还对象会从池中丢弃，让普通引用计数回收接管。
