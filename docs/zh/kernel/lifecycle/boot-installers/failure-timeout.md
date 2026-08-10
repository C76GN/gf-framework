# 失败状态与超时

从 `2.0.0` 起，Installer 路径为空、脚本无法加载或未继承 `GFInstaller` 时会输出错误并中断初始化。此时架构会进入 `has_initialization_failed()` 状态，并记录 `last_initialization_error`。

修正配置后再次调用 `await Gf.init()` 会在新一轮 Installer 开始时清除旧失败状态，并复用同一个架构继续重试初始化。

迁移旧项目或原型阶段如果确实需要沿用“跳过错误 Installer”的行为，可把 `Project Settings > gf/project/fail_on_installer_error` 显式设为 `false`，但建议只作为短期过渡。

如果项目级 Installer 可能等待外部资源、网络或编辑器回调，可以设置 `Project Settings > gf/project/installer_timeout_seconds`。

该值小于等于 `0.0` 时不启用超时；大于 `0.0` 时，单个 `install()` 或 `install_bindings()` 超时会让架构进入初始化失败状态。

和模块 `async_init()` 一样，Godot coroutine 无法被框架抢占式终止。超时会取消当前 Installer 收到的 `GFAsyncScope`、执行 `scope.register_cleanup()` 登记的清理回调，并阻止本轮初始化继续推进；已经挂起的 Installer 恢复后应在每个 `await` 后检查 `scope.is_cancel_requested()`，避免继续写回失效架构。需要兼容旧式状态判断时，也可以检查 `architecture.is_project_installers_running()`。

Installer 主动调用 `scope.cancel(reason)` 并返回时，同样会把本轮装配收敛到现有初始化失败终态：保留首次取消原因，清除 running、保持 applied 为 false，回滚本轮已注册模块，并恰好一次唤醒所有等待 `project_installers_finished` / `Gf.init()` 的调用方。通过 `Gf.init()` 初始化当前 Architecture 时，修正取消条件后可以复用同一实例重试；`Gf.set_architecture(candidate)` 的未发布候选仍按原子 assignment 规则释放，重试必须创建新 candidate。若启用了 Installer timeout，旧 detached continuation 尚未真正返回时，重试会 fail fast，待旧 continuation 收尾后才重新开放 Installer 准入。timeout 为 `0` 时没有 detached 轮询，框架只能在 Installer 方法返回后观察取消，不能抢占一个取消后仍永久挂起的 coroutine。

`project_installers_finished` 只在本轮失败回滚完成、注册表已经清理后发出。失败结算或 quiesce/dispose 终态的同步回调中，`begin_project_installers()` 与 `architecture.init()` 返回 false，`mark_project_installers_applied()` / `finish_project_installers()` 保持 no-op；回调不能重新打开 running、覆盖 applied 终态或重启 lifecycle。

超时不抢占首个 `await` 前的同步代码。Installer 如果需要扫描大量文件、解析大型表格或构建索引，应先拆成能让帧的步骤，再在每段之间检查架构状态；否则这段同步工作仍会阻塞编辑器或启动流程。

架构进入初始化失败状态后，模块、工厂和别名注册入口会拒绝迟到写入，避免超时 coroutine 恢复后污染失败架构。

Installer 全部完成后，声明依赖缺失、歧义或成环也会直接使初始化失败，不提供 warning-only 模式或初始化期多轮补注册。应在 Installer 中补齐固定模块，并用 `get_dependency_diagnostics()` 做启动前诊断。

架构级 `module_async_init_timeout_seconds`、`activation_timeout_seconds` 与 `shutdown_timeout_seconds` 都只接受 `0..86400` 的有限秒数，`0` 禁用对应 deadline。第四阶段 activation 默认使用独立的 30 秒总预算；模块 `begin_activation(scope)` 返回的 `GFAsyncCompletion` 必须在该预算内进入成功终态，取消、超时、失败或空完成源都会阻止 READY 提交并清理本轮模块。它与单个 Installer timeout、单个 `async_init()` timeout 相互独立。

`shutdown_async(token, timeout_seconds)` 的 per-call 参数接受同一区间；默认 `-1.0` 是唯一的负值 sentinel，表示使用 `shutdown_timeout_seconds` 属性。其它负值、非有限值或大于 `86400` 的值会返回失败结果，而不是静默变成无限等待。

关闭等待已经接纳的拓扑事务时也受同一 per-call deadline 与取消令牌约束。触发接管后，框架按“夺取事务写权 → 取消事务 scope → claim 未提交候选的恰好一次清理”的顺序收敛，迟到 continuation 不能发布；若当前模块的 quiesce 失败、取消或超时，该模块本身也会进入 `unfinished_modules`，而不只记录尚未开始 quiesce 的后续模块。
