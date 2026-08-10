# GFNodeStateGroup

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/state_machine/node/gf_node_state_group.gd`
- 模块：`Standard`
- 继承：`Node`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

管理一组互斥激活的节点状态。 一个状态组内同一时间只有一个 GFNodeState 处于启用状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`state_added`](#member-gfnodestategroup-signals-state_added) | `signal state_added(state: GFNodeState)` |
| 信号 | [`state_removed`](#member-gfnodestategroup-signals-state_removed) | `signal state_removed(state: GFNodeState)` |
| 信号 | [`current_state_changed`](#member-gfnodestategroup-signals-current_state_changed) | `signal current_state_changed(old_state: GFNodeState, new_state: GFNodeState)` |
| 信号 | [`transition_blocked`](#member-gfnodestategroup-signals-transition_blocked) | `signal transition_blocked(from_state: GFNodeState, to_state_name: StringName, args: Dictionary, reason: String)` |
| 信号 | [`requested_transition`](#member-gfnodestategroup-signals-requested_transition) | `signal requested_transition(group_name: StringName, state_name: StringName, args: Dictionary)` |
| 信号 | [`state_event_handled`](#member-gfnodestategroup-signals-state_event_handled) | `signal state_event_handled(event_id: StringName, handler_state: GFNodeState, payload: Variant)` |
| 枚举 | [`StackExitPolicy`](#member-gfnodestategroup-enums-stackexitpolicy) | `enum StackExitPolicy` |
| 属性 | [`group_name`](#member-gfnodestategroup-properties-group_name) | `var group_name: StringName = &"":` |
| 属性 | [`initial_state`](#member-gfnodestategroup-properties-initial_state) | `var initial_state: StringName = &"":` |
| 属性 | [`initial_args`](#member-gfnodestategroup-properties-initial_args) | `var initial_args: Dictionary = {}` |
| 属性 | [`reload_states_on_ready`](#member-gfnodestategroup-properties-reload_states_on_ready) | `var reload_states_on_ready: bool = true` |
| 属性 | [`auto_start`](#member-gfnodestategroup-properties-auto_start) | `var auto_start: bool = true:` |
| 属性 | [`history_max_size`](#member-gfnodestategroup-properties-history_max_size) | `var history_max_size: int = 32` |
| 属性 | [`max_stack_depth`](#member-gfnodestategroup-properties-max_stack_depth) | `var max_stack_depth: int = 8` |
| 属性 | [`blackboard`](#member-gfnodestategroup-properties-blackboard) | `var blackboard: Dictionary = {}` |
| 方法 | [`get_group_name`](#member-gfnodestategroup-methods-get_group_name) | `func get_group_name() -> StringName:` |
| 方法 | [`transition_to`](#member-gfnodestategroup-methods-transition_to) | `func transition_to( next_state_name: StringName, args: Dictionary = {}, stack_exit_policy: int = StackExitPolicy.REQUIRE_GUARDS ) -> void:` |
| 方法 | [`push_state`](#member-gfnodestategroup-methods-push_state) | `func push_state(next_state_name: StringName, args: Dictionary = {}) -> void:` |
| 方法 | [`pop_state`](#member-gfnodestategroup-methods-pop_state) | `func pop_state(args: Dictionary = {}) -> bool:` |
| 方法 | [`add_state`](#member-gfnodestategroup-methods-add_state) | `func add_state(state: GFNodeState) -> void:` |
| 方法 | [`remove_state`](#member-gfnodestategroup-methods-remove_state) | `func remove_state(state: GFNodeState) -> bool:` |
| 方法 | [`get_state`](#member-gfnodestategroup-methods-get_state) | `func get_state(query_state_name: StringName) -> GFNodeState:` |
| 方法 | [`get_current_state`](#member-gfnodestategroup-methods-get_current_state) | `func get_current_state() -> GFNodeState:` |
| 方法 | [`get_current_state_name`](#member-gfnodestategroup-methods-get_current_state_name) | `func get_current_state_name() -> StringName:` |
| 方法 | [`get_state_history`](#member-gfnodestategroup-methods-get_state_history) | `func get_state_history() -> Array[StringName]:` |
| 方法 | [`get_stack_depth`](#member-gfnodestategroup-methods-get_stack_depth) | `func get_stack_depth() -> int:` |
| 方法 | [`get_blackboard`](#member-gfnodestategroup-methods-get_blackboard) | `func get_blackboard() -> Dictionary:` |
| 方法 | [`dispatch_state_event`](#member-gfnodestategroup-methods-dispatch_state_event) | `func dispatch_state_event(event_id: StringName, payload: Variant = null) -> bool:` |
| 方法 | [`is_in_state`](#member-gfnodestategroup-methods-is_in_state) | `func is_in_state(query_state_name: StringName) -> bool:` |
| 方法 | [`restart`](#member-gfnodestategroup-methods-restart) | `func restart(args: Dictionary = {}) -> void:` |
| 方法 | [`start`](#member-gfnodestategroup-methods-start) | `func start(args: Dictionary = {}) -> void:` |
| 方法 | [`stop`](#member-gfnodestategroup-methods-stop) | `func stop() -> void:` |
| 方法 | [`get_states`](#member-gfnodestategroup-methods-get_states) | `func get_states() -> Array[GFNodeState]:` |
| 方法 | [`get_state_snapshot`](#member-gfnodestategroup-methods-get_state_snapshot) | `func get_state_snapshot() -> Dictionary:` |
| 方法 | [`get_json_compatible_state_snapshot`](#member-gfnodestategroup-methods-get_json_compatible_state_snapshot) | `func get_json_compatible_state_snapshot(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`clear_states`](#member-gfnodestategroup-methods-clear_states) | `func clear_states(free_states: bool = false) -> void:` |
| 方法 | [`reload_states_from_children`](#member-gfnodestategroup-methods-reload_states_from_children) | `func reload_states_from_children() -> void:` |

## 信号

<a id="member-gfnodestategroup-signals-state_added"></a>

### `state_added`

- API：`public`

```gdscript
signal state_added(state: GFNodeState)
```

状态加入组后发出。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 新加入的状态节点。 |

<a id="member-gfnodestategroup-signals-state_removed"></a>

### `state_removed`

- API：`public`

```gdscript
signal state_removed(state: GFNodeState)
```

状态从组中移除后发出。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 被移除的状态节点。 |

<a id="member-gfnodestategroup-signals-current_state_changed"></a>

### `current_state_changed`

- API：`public`

```gdscript
signal current_state_changed(old_state: GFNodeState, new_state: GFNodeState)
```

当前状态切换后发出。

参数：

| 名称 | 说明 |
|---|---|
| `old_state` | 切换前的状态；没有旧状态时为 null。 |
| `new_state` | 切换后的状态；状态组停止时可为 null。 |

<a id="member-gfnodestategroup-signals-transition_blocked"></a>

### `transition_blocked`

- API：`public`
- 首次版本：`3.0.0`

```gdscript
signal transition_blocked(from_state: GFNodeState, to_state_name: StringName, args: Dictionary, reason: String)
```

状态切换被守卫阻止后发出。

参数：

| 名称 | 说明 |
|---|---|
| `from_state` | 发起切换时的当前状态；没有当前状态时为 null。 |
| `to_state_name` | 被阻止的目标状态名。 |
| `args` | 状态切换参数。 |
| `reason` | 阻止原因，通常为 "exit_guard"、"enter_guard" 或 "stack_exit_guard"。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestategroup-signals-requested_transition"></a>

### `requested_transition`

- API：`public`

```gdscript
signal requested_transition(group_name: StringName, state_name: StringName, args: Dictionary)
```

子状态请求跨组切换时发出。

参数：

| 名称 | 说明 |
|---|---|
| `group_name` | 目标状态组名。 |
| `state_name` | 目标状态名。 |
| `args` | 状态切换参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestategroup-signals-state_event_handled"></a>

### `state_event_handled`

- API：`public`

```gdscript
signal state_event_handled(event_id: StringName, handler_state: GFNodeState, payload: Variant)
```

当前状态或暂停栈状态处理状态事件后发出。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 状态事件标识。 |
| `handler_state` | 实际处理事件的状态节点。 |
| `payload` | 状态事件载荷。 |

结构：

- `payload`: 状态事件载荷；具体结构由 event_id 和项目逻辑约定。

## 枚举

<a id="member-gfnodestategroup-enums-stackexitpolicy"></a>

### `StackExitPolicy`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
enum StackExitPolicy {
	## 每个暂停状态都必须通过 can_exit()。
	REQUIRE_GUARDS,
	## 显式绕过暂停状态的 can_exit()，用于 teardown 等强制恢复场景。
	FORCE,
}
```

普通切换折叠暂停栈时的退出策略。

## 属性

<a id="member-gfnodestategroup-properties-group_name"></a>

### `group_name`

- API：`public`

```gdscript
var group_name: StringName = &"":
```

状态组注册名。为空时使用节点名称。

<a id="member-gfnodestategroup-properties-initial_state"></a>

### `initial_state`

- API：`public`

```gdscript
var initial_state: StringName = &"":
```

初始状态名。

<a id="member-gfnodestategroup-properties-initial_args"></a>

### `initial_args`

- API：`public`

```gdscript
var initial_args: Dictionary = {}
```

初始状态参数。

结构：

- `initial_args`: 初始状态参数 Dictionary；键和值由初始状态的项目逻辑约定。

<a id="member-gfnodestategroup-properties-reload_states_on_ready"></a>

### `reload_states_on_ready`

- API：`public`

```gdscript
var reload_states_on_ready: bool = true
```

ready 时是否自动从子节点加载状态。

<a id="member-gfnodestategroup-properties-auto_start"></a>

### `auto_start`

- API：`public`

```gdscript
var auto_start: bool = true:
```

初始化后是否自动进入 initial_state。关闭后可通过 start() 手动启动。

<a id="member-gfnodestategroup-properties-history_max_size"></a>

### `history_max_size`

- API：`public`

```gdscript
var history_max_size: int = 32
```

每个状态组保留的历史状态名数量。

<a id="member-gfnodestategroup-properties-max_stack_depth"></a>

### `max_stack_depth`

- API：`public`

```gdscript
var max_stack_depth: int = 8
```

push_state 可叠加的最大栈深度。

<a id="member-gfnodestategroup-properties-blackboard"></a>

### `blackboard`

- API：`public`

```gdscript
var blackboard: Dictionary = {}
```

状态组共享黑板。框架不解释其中字段。

结构：

- `blackboard`: 状态组共享黑板 Dictionary；键和值由项目状态逻辑约定。

## 方法

<a id="member-gfnodestategroup-methods-get_group_name"></a>

### `get_group_name`

- API：`public`

```gdscript
func get_group_name() -> StringName:
```

获取状态组注册名。

返回：非空 group_name，或节点名称转换出的 StringName。

<a id="member-gfnodestategroup-methods-transition_to"></a>

### `transition_to`

- API：`public`
- 首次版本：`3.0.0`

```gdscript
func transition_to( next_state_name: StringName, args: Dictionary = {}, stack_exit_policy: int = StackExitPolicy.REQUIRE_GUARDS ) -> void:
```

切换到指定状态。

参数：

| 名称 | 说明 |
|---|---|
| `next_state_name` | 要切换到的目标状态名称。 |
| `args` | 状态切换时传递的可选参数。 |
| `stack_exit_policy` | 折叠暂停栈时要求退出守卫，或显式强制退出。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestategroup-methods-push_state"></a>

### `push_state`

- API：`public`

```gdscript
func push_state(next_state_name: StringName, args: Dictionary = {}) -> void:
```

暂停当前状态并叠加进入一个子状态。

参数：

| 名称 | 说明 |
|---|---|
| `next_state_name` | 要切换到的目标状态名称。 |
| `args` | 状态切换时传递的可选参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestategroup-methods-pop_state"></a>

### `pop_state`

- API：`public`

```gdscript
func pop_state(args: Dictionary = {}) -> bool:
```

退出当前子状态并恢复上一层状态。

参数：

| 名称 | 说明 |
|---|---|
| `args` | 状态切换时传递的可选参数。 |

返回：成功恢复上一层状态时返回 true。

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestategroup-methods-add_state"></a>

### `add_state`

- API：`public`

```gdscript
func add_state(state: GFNodeState) -> void:
```

添加状态节点。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 状态节点。 |

<a id="member-gfnodestategroup-methods-remove_state"></a>

### `remove_state`

- API：`public`

```gdscript
func remove_state(state: GFNodeState) -> bool:
```

移除状态节点。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 状态节点。 |

返回：成功移除已注册状态时返回 true。

<a id="member-gfnodestategroup-methods-get_state"></a>

### `get_state`

- API：`public`

```gdscript
func get_state(query_state_name: StringName) -> GFNodeState:
```

获取状态。

参数：

| 名称 | 说明 |
|---|---|
| `query_state_name` | 目标名称。 |

返回：注册名对应的状态节点；不存在时返回 null。

<a id="member-gfnodestategroup-methods-get_current_state"></a>

### `get_current_state`

- API：`public`

```gdscript
func get_current_state() -> GFNodeState:
```

获取当前状态。

返回：当前激活状态；未启动或已停止时返回 null。

<a id="member-gfnodestategroup-methods-get_current_state_name"></a>

### `get_current_state_name`

- API：`public`

```gdscript
func get_current_state_name() -> StringName:
```

获取当前状态名。

返回：当前激活状态名；未启动或已停止时返回空 StringName。

<a id="member-gfnodestategroup-methods-get_state_history"></a>

### `get_state_history`

- API：`public`

```gdscript
func get_state_history() -> Array[StringName]:
```

获取状态切换历史。

返回：最近进入过的状态名列表。

结构：

- `return`: 状态历史 Array[StringName]，按进入顺序排列。

<a id="member-gfnodestategroup-methods-get_stack_depth"></a>

### `get_stack_depth`

- API：`public`

```gdscript
func get_stack_depth() -> int:
```

获取当前暂停栈深度。

返回：当前暂停栈深度。

<a id="member-gfnodestategroup-methods-get_blackboard"></a>

### `get_blackboard`

- API：`public`

```gdscript
func get_blackboard() -> Dictionary:
```

获取状态组共享黑板。

返回：黑板字典。

结构：

- `return`: 状态组共享黑板 Dictionary；键和值由项目状态逻辑约定，调用方可直接修改。

<a id="member-gfnodestategroup-methods-dispatch_state_event"></a>

### `dispatch_state_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func dispatch_state_event(event_id: StringName, payload: Variant = null) -> bool:
```

从当前状态开始向暂停栈上抛状态事件。 处理器改变激活集合时，本次派发会在当前处理器返回后终止；新激活或已退出状态不会接收旧周期事件。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 状态事件标识。 |
| `payload` | 状态事件载荷。 |

返回：有状态处理该事件时返回 true。

结构：

- `payload`: 状态事件载荷；具体结构由 event_id 和项目逻辑约定。

<a id="member-gfnodestategroup-methods-is_in_state"></a>

### `is_in_state`

- API：`public`

```gdscript
func is_in_state(query_state_name: StringName) -> bool:
```

判断指定状态是否为当前状态或暂停栈中的状态。

参数：

| 名称 | 说明 |
|---|---|
| `query_state_name` | 目标名称。 |

返回：指定状态位于当前状态或暂停栈中时返回 true。

<a id="member-gfnodestategroup-methods-restart"></a>

### `restart`

- API：`public`

```gdscript
func restart(args: Dictionary = {}) -> void:
```

重启当前状态；若当前没有状态，则尝试进入初始状态。

参数：

| 名称 | 说明 |
|---|---|
| `args` | 状态切换时传递的可选参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestategroup-methods-start"></a>

### `start`

- API：`public`

```gdscript
func start(args: Dictionary = {}) -> void:
```

进入初始状态。若已有当前状态则保持不变。

参数：

| 名称 | 说明 |
|---|---|
| `args` | 启动时传给初始状态的参数；为空时使用 initial_args。 |

结构：

- `args`: 启动参数 Dictionary；为空时使用 initial_args。

<a id="member-gfnodestategroup-methods-stop"></a>

### `stop`

- API：`public`

```gdscript
func stop() -> void:
```

停止当前激活状态，但保留已注册状态节点。

<a id="member-gfnodestategroup-methods-get_states"></a>

### `get_states`

- API：`public`

```gdscript
func get_states() -> Array[GFNodeState]:
```

获取所有状态。

返回：已注册状态节点列表。

结构：

- `return`: 已注册 GFNodeState 节点数组。

<a id="member-gfnodestategroup-methods-get_state_snapshot"></a>

### `get_state_snapshot`

- API：`public`

```gdscript
func get_state_snapshot() -> Dictionary:
```

获取状态组调试快照。

返回：包含当前状态、暂停栈、历史、注册状态和黑板副本的字典。

结构：

- `return`: 调试快照 Dictionary，包含 group_name、current_state、stack、history、states 和 blackboard 字段。

<a id="member-gfnodestategroup-methods-get_json_compatible_state_snapshot"></a>

### `get_json_compatible_state_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_json_compatible_state_snapshot(options: Dictionary = {}) -> Dictionary:
```

获取 JSON-safe 状态组调试快照。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 传给 GFReportValueCodec 的编码选项。 |

返回：可安全 JSON.stringify() 的状态组调试快照。

结构：

- `options`: Dictionary with GFReportValueCodec options.
- `return`: Dictionary，包含 JSON-safe group_name、current_state、stack、history、states 和 blackboard 字段。

<a id="member-gfnodestategroup-methods-clear_states"></a>

### `clear_states`

- API：`public`

```gdscript
func clear_states(free_states: bool = false) -> void:
```

清空状态。

参数：

| 名称 | 说明 |
|---|---|
| `free_states` | 为 true 时同时释放已移除的状态节点。 |

<a id="member-gfnodestategroup-methods-reload_states_from_children"></a>

### `reload_states_from_children`

- API：`public`

```gdscript
func reload_states_from_children() -> void:
```

从子节点重新加载状态。
