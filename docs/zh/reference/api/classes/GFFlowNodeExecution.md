# GFFlowNodeExecution

[API Reference](../index.md) / [Flow](../extensions-flow.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/flow/runtime/gf_flow_node_execution.gd`
- 模块：`Flow`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

一次节点执行的写入资格。节点完成、流程取消或同一节点再次执行时，旧回调无法写入后续执行。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`is_active`](#member-gfflownodeexecution-methods-is_active) | `func is_active() -> bool:` |
| 方法 | [`set_runtime_value`](#member-gfflownodeexecution-methods-set_runtime_value) | `func set_runtime_value(key: StringName, value: Variant) -> bool:` |
| 方法 | [`get_runtime_value`](#member-gfflownodeexecution-methods-get_runtime_value) | `func get_runtime_value(key: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`clear_runtime_state`](#member-gfflownodeexecution-methods-clear_runtime_state) | `func clear_runtime_state() -> bool:` |
| 方法 | [`set_next_nodes`](#member-gfflownodeexecution-methods-set_next_nodes) | `func set_next_nodes(node_ids: PackedStringArray) -> bool:` |
| 方法 | [`call_subgraph`](#member-gfflownodeexecution-methods-call_subgraph) | `func call_subgraph(graph: GFFlowGraph) -> bool:` |

## 方法

<a id="member-gfflownodeexecution-methods-is_active"></a>

### `is_active`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_active() -> bool:
```

查询这个执行句柄是否仍可写。

返回：可写时返回 true。

<a id="member-gfflownodeexecution-methods-set_runtime_value"></a>

### `set_runtime_value`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func set_runtime_value(key: StringName, value: Variant) -> bool:
```

写入当前帧中本节点的进度。集合在边界复制，旧执行的更新返回失败。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 节点进度键。 |
| `value` | 项目进度值。 |

返回：成功写入时返回 true。

结构：

- `value`: 原始 Variant；容器复制，项目 Object 仍为引用。

<a id="member-gfflownodeexecution-methods-get_runtime_value"></a>

### `get_runtime_value`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_runtime_value(key: StringName, default_value: Variant = null) -> Variant:
```

读取当前节点在本帧内的运行进度。返回集合副本。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 节点进度键。 |
| `default_value` | 未命中或执行结束时的默认值。 |

返回：节点的运行进度。

结构：

- `default_value`: 任意项目值。
- `return`: 进度值或默认值。

<a id="member-gfflownodeexecution-methods-clear_runtime_state"></a>

### `clear_runtime_state`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func clear_runtime_state() -> bool:
```

清空当前节点在此帧中的进度。

返回：执行仍有效时返回 true。

<a id="member-gfflownodeexecution-methods-set_next_nodes"></a>

### `set_next_nodes`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func set_next_nodes(node_ids: PackedStringArray) -> bool:
```

选择本节点的后继。传入空列表表示停止本分支。

参数：

| 名称 | 说明 |
|---|---|
| `node_ids` | 本次执行选择的后继标识。 |

返回：选择已接纳时返回 true。

<a id="member-gfflownodeexecution-methods-call_subgraph"></a>

### `call_subgraph`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func call_subgraph(graph: GFFlowGraph) -> bool:
```

请求在节点结束后先执行子图。子图有独立帧；同一次节点执行只接纳一个调用。

参数：

| 名称 | 说明 |
|---|---|
| `graph` | 要进入的新子图帧。 |

返回：请求已接纳时返回 true。
