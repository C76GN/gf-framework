# 扩展 Installer

从 `3.0.0` 起，启用的 GF 扩展可以通过 manifest 的 `installer_paths` 提供 Installer。

当 `gf/extensions/auto_install_enabled_installers` 为 `true` 时，`Gf` 会先按依赖优先顺序执行启用扩展的 Installer，再执行 `gf/project/installers` 中的项目 Installer。

扩展 Installer 与项目 Installer 使用同一生命周期钩子签名：`install(architecture, scope)` 和 `install_bindings(binder, scope)`。如果扩展安装器需要等待外部流程，也应在 `await` 后检查 `scope.is_cancel_requested()`，并用 `scope.register_cleanup()` 释放临时资源。

扩展负责装配自己的抽象模块，项目负责装配业务模块或覆盖绑定。GF 内置扩展安装器只注册扩展级生命周期服务，例如 Save 扩展的 `GFSaveGraphUtility`、Combat 扩展的 `GFCombatSystem` 和 `GFSkillTargetingUtility2D`。

纯数据对象、Resource、命令和场景节点仍由项目或局部上下文按需要创建。

项目 Installer 不需要重复注册已启用扩展自动装配的服务。重复注册会被忽略并输出 warning。

如果项目确实要替换某个扩展默认服务，应使用 `replace_utility()` 或 `replace_system()`，而不是再次调用 `register_*()`。
