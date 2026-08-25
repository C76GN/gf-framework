# 类型化场景请求

`GFSceneUtility` 的类型化请求入口为每次加载或预加载返回独立的
`GFSceneOperation`。它适合需要精确关联进度、终态、取消原因或生命周期 owner
的流程；只关心“是否成功发起”并已使用全局路径信号的旧代码，可以继续使用
`load_scene_async()` 与 `preload_scene()`。

两套 request 入口都只能在主线程调用。非主线程调用或内部 Operation 配置失败会返回
`null`，且不会发布 request ID、申请 Broker Lease 或改变 load/preload 状态；需要从 worker
发起时，先把请求投递回主线程。

## 基本用法

`load_scene_request_async()` 加载 `PackedScene`，并且只在安全帧切换成功后报告
`COMPLETED`：

```gdscript
var operation := scene_util.load_scene_request_async(
	"res://levels/level_2.tscn",
	"res://ui/loading_screen.tscn",
	{ "spawn_point": "gate_a" }
)

if operation == null:
	_handle_scene_request_unavailable()
elif operation.is_completed():
	_consume_scene_result(operation.get_result())
else:
	operation.progressed.connect(_on_scene_progress)
	operation.completed.connect(_consume_scene_result, CONNECT_ONE_SHOT)
```

`preload_scene_request_async()` 只准备资源和缓存，不切换当前场景：

```gdscript
var preload_operation := scene_util.preload_scene_request_async(
	"res://levels/level_3.tscn",
	true,
	request_owner,
	cancellation_token
)

if preload_operation == null:
	_handle_scene_request_unavailable()
elif preload_operation.is_completed():
	_consume_scene_result(preload_operation.get_result())
else:
	preload_operation.completed.connect(_consume_scene_result, CONNECT_ONE_SHOT)
```

非 null 的 Operation 可能在 request 方法返回前同步完成。无效路径、已释放的 Utility、不可用
owner、已经取消的 token、load busy、Broker admission 拒绝，以及 preload cache hit
都可能走这条路径。因此调用方必须先检查返回值非 null，再检查 `is_completed()` 或
`get_result()`；只在仍 pending 时连接 `completed`，不能假定连接信号后才会出现终态。

## 请求身份与共享加载

每次调用都会冻结大于零的 request ID、`GFSceneOperation.Kind` 和
`GFResourceIdentity` 副本。`get_scene_identity()` 与 `get_result()` 返回隔离快照；
调用方不能借此改写 Utility 中的请求身份。Operation 的 `progressed` 和 `completed`
只描述当前 consumer，`completed` 最多发出一次。

同一规范资源身份上的多个 preload consumer 各自从注入的 `GFResourceBroker` 取得
Lease。Broker 可以让这些 Lease 共享一个物理加载，但取消一个 Operation、释放它的
owner 或取消它的 token，只终结该 consumer；其它 consumer 继续观察自己的进度和
终态。物理请求失去最后一个 consumer 后仍可能在 Godot 中 drain，迟到完成只负责
回收，不会重新写入场景缓存或重复完成已经取消的 Operation。

`fixed` 也是逐 consumer 兴趣：已经取消、owner 释放或 token 取消的 fixed consumer
不会继续把同路径结果钉在 fixed cache；只要完成边界仍有任一 live fixed consumer，
共享物理结果仍会进入 fixed cache。Broker 在 Utility tick 之前终结旧 Lease 时，下一
次同路径 admission 会先退役旧 aggregate，再建立新 generation；后来创建的 consumer
不会继承较早的取消终态。aggregate 发布终态 progress 前会进入不可加入的 settling
边界；progress listener 同步发起的同路径 load/preload 以 `ERR_BUSY` 拒绝，不会递归
轮询或加入正在发布终态的旧 generation。

load 采用 busy rejection，而不是 replacement：同一时刻已有 load 等待时，新
`load_scene_request_async()` 会同步得到 `REJECTED / REASON_LOAD_BUSY / ERR_BUSY`，
当前请求不会被取代，也没有 `SUPERSEDED` 终态。load 可以复用同路径的在途 preload
物理请求，但仍拥有独立 caller Operation。

## 完成边界

- preload 命中缓存时同步完成，reason 为 `REASON_CACHE_HIT`，不会新建 Broker Lease。
- preload 物理加载成功后，资源确认为 `PackedScene` 即以
  `REASON_SCENE_PRELOADED` 完成；临时缓存是否继续保留由容量策略决定，`fixed`
  consumer 的存活兴趣则要求写入 fixed 缓存。
- load 即使命中缓存，也要等待 loading scene 最短时长与安全帧切换；只有场景切换
  被 `SceneTree.scene_changed` 确认，且 `current_scene` 身份仍为冻结目标后，才以
  `REASON_SCENE_LOADED` 完成。基础实现处理没有 `resource_path` 的运行时打包
  `PackedScene` 时，会先预实例化唯一目标 root，再用 `change_scene_to_node()` 提交，并只
  接受该精确 root；不能用“任意新空路径 root”冒充冻结目标。
- 基础 `_do_change_scene()` 或调用 `super` 的 override 会等待 SceneTree 已接纳的 native
  commit。完全自定义的同步 override 在返回 `true` 且安装了新的、可由规范路径识别的
  target root 时保留兼容完成路径，也可调用 `_confirm_target_scene_commit()` 冻结精确
  root 回执。同路径异步 override 必须在返回 `true` 前调用
  `_defer_target_scene_commit()`；不同路径的既有异步 override 仍可直接等待一次性
  `scene_changed`。自定义 pathless 异步 override 必须先 defer，并在安装精确 root 后调用
  `_confirm_target_scene_commit()`；单独发出 signal 不会给匿名 root 授信。
