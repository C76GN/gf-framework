# GFInputVirtualCursorModifier

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/modifiers/gf_input_virtual_cursor_modifier.gd`
- 模块：`Standard`
- 继承：`GFInputModifier`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

虚拟光标输入修饰器。 将二维输入视为速度并积分为一个位置值。它只维护抽象坐标，不访问 Viewport、 Control 或具体 UI 节点。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`initial_position`](#member-gfinputvirtualcursormodifier-properties-initial_position) | `var initial_position: Vector2 = Vector2(0.5, 0.5)` |
| 属性 | [`speed`](#member-gfinputvirtualcursormodifier-properties-speed) | `var speed: Vector2 = Vector2.ONE` |
| 属性 | [`apply_delta_time`](#member-gfinputvirtualcursormodifier-properties-apply_delta_time) | `var apply_delta_time: bool = true` |
| 属性 | [`use_manual_delta_time`](#member-gfinputvirtualcursormodifier-properties-use_manual_delta_time) | `var use_manual_delta_time: bool = false` |
| 属性 | [`manual_delta_seconds`](#member-gfinputvirtualcursormodifier-properties-manual_delta_seconds) | `var manual_delta_seconds: float = 0.0` |
| 属性 | [`clamp_to_rect`](#member-gfinputvirtualcursormodifier-properties-clamp_to_rect) | `var clamp_to_rect: bool = true` |
| 属性 | [`clamp_rect`](#member-gfinputvirtualcursormodifier-properties-clamp_rect) | `var clamp_rect: Rect2 = Rect2(Vector2.ZERO, Vector2.ONE)` |
| 属性 | [`idle_threshold`](#member-gfinputvirtualcursormodifier-properties-idle_threshold) | `var idle_threshold: float = 0.0` |
| 属性 | [`reset_when_idle`](#member-gfinputvirtualcursormodifier-properties-reset_when_idle) | `var reset_when_idle: bool = false` |
| 属性 | [`position`](#member-gfinputvirtualcursormodifier-properties-position) | `var position: Vector2 = Vector2(0.5, 0.5)` |
| 方法 | [`modify`](#member-gfinputvirtualcursormodifier-methods-modify) | `func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:` |
| 方法 | [`modify_3d`](#member-gfinputvirtualcursormodifier-methods-modify_3d) | `func modify_3d(value: Vector3, event: InputEvent = null, action: GFInputAction = null) -> Vector3:` |
| 方法 | [`reset_position`](#member-gfinputvirtualcursormodifier-methods-reset_position) | `func reset_position() -> GFInputVirtualCursorModifier:` |
| 方法 | [`set_manual_delta_seconds`](#member-gfinputvirtualcursormodifier-methods-set_manual_delta_seconds) | `func set_manual_delta_seconds(delta_seconds: float) -> GFInputVirtualCursorModifier:` |
| 方法 | [`get_runtime_state`](#member-gfinputvirtualcursormodifier-methods-get_runtime_state) | `func get_runtime_state() -> Dictionary:` |
| 方法 | [`restore_runtime_state`](#member-gfinputvirtualcursormodifier-methods-restore_runtime_state) | `func restore_runtime_state(state: Dictionary) -> GFInputVirtualCursorModifier:` |
| 方法 | [`supports_runtime_state`](#member-gfinputvirtualcursormodifier-methods-supports_runtime_state) | `func supports_runtime_state() -> bool:` |
| 方法 | [`get_modifier_runtime_state`](#member-gfinputvirtualcursormodifier-methods-get_modifier_runtime_state) | `func get_modifier_runtime_state() -> Dictionary:` |
| 方法 | [`restore_modifier_runtime_state`](#member-gfinputvirtualcursormodifier-methods-restore_modifier_runtime_state) | `func restore_modifier_runtime_state(state: Dictionary) -> GFInputModifier:` |
| 方法 | [`reset_modifier_runtime_state`](#member-gfinputvirtualcursormodifier-methods-reset_modifier_runtime_state) | `func reset_modifier_runtime_state() -> GFInputModifier:` |
| 方法 | [`set_runtime_delta_seconds`](#member-gfinputvirtualcursormodifier-methods-set_runtime_delta_seconds) | `func set_runtime_delta_seconds(delta_seconds: float) -> GFInputModifier:` |
| 方法 | [`clear_runtime_delta_seconds`](#member-gfinputvirtualcursormodifier-methods-clear_runtime_delta_seconds) | `func clear_runtime_delta_seconds() -> GFInputModifier:` |
| 方法 | [`duplicate_modifier`](#member-gfinputvirtualcursormodifier-methods-duplicate_modifier) | `func duplicate_modifier() -> GFInputModifier:` |

## 属性

<a id="member-gfinputvirtualcursormodifier-properties-initial_position"></a>

### `initial_position`

- API：`public`

```gdscript
var initial_position: Vector2 = Vector2(0.5, 0.5)
```

初始位置。

<a id="member-gfinputvirtualcursormodifier-properties-speed"></a>

### `speed`

- API：`public`

```gdscript
var speed: Vector2 = Vector2.ONE
```

每秒移动速度倍率。

<a id="member-gfinputvirtualcursormodifier-properties-apply_delta_time"></a>

### `apply_delta_time`

- API：`public`

```gdscript
var apply_delta_time: bool = true
```

是否按真实经过时间缩放输入。

<a id="member-gfinputvirtualcursormodifier-properties-use_manual_delta_time"></a>

### `use_manual_delta_time`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var use_manual_delta_time: bool = false
```

