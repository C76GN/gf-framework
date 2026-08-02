# 失败状态与超时

从 `2.0.0` 起，Installer 路径为空、脚本无法加载或未继承 `GFInstaller` 时会输出错误并中断初始化。此时架构会进入 `has_initialization_failed()` 状态，并记录 `last_initialization_error`。

修正配置后再次调用 `await Gf.init()` 会在新一轮 Installer 开始时清除旧失败状态，并复用同一个架构继续重试初始化。

迁移旧项目或原型阶段如果确实需要沿用“跳过错误 Installer”的行为，可把 `Project Settings > gf/project/fail_on_installer_error` 显式设为 `false`，但建议只作为短期过渡。

如果项目级 Installer 可能等待外部资源、网络或编辑器回调，可以设置 `Project Settings > gf/project/installer_timeout_seconds`。

该值小于等于 `0.0` 时不启用超时；大于 `0.0` 时，单个 `install()` 或 `install_bindings()` 超时会让架构进入初始化失败状态。

和模块 `async_init()` 一样，Godot coroutine 无法被框架抢占式终止。超时会取消当前 Installer 收到的 `GFAsyncScope`、执行 `scope.register_cleanup()` 登记的清理回调，并阻止本轮初始化继续推进；已经挂起的 Installer 恢复后应在每个 `await` 后检查 `scope.is_cancel_requested()`，避免继续写回失效架构。需要兼容旧式状态判断时，也可以检查 `architecture.is_project_installers_running()`。

超时不抢占首个 `await` 前的同步代码。Installer 如果需要扫描大量文件、解析大型表格或构建索引，应先拆成能让帧的步骤，再在每段之间检查架构状态；否则这段同步工作仍会阻塞编辑器或启动流程。

架构进入初始化失败状态后，模块、工厂和别名注册入口会拒绝迟到写入，避免超时 coroutine 恢复后污染失败架构。

Installer 全部完成后，声明依赖缺失、歧义或成环也会直接使初始化失败，不提供 warning-only 模式或初始化期多轮补注册。应在 Installer 中补齐固定模块，并用 `get_dependency_diagnostics()` 做启动前诊断。

架构级 `module_async_init_timeout_seconds`、`activation_timeout_seconds` 与 `shutdown_timeout_seconds` 都只接受 `0..86400` 的有限秒数，`0` 禁用对应 deadline。第四阶段 activation 默认使用独立的 30 秒总预算；模块 `begin_activation(scope)` 返回的 `GFAsyncCompletion` 必须在该预算内进入成功终态，取消、超时、失败或空完成源都会阻止 READY 提交并清理本轮模块。它与单个 Installer timeout、单个 `async_init()` timeout 相互独立。

`shutdown_async(token, timeout_seconds)` 的 per-call 参数接受同一区间；默认 `-1.0` 是唯一的负值 sentinel，表示使用 `shutdown_timeout_seconds` 属性。其它负值、非有限值或大于 `86400` 的值会返回失败结果，而不是静默变成无限等待。

关闭等待已经接纳的拓扑事务时也受同一 per-call deadline 与取消令牌约束。触发接管后，框架按“夺取事务写权 → 取消事务 scope → claim 未提交候选的恰好一次清理”的顺序收敛，迟到 continuation 不能发布；若当前模块的 quiesce 失败、取消或超时，该模块本身也会进入 `unfinished_modules`，而不只记录尚未开始 quiesce 的后续模块。
