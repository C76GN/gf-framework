# GFInputDeviceUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/runtime/gf_input_device_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

本地玩家输入设备分配工具。 负责维护玩家索引与键鼠、手柄、触控、AI 或自定义设备的映射。 它不消费输入事件，也不规定动作名。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`assignments_changed`](#member-gfinputdeviceutility-signals-assignments_changed) | `signal assignments_changed(assignments: Array[GFInputDeviceAssignment])` |
| 信号 | [`active_player_changed`](#member-gfinputdeviceutility-signals-active_player_changed) | `signal active_player_changed(player_index: int)` |
| 信号 | [`active_device_changed`](#member-gfinputdeviceutility-signals-active_device_changed) | `signal active_device_changed(player_index: int, assignment: GFInputDeviceAssignment, event: InputEvent)` |
| 信号 | [`player_join_requested`](#member-gfinputdeviceutility-signals-player_join_requested) | `signal player_join_requested(player_index: int, assignment: GFInputDeviceAssignment, event: InputEvent)` |
| 信号 | [`assignment_event_recorded`](#member-gfinputdeviceutility-signals-assignment_event_recorded) | `signal assignment_event_recorded(event_record: Dictionary)` |
| 常量 | [`DEFAULT_MAX_ASSIGNMENT_EVENTS`](#member-gfinputdeviceutility-constants-default_max_assignment_events) | `const DEFAULT_MAX_ASSIGNMENT_EVENTS: int = 64` |
| 属性 | [`max_assignment_events`](#member-gfinputdeviceutility-properties-max_assignment_events) | `var max_assignment_events: int = DEFAULT_MAX_ASSIGNMENT_EVENTS:` |
| 属性 | [`max_players`](#member-gfinputdeviceutility-properties-max_players) | `var max_players: int = 4:` |
| 属性 | [`include_keyboard_mouse`](#member-gfinputdeviceutility-properties-include_keyboard_mouse) | `var include_keyboard_mouse: bool = true` |
| 属性 | [`include_touch`](#member-gfinputdeviceutility-properties-include_touch) | `var include_touch: bool = true` |
| 属性 | [`auto_assign_joypads_on_input`](#member-gfinputdeviceutility-properties-auto_assign_joypads_on_input) | `var auto_assign_joypads_on_input: bool = true` |
| 属性 | [`auto_assign_axis_threshold`](#member-gfinputdeviceutility-properties-auto_assign_axis_threshold) | `var auto_assign_axis_threshold: float = 0.75` |
| 属性 | [`active_player_axis_threshold`](#member-gfinputdeviceutility-properties-active_player_axis_threshold) | `var active_player_axis_threshold: float = 0.2:` |
| 属性 | [`join_events`](#member-gfinputdeviceutility-properties-join_events) | `var join_events: Array[InputEvent] = []` |
| 属性 | [`auto_assign_devices_on_join`](#member-gfinputdeviceutility-properties-auto_assign_devices_on_join) | `var auto_assign_devices_on_join: bool = true` |
| 属性 | [`active_player_index`](#member-gfinputdeviceutility-properties-active_player_index) | `var active_player_index: int = 0` |
| 方法 | [`init`](#member-gfinputdeviceutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfinputdeviceutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`refresh_connected_devices`](#member-gfinputdeviceutility-methods-refresh_connected_devices) | `func refresh_connected_devices() -> void:` |
| 方法 | [`create_assignment`](#member-gfinputdeviceutility-methods-create_assignment) | `func create_assignment( player_index: int, device_type: GFInputDeviceAssignment.DeviceType, device_id: int ) -> GFInputDeviceAssignment:` |
| 方法 | [`set_assignment`](#member-gfinputdeviceutility-methods-set_assignment) | `func set_assignment( assignment: GFInputDeviceAssignment, reason: StringName = &"manual", event_metadata: Dictionary = {}, source_event: InputEvent = null ) -> void:` |
| 方法 | [`remove_assignment`](#member-gfinputdeviceutility-methods-remove_assignment) | `func remove_assignment(player_index: int, reason: StringName = &"manual") -> void:` |
| 方法 | [`get_assignment`](#member-gfinputdeviceutility-methods-get_assignment) | `func get_assignment(player_index: int) -> GFInputDeviceAssignment:` |
| 方法 | [`get_player_for_device`](#member-gfinputdeviceutility-methods-get_player_for_device) | `func get_player_for_device( device_type: GFInputDeviceAssignment.DeviceType, device_id: int ) -> int:` |
| 方法 | [`get_player_for_event`](#member-gfinputdeviceutility-methods-get_player_for_event) | `func get_player_for_event(event: InputEvent) -> int:` |
| 方法 | [`handle_input_event`](#member-gfinputdeviceutility-methods-handle_input_event) | `func handle_input_event(event: InputEvent) -> int:` |
| 方法 | [`handle_join_input_event`](#member-gfinputdeviceutility-methods-handle_join_input_event) | `func handle_join_input_event(event: InputEvent) -> int:` |
| 方法 | [`is_join_input_event`](#member-gfinputdeviceutility-methods-is_join_input_event) | `func is_join_input_event(event: InputEvent) -> bool:` |
| 方法 | [`configure_default_join_events`](#member-gfinputdeviceutility-methods-configure_default_join_events) | `func configure_default_join_events(include_keyboard: bool = true, include_joypad: bool = true) -> void:` |
| 方法 | [`clear_join_events`](#member-gfinputdeviceutility-methods-clear_join_events) | `func clear_join_events() -> void:` |
| 方法 | [`assign_device_to_next_player`](#member-gfinputdeviceutility-methods-assign_device_to_next_player) | `func assign_device_to_next_player( device_type: GFInputDeviceAssignment.DeviceType, device_id: int, reason: StringName = &"auto_assign", source_event: InputEvent = null ) -> int:` |
| 方法 | [`set_active_player`](#member-gfinputdeviceutility-methods-set_active_player) | `func set_active_player(player_index: int) -> void:` |
| 方法 | [`set_player_deadzone`](#member-gfinputdeviceutility-methods-set_player_deadzone) | `func set_player_deadzone(player_index: int, deadzone: float) -> void:` |
| 方法 | [`get_player_deadzone`](#member-gfinputdeviceutility-methods-get_player_deadzone) | `func get_player_deadzone(player_index: int, fallback: float = -1.0) -> float:` |
| 方法 | [`get_device_name`](#member-gfinputdeviceutility-methods-get_device_name) | `func get_device_name(player_index: int) -> String:` |
| 方法 | [`get_active_assignment`](#member-gfinputdeviceutility-methods-get_active_assignment) | `func get_active_assignment() -> GFInputDeviceAssignment:` |
| 方法 | [`get_active_device_name`](#member-gfinputdeviceutility-methods-get_active_device_name) | `func get_active_device_name() -> String:` |
| 方法 | [`start_vibration_for_player`](#member-gfinputdeviceutility-methods-start_vibration_for_player) | `func start_vibration_for_player( player_index: int, weak_magnitude: float, strong_magnitude: float, duration_seconds: float = 0.0 ) -> bool:` |
| 方法 | [`stop_vibration_for_player`](#member-gfinputdeviceutility-methods-stop_vibration_for_player) | `func stop_vibration_for_player(player_index: int) -> bool:` |
| 方法 | [`get_assignments`](#member-gfinputdeviceutility-methods-get_assignments) | `func get_assignments() -> Array[GFInputDeviceAssignment]:` |
| 方法 | [`clear_assignments`](#member-gfinputdeviceutility-methods-clear_assignments) | `func clear_assignments(reason: StringName = &"manual") -> void:` |
| 方法 | [`get_assignment_events`](#member-gfinputdeviceutility-methods-get_assignment_events) | `func get_assignment_events(limit: int = 0, json_compatible: bool = true) -> Array[Dictionary]:` |
| 方法 | [`get_assignment_report`](#member-gfinputdeviceutility-methods-get_assignment_report) | `func get_assignment_report(event_limit: int = 10, json_compatible: bool = true) -> Dictionary:` |

## 信号

<a id="member-gfinputdeviceutility-signals-assignments_changed"></a>

### `assignments_changed`

- API：`public`

```gdscript
signal assignments_changed(assignments: Array[GFInputDeviceAssignment])
```

设备映射发生变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `assignments` | 当前设备映射副本。 |

<a id="member-gfinputdeviceutility-signals-active_player_changed"></a>

### `active_player_changed`

- API：`public`

```gdscript
signal active_player_changed(player_index: int)
```

最近产生输入的玩家变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |

<a id="member-gfinputdeviceutility-signals-active_device_changed"></a>

### `active_device_changed`

- API：`public`

```gdscript
signal active_device_changed(player_index: int, assignment: GFInputDeviceAssignment, event: InputEvent)
```

最近产生输入的设备变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `assignment` | 活跃设备映射副本。 |
| `event` | 触发变化的输入事件副本；手动设置时可能为空。 |

<a id="member-gfinputdeviceutility-signals-player_join_requested"></a>

### `player_join_requested`

- API：`public`

```gdscript
signal player_join_requested(player_index: int, assignment: GFInputDeviceAssignment, event: InputEvent)
```

收到项目配置的加入输入时发出。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `assignment` | 触发加入请求的设备映射副本。 |
| `event` | 触发加入请求的输入事件副本。 |

<a id="member-gfinputdeviceutility-signals-assignment_event_recorded"></a>

### `assignment_event_recorded`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal assignment_event_recorded(event_record: Dictionary)
```

设备分配诊断事件被记录时发出。

参数：

| 名称 | 说明 |
|---|---|
| `event_record` | 结构化设备分配事件副本。 |

结构：

- `event_record`: Dictionary assignment event record.

## 常量

<a id="member-gfinputdeviceutility-constants-default_max_assignment_events"></a>

### `DEFAULT_MAX_ASSIGNMENT_EVENTS`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_MAX_ASSIGNMENT_EVENTS: int = 64
```

默认保留的设备分配诊断事件数量。

## 属性

<a id="member-gfinputdeviceutility-properties-max_assignment_events"></a>

### `max_assignment_events`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_assignment_events: int = DEFAULT_MAX_ASSIGNMENT_EVENTS:
```

最多保留的设备分配诊断事件数量。设置为 0 时不保留历史。

<a id="member-gfinputdeviceutility-properties-max_players"></a>

### `max_players`

- API：`public`

```gdscript
var max_players: int = 4:
```

允许的最大本地玩家数。

<a id="member-gfinputdeviceutility-properties-include_keyboard_mouse"></a>

### `include_keyboard_mouse`

- API：`public`

```gdscript
var include_keyboard_mouse: bool = true
```

是否为 0 号玩家自动分配键鼠。

<a id="member-gfinputdeviceutility-properties-include_touch"></a>

### `include_touch`

- API：`public`

```gdscript
var include_touch: bool = true
```

是否在移动平台自动添加触控设备。

<a id="member-gfinputdeviceutility-properties-auto_assign_joypads_on_input"></a>

### `auto_assign_joypads_on_input`

- API：`public`

```gdscript
var auto_assign_joypads_on_input: bool = true
```

是否在收到未登记手柄输入时自动分配到空玩家席位。

<a id="member-gfinputdeviceutility-properties-auto_assign_axis_threshold"></a>

### `auto_assign_axis_threshold`

- API：`public`

```gdscript
var auto_assign_axis_threshold: float = 0.75
```

未登记手柄轴输入需要达到该幅度才会触发自动分配，避免漂移噪声抢占席位。

<a id="member-gfinputdeviceutility-properties-active_player_axis_threshold"></a>

### `active_player_axis_threshold`

- API：`public`

```gdscript
var active_player_axis_threshold: float = 0.2:
```

已登记手柄轴输入需要达到该幅度才会切换最近活跃玩家。

<a id="member-gfinputdeviceutility-properties-join_events"></a>

### `join_events`

- API：`public`

```gdscript
var join_events: Array[InputEvent] = []
```

可触发本地玩家加入请求的输入事件模板。为空时不启用 join 检测。

<a id="member-gfinputdeviceutility-properties-auto_assign_devices_on_join"></a>

### `auto_assign_devices_on_join`

- API：`public`

```gdscript
var auto_assign_devices_on_join: bool = true
```

join 输入来自未登记设备时，是否自动分配到空玩家席位。

<a id="member-gfinputdeviceutility-properties-active_player_index"></a>

### `active_player_index`

- API：`public`

```gdscript
var active_player_index: int = 0
```

当前最近活跃玩家索引。

## 方法

<a id="member-gfinputdeviceutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化设备映射并订阅手柄连接变化。

<a id="member-gfinputdeviceutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

清理设备映射并取消手柄连接变化订阅。

<a id="member-gfinputdeviceutility-methods-refresh_connected_devices"></a>

### `refresh_connected_devices`

- API：`public`

```gdscript
func refresh_connected_devices() -> void:
```

按当前硬件重新生成设备映射。

<a id="member-gfinputdeviceutility-methods-create_assignment"></a>

### `create_assignment`

- API：`public`

```gdscript
func create_assignment( player_index: int, device_type: GFInputDeviceAssignment.DeviceType, device_id: int ) -> GFInputDeviceAssignment:
```

创建一个设备映射。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `device_type` | 设备类型。 |
| `device_id` | 设备 ID。 |

返回：新映射。

<a id="member-gfinputdeviceutility-methods-set_assignment"></a>

### `set_assignment`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func set_assignment( assignment: GFInputDeviceAssignment, reason: StringName = &"manual", event_metadata: Dictionary = {}, source_event: InputEvent = null ) -> void:
```

手动设置一个玩家的设备映射。

参数：

| 名称 | 说明 |
|---|---|
| `assignment` | 设备映射。 |
| `reason` | 调用方给出的分配原因。 |
| `event_metadata` | 额外诊断元数据。 |
| `source_event` | 触发分配的输入事件；可为空。 |

结构：

- `event_metadata`: Dictionary assignment event metadata.

<a id="member-gfinputdeviceutility-methods-remove_assignment"></a>

### `remove_assignment`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func remove_assignment(player_index: int, reason: StringName = &"manual") -> void:
```

移除指定玩家的设备映射。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `reason` | 调用方给出的移除原因。 |

<a id="member-gfinputdeviceutility-methods-get_assignment"></a>

### `get_assignment`

- API：`public`

```gdscript
func get_assignment(player_index: int) -> GFInputDeviceAssignment:
```

获取指定玩家的设备映射。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |

返回：设备映射；不存在时返回 null。

<a id="member-gfinputdeviceutility-methods-get_player_for_device"></a>

### `get_player_for_device`

- API：`public`

```gdscript
func get_player_for_device( device_type: GFInputDeviceAssignment.DeviceType, device_id: int ) -> int:
```

根据设备类型和设备 ID 获取玩家索引。

参数：

| 名称 | 说明 |
|---|---|
| `device_type` | 设备类型。 |
| `device_id` | 设备 ID。 |

返回：玩家索引；不存在时返回 -1。

<a id="member-gfinputdeviceutility-methods-get_player_for_event"></a>

### `get_player_for_event`

- API：`public`

```gdscript
func get_player_for_event(event: InputEvent) -> int:
```

根据输入事件获取玩家索引，不产生自动分配。

参数：

| 名称 | 说明 |
|---|---|
| `event` | 输入事件。 |

返回：玩家索引；无法匹配时返回 -1。

<a id="member-gfinputdeviceutility-methods-handle_input_event"></a>

### `handle_input_event`

- API：`public`

```gdscript
func handle_input_event(event: InputEvent) -> int:
```

处理输入事件并返回玩家索引。未登记手柄可按配置自动占位。

参数：

| 名称 | 说明 |
|---|---|
| `event` | 输入事件。 |

返回：玩家索引；无法匹配时返回 -1。

<a id="member-gfinputdeviceutility-methods-handle_join_input_event"></a>

### `handle_join_input_event`

- API：`public`

```gdscript
func handle_join_input_event(event: InputEvent) -> int:
```

处理本地玩家加入输入。只有匹配 join_events 的输入会触发。

参数：

| 名称 | 说明 |
|---|---|
| `event` | 输入事件。 |

返回：请求加入的玩家索引；未匹配或无可用席位时返回 -1。

<a id="member-gfinputdeviceutility-methods-is_join_input_event"></a>

### `is_join_input_event`

- API：`public`

```gdscript
func is_join_input_event(event: InputEvent) -> bool:
```

检查输入事件是否匹配当前 join_events。

参数：

| 名称 | 说明 |
|---|---|
| `event` | 输入事件。 |

返回：是否是加入输入。

<a id="member-gfinputdeviceutility-methods-configure_default_join_events"></a>

### `configure_default_join_events`

- API：`public`

```gdscript
func configure_default_join_events(include_keyboard: bool = true, include_joypad: bool = true) -> void:
```

使用常见本地多人加入输入填充 join_events。

参数：

| 名称 | 说明 |
|---|---|
| `include_keyboard` | 是否加入 Enter / 小键盘 Enter。 |
| `include_joypad` | 是否加入手柄确认 / 开始按钮。 |

<a id="member-gfinputdeviceutility-methods-clear_join_events"></a>

### `clear_join_events`

- API：`public`

```gdscript
func clear_join_events() -> void:
```

清空 join 输入模板。

<a id="member-gfinputdeviceutility-methods-assign_device_to_next_player"></a>

### `assign_device_to_next_player`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func assign_device_to_next_player( device_type: GFInputDeviceAssignment.DeviceType, device_id: int, reason: StringName = &"auto_assign", source_event: InputEvent = null ) -> int:
```

把设备分配给第一个空玩家席位。

参数：

| 名称 | 说明 |
|---|---|
| `device_type` | 设备类型。 |
| `device_id` | 设备 ID。 |
| `reason` | 调用方给出的分配原因。 |
| `source_event` | 触发分配的输入事件；可为空。 |

返回：分配到的玩家索引；无空位时返回 -1。

<a id="member-gfinputdeviceutility-methods-set_active_player"></a>

### `set_active_player`

- API：`public`

```gdscript
func set_active_player(player_index: int) -> void:
```

设置最近活跃玩家。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |

<a id="member-gfinputdeviceutility-methods-set_player_deadzone"></a>

### `set_player_deadzone`

- API：`public`

```gdscript
func set_player_deadzone(player_index: int, deadzone: float) -> void:
```

设置玩家级输入死区。小于 0 表示清除覆盖。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `deadzone` | 死区值。 |

<a id="member-gfinputdeviceutility-methods-get_player_deadzone"></a>

### `get_player_deadzone`

- API：`public`

```gdscript
func get_player_deadzone(player_index: int, fallback: float = -1.0) -> float:
```

获取玩家级输入死区覆盖。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `fallback` | 没有覆盖时返回的值。 |

返回：死区值。

<a id="member-gfinputdeviceutility-methods-get_device_name"></a>

### `get_device_name`

- API：`public`

```gdscript
func get_device_name(player_index: int) -> String:
```

获取玩家设备显示名。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |

返回：显示名。

<a id="member-gfinputdeviceutility-methods-get_active_assignment"></a>

### `get_active_assignment`

- API：`public`

```gdscript
func get_active_assignment() -> GFInputDeviceAssignment:
```

获取当前活跃设备映射。

返回：活跃设备映射副本；不存在时返回 null。

<a id="member-gfinputdeviceutility-methods-get_active_device_name"></a>

### `get_active_device_name`

- API：`public`

```gdscript
func get_active_device_name() -> String:
```

获取当前活跃设备显示名。

返回：活跃设备显示名。

<a id="member-gfinputdeviceutility-methods-start_vibration_for_player"></a>

### `start_vibration_for_player`

- API：`public`

```gdscript
func start_vibration_for_player( player_index: int, weak_magnitude: float, strong_magnitude: float, duration_seconds: float = 0.0 ) -> bool:
```

启动指定玩家手柄震动。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |
| `weak_magnitude` | 低频马达强度，范围 0 到 1。 |
| `strong_magnitude` | 高频马达强度，范围 0 到 1。 |
| `duration_seconds` | 持续时间，0 表示由引擎默认处理。 |

返回：成功转发到手柄设备时返回 true。

<a id="member-gfinputdeviceutility-methods-stop_vibration_for_player"></a>

### `stop_vibration_for_player`

- API：`public`

```gdscript
func stop_vibration_for_player(player_index: int) -> bool:
```

停止指定玩家手柄震动。

参数：

| 名称 | 说明 |
|---|---|
| `player_index` | 玩家索引。 |

返回：成功转发到手柄设备时返回 true。

<a id="member-gfinputdeviceutility-methods-get_assignments"></a>

### `get_assignments`

- API：`public`

```gdscript
func get_assignments() -> Array[GFInputDeviceAssignment]:
```

获取所有设备映射的拷贝。

返回：映射数组。

<a id="member-gfinputdeviceutility-methods-clear_assignments"></a>

### `clear_assignments`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear_assignments(reason: StringName = &"manual") -> void:
```

清空所有映射。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 调用方给出的清空原因。 |

<a id="member-gfinputdeviceutility-methods-get_assignment_events"></a>

### `get_assignment_events`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_assignment_events(limit: int = 0, json_compatible: bool = true) -> Array[Dictionary]:
```

获取设备分配诊断事件。

参数：

| 名称 | 说明 |
|---|---|
| `limit` | 最大返回数量；小于等于 0 时返回全部事件。 |
| `json_compatible` | 为 true 时将 metadata 转为 JSON 兼容值。 |

返回：设备分配事件数组。

结构：

- `return`: Array[Dictionary] assignment event records.

<a id="member-gfinputdeviceutility-methods-get_assignment_report"></a>

### `get_assignment_report`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_assignment_report(event_limit: int = 10, json_compatible: bool = true) -> Dictionary:
```

获取当前设备分配诊断报告。

参数：

| 名称 | 说明 |
|---|---|
| `event_limit` | 最近事件数量。 |
| `json_compatible` | 为 true 时将 metadata 转为 JSON 兼容值。 |

返回：设备分配报告。

结构：

- `return`: Dictionary containing max_players, active_player_index, assignments, active_assignment, event_count, and recent_events.
