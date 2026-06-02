# GFPointerActivityUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/runtime/gf_pointer_activity_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用指针活动状态工具。 由项目在 _input(event) 中显式转发事件，工具只维护按下、移动、拖拽和空闲状态， 不消费输入，也不绑定任何具体交互或业务对象。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`pointer_pressed`](#member-gfpointeractivityutility-signals-pointer_pressed) | `signal pointer_pressed(pointer_id: int, position: Vector2, event: InputEvent)` |
| 信号 | [`pointer_released`](#member-gfpointeractivityutility-signals-pointer_released) | `signal pointer_released(pointer_id: int, position: Vector2, event: InputEvent)` |
| 信号 | [`pointer_moved`](#member-gfpointeractivityutility-signals-pointer_moved) | `signal pointer_moved(pointer_id: int, position: Vector2, previous_position: Vector2, event: InputEvent)` |
| 信号 | [`pointer_drag_started`](#member-gfpointeractivityutility-signals-pointer_drag_started) | `signal pointer_drag_started(pointer_id: int, start_position: Vector2, position: Vector2, event: InputEvent)` |
| 信号 | [`pointer_dragged`](#member-gfpointeractivityutility-signals-pointer_dragged) | `signal pointer_dragged(pointer_id: int, position: Vector2, delta: Vector2, event: InputEvent)` |
| 信号 | [`pointer_drag_ended`](#member-gfpointeractivityutility-signals-pointer_drag_ended) | `signal pointer_drag_ended(pointer_id: int, position: Vector2, event: InputEvent)` |
| 信号 | [`pointer_idle_started`](#member-gfpointeractivityutility-signals-pointer_idle_started) | `signal pointer_idle_started(pointer_id: int, position: Vector2)` |
| 信号 | [`pointer_idle_ended`](#member-gfpointeractivityutility-signals-pointer_idle_ended) | `signal pointer_idle_ended(pointer_id: int, position: Vector2)` |
| 属性 | [`track_mouse`](#member-gfpointeractivityutility-properties-track_mouse) | `var track_mouse: bool = true` |
| 属性 | [`track_touch`](#member-gfpointeractivityutility-properties-track_touch) | `var track_touch: bool = true` |
| 属性 | [`mouse_button_index`](#member-gfpointeractivityutility-properties-mouse_button_index) | `var mouse_button_index: MouseButton = MOUSE_BUTTON_LEFT` |
| 属性 | [`drag_threshold_pixels`](#member-gfpointeractivityutility-properties-drag_threshold_pixels) | `var drag_threshold_pixels: float = 8.0` |
| 属性 | [`idle_threshold_seconds`](#member-gfpointeractivityutility-properties-idle_threshold_seconds) | `var idle_threshold_seconds: float = 0.5` |
| 属性 | [`is_pointer_pressed`](#member-gfpointeractivityutility-properties-is_pointer_pressed) | `var is_pointer_pressed: bool = false` |
| 属性 | [`is_pointer_dragging`](#member-gfpointeractivityutility-properties-is_pointer_dragging) | `var is_pointer_dragging: bool = false` |
| 属性 | [`is_pointer_moving`](#member-gfpointeractivityutility-properties-is_pointer_moving) | `var is_pointer_moving: bool = false` |
| 属性 | [`is_pointer_idle`](#member-gfpointeractivityutility-properties-is_pointer_idle) | `var is_pointer_idle: bool = true` |
| 属性 | [`active_pointer_id`](#member-gfpointeractivityutility-properties-active_pointer_id) | `var active_pointer_id: int = -1` |
| 属性 | [`last_pointer_id`](#member-gfpointeractivityutility-properties-last_pointer_id) | `var last_pointer_id: int = -1` |
| 属性 | [`press_position`](#member-gfpointeractivityutility-properties-press_position) | `var press_position: Vector2 = Vector2.ZERO` |
| 属性 | [`last_position`](#member-gfpointeractivityutility-properties-last_position) | `var last_position: Vector2 = Vector2.ZERO` |
| 方法 | [`handle_input_event`](#member-gfpointeractivityutility-methods-handle_input_event) | `func handle_input_event(event: InputEvent) -> bool:` |
| 方法 | [`tick`](#member-gfpointeractivityutility-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`reset_activity`](#member-gfpointeractivityutility-methods-reset_activity) | `func reset_activity() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfpointeractivityutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfpointeractivityutility-signals-pointer_pressed"></a>

### `pointer_pressed`

- API：`public`

```gdscript
signal pointer_pressed(pointer_id: int, position: Vector2, event: InputEvent)
```

指针按下时发出。

参数：

| 名称 | 说明 |
|---|---|
| `pointer_id` | 指针 ID；鼠标为 0，触摸为触点 index。 |
| `position` | 指针位置。 |
| `event` | 原始输入事件。 |

<a id="member-gfpointeractivityutility-signals-pointer_released"></a>

### `pointer_released`

- API：`public`

```gdscript
signal pointer_released(pointer_id: int, position: Vector2, event: InputEvent)
```

指针释放时发出。

参数：

| 名称 | 说明 |
|---|---|
| `pointer_id` | 指针 ID；鼠标为 0，触摸为触点 index。 |
| `position` | 指针位置。 |
| `event` | 原始输入事件。 |

<a id="member-gfpointeractivityutility-signals-pointer_moved"></a>

### `pointer_moved`

- API：`public`

```gdscript
signal pointer_moved(pointer_id: int, position: Vector2, previous_position: Vector2, event: InputEvent)
```

指针移动时发出。

参数：

| 名称 | 说明 |
|---|---|
| `pointer_id` | 指针 ID；鼠标为 0，触摸为触点 index。 |
| `position` | 指针位置。 |
| `previous_position` | 上一次指针位置。 |
| `event` | 原始输入事件。 |

<a id="member-gfpointeractivityutility-signals-pointer_drag_started"></a>

### `pointer_drag_started`

- API：`public`

```gdscript
signal pointer_drag_started(pointer_id: int, start_position: Vector2, position: Vector2, event: InputEvent)
```

指针从按下状态进入拖拽时发出。

参数：

| 名称 | 说明 |
|---|---|
| `pointer_id` | 指针 ID；鼠标为 0，触摸为触点 index。 |
| `start_position` | 指针按下位置。 |
| `position` | 当前指针位置。 |
| `event` | 原始输入事件。 |

<a id="member-gfpointeractivityutility-signals-pointer_dragged"></a>

### `pointer_dragged`

- API：`public`

```gdscript
signal pointer_dragged(pointer_id: int, position: Vector2, delta: Vector2, event: InputEvent)
```

指针拖拽中发出。

参数：

| 名称 | 说明 |
|---|---|
| `pointer_id` | 指针 ID；鼠标为 0，触摸为触点 index。 |
| `position` | 当前指针位置。 |
| `delta` | 本次拖拽位移。 |
| `event` | 原始输入事件。 |

<a id="member-gfpointeractivityutility-signals-pointer_drag_ended"></a>

### `pointer_drag_ended`

- API：`public`

```gdscript
signal pointer_drag_ended(pointer_id: int, position: Vector2, event: InputEvent)
```

指针拖拽结束时发出。

参数：

| 名称 | 说明 |
|---|---|
| `pointer_id` | 指针 ID；鼠标为 0，触摸为触点 index。 |
| `position` | 指针释放位置。 |
| `event` | 原始输入事件。 |

<a id="member-gfpointeractivityutility-signals-pointer_idle_started"></a>

### `pointer_idle_started`

- API：`public`

```gdscript
signal pointer_idle_started(pointer_id: int, position: Vector2)
```

指针活动超过阈值后进入空闲时发出。

参数：

| 名称 | 说明 |
|---|---|
| `pointer_id` | 指针 ID；鼠标为 0，触摸为触点 index。 |
| `position` | 最近活动位置。 |

<a id="member-gfpointeractivityutility-signals-pointer_idle_ended"></a>

### `pointer_idle_ended`

- API：`public`

```gdscript
signal pointer_idle_ended(pointer_id: int, position: Vector2)
```

指针从空闲恢复活动时发出。

参数：

| 名称 | 说明 |
|---|---|
| `pointer_id` | 指针 ID；鼠标为 0，触摸为触点 index。 |
| `position` | 恢复活动位置。 |

## 属性

<a id="member-gfpointeractivityutility-properties-track_mouse"></a>

### `track_mouse`

- API：`public`

```gdscript
var track_mouse: bool = true
```

是否追踪鼠标事件。

<a id="member-gfpointeractivityutility-properties-track_touch"></a>

### `track_touch`

- API：`public`

```gdscript
var track_touch: bool = true
```

是否追踪触摸事件。

<a id="member-gfpointeractivityutility-properties-mouse_button_index"></a>

### `mouse_button_index`

- API：`public`

```gdscript
var mouse_button_index: MouseButton = MOUSE_BUTTON_LEFT
```

鼠标模式下作为主指针的按钮。

<a id="member-gfpointeractivityutility-properties-drag_threshold_pixels"></a>

### `drag_threshold_pixels`

- API：`public`

```gdscript
var drag_threshold_pixels: float = 8.0
```

从按下位置移动超过该距离后进入拖拽状态。

<a id="member-gfpointeractivityutility-properties-idle_threshold_seconds"></a>

### `idle_threshold_seconds`

- API：`public`

```gdscript
var idle_threshold_seconds: float = 0.5
```

无活动超过该秒数后进入空闲状态。

<a id="member-gfpointeractivityutility-properties-is_pointer_pressed"></a>

### `is_pointer_pressed`

- API：`public`

```gdscript
var is_pointer_pressed: bool = false
```

当前是否有指针按下。

<a id="member-gfpointeractivityutility-properties-is_pointer_dragging"></a>

### `is_pointer_dragging`

- API：`public`

```gdscript
var is_pointer_dragging: bool = false
```

当前是否处于拖拽状态。

<a id="member-gfpointeractivityutility-properties-is_pointer_moving"></a>

### `is_pointer_moving`

- API：`public`

```gdscript
var is_pointer_moving: bool = false
```

最近一帧是否收到指针活动。

<a id="member-gfpointeractivityutility-properties-is_pointer_idle"></a>

### `is_pointer_idle`

- API：`public`

```gdscript
var is_pointer_idle: bool = true
```

当前是否处于空闲状态。

<a id="member-gfpointeractivityutility-properties-active_pointer_id"></a>

### `active_pointer_id`

- API：`public`

```gdscript
var active_pointer_id: int = -1
```

当前活动指针 ID；鼠标为 0，触摸为 InputEventScreenTouch.index。

<a id="member-gfpointeractivityutility-properties-last_pointer_id"></a>

### `last_pointer_id`

- API：`public`

```gdscript
var last_pointer_id: int = -1
```

最近发生活动的指针 ID。

<a id="member-gfpointeractivityutility-properties-press_position"></a>

### `press_position`

- API：`public`

```gdscript
var press_position: Vector2 = Vector2.ZERO
```

最近按下位置。

<a id="member-gfpointeractivityutility-properties-last_position"></a>

### `last_position`

- API：`public`

```gdscript
var last_position: Vector2 = Vector2.ZERO
```

最近指针位置。

## 方法

<a id="member-gfpointeractivityutility-methods-handle_input_event"></a>

### `handle_input_event`

- API：`public`

```gdscript
func handle_input_event(event: InputEvent) -> bool:
```

处理一个输入事件。

参数：

| 名称 | 说明 |
|---|---|
| `event` | 输入事件。 |

返回：识别为受追踪指针事件时返回 true。

<a id="member-gfpointeractivityutility-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(delta: float) -> void:
```

推进空闲计时。通常在 tick(delta) 或 _process(delta) 中调用。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 秒。 |

<a id="member-gfpointeractivityutility-methods-reset_activity"></a>

### `reset_activity`

- API：`public`

```gdscript
func reset_activity() -> void:
```

清理所有指针活动状态。

<a id="member-gfpointeractivityutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：当前指针状态。

结构：

- `return`: Dictionary，包含 pointer id、pressed/dragging/moving/idle 标记、位置、idle 计时器和阈值配置。
