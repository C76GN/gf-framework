# 异步超时与 Ready 查询

`async_init()` 适合等待网络请求、本地 IO 或大批量资源异步加载。项目应避免让开发期资源加载、网络请求或外部回调永久挂起。

## 异步超时

可通过 `GFArchitecture.module_async_init_timeout_seconds` 设置模块异步初始化超时。超时会取消当前模块收到的 `GFAsyncScope`，让架构进入初始化失败状态，并唤醒等待 `init()` / `GFNodeContext.wait_until_ready()` 的调用方。

Godot coroutine 无法被框架抢占式终止。超时会阻止架构继续推进，并让 `scope.is_cancel_requested()` 返回 true；已经挂起的 `async_init(scope)` 如果之后恢复，模块内部应先检查 scope，再决定是否写回状态。需要注册临时连接、后台请求或外部句柄清理时，使用 `scope.register_cleanup()`。

超时也不会抢占首个 `await` 之前的同步执行段。需要处理大文件、批量资源索引或复杂表格解析时，应先进入可让帧的分段流程，再在每段之间检查生命周期状态；否则一次长同步段仍会卡住主线程，并推迟超时检测。

## Ready 查询

依赖查询默认保持兼容，会返回已注册但仍处于初始化过程中的模块。如果代码必须只消费完成 `ready()` 的模块，可以在 `GFArchitecture`、`Gf`、`GFNodeContext`、`GFController`、`GFCommand`、`GFQuery`、`GFSystem` 或 `GFUtility` 的 `get_model()` / `get_system()` / `get_utility()` 中传入 `require_ready = true`。

本地查询 `get_local_*()` 也支持相同参数。需要判断某个实例是否已经完成 `ready()` 时，可调用 `architecture.is_module_ready(instance)`，模块自身可用 `is_ready_in_architecture()`。
