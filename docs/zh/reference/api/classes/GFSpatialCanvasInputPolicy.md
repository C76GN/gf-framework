# GFSpatialCanvasInputPolicy

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/spatial_canvas/gf_spatial_canvas_input_policy.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`unreleased`

空间画布输入解释策略。 以数据方式声明平移、选择、滚轮、触摸和取消输入。策略不持有节点、 Viewport 或父容器引用；[code]GFSpatialCanvas2D[/code] 只接受完整校验通过的隔离副本。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`ModifierMask`](#member-gfspatialcanvasinputpolicy-enums-modifiermask) | `enum ModifierMask` |
| 枚举 | [`WheelAxis`](#member-gfspatialcanvasinputpolicy-enums-wheelaxis) | `enum WheelAxis` |
| 枚举 | [`WheelRouting`](#member-gfspatialcanvasinputpolicy-enums-wheelrouting) | `enum WheelRouting` |
| 枚举 | [`TouchPrimaryBehavior`](#member-gfspatialcanvasinputpolicy-enums-touchprimarybehavior) | `enum TouchPrimaryBehavior` |
| 常量 | [`ABSOLUTE_MAX_SELECTION_MODIFIER_BINDINGS`](#member-gfspatialcanvasinputpolicy-constants-absolute_max_selection_modifier_bindings) | `const ABSOLUTE_MAX_SELECTION_MODIFIER_BINDINGS: int = 15` |
| 常量 | [`ABSOLUTE_MAX_ACTION_EVENTS`](#member-gfspatialcanvasinputpolicy-constants-absolute_max_action_events) | `const ABSOLUTE_MAX_ACTION_EVENTS: int = 64` |
| 属性 | [`pan_mouse_button`](#member-gfspatialcanvasinputpolicy-properties-pan_mouse_button) | `var pan_mouse_button: MouseButton = MOUSE_BUTTON_MIDDLE` |
| 属性 | [`pan_action`](#member-gfspatialcanvasinputpolicy-properties-pan_action) | `var pan_action: StringName = &""` |
| 属性 | [`pan_modifier_mask`](#member-gfspatialcanvasinputpolicy-properties-pan_modifier_mask) | `var pan_modifier_mask: int = ModifierMask.NONE` |
| 属性 | [`selection_mouse_button`](#member-gfspatialcanvasinputpolicy-properties-selection_mouse_button) | `var selection_mouse_button: MouseButton = MOUSE_BUTTON_LEFT` |
| 属性 | [`selection_action`](#member-gfspatialcanvasinputpolicy-properties-selection_action) | `var selection_action: StringName = &""` |
| 属性 | [`selection_default_mode`](#member-gfspatialcanvasinputpolicy-properties-selection_default_mode) | `var selection_default_mode: GFSpatialCanvas2D.SelectionMode = ( 	GFSpatialCanvas2D.SelectionMode.REPLACE )` |
| 属性 | [`selection_modifier_bindings`](#member-gfspatialcanvasinputpolicy-properties-selection_modifier_bindings) | `var selection_modifier_bindings: Array[GFSpatialCanvasSelectionModeBinding] = []` |
| 属性 | [`drag_threshold`](#member-gfspatialcanvasinputpolicy-properties-drag_threshold) | `var drag_threshold: float = 4.0` |
| 属性 | [`wheel_axis`](#member-gfspatialcanvasinputpolicy-properties-wheel_axis) | `var wheel_axis: WheelAxis = WheelAxis.VERTICAL` |
| 属性 | [`wheel_routing`](#member-gfspatialcanvasinputpolicy-properties-wheel_routing) | `var wheel_routing: WheelRouting = WheelRouting.CANVAS` |
| 属性 | [`wheel_modifier_mask`](#member-gfspatialcanvasinputpolicy-properties-wheel_modifier_mask) | `var wheel_modifier_mask: int = ModifierMask.NONE` |
| 属性 | [`wheel_zoom_factor`](#member-gfspatialcanvasinputpolicy-properties-wheel_zoom_factor) | `var wheel_zoom_factor: float = 1.1` |
| 属性 | [`touch_enabled`](#member-gfspatialcanvasinputpolicy-properties-touch_enabled) | `var touch_enabled: bool = true` |
| 属性 | [`touch_primary_behavior`](#member-gfspatialcanvasinputpolicy-properties-touch_primary_behavior) | `var touch_primary_behavior: TouchPrimaryBehavior = TouchPrimaryBehavior.PAN` |
| 属性 | [`touch_multi_pan_enabled`](#member-gfspatialcanvasinputpolicy-properties-touch_multi_pan_enabled) | `var touch_multi_pan_enabled: bool = true` |
| 属性 | [`touch_multi_zoom_enabled`](#member-gfspatialcanvasinputpolicy-properties-touch_multi_zoom_enabled) | `var touch_multi_zoom_enabled: bool = true` |
| 属性 | [`system_pan_gesture_enabled`](#member-gfspatialcanvasinputpolicy-properties-system_pan_gesture_enabled) | `var system_pan_gesture_enabled: bool = true` |
| 属性 | [`system_magnify_gesture_enabled`](#member-gfspatialcanvasinputpolicy-properties-system_magnify_gesture_enabled) | `var system_magnify_gesture_enabled: bool = true` |
| 属性 | [`placement_cancel_action`](#member-gfspatialcanvasinputpolicy-properties-placement_cancel_action) | `var placement_cancel_action: StringName = &"ui_cancel"` |
| 属性 | [`consume_handled_events`](#member-gfspatialcanvasinputpolicy-properties-consume_handled_events) | `var consume_handled_events: bool = true` |
| 属性 | [`consume_wheel_events`](#member-gfspatialcanvasinputpolicy-properties-consume_wheel_events) | `var consume_wheel_events: bool = true` |
| 方法 | [`validate_policy`](#member-gfspatialcanvasinputpolicy-methods-validate_policy) | `func validate_policy() -> Dictionary:` |
| 方法 | [`duplicate_policy`](#member-gfspatialcanvasinputpolicy-methods-duplicate_policy) | `func duplicate_policy() -> GFSpatialCanvasInputPolicy:` |

## 枚举

<a id="member-gfspatialcanvasinputpolicy-enums-modifiermask"></a>

### `ModifierMask`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum ModifierMask {
	## 不要求修饰键。
	NONE = 0,
	## Shift 修饰键。
	SHIFT = 1,
	## Ctrl 修饰键。
	CTRL = 2,
	## Alt 修饰键。
	ALT = 4,
	## Meta 修饰键。
	META = 8,
}
```

输入修饰键位掩码。

<a id="member-gfspatialcanvasinputpolicy-enums-wheelaxis"></a>

### `WheelAxis`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum WheelAxis {
	## 使用向上/向下滚轮事件。
	VERTICAL,
	## 使用向左/向右滚轮事件。
	HORIZONTAL,
}
```

滚轮缩放使用的物理轴。

<a id="member-gfspatialcanvasinputpolicy-enums-wheelrouting"></a>

### `WheelRouting`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum WheelRouting {
	## 画布处理目标轴上的所有滚轮事件。
	CANVAS,
	## 只有修饰键掩码精确匹配时由画布处理。
	MODIFIER_GATED,
	## 画布始终忽略滚轮，让 GUI 祖先继续处理。
	PARENT_ONLY,
}
```

滚轮事件的画布路由策略。

<a id="member-gfspatialcanvasinputpolicy-enums-touchprimarybehavior"></a>

### `TouchPrimaryBehavior`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum TouchPrimaryBehavior {
	## 单指不执行画布行为；若启用任一多指行为，首触点仍会被捕获以等待后续触点。
	NONE,
	## 单指拖动平移画布。
	PAN,
	## 单指执行点选、框选或放置确认。
	SELECT,
}
```

单指触摸的主行为。

## 常量

<a id="member-gfspatialcanvasinputpolicy-constants-absolute_max_selection_modifier_bindings"></a>

### `ABSOLUTE_MAX_SELECTION_MODIFIER_BINDINGS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_SELECTION_MODIFIER_BINDINGS: int = 15
```

单份策略允许声明的选择修饰键绑定绝对上限。

<a id="member-gfspatialcanvasinputpolicy-constants-absolute_max_action_events"></a>

### `ABSOLUTE_MAX_ACTION_EVENTS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_ACTION_EVENTS: int = 64
```

校验单个 InputMap action 时允许扫描的事件绝对上限。

## 属性

<a id="member-gfspatialcanvasinputpolicy-properties-pan_mouse_button"></a>

### `pan_mouse_button`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var pan_mouse_button: MouseButton = MOUSE_BUTTON_MIDDLE
```

直接触发平移捕获的鼠标按钮；[constant MOUSE_BUTTON_NONE] 表示禁用直接按钮。

<a id="member-gfspatialcanvasinputpolicy-properties-pan_action"></a>

### `pan_action`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var pan_action: StringName = &""
```

通过 InputMap 触发平移捕获的动作；空名称表示禁用动作绑定。

<a id="member-gfspatialcanvasinputpolicy-properties-pan_modifier_mask"></a>

### `pan_modifier_mask`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var pan_modifier_mask: int = ModifierMask.NONE
```

直接平移按钮必须精确匹配的修饰键掩码。 使用 [member pan_action] 时修饰键由 InputMap action 精确声明，本字段必须为 NONE。

<a id="member-gfspatialcanvasinputpolicy-properties-selection_mouse_button"></a>

### `selection_mouse_button`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var selection_mouse_button: MouseButton = MOUSE_BUTTON_LEFT
```

直接触发选择捕获的鼠标按钮；[constant MOUSE_BUTTON_NONE] 表示禁用直接按钮。

<a id="member-gfspatialcanvasinputpolicy-properties-selection_action"></a>

### `selection_action`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var selection_action: StringName = &""
```

通过 InputMap 触发选择捕获的动作；空名称表示禁用动作绑定。

<a id="member-gfspatialcanvasinputpolicy-properties-selection_default_mode"></a>

### `selection_default_mode`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var selection_default_mode: GFSpatialCanvas2D.SelectionMode = (
	GFSpatialCanvas2D.SelectionMode.REPLACE
)
```

没有选择修饰键绑定精确匹配时使用的 [code]GFSpatialCanvas2D.SelectionMode[/code]。

<a id="member-gfspatialcanvasinputpolicy-properties-selection_modifier_bindings"></a>

### `selection_modifier_bindings`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var selection_modifier_bindings: Array[GFSpatialCanvasSelectionModeBinding] = []
```

修饰键到选择模式的精确匹配表；重复掩码会使策略校验失败。

<a id="member-gfspatialcanvasinputpolicy-properties-drag_threshold"></a>

### `drag_threshold`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var drag_threshold: float = 4.0
```

区分点选和框选的局部画布像素阈值。

<a id="member-gfspatialcanvasinputpolicy-properties-wheel_axis"></a>

### `wheel_axis`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var wheel_axis: WheelAxis = WheelAxis.VERTICAL
```

用于画布缩放的滚轮轴。

<a id="member-gfspatialcanvasinputpolicy-properties-wheel_routing"></a>

### `wheel_routing`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var wheel_routing: WheelRouting = WheelRouting.CANVAS
```

滚轮缩放路由策略。

<a id="member-gfspatialcanvasinputpolicy-properties-wheel_modifier_mask"></a>

### `wheel_modifier_mask`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var wheel_modifier_mask: int = ModifierMask.NONE
```

[constant WheelRouting.MODIFIER_GATED] 下必须精确匹配的修饰键掩码。

<a id="member-gfspatialcanvasinputpolicy-properties-wheel_zoom_factor"></a>

### `wheel_zoom_factor`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var wheel_zoom_factor: float = 1.1
```

每个滚轮刻度的缩放倍率，必须为有限且大于 1 的值。

<a id="member-gfspatialcanvasinputpolicy-properties-touch_enabled"></a>

### `touch_enabled`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var touch_enabled: bool = true
```

是否处理原始 ScreenTouch / ScreenDrag 事件。

<a id="member-gfspatialcanvasinputpolicy-properties-touch_primary_behavior"></a>

### `touch_primary_behavior`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var touch_primary_behavior: TouchPrimaryBehavior = TouchPrimaryBehavior.PAN
```

单指触摸的主行为。

<a id="member-gfspatialcanvasinputpolicy-properties-touch_multi_pan_enabled"></a>

### `touch_multi_pan_enabled`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var touch_multi_pan_enabled: bool = true
```

是否允许双指及以上触点驱动平移。

<a id="member-gfspatialcanvasinputpolicy-properties-touch_multi_zoom_enabled"></a>

### `touch_multi_zoom_enabled`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var touch_multi_zoom_enabled: bool = true
```

是否允许双指及以上触点驱动捏合缩放。

<a id="member-gfspatialcanvasinputpolicy-properties-system_pan_gesture_enabled"></a>

### `system_pan_gesture_enabled`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var system_pan_gesture_enabled: bool = true
```

是否处理 Godot 的系统 PanGesture 事件。

<a id="member-gfspatialcanvasinputpolicy-properties-system_magnify_gesture_enabled"></a>

### `system_magnify_gesture_enabled`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var system_magnify_gesture_enabled: bool = true
```

是否处理 Godot 的系统 MagnifyGesture 事件。

<a id="member-gfspatialcanvasinputpolicy-properties-placement_cancel_action"></a>

### `placement_cancel_action`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var placement_cancel_action: StringName = &"ui_cancel"
```

取消活动放置或瞬态选择的非指针 InputMap 动作；空名称表示禁用取消输入。 动作不得包含鼠标、触摸或位置手势事件，避免取消优先级饿死画布指针行为。

<a id="member-gfspatialcanvasinputpolicy-properties-consume_handled_events"></a>

### `consume_handled_events`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var consume_handled_events: bool = true
```

一般已处理事件是否由 Canvas GUI 边界消费。

<a id="member-gfspatialcanvasinputpolicy-properties-consume_wheel_events"></a>

### `consume_wheel_events`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var consume_wheel_events: bool = true
```

已处理滚轮事件是否由 Canvas GUI 边界消费。

## 方法

<a id="member-gfspatialcanvasinputpolicy-methods-validate_policy"></a>

### `validate_policy`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func validate_policy() -> Dictionary:
```

校验完整策略。 校验失败时调用方必须保留上一份有效策略；报告遵循 [code]GFValidationReportDictionary[/code] 结构。

返回：策略校验报告。

结构：

- `return`: GFValidationReportDictionary-compatible report with issues describing invalid fields.

<a id="member-gfspatialcanvasinputpolicy-methods-duplicate_policy"></a>

### `duplicate_policy`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_policy() -> GFSpatialCanvasInputPolicy:
```

创建策略及嵌套选择绑定的隔离副本。

返回：新策略。
