# 生命周期、装配与依赖

Kernel 生命周期文档说明 `GFArchitecture` 如何装配 `GFModel`、`GFSystem`、`GFUtility`，以及场景节点如何接入架构。Godot 原生节点初始化仍由场景树负责；GF 的生命周期只处理框架模块、局部上下文、工厂和依赖解析。

## 阅读入口

- [启动注册与 Installer](boot-installers/index.md)：boot 脚本、项目 Installer、扩展 Installer、失败状态和超时策略。
- [模块四阶段生命周期](module-lifecycle/index.md)：依赖 DAG、`init()`、`async_init()`、`ready()`、activation、quiesce 与热模块事务。
- [场景级局部上下文](node-contexts.md)：`GFNodeContext`、scoped 架构、继承上下文、局部 tick 和上下文等待。
- [短生命周期工厂与别名](factories-aliases/index.md)：factory、transient/singleton、alias 注册和抽象类型获取。
- [Controller 初始化](controllers/index.md)：`GFController` 与 Godot 节点 `_ready()`、宿主节点和局部上下文协作。

## 使用边界

Installer 只负责注册模块，不应直接启动玩法流程。需要长期存在、参与 tick 或跨模块协作的对象注册为 `Model`、`System` 或 `Utility`；只需要按需创建并注入依赖的对象使用工厂；场景表现逻辑放在 `GFController` 或普通节点中。

## API Reference

完整 Kernel API 见 [Kernel API Reference](../../reference/api/kernel.md)。
