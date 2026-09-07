# GFObjectPoolUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/nodes/gf_object_pool_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

在安全点借出和归还节点的对象池。 空闲实例完全离树；借出时返回一次性 Lease。所有挂载、脱树及清理均在主线程 deferred 安全点执行。根节点可实现同步 on_gf_pool_prepare(context) -> Error， 在每次入树前写入本次数据；该方法不得 await、释放根节点或改变根节点父级。 普通进入/退出场景树的初始化与清理由节点自己的 Godot 生命周期方法负责。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`max_available_per_scene`](#member-gfobjectpoolutility-properties-max_available_per_scene) | `var max_available_per_scene: int = 0` |
| 方法 | [`begin_quiesce`](#member-gfobjectpoolutility-methods-begin_quiesce) | `func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:` |
| 方法 | [`dispose`](#member-gfobjectpoolutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`acquire`](#member-gfobjectpoolutility-methods-acquire) | `func acquire( scene: PackedScene, parent: Node, lifetime_owner: Object, context: Dictionary = {} ) -> GFObjectPoolAcquireResult:` |
| 方法 | [`prewarm`](#member-gfobjectpoolutility-methods-prewarm) | `func prewarm( scene: PackedScene, count: int, batch_size: int = 32, cancellation_token: GFCancellationToken = null ) -> GFObjectPoolPrewarmResult:` |
| 方法 | [`wait_disposed`](#member-gfobjectpoolutility-methods-wait_disposed) | `func wait_disposed() -> void:` |
| 方法 | [`get_available_count`](#member-gfobjectpoolutility-methods-get_available_count) | `func get_available_count(scene: PackedScene) -> int:` |
| 方法 | [`get_active_count`](#member-gfobjectpoolutility-methods-get_active_count) | `func get_active_count(scene: PackedScene) -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfobjectpoolutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfobjectpoolutility-properties-max_available_per_scene"></a>

### `max_available_per_scene`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var max_available_per_scene: int = 0
```

每个场景最多缓存的空闲实例数；0 不限制，-1 归还时直接销毁。

## 方法

<a id="member-gfobjectpoolutility-methods-begin_quiesce"></a>

### `begin_quiesce`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
```

停止接纳新工作，并等待安全点清理及全部已接纳请求与 Lease 的终态通知。 取消静默等待不会取消节点清理；强制退出后仍可单独等待 wait_disposed。

参数：

| 名称 | 说明 |
|---|---|
| `_scope` | 当前静默阶段的取消作用域，不拥有实际节点清理。 |

返回：本次静默等待的一次性完成源。

<a id="member-gfobjectpoolutility-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func dispose() -> void:
```

立即停止接纳新借用并吊销现有 Lease，在安全点完成节点清理。

<a id="member-gfobjectpoolutility-methods-acquire"></a>

### `acquire`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func acquire( scene: PackedScene, parent: Node, lifetime_owner: Object, context: Dictionary = {} ) -> GFObjectPoolAcquireResult:
```

在安全点取得一个完成入树准备的实例。

参数：

| 名称 | 说明 |
|---|---|
| `scene` | 实例来源。 |
| `parent` | 必须位于运行中的 SceneTree，等待期间离树或被删除将取消请求。 |
| `lifetime_owner` | 必填弱引用生命周期锚点；等待期间销毁或 Node 离树会取消请求，成功交付后不再跟踪 owner，也不自动归还 Lease。 |
| `context` | 传给根节点 on_gf_pool_prepare 的本次初始化数据。 |

返回：本次借用的结构化结果；成功后由调用方持有并归还 Lease。

结构：

- `context`: Dictionary；接受请求时深复制嵌套容器，Object 值保留身份，调用方应在等待期间保持所引用对象只读；不得用 context 传递所有权回调。

<a id="member-gfobjectpoolutility-methods-prewarm"></a>

### `prewarm`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func prewarm( scene: PackedScene, count: int, batch_size: int = 32, cancellation_token: GFCancellationToken = null ) -> GFObjectPoolPrewarmResult:
```

分帧预分配离树实例，不执行 prepare、enter_tree 或 ready。

参数：

| 名称 | 说明 |
|---|---|
| `scene` | 实例来源。 |
| `count` | 本次希望新增的数量；0 为成功空操作，负数无效。 |
| `batch_size` | 每次安全点最多创建的数量，必须为正数。 |
| `cancellation_token` | 可选取消令牌；已缓存的实例不会因取消被回滚。 |

返回：请求完成时的创建数量与最终原因。

<a id="member-gfobjectpoolutility-methods-wait_disposed"></a>

### `wait_disposed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func wait_disposed() -> void:
```

等待 dispose 已发起的节点清理及全部已接纳请求与 Lease 的终态通知；允许在完成后重复等待。

<a id="member-gfobjectpoolutility-methods-get_available_count"></a>

### `get_available_count`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_available_count(scene: PackedScene) -> int:
```

获取当前仍存活的离树缓存数量。

参数：

| 名称 | 说明 |
|---|---|
| `scene` | 实例来源。 |

返回：当前可以借出的实例数量。

<a id="member-gfobjectpoolutility-methods-get_active_count"></a>

### `get_active_count`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_active_count(scene: PackedScene) -> int:
```

获取当前仍由 Lease 持有使用权的实例数量。

参数：

| 名称 | 说明 |
|---|---|
| `scene` | 实例来源。 |

返回：ACTIVE 借用数量，不含等待归还的实例。

<a id="member-gfobjectpoolutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取不含节点或 Lease 的诊断计数快照。

返回：按场景身份分组的计数。

结构：

- `return`: Dictionary[String, Dictionary]，键为资源路径或场景实例 ID，值含 total、available、active 三个非负整数；等待归还只计入 total。
