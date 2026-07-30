# 模块四阶段生命周期

本组页面说明 `GFModel`、`GFSystem` 和 `GFUtility` 如何按声明依赖 DAG 完成四阶段初始化、在 READY 后执行热模块拓扑事务，并通过异步 quiesce 安全关闭。

## 阅读入口

- [四阶段初始化、激活与关闭](init-stages.md)：`init()`、`async_init()`、`ready()`、`begin_activation()` 与 `begin_quiesce()` 的职责。
- [异步超时、Activation 与状态查询](async-ready.md)：初始化/激活/关闭 deadline、Ready 与 Active 的区别。
- [热模块拓扑事务](dynamic-registration.md)：READY 后注册、替换、注销的 prepare / commit / rollback 边界。

## 使用边界

GF 生命周期只覆盖注册进架构的 Model、System 和 Utility。Godot 节点生命周期仍由场景树负责；场景桥接逻辑应放在 `GFController`、`GFNodeContext` 或普通节点中。固定模块必须在生命周期计划冻结前由 Installer 装配，不能在 Hook 中动态补注册。
