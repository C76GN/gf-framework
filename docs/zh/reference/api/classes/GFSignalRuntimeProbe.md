# GFSignalRuntimeProbe

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_signal_runtime_probe.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

运行时信号发射追踪器。 以显式 watch 的方式连接节点信号，并把实际发射记录为只读事件快照。 它不修改被观察节点，不解释业务语义，也不应默认用于生产环境全局采样。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`signal_emitted`](#member-gfsignalruntimeprobe-signals-signal_emitted) | `signal signal_emitted(event: Dictionary)` |
| 信号 | [`signal_watch_started`](#member-gfsignalruntimeprobe-signals-signal_watch_started) | `signal signal_watch_started(source_path: String, signal_name: StringName)` |
| 信号 | [`signal_watch_stopped`](#member-gfsignalruntimeprobe-signals-signal_watch_stopped) | `signal signal_watch_stopped(source_path: String, signal_name: StringName)` |
| 常量 | [`DEFAULT_MAX_EVENTS`](#member-gfsignalruntimeprobe-constants-default_max_events) | `const DEFAULT_MAX_EVENTS: int = 256` |
| 常量 | [`DEFAULT_MAX_ARGUMENT_COUNT`](#member-gfsignalruntimeprobe-constants-default_max_argument_count) | `const DEFAULT_MAX_ARGUMENT_COUNT: int = _MAX_SUPPORTED_ARGUMENT_COUNT` |
| 常量 | [`DEFAULT_MAX_WATCH_TREE_DEPTH`](#member-gfsignalruntimeprobe-constants-default_max_watch_tree_depth) | `const DEFAULT_MAX_WATCH_TREE_DEPTH: int = 64` |
| 常量 | [`DEFAULT_MAX_WATCH_TREE_NODES`](#member-gfsignalruntimeprobe-constants-default_max_watch_tree_nodes) | `const DEFAULT_MAX_WATCH_TREE_NODES: int = 4096` |
| 属性 | [`max_events`](#member-gfsignalruntimeprobe-properties-max_events) | `var max_events: int = DEFAULT_MAX_EVENTS` |
| 属性 | [`max_argument_count`](#member-gfsignalruntimeprobe-properties-max_argument_count) | `var max_argument_count: int = DEFAULT_MAX_ARGUMENT_COUNT` |
| 方法 | [`watch_node`](#member-gfsignalruntimeprobe-methods-watch_node) | `func watch_node(source: Node, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`watch_tree`](#member-gfsignalruntimeprobe-methods-watch_tree) | `func watch_tree(root: Node, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`unwatch_node`](#member-gfsignalruntimeprobe-methods-unwatch_node) | `func unwatch_node(source: Node) -> int:` |
| 方法 | [`unwatch_all`](#member-gfsignalruntimeprobe-methods-unwatch_all) | `func unwatch_all() -> int:` |
| 方法 | [`clear_events`](#member-gfsignalruntimeprobe-methods-clear_events) | `func clear_events() -> void:` |
| 方法 | [`get_events`](#member-gfsignalruntimeprobe-methods-get_events) | `func get_events() -> Array[Dictionary]:` |
| 方法 | [`get_watch_count`](#member-gfsignalruntimeprobe-methods-get_watch_count) | `func get_watch_count() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfsignalruntimeprobe-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfsignalruntimeprobe-signals-signal_emitted"></a>

### `signal_emitted`

- API：`public`

```gdscript
signal signal_emitted(event: Dictionary)
```

记录到信号发射事件后发出。

参数：

| 名称 | 说明 |
|---|---|
| `event` | 发射事件快照。 |

结构：

- `event`: Dictionary，包含 timestamp_msec、process_frame、physics_frame、source_instance_id、source_node_path、signal_name、argument_count、arguments 和 connections。

<a id="member-gfsignalruntimeprobe-signals-signal_watch_started"></a>

### `signal_watch_started`

- API：`public`

```gdscript
signal signal_watch_started(source_path: String, signal_name: StringName)
```

开始监听一个节点信号后发出。

参数：

| 名称 | 说明 |
|---|---|
| `source_path` | 信号来源节点路径。 |
| `signal_name` | 信号名称。 |

<a id="member-gfsignalruntimeprobe-signals-signal_watch_stopped"></a>

### `signal_watch_stopped`

- API：`public`

```gdscript
signal signal_watch_stopped(source_path: String, signal_name: StringName)
```

停止监听一个节点信号后发出。

参数：

| 名称 | 说明 |
|---|---|
| `source_path` | 信号来源节点路径。 |
| `signal_name` | 信号名称。 |

## 常量

<a id="member-gfsignalruntimeprobe-constants-default_max_events"></a>

### `DEFAULT_MAX_EVENTS`

- API：`public`

```gdscript
const DEFAULT_MAX_EVENTS: int = 256
```

默认保留的最近信号发射事件数量。

<a id="member-gfsignalruntimeprobe-constants-default_max_argument_count"></a>

### `DEFAULT_MAX_ARGUMENT_COUNT`

- API：`public`

```gdscript
const DEFAULT_MAX_ARGUMENT_COUNT: int = _MAX_SUPPORTED_ARGUMENT_COUNT
```

默认单个信号最多追踪的参数数量。

<a id="member-gfsignalruntimeprobe-constants-default_max_watch_tree_depth"></a>

### `DEFAULT_MAX_WATCH_TREE_DEPTH`

- API：`public`

```gdscript
const DEFAULT_MAX_WATCH_TREE_DEPTH: int = 64
```

默认递归监听节点树深度上限。

<a id="member-gfsignalruntimeprobe-constants-default_max_watch_tree_nodes"></a>

### `DEFAULT_MAX_WATCH_TREE_NODES`

- API：`public`

```gdscript
const DEFAULT_MAX_WATCH_TREE_NODES: int = 4096
```

默认递归监听节点树数量上限。

## 属性

<a id="member-gfsignalruntimeprobe-properties-max_events"></a>

### `max_events`

- API：`public`

```gdscript
var max_events: int = DEFAULT_MAX_EVENTS
```

最多保留的最近事件数量。小于等于 0 表示不保留历史，只发出 signal_emitted。

<a id="member-gfsignalruntimeprobe-properties-max_argument_count"></a>

### `max_argument_count`

- API：`public`

```gdscript
var max_argument_count: int = DEFAULT_MAX_ARGUMENT_COUNT
```

单个信号最多支持追踪的参数数量。

## 方法

<a id="member-gfsignalruntimeprobe-methods-watch_node"></a>

### `watch_node`

- API：`public`

```gdscript
func watch_node(source: Node, options: Dictionary = {}) -> Dictionary:
```

监听单个节点的信号。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 需要观察的节点。 |
| `options` | 选项，支持 include_signals、exclude_signals、include_internal、max_argument_count 与 connect_flags。 |

返回：监听报告。

结构：

- `options`: Dictionary，支持 include_signals、exclude_signals、include_internal、max_argument_count 和 connect_flags。
- `return`: Dictionary，包含 ok、watched_count、skipped_count 和 errors。

<a id="member-gfsignalruntimeprobe-methods-watch_tree"></a>

### `watch_tree`

- API：`public`

```gdscript
func watch_tree(root: Node, options: Dictionary = {}) -> Dictionary:
```

递归监听节点树。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 需要观察的根节点。 |
| `options` | 选项，支持 watch_node() 选项以及 recursive、include_internal_nodes、max_node_depth 与 max_nodes。 |

返回：监听报告。

结构：

- `options`: Dictionary，支持 watch_node() 选项以及 recursive、include_internal_nodes、max_node_depth 和 max_nodes。
- `return`: Dictionary，包含 ok、watched_count、skipped_count 和 errors。

<a id="member-gfsignalruntimeprobe-methods-unwatch_node"></a>

### `unwatch_node`

- API：`public`

```gdscript
func unwatch_node(source: Node) -> int:
```

停止监听某个节点。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 需要停止观察的节点。 |

返回：断开的信号数量。

<a id="member-gfsignalruntimeprobe-methods-unwatch_all"></a>

### `unwatch_all`

- API：`public`

```gdscript
func unwatch_all() -> int:
```

停止所有监听。

返回：断开的信号数量。

<a id="member-gfsignalruntimeprobe-methods-clear_events"></a>

### `clear_events`

- API：`public`

```gdscript
func clear_events() -> void:
```

清空最近事件。

<a id="member-gfsignalruntimeprobe-methods-get_events"></a>

### `get_events`

- API：`public`

```gdscript
func get_events() -> Array[Dictionary]:
```

获取最近事件副本。

返回：事件快照数组。

结构：

- `return`: Array[Dictionary]，每个元素包含 timestamp_msec、process_frame、physics_frame、source_instance_id、source_node_path、signal_name、argument_count、arguments 和 connections。

<a id="member-gfsignalruntimeprobe-methods-get_watch_count"></a>

### `get_watch_count`

- API：`public`

```gdscript
func get_watch_count() -> int:
```

获取被监听的信号数量。

返回：当前有效监听数量。

<a id="member-gfsignalruntimeprobe-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary，包含 watch_count、event_count、max_events、max_argument_count 和 watches。
