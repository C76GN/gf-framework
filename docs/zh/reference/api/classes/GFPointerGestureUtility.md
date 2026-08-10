# GFPointerGestureUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/runtime/gf_pointer_gesture_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

通用指针手势摘要工具。 把鼠标、触摸和系统手势事件归一为平移、缩放和旋转摘要。 工具只输出数据，不控制 Camera、Control、Node2D 或项目业务对象。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`gesture_updated`](#member-gfpointergestureutility-signals-gesture_updated) | `signal gesture_updated(snapshot: Dictionary, event: InputEvent)` |
| 信号 | [`gesture_ended`](#member-gfpointergestureutility-signals-gesture_ended) | `signal gesture_ended(snapshot: Dictionary)` |
| 属性 | [`track_mouse`](#member-gfpointergestureutility-properties-track_mouse) | `var track_mouse: bool = true` |
| 属性 | [`track_mouse_wheel`](#member-gfpointergestureutility-properties-track_mouse_wheel) | `var track_mouse_wheel: bool = true` |
| 属性 | [`track_touch`](#member-gfpointergestureutility-properties-track_touch) | `var track_touch: bool = true` |
| 属性 | [`track_gesture_events`](#member-gfpointergestureutility-properties-track_gesture_events) | `var track_gesture_events: bool = true` |
| 属性 | [`mouse_button_index`](#member-gfpointergestureutility-properties-mouse_button_index) | `var mouse_button_index: MouseButton = MOUSE_BUTTON_LEFT` |
| 属性 | [`mouse_wheel_zoom_factor`](#member-gfpointergestureutility-properties-mouse_wheel_zoom_factor) | `var mouse_wheel_zoom_factor: float = 1.1` |
| 属性 | [`minimum_pinch_distance`](#member-gfpointergestureutility-properties-minimum_pinch_distance) | `var minimum_pinch_distance: float = _DEFAULT_MINIMUM_PINCH_DISTANCE` |
| 方法 | [`handle_input_event`](#member-gfpointergestureutility-methods-handle_input_event) | `func handle_input_event(event: InputEvent) -> bool:` |
| 方法 | [`reset_gesture`](#member-gfpointergestureutility-methods-reset_gesture) | `func reset_gesture() -> void:` |
| 方法 | [`get_active_pointer_count`](#member-gfpointergestureutility-methods-get_active_pointer_count) | `func get_active_pointer_count() -> int:` |
| 方法 | [`get_gesture_snapshot`](#member-gfpointergestureutility-methods-get_gesture_snapshot) | `func get_gesture_snapshot() -> Dictionary:` |
| 方法 | [`calculate_gesture`](#member-gfpointergestureutility-methods-calculate_gesture) | `static func calculate_gesture( previous_points: Dictionary, current_points: Dictionary, source: StringName = &"pointer", minimum_distance: float = _DEFAULT_MINIMUM_PINCH_DISTANCE ) -> Dictionary:` |

## 信号

<a id="member-gfpointergestureutility-signals-gesture_updated"></a>

### `gesture_updated`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal gesture_updated(snapshot: Dictionary, event: InputEvent)
```

手势摘要更新时发出。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 手势摘要字典。 |
| `event` | 原始输入事件。 |

结构：

- `snapshot`: Dictionary with active, source, pointer_count, pointer_ids, center, previous_center, pan_delta, scale, rotation_delta, distance, previous_distance, and primary_pointer_id. Runtime mouse identity is -2; touch identities keep their event index.

<a id="member-gfpointergestureutility-signals-gesture_ended"></a>

### `gesture_ended`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal gesture_ended(snapshot: Dictionary)
```

最后一个活动指针释放或 reset_gesture() 清理活动手势时发出。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 结束后的手势摘要。 |

结构：

- `snapshot`: Dictionary with active=false and the last known center fields.

## 属性

<a id="member-gfpointergestureutility-properties-track_mouse"></a>

### `track_mouse`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var track_mouse: bool = true
```

是否追踪鼠标拖拽事件。

<a id="member-gfpointergestureutility-properties-track_mouse_wheel"></a>

### `track_mouse_wheel`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var track_mouse_wheel: bool = true
```

是否把鼠标滚轮归一为缩放手势。

<a id="member-gfpointergestureutility-properties-track_touch"></a>

### `track_touch`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var track_touch: bool = true
```

是否追踪触摸事件。

<a id="member-gfpointergestureutility-properties-track_gesture_events"></a>

### `track_gesture_events`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var track_gesture_events: bool = true
```

是否追踪 Godot 提供的 pan / magnify 系统手势事件。

<a id="member-gfpointergestureutility-properties-mouse_button_index"></a>

### `mouse_button_index`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var mouse_button_index: MouseButton = MOUSE_BUTTON_LEFT
```

鼠标模式下作为拖拽指针的按钮。

<a id="member-gfpointergestureutility-properties-mouse_wheel_zoom_factor"></a>

### `mouse_wheel_zoom_factor`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var mouse_wheel_zoom_factor: float = 1.1
```

鼠标滚轮单步缩放因子。向下滚动会使用该值的倒数。

<a id="member-gfpointergestureutility-properties-minimum_pinch_distance"></a>

### `minimum_pinch_distance`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var minimum_pinch_distance: float = _DEFAULT_MINIMUM_PINCH_DISTANCE
```

双指距离低于该阈值时不产生缩放因子。

## 方法

<a id="member-gfpointergestureutility-methods-handle_input_event"></a>

### `handle_input_event`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func handle_input_event(event: InputEvent) -> bool:
```

处理一个输入事件。

参数：

| 名称 | 说明 |
|---|---|
| `event` | 输入事件。 |

返回：识别为受追踪手势事件时返回 true。

<a id="member-gfpointergestureutility-methods-reset_gesture"></a>

### `reset_gesture`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func reset_gesture() -> void:
```

清理当前手势状态。

<a id="member-gfpointergestureutility-methods-get_active_pointer_count"></a>

### `get_active_pointer_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_active_pointer_count() -> int:
```

获取活动指针数量。

返回：当前活动指针数量。

<a id="member-gfpointergestureutility-methods-get_gesture_snapshot"></a>

### `get_gesture_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_gesture_snapshot() -> Dictionary:
```

获取最近一次手势摘要。

返回：手势摘要副本。

结构：

- `return`: Dictionary with active, source, pointer_count, pointer_ids, center, previous_center, pan_delta, scale, rotation_delta, distance, previous_distance, and primary_pointer_id. Runtime mouse identity is -2; touch identities keep their event index.

<a id="member-gfpointergestureutility-methods-calculate_gesture"></a>

### `calculate_gesture`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func calculate_gesture( previous_points: Dictionary, current_points: Dictionary, source: StringName = &"pointer", minimum_distance: float = _DEFAULT_MINIMUM_PINCH_DISTANCE ) -> Dictionary:
```

根据上一组和当前组指针位置计算手势摘要。

参数：

| 名称 | 说明 |
|---|---|
| `previous_points` | 上一组指针位置，键为 pointer id，值为 Vector2。 |
| `current_points` | 当前指针位置，键为 pointer id，值为 Vector2。 |
| `source` | 摘要来源标识。 |
| `minimum_distance` | 缩放计算的最小安全距离。 |

返回：手势摘要字典。

结构：

- `previous_points`: Dictionary[int, Vector2] previous pointer positions.
- `current_points`: Dictionary[int, Vector2] current pointer positions.
- `return`: Dictionary with active, source, pointer_count, pointer_ids, center, previous_center, pan_delta, scale, rotation_delta, distance, previous_distance, and primary_pointer_id.
