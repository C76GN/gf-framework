# Kernel 架构容器

Kernel 是 GF 的运行内核，负责全局入口、架构容器、注册表、生命周期、事件、依赖解析、编辑器基础设施和最小协议。`standard` 与 `extensions` 可以依赖 Kernel；Kernel 不能反向引用标准库或可选扩展的具体实现。

## 阅读入口

- [核心单例与层级边界](architecture-boundary.md)：`Gf`、`GFArchitecture`、四阶段准入、正常关闭、源码依赖方向和 AutoLoad 安全入口。
- [装配入口与依赖诊断](assembly-diagnostics/index.md)：Installer、`GFNodeContext`、声明式绑定、工厂和依赖诊断。
- [五层分工与信息流](module-roles-flow/index.md)：Foundation、Model、System、Controller、Utility 的职责和信息流方向。
- [IDE 类型提示与编辑器访问器](editor-accessors.md)：类型断言、脚本模板、访问器生成和编辑器工具索引。
- [全局快照与内核基础设施](snapshots-infrastructure.md)：架构快照、脚本类型检查、属性工具和时间提供者协议。
- [生命周期、装配与依赖](../lifecycle/index.md)：依赖 DAG、activation/quiesce、热模块事务、局部上下文和 Controller 接入说明。
- [消息、事件、命令与查询](../messaging/index.md)：事件系统、命令、查询、规则和命令历史。
- [场景桥接、Controller 与数据绑定](../scene-controller/index.md)：场景节点、Controller、绑定属性和场景桥接。

## 使用边界

进入 Kernel 的能力必须是框架运行时直接需要的契约或基础设施。纯算法进入 Foundation；默认稳定运行时服务进入 Standard Utilities；可选能力进入 Extensions；项目玩法、SDK 适配和跨扩展组合留在项目代码或独立插件中。
