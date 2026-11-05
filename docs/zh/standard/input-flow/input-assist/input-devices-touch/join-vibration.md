# 加入输入与震动

未登记的手柄可按配置自动分配到空玩家席位，手柄轴自动分配带有阈值过滤，避免摇杆漂移噪声抢占席位。

已登记手柄切换 `active_player_index` 时使用独立的 `active_player_axis_threshold`，避免轻微漂移反复切换活跃玩家。

手动 `set_assignment()` 会受 `max_players` 约束，并会把同一物理设备从旧玩家席位移到新玩家席位。

需要多个 AI 虚拟席位时可继续使用 `DeviceType.AI` 与负数设备 ID。

本地多人大厅可以显式配置 join 输入模板，再把匹配事件交给 `handle_join_input_event()`。该接口只发出“某个设备请求加入”的通用信号，不决定队伍、角色、出生点或 UI 流程。

```gdscript
# 大厅接入片段：devices 为已就绪的设备 Utility，项目自行响应加入请求。
devices.configure_default_join_events(true, true)
devices.player_join_requested.connect(func(player_index: int, assignment: GFInputDeviceAssignment, _event: InputEvent) -> void:
	print("join requested: ", player_index, assignment.device_type)
)

## 转发加入候选事件；识别请求本身不创建角色或决定队伍。
func _input(event: InputEvent) -> void:
	devices.handle_join_input_event(event)
```

需要手柄反馈时，可以通过玩家席位转发震动请求，而不是在业务代码里散落 device id 查询：

```gdscript
devices.start_vibration_for_player(player_index, 0.2, 0.8, 0.15)
devices.stop_vibration_for_player(player_index)
```
