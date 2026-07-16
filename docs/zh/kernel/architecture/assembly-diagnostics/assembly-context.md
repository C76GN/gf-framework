# 装配入口与局部上下文

从 `1.9.0` 起，GF Framework 支持两类装配入口。

**Installer 装配**：继承 `GFInstaller` 并重写 `install(architecture, scope)`。项目自己的启动装配放入 `Project Settings > gf/project/installers`；GF 扩展自己的装配入口放入 `gf_extension.json` 的 `installer_paths`，并由 `gf/extensions/selection_mode` 与显式 `gf/extensions/enabled` 列表共同决定是否启用。

`Gf.init()` 与 `Gf.set_architecture()` 会在三阶段生命周期开始前先执行启用扩展 Installer，再执行项目 Installer，适合集中注册全局 Model、System 和 Utility。

默认情况下，配置错误会输出错误并中断初始化。迁移旧项目时可把 `gf/project/fail_on_installer_error` 显式设为 `false` 临时跳过错误 Installer。如果 Installer 可能长期等待外部流程，可用 `gf/project/installer_timeout_seconds` 限制单步等待时间，并在 `await` 后检查 `GFAsyncScope` 是否已取消。

**节点级上下文**：在场景树中挂载 `GFNodeContext`。`SCOPED` 模式会创建一个局部 `GFArchitecture`，本地查不到依赖时会回退到父级或全局架构，并在节点退出树时自动释放局部模块；`INHERITED` 模式则复用父级或全局架构。

这两者的定位不同：Installer 解决“项目启动时装什么”，NodeContext 解决“某个场景或玩法片段拥有自己的临时模块”。

`GFController` 会优先沿父节点链查找最近的 `GFNodeContext`，因此局部 UI、输入桥接和表现节点可以继续使用熟悉的 `get_model()` / `get_system()` / `get_utility()` 形式，同时自动命中所属局部架构。

注册到局部架构中的 `GFModel`、`GFSystem`、`GFUtility` 也会保存当前架构引用，基类依赖访问会优先使用自身所属架构。模块被注销或架构释放后，这个注入作用域会失效，不会静默回退到全局架构。
