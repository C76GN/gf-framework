# Buff 与技能示例

Combat 的 Buff、技能和属性修饰器都是通用原语。项目应在自己的技能脚本、AI、输入系统或状态机里决定何时创建、添加、施放和移除它们。

## Tick Buff

```gdscript
## 项目回血效果；应用前须保证 owner 提供有效的 HP 属性。
class_name RegenBuff
extends GFBuff

## 按战斗系统传入的时间增量恢复生命，并立即刷新属性计算结果。
func on_tick(p_delta: float) -> void:
	# 假设宿主有方法获取 HP 属性。
	var hp := owner.get_attribute(&"HP") as GFModifiedAttribute
	hp.set_base_value(hp.get_base_value() + 5.0 * p_delta)
	hp.force_recalculate()
```

## 自动索敌技能

```gdscript
## 项目火球技能的目标筛选与执行入口；示例只打印目标，不实现伤害结算。
class_name FireBallSkill
extends GFSkill

## 绑定本技能的 owner，并配置项目冷却和二维目标筛选规则。
func _init(p_owner: Object) -> void:
	super._init(p_owner)
	id = &"FireBall"
	cooldown_max = 2.0

	targeting_rule = GFSkillTargetingRule2D.new()
	targeting_rule.shape = GFSkillTargetingRule2D.Shape.CIRCLE
	targeting_rule.radius = 300.0
	targeting_rule.max_count = 3
	targeting_rule.sort_rule = GFSkillTargetingRule2D.SortRule.ATTRIBUTE_LOWEST
	targeting_rule.sort_attribute_name = &"HP"

## 消费技能框架筛选后的目标；返回值表示本次项目执行是否成功。
func _try_execute(p_targets: Array[Object]) -> bool:
	for target in p_targets:
		print("Fireball hits: ", target)
	return true
```

需要项目自定义成本、状态或上下文检查时，不必把规则写进 `GFSkill` 子类深处。无副作用条件放入 `activation_checks`，可产生副作用的成本、预留和提交实现为 `GFSkillActivationStep`：

```gdscript
## 固定扣蓝步骤的最小演示；正式资源事务还须按正文保存预值并保证回滚幂等。
class SpendManaStep:
	extends GFSkillActivationStep

	## 借用的项目施法者；激活事务期间须保持有效并提供 mana 属性。
	var actor: Object

	## 本步骤校验、扣除和补回的固定数额。
	var amount: float

	## 将本步骤绑定到一次项目成本配置，不接管施法者生命周期。
	func _init(p_actor: Object, p_amount: float) -> void:
		actor = p_actor
		amount = p_amount

	## 只检查余额，不在验证阶段扣费；所有步骤验证后才开始应用。
	func _validate_activation(_context: GFSkillActivationContext) -> Variant:
		return {
			"ok": actor != null and float(actor.get("mana")) >= amount,
			"reason": &"not_enough_resource",
		}

	## 同步扣除成本，并将数额写入仅供项目使用的激活 metadata。
	func _apply_activation(context: GFSkillActivationContext) -> Variant:
		actor.set("mana", float(actor.get("mana")) - amount)
		context.metadata[&"spent_mana"] = amount
		return true

	## 后续步骤失败时补回已应用成本；此简化示例不支持重复回滚。
	func _rollback_activation(_context: GFSkillActivationContext) -> Variant:
		actor.set("mana", float(actor.get("mana")) + amount)
		return true


var skill := FireBallSkill.new(caster)
skill.activation_checks.append(func(context: GFSkillActivationContext) -> Dictionary:
	return {
		"ok": mana >= 10,
		"reason": &"not_enough_resource",
	}
)

var spend_mana_step := SpendManaStep.new(caster, 10.0)
spend_mana_step.configure(&"spend_mana")
skill.activation_steps.append(spend_mana_step)

skill.execute(enemy, null, { "input_id": &"primary" })
```

检查回调必须保持无副作用。事务会先验证全部步骤，再按顺序应用；执行失败时按逆序调用已应用步骤的回滚钩子。项目步骤应把本次预留值写入激活上下文或自己的事务对象，并实现幂等回滚。上下文的 `metadata` 只作为项目诊断和串联数据，框架不解释其中字段。

## 属性修饰器

```gdscript
var strength_buff := GFBuff.new()
strength_buff.setup(&"StrBoost", 5.0, entity)
strength_buff.modifiers.append(GFModifier.create_percent_add(0.2, &"STR", &"StrBoost"))
combat_system.add_buff(entity, strength_buff)
```

`attribute_id` 表示修饰器要挂到哪一个属性上；`source_id` 表示它来自哪个装备、Buff 或技能，便于按来源批量移除。2.0 起 Buff 不再把 `source_id` 当作目标属性回退，也不再提供旧字段名 `source_tag`。迁移旧代码时，应把目标属性写入 `attribute_id`，把来源写入 `source_id`。
