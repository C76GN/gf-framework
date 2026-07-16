# GFObjectPoolUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/nodes/gf_object_pool_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

节点对象池管理器。 继承自 GFUtility，管理 Node 对象的实例化与回收， 避免高频 instance/free 操作带来的内存碎片和性能抖动。 适合管理大量同类对象，如子弹、敌人单位、特效粒子、棋盘方块等。 内部使用 Node metadata 键 _gf_pool_active 跟踪节点使用状态， 因此兼容任意 Node 子类型（无需 CanvasItem/visible 支持）。 工作流程： 1. 调用 acquire(scene, parent) 从池中取出一个可用节点（或自动实例化）。 2. 对节点进行配置使用。 3. 对象生命周期结束后，调用 release(node, scene) 将其归还至池中。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`HOOK_ON_RELEASE`](#member-gfobjectpoolutility-constants-hook_on_release) | `const HOOK_ON_RELEASE: StringName = &"on_gf_pool_release"` |
| 常量 | [`HOOK_ON_ACQUIRE`](#member-gfobjectpoolutility-constants-hook_on_acquire) | `const HOOK_ON_ACQUIRE: StringName = &"on_gf_pool_acquire"` |
| 属性 | [`max_available_per_scene`](#member-gfobjectpoolutility-properties-max_available_per_scene) | `var max_available_per_scene: int = 0` |
| 属性 | [`manage_descendant_active_state`](#member-gfobjectpoolutility-properties-manage_descendant_active_state) | `var manage_descendant_active_state: bool = true` |
| 属性 | [`prune_invalid_on_each_operation`](#member-gfobjectpoolutility-properties-prune_invalid_on_each_operation) | `var prune_invalid_on_each_operation: bool = true` |
| 方法 | [`init`](#member-gfobjectpoolutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfobjectpoolutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`acquire`](#member-gfobjectpoolutility-methods-acquire) | `func acquire(scene: PackedScene, parent: Node, before_add: Callable = Callable()) -> Node:` |
| 方法 | [`release`](#member-gfobjectpoolutility-methods-release) | `func release(node: Node, scene: PackedScene) -> void:` |
| 方法 | [`prewarm`](#member-gfobjectpoolutility-methods-prewarm) | `func prewarm(scene: PackedScene, parent: Node, count: int, before_add: Callable = Callable()) -> void:` |
| 方法 | [`prewarm_async`](#member-gfobjectpoolutility-methods-prewarm_async) | `func prewarm_async( scene: PackedScene, parent: Node, count: int, batch_size: int = 32, before_add: Callable = Callable() ) -> void:` |
| 方法 | [`prewarm_async_budget`](#member-gfobjectpoolutility-methods-prewarm_async_budget) | `func prewarm_async_budget( scene: PackedScene, parent: Node, count: int, msec_budget_per_frame: float = 8.0, before_add: Callable = Callable() ) -> void:` |
| 方法 | [`get_available_count`](#member-gfobjectpoolutility-methods-get_available_count) | `func get_available_count(scene: PackedScene) -> int:` |
| 方法 | [`get_active_count`](#member-gfobjectpoolutility-methods-get_active_count) | `func get_active_count(scene: PackedScene) -> int:` |
| 方法 | [`get_active_nodes`](#member-gfobjectpoolutility-methods-get_active_nodes) | `func get_active_nodes(scene: PackedScene) -> Array[Node]:` |
| 方法 | [`prune_invalid_nodes`](#member-gfobjectpoolutility-methods-prune_invalid_nodes) | `func prune_invalid_nodes() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfobjectpoolutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 常量

<a id="member-gfobjectpoolutility-constants-hook_on_release"></a>

### `HOOK_ON_RELEASE`

- API：`public`

```gdscript
const HOOK_ON_RELEASE: StringName = &"on_gf_pool_release"
```

节点可选实现：归还对象池前调用，用于清理 Tween、临时信号、运行时状态等。

<a id="member-gfobjectpoolutility-constants-hook_on_acquire"></a>

### `HOOK_ON_ACQUIRE`

- API：`public`

```gdscript
const HOOK_ON_ACQUIRE: StringName = &"on_gf_pool_acquire"
```

节点可选实现：从对象池取出并恢复激活后调用，用于重置本次使用状态。

## 属性

<a id="member-gfobjectpoolutility-properties-max_available_per_scene"></a>

### `max_available_per_scene`

- API：`public`

```gdscript
var max_available_per_scene: int = 0
```

每个 PackedScene 最多保留的可用节点数量。为 0 时不限制。

<a id="member-gfobjectpoolutility-properties-manage_descendant_active_state"></a>

### `manage_descendant_active_state`

- API：`public`

```gdscript
var manage_descendant_active_state: bool = true
```

是否递归管理子节点的 process_mode、visible 与 disabled 状态。

<a id="member-gfobjectpoolutility-properties-prune_invalid_on_each_operation"></a>

### `prune_invalid_on_each_operation`

- API：`public`

```gdscript
var prune_invalid_on_each_operation: bool = true
```

是否在 acquire/release/count 等高频操作前立即清理失效节点。

## 方法

<a id="member-gfobjectpoolutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

第一阶段初始化：清空内部池字典。

<a id="member-gfobjectpoolutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

销毁阶段：释放所有池中的节点。

<a id="member-gfobjectpoolutility-methods-acquire"></a>

### `acquire`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func acquire(scene: PackedScene, parent: Node, before_add: Callable = Callable()) -> Node:
```

从池中获取一个节点实例。若池为空则自动实例化并加入父节点。

参数：

| 名称 | 说明 |
|---|---|
| `scene` | 要实例化的 PackedScene 资源。 |
| `parent` | 借出的节点将加入或移动到此父节点；释放时会移动到内部池根节点。 |
| `before_add` | 可选入树前回调，签名为 `func(node: Node) -> void`。 |

返回：可直接使用的节点实例。

<a id="member-gfobjectpoolutility-methods-release"></a>

### `release`

- API：`public`

```gdscript
func release(node: Node, scene: PackedScene) -> void:
```

将节点归还到对象池，隐藏它以待下次复用。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 要归还的节点实例（必须由此工具创建）。 |
| `scene` | 该节点所属的 PackedScene 资源，用于匹配正确的池。 |

<a id="member-gfobjectpoolutility-methods-prewarm"></a>

### `prewarm`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func prewarm(scene: PackedScene, parent: Node, count: int, before_add: Callable = Callable()) -> void:
```

预热对象池，预先实例化指定数量的节点以避免首次使用时的卡顿。

参数：

| 名称 | 说明 |
|---|---|
| `scene` | 要预热的 PackedScene 资源。 |
| `parent` | 预热节点将加入此父节点。 |
| `count` | 预热的数量。 |
| `before_add` | 可选入树前回调，签名为 `func(node: Node) -> void`。 |

<a id="member-gfobjectpoolutility-methods-prewarm_async"></a>

### `prewarm_async`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func prewarm_async( scene: PackedScene, parent: Node, count: int, batch_size: int = 32, before_add: Callable = Callable() ) -> void:
```

分批预热对象池，避免一次性实例化大量节点造成单帧卡顿。

参数：

| 名称 | 说明 |
|---|---|
| `scene` | 要预热的 PackedScene 资源。 |
| `parent` | 预热节点将加入此父节点。 |
| `count` | 预热的数量。 |
| `batch_size` | 每帧最多实例化数量；小于等于 0 时退化为同步预热。 |
| `before_add` | 可选入树前回调，签名为 `func(node: Node) -> void`。 |

<a id="member-gfobjectpoolutility-methods-prewarm_async_budget"></a>

### `prewarm_async_budget`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func prewarm_async_budget( scene: PackedScene, parent: Node, count: int, msec_budget_per_frame: float = 8.0, before_add: Callable = Callable() ) -> void:
```

按单帧时间预算预热对象池，适合复杂度差异较大的 PackedScene。

参数：

| 名称 | 说明 |
|---|---|
| `scene` | 要预热的 PackedScene 资源。 |
| `parent` | 预热节点将加入此父节点。 |
| `count` | 预热的数量。 |
| `msec_budget_per_frame` | 每帧实例化预算毫秒数；小于等于 0 时退化为同步预热。 |
| `before_add` | 可选入树前回调，签名为 `func(node: Node) -> void`。 |

<a id="member-gfobjectpoolutility-methods-get_available_count"></a>

### `get_available_count`

- API：`public`

```gdscript
func get_available_count(scene: PackedScene) -> int:
```

获取指定场景当前池中可用（未使用）的节点数量。

参数：

| 名称 | 说明 |
|---|---|
| `scene` | 要查询的 PackedScene 资源。 |

返回：池中可用节点数量。

<a id="member-gfobjectpoolutility-methods-get_active_count"></a>

### `get_active_count`

- API：`public`

```gdscript
func get_active_count(scene: PackedScene) -> int:
```

获取指定场景当前正在使用中的节点数量。

参数：

| 名称 | 说明 |
|---|---|
| `scene` | 要查询的 PackedScene 资源。 |

返回：当前激活节点数量。

<a id="member-gfobjectpoolutility-methods-get_active_nodes"></a>

### `get_active_nodes`

- API：`public`

```gdscript
func get_active_nodes(scene: PackedScene) -> Array[Node]:
```

获取指定场景当前正在使用中的节点列表。

参数：

| 名称 | 说明 |
|---|---|
| `scene` | 要查询的 PackedScene 资源。 |

返回：当前激活节点数组。

<a id="member-gfobjectpoolutility-methods-prune_invalid_nodes"></a>

### `prune_invalid_nodes`

- API：`public`

```gdscript
func prune_invalid_nodes() -> void:
```

主动清理全部池中的失效节点引用。

<a id="member-gfobjectpoolutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取对象池诊断快照。

返回：以资源路径或实例 ID 为键的池状态字典。

结构：

- `return`: Dictionary[String, Dictionary] keyed by PackedScene resource path or instance id, with total, available, and active counts.
