# 定义 Payload

```gdscript
## 一次伤害通知的数据载荷；Node 字段借用场景对象，不接管其生命周期。
class_name DamagePayload extends GFPayload

## 发起本次伤害的场景对象，延迟消费时需由业务确认其仍有效。
var attacker: Node

## 本次通知的目标对象引用。
var target: Node

## 已供事件消费者使用的伤害数值。
var amount: int

## 提供诊断字典；其中的 Node 引用不是可直接持久化的纯数据。
func to_dict() -> Dictionary:
	return {
		"attacker": attacker,
		"amount": amount
	}
```

Payload 应保持稳定和轻量。业务事件需要明确数据协议时，优先定义独立 payload 类型。
