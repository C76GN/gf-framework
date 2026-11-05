# GFFlowRunState

[API Reference](../index.md) / [Flow](../extensions-flow.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/flow/runtime/gf_flow_run_state.gd`
- 模块：`Flow`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

一轮 Flow 的调度和节点进度。不同 Runner 各自持有独立状态，即使它们共用业务 Context。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`create_data_snapshot`](#member-gfflowrunstate-methods-create_data_snapshot) | `func create_data_snapshot() -> Dictionary:` |
| 方法 | [`describe_frames`](#member-gfflowrunstate-methods-describe_frames) | `func describe_frames() -> Array[Dictionary]:` |
| 方法 | [`get_report`](#member-gfflowrunstate-methods-get_report) | `func get_report() -> Dictionary:` |
| 方法 | [`cancel`](#member-gfflowrunstate-methods-cancel) | `func cancel() -> bool:` |

## 方法

<a id="member-gfflowrunstate-methods-create_data_snapshot"></a>

### `create_data_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func create_data_snapshot() -> Dictionary:
```

读取根图的节点进度副本。可将 nodes 显式传给另一次运行作为初始进度。

返回：根图数据，不包含等待、调用帧或运行位置。

结构：

- `return`: nodes 按节点 ID 保存进度字典。

<a id="member-gfflowrunstate-methods-describe_frames"></a>

### `describe_frames`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func describe_frames() -> Array[Dictionary]:
```

列出当前调用帧与各自的待执行节点。

返回：按根至子图的顺序返回帧报告。

结构：

- `return`: 每项含 frame_id 和 pending 节点 ID 列表。

<a id="member-gfflowrunstate-methods-get_report"></a>

### `get_report`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_report() -> Dictionary:
```

读取此轮运行的进展或终态。Runner 被重用后，旧状态仍返回自己的报告。

返回：当前运行报告副本。

结构：

- `return`: 与 Runner 报告相同，waiting_node_id 记录活动等待的节点。

<a id="member-gfflowrunstate-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel() -> bool:
```

只对这一次运行请求取消，立即封闭在途节点写权限。

返回：首次接纳取消时返回 true；结束后或已取消时返回 false。
