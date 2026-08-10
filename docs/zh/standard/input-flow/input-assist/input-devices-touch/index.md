# 设备席位、方向历史与触屏输入

这一组文档说明本地玩家席位、设备解析、活跃设备、方向仲裁、加入输入、手柄震动和触屏控件。

## 阅读入口

- [设备席位与玩家级输入](player-devices.md)：`GFInputDeviceUtility`、`GFInputDeviceAssignment`、设备分配和玩家级动作状态。
- [活跃设备与方向历史](active-device-direction.md)：活跃设备信号、设备名、提示展示边界和 `GFInputDirectionHistory`。
- [加入输入与震动](join-vibration.md)：本地多人加入事件、席位约束、手柄轴阈值和玩家级震动。

## 使用边界

本地多人项目应优先使用 `*_for_player()` 接口。图标包、平台品牌、按钮命名、角色选择、队伍、出生点和 UI 流程仍由项目层决定。

## 触屏控件

`GFInputBinding` 的触屏事件默认表示“任意触摸”，适合简单确认或由 `GFTouchButton` / `GFTouchJoystick` 承担区域判断的场景。需要区分多指触点时可启用 `match_touch_index`，让 `InputEventScreenTouch.index` 参与匹配。

`GFTouchJoystick` 是一个可直接放进场景树的 `Node2D`。它会发出 `direction_changed(direction)`，输出会应用死区并保留 0..1 的模拟强度，也可以把方向映射到项目自己的 InputMap 动作名。相对模式适合移动端虚拟摇杆；FOLLOW 模式会在拖动超过半径后让摇杆中心跟随触点，适合需要连续大幅拖动的虚拟摇杆。`emit_joypad_motion` 可把触屏输入桥接为虚拟手柄轴事件。`GFTouchButton` 提供通用触屏按钮，并同样支持 InputMap 动作或虚拟手柄按钮事件。

触屏控件默认只处理触摸事件，不会替项目创建 InputMap 动作，也不会发送虚拟手柄事件。`GFTouchButton.accept_mouse_input` 默认关闭；需要在桌面端用鼠标模拟触屏时，项目应按调试构建、平台或自己的输入设置显式开启。

`GFTouchButton` 与 `GFTouchJoystick` 共享 `GFTouchControl2D` 的触点捕获和生命周期释放逻辑：控件隐藏、离开场景树、`process_mode = PROCESS_MODE_DISABLED` 或手动 `release()` 时都会清空捕获并释放已桥接的 action。`-1` 是 inactive sentinel，不能成为有效触点。项目自定义触屏控件也可以继承 `GFTouchControl2D`，复用 `is_touch_active()`、`get_active_touch_index()`、屏幕坐标转换和 handled 标记，再自行定义形状与输出。

一次 press/gesture 会冻结开始时的 action、虚拟 joypad device/button/axis 以及摇杆定位模式；活动期间修改 export 只影响下一次手势，当前 release 始终归还原来的输出 lane。关闭 `GFTouchButton.accept_mouse_input` 会先释放已有 mouse press。Godot 原生 `set_process_input(false)` 不等同于禁用 Node 的 process mode，调用它之前必须先显式 `release()`，否则节点收不到后续 release event。

需要在自定义触屏控件、虚拟光标或拖放控制器中单独记录 pointer/touch owner 时，可使用 `GFPointerCapture`。它只保存单个活动 pointer id，并提供 `try_capture()`、`matches()`、`release()` 和调试快照，不读取输入事件；`try_capture(NO_POINTER_ID)` 会失败，inactive 状态也不会匹配 sentinel。

需要从非触屏节点写入 InputMap action 或虚拟手柄事件时，可使用 `GFVirtualInputBridge`。它只负责 owner 级 action refcount 和 joypad event 发送，不创建 action、不分配玩家，也不替代 `GFInputMappingUtility` 的玩家级输入流。
