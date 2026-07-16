# GFFlowRunner

[API Reference](../index.md) / [Flow](../extensions-flow.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/flow/runtime/gf_flow_runner.gd`
- 模块：`Flow`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用流程图执行器。 按节点后继关系执行 GFFlowGraph，支持 Signal 等待、取消和简单循环保护。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`flow_started`](#member-gfflowrunner-signals-flow_started) | `signal flow_started(graph: GFFlowGraph)` |
| 信号 | [`node_started`](#member-gfflowrunner-signals-node_started) | `signal node_started(node_id: StringName, node: GFFlowNode)` |
| 信号 | [`node_completed`](#member-gfflowrunner-signals-node_completed) | `signal node_completed(node_id: StringName, node: GFFlowNode)` |
| 信号 | [`flow_completed`](#member-gfflowrunner-signals-flow_completed) | `signal flow_completed` |
| 信号 | [`flow_cancelled`](#member-gfflowrunner-signals-flow_cancelled) | `signal flow_cancelled` |
| 属性 | [`is_running`](#member-gfflowrunner-properties-is_running) | `var is_running: bool = false` |
| 属性 | [`max_executed_nodes`](#member-gfflowrunner-properties-max_executed_nodes) | `var max_executed_nodes: int = 1024` |
| 属性 | [`signal_timeout_seconds`](#member-gfflowrunner-properties-signal_timeout_seconds) | `var signal_timeout_seconds: float = 30.0` |
| 属性 | [`signal_timeout_respects_time_scale`](#member-gfflowrunner-properties-signal_timeout_respects_time_scale) | `var signal_timeout_respects_time_scale: bool = true` |
| 属性 | [`isolate_graph_runtime_state`](#member-gfflowrunner-properties-isolate_graph_runtime_state) | `var isolate_graph_runtime_state: bool = true` |
| 方法 | [`run`](#member-gfflowrunner-methods-run) | `func run(graph: GFFlowGraph, context: GFFlowContext = null) -> void:` |
| 方法 | [`cancel`](#member-gfflowrunner-methods-cancel) | `func cancel() -> void:` |
| 方法 | [`with_signal_timeout`](#member-gfflowrunner-methods-with_signal_timeout) | `func with_signal_timeout(seconds: float, respect_time_scale: bool = true) -> GFFlowRunner:` |

## 信号

<a id="member-gfflowrunner-signals-flow_started"></a>

### `flow_started`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal flow_started(graph: GFFlowGraph)
```

流程开始时发出。

参数：

| 名称 | 说明 |
|---|---|
| `graph` | 流程图资源。 |

<a id="member-gfflowrunner-signals-node_started"></a>

### `node_started`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal node_started(node_id: StringName, node: GFFlowNode)
```

节点开始执行时发出。

参数：

| 名称 | 说明 |
|---|---|
| `node_id` | 节点 ID。 |
| `node` | 节点资源。 |

<a id="member-gfflowrunner-signals-node_completed"></a>

### `node_completed`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal node_completed(node_id: StringName, node: GFFlowNode)
```

节点完成执行时发出。

参数：

| 名称 | 说明 |
|---|---|
| `node_id` | 节点 ID。 |
| `node` | 节点资源。 |

<a id="member-gfflowrunner-signals-flow_completed"></a>

### `flow_completed`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal flow_completed
```

流程完成时发出。

<a id="member-gfflowrunner-signals-flow_cancelled"></a>

### `flow_cancelled`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal flow_cancelled
```

流程取消时发出。

## 属性

<a id="member-gfflowrunner-properties-is_running"></a>

### `is_running`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var is_running: bool = false
```

当前是否正在执行。

<a id="member-gfflowrunner-properties-max_executed_nodes"></a>

### `max_executed_nodes`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var max_executed_nodes: int = 1024
```

最多执行节点数量，避免循环图无限运行。小于等于 0 表示不限制。

<a id="member-gfflowrunner-properties-signal_timeout_seconds"></a>

### `signal_timeout_seconds`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var signal_timeout_seconds: float = 30.0
```

Signal 等待超时时间。小于等于 0 表示不启用超时。

<a id="member-gfflowrunner-properties-signal_timeout_respects_time_scale"></a>

### `signal_timeout_respects_time_scale`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var signal_timeout_respects_time_scale: bool = true
```

Signal 超时计时是否跟随 GFTimeUtility 的暂停与 time_scale。

<a id="member-gfflowrunner-properties-isolate_graph_runtime_state"></a>

### `isolate_graph_runtime_state`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var isolate_graph_runtime_state: bool = true
```

运行时是否把节点 runtime_state 隔离到 GFFlowContext，避免污染共享图资源。

## 方法

<a id="member-gfflowrunner-methods-run"></a>

### `run`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func run(graph: GFFlowGraph, context: GFFlowContext = null) -> void:
```

运行流程图。

参数：

| 名称 | 说明 |
|---|---|
| `graph` | 流程图资源。 |
| `context` | 可选上下文。 |

<a id="member-gfflowrunner-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func cancel() -> void:
```

请求取消流程。

<a id="member-gfflowrunner-methods-with_signal_timeout"></a>

### `with_signal_timeout`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func with_signal_timeout(seconds: float, respect_time_scale: bool = true) -> GFFlowRunner:
```

设置 Signal 等待超时时间。

参数：

| 名称 | 说明 |
|---|---|
| `seconds` | 秒数；小于等于 0 时表示不启用超时。 |
| `respect_time_scale` | 是否跟随 GFTimeUtility 的暂停与 time_scale。 |

返回：当前执行器。
