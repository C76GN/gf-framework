# GF Workspace

`GF Workspace` 是核心插件固定提供的独立编辑器窗口。它把 GF 自带的扩展管理、输入映射、信号诊断和诊断快照等基础面板收束到一个响应式工作区，避免多个 GF 面板挤占 Godot 底部栏。存档图、Flow 等业务型工具页面只在对应可选扩展显式启用后，通过 `editor/gf_tool_contribution.json` 贡献到同一个工作区。

窗口右上角的“置顶”开关可让独立工作区保持在其他窗口上方，便于一边操作编辑器或运行窗口一边观察调试页面。

## 打开与布局

插件启用或编辑器打开项目时，GF 会默认弹出工作区窗口；关闭窗口后，可从 `工具 > GF > 打开 GF 工作区` 再次打开。

工作区顶部提供自动换行的短页面入口，完整页面名保留在 tooltip；页面默认按“状态、输入、存储、信号、诊断、扩展、保存、流程”的产品顺序展示，未启用扩展贡献的页面不会占位。标准库页面通过记录里的 `order` 和 `short_label` 声明顺序与短标签，扩展页面通过 manifest 的 `editor_dock_order` 和 `editor_dock_short_label` 声明对应信息，核心插件只按记录排序。

内容区仍只显示当前页面，避免多个工具同时挤压。每个页面都会放进无最小高度的裁剪容器，页面内容不会把窗口撑坏。右上角的“关于”按钮会打开 GF Framework 简介，并提供项目地址、正式文档地址、Issues、Releases、维护者联系方式和手动最新版本检测入口。检测到 GitHub Releases 存在更高版本时，关于弹窗会显示“打开更新页面”按钮，跳转到对应 Release；GF 不会在编辑器运行中自动覆盖 `addons/gf`，以避免丢失本地修改或替换正在加载的插件脚本。

内置页面共享 `GFEditorWorkspaceUI` 提供的页面根、工具栏、摘要、空状态和详情输出构建方式。新增页面应优先复用这些通用控件，再把真正的业务无关编辑逻辑放在页面自身脚本中，这样工作区的密度、状态颜色、空态文案和只读详情区会保持一致。

可选扩展的编辑器工具放在扩展自己的 `editor/` 目录中。`editor_action_paths`、`editor_dock_paths`、`editor_inspector_paths`、`import_plugin_paths`、`export_plugin_paths`、`gltf_document_extension_paths`、`access_generator_extension_paths` 和 `debugger_plugin_paths` 都只通过扩展目录下的 `editor/gf_tool_contribution.json` 贡献，不能写入运行时 `gf_extension.json`。贡献文件必须声明 `schema_version: 2` 和与所属 manifest 一致的 `extension_id`，路径字段必须是非空字符串数组；schema v1、未来 schema、未知字段、错误扩展 ID 或越过扩展根的路径都会被拒绝并进入选择快照的 `tool_contribution_errors`。

无效 tool contribution 只会使选择报告进入 `partial` 并隔离该文件的无效路径，不会使运行时 manifest 图失效，也不会阻断 manifest 中有效的 `installer_paths`。工作区页面的 `editor_dock_order` 与 `editor_dock_short_label` 仍保留在 manifest 中；扩展源码包含有效贡献且扩展启用后，根编辑器插件才会在标准库 Debugger 记录之后装载 `debugger_plugin_paths` 指向的 `EditorDebuggerPlugin` 脚本，重复路径只装载一次，并在插件刷新或卸载时由同一生命周期统一移除。

## Extensions 页面

`GF Extensions` 页面用于查看 `gf_extension.json`、显式启用或禁用默认关闭的内置可选扩展、检查 manifest 状态、扫描禁用扩展引用并保存扩展相关设置。

扩展 preset 会先校验 ID、依赖 ID 和来源路径；项目工具需要审查 preset 配置时，可读取 `GFExtensionSettings.get_extension_preset_report()` 获取有效、无效、重复和跳过的 preset 记录。

面板里的三个开关含义不同：

- `自动装配启用扩展 Installer`：`Gf.init()` / `Gf.set_architecture()` 时执行启用扩展 manifest 声明的 `installer_paths`。
- `导出时排除禁用扩展`：导出阶段跳过禁用扩展根目录下的文件。
- `引用禁用扩展时阻止导出`：导出审计发现项目仍引用禁用扩展时，以错误形式报告，适合发布前或 CI 使用。

扩展启用状态不会让编辑器中的脚本或 `class_name` 立刻消失。它影响的是扩展 Installer 是否自动参与运行时装配，以及导出时是否排除禁用扩展目录。禁用或删除扩展前，应先清理项目脚本、场景、资源、preload 和已生成访问器中的直接引用。

扩展管理只作用于完整插件中已经存在的本地源码，不下载、更新或卸载框架文件。`extensions/content_package` 管理的是游戏内容 manifest 与内容依赖，也不是框架安装入口。

## 更新框架

GF Workspace 不下载、安装或更新框架文件。“关于”弹窗只负责检查是否有新版本并打开对应 Release 页面。升级时关闭 Godot，提交或备份项目，再用单个新版本的完整发布包替换整个 `addons/gf`。

GF 10 模块化安装项目应先按照[从 GF 10 模块化安装迁移](../overview/quickstart/package-manager-migration.md)收敛旧事务；GF 11 不会继续读取安装源或写入 package lockfile。
