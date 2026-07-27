# 共享键盘本地多人

一块键盘在 Godot 中只有一个键鼠设备身份，不能通过 device id 拆成多个玩家。项目需要共享键盘本地多人时，应把互不重叠的物理键区显式路由到不同玩家的 `GFVirtualInputSource`；`GFInputDeviceUtility` 仍把整块键盘视为一个物理设备，不负责猜测席位。

## 建立项目侧路由

每个席位使用独立的 `source_id` 和 `player_index`。键位表只保存“物理键 -> 抽象动作”，加入流程、角色控制权和动作含义继续由项目决定。

```gdscript
extends Node

const SEAT_BINDINGS: Array[Dictionary] = [
	{
		"player_index": 0,
		"source_id": &"shared_keyboard/left",
		"keys": {
			KEY_A: &"move_left",
			KEY_D: &"move_right",
			KEY_W: &"move_up",
			KEY_S: &"move_down",
			KEY_F: &"confirm",
		},
	},
	{
		"player_index": 1,
		"source_id": &"shared_keyboard/right",
		"keys": {
			KEY_LEFT: &"move_left",
			KEY_RIGHT: &"move_right",
			KEY_UP: &"move_up",
			KEY_DOWN: &"move_down",
			KEY_KP_ENTER: &"confirm",
		},
	},
]

var _sources: Array[GFVirtualInputSource] = []


func _ready() -> void:
	var input_mapping: GFInputMappingUtility = (
		Gf.get_utility(GFInputMappingUtility) as GFInputMappingUtility
	)
	if input_mapping == null:
		return
	for seat: Dictionary in SEAT_BINDINGS:
		_sources.append(input_mapping.create_virtual_source(
			GFVariantData.get_option_string_name(seat, "source_id"),
			GFVariantData.get_option_int(seat, "player_index")
		))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event
	if key_event.echo:
		return

	for seat_index: int in range(SEAT_BINDINGS.size()):
		var keys: Dictionary = GFVariantData.get_option_dictionary(
			SEAT_BINDINGS[seat_index],
			"keys"
		)
		if not keys.has(key_event.physical_keycode):
			continue
		var action_id: StringName = GFVariantData.to_string_name(
			keys[key_event.physical_keycode]
		)
		if key_event.pressed:
			var _pressed: bool = _sources[seat_index].press(action_id)
		else:
			var _released: bool = _sources[seat_index].release(action_id)
		get_viewport().set_input_as_handled()
		return


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_sources()


func _exit_tree() -> void:
	_clear_sources()


func _clear_sources() -> void:
	for source: GFVirtualInputSource in _sources:
		source.clear_all()
```

示例使用 `physical_keycode`，让键区跟随键盘物理位置；需要按当前布局解释字符时，项目可以改用 `keycode`。路由放在 `_unhandled_key_input()`，可让文本框、重绑定界面或其他 UI 先消费按键。项目仍应为暂停、聊天和输入法状态定义自己的输入优先级。

## 生命周期与边界

- 不同席位必须使用不同 `source_id`。`clear_all()` 按 source 清理贡献，复用同一 ID 会让一个席位清掉另一个席位的状态。
- 忽略键盘 repeat，并在应用失焦、场景退出、玩家离席或路由切换时清理虚拟源，避免释放事件丢失后动作一直保持按下。
- 同一物理键只能归一个席位；启动时应由项目校验键位表重复项。多键映射到同一动作时，还要在项目路由中维护按键集合，只有最后一个键释放后才释放动作。
- 普通键盘可能受 rollover 或 ghosting 限制。GF 不能保证任意组合键都被硬件同时报告，项目应在目标设备上验证实际键区。
- `GFVirtualInputSource` 只写入玩家级抽象动作。玩家加入、准备状态、设备提示、暂停归属、角色选择和存档配置都不应写进通用输入路由。

如果项目需要运行时改键，应先从 `GFInputRemapConfig` 或自己的席位配置生成上述互斥键位表，再交给同一个路由；不要同时让真实 InputMap 和虚拟源为同一玩家重复贡献同一按键。
