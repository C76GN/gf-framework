# GFSignalGraphDock

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/editor/gf_signal_graph_dock.gd`
- 模块：`Standard`
- 继承：`Control`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

当前场景信号连接与发射记录查看面板。 基于 GFSceneSignalAudit 渲染编辑器中保存的信号连接，并可显式开启 GFSignalRuntimeProbe 观察当前场景信号发射。面板只读，不修改场景。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`set_graph_source`](#member-gfsignalgraphdock-methods-set_graph_source) | `func set_graph_source(root: Node) -> void:` |
| 方法 | [`refresh`](#member-gfsignalgraphdock-methods-refresh) | `func refresh(root: Node = null) -> void:` |
| 方法 | [`set_live_tracking_enabled`](#member-gfsignalgraphdock-methods-set_live_tracking_enabled) | `func set_live_tracking_enabled(enabled: bool) -> void:` |
| 方法 | [`get_last_graph`](#member-gfsignalgraphdock-methods-get_last_graph) | `func get_last_graph() -> Dictionary:` |
| 方法 | [`get_recent_events`](#member-gfsignalgraphdock-methods-get_recent_events) | `func get_recent_events() -> Array[Dictionary]:` |
| 方法 | [`get_debug_snapshot`](#member-gfsignalgraphdock-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 方法

<a id="member-gfsignalgraphdock-methods-set_graph_source"></a>

### `set_graph_source`

- API：`public`

```gdscript
func set_graph_source(root: Node) -> void:
```

设置要查看的根节点。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 根节点；为空时刷新时会尝试使用当前编辑场景根节点。 |

<a id="member-gfsignalgraphdock-methods-refresh"></a>

### `refresh`

- API：`public`

```gdscript
func refresh(root: Node = null) -> void:
```

刷新信号图。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 可选根节点；为空时使用 set_graph_source() 或当前编辑场景根节点。 |

<a id="member-gfsignalgraphdock-methods-set_live_tracking_enabled"></a>

### `set_live_tracking_enabled`

- API：`public`

```gdscript
func set_live_tracking_enabled(enabled: bool) -> void:
```

设置运行时信号发射追踪开关。

参数：

| 名称 | 说明 |
|---|---|
| `enabled` | 为 true 时追踪当前可见信号；为 false 时停止追踪。 |

<a id="member-gfsignalgraphdock-methods-get_last_graph"></a>

### `get_last_graph`

- API：`public`

```gdscript
func get_last_graph() -> Dictionary:
```

获取最近一次信号图快照。

返回：信号图字典副本。

结构：

- `return`: Dictionary，包含 GFSceneSignalAudit.build_signal_graph() 返回的信号图字段。

<a id="member-gfsignalgraphdock-methods-get_recent_events"></a>

### `get_recent_events`

- API：`public`

```gdscript
func get_recent_events() -> Array[Dictionary]:
```

获取最近信号发射记录。

返回：发射记录副本。

结构：

- `return`: Array[Dictionary]，每个元素包含 timestamp_msec、source_node_path、signal_name、arguments 和 connections 等字段。

<a id="member-gfsignalgraphdock-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取面板调试快照。

返回：面板调试快照。

结构：

- `return`: Dictionary，包含 graph、recent_events、live 和 ui 分区，用于编辑器诊断和测试。
