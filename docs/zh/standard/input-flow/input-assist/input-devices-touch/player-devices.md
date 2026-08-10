# 设备席位与玩家级输入

同一输入层提供本地设备席位映射与触屏输入。

## 设备映射

```gdscript
var devices := Gf.get_utility(GFInputDeviceUtility) as GFInputDeviceUtility
devices.max_players = 4
devices.refresh_connected_devices()

for assignment in devices.get_assignments():
	print(assignment.player_index, assignment.device_type, assignment.device_id)
```

`GFInputDeviceAssignment` 只是“玩家席位 -> 设备”的资源化记录，字段包含 `player_index`、`device_type`、`device_id` 和项目自定义 `metadata`，不会绑定任何动作名。

`get_assignment()`、`get_active_assignment()` 和 `get_assignments()` 都返回隔离副本；修改返回 Resource 不会重写运行时分配表。变更归属必须使用 `set_assignment()`、`remove_assignment()`、`clear_assignments()` 或容量配置入口，才能保持设备唯一性、诊断事件和玩家动作清理一致。

Godot 4.7 下键盘和鼠标事件使用引擎提供的键盘/鼠标设备 ID；GF 会把旧资源中的键鼠 `device = 0` 视为兼容占位。AI、虚拟触屏或自定义席位可以继续使用项目约定的 ID。

`GFInputDeviceUtility` 会把输入事件解析到玩家席位；`GFInputMappingUtility` 在存在该工具时会同步维护玩家级动作状态。

## 触屏摇杆

`GFTouchJoystick` 默认只发出 `direction_changed`，不写入项目级 action。需要接入现有输入流时，优先启用 `emit_joypad_motion` 并使用负数虚拟设备 ID，让 `GFInputMappingUtility` 像处理真实手柄一样处理触控输入。

```gdscript
var joystick: GFTouchJoystick = %MoveJoystick
joystick.output_mode = GFTouchJoystick.OutputMode.ANALOG
joystick.emit_joypad_motion = true
joystick.joypad_device_id = -20
```

`GFVirtualInputBridge` 只把给定 device ID 写入事件，不自动创建玩家席位。相同 ID 的按钮与摇杆会组成同一虚拟手柄；两套本地玩家触控必须使用不同 ID，并通过 `GFInputDeviceUtility.set_assignment()` 显式绑定到对应席位。两套控件都保留默认 `-2` 时，只表示同一个共享虚拟设备，不能据此推断玩家。框架当前没有 player-aware 虚拟设备分配器。

移动端 UI 可用 `use_active_region` 和 `active_region` 限制触摸起点，例如左半屏移动、右半屏视角。`output_mode` 设为 `DPAD_4` 或 `DPAD_8` 时，摇杆会输出离散方向，适合菜单、格子移动或复古操作。

## 分配诊断

设备分配诊断可用 `get_assignment_report()` 读取。报告包含当前席位、活跃玩家、最近分配事件和触发输入摘要，适合编辑器页面、设置界面或支持报告定位“为什么某个设备归给了这个玩家”：

```gdscript
var report: Dictionary = devices.get_assignment_report()
var recent_events: Array = report.get("recent_events", [])
for event_value: Variant in recent_events:
	if not event_value is Dictionary:
		continue
	var event_record: Dictionary = event_value
	print(event_record.get("reason", ""), event_record.get("assignment", {}))
```

`set_assignment()`、自动手柄占位、join 输入、设备断开和活跃设备变化都会记录结构化事件。事件只描述原因、设备、旧映射、输入摘要和调用方 metadata；角色选择、队伍、UI 流程或重新分配策略仍由项目层决定。

运行时降低 `max_players` 会在一次集合变更中撤销所有越界 assignment、删除对应 deadzone 覆盖，并把 active player 修复到仍存在的最小席位或 `-1`。每个被撤销席位都会记录 reason 为 `max_players_reduced` 的 `assignment_removed`，因此绑定的 `GFInputMappingUtility` 会同步清除该玩家及其全局聚合贡献。随后重新扩容只增加可用容量，不会复活已撤销 assignment。

## 玩家级状态

事件由 `GFInputMappingUtility` 处理后，System 或状态逻辑可以按已知玩家索引消费：

```gdscript
var player_index := devices.active_player_index
if input_map.consume_action_for_player(player_index, &"confirm"):
	print("player confirm: ", player_index)

var move := input_map.get_action_vector_for_player(player_index, &"move")
```

玩家级状态会保留具体输入来源。同一玩家的同一绑定如果同时来自多个来源，释放其中一个来源不会覆盖仍然按住的另一个来源。

全局状态与玩家状态因此保持一致的聚合语义。调用 `clear_player_input_state(player_index)` 会同时移除该玩家写入的玩家级状态和全局聚合贡献，适合玩家离开、设备断开或切换控制权时清理残留输入。
