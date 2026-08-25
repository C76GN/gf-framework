# 重叠广播与状态组

HitBox 可以把当前重叠对象广播成统一命中上下文，也可以通过状态组统一管理一组命中区域的启停。

## 重叠广播

HitBox 的 `broadcast_overlaps()` 会从当前重叠的 Area/Body 中向上查找具备 `receive_hit()` 的节点，并去重发送。

若 HitBox 配置了 `sender_path`，且该业务发送者实现了 `send_to(receiver, payload_override, hit_id_override)`，碰撞广播会交给业务发送者接管；否则仍使用 HitBox 自身的 `send_to()`。

Projectile Runtime 不再继承 impact source，也不自动承担 sender。`GFProjectileDefinition2D` / `GFProjectileDefinition3D` 通过 `impact_source_paths` 显式绑定 0..N 个同维度 `GFHitBox2D | GFHitScan2D` 或 `GFHitBox3D | GFHitScan3D`；HitBox 继续独立遵守上述 sender 分发规则，HitScan 继续使用自己的命中发送协议。Runtime 只监听绑定 source 的 `hit_accepted`，用当前 Session generation 累加 accepted impact；rejected 或旧 generation 的迟到回调不会推进 Projectile 生命周期。

业务 sender 接管时，发送结果信号仍由对应 HitBox 发出；如果项目还希望 HurtBox 发出 `hit_received`，业务 sender 的 `send_to()` 需要实际调用 `receiver.receive_hit(context)`。

HurtBox 支持 `accepted_hit_ids`、`rejected_hit_ids` 和 `validation_callback`，适合项目层接入护盾、无敌帧、阵营过滤或编辑器调试；这些规则都在回调里表达，不写进框架默认逻辑。

## 状态组

需要随状态统一开关一组命中区域时，可以把 `GFHitBoxState2D` 或 `GFHitBoxState3D` 放在区域节点上层。它会递归管理子树内的 `GFHitBox*`、`GFHurtBox*` 和 `Area*`，可选择同步 `enabled`、`monitoring` / `monitorable` 和可见性：

```gdscript
@onready var attack_state: GFHitBoxState2D = $AttackHitBoxes

func _on_attack_started() -> void:
	attack_state.activate()


func _on_attack_finished() -> void:
	attack_state.deactivate()
```

状态组只表达“这一组区域当前是否参与收发命中”，不决定伤害窗口、动画帧、阵营或技能逻辑。项目应在自己的状态机、动画事件或技能系统中决定何时调用 `activate()` / `deactivate()`。

和节点状态机配合时，推荐在具体 `GFNodeState` 的 `_enter()` / `_exit()` 中控制攻击窗口，这样命中盒开关和角色状态生命周期保持一致：

```gdscript
class_name AttackState
extends GFNodeState

@onready var attack_state: GFHitBoxState2D = $AttackHitBoxes


func _enter(_previous_state: StringName = &"", _args: Dictionary = {}) -> void:
	attack_state.activate()


func _exit(_next_state: StringName = &"", _args: Dictionary = {}) -> void:
	attack_state.deactivate()
```
