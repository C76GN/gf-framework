# Controller 更新边界

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

实例级 `send_command()` 会保留最近 `GFNodeContext` 的依赖作用域。只有明确要绕过局部架构并发送到全局容器时，才直接调用 `Gf.send_command()`。

全局场景应先由 Boot 入口完成 `await Gf.init()`。没有局部 Context 时，`wait_for_context_ready()` 不会替项目初始化或等待全局架构。
