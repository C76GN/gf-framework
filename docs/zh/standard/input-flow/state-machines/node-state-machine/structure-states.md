# 节点结构与状态脚本

节点式状态机适合角色控制器、UI 流程、复杂交互对象这类天然依赖场景树的状态。

## 场景结构

```text
Player
└── GFNodeStateMachine
	├── IdleState.gd  (extends GFNodeState)
	├── RunState.gd   (extends GFNodeState)
	└── Combat        (GFNodeStateGroup)
		├── AimState.gd
		└── FireState.gd
```

状态机支持直接子状态组成内部组，也支持 `GFNodeStateGroup` 形成多个并行状态层。`ready` 后动态加入 `GFNodeState` 或 `GFNodeStateGroup` 会自动重新加载状态结构，普通辅助子节点不会触发重载。

## 状态脚本

```gdscript
## 项目待机节点状态；场景中须有本例约定的 AnimationPlayer 子节点。
class_name IdleState
extends GFNodeState


## 每次进入待机时恢复对应动画，不依赖节点只执行一次的 ready。
func _enter(previous_state: StringName = &"", args: Dictionary = {}) -> void:
	$AnimationPlayer.play("idle")


## 在激活状态的物理更新中将项目移动输入映射为切换请求。
func _physics_process(_delta: float) -> void:
	if Input.is_action_pressed("move_right"):
		transition_to(&"Run")
```

## 跨组切换

跨组切换使用 `"Group/State"` 路径：

```gdscript
transition_to(&"Combat/Fire", { "target": enemy })
```

## 使用边界

节点状态适合直接操作宿主节点、子节点、动画和 UI。若状态不需要场景树，可以优先使用纯代码 `GFStateMachine`，降低节点结构耦合。
