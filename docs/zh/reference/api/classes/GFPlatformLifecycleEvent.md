# GFPlatformLifecycleEvent

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/platform/gf_platform_lifecycle_event.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`8.0.0`

平台生命周期事件。 用纯数据表达平台 adapter 观察到的前后台、窗口、网络、输入法或资源压力等事件。 它不订阅任何平台回调，也不持有场景树状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`TYPE_FOREGROUND`](#member-gfplatformlifecycleevent-constants-type_foreground) | `const TYPE_FOREGROUND: StringName = &"foreground"` |
| 常量 | [`TYPE_BACKGROUND`](#member-gfplatformlifecycleevent-constants-type_background) | `const TYPE_BACKGROUND: StringName = &"background"` |
| 常量 | [`TYPE_WINDOW_RESIZED`](#member-gfplatformlifecycleevent-constants-type_window_resized) | `const TYPE_WINDOW_RESIZED: StringName = &"window_resized"` |
| 常量 | [`TYPE_SAFE_AREA_CHANGED`](#member-gfplatformlifecycleevent-constants-type_safe_area_changed) | `const TYPE_SAFE_AREA_CHANGED: StringName = &"safe_area_changed"` |
| 常量 | [`TYPE_NETWORK_CHANGED`](#member-gfplatformlifecycleevent-constants-type_network_changed) | `const TYPE_NETWORK_CHANGED: StringName = &"network_changed"` |
| 常量 | [`TYPE_KEYBOARD_SHOWN`](#member-gfplatformlifecycleevent-constants-type_keyboard_shown) | `const TYPE_KEYBOARD_SHOWN: StringName = &"keyboard_shown"` |
| 常量 | [`TYPE_KEYBOARD_HIDDEN`](#member-gfplatformlifecycleevent-constants-type_keyboard_hidden) | `const TYPE_KEYBOARD_HIDDEN: StringName = &"keyboard_hidden"` |
| 常量 | [`TYPE_MEMORY_WARNING`](#member-gfplatformlifecycleevent-constants-type_memory_warning) | `const TYPE_MEMORY_WARNING: StringName = &"memory_warning"` |
| 属性 | [`event_type`](#member-gfplatformlifecycleevent-properties-event_type) | `var event_type: StringName = &""` |
| 属性 | [`platform_id`](#member-gfplatformlifecycleevent-properties-platform_id) | `var platform_id: StringName = &""` |
| 属性 | [`sequence`](#member-gfplatformlifecycleevent-properties-sequence) | `var sequence: int = 0` |
| 属性 | [`timestamp_msec`](#member-gfplatformlifecycleevent-properties-timestamp_msec) | `var timestamp_msec: int = 0` |
| 属性 | [`payload`](#member-gfplatformlifecycleevent-properties-payload) | `var payload: Dictionary = {}` |
| 属性 | [`metadata`](#member-gfplatformlifecycleevent-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfplatformlifecycleevent-methods-configure) | `func configure( p_event_type: StringName, p_platform_id: StringName = &"", p_payload: Dictionary = {}, p_sequence: int = 0, p_timestamp_msec: int = 0, p_metadata: Dictionary = {} ) -> GFPlatformLifecycleEvent:` |
| 方法 | [`is_type`](#member-gfplatformlifecycleevent-methods-is_type) | `func is_type(expected_type: StringName) -> bool:` |
| 方法 | [`to_dict`](#member-gfplatformlifecycleevent-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfplatformlifecycleevent-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_event`](#member-gfplatformlifecycleevent-methods-duplicate_event) | `func duplicate_event() -> GFPlatformLifecycleEvent:` |
| 方法 | [`from_dict`](#member-gfplatformlifecycleevent-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFPlatformLifecycleEvent:` |

## 常量

<a id="member-gfplatformlifecycleevent-constants-type_foreground"></a>

### `TYPE_FOREGROUND`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const TYPE_FOREGROUND: StringName = &"foreground"
```

平台进入前台或恢复可交互。

<a id="member-gfplatformlifecycleevent-constants-type_background"></a>

### `TYPE_BACKGROUND`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const TYPE_BACKGROUND: StringName = &"background"
```

平台进入后台、挂起或不可交互。

<a id="member-gfplatformlifecycleevent-constants-type_window_resized"></a>

### `TYPE_WINDOW_RESIZED`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const TYPE_WINDOW_RESIZED: StringName = &"window_resized"
```

窗口尺寸或显示区域变化。

<a id="member-gfplatformlifecycleevent-constants-type_safe_area_changed"></a>

### `TYPE_SAFE_AREA_CHANGED`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const TYPE_SAFE_AREA_CHANGED: StringName = &"safe_area_changed"
```

安全区域变化。

<a id="member-gfplatformlifecycleevent-constants-type_network_changed"></a>

### `TYPE_NETWORK_CHANGED`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const TYPE_NETWORK_CHANGED: StringName = &"network_changed"
```

网络状态变化。

<a id="member-gfplatformlifecycleevent-constants-type_keyboard_shown"></a>

### `TYPE_KEYBOARD_SHOWN`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const TYPE_KEYBOARD_SHOWN: StringName = &"keyboard_shown"
```

输入法或软键盘显示。

<a id="member-gfplatformlifecycleevent-constants-type_keyboard_hidden"></a>

### `TYPE_KEYBOARD_HIDDEN`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const TYPE_KEYBOARD_HIDDEN: StringName = &"keyboard_hidden"
```

输入法或软键盘隐藏。

<a id="member-gfplatformlifecycleevent-constants-type_memory_warning"></a>

### `TYPE_MEMORY_WARNING`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const TYPE_MEMORY_WARNING: StringName = &"memory_warning"
```

平台发出内存压力警告。

## 属性

<a id="member-gfplatformlifecycleevent-properties-event_type"></a>

### `event_type`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var event_type: StringName = &""
```

事件类型。

<a id="member-gfplatformlifecycleevent-properties-platform_id"></a>

### `platform_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var platform_id: StringName = &""
```

平台标识。

<a id="member-gfplatformlifecycleevent-properties-sequence"></a>

### `sequence`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var sequence: int = 0
```

单调递增序号。

<a id="member-gfplatformlifecycleevent-properties-timestamp_msec"></a>

### `timestamp_msec`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var timestamp_msec: int = 0
```

事件时间戳，单位毫秒。

<a id="member-gfplatformlifecycleevent-properties-payload"></a>

### `payload`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var payload: Dictionary = {}
```

事件载荷。

结构：

- `payload`: Dictionary adapter-defined event payload.

<a id="member-gfplatformlifecycleevent-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方元数据。

结构：

- `metadata`: Dictionary caller-defined metadata.

## 方法

<a id="member-gfplatformlifecycleevent-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure( p_event_type: StringName, p_platform_id: StringName = &"", p_payload: Dictionary = {}, p_sequence: int = 0, p_timestamp_msec: int = 0, p_metadata: Dictionary = {} ) -> GFPlatformLifecycleEvent:
```

配置生命周期事件。

参数：

| 名称 | 说明 |
|---|---|
| `p_event_type` | 事件类型。 |
| `p_platform_id` | 平台标识。 |
| `p_payload` | 事件载荷。 |
| `p_sequence` | 单调递增序号。 |
| `p_timestamp_msec` | 单调时间戳；0 表示由发布该事件的 adapter 填充。 |
| `p_metadata` | 调用方元数据。 |

返回：当前事件。

结构：

- `p_payload`: Dictionary adapter-defined event payload.
- `p_metadata`: Dictionary caller-defined metadata.

<a id="member-gfplatformlifecycleevent-methods-is_type"></a>

### `is_type`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_type(expected_type: StringName) -> bool:
```

检查事件类型。

参数：

| 名称 | 说明 |
|---|---|
| `expected_type` | 期望事件类型。 |

返回：类型一致返回 true。

<a id="member-gfplatformlifecycleevent-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：生命周期事件字典。

结构：

- `return`: Dictionary with event_type, platform_id, sequence, timestamp_msec, payload, and metadata.

<a id="member-gfplatformlifecycleevent-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用生命周期事件字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 生命周期事件字典。 |

结构：

- `data`: Dictionary with event_type, platform_id, sequence, timestamp_msec, payload, and metadata.

<a id="member-gfplatformlifecycleevent-methods-duplicate_event"></a>

### `duplicate_event`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_event() -> GFPlatformLifecycleEvent:
```

创建生命周期事件深拷贝。

返回：新生命周期事件。

<a id="member-gfplatformlifecycleevent-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFPlatformLifecycleEvent:
```

从字典创建生命周期事件。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 生命周期事件字典。 |

返回：新生命周期事件。

结构：

- `data`: Dictionary with event_type, platform_id, sequence, timestamp_msec, payload, and metadata.
