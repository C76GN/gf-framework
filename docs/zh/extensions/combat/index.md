# Combat 战斗通用能力

Combat 是 GF 随框架分发的可选战斗基础扩展。它提供属性修饰、标签组件、Buff、技能、目标选择、命中桥接、发射体、动作数值槽和 `GFCombatSystem`，但不内置伤害公式、阵营规则、特效、输入、动画状态机或具体游戏玩法。

Combat 属于业务型扩展外置候选：当前随 GF 包分发以便统一测试和文档，但保持默认关闭、原子依赖和无跨扩展硬引用。项目应通过 preset、项目 Installer 或 `addons/gf` 外的独立插件组合它，而不是让 kernel、standard 或其他内置扩展主动依赖 Combat。

## 阅读入口

- [核心模型与系统边界](core-model/index.md)：属性、标签、Buff、技能、目标选择和战斗事件。
- [命中桥接与碰撞窗口](hit-bridge/index.md)：HitBox、HurtBox、HitScan、碰撞形状配置、重叠广播和状态组。
- [发射体运行时](projectiles.md)：类型化 Definition/Binding、LaunchInput/Session、Motion/Adapter、两阶段 Emitter、Catalog 与 Spawn Pattern。
- [通用动作与数值槽](actions-gauges.md)：`GFCombatAction`、`GFCombatActionModifier`、`GFCombatGauge` 和结果对象。
- [运行时示例与系统驱动](runtime-usage/index.md)：事件监听、Buff、技能、运行时 Buff 调整和手动装配。

## 使用边界

Combat 只提供可复用的战斗原语。项目应在自己的技能、能力、状态机、AI、动画事件或接收器中决定何时施放、如何结算、是否命中、扣什么数值、播放什么反馈，以及如何处理 PvE/PvP 规则。

## API Reference

完整类、方法、信号和属性清单见 [Combat API Reference](../../reference/api/extensions-combat.md)。正文页只说明职责边界和典型组合方式，不重复维护完整 API 表。
