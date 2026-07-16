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

`acquire()` 与 `prewarm()` / `prewarm_async*()` 都支持可选 `before_add` 回调。这个回调会在节点加入业务父节点、触发 `_ready()` 之前运行，适合关闭 `auto_launch_on_ready`、写入必要 meta、设置一次性上下文或配置必须先于入树完成的节点属性：

```gdscript
var projectile = pool.acquire(projectile_scene, projectile_parent, func(node: Node) -> void:
	if "auto_launch_on_ready" in node:
		node.set("auto_launch_on_ready", false)
)
```

`prewarm_async_budget()` 会按帧预算让出执行权，因此调用方如果还要等待宿主节点的 `ready` 信号，应先等待 `ready`，或在等待前用 `is_node_ready()` 判断宿主是否已经就绪。

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

`GFRefCountedPool` 适合短生命周期、可明确重置的上下文、报告、查询结果或临时列表包装；不适合长期所有权复杂、带外部信号连接且无法可靠清理的对象。`max_available` 可限制保留数量，超过容量的归还对象会从池中丢弃，让普通引用计数回收接管。
