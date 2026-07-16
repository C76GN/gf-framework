# Combat 核心模型与系统边界

本组页面说明 Combat 扩展的基础模型：可修饰属性、标签组件、Buff、技能、目标选择和战斗事件。它们是运行时战斗流程的通用构件，不负责项目具体玩法判定。

## 阅读入口

- [属性与标签](attributes-tags.md)：`GFModifiedAttribute`、`GFModifiedAttributeSet` 和 `GFTagComponent`。
- [Buff 与技能](buffs-skills.md)：`GFBuff`、`GFSkill`、刷新策略、周期 Tick 和冷却边界。
- [目标选择与事件](targeting-events.md)：`GFSkillTargetingRule2D`、`GFSkillTargetingUtility2D` 和 Combat 事件 payload。

## 使用边界

Combat 提供可复用战斗原语。伤害公式、阵营规则、输入、动画、AI、表现反馈、死亡流程和 PvE/PvP 策略仍由项目层组合。
