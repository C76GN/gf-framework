# Controller 更新边界

## 帧更新职责

继承自 `Node` 的 `GFController` 通常承担特效表现、玩家输入转发和 UI 动画插值等渲染职责。它们仍依附于 Godot 原生 `_process()` 与 `_physics_process()`。

```gdscript
class_name PlayerInputController extends GFController

var _architecture_ready: bool = false


func _ready() -> void:
	var architecture := await wait_for_context_ready()
	_architecture_ready = architecture != null and architecture.is_inited()


func _process(_delta: float) -> void:
	if not _architecture_ready:
		return
	var x_input := Input.get_axis("ui_left", "ui_right")

	if x_input != 0:
		var move_cmd := MoveCommand.new()
		move_cmd.direction = Vector2(x_input, 0)
		var _command_result: Variant = send_command(move_cmd)
```

Controller 可以按普通 Godot 节点习惯读取输入、驱动局部动画和访问宿主节点。它应把干净的指令、命令或事件交给 System，而不是在场景节点里保存核心业务状态。

## 事件绑定生命周期

Controller 的事件 helper 维护“期望绑定”而不是一次性的信号连接。节点退出树时会从当前架构注销实际监听，但再次入树后会自动恢复；同一 `SceneTree` 内 reparent 到另一个 `GFNodeContext`，或全局 `Gf` 原子提交 replacement Architecture 时，会在相应生命周期操作返回前同步迁移监听并清理旧 owner 注册。同一架构内追加或删除 type、assignable、simple 绑定也会按 desired-set revision 立即重建，不会等到下一帧。对象池 acquire 如果暂时找不到架构，会保留期望绑定，并在正式的全局架构提交通知到达时恢复；Controller 不再为此永久逐帧扫描父链。

Controller 还会观察当前 Architecture 的初始化终态。初始化失败会清空实际 owner 注册并保留 desired set；同一个全局 Architecture 随后重试成功时，即使 identity 没有变化，也会在 `initialization_finished` 后强制恢复监听。已失败、正在 quiesce、正在 dispose 或已经 dispose 的最近 Context 不会让 `get_architecture()`、`get_architecture_or_null()` 或事件绑定静默越过局部边界回退到全局架构。

实例级 `send_command()` 会保留最近 `GFNodeContext` 的依赖作用域。只有明确要绕过局部架构并发送到全局容器时，才直接调用 `Gf.send_command()`。

全局场景应先由 Boot 入口完成 `await Gf.init()`。没有局部 Context 时，`wait_for_context_ready()` 不会替项目初始化或等待全局架构。
