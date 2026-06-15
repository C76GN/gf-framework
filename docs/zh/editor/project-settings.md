# ProjectSettings

GF 编辑器插件启用后会写入几组项目设置。这些设置是项目级配置，不是运行时全局常量。

## 设置项

- `gf/project/installers`：项目级 `GFInstaller` 路径数组。
- `gf/project/fail_on_installer_error`：Installer 配置或执行失败时是否中断初始化。
- `gf/project/installer_timeout_seconds`：单个 Installer 的最长等待时间。
- `gf/codegen/access_output_path`：`GFAccess` 生成路径。
- `gf/codegen/project_access_output_path`：`GFProjectAccess` 生成路径。
- `gf/build/export/*`：构建信息导出相关设置。
- `gf/extensions/*`：扩展启用、扩展 Installer 自动装配、禁用扩展导出排除和禁用扩展引用审计策略。

运行时代码需要读取这些设置时，应通过对应工具类或 `ProjectSettings.get_setting()` 明确访问。

`GFProjectSettingsTools` 是底层声明工具，用于统一写入缺失默认值、缺失键的重置初始值和注册 Inspector 属性提示。它不会保存 `project.godot`，也不会替业务模块解释设置值；需要持久化时由插件、扩展管理器或项目工具显式调用 `ProjectSettings.save()`。
