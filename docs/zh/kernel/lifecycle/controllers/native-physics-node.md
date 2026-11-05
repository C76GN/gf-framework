# 原生物理节点桥接

角色、载具等 Godot 物理节点应继续继承自己的原生类型，Controller 作为子节点接入 GF 架构。这样可以保留 Godot 物理语义，同时把输入、模型读取和系统调用收敛到 Controller。

## 宿主节点

```gdscript
## 保留 CharacterBody2D 的物理职责，由子 Controller 提供移动意图。
class_name ActorBody
extends CharacterBody2D

## 场景中的状态机子节点；生命周期随宿主场景管理。
@onready var state_machine: GFNodeStateMachine = $StateMachine


## 在物理帧接收移动意图，碰撞与滑动仍由原生物理节点处理。
func move_by_input(input_vector: Vector2, speed: float) -> void:
	velocity = input_vector * speed
	move_and_slide()
```

## Controller 桥接

```gdscript
## 将架构数据和玩家输入桥接到宿主；不在 Controller 中保存核心移动状态。
class_name ActorMovementController
extends GFController

## 借用宿主及其子节点，不接管它们的释放。
@onready var _actor: ActorBody = get_host_as(ActorBody) as ActorBody

## 架构中的业务数据引用，与 Controller 的场景节点状态分离。
var _actor_model: ActorModel = null

## 借用宿主拥有的状态机节点，不能按架构模块释放它。
var _state_machine: GFNodeStateMachine = null


## 在上下文等待结束后取得模型和宿主状态机。
func _ready() -> void:
	var architecture := await wait_for_context_ready()
	_actor_model = architecture.get_model(ActorModel) as ActorModel
	_state_machine = _actor.state_machine


## 仅在宿主、模型和业务移动许可都有效时转发本帧输入。
func _physics_process(_delta: float) -> void:
	if _actor == null or _actor_model == null or not _actor_model.can_move:
		return

	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_actor.move_by_input(input_vector, _actor_model.move_speed)
```

## 使用边界

物理移动、碰撞响应和节点生命周期仍遵循 Godot 原生规则。Controller 只负责把架构数据和输入意图转交给宿主节点。
