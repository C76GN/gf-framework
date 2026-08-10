# GFInputDetectionResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/rebinding/gf_input_detection_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`8.0.0`

输入检测结束结果。 表达 GFInputDetector 一轮检测为什么结束，以及成功时捕获到的输入事件。 它不处理冲突、不修改 InputMap，也不绑定具体改键 UI 流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`FinishReason`](#member-gfinputdetectionresult-enums-finishreason) | `enum FinishReason` |
| 属性 | [`reason`](#member-gfinputdetectionresult-properties-reason) | `var reason: FinishReason = FinishReason.CANCELLED` |
| 属性 | [`input_event`](#member-gfinputdetectionresult-properties-input_event) | `var input_event: InputEvent = null` |
| 属性 | [`elapsed_seconds`](#member-gfinputdetectionresult-properties-elapsed_seconds) | `var elapsed_seconds: float = 0.0` |
| 属性 | [`value_type`](#member-gfinputdetectionresult-properties-value_type) | `var value_type: int = -1` |
| 属性 | [`allowed_device_types`](#member-gfinputdetectionresult-properties-allowed_device_types) | `var allowed_device_types: Array[int] = []` |
| 方法 | [`create`](#member-gfinputdetectionresult-methods-create) | `static func create( finish_reason: FinishReason, detected_event: InputEvent = null, detection_elapsed_seconds: float = 0.0, detection_value_type: int = -1, detection_allowed_device_types: Array[int] = [] ) -> GFInputDetectionResult:` |
| 方法 | [`is_success`](#member-gfinputdetectionresult-methods-is_success) | `func is_success() -> bool:` |
| 方法 | [`has_input_event`](#member-gfinputdetectionresult-methods-has_input_event) | `func has_input_event() -> bool:` |
| 方法 | [`to_dictionary`](#member-gfinputdetectionresult-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`reason_to_string`](#member-gfinputdetectionresult-methods-reason_to_string) | `static func reason_to_string(finish_reason: FinishReason) -> StringName:` |

## 枚举

<a id="member-gfinputdetectionresult-enums-finishreason"></a>

### `FinishReason`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
enum FinishReason {
	## 已检测到可接受输入。
	SUCCESS,
	## 调用方或取消输入结束了检测。
	CANCELLED,
	## 检测超时结束。
	TIMEOUT,
	## 新一轮检测替换了上一轮检测。
	REPLACED,
}
```

检测结束原因。

## 属性

<a id="member-gfinputdetectionresult-properties-reason"></a>

### `reason`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var reason: FinishReason = FinishReason.CANCELLED
```

检测结束原因。

<a id="member-gfinputdetectionresult-properties-input_event"></a>

### `input_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var input_event: InputEvent = null
```

捕获到的输入事件。只有 reason 为 SUCCESS 时应非空。

<a id="member-gfinputdetectionresult-properties-elapsed_seconds"></a>

### `elapsed_seconds`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var elapsed_seconds: float = 0.0
```

本轮检测从 begin 到 finish 经过的有限非负秒数。

<a id="member-gfinputdetectionresult-properties-value_type"></a>

### `value_type`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var value_type: int = -1
```

本轮检测使用的动作值类型；-1 表示未限制。

<a id="member-gfinputdetectionresult-properties-allowed_device_types"></a>

### `allowed_device_types`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var allowed_device_types: Array[int] = []
```

本轮检测允许的设备类型。

结构：

- `allowed_device_types`: Array[int]，包含 GFInputDetector.DeviceType 枚举值；为空表示未限制。

## 方法

<a id="member-gfinputdetectionresult-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func create( finish_reason: FinishReason, detected_event: InputEvent = null, detection_elapsed_seconds: float = 0.0, detection_value_type: int = -1, detection_allowed_device_types: Array[int] = [] ) -> GFInputDetectionResult:
```

创建检测结束结果。

参数：

| 名称 | 说明 |
|---|---|
| `finish_reason` | 检测结束原因。 |
| `detected_event` | 捕获到的输入事件；非成功结果应传 null。 |
| `detection_elapsed_seconds` | 本轮检测经过的秒数。 |
| `detection_value_type` | 本轮检测使用的动作值类型；-1 表示未限制。 |
| `detection_allowed_device_types` | 本轮检测允许的设备类型。 |

返回：检测结果。

结构：

- `detection_allowed_device_types`: Array[int]，包含 GFInputDetector.DeviceType 枚举值；为空表示未限制。

<a id="member-gfinputdetectionresult-methods-is_success"></a>

### `is_success`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_success() -> bool:
```

检测是否成功捕获输入事件。

返回：成功捕获输入事件时返回 true。

<a id="member-gfinputdetectionresult-methods-has_input_event"></a>

### `has_input_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_input_event() -> bool:
```

检测结果是否包含输入事件。

返回：包含输入事件时返回 true。

<a id="member-gfinputdetectionresult-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为 JSON 安全字典。即使 public elapsed_seconds 被外部改成 NaN/Infinity， 输出边界也会把它规范为 0。

返回：检测结果字典。

结构：

- `return`: Dictionary with reason, success, elapsed_seconds, value_type, allowed_device_types, and input_identity fields.

<a id="member-gfinputdetectionresult-methods-reason_to_string"></a>

### `reason_to_string`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func reason_to_string(finish_reason: FinishReason) -> StringName:
```

获取结束原因的稳定字符串。

参数：

| 名称 | 说明 |
|---|---|
| `finish_reason` | 检测结束原因。 |

返回：结束原因字符串。
