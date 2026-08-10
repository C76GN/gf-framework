# ProjectSettings

GF 编辑器插件启用后会注册几组项目设置及其进程内默认值。这些设置是项目级配置，不是运行时全局常量；只有用户修改或所属工具执行显式保存流程时才会写入 `project.godot`。

## 设置项

- `gf/project/installers`：项目级 `GFInstaller` 脚本资源数组；接受 `res://` 或可解析的 `uid://`，运行时必须最终落到 `res://` 下的 `.gd`。
- `gf/project/fail_on_installer_error`：Installer 配置或执行失败时是否中断初始化。
- `gf/project/installer_timeout_seconds`：单个 Installer 的最长等待时间。
- `gf/codegen/access_output_path`：`GFAccess` 生成路径。
- `gf/codegen/access_policies`：按 `res://` 脚本路径声明 Model、System 和 Utility 访问器的 `scope`、`required` 与 `require_ready` 冻结策略；详见[访问器生成](access-generator.md)。
- `gf/codegen/project_access_output_path`：`GFProjectAccess` 生成路径。
- `gf/build/export/*`：标准库 debug 编辑器贡献的构建信息导出设置。
- `gf/extensions/*`：扩展启用、扩展 Installer 自动装配、禁用扩展导出排除和禁用扩展引用审计策略。
- `gf/network/*`：启用 Network 编辑器工具后，由该工具贡献的契约资源路径与访问器输出目录。

## 编辑器显示

GF 会按 Godot 编辑器的工具语言显示已声明设置的左侧分区、名称、悬浮说明和枚举选项。悬浮说明末尾始终保留稳定的 `gf/...` 设置键或分区路径，便于在源码、配置文件和诊断报告之间定位同一项设置。枚举本地化只替换可见文本，写入 `project.godot` 的值不会随语言变化。

启动 Installer 使用 Script 资源路径数组控件；代码生成输出使用“保存文件”语义，允许目标脚本尚未生成；其他现有资源引用同样使用 `res://` / `uid://` 路径输入和类型校验。资源浏览窗口属于当前 Inspector 所在窗口，不会在 Project Settings 已独占主编辑器时再打开全局 Quick Open。

内核设置的展示信息由内核维护；标准库设置通过 data-only 编辑器贡献清单提供；可选扩展工具只在启用时通过自己的编辑器动作贡献设置和分区记录。设置记录使用 `editor_labels`、`editor_descriptions`、`editor_enum_labels` 和 `editor_enum_descriptions` 声明多语言文本，分区记录使用稳定 `path` 及名称、说明映射。名称与说明必须同时存在，并提供非空 `en` 兜底。未声明展示信息的项目自有设置不会被 GF 接管，仍使用 Godot 默认 Inspector。

分区展示适配器只在可见文本实际变化时写入 TreeItem，并保存接管前的标签和悬浮说明。插件 cleanup、贡献刷新或对话框重建时会对称恢复仍由 GF 持有的显示值；如果 Godot 在此期间已经重建或修改该条目，cleanup 不会覆盖新的宿主状态。

运行时代码需要读取这些设置时，应通过对应工具类或 `ProjectSettings.get_setting()` 明确访问。`kernel/editor` 只提供通用注册机制；标准库或扩展需要自己的设置键时，应由所属编辑器贡献主动声明，避免让内核硬编码具体业务含义。

`GFProjectSettingsTools` 是底层声明工具，用于统一写入缺失默认值、缺失键的重置初始值和注册 Inspector 属性提示。`GFPluginProjectSettings.ensure_all()` 同样只负责注册，不会顺带保存同一进程内由测试或其他工具写入的临时设置。需要持久化时由扩展管理器或项目工具在明确的用户操作边界调用 `ProjectSettings.save()`。设置贡献消失、核心插件降级或只加载 kernel 时，它也不会自动删除既有项目设置，避免把项目自有配置误判为框架残留。
