# GFNodeStateBehavior

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/state_machine/node/gf_node_state_behavior.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

节点状态的可复用生命周期行为资源。 行为资源可挂到 GFNodeState 上复用进入、退出、暂停、恢复和事件处理逻辑。 它不替代状态脚本；状态脚本仍负责业务状态的主要控制权。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`behavior_id`](#member-gfnodestatebehavior-properties-behavior_id) | `var behavior_id: StringName = &""` |
| 属性 | [`enabled`](#member-gfnodestatebehavior-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`metadata`](#member-gfnodestatebehavior-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`initialize`](#member-gfnodestatebehavior-methods-initialize) | `func initialize(state: GFNodeState) -> void:` |
| 方法 | [`enter`](#member-gfnodestatebehavior-methods-enter) | `func enter(state: GFNodeState, previous_state: StringName = &"", args: Dictionary = {}) -> void:` |
| 方法 | [`exit`](#member-gfnodestatebehavior-methods-exit) | `func exit(state: GFNodeState, next_state: StringName = &"", args: Dictionary = {}) -> void:` |
| 方法 | [`pause`](#member-gfnodestatebehavior-methods-pause) | `func pause(state: GFNodeState, next_state: StringName = &"", args: Dictionary = {}) -> void:` |
| 方法 | [`resume`](#member-gfnodestatebehavior-methods-resume) | `func resume(state: GFNodeState, previous_state: StringName = &"", args: Dictionary = {}) -> void:` |
| 方法 | [`handle_state_event`](#member-gfnodestatebehavior-methods-handle_state_event) | `func handle_state_event(state: GFNodeState, event_id: StringName, payload: Variant = null) -> bool:` |
| 方法 | [`_initialize`](#member-gfnodestatebehavior-methods-_initialize) | `func _initialize(_state: GFNodeState) -> void:` |
| 方法 | [`_enter`](#member-gfnodestatebehavior-methods-_enter) | `func _enter(_state: GFNodeState, _previous_state: StringName = &"", _args: Dictionary = {}) -> void:` |
| 方法 | [`_exit`](#member-gfnodestatebehavior-methods-_exit) | `func _exit(_state: GFNodeState, _next_state: StringName = &"", _args: Dictionary = {}) -> void:` |
| 方法 | [`_pause`](#member-gfnodestatebehavior-methods-_pause) | `func _pause(_state: GFNodeState, _next_state: StringName = &"", _args: Dictionary = {}) -> void:` |
| 方法 | [`_resume`](#member-gfnodestatebehavior-methods-_resume) | `func _resume(_state: GFNodeState, _previous_state: StringName = &"", _args: Dictionary = {}) -> void:` |
| 方法 | [`_handle_state_event`](#member-gfnodestatebehavior-methods-_handle_state_event) | `func _handle_state_event(_state: GFNodeState, _event_id: StringName, _payload: Variant = null) -> bool:` |

## 属性

<a id="member-gfnodestatebehavior-properties-behavior_id"></a>

### `behavior_id`

- API：`public`

```gdscript
var behavior_id: StringName = &""
```

行为标识，便于调试或项目工具识别。

<a id="member-gfnodestatebehavior-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用该行为。

<a id="member-gfnodestatebehavior-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。

结构：

- `metadata`: 项目自定义元数据 Dictionary；键和值由项目侧约定。

## 方法

<a id="member-gfnodestatebehavior-methods-initialize"></a>

### `initialize`

- API：`public`

```gdscript
func initialize(state: GFNodeState) -> void:
```

初始化行为。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 行为所属状态。 |

<a id="member-gfnodestatebehavior-methods-enter"></a>

### `enter`

- API：`public`

```gdscript
func enter(state: GFNodeState, previous_state: StringName = &"", args: Dictionary = {}) -> void:
```

状态进入后调用。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 行为所属状态。 |
| `previous_state` | 来源状态名。 |
| `args` | 状态切换参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestatebehavior-methods-exit"></a>

### `exit`

- API：`public`

```gdscript
func exit(state: GFNodeState, next_state: StringName = &"", args: Dictionary = {}) -> void:
```

状态退出前调用。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 行为所属状态。 |
| `next_state` | 目标状态名。 |
| `args` | 状态切换参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestatebehavior-methods-pause"></a>

### `pause`

- API：`public`

```gdscript
func pause(state: GFNodeState, next_state: StringName = &"", args: Dictionary = {}) -> void:
```

状态被栈式子状态覆盖时调用。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 行为所属状态。 |
| `next_state` | 目标状态名。 |
| `args` | 状态切换参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestatebehavior-methods-resume"></a>

### `resume`

- API：`public`

```gdscript
func resume(state: GFNodeState, previous_state: StringName = &"", args: Dictionary = {}) -> void:
```

状态从栈式子状态恢复后调用。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 行为所属状态。 |
| `previous_state` | 来源状态名。 |
| `args` | 状态切换参数。 |

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestatebehavior-methods-handle_state_event"></a>

### `handle_state_event`

- API：`public`

```gdscript
func handle_state_event(state: GFNodeState, event_id: StringName, payload: Variant = null) -> bool:
```

处理状态事件。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 行为所属状态。 |
| `event_id` | 状态事件标识。 |
| `payload` | 状态事件载荷。 |

返回：已处理返回 true。

结构：

- `payload`: 状态事件载荷；具体类型由 event_id 和项目约定决定。

<a id="member-gfnodestatebehavior-methods-_initialize"></a>

### `_initialize`

- API：`protected`

```gdscript
func _initialize(_state: GFNodeState) -> void:
```

行为初始化扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `_state` | 行为所属状态。 |

<a id="member-gfnodestatebehavior-methods-_enter"></a>

### `_enter`

- API：`protected`

```gdscript
func _enter(_state: GFNodeState, _previous_state: StringName = &"", _args: Dictionary = {}) -> void:
```

状态进入行为扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `_state` | 行为所属状态。 |
| `_previous_state` | 来源状态名。 |
| `_args` | 状态切换参数。 |

结构：

- `_args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestatebehavior-methods-_exit"></a>

### `_exit`

- API：`protected`

```gdscript
func _exit(_state: GFNodeState, _next_state: StringName = &"", _args: Dictionary = {}) -> void:
```

状态退出行为扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `_state` | 行为所属状态。 |
| `_next_state` | 目标状态名。 |
| `_args` | 状态切换参数。 |

结构：

- `_args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestatebehavior-methods-_pause"></a>

### `_pause`

- API：`protected`

```gdscript
func _pause(_state: GFNodeState, _next_state: StringName = &"", _args: Dictionary = {}) -> void:
```

状态暂停行为扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `_state` | 行为所属状态。 |
| `_next_state` | 目标状态名。 |
| `_args` | 状态切换参数。 |

结构：

- `_args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestatebehavior-methods-_resume"></a>

### `_resume`

- API：`protected`

```gdscript
func _resume(_state: GFNodeState, _previous_state: StringName = &"", _args: Dictionary = {}) -> void:
```

状态恢复行为扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `_state` | 行为所属状态。 |
| `_previous_state` | 来源状态名。 |
| `_args` | 状态切换参数。 |

结构：

- `_args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestatebehavior-methods-_handle_state_event"></a>

### `_handle_state_event`

- API：`protected`

```gdscript
func _handle_state_event(_state: GFNodeState, _event_id: StringName, _payload: Variant = null) -> bool:
```

状态事件行为扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `_state` | 行为所属状态。 |
| `_event_id` | 状态事件标识。 |
| `_payload` | 状态事件载荷。 |

返回：已处理返回 true。

结构：

- `_payload`: 状态事件载荷；具体类型由 _event_id 和项目约定决定。
