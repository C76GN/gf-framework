# GFAction

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/core/gf_action.gd`
- 模块：`Action Queue`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

动作队列常用工厂。 提供轻量、静态的动作创建入口，让项目用更少样板组合 ActionQueue。 它只创建通用动作，不隐含任何项目业务流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`sequence`](#member-gfaction-methods-sequence) | `static func sequence(actions: Array) -> GFVisualActionGroup:` |
| 方法 | [`parallel`](#member-gfaction-methods-parallel) | `static func parallel(actions: Array) -> GFVisualActionGroup:` |
| 方法 | [`race`](#member-gfaction-methods-race) | `static func race(actions: Array, cancel_remaining: bool = true) -> GFVisualActionGroup:` |
| 方法 | [`wait`](#member-gfaction-methods-wait) | `static func wait(seconds: float, host_node: Node = null) -> GFWaitAction:` |
| 方法 | [`callback`](#member-gfaction-methods-callback) | `static func callback(action_callback: Callable, args: Array = []) -> GFCallableAction:` |
| 方法 | [`repeat`](#member-gfaction-methods-repeat) | `static func repeat(action_factory: Callable, count: int = 1) -> GFRepeatAction:` |
| 方法 | [`repeat_forever`](#member-gfaction-methods-repeat_forever) | `static func repeat_forever(action_factory: Callable) -> GFRepeatAction:` |
| 方法 | [`tween`](#member-gfaction-methods-tween) | `static func tween( target: Object, property_name: NodePath, target_value: Variant, duration: float = 0.2, options: Dictionary = {} ) -> GFConfiguredTweenAction:` |
| 方法 | [`tween_by`](#member-gfaction-methods-tween_by) | `static func tween_by( target: Object, property_name: NodePath, offset: Variant, duration: float = 0.2, options: Dictionary = {} ) -> GFConfiguredTweenAction:` |
| 方法 | [`move_to`](#member-gfaction-methods-move_to) | `static func move_to( target: Node, target_position: Variant, duration: float = 0.2, property_name: NodePath = ^"position" ) -> GFMoveTweenAction:` |
| 方法 | [`move_by`](#member-gfaction-methods-move_by) | `static func move_by( target: Object, offset: Variant, duration: float = 0.2, property_name: NodePath = ^"position", options: Dictionary = {} ) -> GFConfiguredTweenAction:` |
| 方法 | [`scale_to`](#member-gfaction-methods-scale_to) | `static func scale_to( target: Object, scale_value: Variant, duration: float = 0.2, property_name: NodePath = ^"scale", options: Dictionary = {} ) -> GFConfiguredTweenAction:` |
| 方法 | [`scale_by`](#member-gfaction-methods-scale_by) | `static func scale_by( target: Object, scale_delta: Variant, duration: float = 0.2, property_name: NodePath = ^"scale", options: Dictionary = {} ) -> GFConfiguredTweenAction:` |
| 方法 | [`rotate_to`](#member-gfaction-methods-rotate_to) | `static func rotate_to( target: Object, rotation_value: Variant, duration: float = 0.2, property_name: NodePath = ^"rotation", options: Dictionary = {} ) -> GFConfiguredTweenAction:` |
| 方法 | [`rotate_by`](#member-gfaction-methods-rotate_by) | `static func rotate_by( target: Object, rotation_delta: Variant, duration: float = 0.2, property_name: NodePath = ^"rotation", options: Dictionary = {} ) -> GFConfiguredTweenAction:` |
| 方法 | [`fade_to`](#member-gfaction-methods-fade_to) | `static func fade_to( target: Object, alpha: float, duration: float = 0.2, options: Dictionary = {} ) -> GFConfiguredTweenAction:` |
| 方法 | [`fade_by`](#member-gfaction-methods-fade_by) | `static func fade_by( target: Object, alpha_delta: float, duration: float = 0.2, options: Dictionary = {} ) -> GFConfiguredTweenAction:` |
| 方法 | [`colorize`](#member-gfaction-methods-colorize) | `static func colorize( target: Object, color: Color, duration: float = 0.2, options: Dictionary = {} ) -> GFConfiguredTweenAction:` |
| 方法 | [`shader_parameter`](#member-gfaction-methods-shader_parameter) | `static func shader_parameter( target: Object, parameter_name: StringName, target_value: Variant, duration: float = 0.2, options: Dictionary = {} ) -> GFShaderParameterAction:` |
| 方法 | [`set_property`](#member-gfaction-methods-set_property) | `static func set_property(target: Object, property_name: NodePath, value: Variant) -> GFCallableAction:` |
| 方法 | [`set_visible`](#member-gfaction-methods-set_visible) | `static func set_visible(target: Object, visible: bool, property_name: NodePath = ^"visible") -> GFCallableAction:` |
| 方法 | [`show`](#member-gfaction-methods-show) | `static func show(target: Object, property_name: NodePath = ^"visible") -> GFCallableAction:` |
| 方法 | [`hide`](#member-gfaction-methods-hide) | `static func hide(target: Object, property_name: NodePath = ^"visible") -> GFCallableAction:` |
| 方法 | [`remove_node`](#member-gfaction-methods-remove_node) | `static func remove_node(target: Node) -> GFCallableAction:` |

## 方法

<a id="member-gfaction-methods-sequence"></a>

### `sequence`

- API：`public`

```gdscript
static func sequence(actions: Array) -> GFVisualActionGroup:
```

创建顺序动作组。

参数：

| 名称 | 说明 |
|---|---|
| `actions` | 子动作列表。 |

返回：顺序动作组。

结构：

- `actions`: Array，元素为 GFVisualAction 或实现 execute() 协议的动作对象。

<a id="member-gfaction-methods-parallel"></a>

### `parallel`

- API：`public`

```gdscript
static func parallel(actions: Array) -> GFVisualActionGroup:
```

创建并行动作组。

参数：

| 名称 | 说明 |
|---|---|
| `actions` | 子动作列表。 |

返回：并行动作组。

结构：

- `actions`: Array，元素为 GFVisualAction 或实现 execute() 协议的动作对象。

<a id="member-gfaction-methods-race"></a>

### `race`

- API：`public`
- 首次版本：`4.2.0`

```gdscript
static func race(actions: Array, cancel_remaining: bool = true) -> GFVisualActionGroup:
```

创建任一子动作完成即结束的并行动作组。

参数：

| 名称 | 说明 |
|---|---|
| `actions` | 子动作列表。 |
| `cancel_remaining` | 完成后是否取消仍在等待的子动作。 |

返回：并行动作组。

结构：

- `actions`: Array，元素为 GFVisualAction 或实现 execute() 协议的动作对象。

<a id="member-gfaction-methods-wait"></a>

### `wait`

- API：`public`

```gdscript
static func wait(seconds: float, host_node: Node = null) -> GFWaitAction:
```

创建等待动作。

参数：

| 名称 | 说明 |
|---|---|
| `seconds` | 等待秒数。 |
| `host_node` | 可选宿主节点。 |

返回：等待动作。

<a id="member-gfaction-methods-callback"></a>

### `callback`

- API：`public`

```gdscript
static func callback(action_callback: Callable, args: Array = []) -> GFCallableAction:
```

创建回调动作。

参数：

| 名称 | 说明 |
|---|---|
| `action_callback` | 要执行的回调。 |
| `args` | 回调参数。 |

返回：回调动作。

结构：

- `args`: Array，传给 action_callback.callv() 的参数列表。

<a id="member-gfaction-methods-repeat"></a>

### `repeat`

- API：`public`

```gdscript
static func repeat(action_factory: Callable, count: int = 1) -> GFRepeatAction:
```

创建重复动作。

参数：

| 名称 | 说明 |
|---|---|
| `action_factory` | 每轮创建动作的工厂。 |
| `count` | 重复次数；0 表示无限重复。 |

返回：重复动作。

<a id="member-gfaction-methods-repeat_forever"></a>

### `repeat_forever`

- API：`public`

```gdscript
static func repeat_forever(action_factory: Callable) -> GFRepeatAction:
```

创建无限重复动作。

参数：

| 名称 | 说明 |
|---|---|
| `action_factory` | 每轮创建动作的工厂。 |

返回：无限重复动作。

<a id="member-gfaction-methods-tween"></a>

### `tween`

- API：`public`

```gdscript
static func tween( target: Object, property_name: NodePath, target_value: Variant, duration: float = 0.2, options: Dictionary = {} ) -> GFConfiguredTweenAction:
```

创建通用属性 Tween 动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `property_name` | 属性路径。 |
| `target_value` | 目标值。 |
| `duration` | 持续时间。 |
| `options` | 可选 Tween 配置。 |

返回：配置化 Tween 动作。

结构：

- `target_value`: Variant，可被 Tween 写入 property_name 的目标值。
- `options`: Dictionary，支持 host_node、duration_scale、loop_count、ignore_time_scale、process_mode、pause_mode、delay、parallel、as_relative、transition_type 和 ease_type。

<a id="member-gfaction-methods-tween_by"></a>

### `tween_by`

- API：`public`

```gdscript
static func tween_by( target: Object, property_name: NodePath, offset: Variant, duration: float = 0.2, options: Dictionary = {} ) -> GFConfiguredTweenAction:
```

创建通用相对属性 Tween 动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `property_name` | 属性路径。 |
| `offset` | 相对偏移值。 |
| `duration` | 持续时间。 |
| `options` | 可选 Tween 配置。 |

返回：配置化 Tween 动作。

结构：

- `offset`: Variant，会与当前属性值相加的相对偏移。
- `options`: Dictionary，字段同 tween() 的 options，并强制启用 as_relative。

<a id="member-gfaction-methods-move_to"></a>

### `move_to`

- API：`public`

```gdscript
static func move_to( target: Node, target_position: Variant, duration: float = 0.2, property_name: NodePath = ^"position" ) -> GFMoveTweenAction:
```

创建移动到目标位置的 Tween 动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标节点。 |
| `target_position` | 目标位置。 |
| `duration` | 持续时间。 |
| `property_name` | 位置属性路径。 |

返回：移动动作。

结构：

- `target_position`: Variant，可写入 property_name 的目标位置，通常为 Vector2、Vector3 或 float。

<a id="member-gfaction-methods-move_by"></a>

### `move_by`

- API：`public`

```gdscript
static func move_by( target: Object, offset: Variant, duration: float = 0.2, property_name: NodePath = ^"position", options: Dictionary = {} ) -> GFConfiguredTweenAction:
```

创建相对移动 Tween 动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `offset` | 相对偏移。 |
| `duration` | 持续时间。 |
| `property_name` | 位置属性路径。 |
| `options` | 可选 Tween 配置。 |

返回：配置化 Tween 动作。

结构：

- `offset`: Variant，会与当前 property_name 值相加的相对偏移。
- `options`: Dictionary，字段同 tween() 的 options，并强制启用 as_relative。

<a id="member-gfaction-methods-scale_to"></a>

### `scale_to`

- API：`public`

```gdscript
static func scale_to( target: Object, scale_value: Variant, duration: float = 0.2, property_name: NodePath = ^"scale", options: Dictionary = {} ) -> GFConfiguredTweenAction:
```

创建缩放到目标值的 Tween 动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `scale_value` | 目标缩放。 |
| `duration` | 持续时间。 |
| `property_name` | 缩放属性路径。 |
| `options` | 可选 Tween 配置。 |

返回：配置化 Tween 动作。

结构：

- `scale_value`: Variant，可写入 property_name 的目标缩放值。
- `options`: Dictionary，字段同 tween() 的 options。

<a id="member-gfaction-methods-scale_by"></a>

### `scale_by`

- API：`public`

```gdscript
static func scale_by( target: Object, scale_delta: Variant, duration: float = 0.2, property_name: NodePath = ^"scale", options: Dictionary = {} ) -> GFConfiguredTweenAction:
```

创建相对缩放 Tween 动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `scale_delta` | 相对缩放偏移。 |
| `duration` | 持续时间。 |
| `property_name` | 缩放属性路径。 |
| `options` | 可选 Tween 配置。 |

返回：配置化 Tween 动作。

结构：

- `scale_delta`: Variant，会与当前 property_name 值相加的相对缩放偏移。
- `options`: Dictionary，字段同 tween() 的 options，并强制启用 as_relative。

<a id="member-gfaction-methods-rotate_to"></a>

### `rotate_to`

- API：`public`

```gdscript
static func rotate_to( target: Object, rotation_value: Variant, duration: float = 0.2, property_name: NodePath = ^"rotation", options: Dictionary = {} ) -> GFConfiguredTweenAction:
```

创建旋转到目标值的 Tween 动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `rotation_value` | 目标旋转值。 |
| `duration` | 持续时间。 |
| `property_name` | 旋转属性路径。 |
| `options` | 可选 Tween 配置。 |

返回：配置化 Tween 动作。

结构：

- `rotation_value`: Variant，可写入 property_name 的目标旋转值。
- `options`: Dictionary，字段同 tween() 的 options。

<a id="member-gfaction-methods-rotate_by"></a>

### `rotate_by`

- API：`public`

```gdscript
static func rotate_by( target: Object, rotation_delta: Variant, duration: float = 0.2, property_name: NodePath = ^"rotation", options: Dictionary = {} ) -> GFConfiguredTweenAction:
```

创建相对旋转 Tween 动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `rotation_delta` | 相对旋转偏移。 |
| `duration` | 持续时间。 |
| `property_name` | 旋转属性路径。 |
| `options` | 可选 Tween 配置。 |

返回：配置化 Tween 动作。

结构：

- `rotation_delta`: Variant，会与当前 property_name 值相加的相对旋转偏移。
- `options`: Dictionary，字段同 tween() 的 options，并强制启用 as_relative。

<a id="member-gfaction-methods-fade_to"></a>

### `fade_to`

- API：`public`

```gdscript
static func fade_to( target: Object, alpha: float, duration: float = 0.2, options: Dictionary = {} ) -> GFConfiguredTweenAction:
```

创建透明度 Tween 动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象，通常为 CanvasItem。 |
| `alpha` | 目标 alpha。 |
| `duration` | 持续时间。 |
| `options` | 可选 Tween 配置。 |

返回：配置化 Tween 动作。

结构：

- `options`: Dictionary，字段同 tween() 的 options。

<a id="member-gfaction-methods-fade_by"></a>

### `fade_by`

- API：`public`

```gdscript
static func fade_by( target: Object, alpha_delta: float, duration: float = 0.2, options: Dictionary = {} ) -> GFConfiguredTweenAction:
```

创建相对透明度 Tween 动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象，通常为 CanvasItem。 |
| `alpha_delta` | 相对 alpha 偏移。 |
| `duration` | 持续时间。 |
| `options` | 可选 Tween 配置。 |

返回：配置化 Tween 动作。

结构：

- `options`: Dictionary，字段同 tween() 的 options，并强制启用 as_relative。

<a id="member-gfaction-methods-colorize"></a>

### `colorize`

- API：`public`

```gdscript
static func colorize( target: Object, color: Color, duration: float = 0.2, options: Dictionary = {} ) -> GFConfiguredTweenAction:
```

创建整体颜色 Tween 动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象，通常为 CanvasItem。 |
| `color` | 目标颜色。 |
| `duration` | 持续时间。 |
| `options` | 可选 Tween 配置。 |

返回：配置化 Tween 动作。

结构：

- `options`: Dictionary，字段同 tween() 的 options。

<a id="member-gfaction-methods-shader_parameter"></a>

### `shader_parameter`

- API：`public`
- 首次版本：`4.2.0`

```gdscript
static func shader_parameter( target: Object, parameter_name: StringName, target_value: Variant, duration: float = 0.2, options: Dictionary = {} ) -> GFShaderParameterAction:
```

创建 ShaderMaterial 参数 Tween 动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。可以是 ShaderMaterial，也可以是持有材质属性的对象。 |
| `parameter_name` | Shader uniform 参数名。 |
| `target_value` | 目标参数值。 |
| `duration` | 持续时间。 |
| `options` | 可选动作配置。 |

返回：Shader 参数动作。

结构：

- `target_value`: Variant，可被 Tween 插值并写入 parameter_name 的目标值。
- `options`: Dictionary，支持 host_node、material_property、transition_type、ease_type、duplicate_material_on_execute、restore_initial_value_on_cancel 和 restore_initial_value_on_finish。

<a id="member-gfaction-methods-set_property"></a>

### `set_property`

- API：`public`

```gdscript
static func set_property(target: Object, property_name: NodePath, value: Variant) -> GFCallableAction:
```

创建设置任意属性的瞬时动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `property_name` | 属性路径。 |
| `value` | 要写入的值。 |

返回：回调动作。

结构：

- `value`: Variant，会通过 target.set_indexed(property_name, value) 写入的值。

<a id="member-gfaction-methods-set_visible"></a>

### `set_visible`

- API：`public`

```gdscript
static func set_visible(target: Object, visible: bool, property_name: NodePath = ^"visible") -> GFCallableAction:
```

创建设置 visible 属性的瞬时动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `visible` | 可见性。 |
| `property_name` | 可见性属性路径。 |

返回：回调动作。

<a id="member-gfaction-methods-show"></a>

### `show`

- API：`public`

```gdscript
static func show(target: Object, property_name: NodePath = ^"visible") -> GFCallableAction:
```

创建显示目标的瞬时动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `property_name` | 可见性属性路径。 |

返回：回调动作。

<a id="member-gfaction-methods-hide"></a>

### `hide`

- API：`public`

```gdscript
static func hide(target: Object, property_name: NodePath = ^"visible") -> GFCallableAction:
```

创建隐藏目标的瞬时动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `property_name` | 可见性属性路径。 |

返回：回调动作。

<a id="member-gfaction-methods-remove_node"></a>

### `remove_node`

- API：`public`

```gdscript
static func remove_node(target: Node) -> GFCallableAction:
```

创建释放节点的瞬时动作。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 要释放的节点。 |

返回：回调动作。