- defer、confirm 与 override 栈内同步发出的 `scene_changed` 都绑定 current generation；
  只有 override 返回 `true`，且 owner、token 与请求身份复核通过后才结算。返回 `false`
  会丢弃回执并进入切场失败终态。实例化期间的回调若取消或替换 generation，基础实现会
  释放尚未入树的 root，并在任何物理切场前失败关闭。
- 资源加载成功但类型不是 `PackedScene`，或安全帧切换失败，都会进入 `FAILED`，
  不会发出伪成功终态。
- 成功终态前若 Operation 尚未到 `1.0`，会先发布一次 `progressed(1.0)`；已经是
  `1.0` 时不重复。失败、取消与释放终态不会伪造最终成功进度。

`GFSceneOperationResult` 的 status、reason 与 error 是闭合组合：

| Status | Reason | Error | 含义 |
|---|---|---|---|
| `COMPLETED` | `REASON_SCENE_LOADED` | `OK` | load 已在安全帧完成场景切换。 |
| `COMPLETED` | `REASON_SCENE_PRELOADED` | `OK` | preload 已取得资源；是否继续保留在缓存由容量与 `fixed` 策略决定。 |
| `COMPLETED` | `REASON_CACHE_HIT` | `OK` | preload 同步命中已有缓存。 |
| `REJECTED` | `REASON_INVALID_PATH` | `ERR_INVALID_PARAMETER` | 路径为空、越界、不存在或不是场景资源。 |
| `REJECTED` | `REASON_OWNER_UNAVAILABLE` | `ERR_UNAVAILABLE` | owner 在接纳前已经无效。 |
| `REJECTED` | `REASON_LOAD_BUSY` | `ERR_BUSY` | 已有 load 等待，新请求不替换它。 |
| `REJECTED` | `REASON_BROKER_REJECTED` | Broker 返回的非 `OK` | Broker Lease 或 admission 未被接纳。 |
| `FAILED` | `REASON_RESOURCE_LOAD_FAILED` | `ERR_CANT_OPEN` | 已接纳的物理资源加载失败。 |
| `FAILED` | `REASON_RESOURCE_TYPE_MISMATCH` | `ERR_INVALID_DATA` | Broker 返回的资源不是 `PackedScene`。 |
| `FAILED` | `REASON_SCENE_CHANGE_FAILED` | `ERR_CANT_CREATE` | 目标资源已准备，但安全帧切换失败。 |
| `CANCELLED` | `REASON_CALLER_CANCELLED` | `ERR_SKIP` | 当前 Operation 接受了 `cancel()`。 |
| `CANCELLED` | `REASON_TOKEN_CANCELLED` | `ERR_SKIP` | 绑定 token 请求取消。 |
| `CANCELLED` | `REASON_OWNER_RELEASED` | `ERR_SKIP` | 弱绑定 owner 在等待期间释放。 |
| `CANCELLED` | `REASON_PATH_CANCELLED` | `ERR_SKIP` | 旧 path-level cancel 取消同路径 consumer。 |
| `CANCELLED` | `REASON_EXTERNAL_CANCELLED` | `ERR_SKIP` | 共享 Broker 被外部调用方以 `external` 取消。 |
| `CANCELLED` | `REASON_BROKER_DISPOSED` | `ERR_SKIP` | 共享 Broker 已释放。 |
| `CANCELLED` | `REASON_BROKER_CANCELLED` | `ERR_SKIP` | Broker 返回未公开的取消原因，已收敛到有界 fallback。 |
| `DISPOSED` | `REASON_UTILITY_DISPOSED` | `ERR_UNAVAILABLE` | Scene Utility 已释放。 |

成功结果的 `get_scene()` 返回规范 `PackedScene` 引用；其它终态返回 `null`。
`to_dict()` 适合诊断或日志投影，但业务分支应优先读取类型化 getter 和枚举。

## 取消、owner 与释放

`operation.cancel()` 只提交当前 caller 的取消 intent，并在首次接受时返回 `true`。
可选 `request_owner` 以弱引用绑定；owner 释放或进入待删除状态时，当前 consumer 在
下一次 Scene Utility tick 取消。需要在切换后继续处理结果的观察者，应由跨场景存活
的协调器持有回调，不要依赖即将随旧场景释放的节点。可选 `GFCancellationToken` 也只
取消当前 consumer；传入已经取消的 token 会在 Broker dispatch 前同步终结。

`cancel_scene_preload(path)` 与 `cancel_all_scene_preloads()` 是兼容的 path-level API，
会以 `REASON_PATH_CANCELLED` 终结匹配路径上的全部类型化 consumer。需要隔离取消时，
应保存并取消具体 Operation，而不是使用 path-level 入口。

`dispose()` 会先冻结所有 pending Operation 的 `DISPOSED` 终态，再清理 load、preload、
缓存和自有 Broker，最后逐个发出完成通知。这样首个完成回调即使同步重入，也只能看到
已经统一结算的请求集合；释放后的新 request 会同步返回 `DISPOSED`。
若 SceneTree 已接纳 native target commit（包括 `change_scene_to_packed()` 或
`change_scene_to_node()`），并在旧场景退出时同步触发
`dispose()`，Utility 会仅保留这一代一次性的 `scene_changed` 物理观察；回调先断开连接，
再因 disposed 状态静默结束，不会发布 typed 或 legacy success。这样既不提前报告成功，
也不会让观察器跨过本次已接纳的物理切换继续存活。

## 迁移与兼容

既有 `load_scene_async()`、`preload_scene()`、场景进度信号和 path-level cancel 保持
兼容，不需要一次性迁移。新流程若需要区分同路径的多个消费者、精确取消原因或安全帧
提交结果，应改用两套 request API，并把全局场景信号只当作汇总遥测或旧代码兼容入口，
不要用它们关联单次请求。