是否使用 manual_delta_seconds 替代系统时钟。

<a id="member-gfinputvirtualcursormodifier-properties-manual_delta_seconds"></a>

### `manual_delta_seconds`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var manual_delta_seconds: float = 0.0
```

手动驱动的每步 delta 秒数，用于确定性输入回放。

<a id="member-gfinputvirtualcursormodifier-properties-clamp_to_rect"></a>

### `clamp_to_rect`

- API：`public`

```gdscript
var clamp_to_rect: bool = true
```

是否将位置限制在 clamp_rect 内。

<a id="member-gfinputvirtualcursormodifier-properties-clamp_rect"></a>

### `clamp_rect`

- API：`public`

```gdscript
var clamp_rect: Rect2 = Rect2(Vector2.ZERO, Vector2.ONE)
```

可用位置范围。

<a id="member-gfinputvirtualcursormodifier-properties-idle_threshold"></a>

### `idle_threshold`

- API：`public`

```gdscript
var idle_threshold: float = 0.0
```

输入低于该长度时视为空闲。

<a id="member-gfinputvirtualcursormodifier-properties-reset_when_idle"></a>

### `reset_when_idle`

- API：`public`

```gdscript
var reset_when_idle: bool = false
```

空闲时是否回到 initial_position。

<a id="member-gfinputvirtualcursormodifier-properties-position"></a>

### `position`

- API：`public`

```gdscript
var position: Vector2 = Vector2(0.5, 0.5)
```

当前虚拟光标位置。

## 方法

<a id="member-gfinputvirtualcursormodifier-methods-modify"></a>

### `modify`

- API：`public`

```gdscript
func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:
```

修改二维输入值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入或修改的值。 |
| `_event` | 原始输入事件，默认实现不直接使用。 |
| `_action` | 当前输入动作配置，默认实现不直接使用。 |

返回：更新后的虚拟光标位置。

<a id="member-gfinputvirtualcursormodifier-methods-modify_3d"></a>

### `modify_3d`

- API：`public`

```gdscript
func modify_3d(value: Vector3, event: InputEvent = null, action: GFInputAction = null) -> Vector3:
```

修改三维输入值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入或修改的值。 |
| `event` | 原始输入事件，默认实现不直接使用。 |
| `action` | 当前输入动作配置，默认实现不直接使用。 |

返回：包含虚拟光标 X/Y 和原 Z 分量的三维值。

<a id="member-gfinputvirtualcursormodifier-methods-reset_position"></a>

### `reset_position`

- API：`public`

```gdscript
func reset_position() -> GFInputVirtualCursorModifier:
```

重置虚拟光标位置。

返回：当前修饰器。

<a id="member-gfinputvirtualcursormodifier-methods-set_manual_delta_seconds"></a>

### `set_manual_delta_seconds`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func set_manual_delta_seconds(delta_seconds: float) -> GFInputVirtualCursorModifier:
```

