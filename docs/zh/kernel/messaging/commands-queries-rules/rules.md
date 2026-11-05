# GFRule 资源化规则对象

`GFRule` 是继承自 `Resource` 的规则抽象基类，用于把“可配置策略”从 `System` 中抽离成独立资源。

它适合技能筛选、结算策略、AI 条件、关卡评分、掉落规则这类需要在编辑器中配置、在运行时由系统执行的逻辑片段。

```gdscript
## 无状态的伤害减免配置；同一资源可以被多个对象共享。
class_name DamageReductionRule
extends GFRule

## 规则输出的下限，由项目在使用前主动 validate 配置。
@export var min_damage: int = 1

## 只读取调用方提供的上下文，不在共享 Resource 上积累本次结算状态。
func execute(context: Object = null) -> Variant:
	var payload := context as DamagePayload
	if payload == null:
		return min_damage
	return maxi(payload.raw_damage - payload.defense, min_damage)

## 检查配置是否允许执行；框架不会自动调用此校验。
func validate() -> bool:
	return min_damage >= 0
```

`execute(context)` 的上下文当前是 `Object`，通常是 `GFPayload` 子类，也可以是项目自己的 `Resource`、`RefCounted` 或 `Node` 对象；如果规则需要 `Dictionary`、`Array` 这类纯数据上下文，建议包装成明确的上下文对象再传入。返回值保持 `Variant`，异步规则也可以返回 `Signal` 供调用方等待。

`GFRule` 只提供资源化策略边界，不负责规则调度、优先级、失败策略或业务含义；这些应由调用它的 `System` 或流程节点决定。

`validate()` 不会自动执行，项目应在加载配置、进入战斗或执行规则前主动调用并处理失败。`GFRule` 也不参与 `GFArchitecture` 依赖注入；如果规则需要架构中的 Model/System/Utility，优先由调用方把必要数据或服务放入 context，而不是让 Resource 自己查全局。

由于 `GFRule` 是 `Resource`，同一个 `.tres` 可能被多个对象共享。规则应尽量保持无状态；运行时缓存、计数器或临时结果应放在 context、System 或 Command 中。如果必须修改规则实例本身，调用方应先 `duplicate(true)`，避免共享资源污染。
