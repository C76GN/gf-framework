# Domain 通用领域模型

Domain 扩展提供背包、槽位库存、属性、特征、装备、关卡和任务等通用领域数据结构。这些类只表达可复用的数据模型和操作结果，不内置具体物品含义、标签体系、战斗结算、任务奖励或业务规则。

它适合项目希望复用稳定领域容器，但仍由项目自己定义 ID、规则、UI、存档聚合和服务器校验的场景。

Domain 属于业务型扩展外置候选：当前随 GF 包分发以便统一测试和文档，但保持默认关闭、原子依赖和无跨扩展硬引用。项目应通过 preset、项目 Installer 或 `addons/gf` 外的独立插件组合它，而不是让 kernel、standard 或其他内置扩展主动依赖 Domain。

## 阅读入口

- [背包与槽位库存](inventory.md)：物品定义、注册表、堆叠、槽位、容量查询和操作结果。
- [属性、特征与装备](attributes-traits-equipment.md)：属性集合、派生属性、Trait 修饰和装备槽。
- [关卡流程](level-flow.md)：关卡目录、关卡进度和基础切换流程。
- [任务与进度](quest-progress.md)：任务定义、接取、进度事件和任务树。

## 使用边界

- Domain 不规定物品 ID、属性含义、装备规则、任务条件、奖励发放或 UI 绑定。
- 存档格式、网络同步、服务器校验和经济系统应由项目层组合。
- 需要战斗结算、Buff、技能或命中结果时，使用 [Combat](../combat/index.md) 或项目战斗系统。
- 需要标签表达式、校验报告或通用数据契约时，优先使用 [Standard Foundation 数据流程与校验](../../standard/foundation/data-validation/index.md)。

## API Reference

完整类、方法和信号列表见 [Domain API Reference](../../reference/api/extensions-domain.md)。
