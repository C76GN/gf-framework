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

## 回调中的绑定与事件归属

本地信号先于可选自动发送。每次事件在进入时记录绑定代次与实际接收实例；信号回调中重绑碰撞对象、修改 `receiver_path` 或禁用桥接，会取消该事件剩余的自动发送及由旧按压派生的点击。A → B → A 或禁用后立即重新启用，也不能恢复旧事件。已经发出的本地信号或已经提交的交互不会撤回。

接收者在同一路径下被替换，也不接收旧事件。桥接器、碰撞对象或目标离树、排队删除后不能继续自动发送；新目标也不能继承旧目标的按压配对。释放处理在回调前移除旧配对，回调中创建的新按压仍可正常完成后续点击。

自动发送不隐式将旧事件转交给新目标。需要这种业务流程时，先关闭对应的 `send_on_*`，再显式发起一次新交互：

```gdscript
# 接入片段：pointer 已入树，且由当前页面持有；在接收事件前关闭自动 release。
pointer.send_on_released = false
var _released_connected: int = pointer.pointer_released.connect(
	func(_context: GFInteractionContext, _event: InputEventMouseButton) -> void:
		# 改绑撤销旧点击；这次发送明确属于新目标，不复用旧 context。
		pointer.receiver_path = NodePath("../NextReceiver")
		var report: Dictionary = pointer.send_pointer_interaction(&"released")
		if not GFVariantData.get_option_bool(report, "ok"):
			push_warning(GFVariantData.get_option_string(report, "message"))
)
```

不要等到释放回调里才关闭自动发送：该次按钮事件是否自动发送已在信号前取值。`send_pointer_interaction()` 仍按调用时的目标创建新上下文，也可以通过 `GFInteractionSensor.send_to()` 实现项目自己的捕获或转交规则；项目负责显式目标的存活、业务权限和重复发送控制。
