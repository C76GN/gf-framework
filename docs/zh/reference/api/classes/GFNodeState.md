# GFNodeState

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/state_machine/node/gf_node_state.gd`
- 模块：`Standard`
- 继承：`Node`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

基于场景树的状态节点。 适合需要直接访问动画、碰撞、输入或子节点的状态逻辑。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`requested_transition`](#member-gfnodestate-signals-requested_transition) | `signal requested_transition(group_name: StringName, state_name: StringName, args: Dictionary)` |
| 属性 | [`state_name`](#member-gfnodestate-properties-state_name) | `var state_name: StringName = &""` |
| 属性 | [`enter_conditions`](#member-gfnodestate-properties-enter_conditions) | `var enter_conditions: Array[Resource] = []` |
| 属性 | [`exit_conditions`](#member-gfnodestate-properties-exit_conditions) | `var exit_conditions: Array[Resource] = []` |
| 属性 | [`behaviors`](#member-gfnodestate-properties-behaviors) | `var behaviors: Array[Resource] = []` |
| 属性 | [`host`](#member-gfnodestate-properties-host) | `var host: Node:` |
| 方法 | [`get_machine`](#member-gfnodestate-methods-get_machine) | `func get_machine() -> Object:` |
| 方法 | [`get_group`](#member-gfnodestate-methods-get_group) | `func get_group() -> Object:` |
| 方法 | [`get_host`](#member-gfnodestate-methods-get_host) | `func get_host() -> Node:` |
| 方法 | [`get_state_name`](#member-gfnodestate-methods-get_state_name) | `func get_state_name() -> StringName:` |
| 方法 | [`enter`](#member-gfnodestate-methods-enter) | `func enter(previous_state: StringName = &"", args: Dictionary = {}) -> void:` |
| 方法 | [`exit`](#member-gfnodestate-methods-exit) | `func exit(next_state: StringName = &"", args: Dictionary = {}) -> void:` |
| 方法 | [`pause`](#member-gfnodestate-methods-pause) | `func pause(next_state: StringName = &"", args: Dictionary = {}) -> void:` |
| 方法 | [`resume`](#member-gfnodestate-methods-resume) | `func resume(previous_state: StringName = &"", args: Dictionary = {}) -> void:` |
| 方法 | [`transition_to`](#member-gfnodestate-methods-transition_to) | `func transition_to(path: StringName, args: Dictionary = {}) -> void:` |
| 方法 | [`initialize`](#member-gfnodestate-methods-initialize) | `func initialize() -> void:` |
| 方法 | [`can_enter`](#member-gfnodestate-methods-can_enter) | `func can_enter(previous_state: StringName = &"", args: Dictionary = {}) -> bool:` |
| 方法 | [`can_exit`](#member-gfnodestate-methods-can_exit) | `func can_exit(next_state: StringName = &"", args: Dictionary = {}) -> bool:` |
| 方法 | [`get_blackboard`](#member-gfnodestate-methods-get_blackboard) | `func get_blackboard() -> Dictionary:` |
| 方法 | [`handle_state_event`](#member-gfnodestate-methods-handle_state_event) | `func handle_state_event(event_id: StringName, payload: Variant = null) -> bool:` |
| 方法 | [`get_architecture_or_null`](#member-gfnodestate-methods-get_architecture_or_null) | `func get_architecture_or_null() -> GFArchitecture:` |
| 方法 | [`get_model`](#member-gfnodestate-methods-get_model) | `func get_model(model_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_system`](#member-gfnodestate-methods-get_system) | `func get_system(system_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_utility`](#member-gfnodestate-methods-get_utility) | `func get_utility(utility_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_model`](#member-gfnodestate-methods-get_local_model) | `func get_local_model(model_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_system`](#member-gfnodestate-methods-get_local_system) | `func get_local_system(system_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_utility`](#member-gfnodestate-methods-get_local_utility) | `func get_local_utility(utility_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`send_command`](#member-gfnodestate-methods-send_command) | `func send_command(command: Object) -> Variant:` |
| 方法 | [`send_query`](#member-gfnodestate-methods-send_query) | `func send_query(query: Object) -> Variant:` |
| 方法 | [`send_event`](#member-gfnodestate-methods-send_event) | `func send_event(event_instance: Object) -> void:` |
| 方法 | [`send_simple_event`](#member-gfnodestate-methods-send_simple_event) | `func send_simple_event(event_id: StringName, payload: Variant = null) -> void:` |
| 方法 | [`register_event`](#member-gfnodestate-methods-register_event) | `func register_event(event_type: Script, listener: GFEventListener, priority: int = 0) -> void:` |
| 方法 | [`unregister_event`](#member-gfnodestate-methods-unregister_event) | `func unregister_event(event_type: Script, listener: GFEventListener) -> void:` |
| 方法 | [`register_assignable_event`](#member-gfnodestate-methods-register_assignable_event) | `func register_assignable_event(base_event_type: Script, listener: GFEventListener, priority: int = 0) -> void:` |
| 方法 | [`unregister_assignable_event`](#member-gfnodestate-methods-unregister_assignable_event) | `func unregister_assignable_event(base_event_type: Script, listener: GFEventListener) -> void:` |
| 方法 | [`register_simple_event`](#member-gfnodestate-methods-register_simple_event) | `func register_simple_event(event_id: StringName, listener: GFEventListener) -> void:` |
| 方法 | [`unregister_simple_event`](#member-gfnodestate-methods-unregister_simple_event) | `func unregister_simple_event(event_id: StringName, listener: GFEventListener) -> void:` |
| 方法 | [`unregister_owner_events`](#member-gfnodestate-methods-unregister_owner_events) | `func unregister_owner_events() -> void:` |
| 方法 | [`_initialize`](#member-gfnodestate-methods-_initialize) | `func _initialize() -> void:` |
| 方法 | [`_can_enter`](#member-gfnodestate-methods-_can_enter) | `func _can_enter(_previous_state: StringName = &"", _args: Dictionary = {}) -> bool:` |
| 方法 | [`_can_exit`](#member-gfnodestate-methods-_can_exit) | `func _can_exit(_next_state: StringName = &"", _args: Dictionary = {}) -> bool:` |
| 方法 | [`_enter`](#member-gfnodestate-methods-_enter) | `func _enter(_previous_state: StringName = &"", _args: Dictionary = {}) -> void:` |
| 方法 | [`_exit`](#member-gfnodestate-methods-_exit) | `func _exit(_next_state: StringName = &"", _args: Dictionary = {}) -> void:` |
| 方法 | [`_pause`](#member-gfnodestate-methods-_pause) | `func _pause(_next_state: StringName = &"", _args: Dictionary = {}) -> void:` |
| 方法 | [`_resume`](#member-gfnodestate-methods-_resume) | `func _resume(_previous_state: StringName = &"", _args: Dictionary = {}) -> void:` |
| 方法 | [`_handle_state_event`](#member-gfnodestate-methods-_handle_state_event) | `func _handle_state_event(_event_id: StringName, _payload: Variant = null) -> bool:` |

## 信号

<a id="member-gfnodestate-signals-requested_transition"></a>

### `requested_transition`

- API：`public`

```gdscript
signal requested_transition(group_name: StringName, state_name: StringName, args: Dictionary)
```

状态请求切换时发出，由所属状态组或状态机处理。

参数：

| 名称 | 说明 |
|---|---|
| `group_name` | 目标状态组名。 |
| `state_name` | 目标状态名。 |
| `args` | 状态切换参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

## 属性

<a id="member-gfnodestate-properties-state_name"></a>

### `state_name`

- API：`public`

```gdscript
var state_name: StringName = &""
```

状态注册名。为空时使用节点名称。

<a id="member-gfnodestate-properties-enter_conditions"></a>

### `enter_conditions`

- API：`public`

```gdscript
var enter_conditions: Array[Resource] = []
```

进入状态前需要全部通过的条件资源。

结构：

- `enter_conditions`: 元素为 GFNodeStateCondition 或兼容 evaluate() 入口的 Resource 列表。

<a id="member-gfnodestate-properties-exit_conditions"></a>

### `exit_conditions`

- API：`public`

```gdscript
var exit_conditions: Array[Resource] = []
```

离开状态前需要全部通过的条件资源。

结构：

- `exit_conditions`: 元素为 GFNodeStateCondition 或兼容 evaluate() 入口的 Resource 列表。

<a id="member-gfnodestate-properties-behaviors"></a>

### `behaviors`

- API：`public`

```gdscript
var behaviors: Array[Resource] = []
```

进入、退出、暂停、恢复和事件处理时调用的可复用行为资源。

结构：

- `behaviors`: 元素为 GFNodeStateBehavior 或兼容状态生命周期入口的 Resource 列表。

<a id="member-gfnodestate-properties-host"></a>

### `host`

- API：`public`

```gdscript
var host: Node:
```

状态机宿主节点。通常是 GFNodeStateMachine 的父节点。

## 方法

<a id="member-gfnodestate-methods-get_machine"></a>

### `get_machine`

- API：`public`

```gdscript
func get_machine() -> Object:
```

获取所属状态机。

返回：所属 GFNodeStateMachine；尚未挂入状态组时返回 null。

<a id="member-gfnodestate-methods-get_group"></a>

### `get_group`

- API：`public`

```gdscript
func get_group() -> Object:
```

获取所属状态组。

返回：所属 GFNodeStateGroup；尚未挂入状态组时返回 null。

<a id="member-gfnodestate-methods-get_host"></a>

### `get_host`

- API：`public`

```gdscript
func get_host() -> Node:
```

获取状态机宿主节点。若无状态机，则退回到状态组父节点或当前父节点。

返回：状态机宿主节点；不可用时返回当前父节点或 null。

<a id="member-gfnodestate-methods-get_state_name"></a>

### `get_state_name`

- API：`public`

```gdscript
func get_state_name() -> StringName:
```

获取实际注册名。

返回：非空 state_name，或节点名称转换出的 StringName。

<a id="member-gfnodestate-methods-enter"></a>

### `enter`

- API：`public`

```gdscript
func enter(previous_state: StringName = &"", args: Dictionary = {}) -> void:
```

进入状态。

参数：

| 名称 | 说明 |
|---|---|
| `previous_state` | 上一个状态名称。 |
| `args` | 状态切换时传递的可选参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestate-methods-exit"></a>

### `exit`

- API：`public`

```gdscript
func exit(next_state: StringName = &"", args: Dictionary = {}) -> void:
```

离开状态。

参数：

| 名称 | 说明 |
|---|---|
| `next_state` | 下一个状态名称。 |
| `args` | 状态切换时传递的可选参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestate-methods-pause"></a>

### `pause`

- API：`public`

```gdscript
func pause(next_state: StringName = &"", args: Dictionary = {}) -> void:
```

进入栈式子状态时暂停当前状态。

参数：

| 名称 | 说明 |
|---|---|
| `next_state` | 下一个状态名称。 |
| `args` | 状态切换时传递的可选参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestate-methods-resume"></a>

### `resume`

- API：`public`

```gdscript
func resume(previous_state: StringName = &"", args: Dictionary = {}) -> void:
```

弹出栈式子状态后恢复当前状态。

参数：

| 名称 | 说明 |
|---|---|
| `previous_state` | 上一个状态名称。 |
| `args` | 状态切换时传递的可选参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestate-methods-transition_to"></a>

### `transition_to`

- API：`public`

```gdscript
func transition_to(path: StringName, args: Dictionary = {}) -> void:
```

请求切换状态。path 可为 "State" 或 "Group/State"。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径或状态路径。 |
| `args` | 状态切换时传递的可选参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestate-methods-initialize"></a>

### `initialize`

- API：`public`

```gdscript
func initialize() -> void:
```

状态初始化 Hook。状态加入状态组时调用一次。

<a id="member-gfnodestate-methods-can_enter"></a>

### `can_enter`

- API：`public`

```gdscript
func can_enter(previous_state: StringName = &"", args: Dictionary = {}) -> bool:
```

判断是否允许进入状态。

参数：

| 名称 | 说明 |
|---|---|
| `previous_state` | 来源状态名。 |
| `args` | 切换参数。 |

返回：允许进入返回 true。

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestate-methods-can_exit"></a>

### `can_exit`

- API：`public`

```gdscript
func can_exit(next_state: StringName = &"", args: Dictionary = {}) -> bool:
```

判断是否允许离开状态。

参数：

| 名称 | 说明 |
|---|---|
| `next_state` | 目标状态名。 |
| `args` | 切换参数。 |

返回：允许离开返回 true。

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestate-methods-get_blackboard"></a>

### `get_blackboard`

- API：`public`

```gdscript
func get_blackboard() -> Dictionary:
```

获取状态组共享黑板。

返回：黑板字典；没有状态组时返回空字典。

结构：

- `return`: 状态组共享黑板 Dictionary；键和值由项目状态逻辑约定。

<a id="member-gfnodestate-methods-handle_state_event"></a>

### `handle_state_event`

- API：`public`

```gdscript
func handle_state_event(event_id: StringName, payload: Variant = null) -> bool:
```

处理状态事件。返回 false 时事件会继续交给同组的暂停栈状态。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 状态事件标识。 |
| `payload` | 状态事件载荷。 |

返回：已处理返回 true。

结构：

- `payload`: 状态事件载荷；具体结构由 event_id 和项目逻辑约定。

<a id="member-gfnodestate-methods-get_architecture_or_null"></a>

### `get_architecture_or_null`

- API：`public`

```gdscript
func get_architecture_or_null() -> GFArchitecture:
```

获取当前状态可用的架构实例。

返回：架构实例；状态未挂入可解析上下文时返回 null。

<a id="member-gfnodestate-methods-get_model"></a>

### `get_model`

- API：`public`

```gdscript
func get_model(model_type: Script, require_ready: bool = false) -> Object:
```

通过当前状态上下文获取 Model。

参数：

| 名称 | 说明 |
|---|---|
| `model_type` | 模型脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：模型实例；不可用时返回 null。

<a id="member-gfnodestate-methods-get_system"></a>

### `get_system`

- API：`public`

```gdscript
func get_system(system_type: Script, require_ready: bool = false) -> Object:
```

通过当前状态上下文获取 System。

参数：

| 名称 | 说明 |
|---|---|
| `system_type` | 系统脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：系统实例；不可用时返回 null。

<a id="member-gfnodestate-methods-get_utility"></a>

### `get_utility`

- API：`public`

```gdscript
func get_utility(utility_type: Script, require_ready: bool = false) -> Object:
```

通过当前状态上下文获取 Utility。

参数：

| 名称 | 说明 |
|---|---|
| `utility_type` | 工具脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：工具实例；不可用时返回 null。

<a id="member-gfnodestate-methods-get_local_model"></a>

### `get_local_model`

- API：`public`

```gdscript
func get_local_model(model_type: Script, require_ready: bool = false) -> Object:
```

仅从当前状态所属架构获取 Model，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `model_type` | 模型脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前架构中的模型实例；不可用时返回 null。

<a id="member-gfnodestate-methods-get_local_system"></a>

### `get_local_system`

- API：`public`

```gdscript
func get_local_system(system_type: Script, require_ready: bool = false) -> Object:
```

仅从当前状态所属架构获取 System，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `system_type` | 系统脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前架构中的系统实例；不可用时返回 null。

<a id="member-gfnodestate-methods-get_local_utility"></a>

### `get_local_utility`

- API：`public`

```gdscript
func get_local_utility(utility_type: Script, require_ready: bool = false) -> Object:
```

仅从当前状态所属架构获取 Utility，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `utility_type` | 工具脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前架构中的工具实例；不可用时返回 null。

<a id="member-gfnodestate-methods-send_command"></a>

### `send_command`

- API：`public`

```gdscript
func send_command(command: Object) -> Variant:
```

向当前状态上下文发送命令。

参数：

| 名称 | 说明 |
|---|---|
| `command` | 要发送的命令实例。 |

返回：命令执行结果；无可用架构时返回 null。

结构：

- `return`: 命令返回值；具体结构由 GFCommand 实现决定。

<a id="member-gfnodestate-methods-send_query"></a>

### `send_query`

- API：`public`

```gdscript
func send_query(query: Object) -> Variant:
```

向当前状态上下文发送查询。

参数：

| 名称 | 说明 |
|---|---|
| `query` | 要发送的查询实例。 |

返回：查询结果；无可用架构时返回 null。

结构：

- `return`: 查询返回值；具体结构由 GFQuery 实现决定。

<a id="member-gfnodestate-methods-send_event"></a>

### `send_event`

- API：`public`

```gdscript
func send_event(event_instance: Object) -> void:
```

发送类型事件。

参数：

| 名称 | 说明 |
|---|---|
| `event_instance` | 要分发的事件实例。 |

<a id="member-gfnodestate-methods-send_simple_event"></a>

### `send_simple_event`

- API：`public`

```gdscript
func send_simple_event(event_id: StringName, payload: Variant = null) -> void:
```

发送轻量级 StringName 事件。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `payload` | 可选的事件附加数据。 |

结构：

- `payload`: 轻量事件载荷；具体结构由 event_id 和项目逻辑约定。

<a id="member-gfnodestate-methods-register_event"></a>

### `register_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_event(event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
```

注册类型事件监听器，默认以当前状态作为 owner。

参数：

| 名称 | 说明 |
|---|---|
| `event_type` | 要监听的脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |

<a id="member-gfnodestate-methods-unregister_event"></a>

### `unregister_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_event(event_type: Script, listener: GFEventListener) -> void:
```

注销类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_type` | 要注销的脚本类型。 |
| `listener` | 要移除的事件监听器契约。 |

<a id="member-gfnodestate-methods-register_assignable_event"></a>

### `register_assignable_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_assignable_event(base_event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
```

注册可赋值类型事件监听器，默认以当前状态作为 owner。

参数：

| 名称 | 说明 |
|---|---|
| `base_event_type` | 要监听的基类脚本类型。 |
| `listener` | 事件监听器契约。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |

<a id="member-gfnodestate-methods-unregister_assignable_event"></a>

### `unregister_assignable_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_assignable_event(base_event_type: Script, listener: GFEventListener) -> void:
```

注销可赋值类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `base_event_type` | 注册时使用的基类脚本类型。 |
| `listener` | 要移除的事件监听器契约。 |

<a id="member-gfnodestate-methods-register_simple_event"></a>

### `register_simple_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_simple_event(event_id: StringName, listener: GFEventListener) -> void:
```

注册轻量级 StringName 事件监听器，默认以当前状态作为 owner。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `listener` | 简单事件监听器契约。 |

<a id="member-gfnodestate-methods-unregister_simple_event"></a>

### `unregister_simple_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_simple_event(event_id: StringName, listener: GFEventListener) -> void:
```

注销轻量级 StringName 事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `listener` | 要移除的简单事件监听器契约。 |

<a id="member-gfnodestate-methods-unregister_owner_events"></a>

### `unregister_owner_events`

- API：`public`

```gdscript
func unregister_owner_events() -> void:
```

注销当前状态通过事件代理注册过的全部监听器。

<a id="member-gfnodestate-methods-_initialize"></a>

### `_initialize`

- API：`protected`

```gdscript
func _initialize() -> void:
```

状态初始化扩展点。

<a id="member-gfnodestate-methods-_can_enter"></a>

### `_can_enter`

- API：`protected`

```gdscript
func _can_enter(_previous_state: StringName = &"", _args: Dictionary = {}) -> bool:
```

状态进入守卫扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `_previous_state` | 来源状态名。 |
| `_args` | 状态切换参数。 |

返回：允许进入返回 true。

结构：

- `_args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestate-methods-_can_exit"></a>

### `_can_exit`

- API：`protected`

```gdscript
func _can_exit(_next_state: StringName = &"", _args: Dictionary = {}) -> bool:
```

状态退出守卫扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `_next_state` | 目标状态名。 |
| `_args` | 状态切换参数。 |

返回：允许退出返回 true。

结构：

- `_args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestate-methods-_enter"></a>

### `_enter`

- API：`protected`

```gdscript
func _enter(_previous_state: StringName = &"", _args: Dictionary = {}) -> void:
```

状态进入扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `_previous_state` | 来源状态名。 |
| `_args` | 状态切换参数。 |

结构：

- `_args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestate-methods-_exit"></a>

### `_exit`

- API：`protected`

```gdscript
func _exit(_next_state: StringName = &"", _args: Dictionary = {}) -> void:
```

状态退出扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `_next_state` | 目标状态名。 |
| `_args` | 状态切换参数。 |

结构：

- `_args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestate-methods-_pause"></a>

### `_pause`

- API：`protected`

```gdscript
func _pause(_next_state: StringName = &"", _args: Dictionary = {}) -> void:
```

状态被栈式子状态覆盖时的扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `_next_state` | 目标状态名。 |
| `_args` | 状态切换参数。 |

结构：

- `_args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestate-methods-_resume"></a>

### `_resume`

- API：`protected`

```gdscript
func _resume(_previous_state: StringName = &"", _args: Dictionary = {}) -> void:
```

状态从栈式子状态恢复时的扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `_previous_state` | 来源状态名。 |
| `_args` | 状态切换参数。 |

结构：

- `_args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestate-methods-_handle_state_event"></a>

### `_handle_state_event`

- API：`protected`

```gdscript
func _handle_state_event(_event_id: StringName, _payload: Variant = null) -> bool:
```

状态事件处理扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `_event_id` | 状态事件标识。 |
| `_payload` | 状态事件载荷。 |

返回：已处理返回 true。

结构：

- `_payload`: 状态事件载荷；具体结构由 _event_id 和项目逻辑约定。
