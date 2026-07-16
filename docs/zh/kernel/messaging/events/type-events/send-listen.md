# 发送与监听事件

发送事件时，把包含数据的实例发送至系统总线。

```gdscript
func attack_enemy(enemy: Node) -> void:
	var payload := DamagePayload.new()
	payload.attacker = self
	payload.target = enemy
	payload.amount = 100

	Gf.send_event(payload)
```

监听方法必须至少接收一个事件实例参数。事件注册 API 接收 `GFEventListener`，用它显式声明事件系统会传入的派发参数数量；类型事件当前为 1。推荐把回调参数声明为具体 Payload 类型，或声明为 `GFPayload` 后再恢复强类型。

```gdscript
func ready() -> void:
	# 可以通过第三个可选参数 priority 控制监听顺序，默认优先级为 0
	register_event(DamagePayload, GFEventListener.from_method(self, &"_on_damage_taken", 1), 100)

func _on_damage_taken(payload: DamagePayload) -> void:
	print(payload.attacker.name, " 造成了 ", payload.amount, " 点伤害")

func dispose() -> void:
	unregister_event(DamagePayload, GFEventListener.from_method(self, &"_on_damage_taken", 1))
```

`GFSystem`、`GFUtility`、`GFController` 和状态对象的 `register_event()` 会把自身作为 owner 注册，配套 `unregister_event()` 会按 owner 精确注销。直接使用全局入口时，`Gf.listen_owned(owner, EventType, listener)` 应搭配 `Gf.unlisten_owned(owner, EventType, listener)`；普通 `unlisten()` 只移除无 owner 的监听，不会误删其它 owner 使用同一回调注册的监听。

## 消费语义与性能边界

`GFPayload` 提供 `is_consumed` 字段。Type Event 派发后会检查事件实例上的 `is_consumed == true`，命中时停止后续监听。非 `GFPayload` 事件如果也定义并设置了同名字段，同样会触发消费语义。

保持 Payload 轻量。Godot 4 的内存回收针对 `RefCounted` 已经优化，但在 `_physics_process` 这类高频循环中大量 `new` 强类型 Payload 仍会构成 GC 压力。这类场景可考虑改用 [Simple Event](../simple-events.md)。
