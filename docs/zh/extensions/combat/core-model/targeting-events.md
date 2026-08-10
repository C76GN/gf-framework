# 目标选择与事件

Combat 的目标选择和事件 payload 只描述通用运行时流程。目标是否合法、是否可命中、是否触发伤害或表现反馈由项目层决定。

## 目标选择管线

`GFSkillTargetingUtility2D` 处理 `GFSkillTargetingRule2D` 定义的 2D 自动索敌管线。`GFSkill` 可内置使用这套管线；若需手动调用，应通过 `Gf.get_utility(GFSkillTargetingUtility2D)` 获取。

名称中的 `2D` 是真实维度契约：候选必须能提供有限的 `Vector2` 位置，规则的半径、扇形角度、朝向和施法中心也必须有限。3D 项目应提供独立的 3D 目标选择策略，不应把 `Node3D` 交给该服务后依赖静默过滤。

管线流程：

1. 空间收集：基于形状和半径筛选候选对象。
2. 标签过滤：检查 `GFTagComponent`，支持必须拥有和禁止拥有标签。
3. 动态排序：支持基于距离或动态属性名进行最高/最低排序；候选位置和排序属性会在比较前各读取一次，避免反射 getter 在 `sort_custom()` 中被重复调用并产生不稳定次序。
4. 数量截取：严格限制返回的目标数量。

通过创建 `GFSkillTargetingRule2D` 资源文件，可以在不修改代码的情况下调整索敌逻辑。调用前可用 `is_configuration_valid()` 拒绝非有限或自相矛盾的规则。管线只处理通用候选、标签、排序和截取，不解释阵营、视野、障碍、仇恨或技能业务规则。

## 战斗事件

`GFCombatSystem` 在处理 Buff 时会通过 `GFArchitecture` 发送强类型事件，便于业务层通过订阅 payload 实现引爆、致死拦截、日志、UI 或表现联动。

常见 payload：

- `GFBuffAppliedPayload`：新 Buff 被成功应用。
- `GFBuffRefreshedPayload`：已有 Buff 持续时间或层数被刷新。
- `GFBuffRemovedPayload`：Buff 耗尽或被强制移除。

事件只报告 Combat 层状态变化，不负责项目的伤害结算、任务进度、特效播放或网络同步。
