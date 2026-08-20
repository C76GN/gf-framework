# GFTurnFlowSystem

[API Reference](../index.md) / [Turn Based](../extensions-turn-based.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/turn_based/runtime/gf_turn_flow_system.gd`
- 模块：`Turn Based`
- 继承：`GFSystem`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用回合流程系统。 提供阶段推进、行动排队和按优先级解析能力。 它不关心战斗、卡牌、棋盘等具体业务，只调度抽象行动。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`flow_started`](#member-gfturnflowsystem-signals-flow_started) | `signal flow_started(context: GFTurnContext)` |
| 信号 | [`flow_stopped`](#member-gfturnflowsystem-signals-flow_stopped) | `signal flow_stopped(context: GFTurnContext)` |
| 信号 | [`phase_changed`](#member-gfturnflowsystem-signals-phase_changed) | `signal phase_changed(phase: GFTurnPhase, index: int)` |
| 信号 | [`action_enqueued`](#member-gfturnflowsystem-signals-action_enqueued) | `signal action_enqueued(action: GFTurnAction)` |
| 信号 | [`action_resolved`](#member-gfturnflowsystem-signals-action_resolved) | `signal action_resolved(action: GFTurnAction)` |
| 属性 | [`context`](#member-gfturnflowsystem-properties-context) | `var context: GFTurnContext:` |
| 属性 | [`phases`](#member-gfturnflowsystem-properties-phases) | `var phases: Array[GFTurnPhase]:` |
| 属性 | [`current_phase_index`](#member-gfturnflowsystem-properties-current_phase_index) | `var current_phase_index: int:` |
| 属性 | [`is_running`](#member-gfturnflowsystem-properties-is_running) | `var is_running: bool:` |
| 属性 | [`sort_actions_before_resolve`](#member-gfturnflowsystem-properties-sort_actions_before_resolve) | `var sort_actions_before_resolve: bool = true` |
| 属性 | [`signal_timeout_seconds`](#member-gfturnflowsystem-properties-signal_timeout_seconds) | `var signal_timeout_seconds: float = 30.0` |
| 属性 | [`signal_timeout_respects_time_scale`](#member-gfturnflowsystem-properties-signal_timeout_respects_time_scale) | `var signal_timeout_respects_time_scale: bool = true` |
| 方法 | [`set_context`](#member-gfturnflowsystem-methods-set_context) | `func set_context(p_context: GFTurnContext) -> void:` |
| 方法 | [`set_phases`](#member-gfturnflowsystem-methods-set_phases) | `func set_phases(p_phases: Array[GFTurnPhase]) -> void:` |
| 方法 | [`start`](#member-gfturnflowsystem-methods-start) | `func start(reset_indices: bool = true) -> void:` |
| 方法 | [`stop`](#member-gfturnflowsystem-methods-stop) | `func stop(should_clear_actions: bool = true) -> void:` |
| 方法 | [`dispose`](#member-gfturnflowsystem-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`advance_phase`](#member-gfturnflowsystem-methods-advance_phase) | `func advance_phase() -> void:` |
| 方法 | [`get_actions`](#member-gfturnflowsystem-methods-get_actions) | `func get_actions() -> Array[GFTurnAction]:` |
| 方法 | [`get_action_count`](#member-gfturnflowsystem-methods-get_action_count) | `func get_action_count() -> int:` |
| 方法 | [`clear_actions`](#member-gfturnflowsystem-methods-clear_actions) | `func clear_actions() -> void:` |
| 方法 | [`enqueue_action`](#member-gfturnflowsystem-methods-enqueue_action) | `func enqueue_action(action: GFTurnAction) -> void:` |
| 方法 | [`resolve_actions`](#member-gfturnflowsystem-methods-resolve_actions) | `func resolve_actions(order_resolver: Callable = Callable()) -> void:` |

## 信号

<a id="member-gfturnflowsystem-signals-flow_started"></a>

### `flow_started`

- API：`public`

```gdscript
signal flow_started(context: GFTurnContext)
```

流程开始时发出。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 当前回合上下文。 |

<a id="member-gfturnflowsystem-signals-flow_stopped"></a>

### `flow_stopped`

- API：`public`

```gdscript
signal flow_stopped(context: GFTurnContext)
```

流程停止时发出。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 当前回合上下文。 |

<a id="member-gfturnflowsystem-signals-phase_changed"></a>

### `phase_changed`

- API：`public`

```gdscript
signal phase_changed(phase: GFTurnPhase, index: int)
```

阶段切换时发出。

参数：

| 名称 | 说明 |
|---|---|
| `phase` | 当前阶段。 |
| `index` | 当前阶段索引。 |

<a id="member-gfturnflowsystem-signals-action_enqueued"></a>

### `action_enqueued`

- API：`public`

```gdscript
signal action_enqueued(action: GFTurnAction)
```

行动入队时发出。

参数：

| 名称 | 说明 |
|---|---|
| `action` | 入队行动。 |

<a id="member-gfturnflowsystem-signals-action_resolved"></a>

### `action_resolved`

- API：`public`

```gdscript
signal action_resolved(action: GFTurnAction)
```

行动解析完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `action` | 已解析行动。 |

## 属性

<a id="member-gfturnflowsystem-properties-context"></a>

### `context`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var context: GFTurnContext:
```

当前回合上下文。

<a id="member-gfturnflowsystem-properties-phases"></a>

### `phases`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var phases: Array[GFTurnPhase]:
```

阶段列表。

<a id="member-gfturnflowsystem-properties-current_phase_index"></a>

### `current_phase_index`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var current_phase_index: int:
```

当前阶段索引。

<a id="member-gfturnflowsystem-properties-is_running"></a>

### `is_running`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var is_running: bool:
```

当前是否正在运行。

<a id="member-gfturnflowsystem-properties-sort_actions_before_resolve"></a>

### `sort_actions_before_resolve`

- API：`public`

```gdscript
var sort_actions_before_resolve: bool = true
```

解析行动前是否按优先级排序。

<a id="member-gfturnflowsystem-properties-signal_timeout_seconds"></a>

### `signal_timeout_seconds`

- API：`public`

```gdscript
var signal_timeout_seconds: float = 30.0
```

Signal 等待超时时间。小于等于 0 表示不启用超时。

<a id="member-gfturnflowsystem-properties-signal_timeout_respects_time_scale"></a>

### `signal_timeout_respects_time_scale`

- API：`public`

```gdscript
var signal_timeout_respects_time_scale: bool = true
```

Signal 超时计时是否跟随 GFTimeUtility 的暂停与 time_scale。

## 方法

<a id="member-gfturnflowsystem-methods-set_context"></a>

### `set_context`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func set_context(p_context: GFTurnContext) -> void:
```

设置上下文。 存在活动 Context operation claim 时会拒绝修改；operation 安全收尾并释放最后一张 claim 后可顺序重试。

参数：

| 名称 | 说明 |
|---|---|
| `p_context` | 新上下文。 |

<a id="member-gfturnflowsystem-methods-set_phases"></a>

### `set_phases`

- API：`public`

```gdscript
func set_phases(p_phases: Array[GFTurnPhase]) -> void:
```

设置阶段列表。

参数：

| 名称 | 说明 |
|---|---|
| `p_phases` | 新阶段列表。 |

<a id="member-gfturnflowsystem-methods-start"></a>

### `start`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func start(reset_indices: bool = true) -> void:
```

开始流程。 若同一 Context 正由其他 Flow generation 持有，本次调用会在重置索引、轮次或发出信号前失败关闭；最后一张 operation claim 释放后可顺序重试。 若本 system 在自身 [signal flow_started] 通知中完成 [method stop]，并在由此发出的 [signal flow_stopped] 回调中再次调用本方法，首个重启请求会等旧 claim 释放后同步重放；重放前的后续 [method stop] 或 [method dispose] 会取消该请求。

参数：

| 名称 | 说明 |
|---|---|
| `reset_indices` | 是否重置阶段索引和轮次数据。 |

<a id="member-gfturnflowsystem-methods-stop"></a>

### `stop`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func stop(should_clear_actions: bool = true) -> void:
```

停止流程。

参数：

| 名称 | 说明 |
|---|---|
| `should_clear_actions` | 是否清空待处理行动。即使流程已经 stopped，true 仍会幂等清理并封存队列；此前的保留策略也会升级为清理。 |

<a id="member-gfturnflowsystem-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func dispose() -> void:
```

销毁系统，撤销所有在途 operation，并拒绝后续启动、阶段推进、行动入队与行动解析。 在途 continuation 会先完成精确清理，再释放 Context claim。

<a id="member-gfturnflowsystem-methods-advance_phase"></a>

### `advance_phase`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func advance_phase() -> void:
```

推进到下一个阶段。 若同一 Context 正由其他 Flow generation 持有，本次调用会在清理 actor、修改阶段/轮次或发出阶段信号前失败关闭；最后一张 operation claim 释放后可顺序重试。

<a id="member-gfturnflowsystem-methods-get_actions"></a>

### `get_actions`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_actions() -> Array[GFTurnAction]:
```

获取待处理行动的只读快照。

返回：当前待处理行动数组副本。

<a id="member-gfturnflowsystem-methods-get_action_count"></a>

### `get_action_count`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_action_count() -> int:
```

获取待处理行动数量。

返回：当前待处理行动数量。

<a id="member-gfturnflowsystem-methods-clear_actions"></a>

### `clear_actions`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_actions() -> void:
```

清空待处理行动并封存这些一次性实例。

<a id="member-gfturnflowsystem-methods-enqueue_action"></a>

### `enqueue_action`

- API：`public`

```gdscript
func enqueue_action(action: GFTurnAction) -> void:
```

加入一个行动。

参数：

| 名称 | 说明 |
|---|---|
| `action` | 行动实例。 |

<a id="member-gfturnflowsystem-methods-resolve_actions"></a>

### `resolve_actions`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func resolve_actions(order_resolver: Callable = Callable()) -> void:
```

解析当前上下文中的所有行动。 若同一 Context 正由其他 Flow generation 持有，本次调用会在清理 actor、取走队列、写入 current_actor 或调用 action 前失败关闭；最后一张 operation claim 释放后可顺序重试。

参数：

| 名称 | 说明 |
|---|---|
| `order_resolver` | 可选排序回调，签名为 func(a, b) -> bool；调用方必须提供无副作用、确定且满足严格弱序的比较器。自定义比较器不继承默认 non-finite 与入队顺序规则。 |