设置下一步和后续步骤使用的手动 delta 秒数。

参数：

| 名称 | 说明 |
|---|---|
| `delta_seconds` | 手动 delta 秒数；小于 0 时按 0 处理。 |

返回：当前修饰器。

<a id="member-gfinputvirtualcursormodifier-methods-get_runtime_state"></a>

### `get_runtime_state`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_runtime_state() -> Dictionary:
```

获取运行时状态快照。

返回：当前运行时状态。

结构：

- `return`: Dictionary，包含 position 与 initialized。

<a id="member-gfinputvirtualcursormodifier-methods-restore_runtime_state"></a>

### `restore_runtime_state`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func restore_runtime_state(state: Dictionary) -> GFInputVirtualCursorModifier:
```

从运行时状态快照恢复虚拟光标。

参数：

| 名称 | 说明 |
|---|---|
| `state` | get_runtime_state() 生成的状态。 |

返回：当前修饰器。

结构：

- `state`: Dictionary，可包含 position: Vector2 与 initialized: bool。

<a id="member-gfinputvirtualcursormodifier-methods-supports_runtime_state"></a>

### `supports_runtime_state`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func supports_runtime_state() -> bool:
```

当前修饰器是否维护运行时状态。

返回：始终返回 true。

<a id="member-gfinputvirtualcursormodifier-methods-get_modifier_runtime_state"></a>

### `get_modifier_runtime_state`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_modifier_runtime_state() -> Dictionary:
```

获取运行时状态快照。

返回：当前运行时状态。

结构：

- `return`: Dictionary，包含 position 与 initialized。

<a id="member-gfinputvirtualcursormodifier-methods-restore_modifier_runtime_state"></a>

### `restore_modifier_runtime_state`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func restore_modifier_runtime_state(state: Dictionary) -> GFInputModifier:
```

从运行时状态快照恢复虚拟光标。

参数：

| 名称 | 说明 |
|---|---|
| `state` | get_modifier_runtime_state() 生成的状态。 |

返回：当前修饰器。

结构：

- `state`: Dictionary，可包含 position: Vector2 与 initialized: bool。

<a id="member-gfinputvirtualcursormodifier-methods-reset_modifier_runtime_state"></a>

### `reset_modifier_runtime_state`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func reset_modifier_runtime_state() -> GFInputModifier:
```

重置运行时状态。

返回：当前修饰器。

<a id="member-gfinputvirtualcursormodifier-methods-set_runtime_delta_seconds"></a>

### `set_runtime_delta_seconds`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_runtime_delta_seconds(delta_seconds: float) -> GFInputModifier:
```

设置下一步和后续步骤使用的运行时 delta 秒数。

参数：

| 名称 | 说明 |
|---|---|
| `delta_seconds` | 运行时 delta 秒数；小于 0 时按 0 处理。 |

返回：当前修饰器。

<a id="member-gfinputvirtualcursormodifier-methods-clear_runtime_delta_seconds"></a>

### `clear_runtime_delta_seconds`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_runtime_delta_seconds() -> GFInputModifier:
```

清除手动运行时 delta，恢复系统时间源。

返回：当前修饰器。

<a id="member-gfinputvirtualcursormodifier-methods-duplicate_modifier"></a>

### `duplicate_modifier`

- API：`public`

```gdscript
func duplicate_modifier() -> GFInputModifier:
```

创建运行时副本。

返回：修饰器副本。
