# 活跃设备与方向历史

当 UI 需要跟随最近活跃设备切换提示文本或图标时，可以监听 `GFInputDeviceUtility.active_device_changed`，或用 `get_active_assignment()` / `get_active_device_name()` 读取当前设备。

该信号只表达“哪个玩家席位的哪个设备最近产生了有效输入”，不绑定任何图标包、平台品牌、按钮命名或 UI 样式。

项目可以继续通过 `GFInputFormatter`、`GFInputIconProvider` 或自己的界面层决定最终展示。

如果项目只需要“最后按下方向优先”的通用规则，而不想把这套逻辑塞进完整输入映射里，可以直接使用 `GFInputDirectionHistory`。

它只记录动作 ID 与方向的按下顺序，不读取 `InputMap`，适合网格移动、菜单导航或其他需要方向仲裁的场景。

```gdscript
var history := GFInputDirectionHistory.new()
history.press_action(&"move_left", Vector2i.LEFT)
history.press_action(&"move_up", Vector2i.UP)
print(history.get_current_direction()) # Vector2i.UP
```

## 方向吸附

如果项目已经拿到了连续二维输入，但希望把它转成稳定的 2 向、4 向或 8 向方向，可以使用 `GFInputDirectionTools`。它只处理 `Vector2`，不读取 `InputMap`，适合触屏摇杆、手柄轴、菜单导航、格子移动或编辑器预览共用同一套方向规则。

```gdscript
var raw := Vector2(0.35, 0.8)
var dpad := GFInputDirectionTools.snap_vector(
	raw,
	GFInputDirectionTools.SnapMode.EIGHT_WAY,
	0.2
)

var direction_id := GFInputDirectionTools.get_closest_direction(dpad)
print(GFInputDirectionTools.get_direction_name(direction_id))
```

`SnapMode.ANALOG` 会保留连续向量并应用径向死区；离散模式会输出每个轴为 `-1.0`、`0.0` 或 `1.0` 的方向向量。方向名称和反向映射只表达通用方向，不绑定动作名、动画名或本地化文本。
