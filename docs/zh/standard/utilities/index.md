# Utilities 工具总览

`standard/utilities` 收纳需要生命周期、缓存、异步任务、文件系统、ProjectSettings、全局状态或跨模块服务的通用工具。它们属于标准库能力，可以依赖 `kernel`，但不能硬绑定任何 GF 内置扩展。

Utilities 与 Foundation 的区别在于运行时状态：如果一个能力需要注册、持有资源、排队、轮询、缓存或输出诊断快照，它通常属于 Utilities。

## 阅读入口

- [资源、存储与 IO](io/index.md)：资源加载、本地存储、编码、同步、下载、远程缓存、导表、版本化 Analytics 和请求 Outbox。
- [运行时服务与调试](runtime/index.md)：时间、信号、对象池、设置、UI、场景查询、音频、日志、诊断和控制台。

## 使用边界

- Utilities 提供通用服务和扩展点，不解释项目业务含义。
- 诊断、日志、设置和运行时工具可以接收外部模块注册的快照、监控项或命令，但不写死 GF 内置扩展的路径、扩展 ID 或类型。
- 纯算法、坐标、数值、标签、校验报告和无生命周期数据结构应放在 [Foundation](../foundation/index.md)。
- Combat、Save、Network、Capability、Interaction、BehaviorTree 等可选运行时系统应放在 [Extensions](../../extensions/index.md) 或项目自己的插件。

## API Reference

完整类、方法和信号列表见 [Standard API Reference](../../reference/api/standard.md)。
