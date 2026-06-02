# GFPointerInteraction3D

[API Reference](../index.md) / [Interaction](../extensions-interaction.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/interaction/nodes/gf_pointer_interaction_3d.gd`
- 模块：`Interaction`
- 继承：`Node`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

将 3D 指针事件桥接为 GFInteractionContext。 监听 CollisionObject3D 的 hover、鼠标按钮与滚轮事件，构建通用交互上下文。 节点只传递位置、法线、按钮、标签和元数据，不解释点击对象的业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`pointer_entered`](#member-gfpointerinteraction3d-signals-pointer_entered) | `signal pointer_entered(context: GFInteractionContext)` |
| 信号 | [`pointer_exited`](#member-gfpointerinteraction3d-signals-pointer_exited) | `signal pointer_exited(context: GFInteractionContext)` |
| 信号 | [`pointer_pressed`](#member-gfpointerinteraction3d-signals-pointer_pressed) | `signal pointer_pressed(context: GFInteractionContext, event: InputEventMouseButton)` |
| 信号 | [`pointer_released`](#member-gfpointerinteraction3d-signals-pointer_released) | `signal pointer_released(context: GFInteractionContext, event: InputEventMouseButton)` |
| 信号 | [`pointer_clicked`](#member-gfpointerinteraction3d-signals-pointer_clicked) | `signal pointer_clicked(context: GFInteractionContext, event: InputEventMouseButton)` |
| 信号 | [`pointer_wheel`](#member-gfpointerinteraction3d-signals-pointer_wheel) | `signal pointer_wheel(context: GFInteractionContext, event: InputEventMouseButton)` |
| 信号 | [`pointer_interaction_sent`](#member-gfpointerinteraction3d-signals-pointer_interaction_sent) | `signal pointer_interaction_sent(context: GFInteractionContext, receiver: Object, report: Dictionary)` |
| 属性 | [`enabled`](#member-gfpointerinteraction3d-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`interaction_id`](#member-gfpointerinteraction3d-properties-interaction_id) | `var interaction_id: StringName = &""` |
| 属性 | [`group_name`](#member-gfpointerinteraction3d-properties-group_name) | `var group_name: StringName = &""` |
| 属性 | [`payload`](#member-gfpointerinteraction3d-properties-payload) | `var payload: Dictionary = {}` |
| 属性 | [`tags`](#member-gfpointerinteraction3d-properties-tags) | `var tags: PackedStringArray = PackedStringArray()` |
| 属性 | [`metadata`](#member-gfpointerinteraction3d-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`collision_object_path`](#member-gfpointerinteraction3d-properties-collision_object_path) | `var collision_object_path: NodePath = NodePath("")` |
| 属性 | [`receiver_path`](#member-gfpointerinteraction3d-properties-receiver_path) | `var receiver_path: NodePath = NodePath("")` |
| 属性 | [`sender_path`](#member-gfpointerinteraction3d-properties-sender_path) | `var sender_path: NodePath = NodePath("")` |
| 属性 | [`send_on_clicked`](#member-gfpointerinteraction3d-properties-send_on_clicked) | `var send_on_clicked: bool = true` |
| 属性 | [`send_on_pressed`](#member-gfpointerinteraction3d-properties-send_on_pressed) | `var send_on_pressed: bool = false` |
| 属性 | [`send_on_released`](#member-gfpointerinteraction3d-properties-send_on_released) | `var send_on_released: bool = false` |
| 属性 | [`send_on_wheel`](#member-gfpointerinteraction3d-properties-send_on_wheel) | `var send_on_wheel: bool = false` |
| 属性 | [`send_on_hover`](#member-gfpointerinteraction3d-properties-send_on_hover) | `var send_on_hover: bool = false` |
| 属性 | [`ensure_input_ray_pickable`](#member-gfpointerinteraction3d-properties-ensure_input_ray_pickable) | `var ensure_input_ray_pickable: bool = true` |
| 属性 | [`change_cursor_on_hover`](#member-gfpointerinteraction3d-properties-change_cursor_on_hover) | `var change_cursor_on_hover: bool = false` |
| 属性 | [`cursor_shape`](#member-gfpointerinteraction3d-properties-cursor_shape) | `var cursor_shape: Input.CursorShape = Input.CURSOR_ARROW` |
| 方法 | [`bind_collision_object`](#member-gfpointerinteraction3d-methods-bind_collision_object) | `func bind_collision_object(collision_object: CollisionObject3D) -> void:` |
| 方法 | [`get_collision_object`](#member-gfpointerinteraction3d-methods-get_collision_object) | `func get_collision_object() -> CollisionObject3D:` |
| 方法 | [`build_context`](#member-gfpointerinteraction3d-methods-build_context) | `func build_context( pointer_event: StringName, pointer_data: Dictionary = {}, receiver: Object = null ) -> GFInteractionContext:` |
| 方法 | [`send_pointer_interaction`](#member-gfpointerinteraction3d-methods-send_pointer_interaction) | `func send_pointer_interaction( pointer_event: StringName, pointer_data: Dictionary = {}, interaction_id_override: StringName = &"" ) -> Dictionary:` |

## 信号

<a id="member-gfpointerinteraction3d-signals-pointer_entered"></a>

### `pointer_entered`

- API：`public`

```gdscript
signal pointer_entered(context: GFInteractionContext)
```

指针进入绑定的 3D 碰撞对象。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 交互上下文。 |

<a id="member-gfpointerinteraction3d-signals-pointer_exited"></a>

### `pointer_exited`

- API：`public`

```gdscript
signal pointer_exited(context: GFInteractionContext)
```

指针离开绑定的 3D 碰撞对象。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 交互上下文。 |

<a id="member-gfpointerinteraction3d-signals-pointer_pressed"></a>

### `pointer_pressed`

- API：`public`

```gdscript
signal pointer_pressed(context: GFInteractionContext, event: InputEventMouseButton)
```

指针按钮按下。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 交互上下文。 |
| `event` | 原始输入事件。 |

<a id="member-gfpointerinteraction3d-signals-pointer_released"></a>

### `pointer_released`

- API：`public`

```gdscript
signal pointer_released(context: GFInteractionContext, event: InputEventMouseButton)
```

指针按钮释放。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 交互上下文。 |
| `event` | 原始输入事件。 |

<a id="member-gfpointerinteraction3d-signals-pointer_clicked"></a>

### `pointer_clicked`

- API：`public`

```gdscript
signal pointer_clicked(context: GFInteractionContext, event: InputEventMouseButton)
```

指针完成一次点击。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 交互上下文。 |
| `event` | 原始输入事件。 |

<a id="member-gfpointerinteraction3d-signals-pointer_wheel"></a>

### `pointer_wheel`

- API：`public`

```gdscript
signal pointer_wheel(context: GFInteractionContext, event: InputEventMouseButton)
```

指针滚轮事件。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 交互上下文。 |
| `event` | 原始输入事件。 |

<a id="member-gfpointerinteraction3d-signals-pointer_interaction_sent"></a>

### `pointer_interaction_sent`

- API：`public`

```gdscript
signal pointer_interaction_sent(context: GFInteractionContext, receiver: Object, report: Dictionary)
```

已向接收器发送交互。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 交互上下文。 |
| `receiver` | 接收对象。 |
| `report` | 结果报告。 |

结构：

- `report`: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver、reason、message 和 metadata 等字段。

## 属性

<a id="member-gfpointerinteraction3d-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用指针桥接。

<a id="member-gfpointerinteraction3d-properties-interaction_id"></a>

### `interaction_id`

- API：`public`

```gdscript
var interaction_id: StringName = &""
```

默认交互 ID。

<a id="member-gfpointerinteraction3d-properties-group_name"></a>

### `group_name`

- API：`public`

```gdscript
var group_name: StringName = &""
```

默认交互分组。

<a id="member-gfpointerinteraction3d-properties-payload"></a>

### `payload`

- API：`public`

```gdscript
var payload: Dictionary = {}
```

默认 payload；发送时会深拷贝并附加 pointer_* 字段。

结构：

- `payload`: 默认交互载荷 Dictionary；发送时会复制并附加 pointer_event、pointer_tags、pointer_metadata 等 pointer_* 字段。

<a id="member-gfpointerinteraction3d-properties-tags"></a>

### `tags`

- API：`public`

```gdscript
var tags: PackedStringArray = PackedStringArray()
```

指针标签。框架不解释标签含义。

<a id="member-gfpointerinteraction3d-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

自定义元数据。框架不解释该字段。

结构：

- `metadata`: 指针交互自定义元数据 Dictionary；会写入 payload.pointer_metadata 并复制到结果报告。

<a id="member-gfpointerinteraction3d-properties-collision_object_path"></a>

### `collision_object_path`

- API：`public`

```gdscript
var collision_object_path: NodePath = NodePath("")
```

可选 3D 碰撞对象路径；为空时优先使用父节点。

<a id="member-gfpointerinteraction3d-properties-receiver_path"></a>

### `receiver_path`

- API：`public`

```gdscript
var receiver_path: NodePath = NodePath("")
```

可选交互接收器路径；为空时从碰撞对象向父级解析 receive_interaction()。

<a id="member-gfpointerinteraction3d-properties-sender_path"></a>

### `sender_path`

- API：`public`

```gdscript
var sender_path: NodePath = NodePath("")
```

可选发送者路径；为空时使用当前节点。

<a id="member-gfpointerinteraction3d-properties-send_on_clicked"></a>

### `send_on_clicked`

- API：`public`

```gdscript
var send_on_clicked: bool = true
```

是否在点击完成时发送交互。

<a id="member-gfpointerinteraction3d-properties-send_on_pressed"></a>

### `send_on_pressed`

- API：`public`

```gdscript
var send_on_pressed: bool = false
```

是否在按钮按下时发送交互。

<a id="member-gfpointerinteraction3d-properties-send_on_released"></a>

### `send_on_released`

- API：`public`

```gdscript
var send_on_released: bool = false
```

是否在按钮释放时发送交互。

<a id="member-gfpointerinteraction3d-properties-send_on_wheel"></a>

### `send_on_wheel`

- API：`public`

```gdscript
var send_on_wheel: bool = false
```

是否在滚轮事件时发送交互。

<a id="member-gfpointerinteraction3d-properties-send_on_hover"></a>

### `send_on_hover`

- API：`public`

```gdscript
var send_on_hover: bool = false
```

是否在 hover 进入和离开时发送交互。

<a id="member-gfpointerinteraction3d-properties-ensure_input_ray_pickable"></a>

### `ensure_input_ray_pickable`

- API：`public`

```gdscript
var ensure_input_ray_pickable: bool = true
```

绑定碰撞对象时是否确保 input_ray_pickable 为 true。

<a id="member-gfpointerinteraction3d-properties-change_cursor_on_hover"></a>

### `change_cursor_on_hover`

- API：`public`

```gdscript
var change_cursor_on_hover: bool = false
```

hover 时是否临时切换鼠标光标。

<a id="member-gfpointerinteraction3d-properties-cursor_shape"></a>

### `cursor_shape`

- API：`public`

```gdscript
var cursor_shape: Input.CursorShape = Input.CURSOR_ARROW
```

hover 时使用的鼠标光标。

## 方法

<a id="member-gfpointerinteraction3d-methods-bind_collision_object"></a>

### `bind_collision_object`

- API：`public`

```gdscript
func bind_collision_object(collision_object: CollisionObject3D) -> void:
```

绑定 3D 碰撞对象。

参数：

| 名称 | 说明 |
|---|---|
| `collision_object` | 要监听的碰撞对象。 |

<a id="member-gfpointerinteraction3d-methods-get_collision_object"></a>

### `get_collision_object`

- API：`public`

```gdscript
func get_collision_object() -> CollisionObject3D:
```

获取当前绑定的 3D 碰撞对象。

返回：碰撞对象；不存在时返回 null。

<a id="member-gfpointerinteraction3d-methods-build_context"></a>

### `build_context`

- API：`public`

```gdscript
func build_context( pointer_event: StringName, pointer_data: Dictionary = {}, receiver: Object = null ) -> GFInteractionContext:
```

构建指针交互上下文。

参数：

| 名称 | 说明 |
|---|---|
| `pointer_event` | 指针事件标识。 |
| `pointer_data` | 指针事件数据。 |
| `receiver` | 可选接收对象；为空时自动解析。 |

返回：交互上下文。

结构：

- `pointer_data`: 指针事件数据 Dictionary；常见字段包括 pointer_position、pointer_normal、pointer_shape_idx、pointer_camera 和 pointer_input_event。

<a id="member-gfpointerinteraction3d-methods-send_pointer_interaction"></a>

### `send_pointer_interaction`

- API：`public`

```gdscript
func send_pointer_interaction( pointer_event: StringName, pointer_data: Dictionary = {}, interaction_id_override: StringName = &"" ) -> Dictionary:
```

发送一次指针交互。

参数：

| 名称 | 说明 |
|---|---|
| `pointer_event` | 指针事件标识。 |
| `pointer_data` | 指针事件数据。 |
| `interaction_id_override` | 可选交互 ID 覆盖。 |

返回：统一结果报告。

结构：

- `pointer_data`: 指针事件数据 Dictionary；常见字段包括 pointer_position、pointer_normal、pointer_shape_idx、pointer_camera 和 pointer_input_event。
- `return`: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver、reason、message 和 metadata 等字段。
