# GF Workspace

`GF Workspace` 是核心插件固定提供的独立编辑器窗口。它把 GF 自带的扩展管理、输入映射、信号诊断和诊断快照等基础面板收束到一个响应式工作区，避免多个 GF 面板挤占 Godot 底部栏。存档图、Flow 等业务型工具页面只在对应可选扩展显式启用后，通过 `editor/gf_tool_contribution.json` 贡献到同一个工作区。

窗口右上角的“置顶”开关可让独立工作区保持在其他窗口上方，便于一边操作编辑器或运行窗口一边观察调试页面。

## 打开与布局

当前项目首次使用时，GF 会弹出工作区窗口；关闭窗口后，可从 `工具 > GF > 打开 GF 工作区` 再次打开。顶部启动方式可以选择“首次打开”“每次打开”或“手动打开”。启动方式、最近页面、关闭时的窗口位置与尺寸和置顶状态只保存到当前项目的个人编辑器偏好，不写入项目运行配置，也不需要加入版本控制。

内置页面都声明了 `label`，工作区首次打开只创建当前页面，其他页面在首次选中时加载。已访问页面会保留实例和编辑状态，切页、关闭后重新打开不会重复初始化；刷新 GF 编辑器贡献或重新加载插件时会重建页面。自定义页面应显式提供 `label`，使页面未加载时也能显示清晰的标题；没有 `label` 的旧页面仍会提前创建，以保留构造器设置的标题和按标题选页行为。初始化只处理本页必需内容，项目扫描等操作应由用户主动启动。

页面使用贡献来源标识记住选择，改名和重新排序不会改变其身份；旧贡献以脚本路径作为兼容标识。最近页面被移除时回到首个可用页面。页面切换按钮、置顶和启动方式均可通过键盘焦点访问。

工作区顶部提供自动换行的短页面入口，完整页面名保留在 tooltip；首页排在最前，其余基础页面按“状态、输入、存储、信号、诊断、扩展、保存、流程”的产品顺序展示，未启用扩展贡献的页面不会占位。标准库页面通过记录里的 `order` 和 `short_label` 声明顺序与短标签，扩展页面通过 manifest 的 `editor_dock_order` 和 `editor_dock_short_label` 声明对应信息，核心插件只按记录排序。

内容区仍只显示当前页面，避免多个工具同时挤压。每个页面都会放进无最小高度的裁剪容器，页面内容不会把窗口撑坏。右上角的“关于”按钮会打开 GF Framework 简介，并提供项目地址、正式文档地址、Issues、Releases、维护者联系方式和手动最新版本检测入口。检测到 GitHub Releases 存在更高版本时，关于弹窗会显示“打开更新页面”按钮，跳转到对应 Release；GF 不会在编辑器运行中自动覆盖 `addons/gf`，以避免丢失本地修改或替换正在加载的插件脚本。

内置页面共享 `GFEditorWorkspaceUI` 提供的页面根、工具栏、摘要、空状态和详情输出构建方式。新增页面应优先复用这些通用控件，再把真正的业务无关编辑逻辑放在页面自身脚本中，这样工作区的密度、状态颜色、空态文案和只读详情区会保持一致。

制作期工具也可以贡献工作区页面。[Project Layout](tools/project-layout.md) 的“结构”页面用于检查项目目录，[Scene Groups](tools/scene-groups.md) 的“组查询”页面用于查找已保存场景中的持久化 Group 声明。它们随完整插件提供，由用户主动启动扫描。

[3D 场景摆放](tools/scene-placement.md) 的“3D 摆放”页面负责打开或关闭原生 3D 编辑器侧栏；摆放参数、指针预览与确认在侧栏和 Godot 3D 视口中完成。

需要提交可撤销编辑的自定义页面可以实现 `set_editor_context(context: GFEditorToolContext) -> void`。工作区会在页面入树前传入由当前插件创建的上下文，页面重建、工作区离树或插件卸载时传入 `null`。没有这一方法的查看页面保持原有用法。页面应在上下文撤销后停用编辑入口，并清理待应用的输入；已经提交的命令由 Godot 的历史持有，不应强引用页面控件。上下文中的选中节点与场景根是创建时的快照，需要实时选择的工具应自行读取当前编辑器选择。

可选扩展的编辑器工具放在扩展自己的 `editor/` 目录中。`editor_action_paths`、`editor_dock_paths`、`editor_inspector_paths`、`import_plugin_paths`、`export_plugin_paths`、`gltf_document_extension_paths`、`access_generator_extension_paths` 和 `debugger_plugin_paths` 都只通过扩展目录下的 `editor/gf_tool_contribution.json` 贡献，不能写入运行时 `gf_extension.json`。贡献文件必须声明受支持的 schema 和与所属 manifest 一致的 `extension_id`，路径字段必须是非空字符串数组；schema v1、未来 schema、未知字段、错误扩展 ID 或越过扩展根的路径都会被拒绝并进入选择快照的 `tool_contribution_errors`。

