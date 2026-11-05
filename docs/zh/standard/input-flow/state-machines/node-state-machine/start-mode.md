# 启动时机

从 `2.0.0` 起，默认 `start_mode` 为 `AFTER_HOST_READY`，会等待状态机宿主节点完成 `_ready()` 后再进入 `initial_state`。

如果旧项目依赖“状态机自身 `_ready()` 后立刻进入初始状态”的顺序，可以显式设回 `ON_READY`。

需要完全由业务时机控制时使用 `MANUAL`。

```gdscript
# Inspector: StateMachine.start_mode = GFNodeStateMachine.StartMode.MANUAL
@onready var state_machine: GFNodeStateMachine = $StateMachine


## MANUAL 模式下由宿主在依赖准备完成后显式启动。
func _ready() -> void:
	# 完成宿主节点自己的初始化后再启动状态机。
	state_machine.start()
```

也可以直接在 Inspector 中把 `start_mode` 设为 `AFTER_HOST_READY`，让状态机自动等待宿主 ready 后再进入初始状态。
