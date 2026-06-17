# GFNodeStateMachine

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/state_machine/node/gf_node_state_machine.gd`
- 模块：`Standard`
- 继承：`Node`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

基于场景树的多状态组状态机。 支持直接子 GFNodeState 组成内部状态组，也支持多个 GFNodeStateGroup 并行工作。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`state_group_added`](#member-gfnodestatemachine-signals-state_group_added) | `signal state_group_added(group: GFNodeStateGroup)` |
| 信号 | [`state_group_removed`](#member-gfnodestatemachine-signals-state_group_removed) | `signal state_group_removed(group: GFNodeStateGroup)` |
| 信号 | [`state_changed`](#member-gfnodestatemachine-signals-state_changed) | `signal state_changed(group: GFNodeStateGroup, old_state: GFNodeState, new_state: GFNodeState)` |
| 信号 | [`state_event_handled`](#member-gfnodestatemachine-signals-state_event_handled) | `signal state_event_handled(group: GFNodeStateGroup, event_id: StringName, handler_state: GFNodeState, payload: Variant)` |
| 枚举 | [`StartMode`](#member-gfnodestatemachine-enums-startmode) | `enum StartMode` |
| 常量 | [`INTERNAL_GROUP_NAME`](#member-gfnodestatemachine-constants-internal_group_name) | `const INTERNAL_GROUP_NAME: StringName = &"_internal"` |
| 属性 | [`config`](#member-gfnodestatemachine-properties-config) | `var config: GFNodeStateMachineConfig = null:` |
| 属性 | [`initial_state`](#member-gfnodestatemachine-properties-initial_state) | `var initial_state: StringName = &"":` |
| 属性 | [`initial_args`](#member-gfnodestatemachine-properties-initial_args) | `var initial_args: Dictionary = {}` |
| 属性 | [`reload_on_ready`](#member-gfnodestatemachine-properties-reload_on_ready) | `var reload_on_ready: bool = true` |
| 属性 | [`start_mode`](#member-gfnodestatemachine-properties-start_mode) | `var start_mode: StartMode = StartMode.AFTER_HOST_READY:` |
| 属性 | [`preserve_current_state_on_reload`](#member-gfnodestatemachine-properties-preserve_current_state_on_reload) | `var preserve_current_state_on_reload: bool = true` |
| 方法 | [`transition_to`](#member-gfnodestatemachine-methods-transition_to) | `func transition_to(path: StringName, args: Dictionary = {}) -> void:` |
| 方法 | [`transition_group_to`](#member-gfnodestatemachine-methods-transition_group_to) | `func transition_group_to(group_name: StringName, state_name: StringName, args: Dictionary = {}) -> void:` |
| 方法 | [`push_state`](#member-gfnodestatemachine-methods-push_state) | `func push_state(path: StringName, args: Dictionary = {}) -> void:` |
| 方法 | [`push_group_state`](#member-gfnodestatemachine-methods-push_group_state) | `func push_group_state(group_name: StringName, state_name: StringName, args: Dictionary = {}) -> void:` |
| 方法 | [`pop_state`](#member-gfnodestatemachine-methods-pop_state) | `func pop_state(group_name: StringName = INTERNAL_GROUP_NAME, args: Dictionary = {}) -> bool:` |
| 方法 | [`start`](#member-gfnodestatemachine-methods-start) | `func start(args: Dictionary = {}) -> void:` |
| 方法 | [`start_group`](#member-gfnodestatemachine-methods-start_group) | `func start_group(group_name: StringName = INTERNAL_GROUP_NAME, args: Dictionary = {}) -> void:` |
| 方法 | [`add_state_group`](#member-gfnodestatemachine-methods-add_state_group) | `func add_state_group(group: GFNodeStateGroup) -> void:` |
| 方法 | [`remove_state_group`](#member-gfnodestatemachine-methods-remove_state_group) | `func remove_state_group(group: GFNodeStateGroup) -> bool:` |
| 方法 | [`get_state_group`](#member-gfnodestatemachine-methods-get_state_group) | `func get_state_group(group_name: StringName) -> GFNodeStateGroup:` |
| 方法 | [`get_current_state`](#member-gfnodestatemachine-methods-get_current_state) | `func get_current_state() -> GFNodeState:` |
| 方法 | [`get_current_group_state`](#member-gfnodestatemachine-methods-get_current_group_state) | `func get_current_group_state(group_name: StringName = INTERNAL_GROUP_NAME) -> GFNodeState:` |
| 方法 | [`get_current_state_name`](#member-gfnodestatemachine-methods-get_current_state_name) | `func get_current_state_name(group_name: StringName = INTERNAL_GROUP_NAME) -> StringName:` |
| 方法 | [`get_state_history`](#member-gfnodestatemachine-methods-get_state_history) | `func get_state_history(group_name: StringName = INTERNAL_GROUP_NAME) -> Array[StringName]:` |
| 方法 | [`get_stack_depth`](#member-gfnodestatemachine-methods-get_stack_depth) | `func get_stack_depth(group_name: StringName = INTERNAL_GROUP_NAME) -> int:` |
| 方法 | [`is_in_state`](#member-gfnodestatemachine-methods-is_in_state) | `func is_in_state(path: StringName) -> bool:` |
| 方法 | [`restart_group`](#member-gfnodestatemachine-methods-restart_group) | `func restart_group(group_name: StringName = INTERNAL_GROUP_NAME, args: Dictionary = {}) -> void:` |
| 方法 | [`dispatch_state_event`](#member-gfnodestatemachine-methods-dispatch_state_event) | `func dispatch_state_event(event_id: StringName, payload: Variant = null, group_name: StringName = &"") -> bool:` |
| 方法 | [`get_state_snapshot`](#member-gfnodestatemachine-methods-get_state_snapshot) | `func get_state_snapshot() -> Dictionary:` |
| 方法 | [`get_architecture_or_null`](#member-gfnodestatemachine-methods-get_architecture_or_null) | `func get_architecture_or_null() -> GFArchitecture:` |
| 方法 | [`get_model`](#member-gfnodestatemachine-methods-get_model) | `func get_model(model_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_system`](#member-gfnodestatemachine-methods-get_system) | `func get_system(system_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_utility`](#member-gfnodestatemachine-methods-get_utility) | `func get_utility(utility_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_model`](#member-gfnodestatemachine-methods-get_local_model) | `func get_local_model(model_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_system`](#member-gfnodestatemachine-methods-get_local_system) | `func get_local_system(system_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`get_local_utility`](#member-gfnodestatemachine-methods-get_local_utility) | `func get_local_utility(utility_type: Script, require_ready: bool = false) -> Object:` |
| 方法 | [`send_command`](#member-gfnodestatemachine-methods-send_command) | `func send_command(command: Object) -> Variant:` |
| 方法 | [`send_query`](#member-gfnodestatemachine-methods-send_query) | `func send_query(query: Object) -> Variant:` |
| 方法 | [`send_event`](#member-gfnodestatemachine-methods-send_event) | `func send_event(event_instance: Object) -> void:` |
| 方法 | [`send_simple_event`](#member-gfnodestatemachine-methods-send_simple_event) | `func send_simple_event(event_id: StringName, payload: Variant = null) -> void:` |
| 方法 | [`register_event_owned`](#member-gfnodestatemachine-methods-register_event_owned) | `func register_event_owned(listener_owner: Object, event_type: Script, callback: Callable, priority: int = 0) -> void:` |
| 方法 | [`unregister_event`](#member-gfnodestatemachine-methods-unregister_event) | `func unregister_event(event_type: Script, callback: Callable) -> void:` |
| 方法 | [`register_assignable_event_owned`](#member-gfnodestatemachine-methods-register_assignable_event_owned) | `func register_assignable_event_owned( listener_owner: Object, base_event_type: Script, callback: Callable, priority: int = 0 ) -> void:` |
| 方法 | [`unregister_assignable_event`](#member-gfnodestatemachine-methods-unregister_assignable_event) | `func unregister_assignable_event(base_event_type: Script, callback: Callable) -> void:` |
| 方法 | [`register_simple_event_owned`](#member-gfnodestatemachine-methods-register_simple_event_owned) | `func register_simple_event_owned(listener_owner: Object, event_id: StringName, callback: Callable) -> void:` |
| 方法 | [`unregister_simple_event`](#member-gfnodestatemachine-methods-unregister_simple_event) | `func unregister_simple_event(event_id: StringName, callback: Callable) -> void:` |
| 方法 | [`unregister_owner_events`](#member-gfnodestatemachine-methods-unregister_owner_events) | `func unregister_owner_events(listener_owner: Object) -> void:` |
| 方法 | [`reload_from_children`](#member-gfnodestatemachine-methods-reload_from_children) | `func reload_from_children() -> void:` |
| 方法 | [`clear_state_groups`](#member-gfnodestatemachine-methods-clear_state_groups) | `func clear_state_groups(free_groups: bool = false) -> void:` |

## 信号

<a id="member-gfnodestatemachine-signals-state_group_added"></a>

### `state_group_added`

- API：`public`

```gdscript
signal state_group_added(group: GFNodeStateGroup)
```

状态组加入后发出。

参数：

| 名称 | 说明 |
|---|---|
| `group` | 新加入的状态组。 |

<a id="member-gfnodestatemachine-signals-state_group_removed"></a>

### `state_group_removed`

- API：`public`

```gdscript
signal state_group_removed(group: GFNodeStateGroup)
```

状态组移除后发出。

参数：

| 名称 | 说明 |
|---|---|
| `group` | 被移除的状态组。 |

<a id="member-gfnodestatemachine-signals-state_changed"></a>

### `state_changed`

- API：`public`

```gdscript
signal state_changed(group: GFNodeStateGroup, old_state: GFNodeState, new_state: GFNodeState)
```

任意状态组切换状态后发出。

参数：

| 名称 | 说明 |
|---|---|
| `group` | 发生状态切换的状态组。 |
| `old_state` | 切换前的状态；没有旧状态时为 null。 |
| `new_state` | 切换后的状态；状态组停止时可为 null。 |

<a id="member-gfnodestatemachine-signals-state_event_handled"></a>

### `state_event_handled`

- API：`public`

```gdscript
signal state_event_handled(group: GFNodeStateGroup, event_id: StringName, handler_state: GFNodeState, payload: Variant)
```

任意状态组中的状态处理状态事件后发出。

参数：

| 名称 | 说明 |
|---|---|
| `group` | 处理事件的状态所属状态组。 |
| `event_id` | 状态事件标识。 |
| `handler_state` | 实际处理事件的状态节点。 |
| `payload` | 状态事件载荷。 |

结构：

- `payload`: 状态事件载荷；具体结构由 event_id 和项目逻辑约定。

## 枚举

<a id="member-gfnodestatemachine-enums-startmode"></a>

### `StartMode`

- API：`public`

```gdscript
enum StartMode {
	## 状态机 ready 时启动，适合需要旧版启动顺序的项目。
	ON_READY,
	## 等待宿主节点 ready 后启动。
	AFTER_HOST_READY,
	## 只加载状态，不自动启动；由外部调用 start()。
	MANUAL,
}
```

节点状态机初始状态启动时机。

## 常量

<a id="member-gfnodestatemachine-constants-internal_group_name"></a>

### `INTERNAL_GROUP_NAME`

- API：`public`

```gdscript
const INTERNAL_GROUP_NAME: StringName = &"_internal"
```

直接子 GFNodeState 组成的内置状态组名称。

## 属性

<a id="member-gfnodestatemachine-properties-config"></a>

### `config`

- API：`public`

```gdscript
var config: GFNodeStateMachineConfig = null:
```

可选状态机配置资源。为空时继续使用本节点上的兼容导出项。

<a id="member-gfnodestatemachine-properties-initial_state"></a>

### `initial_state`

- API：`public`

```gdscript
var initial_state: StringName = &"":
```

内部状态组初始状态名。

<a id="member-gfnodestatemachine-properties-initial_args"></a>

### `initial_args`

- API：`public`

```gdscript
var initial_args: Dictionary = {}
```

内部状态组初始状态参数。

结构：

- `initial_args`: 内部状态组初始状态参数 Dictionary；键和值由初始状态的项目逻辑约定。

<a id="member-gfnodestatemachine-properties-reload_on_ready"></a>

### `reload_on_ready`

- API：`public`

```gdscript
var reload_on_ready: bool = true
```

ready 时是否自动从子节点加载状态与状态组。

<a id="member-gfnodestatemachine-properties-start_mode"></a>

### `start_mode`

- API：`public`

```gdscript
var start_mode: StartMode = StartMode.AFTER_HOST_READY:
```

初始状态启动模式。

<a id="member-gfnodestatemachine-properties-preserve_current_state_on_reload"></a>

### `preserve_current_state_on_reload`

- API：`public`

```gdscript
var preserve_current_state_on_reload: bool = true
```

运行时重新从子节点加载时，是否尽量恢复各状态组的当前状态。

## 方法

<a id="member-gfnodestatemachine-methods-transition_to"></a>

### `transition_to`

- API：`public`

```gdscript
func transition_to(path: StringName, args: Dictionary = {}) -> void:
```

通过路径切换状态。path 可为 "State" 或 "Group/State"。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径或状态路径。 |
| `args` | 状态切换时传递的可选参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestatemachine-methods-transition_group_to"></a>

### `transition_group_to`

- API：`public`

```gdscript
func transition_group_to(group_name: StringName, state_name: StringName, args: Dictionary = {}) -> void:
```

切换指定状态组到指定状态。

参数：

| 名称 | 说明 |
|---|---|
| `group_name` | 能力组或状态组名称。 |
| `state_name` | 目标状态名称。 |
| `args` | 状态切换时传递的可选参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestatemachine-methods-push_state"></a>

### `push_state`

- API：`public`

```gdscript
func push_state(path: StringName, args: Dictionary = {}) -> void:
```

暂停当前内部状态并叠加进入一个子状态。path 可为 "State" 或 "Group/State"。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径或状态路径。 |
| `args` | 状态切换时传递的可选参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestatemachine-methods-push_group_state"></a>

### `push_group_state`

- API：`public`

```gdscript
func push_group_state(group_name: StringName, state_name: StringName, args: Dictionary = {}) -> void:
```

暂停指定状态组当前状态并叠加进入一个子状态。

参数：

| 名称 | 说明 |
|---|---|
| `group_name` | 能力组或状态组名称。 |
| `state_name` | 目标状态名称。 |
| `args` | 状态切换时传递的可选参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestatemachine-methods-pop_state"></a>

### `pop_state`

- API：`public`

```gdscript
func pop_state(group_name: StringName = INTERNAL_GROUP_NAME, args: Dictionary = {}) -> bool:
```

弹出指定状态组的栈式子状态。

参数：

| 名称 | 说明 |
|---|---|
| `group_name` | 能力组或状态组名称。 |
| `args` | 状态切换时传递的可选参数。 |

返回：成功恢复上一层状态时返回 true。

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestatemachine-methods-start"></a>

### `start`

- API：`public`

```gdscript
func start(args: Dictionary = {}) -> void:
```

启动所有已加载状态组的初始状态。若尚未加载状态，则会先从子节点加载。

参数：

| 名称 | 说明 |
|---|---|
| `args` | 启动时传给初始状态的参数；为空时使用各状态组 initial_args。 |

结构：

- `args`: 启动参数 Dictionary；为空时使用各状态组 initial_args。

<a id="member-gfnodestatemachine-methods-start_group"></a>

### `start_group`

- API：`public`

```gdscript
func start_group(group_name: StringName = INTERNAL_GROUP_NAME, args: Dictionary = {}) -> void:
```

启动指定状态组的初始状态。若尚未加载状态，则会先从子节点加载。

参数：

| 名称 | 说明 |
|---|---|
| `group_name` | 要启动的状态组名。 |
| `args` | 启动时传给初始状态的参数；为空时使用该状态组 initial_args。 |

结构：

- `args`: 启动参数 Dictionary；为空时使用该状态组 initial_args。

<a id="member-gfnodestatemachine-methods-add_state_group"></a>

### `add_state_group`

- API：`public`

```gdscript
func add_state_group(group: GFNodeStateGroup) -> void:
```

添加状态组。

参数：

| 名称 | 说明 |
|---|---|
| `group` | 所属状态组。 |

<a id="member-gfnodestatemachine-methods-remove_state_group"></a>

### `remove_state_group`

- API：`public`

```gdscript
func remove_state_group(group: GFNodeStateGroup) -> bool:
```

移除状态组。

参数：

| 名称 | 说明 |
|---|---|
| `group` | 所属状态组。 |

返回：成功移除已注册状态组时返回 true。

<a id="member-gfnodestatemachine-methods-get_state_group"></a>

### `get_state_group`

- API：`public`

```gdscript
func get_state_group(group_name: StringName) -> GFNodeStateGroup:
```

获取状态组。

参数：

| 名称 | 说明 |
|---|---|
| `group_name` | 能力组或状态组名称。 |

返回：注册名对应的状态组；不存在时返回 null。

<a id="member-gfnodestatemachine-methods-get_current_state"></a>

### `get_current_state`

- API：`public`

```gdscript
func get_current_state() -> GFNodeState:
```

获取内部状态组当前状态。

返回：内部状态组当前状态；未启动或不存在时返回 null。

<a id="member-gfnodestatemachine-methods-get_current_group_state"></a>

### `get_current_group_state`

- API：`public`

```gdscript
func get_current_group_state(group_name: StringName = INTERNAL_GROUP_NAME) -> GFNodeState:
```

获取指定状态组当前状态。

参数：

| 名称 | 说明 |
|---|---|
| `group_name` | 能力组或状态组名称。 |

返回：当前状态；未找到状态组或未启动时返回 null。

<a id="member-gfnodestatemachine-methods-get_current_state_name"></a>

### `get_current_state_name`

- API：`public`

```gdscript
func get_current_state_name(group_name: StringName = INTERNAL_GROUP_NAME) -> StringName:
```

获取指定状态组当前状态名。

参数：

| 名称 | 说明 |
|---|---|
| `group_name` | 能力组或状态组名称。 |

返回：当前状态名；未找到状态组或未启动时返回空 StringName。

<a id="member-gfnodestatemachine-methods-get_state_history"></a>

### `get_state_history`

- API：`public`

```gdscript
func get_state_history(group_name: StringName = INTERNAL_GROUP_NAME) -> Array[StringName]:
```

获取指定状态组状态历史。

参数：

| 名称 | 说明 |
|---|---|
| `group_name` | 能力组或状态组名称。 |

返回：最近进入过的状态名列表。

结构：

- `return`: 状态历史 Array[StringName]，按进入顺序排列。

<a id="member-gfnodestatemachine-methods-get_stack_depth"></a>

### `get_stack_depth`

- API：`public`

```gdscript
func get_stack_depth(group_name: StringName = INTERNAL_GROUP_NAME) -> int:
```

获取指定状态组暂停栈深度。

参数：

| 名称 | 说明 |
|---|---|
| `group_name` | 能力组或状态组名称。 |

返回：指定状态组的暂停栈深度；未找到状态组时返回 0。

<a id="member-gfnodestatemachine-methods-is_in_state"></a>

### `is_in_state`

- API：`public`

```gdscript
func is_in_state(path: StringName) -> bool:
```

判断 path 指向的状态是否为当前状态或暂停栈中的状态。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径或状态路径。 |

返回：指定状态位于当前状态或暂停栈中时返回 true。

<a id="member-gfnodestatemachine-methods-restart_group"></a>

### `restart_group`

- API：`public`

```gdscript
func restart_group(group_name: StringName = INTERNAL_GROUP_NAME, args: Dictionary = {}) -> void:
```

重启指定状态组当前状态。

参数：

| 名称 | 说明 |
|---|---|
| `group_name` | 能力组或状态组名称。 |
| `args` | 状态切换时传递的可选参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestatemachine-methods-dispatch_state_event"></a>

### `dispatch_state_event`

- API：`public`

```gdscript
func dispatch_state_event(event_id: StringName, payload: Variant = null, group_name: StringName = &"") -> bool:
```

派发状态事件。group_name 为空时会按已注册状态组顺序广播到所有组。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 状态事件标识。 |
| `payload` | 状态事件载荷。 |
| `group_name` | 可选目标状态组名；为空表示所有状态组。 |

返回：有状态处理该事件时返回 true。

结构：

- `payload`: 状态事件载荷；具体结构由 event_id 和项目逻辑约定。

<a id="member-gfnodestatemachine-methods-get_state_snapshot"></a>

### `get_state_snapshot`

- API：`public`

```gdscript
func get_state_snapshot() -> Dictionary:
```

获取节点状态机调试快照。

返回：包含所有状态组当前状态、历史、栈深度和黑板副本的字典。

结构：

- `return`: 调试快照 Dictionary，包含 groups 和 internal_group 字段；groups 的键为状态组名，值为 GFNodeStateGroup.get_state_snapshot() 返回的状态组快照。

<a id="member-gfnodestatemachine-methods-get_architecture_or_null"></a>

### `get_architecture_or_null`

- API：`public`

```gdscript
func get_architecture_or_null() -> GFArchitecture:
```

获取当前状态机可用的架构实例。

返回：架构实例；状态机未挂入可解析上下文时返回 null。

<a id="member-gfnodestatemachine-methods-get_model"></a>

### `get_model`

- API：`public`

```gdscript
func get_model(model_type: Script, require_ready: bool = false) -> Object:
```

通过当前状态机上下文获取 Model。

参数：

| 名称 | 说明 |
|---|---|
| `model_type` | 模型脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：模型实例；不可用时返回 null。

<a id="member-gfnodestatemachine-methods-get_system"></a>

### `get_system`

- API：`public`

```gdscript
func get_system(system_type: Script, require_ready: bool = false) -> Object:
```

通过当前状态机上下文获取 System。

参数：

| 名称 | 说明 |
|---|---|
| `system_type` | 系统脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：系统实例；不可用时返回 null。

<a id="member-gfnodestatemachine-methods-get_utility"></a>

### `get_utility`

- API：`public`

```gdscript
func get_utility(utility_type: Script, require_ready: bool = false) -> Object:
```

通过当前状态机上下文获取 Utility。

参数：

| 名称 | 说明 |
|---|---|
| `utility_type` | 工具脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：工具实例；不可用时返回 null。

<a id="member-gfnodestatemachine-methods-get_local_model"></a>

### `get_local_model`

- API：`public`

```gdscript
func get_local_model(model_type: Script, require_ready: bool = false) -> Object:
```

仅从当前状态机所属架构获取 Model，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `model_type` | 模型脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前架构中的模型实例；不可用时返回 null。

<a id="member-gfnodestatemachine-methods-get_local_system"></a>

### `get_local_system`

- API：`public`

```gdscript
func get_local_system(system_type: Script, require_ready: bool = false) -> Object:
```

仅从当前状态机所属架构获取 System，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `system_type` | 系统脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前架构中的系统实例；不可用时返回 null。

<a id="member-gfnodestatemachine-methods-get_local_utility"></a>

### `get_local_utility`

- API：`public`

```gdscript
func get_local_utility(utility_type: Script, require_ready: bool = false) -> Object:
```

仅从当前状态机所属架构获取 Utility，不回退父级架构。

参数：

| 名称 | 说明 |
|---|---|
| `utility_type` | 工具脚本类型。 |
| `require_ready` | 为 true 时，仅返回已完成 ready 阶段的实例。 |

返回：当前架构中的工具实例；不可用时返回 null。

<a id="member-gfnodestatemachine-methods-send_command"></a>

### `send_command`

- API：`public`

```gdscript
func send_command(command: Object) -> Variant:
```

向当前状态机上下文发送命令。

参数：

| 名称 | 说明 |
|---|---|
| `command` | 要发送的命令实例。 |

返回：命令执行结果；无可用架构时返回 null。

结构：

- `return`: 命令返回值；具体结构由 GFCommand 实现决定。

<a id="member-gfnodestatemachine-methods-send_query"></a>

### `send_query`

- API：`public`

```gdscript
func send_query(query: Object) -> Variant:
```

向当前状态机上下文发送查询。

参数：

| 名称 | 说明 |
|---|---|
| `query` | 要发送的查询实例。 |

返回：查询结果；无可用架构时返回 null。

结构：

- `return`: 查询返回值；具体结构由 GFQuery 实现决定。

<a id="member-gfnodestatemachine-methods-send_event"></a>

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

<a id="member-gfnodestatemachine-methods-send_simple_event"></a>

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

<a id="member-gfnodestatemachine-methods-register_event_owned"></a>

### `register_event_owned`

- API：`public`

```gdscript
func register_event_owned(listener_owner: Object, event_type: Script, callback: Callable, priority: int = 0) -> void:
```

注册带拥有者的类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `listener_owner` | 监听器拥有者。 |
| `event_type` | 要监听的脚本类型。 |
| `callback` | 回调函数。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |

<a id="member-gfnodestatemachine-methods-unregister_event"></a>

### `unregister_event`

- API：`public`

```gdscript
func unregister_event(event_type: Script, callback: Callable) -> void:
```

注销类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_type` | 要注销的脚本类型。 |
| `callback` | 要移除的回调函数。 |

<a id="member-gfnodestatemachine-methods-register_assignable_event_owned"></a>

### `register_assignable_event_owned`

- API：`public`

```gdscript
func register_assignable_event_owned( listener_owner: Object, base_event_type: Script, callback: Callable, priority: int = 0 ) -> void:
```

注册带拥有者的可赋值类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `listener_owner` | 监听器拥有者。 |
| `base_event_type` | 要监听的基类脚本类型。 |
| `callback` | 回调函数。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |

<a id="member-gfnodestatemachine-methods-unregister_assignable_event"></a>

### `unregister_assignable_event`

- API：`public`

```gdscript
func unregister_assignable_event(base_event_type: Script, callback: Callable) -> void:
```

注销可赋值类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `base_event_type` | 注册时使用的基类脚本类型。 |
| `callback` | 要移除的回调函数。 |

<a id="member-gfnodestatemachine-methods-register_simple_event_owned"></a>

### `register_simple_event_owned`

- API：`public`

```gdscript
func register_simple_event_owned(listener_owner: Object, event_id: StringName, callback: Callable) -> void:
```

注册带拥有者的轻量级 StringName 事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `listener_owner` | 监听器拥有者。 |
| `event_id` | StringName 事件标识符。 |
| `callback` | 回调函数，签名为 func(payload: Variant)。 |

<a id="member-gfnodestatemachine-methods-unregister_simple_event"></a>

### `unregister_simple_event`

- API：`public`

```gdscript
func unregister_simple_event(event_id: StringName, callback: Callable) -> void:
```

注销轻量级 StringName 事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `callback` | 要移除的回调函数。 |

<a id="member-gfnodestatemachine-methods-unregister_owner_events"></a>

### `unregister_owner_events`

- API：`public`

```gdscript
func unregister_owner_events(listener_owner: Object) -> void:
```

注销指定拥有者通过状态机事件代理注册过的全部监听器。

参数：

| 名称 | 说明 |
|---|---|
| `listener_owner` | 要清理监听器的拥有者。 |

<a id="member-gfnodestatemachine-methods-reload_from_children"></a>

### `reload_from_children`

- API：`public`

```gdscript
func reload_from_children() -> void:
```

从子节点重新加载状态和状态组。

<a id="member-gfnodestatemachine-methods-clear_state_groups"></a>

### `clear_state_groups`

- API：`public`

```gdscript
func clear_state_groups(free_groups: bool = false) -> void:
```

清空所有状态组。

参数：

| 名称 | 说明 |
|---|---|
| `free_groups` | 清理状态组时是否释放节点。 |
