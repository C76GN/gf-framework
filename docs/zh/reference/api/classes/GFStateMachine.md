# GFStateMachine

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/state_machine/pure/gf_state_machine.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

纯代码分层有限状态机。 继承自 RefCounted，不依赖 Node 树，可在 GFSystem 或 GFUtility 中直接持有。 支持平铺 FSM，也支持通过 parent_state_name 组成父子状态层级；切换时会 按最近公共祖先执行退出/进入链，并允许事件从当前叶子状态向父状态上抛。 context 通常是拥有它的 GFSystem/GFUtility 实例，仅用于生命周期守卫； 未传入 context 时，状态机仍可通过全局 Gf 访问框架依赖。 使用示例： var _fsm := GFStateMachine.new(self) _fsm.add_state(&"Grounded", GroundedState.new()) _fsm.add_state(&"Idle", IdleState.new(), &"Grounded") _fsm.add_state(&"Run", RunState.new(), &"Grounded") _fsm.start(&"Idle")

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`state_changed`](#member-gfstatemachine-signals-state_changed) | `signal state_changed(from_state: StringName, to_state: StringName)` |
| 信号 | [`transition_blocked`](#member-gfstatemachine-signals-transition_blocked) | `signal transition_blocked(from_state: StringName, to_state: StringName, msg: Dictionary, reason: StringName)` |
| 信号 | [`state_event_handled`](#member-gfstatemachine-signals-state_event_handled) | `signal state_event_handled(event_id: StringName, handler_state: StringName, payload: Variant)` |
| 属性 | [`current_state_name`](#member-gfstatemachine-properties-current_state_name) | `var current_state_name: StringName = &""` |
| 属性 | [`blackboard`](#member-gfstatemachine-properties-blackboard) | `var blackboard: Dictionary = {}` |
| 方法 | [`_init`](#member-gfstatemachine-methods-_init) | `func _init(context: Object = null) -> void:` |
| 方法 | [`add_state`](#member-gfstatemachine-methods-add_state) | `func add_state(state_name: StringName, state: GFState, parent_state_name: StringName = &"") -> void:` |
| 方法 | [`set_state_parent`](#member-gfstatemachine-methods-set_state_parent) | `func set_state_parent(state_name: StringName, parent_state_name: StringName = &"") -> bool:` |
| 方法 | [`start`](#member-gfstatemachine-methods-start) | `func start(initial_state_name: StringName, msg: Dictionary = {}, emit_changed: bool = true) -> void:` |
| 方法 | [`change_state`](#member-gfstatemachine-methods-change_state) | `func change_state(state_name: StringName, msg: Dictionary = {}) -> void:` |
| 方法 | [`update`](#member-gfstatemachine-methods-update) | `func update(delta: float, include_ancestors: bool = false) -> void:` |
| 方法 | [`dispatch_state_event`](#member-gfstatemachine-methods-dispatch_state_event) | `func dispatch_state_event(event_id: StringName, payload: Variant = null) -> bool:` |
| 方法 | [`stop`](#member-gfstatemachine-methods-stop) | `func stop() -> void:` |
| 方法 | [`dispose`](#member-gfstatemachine-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`get_state`](#member-gfstatemachine-methods-get_state) | `func get_state(state_name: StringName) -> GFState:` |
| 方法 | [`get_current_state`](#member-gfstatemachine-methods-get_current_state) | `func get_current_state() -> GFState:` |
| 方法 | [`has_state`](#member-gfstatemachine-methods-has_state) | `func has_state(state_name: StringName) -> bool:` |
| 方法 | [`get_state_names`](#member-gfstatemachine-methods-get_state_names) | `func get_state_names() -> Array[StringName]:` |
| 方法 | [`get_parent_state_name`](#member-gfstatemachine-methods-get_parent_state_name) | `func get_parent_state_name(state_name: StringName) -> StringName:` |
| 方法 | [`get_active_state_path`](#member-gfstatemachine-methods-get_active_state_path) | `func get_active_state_path() -> Array[StringName]:` |
| 方法 | [`is_in_state`](#member-gfstatemachine-methods-is_in_state) | `func is_in_state(state_name: StringName) -> bool:` |
| 方法 | [`get_blackboard`](#member-gfstatemachine-methods-get_blackboard) | `func get_blackboard() -> Dictionary:` |
| 方法 | [`get_state_snapshot`](#member-gfstatemachine-methods-get_state_snapshot) | `func get_state_snapshot() -> Dictionary:` |
| 方法 | [`get_model`](#member-gfstatemachine-methods-get_model) | `func get_model(model_type: Script) -> Object:` |
| 方法 | [`get_system`](#member-gfstatemachine-methods-get_system) | `func get_system(system_type: Script) -> Object:` |
| 方法 | [`get_utility`](#member-gfstatemachine-methods-get_utility) | `func get_utility(utility_type: Script) -> Object:` |
| 方法 | [`send_command`](#member-gfstatemachine-methods-send_command) | `func send_command(command: Object) -> Variant:` |
| 方法 | [`send_query`](#member-gfstatemachine-methods-send_query) | `func send_query(query: Object) -> Variant:` |
| 方法 | [`send_event`](#member-gfstatemachine-methods-send_event) | `func send_event(event_instance: Object) -> void:` |
| 方法 | [`send_simple_event`](#member-gfstatemachine-methods-send_simple_event) | `func send_simple_event(event_id: StringName, payload: Variant = null) -> void:` |
| 方法 | [`register_event_owned`](#member-gfstatemachine-methods-register_event_owned) | `func register_event_owned(owner: Object, event_type: Script, callback: Callable, priority: int = 0) -> void:` |
| 方法 | [`unregister_event`](#member-gfstatemachine-methods-unregister_event) | `func unregister_event(event_type: Script, callback: Callable, owner: Object = null) -> void:` |
| 方法 | [`register_assignable_event_owned`](#member-gfstatemachine-methods-register_assignable_event_owned) | `func register_assignable_event_owned( owner: Object, base_event_type: Script, callback: Callable, priority: int = 0 ) -> void:` |
| 方法 | [`unregister_assignable_event`](#member-gfstatemachine-methods-unregister_assignable_event) | `func unregister_assignable_event(base_event_type: Script, callback: Callable, owner: Object = null) -> void:` |
| 方法 | [`register_simple_event_owned`](#member-gfstatemachine-methods-register_simple_event_owned) | `func register_simple_event_owned(owner: Object, event_id: StringName, callback: Callable) -> void:` |
| 方法 | [`unregister_simple_event`](#member-gfstatemachine-methods-unregister_simple_event) | `func unregister_simple_event(event_id: StringName, callback: Callable, owner: Object = null) -> void:` |
| 方法 | [`unregister_owner_events`](#member-gfstatemachine-methods-unregister_owner_events) | `func unregister_owner_events(owner: Object) -> void:` |

## 信号

<a id="member-gfstatemachine-signals-state_changed"></a>

### `state_changed`

- API：`public`

```gdscript
signal state_changed(from_state: StringName, to_state: StringName)
```

当状态成功切换后发出。

参数：

| 名称 | 说明 |
|---|---|
| `from_state` | 离开的叶子状态名，初始切换时为空字符串。 |
| `to_state` | 进入的新叶子状态名。 |

<a id="member-gfstatemachine-signals-transition_blocked"></a>

### `transition_blocked`

- API：`public`

```gdscript
signal transition_blocked(from_state: StringName, to_state: StringName, msg: Dictionary, reason: StringName)
```

当状态守卫阻止切换时发出。

参数：

| 名称 | 说明 |
|---|---|
| `from_state` | 当前叶子状态名。 |
| `to_state` | 请求进入的目标叶子状态名。 |
| `msg` | 状态切换参数。 |
| `reason` | 阻止原因，常见为 exit_guard 或 enter_guard。 |

结构：

- `msg`: Dictionary state transition payload.

<a id="member-gfstatemachine-signals-state_event_handled"></a>

### `state_event_handled`

- API：`public`

```gdscript
signal state_event_handled(event_id: StringName, handler_state: StringName, payload: Variant)
```

当状态事件被某个激活状态处理后发出。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 状态事件标识。 |
| `handler_state` | 处理该事件的状态名。 |
| `payload` | 状态事件载荷。 |

结构：

- `payload`: Variant state event payload.

## 属性

<a id="member-gfstatemachine-properties-current_state_name"></a>

### `current_state_name`

- API：`public`

```gdscript
var current_state_name: StringName = &""
```

当前激活的叶子状态注册名。

<a id="member-gfstatemachine-properties-blackboard"></a>

### `blackboard`

- API：`public`

```gdscript
var blackboard: Dictionary = {}
```

状态机共享黑板。框架不解释其中字段。

结构：

- `blackboard`: Dictionary shared state machine data.

## 方法

<a id="member-gfstatemachine-methods-_init"></a>

### `_init`

- API：`public`

```gdscript
func _init(context: Object = null) -> void:
```

创建状态机并注入框架上下文。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 可选上下文对象，用于守卫 get_model/get_system/get_utility 调用。 |

<a id="member-gfstatemachine-methods-add_state"></a>

### `add_state`

- API：`public`

```gdscript
func add_state(state_name: StringName, state: GFState, parent_state_name: StringName = &"") -> void:
```

注册一个状态。注册后，状态机会自动注入自身引用。

参数：

| 名称 | 说明 |
|---|---|
| `state_name` | 用于标识和切换该状态的唯一名称。 |
| `state` | GFState 实例。 |
| `parent_state_name` | 可选父状态名；为空表示根状态。 |

<a id="member-gfstatemachine-methods-set_state_parent"></a>

### `set_state_parent`

- API：`public`

```gdscript
func set_state_parent(state_name: StringName, parent_state_name: StringName = &"") -> bool:
```

设置已注册状态的父状态。

参数：

| 名称 | 说明 |
|---|---|
| `state_name` | 要调整父级的状态名。 |
| `parent_state_name` | 新父状态名；为空表示根状态。 |

返回：设置成功返回 true。

<a id="member-gfstatemachine-methods-start"></a>

### `start`

- API：`public`

```gdscript
func start(initial_state_name: StringName, msg: Dictionary = {}, emit_changed: bool = true) -> void:
```

启动状态机并进入初始状态。

参数：

| 名称 | 说明 |
|---|---|
| `initial_state_name` | 首个要进入的状态名。 |
| `msg` | 传递给初始状态 enter() 的可选参数字典。 |
| `emit_changed` | 是否发出 state_changed 信号；默认为 true，from_state 为空字符串。 |

结构：

- `msg`: Dictionary state transition payload.

<a id="member-gfstatemachine-methods-change_state"></a>

### `change_state`

- API：`public`

```gdscript
func change_state(state_name: StringName, msg: Dictionary = {}) -> void:
```

切换到指定状态。分层状态会按最近公共祖先执行退出/进入链。

参数：

| 名称 | 说明 |
|---|---|
| `state_name` | 目标状态的注册名。 |
| `msg` | 传递给目标状态 enter() 的可选参数字典。 |

结构：

- `msg`: Dictionary state transition payload.

<a id="member-gfstatemachine-methods-update"></a>

### `update`

- API：`public`

```gdscript
func update(delta: float, include_ancestors: bool = false) -> void:
```

驱动当前状态的 update() 逻辑，应在宿主的 _process() 中调用。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 上一帧的时间间隔（秒）。 |
| `include_ancestors` | 为 true 时按 root -> leaf 顺序更新整条激活路径。 |

<a id="member-gfstatemachine-methods-dispatch_state_event"></a>

### `dispatch_state_event`

- API：`public`

```gdscript
func dispatch_state_event(event_id: StringName, payload: Variant = null) -> bool:
```

从当前叶子状态开始向父状态上抛事件，直到某个状态返回 true。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 状态事件标识。 |
| `payload` | 状态事件载荷。 |

返回：有状态处理该事件时返回 true。

结构：

- `payload`: Variant state event payload.

<a id="member-gfstatemachine-methods-stop"></a>

### `stop`

- API：`public`

```gdscript
func stop() -> void:
```

停止状态机，按 leaf -> root 顺序调用当前激活路径的 exit() 并清空状态。

<a id="member-gfstatemachine-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放状态机持有的所有引用，避免 RefCounted 环状引用。

<a id="member-gfstatemachine-methods-get_state"></a>

### `get_state`

- API：`public`

```gdscript
func get_state(state_name: StringName) -> GFState:
```

获取状态实例。

参数：

| 名称 | 说明 |
|---|---|
| `state_name` | 要查询的状态名。 |

返回：已注册状态实例；不存在时返回 null。

<a id="member-gfstatemachine-methods-get_current_state"></a>

### `get_current_state`

- API：`public`

```gdscript
func get_current_state() -> GFState:
```

获取当前叶子状态实例。

返回：当前叶子状态；未启动时返回 null。

<a id="member-gfstatemachine-methods-has_state"></a>

### `has_state`

- API：`public`

```gdscript
func has_state(state_name: StringName) -> bool:
```

判断状态是否已注册。

参数：

| 名称 | 说明 |
|---|---|
| `state_name` | 要查询的状态名。 |

返回：已注册返回 true。

<a id="member-gfstatemachine-methods-get_state_names"></a>

### `get_state_names`

- API：`public`

```gdscript
func get_state_names() -> Array[StringName]:
```

获取已注册状态名列表。

返回：状态名列表副本。

<a id="member-gfstatemachine-methods-get_parent_state_name"></a>

### `get_parent_state_name`

- API：`public`

```gdscript
func get_parent_state_name(state_name: StringName) -> StringName:
```

获取指定状态的父状态名。

参数：

| 名称 | 说明 |
|---|---|
| `state_name` | 要查询的状态名。 |

返回：父状态名；没有父级或状态不存在时返回空 StringName。

<a id="member-gfstatemachine-methods-get_active_state_path"></a>

### `get_active_state_path`

- API：`public`

```gdscript
func get_active_state_path() -> Array[StringName]:
```

获取当前激活状态路径，按 root -> leaf 排列。

返回：激活状态路径副本。

<a id="member-gfstatemachine-methods-is_in_state"></a>

### `is_in_state`

- API：`public`

```gdscript
func is_in_state(state_name: StringName) -> bool:
```

判断指定状态是否在当前激活路径中。

参数：

| 名称 | 说明 |
|---|---|
| `state_name` | 要查询的状态名。 |

返回：处于当前激活路径中返回 true。

<a id="member-gfstatemachine-methods-get_blackboard"></a>

### `get_blackboard`

- API：`public`

```gdscript
func get_blackboard() -> Dictionary:
```

获取共享黑板。

返回：状态机黑板字典。

结构：

- `return`: Dictionary shared blackboard.

<a id="member-gfstatemachine-methods-get_state_snapshot"></a>

### `get_state_snapshot`

- API：`public`

```gdscript
func get_state_snapshot() -> Dictionary:
```

获取状态机调试快照。

返回：包含当前状态、激活路径、父子关系和黑板副本的字典。

结构：

- `return`: Dictionary with current_state, active_path, states, parents, and blackboard.

<a id="member-gfstatemachine-methods-get_model"></a>

### `get_model`

- API：`public`

```gdscript
func get_model(model_type: Script) -> Object:
```

代理获取框架内的 Model 实例。

参数：

| 名称 | 说明 |
|---|---|
| `model_type` | 模型的脚本类型。 |

返回：模型实例，若上下文或架构无效则返回 null。

<a id="member-gfstatemachine-methods-get_system"></a>

### `get_system`

- API：`public`

```gdscript
func get_system(system_type: Script) -> Object:
```

代理获取框架内的 System 实例。

参数：

| 名称 | 说明 |
|---|---|
| `system_type` | 系统的脚本类型。 |

返回：系统实例，若上下文或架构无效则返回 null。

<a id="member-gfstatemachine-methods-get_utility"></a>

### `get_utility`

- API：`public`

```gdscript
func get_utility(utility_type: Script) -> Object:
```

代理获取框架内的 Utility 实例。

参数：

| 名称 | 说明 |
|---|---|
| `utility_type` | 工具的脚本类型。 |

返回：工具实例，若上下文或架构无效则返回 null。

<a id="member-gfstatemachine-methods-send_command"></a>

### `send_command`

- API：`public`

```gdscript
func send_command(command: Object) -> Variant:
```

代理向框架发送命令。

参数：

| 名称 | 说明 |
|---|---|
| `command` | 要发送的命令实例。 |

返回：命令执行结果；上下文或架构无效时返回 null。

结构：

- `return`: Variant command result, Signal, or null.

<a id="member-gfstatemachine-methods-send_query"></a>

### `send_query`

- API：`public`

```gdscript
func send_query(query: Object) -> Variant:
```

代理向框架发送查询。

参数：

| 名称 | 说明 |
|---|---|
| `query` | 要发送的查询实例。 |

返回：查询结果；上下文或架构无效时返回 null。

结构：

- `return`: Variant query result or null.

<a id="member-gfstatemachine-methods-send_event"></a>

### `send_event`

- API：`public`

```gdscript
func send_event(event_instance: Object) -> void:
```

代理发送类型事件。

参数：

| 名称 | 说明 |
|---|---|
| `event_instance` | 要分发的事件实例。 |

<a id="member-gfstatemachine-methods-send_simple_event"></a>

### `send_simple_event`

- API：`public`

```gdscript
func send_simple_event(event_id: StringName, payload: Variant = null) -> void:
```

代理发送轻量级 StringName 事件。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `payload` | 可选的事件附加数据。 |

结构：

- `payload`: Variant event payload.

<a id="member-gfstatemachine-methods-register_event_owned"></a>

### `register_event_owned`

- API：`public`

```gdscript
func register_event_owned(owner: Object, event_type: Script, callback: Callable, priority: int = 0) -> void:
```

注册带拥有者的类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 监听器拥有者。 |
| `event_type` | 要监听的脚本类型。 |
| `callback` | 回调函数。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |

<a id="member-gfstatemachine-methods-unregister_event"></a>

### `unregister_event`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unregister_event(event_type: Script, callback: Callable, owner: Object = null) -> void:
```

注销类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_type` | 要注销的脚本类型。 |
| `callback` | 要移除的回调函数。 |
| `owner` | 注册监听时使用的拥有者；为空时只注销无 owner 监听。 |

<a id="member-gfstatemachine-methods-register_assignable_event_owned"></a>

### `register_assignable_event_owned`

- API：`public`

```gdscript
func register_assignable_event_owned( owner: Object, base_event_type: Script, callback: Callable, priority: int = 0 ) -> void:
```

注册带拥有者的可赋值类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 监听器拥有者。 |
| `base_event_type` | 要监听的基类脚本类型。 |
| `callback` | 回调函数。 |
| `priority` | 回调优先级，数值越大越先执行，默认为 0。 |

<a id="member-gfstatemachine-methods-unregister_assignable_event"></a>

### `unregister_assignable_event`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unregister_assignable_event(base_event_type: Script, callback: Callable, owner: Object = null) -> void:
```

注销可赋值类型事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `base_event_type` | 注册时使用的基类脚本类型。 |
| `callback` | 要移除的回调函数。 |
| `owner` | 注册监听时使用的拥有者；为空时只注销无 owner 监听。 |

<a id="member-gfstatemachine-methods-register_simple_event_owned"></a>

### `register_simple_event_owned`

- API：`public`

```gdscript
func register_simple_event_owned(owner: Object, event_id: StringName, callback: Callable) -> void:
```

注册带拥有者的轻量级 StringName 事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 监听器拥有者。 |
| `event_id` | StringName 事件标识符。 |
| `callback` | 回调函数，签名为 func(payload: Variant)。 |

<a id="member-gfstatemachine-methods-unregister_simple_event"></a>

### `unregister_simple_event`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
func unregister_simple_event(event_id: StringName, callback: Callable, owner: Object = null) -> void:
```

注销轻量级 StringName 事件监听器。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `callback` | 要移除的回调函数。 |
| `owner` | 注册监听时使用的拥有者；为空时只注销无 owner 监听。 |

<a id="member-gfstatemachine-methods-unregister_owner_events"></a>

### `unregister_owner_events`

- API：`public`

```gdscript
func unregister_owner_events(owner: Object) -> void:
```

注销指定拥有者通过状态机事件代理注册过的全部监听器。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 要清理监听器的拥有者。 |
