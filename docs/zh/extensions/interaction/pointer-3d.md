# 3D 指针桥接

3D 鼠标或指针点击可使用 `GFPointerInteraction3D` 作为场景桥接节点。它监听绑定的 `CollisionObject3D.input_event`、`mouse_entered` 和 `mouse_exited`，把 hover、press、release、click、wheel 转为 `GFInteractionContext`。

payload 中包含 `pointer_position`、`pointer_normal`、`pointer_shape_idx`、`pointer_button_index`、`pointer_tags` 和 `pointer_metadata` 等通用字段。

```gdscript
var pointer := GFPointerInteraction3D.new()
pointer.interaction_id = &"inspect"
pointer.payload = { "source": "mouse" }
pointer.receiver_path = NodePath("../InteractionReceiver")
static_body.add_child(pointer)
```

默认只在 click 完成时发送交互；`send_on_pressed`、`send_on_released`、`send_on_wheel` 和 `send_on_hover` 可按需开启。桥接节点不会替项目判断距离、可见性、焦点、阵营、物品权限或点击后的效果，只负责把 Godot 3D 指针事件转换为 GF 通用交互上下文。

非滚轮按钮的 press/release 按 `(window_id, device, button_index)` 独立配对，并同时要求 `pointer_shape_idx` 一致；多个按钮或多个设备交错按下不会互相覆盖。未完成配对最多保留 64 项，容量已满时新的 identity 仍会发出 pressed/released 信号，但不会建立 click 配对。离开碰撞对象、禁用或重新绑定会一次性清空全部未完成配对。Pointer 向 `GFInteractionReceiver` 发送时使用框架 raw handoff，并只在 `pointer_interaction_sent` / 返回值的公开边界编码一次报告。