无效 tool contribution 只会使选择报告进入 `partial` 并隔离该文件的无效路径，不会使运行时 manifest 图失效，也不会阻断 manifest 中有效的 `installer_paths`。工作区页面的 `editor_dock_order` 与 `editor_dock_short_label` 仍保留在 manifest 中；扩展源码包含有效贡献且扩展启用后，根编辑器插件才会在标准库 Debugger 记录之后装载 `debugger_plugin_paths` 指向的 `EditorDebuggerPlugin` 脚本，重复路径只装载一次，并在插件刷新或卸载时由同一生命周期统一移除。

## 任务首页

首页按任务提供入口，支持按名称、说明、分组和关键词搜索。按 `Ctrl+K` 可从工作区其他页面返回搜索。收藏和最近使用只保存到个人编辑器偏好；已有页面没有专用任务声明时仍提供普通打开入口。

搜索和展示任务不会创建其工具页面。禁用扩展可以声明任务说明；点击这类入口会打开扩展选择页面，由用户明确启用需要的扩展。刷新贡献后，旧上下文和未执行的路由命令失效。

“浏览项目素材”进入资源工作台；“创建 Tween 动效”打开资源创建窗口。“编辑流程图”和“检查场景存档结构”分别由 Flow / Save 扩展提供。未启用的扩展先展示说明和启用入口，启用后再从首页打开任务。

## 贡献任务与资源动作

标准库和制作期工具的 `gf_editor_contributions.json` 支持 schema 4 与 5；schema 5 新增 `task_records` 和 `resource_action_records`。扩展的 `editor/gf_tool_contribution.json` 支持 schema 2 与 3；相应新记录需要 schema 3。各版本均拒绝未声明字段。

任务记录使用本地 `source_id`、`title`、`page_path`，可附加 `description`、`group`、字符串数组 `keywords` 和 `action_id`。目标必须是同一来源已贡献的页面。宿主将来源 ID 加上所属模块前缀，避免不同工具重名。任务没有 `action_id` 时只打开页面；有值时调用该页面的 `run_workspace_task(action_id: String) -> Dictionary`。接收页面返回含 `ok` 和可读 `message` 的结果。

资源动作额外声明原生 `resource_types` 和 `max_selection`（1–100，默认 1），并必须提供 `action_id`。当前支持 `Resource`、`PackedScene`、`Texture2D`、`AudioStream`、`Font`、`Material`、`Mesh` 和 `Script`；类型判断使用编辑器文件索引，不加载项目资源脚本。接收页面实现 `receive_workspace_resources(action_id: String, paths: PackedStringArray) -> Dictionary`。该方法只接收选择并准备下一步；涉及保存或场景修改的操作仍由工具明确执行。

工具通过 `GFEditorToolContext.get_workspace_tasks()` / `request_workspace_task()` 查询和打开任务，通过 `get_resource_actions(paths)` / `request_resource_action(action_id, paths)` 查询并交接资源。查询返回可用性和原因；执行时再次检查页面、选择数量和资源类型。上下文撤销后，请求返回不可用。导航及资源交接不产生 Undo 历史，实际编辑沿用所属工具的命令机制。

贡献发现只读取有大小和数量上限的 JSON 数据，不支持脚本表达式、任意方法名或跨工具实现路径。

## 阅读工具状态与高级详情

状态、输入、信号、诊断、存储以及已启用的 Save / Flow 页面共享当前编辑器主题的文字与状态颜色。空页面说明所需输入和下一步操作；无结果、尚未扫描和发生错误分别呈现，颜色只作辅助。

输入和 Flow 可定位已经加载的资源，状态和 Save 可定位当前节点，信号可定位当前编辑场景内的来源节点。来源已删除或切换场景后，先刷新再定位。

“高级详情”用于按需展开完整数据，收起后保留选择、报告与编辑值。状态问题选中和 Save 载荷预览会显式展开对应详情。存储页的“解码选项”收起时仍保留密钥、压缩与完整性设置；应与写入文件时的设置一致，查看与复制不会改写存档。状态机页面检查已声明结构，运行时动态转换保持未知。

## Extensions 页面

`GF Extensions` 页面用于查看 `gf_extension.json`、显式启用或禁用默认关闭的内置可选扩展、检查 manifest 状态、扫描禁用扩展引用并保存扩展相关设置。

打开或刷新列表、修改选择、应用 preset 和保存设置都不会自动扫描项目引用。点击“扫描引用”后，面板才检查当前选择并展示报告；选择、项目设置或编辑器文件系统变化会使已有报告失效，需要再次扫描。状态区和禁用扩展详情区会明确区分“未扫描”“已失效”“扫描完成”和“扫描不完整”。保存成功不代表引用已通过检查，扫描不完整或过期的零引用结果也不能证明排除安全。导出阶段仍按导出策略独立审计，不使用面板缓存代替检查。

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
