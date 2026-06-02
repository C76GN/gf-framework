# GFNetworkHistoryBuffer

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/snapshot/gf_network_history_buffer.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

按 tick 保存网络快照的环形历史。 用于插值、重放、状态对账或项目自定义同步流程；不会自动执行预测、回滚或冲突解决。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`capacity`](#member-gfnetworkhistorybuffer-properties-capacity) | `var capacity: int = 120` |
| 方法 | [`add_snapshot`](#member-gfnetworkhistorybuffer-methods-add_snapshot) | `func add_snapshot(snapshot: GFNetworkSnapshot) -> bool:` |
| 方法 | [`add_state`](#member-gfnetworkhistorybuffer-methods-add_state) | `func add_state( tick: int, state: Dictionary, peer_id: int = -1, metadata: Dictionary = {} ) -> GFNetworkSnapshot:` |
| 方法 | [`has_snapshot`](#member-gfnetworkhistorybuffer-methods-has_snapshot) | `func has_snapshot(tick: int) -> bool:` |
| 方法 | [`get_snapshot`](#member-gfnetworkhistorybuffer-methods-get_snapshot) | `func get_snapshot(tick: int) -> GFNetworkSnapshot:` |
| 方法 | [`get_latest_snapshot`](#member-gfnetworkhistorybuffer-methods-get_latest_snapshot) | `func get_latest_snapshot() -> GFNetworkSnapshot:` |
| 方法 | [`get_earliest_snapshot`](#member-gfnetworkhistorybuffer-methods-get_earliest_snapshot) | `func get_earliest_snapshot() -> GFNetworkSnapshot:` |
| 方法 | [`get_closest_snapshot`](#member-gfnetworkhistorybuffer-methods-get_closest_snapshot) | `func get_closest_snapshot(tick: int, prefer_older: bool = true) -> GFNetworkSnapshot:` |
| 方法 | [`get_snapshots_between`](#member-gfnetworkhistorybuffer-methods-get_snapshots_between) | `func get_snapshots_between( from_tick: int, to_tick: int, include_bounds: bool = true ) -> Array[GFNetworkSnapshot]:` |
| 方法 | [`get_surrounding_snapshots`](#member-gfnetworkhistorybuffer-methods-get_surrounding_snapshots) | `func get_surrounding_snapshots(tick: int) -> Dictionary:` |
| 方法 | [`get_ticks`](#member-gfnetworkhistorybuffer-methods-get_ticks) | `func get_ticks() -> PackedInt64Array:` |
| 方法 | [`prune_before`](#member-gfnetworkhistorybuffer-methods-prune_before) | `func prune_before(tick: int) -> int:` |
| 方法 | [`clear`](#member-gfnetworkhistorybuffer-methods-clear) | `func clear() -> void:` |
| 方法 | [`size`](#member-gfnetworkhistorybuffer-methods-size) | `func size() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfnetworkhistorybuffer-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfnetworkhistorybuffer-properties-capacity"></a>

### `capacity`

- API：`public`

```gdscript
var capacity: int = 120
```

最大保存快照数量。小于等于 0 表示不限制。

## 方法

<a id="member-gfnetworkhistorybuffer-methods-add_snapshot"></a>

### `add_snapshot`

- API：`public`

```gdscript
func add_snapshot(snapshot: GFNetworkSnapshot) -> bool:
```

添加快照。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 快照。 |

返回：添加成功返回 true。

<a id="member-gfnetworkhistorybuffer-methods-add_state"></a>

### `add_state`

- API：`public`

```gdscript
func add_state( tick: int, state: Dictionary, peer_id: int = -1, metadata: Dictionary = {} ) -> GFNetworkSnapshot:
```

添加状态字典并返回生成的快照。

参数：

| 名称 | 说明 |
|---|---|
| `tick` | 快照 tick。 |
| `state` | 状态字典。 |
| `peer_id` | 来源 peer。 |
| `metadata` | 元数据。 |

返回：新快照。

结构：

- `state`: Dictionary[StringName|String, Variant]，保存项目自定义同步状态。
- `metadata`: Dictionary，保存项目自定义快照元数据。

<a id="member-gfnetworkhistorybuffer-methods-has_snapshot"></a>

### `has_snapshot`

- API：`public`

```gdscript
func has_snapshot(tick: int) -> bool:
```

检查指定 tick 是否存在快照。

参数：

| 名称 | 说明 |
|---|---|
| `tick` | 快照 tick。 |

返回：存在返回 true。

<a id="member-gfnetworkhistorybuffer-methods-get_snapshot"></a>

### `get_snapshot`

- API：`public`

```gdscript
func get_snapshot(tick: int) -> GFNetworkSnapshot:
```

获取指定 tick 的快照副本。

参数：

| 名称 | 说明 |
|---|---|
| `tick` | 快照 tick。 |

返回：快照副本；不存在时返回 null。

<a id="member-gfnetworkhistorybuffer-methods-get_latest_snapshot"></a>

### `get_latest_snapshot`

- API：`public`

```gdscript
func get_latest_snapshot() -> GFNetworkSnapshot:
```

获取最新快照副本。

返回：最新快照；不存在时返回 null。

<a id="member-gfnetworkhistorybuffer-methods-get_earliest_snapshot"></a>

### `get_earliest_snapshot`

- API：`public`

```gdscript
func get_earliest_snapshot() -> GFNetworkSnapshot:
```

获取最早快照副本。

返回：最早快照；不存在时返回 null。

<a id="member-gfnetworkhistorybuffer-methods-get_closest_snapshot"></a>

### `get_closest_snapshot`

- API：`public`

```gdscript
func get_closest_snapshot(tick: int, prefer_older: bool = true) -> GFNetworkSnapshot:
```

获取最接近指定 tick 的快照副本。

参数：

| 名称 | 说明 |
|---|---|
| `tick` | 查询 tick。 |
| `prefer_older` | 距离相同时是否优先旧快照。 |

返回：快照副本；不存在时返回 null。

<a id="member-gfnetworkhistorybuffer-methods-get_snapshots_between"></a>

### `get_snapshots_between`

- API：`public`

```gdscript
func get_snapshots_between( from_tick: int, to_tick: int, include_bounds: bool = true ) -> Array[GFNetworkSnapshot]:
```

获取指定 tick 范围内的快照副本。

参数：

| 名称 | 说明 |
|---|---|
| `from_tick` | 起始 tick。 |
| `to_tick` | 结束 tick。 |
| `include_bounds` | 是否包含边界 tick。 |

返回：按 tick 升序排列的快照副本。

结构：

- `return`: Array[GFNetworkSnapshot]，按 tick 升序排列的快照副本。

<a id="member-gfnetworkhistorybuffer-methods-get_surrounding_snapshots"></a>

### `get_surrounding_snapshots`

- API：`public`

```gdscript
func get_surrounding_snapshots(tick: int) -> Dictionary:
```

获取包围指定 tick 的快照副本。

参数：

| 名称 | 说明 |
|---|---|
| `tick` | 查询 tick。 |

返回：字典，包含 exact、previous、next 三个可选快照。

结构：

- `return`: Dictionary，包含 exact、previous、next，值为 GFNetworkSnapshot 或 null。

<a id="member-gfnetworkhistorybuffer-methods-get_ticks"></a>

### `get_ticks`

- API：`public`

```gdscript
func get_ticks() -> PackedInt64Array:
```

获取已保存 tick 列表。

返回：tick 列表。

<a id="member-gfnetworkhistorybuffer-methods-prune_before"></a>

### `prune_before`

- API：`public`

```gdscript
func prune_before(tick: int) -> int:
```

删除指定 tick 之前的快照。

参数：

| 名称 | 说明 |
|---|---|
| `tick` | 保留起点 tick。 |

返回：删除数量。

<a id="member-gfnetworkhistorybuffer-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空历史。

<a id="member-gfnetworkhistorybuffer-methods-size"></a>

### `size`

- API：`public`

```gdscript
func size() -> int:
```

获取快照数量。

返回：快照数量。

<a id="member-gfnetworkhistorybuffer-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary，包含 capacity、size、earliest_tick、latest_tick。
