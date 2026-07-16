# GFState

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/state_machine/pure/gf_state.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

纯代码状态机的状态抽象基类。 继承自 RefCounted，不依赖 Node 树，可在任何逻辑层使用。 通过持有对所属 GFStateMachine 的弱引用，间接访问框架的 Model、System、Utility 层，实现状态与框架的解耦。 子类必须重写 enter()、update()、exit() 以实现具体状态逻辑。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`enter`](#member-gfstate-methods-enter) | `func enter(_msg: Dictionary = {}) -> void:` |
| 方法 | [`update`](#member-gfstate-methods-update) | `func update(_delta: float) -> void:` |
| 方法 | [`exit`](#member-gfstate-methods-exit) | `func exit() -> void:` |
| 方法 | [`get_state_name`](#member-gfstate-methods-get_state_name) | `func get_state_name() -> StringName:` |
| 方法 | [`can_enter`](#member-gfstate-methods-can_enter) | `func can_enter(_previous_state: StringName = &"", _msg: Dictionary = {}) -> bool:` |
| 方法 | [`can_exit`](#member-gfstate-methods-can_exit) | `func can_exit(_next_state: StringName = &"", _msg: Dictionary = {}) -> bool:` |
| 方法 | [`handle_state_event`](#member-gfstate-methods-handle_state_event) | `func handle_state_event(_event_id: StringName, _payload: Variant = null) -> bool:` |
| 方法 | [`get_model`](#member-gfstate-methods-get_model) | `func get_model(model_type: Script) -> Object:` |
| 方法 | [`get_system`](#member-gfstate-methods-get_system) | `func get_system(system_type: Script) -> Object:` |
| 方法 | [`get_utility`](#member-gfstate-methods-get_utility) | `func get_utility(utility_type: Script) -> Object:` |
| 方法 | [`send_command`](#member-gfstate-methods-send_command) | `func send_command(command: Object) -> Variant:` |
| 方法 | [`send_query`](#member-gfstate-methods-send_query) | `func send_query(query: Object) -> Variant:` |
| 方法 | [`send_event`](#member-gfstate-methods-send_event) | `func send_event(event_instance: Object) -> void:` |
| 方法 | [`send_simple_event`](#member-gfstate-methods-send_simple_event) | `func send_simple_event(event_id: StringName, payload: Variant = null) -> void:` |
| 方法 | [`register_event`](#member-gfstate-methods-register_event) | `func register_event(event_type: Script, listener: GFEventListener, priority: int = 0) -> void:` |
| 方法 | [`unregister_event`](#member-gfstate-methods-unregister_event) | `func unregister_event(event_type: Script, listener: GFEventListener) -> void:` |
| 方法 | [`register_assignable_event`](#member-gfstate-methods-register_assignable_event) | `func register_assignable_event(base_event_type: Script, listener: GFEventListener, priority: int = 0) -> void:` |
| 方法 | [`unregister_assignable_event`](#member-gfstate-methods-unregister_assignable_event) | `func unregister_assignable_event(base_event_type: Script, listener: GFEventListener) -> void:` |
| 方法 | [`register_simple_event`](#member-gfstate-methods-register_simple_event) | `func register_simple_event(event_id: StringName, listener: GFEventListener) -> void:` |
| 方法 | [`unregister_simple_event`](#member-gfstate-methods-unregister_simple_event) | `func unregister_simple_event(event_id: StringName, listener: GFEventListener) -> void:` |
| 方法 | [`unregister_owner_events`](#member-gfstate-methods-unregister_owner_events) | `func unregister_owner_events() -> void:` |
| 方法 | [`change_state`](#member-gfstate-methods-change_state) | `func change_state(state_name: StringName, msg: Dictionary = {}) -> void:` |
| 方法 | [`dispatch_state_event`](#member-gfstate-methods-dispatch_state_event) | `func dispatch_state_event(event_id: StringName, payload: Variant = null) -> bool:` |
| 方法 | [`get_parent_state_name`](#member-gfstate-methods-get_parent_state_name) | `func get_parent_state_name() -> StringName:` |
| 方法 | [`is_in_state`](#member-gfstate-methods-is_in_state) | `func is_in_state(state_name: StringName) -> bool:` |
| 方法 | [`get_blackboard`](#member-gfstate-methods-get_blackboard) | `func get_blackboard() -> Dictionary:` |

## 方法

<a id="member-gfstate-methods-enter"></a>

### `enter`

- API：`public`

```gdscript
func enter(_msg: Dictionary = {}) -> void:
```

进入此状态时调用。子类可重写以执行进入逻辑（如初始化动画）。

参数：

| 名称 | 说明 |
|---|---|
| `_msg` | 从上一个状态或调用方传递过来的可选参数字典。 |

结构：

- `_msg`: Dictionary state transition payload.

<a id="member-gfstate-methods-update"></a>

### `update`

- API：`public`

```gdscript
func update(_delta: float) -> void:
```

每帧更新时调用，用于处理持续性逻辑（如计时、轮询）。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 上一帧的时间间隔（秒）。 |

<a id="member-gfstate-methods-exit"></a>

### `exit`

- API：`public`

```gdscript
func exit() -> void:
```

退出此状态时调用。子类可重写以执行清理逻辑（如停止动画）。

<a id="member-gfstate-methods-get_state_name"></a>

### `get_state_name`

- API：`public`

```gdscript
func get_state_name() -> StringName:
```

获取该状态在状态机中的注册名。

返回：注册名；未加入状态机时为空 StringName。

<a id="member-gfstate-methods-can_enter"></a>

### `can_enter`

- API：`public`

```gdscript
func can_enter(_previous_state: StringName = &"", _msg: Dictionary = {}) -> bool:
```

判断是否允许进入状态。用于 GFStateMachine 分层切换守卫。

参数：

| 名称 | 说明 |
|---|---|
| `_previous_state` | 来源叶子状态名。 |
| `_msg` | 状态切换参数。 |

返回：允许进入返回 true。

结构：

- `_msg`: Dictionary state transition payload.

<a id="member-gfstate-methods-can_exit"></a>

### `can_exit`

- API：`public`

```gdscript
func can_exit(_next_state: StringName = &"", _msg: Dictionary = {}) -> bool:
```

判断是否允许离开状态。用于 GFStateMachine 分层切换守卫。

参数：

| 名称 | 说明 |
|---|---|
| `_next_state` | 目标叶子状态名。 |
| `_msg` | 状态切换参数。 |

返回：允许离开返回 true。

结构：

- `_msg`: Dictionary state transition payload.

<a id="member-gfstate-methods-handle_state_event"></a>

### `handle_state_event`

- API：`public`

```gdscript
func handle_state_event(_event_id: StringName, _payload: Variant = null) -> bool:
```

处理状态事件。返回 false 时事件会继续向父状态上抛。

参数：

| 名称 | 说明 |
|---|---|
| `_event_id` | 状态事件标识。 |
| `_payload` | 状态事件载荷。 |

返回：已处理返回 true。

结构：

- `_payload`: Variant state event payload.

<a id="member-gfstate-methods-get_model"></a>

### `get_model`

- API：`public`

```gdscript
func get_model(model_type: Script) -> Object:
```

获取框架内的 Model 实例（委托给所属状态机）。

参数：

| 名称 | 说明 |
|---|---|
| `model_type` | 模型的脚本类型。 |

返回：模型实例。

<a id="member-gfstate-methods-get_system"></a>

### `get_system`

- API：`public`

```gdscript
func get_system(system_type: Script) -> Object:
```

获取框架内的 System 实例（委托给所属状态机）。

参数：

| 名称 | 说明 |
|---|---|
| `system_type` | 系统的脚本类型。 |

返回：系统实例。

<a id="member-gfstate-methods-get_utility"></a>

### `get_utility`

- API：`public`

```gdscript
func get_utility(utility_type: Script) -> Object:
```

获取框架内的 Utility 实例（委托给所属状态机）。

参数：

| 名称 | 说明 |
|---|---|
| `utility_type` | 工具的脚本类型。 |

返回：工具实例。

<a id="member-gfstate-methods-send_command"></a>

### `send_command`

- API：`public`

```gdscript
func send_command(command: Object) -> Variant:
```

向框架发送命令（委托给所属状态机）。

参数：

| 名称 | 说明 |
|---|---|
| `command` | 要发送的命令实例。 |

返回：命令执行结果；未绑定状态机时返回 null。

结构：

- `return`: Variant command result, Signal, or null.

<a id="member-gfstate-methods-send_query"></a>

### `send_query`

- API：`public`

```gdscript
func send_query(query: Object) -> Variant:
```

向框架发送查询（委托给所属状态机）。

参数：

| 名称 | 说明 |
|---|---|
| `query` | 要发送的查询实例。 |

返回：查询结果；未绑定状态机时返回 null。

结构：

- `return`: Variant query result or null.

<a id="member-gfstate-methods-send_event"></a>

### `send_event`

- API：`public`

```gdscript
func send_event(event_instance: Object) -> void:
```

发送类型事件（委托给所属状态机）。

参数：

| 名称 | 说明 |
|---|---|
| `event_instance` | 要分发的事件实例。 |

<a id="member-gfstate-methods-send_simple_event"></a>

### `send_simple_event`

- API：`public`

```gdscript
func send_simple_event(event_id: StringName, payload: Variant = null) -> void:
```

发送轻量级 StringName 事件（委托给所属状态机）。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | StringName 事件标识符。 |
| `payload` | 可选的事件附加数据。 |

结构：

- `payload`: Variant event payload.

<a id="member-gfstate-methods-register_event"></a>

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

<a id="member-gfstate-methods-unregister_event"></a>

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

<a id="member-gfstate-methods-register_assignable_event"></a>

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

<a id="member-gfstate-methods-unregister_assignable_event"></a>

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

<a id="member-gfstate-methods-register_simple_event"></a>

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

<a id="member-gfstate-methods-unregister_simple_event"></a>

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

<a id="member-gfstate-methods-unregister_owner_events"></a>

### `unregister_owner_events`

- API：`public`

```gdscript
func unregister_owner_events() -> void:
```

注销当前状态通过事件代理注册过的全部监听器。

<a id="member-gfstate-methods-change_state"></a>

### `change_state`

- API：`public`

```gdscript
func change_state(state_name: StringName, msg: Dictionary = {}) -> void:
```

请求状态机切换到指定状态。

参数：

| 名称 | 说明 |
|---|---|
| `state_name` | 目标状态的注册名。 |
| `msg` | 传递给目标状态 enter() 的可选参数字典。 |

结构：

- `msg`: Dictionary state transition payload.

<a id="member-gfstate-methods-dispatch_state_event"></a>

### `dispatch_state_event`

- API：`public`

```gdscript
func dispatch_state_event(event_id: StringName, payload: Variant = null) -> bool:
```

从所属状态机派发状态事件。

参数：

| 名称 | 说明 |
|---|---|
| `event_id` | 状态事件标识。 |
| `payload` | 状态事件载荷。 |

返回：有状态处理该事件时返回 true。

结构：

- `payload`: Variant state event payload.

<a id="member-gfstate-methods-get_parent_state_name"></a>

### `get_parent_state_name`

- API：`public`

```gdscript
func get_parent_state_name() -> StringName:
```

获取当前状态在所属状态机中的父状态名。

返回：父状态名；未绑定状态机或没有父级时返回空 StringName。

<a id="member-gfstate-methods-is_in_state"></a>

### `is_in_state`

- API：`public`

```gdscript
func is_in_state(state_name: StringName) -> bool:
```

判断指定状态是否在所属状态机当前激活路径中。

参数：

| 名称 | 说明 |
|---|---|
| `state_name` | 要查询的状态名。 |

返回：处于激活路径中返回 true。

<a id="member-gfstate-methods-get_blackboard"></a>

### `get_blackboard`

- API：`public`

```gdscript
func get_blackboard() -> Dictionary:
```

获取所属状态机共享黑板。

返回：黑板字典；未绑定状态机时返回空字典。

结构：

- `return`: Dictionary shared blackboard.
