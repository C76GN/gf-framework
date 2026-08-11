# GFViewportSurfaceInputBridge

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/runtime/gf_viewport_surface_input_bridge.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

将外部表面命中桥接为 Viewport 指针事件。 调用方只提供稳定 source/device/pointer 身份、目标 Viewport 代际、 0..1 标准化表面坐标和显式单调毫秒。桥不求解射线、UV、Mesh、XR 或交互模式； 也不复制 Pointer Activity、Gesture 或 DragDrop 的所有权。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`input_forwarded`](#member-gfviewportsurfaceinputbridge-signals-input_forwarded) | `signal input_forwarded( source_id: StringName, device_id: int, pointer_id: int, capture_generation: int, target_generation: int, target: Viewport, event: InputEvent )` |
| 枚举 | [`PointerType`](#member-gfviewportsurfaceinputbridge-enums-pointertype) | `enum PointerType` |
| 方法 | [`configure_limits`](#member-gfviewportsurfaceinputbridge-methods-configure_limits) | `func configure_limits( max_active_pointers: int = _DEFAULT_MAX_ACTIVE_POINTERS, max_click_history: int = _DEFAULT_MAX_CLICK_HISTORY, double_click_interval_msec: int = _DEFAULT_DOUBLE_CLICK_INTERVAL_MSEC, double_click_distance_pixels: float = _DEFAULT_DOUBLE_CLICK_DISTANCE_PIXELS, max_pointer_timestamps: int = _DEFAULT_MAX_POINTER_TIMESTAMPS ) -> bool:` |
| 方法 | [`forward_mouse_hover`](#member-gfviewportsurfaceinputbridge-methods-forward_mouse_hover) | `func forward_mouse_hover( source_id: StringName, device_id: int, pointer_id: int, target: Viewport, target_generation: int, normalized_position: Vector2, timestamp_msec: int ) -> bool:` |
| 方法 | [`capture_pointer`](#member-gfviewportsurfaceinputbridge-methods-capture_pointer) | `func capture_pointer( source_id: StringName, device_id: int, pointer_id: int, pointer_type: PointerType, target: Viewport, target_generation: int, normalized_position: Vector2, timestamp_msec: int, mouse_button: MouseButton = MOUSE_BUTTON_LEFT ) -> GFViewportSurfaceInputCapture:` |
| 方法 | [`move_pointer`](#member-gfviewportsurfaceinputbridge-methods-move_pointer) | `func move_pointer( capture: GFViewportSurfaceInputCapture, target: Viewport, target_generation: int, normalized_position: Vector2, timestamp_msec: int ) -> bool:` |
| 方法 | [`press_mouse_button`](#member-gfviewportsurfaceinputbridge-methods-press_mouse_button) | `func press_mouse_button( capture: GFViewportSurfaceInputCapture, target: Viewport, target_generation: int, normalized_position: Vector2, timestamp_msec: int, mouse_button: MouseButton ) -> bool:` |
| 方法 | [`release_pointer`](#member-gfviewportsurfaceinputbridge-methods-release_pointer) | `func release_pointer( capture: GFViewportSurfaceInputCapture, timestamp_msec: int, mouse_button: MouseButton = MOUSE_BUTTON_LEFT ) -> bool:` |
| 方法 | [`release_pointer_on_surface`](#member-gfviewportsurfaceinputbridge-methods-release_pointer_on_surface) | `func release_pointer_on_surface( capture: GFViewportSurfaceInputCapture, target: Viewport, target_generation: int, normalized_position: Vector2, timestamp_msec: int, mouse_button: MouseButton = MOUSE_BUTTON_LEFT ) -> bool:` |
| 方法 | [`cancel_pointer`](#member-gfviewportsurfaceinputbridge-methods-cancel_pointer) | `func cancel_pointer(capture: GFViewportSurfaceInputCapture, timestamp_msec: int) -> bool:` |
| 方法 | [`cancel_source`](#member-gfviewportsurfaceinputbridge-methods-cancel_source) | `func cancel_source( source_id: StringName, timestamp_msec: int, device_id: int = -1 ) -> int:` |
| 方法 | [`cancel_target`](#member-gfviewportsurfaceinputbridge-methods-cancel_target) | `func cancel_target(target: Viewport, target_generation: int, timestamp_msec: int) -> int:` |
| 方法 | [`prune_released_captures`](#member-gfviewportsurfaceinputbridge-methods-prune_released_captures) | `func prune_released_captures(timestamp_msec: int = 0) -> int:` |
| 方法 | [`has_capture`](#member-gfviewportsurfaceinputbridge-methods-has_capture) | `func has_capture(capture: GFViewportSurfaceInputCapture) -> bool:` |
| 方法 | [`get_active_pointer_count`](#member-gfviewportsurfaceinputbridge-methods-get_active_pointer_count) | `func get_active_pointer_count() -> int:` |
| 方法 | [`get_click_history_count`](#member-gfviewportsurfaceinputbridge-methods-get_click_history_count) | `func get_click_history_count() -> int:` |
| 方法 | [`get_pointer_timestamp_count`](#member-gfviewportsurfaceinputbridge-methods-get_pointer_timestamp_count) | `func get_pointer_timestamp_count() -> int:` |
| 方法 | [`is_disposed`](#member-gfviewportsurfaceinputbridge-methods-is_disposed) | `func is_disposed() -> bool:` |
| 方法 | [`dispose`](#member-gfviewportsurfaceinputbridge-methods-dispose) | `func dispose(timestamp_msec: int = 0) -> void:` |

## 信号

<a id="member-gfviewportsurfaceinputbridge-signals-input_forwarded"></a>

### `input_forwarded`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal input_forwarded( source_id: StringName, device_id: int, pointer_id: int, capture_generation: int, target_generation: int, target: Viewport, event: InputEvent )
```

一个经过校验的指针事件已推送到目标 Viewport 后发出。

参数：

| 名称 | 说明 |
|---|---|
| `source_id` | 输入源标识。 |
| `device_id` | 设备标识。 |
| `pointer_id` | 输入源内指针标识。 |
| `capture_generation` | hover 为 0，捕获事件为桥分配的代际。 |
| `target_generation` | Resolver 提供的目标代际。 |
| `target` | 已接收事件的 Viewport。 |
| `event` | 新创建的 Mouse 或 Touch 事件。 |

## 枚举

<a id="member-gfviewportsurfaceinputbridge-enums-pointertype"></a>

### `PointerType`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum PointerType {
	## `InputEventMouseButton` / `InputEventMouseMotion`。
	MOUSE,
	## `InputEventScreenTouch` / `InputEventScreenDrag`。
	TOUCH,
}
```

输出到 Viewport 的指针事件家族。

## 方法

<a id="member-gfviewportsurfaceinputbridge-methods-configure_limits"></a>

### `configure_limits`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func configure_limits( max_active_pointers: int = _DEFAULT_MAX_ACTIVE_POINTERS, max_click_history: int = _DEFAULT_MAX_CLICK_HISTORY, double_click_interval_msec: int = _DEFAULT_DOUBLE_CLICK_INTERVAL_MSEC, double_click_distance_pixels: float = _DEFAULT_DOUBLE_CLICK_DISTANCE_PIXELS, max_pointer_timestamps: int = _DEFAULT_MAX_POINTER_TIMESTAMPS ) -> bool:
```

在首个样本前配置活动指针、跨代际时间与双击状态预算。

参数：

| 名称 | 说明 |
|---|---|
| `max_active_pointers` | 同时按下 key 上限，必须为 1..256。 |
| `max_click_history` | 双击历史上限，0 禁用历史，最大 512。 |
| `double_click_interval_msec` | 双击间隔，必须为 0..60000 毫秒。 |
| `double_click_distance_pixels` | 在当前 Viewport 尺寸下的最大双击距离，必须有限且为 0..4096。 |
| `max_pointer_timestamps` | 跨捕获代际保留的最近指针时间高水位数，必须为 1..4096。 |

返回：尚未开始、未 dispose 且所有预算合法时返回 true。

<a id="member-gfviewportsurfaceinputbridge-methods-forward_mouse_hover"></a>

### `forward_mouse_hover`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func forward_mouse_hover( source_id: StringName, device_id: int, pointer_id: int, target: Viewport, target_generation: int, normalized_position: Vector2, timestamp_msec: int ) -> bool:
```

转发未按下鼠标在表面上的 hover motion。

参数：

| 名称 | 说明 |
|---|---|
| `source_id` | 稳定 Resolver/输入源标识。 |
| `device_id` | 非负设备标识。 |
| `pointer_id` | 输入源内非负指针标识。 |
| `target` | 当前命中且已进入 SceneTree 的 Viewport。 |
| `target_generation` | Resolver 提供的正整数目标代际。 |
| `normalized_position` | 有限且两分量均为 0..1 的表面坐标。 |
| `timestamp_msec` | 非负单调毫秒；不得早于该 key 仍在预算内的时间高水位。 |

返回：输入合法、key 未捕获、时间未回退并已同步推送到目标时返回 true。

<a id="member-gfviewportsurfaceinputbridge-methods-capture_pointer"></a>

### `capture_pointer`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func capture_pointer( source_id: StringName, device_id: int, pointer_id: int, pointer_type: PointerType, target: Viewport, target_generation: int, normalized_position: Vector2, timestamp_msec: int, mouse_button: MouseButton = MOUSE_BUTTON_LEFT ) -> GFViewportSurfaceInputCapture:
```

按下指针并创建调用方必须保留的代际回执。

参数：

| 名称 | 说明 |
|---|---|
| `source_id` | 稳定 Resolver/输入源标识。 |
| `device_id` | 非负设备标识。 |
| `pointer_id` | 输入源内非负指针标识。 |
| `pointer_type` | \`PointerType.MOUSE\` 或 \`PointerType.TOUCH\`。 |
| `target` | 命中且已进入 SceneTree 的 Viewport。 |
| `target_generation` | Resolver 提供的正整数目标代际。 |
| `normalized_position` | 有限且两分量均为 0..1 的表面坐标。 |
| `timestamp_msec` | 非负单调毫秒；不得早于该 key 仍在预算内的时间高水位。 |
| `mouse_button` | 鼠标捕获的首个非滚轮按钮；Touch 时忽略。 |

返回：成功时返回新回执；时间未回退的重复同状态 press 更新最后样本并返回现有回执；失败返回 null。

<a id="member-gfviewportsurfaceinputbridge-methods-move_pointer"></a>

### `move_pointer`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func move_pointer( capture: GFViewportSurfaceInputCapture, target: Viewport, target_generation: int, normalized_position: Vector2, timestamp_msec: int ) -> bool:
```

在捕获目标内移动指针。

参数：

| 名称 | 说明 |
|---|---|
| `capture` | 按下时返回的原始回执。 |
| `target` | 当前命中 Viewport，必须与回执捕获目标相同。 |
| `target_generation` | 必须与按下时目标代际相同。 |
| `normalized_position` | 新的有限 0..1 表面坐标。 |
| `timestamp_msec` | 不得早于该捕获上一样本的单调毫秒。 |

返回：回执、目标、代际、坐标和时间都合法时返回 true。

<a id="member-gfviewportsurfaceinputbridge-methods-press_mouse_button"></a>

### `press_mouse_button`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func press_mouse_button( capture: GFViewportSurfaceInputCapture, target: Viewport, target_generation: int, normalized_position: Vector2, timestamp_msec: int, mouse_button: MouseButton ) -> bool:
```

在已捕获鼠标上增加一个非滚轮按钮。

参数：

| 名称 | 说明 |
|---|---|
| `capture` | 活动鼠标捕获回执。 |
| `target` | 与捕获相同的当前 Viewport。 |
| `target_generation` | 捕获的外部目标代际。 |
| `normalized_position` | 有限 0..1 表面坐标。 |
| `timestamp_msec` | 非回退单调毫秒。 |
| `mouse_button` | 待按下的非滚轮按钮。 |

返回：新按钮已推送或该按钮已处于按下状态时返回 true。

<a id="member-gfviewportsurfaceinputbridge-methods-release_pointer"></a>

### `release_pointer`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func release_pointer( capture: GFViewportSurfaceInputCapture, timestamp_msec: int, mouse_button: MouseButton = MOUSE_BUTTON_LEFT ) -> bool:
```

在最后一个合法表面位置释放指针或鼠标按钮。

参数：

| 名称 | 说明 |
|---|---|
| `capture` | 活动捕获回执。 |
| `timestamp_msec` | 非回退单调毫秒。 |
| `mouse_button` | 鼠标待释放的受支持非滚轮按钮；Touch 时忽略。 |

返回：回执仍为当前代际，且按钮已释放或已处于释放状态时返回 true；不支持的鼠标按钮返回 false。

<a id="member-gfviewportsurfaceinputbridge-methods-release_pointer_on_surface"></a>

### `release_pointer_on_surface`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func release_pointer_on_surface( capture: GFViewportSurfaceInputCapture, target: Viewport, target_generation: int, normalized_position: Vector2, timestamp_msec: int, mouse_button: MouseButton = MOUSE_BUTTON_LEFT ) -> bool:
```

更新最后合法表面位置后释放指针或鼠标按钮。

参数：

| 名称 | 说明 |
|---|---|
| `capture` | 活动捕获回执。 |
| `target` | 与捕获相同的当前 Viewport。 |
| `target_generation` | 捕获的外部目标代际。 |
| `normalized_position` | 终止时有限 0..1 表面坐标。 |
| `timestamp_msec` | 非回退单调毫秒。 |
| `mouse_button` | 鼠标待释放的受支持非滚轮按钮；Touch 时忽略。 |

返回：位置与捕获身份合法，且按钮已释放或已处于释放状态时返回 true；不支持的鼠标按钮返回 false。

<a id="member-gfviewportsurfaceinputbridge-methods-cancel_pointer"></a>

### `cancel_pointer`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel_pointer(capture: GFViewportSurfaceInputCapture, timestamp_msec: int) -> bool:
```

在最后合法位置取消整个指针捕获。

参数：

| 名称 | 说明 |
|---|---|
| `capture` | 活动捕获回执。 |
| `timestamp_msec` | 非回退单调毫秒。 |

返回：回执匹配当前代际且捕获已清理时返回 true。

<a id="member-gfviewportsurfaceinputbridge-methods-cancel_source"></a>

### `cancel_source`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel_source( source_id: StringName, timestamp_msec: int, device_id: int = -1 ) -> int:
```

取消指定输入源的全部捕获，并清除调用前已结束指针的双击与时间状态。

参数：

| 名称 | 说明 |
|---|---|
| `source_id` | 待清理的输入源标识。 |
| `timestamp_msec` | 终止样本单调毫秒，早于捕获最新样本时自动使用最新值。 |
| `device_id` | -1 表示该 source 的全部设备，否则只清理指定非负设备。 |

返回：本次移除的捕获数。

<a id="member-gfviewportsurfaceinputbridge-methods-cancel_target"></a>

### `cancel_target`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel_target(target: Viewport, target_generation: int, timestamp_msec: int) -> int:
```

取消指定 Viewport 外部代际的全部捕获。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 待失效的 Viewport。 |
| `target_generation` | 只清理与该正整数外部代际完全匹配的捕获。 |
| `timestamp_msec` | 终止样本单调毫秒。 |

返回：本次移除的捕获数。

<a id="member-gfviewportsurfaceinputbridge-methods-prune_released_captures"></a>

### `prune_released_captures`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func prune_released_captures(timestamp_msec: int = 0) -> int:
```

清理回执、目标或 SceneTree 生命周期已结束的捕获。

参数：

| 名称 | 说明 |
|---|---|
| `timestamp_msec` | 活目标补发 cancel 时的单调毫秒。 |

返回：本次移除的捕获数。

<a id="member-gfviewportsurfaceinputbridge-methods-has_capture"></a>

### `has_capture`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func has_capture(capture: GFViewportSurfaceInputCapture) -> bool:
```

检查回执是否仍指向当前活动捕获。

参数：

| 名称 | 说明 |
|---|---|
| `capture` | 待检查回执。 |

返回：桥、key、代际、回执对象和弱目标均仍匹配时返回 true。

<a id="member-gfviewportsurfaceinputbridge-methods-get_active_pointer_count"></a>

### `get_active_pointer_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_active_pointer_count() -> int:
```

获取当前活动指针 key 数。

返回：不超过配置预算的捕获数。

<a id="member-gfviewportsurfaceinputbridge-methods-get_click_history_count"></a>

### `get_click_history_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_click_history_count() -> int:
```

获取当前双击历史数。

返回：不超过配置预算的历史条目数。

<a id="member-gfviewportsurfaceinputbridge-methods-get_pointer_timestamp_count"></a>

### `get_pointer_timestamp_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_pointer_timestamp_count() -> int:
```

获取当前跨代际指针时间高水位数。

返回：不超过配置预算的最近指针 key 数。

<a id="member-gfviewportsurfaceinputbridge-methods-is_disposed"></a>

### `is_disposed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_disposed() -> bool:
```

检查桥是否已进入不可复用终态。

返回：[method dispose] 已调用时返回 true。

<a id="member-gfviewportsurfaceinputbridge-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func dispose(timestamp_msec: int = 0) -> void:
```

取消所有活动捕获并清空有界历史。

参数：

| 名称 | 说明 |
|---|---|
| `timestamp_msec` | 终止样本单调毫秒；负数视为 0。 |
