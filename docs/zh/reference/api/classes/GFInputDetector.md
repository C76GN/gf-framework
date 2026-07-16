# GFInputDetector

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/rebinding/gf_input_detector.gd`
- 模块：`Standard`
- 继承：`Node`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

检测下一次输入事件的辅助节点。 可用于项目自己的改键界面。检测结果只返回 Godot InputEvent，冲突处理由项目层决定。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`detection_started`](#member-gfinputdetector-signals-detection_started) | `signal detection_started` |
| 信号 | [`input_detected`](#member-gfinputdetector-signals-input_detected) | `signal input_detected(input_event: InputEvent)` |
| 信号 | [`detection_finished`](#member-gfinputdetector-signals-detection_finished) | `signal detection_finished(result: GFInputDetectionResult)` |
| 枚举 | [`DeviceType`](#member-gfinputdetector-enums-devicetype) | `enum DeviceType` |
| 枚举 | [`DetectionState`](#member-gfinputdetector-enums-detectionstate) | `enum DetectionState` |
| 属性 | [`ignore_echo`](#member-gfinputdetector-properties-ignore_echo) | `var ignore_echo: bool = true` |
| 属性 | [`minimum_axis_amplitude`](#member-gfinputdetector-properties-minimum_axis_amplitude) | `var minimum_axis_amplitude: float = 0.25` |
| 属性 | [`countdown_seconds`](#member-gfinputdetector-properties-countdown_seconds) | `var countdown_seconds: float = 0.0` |
| 属性 | [`timeout_seconds`](#member-gfinputdetector-properties-timeout_seconds) | `var timeout_seconds: float = 0.0` |
| 属性 | [`abort_events`](#member-gfinputdetector-properties-abort_events) | `var abort_events: Array[InputEvent] = []` |
| 属性 | [`wait_for_clear_before_detection`](#member-gfinputdetector-properties-wait_for_clear_before_detection) | `var wait_for_clear_before_detection: bool = true` |
| 属性 | [`wait_for_clear_after_detection`](#member-gfinputdetector-properties-wait_for_clear_after_detection) | `var wait_for_clear_after_detection: bool = false` |
| 方法 | [`begin_detection`](#member-gfinputdetector-methods-begin_detection) | `func begin_detection(allowed_device_types: Array[int] = []) -> void:` |
| 方法 | [`begin_detection_for_value_type`](#member-gfinputdetector-methods-begin_detection_for_value_type) | `func begin_detection_for_value_type( value_type: GFInputAction.ValueType, allowed_device_types: Array[int] = [] ) -> void:` |
| 方法 | [`begin_detection_for_action`](#member-gfinputdetector-methods-begin_detection_for_action) | `func begin_detection_for_action( action: GFInputAction, allowed_device_types: Array[int] = [] ) -> void:` |
| 方法 | [`detect_bool`](#member-gfinputdetector-methods-detect_bool) | `func detect_bool(allowed_device_types: Array[int] = []) -> void:` |
| 方法 | [`detect_axis_1d`](#member-gfinputdetector-methods-detect_axis_1d) | `func detect_axis_1d(allowed_device_types: Array[int] = []) -> void:` |
| 方法 | [`detect_axis_2d`](#member-gfinputdetector-methods-detect_axis_2d) | `func detect_axis_2d(allowed_device_types: Array[int] = []) -> void:` |
| 方法 | [`detect_axis_3d`](#member-gfinputdetector-methods-detect_axis_3d) | `func detect_axis_3d(allowed_device_types: Array[int] = []) -> void:` |
| 方法 | [`get_countdown_remaining`](#member-gfinputdetector-methods-get_countdown_remaining) | `func get_countdown_remaining() -> float:` |
| 方法 | [`get_detection_state`](#member-gfinputdetector-methods-get_detection_state) | `func get_detection_state() -> DetectionState:` |
| 方法 | [`is_accepting_input`](#member-gfinputdetector-methods-is_accepting_input) | `func is_accepting_input() -> bool:` |
| 方法 | [`cancel_detection`](#member-gfinputdetector-methods-cancel_detection) | `func cancel_detection() -> void:` |
| 方法 | [`is_detecting`](#member-gfinputdetector-methods-is_detecting) | `func is_detecting() -> bool:` |
| 方法 | [`get_last_detection_result`](#member-gfinputdetector-methods-get_last_detection_result) | `func get_last_detection_result() -> GFInputDetectionResult:` |

## 信号

<a id="member-gfinputdetector-signals-detection_started"></a>

### `detection_started`

- API：`public`

```gdscript
signal detection_started
```

开始检测时发出。

<a id="member-gfinputdetector-signals-input_detected"></a>

### `input_detected`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal input_detected(input_event: InputEvent)
```

