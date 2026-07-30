# 事件与生命周期

事件和生命周期阶段应服务于明确的模块协作，不应替代所有函数调用，也不应依赖偶然的注册顺序。

## 事件

事件适合表达“某件事发生了”，不适合替代所有函数调用。

- 一个模块需要通知多个监听者时，使用事件。
- 调用者需要明确知道执行结果时，使用命令、查询或普通方法。
- 事件 payload 应使用稳定字段，不要把临时 UI 节点、场景对象或项目局部状态塞进通用事件。

事件监听要有明确 owner。节点或短生命周期对象退出时，应取消监听或让框架通过 owner 清理。

## 生命周期

固定模块应由 Installer 在生命周期计划冻结前完成注册。模块用 `get_required_models()`、`get_required_systems()` 和 `get_required_utilities()` 声明真实依赖；架构据此编译 DAG，而不是依赖偶然的注册顺序或在初始化 Hook 中补注册。

`init()` 只建立本模块同步状态，`async_init()` 准备本模块异步资源，`ready()` 装配已 ready 的依赖，`begin_activation()` 才启动需要阻止架构过早开放的运行时流程。第三阶段完成不代表运行时可用；外部代码应等待 `is_accepting_runtime_work()` 或 `GFNodeContext.context_ready`。

依赖诊断只读，不会自动注册模块；声明缺失、歧义或成环会让初始化 fail closed。真正可选的集成用 `find_*()`，不要把 required 声明写成“有就用”的探测。

异步初始化和 activation 不要无限等待外部流程。Installer、模块准备和 bootstrap 都应使用 `GFAsyncScope`、一次性完成源以及显式 timeout/cancellation；每个异步恢复点重新检查 scope 或 lifecycle generation。

正常退出优先 `await architecture.shutdown_async()`：架构先关闭新工作准入，再按依赖逆序 quiesce 已接纳工作。同步 `dispose()` 只用于 SceneTree 退出等无法等待的 forced fallback，不能替代存档 flush 或后台任务 drain。