检测结束时发出。input_event 为 null 表示取消或超时。

参数：

| 名称 | 说明 |
|---|---|
| `input_event` | 检测到的输入事件；取消或超时时为 null。 |

<a id="member-gfinputdetector-signals-detection_finished"></a>

### `detection_finished`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal detection_finished(result: GFInputDetectionResult)
```

检测结束时发出结构化结果。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 检测结束结果。 |

## 枚举

<a id="member-gfinputdetector-enums-devicetype"></a>

### `DeviceType`

- API：`public`

```gdscript
enum DeviceType {
	## 键盘输入。
	KEYBOARD,
	## 鼠标输入。
	MOUSE,
	## 手柄按钮或轴输入。
	JOYPAD,
	## 触屏输入。
	TOUCH,
}
```

设备过滤类型。

<a id="member-gfinputdetector-enums-detectionstate"></a>

### `DetectionState`

- API：`public`

```gdscript
enum DetectionState {
	## 未检测。
	IDLE,
	## 倒计时中。
	COUNTDOWN,
	## 等待取消输入释放。
	PRE_CLEAR,
	## 正在接收候选输入。
	DETECTING,
	## 等待检测到的输入释放。
	POST_CLEAR,
}
```

检测阶段。

## 属性

<a id="member-gfinputdetector-properties-ignore_echo"></a>

### `ignore_echo`

- API：`public`

```gdscript
var ignore_echo: bool = true
```

是否忽略键盘 echo 事件。

<a id="member-gfinputdetector-properties-minimum_axis_amplitude"></a>

### `minimum_axis_amplitude`

- API：`public`

```gdscript
var minimum_axis_amplitude: float = 0.25
```

轴输入检测阈值。

<a id="member-gfinputdetector-properties-countdown_seconds"></a>

### `countdown_seconds`

- API：`public`

```gdscript
var countdown_seconds: float = 0.0
```

正式接收输入前的倒计时。可用于改键界面避开确认按钮本身。

<a id="member-gfinputdetector-properties-timeout_seconds"></a>

### `timeout_seconds`

- API：`public`

```gdscript
var timeout_seconds: float = 0.0
```

检测超时时间。小于等于 0 表示不超时。

<a id="member-gfinputdetector-properties-abort_events"></a>

### `abort_events`

- API：`public`

```gdscript
var abort_events: Array[InputEvent] = []
```

取消检测的输入事件列表。

结构：

- `abort_events`: Array[InputEvent] used to cancel detection or wait for release before accepting input.

<a id="member-gfinputdetector-properties-wait_for_clear_before_detection"></a>

### `wait_for_clear_before_detection`

- API：`public`

```gdscript
var wait_for_clear_before_detection: bool = true
```

开始正式检测前，是否等待 abort_events 中仍按住的输入释放。

<a id="member-gfinputdetector-properties-wait_for_clear_after_detection"></a>

### `wait_for_clear_after_detection`

- API：`public`

```gdscript
var wait_for_clear_after_detection: bool = false
```

检测到输入后，是否等待该输入释放再发出 input_detected。

## 方法

<a id="member-gfinputdetector-methods-begin_detection"></a>

### `begin_detection`

- API：`public`

```gdscript
func begin_detection(allowed_device_types: Array[int] = []) -> void:
```

开始检测下一次输入。

参数：

| 名称 | 说明 |
|---|---|
| `allowed_device_types` | 允许的设备类型。空数组表示不限制。 |

结构：

- `allowed_device_types`: Array[int]，包含 DeviceType 枚举值；为空表示不过滤设备。

<a id="member-gfinputdetector-methods-begin_detection_for_value_type"></a>

### `begin_detection_for_value_type`

- API：`public`

```gdscript
func begin_detection_for_value_type( value_type: GFInputAction.ValueType, allowed_device_types: Array[int] = [] ) -> void:
```

按动作值类型开始检测下一次输入。

参数：

| 名称 | 说明 |
|---|---|
| `value_type` | 期望的动作值类型。 |
| `allowed_device_types` | 允许的设备类型。空数组表示不限制。 |

结构：

- `allowed_device_types`: Array[int]，包含 DeviceType 枚举值；为空表示不过滤设备。

<a id="member-gfinputdetector-methods-begin_detection_for_action"></a>

### `begin_detection_for_action`

- API：`public`

```gdscript
func begin_detection_for_action( action: GFInputAction, allowed_device_types: Array[int] = [] ) -> void:
```

按动作资源开始检测下一次输入。

参数：

| 名称 | 说明 |
|---|---|
| `action` | 输入动作资源。 |
| `allowed_device_types` | 允许的设备类型。空数组表示不限制。 |

结构：

- `allowed_device_types`: Array[int]，包含 DeviceType 枚举值；为空表示不过滤设备。

<a id="member-gfinputdetector-methods-detect_bool"></a>

### `detect_bool`

- API：`public`

```gdscript
func detect_bool(allowed_device_types: Array[int] = []) -> void:
```

开始检测布尔输入。

参数：

| 名称 | 说明 |
|---|---|
| `allowed_device_types` | 允许的设备类型。空数组表示不限制。 |

结构：

- `allowed_device_types`: Array[int]，包含 DeviceType 枚举值；为空表示不过滤设备。

<a id="member-gfinputdetector-methods-detect_axis_1d"></a>

### `detect_axis_1d`

- API：`public`

```gdscript
func detect_axis_1d(allowed_device_types: Array[int] = []) -> void:
```

开始检测一维轴输入。

参数：

| 名称 | 说明 |
|---|---|
| `allowed_device_types` | 允许的设备类型。空数组表示不限制。 |

结构：

- `allowed_device_types`: Array[int]，包含 DeviceType 枚举值；为空表示不过滤设备。

<a id="member-gfinputdetector-methods-detect_axis_2d"></a>

### `detect_axis_2d`

- API：`public`

```gdscript
func detect_axis_2d(allowed_device_types: Array[int] = []) -> void:
```

开始检测二维轴输入。

参数：

| 名称 | 说明 |
|---|---|
| `allowed_device_types` | 允许的设备类型。空数组表示不限制。 |

结构：

- `allowed_device_types`: Array[int]，包含 DeviceType 枚举值；为空表示不过滤设备。

<a id="member-gfinputdetector-methods-detect_axis_3d"></a>

### `detect_axis_3d`

- API：`public`

```gdscript
func detect_axis_3d(allowed_device_types: Array[int] = []) -> void:
```

开始检测三维轴输入。

参数：

| 名称 | 说明 |
|---|---|
| `allowed_device_types` | 允许的设备类型。空数组表示不限制。 |

结构：

- `allowed_device_types`: Array[int]，包含 DeviceType 枚举值；为空表示不过滤设备。

<a id="member-gfinputdetector-methods-get_countdown_remaining"></a>

### `get_countdown_remaining`

- API：`public`

```gdscript
func get_countdown_remaining() -> float:
```

获取正式接收输入前剩余的倒计时秒数。

返回：剩余秒数。

<a id="member-gfinputdetector-methods-get_detection_state"></a>

### `get_detection_state`

- API：`public`

```gdscript
func get_detection_state() -> DetectionState:
```

获取当前检测阶段。

返回：检测阶段。

<a id="member-gfinputdetector-methods-is_accepting_input"></a>

### `is_accepting_input`

- API：`public`

```gdscript
func is_accepting_input() -> bool:
```

是否已经结束倒计时并正在接收候选输入。

返回：是否可接收输入。

<a id="member-gfinputdetector-methods-cancel_detection"></a>

### `cancel_detection`

- API：`public`

```gdscript
func cancel_detection() -> void:
```

取消检测。

<a id="member-gfinputdetector-methods-is_detecting"></a>

### `is_detecting`

- API：`public`

```gdscript
func is_detecting() -> bool:
```

检查当前是否正在检测。

返回：是否正在检测。

<a id="member-gfinputdetector-methods-get_last_detection_result"></a>

### `get_last_detection_result`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_last_detection_result() -> GFInputDetectionResult:
```

获取最近一次检测结束结果。

返回：最近一次检测结束结果；尚未结束过检测时返回 null。
