# 编辑器扩展管理器

启用 GF 编辑器插件后，会默认打开独立的 `GF Workspace`。其中 `GF Extensions` 页面用于查看所有 GF 内置扩展的 manifest 信息、启用/禁用扩展、查看发行版本与扩展版本、依赖、标签、Installer 路径、编辑器扩展路径和校验状态。

## 扩展面板

面板中的“有效/无效”表示 manifest 是否通过基础校验；“保存设置”会把当前勾选状态和扩展相关开关写入 ProjectSettings。搜索框只影响当前列表显示，不会自动修改启用状态。

“扩展组合”下拉框读取 `GFExtensionSettings.get_extension_presets()`。GF 内置只提供动态基础组合，例如默认选择、全部关闭和全部可发现扩展；项目或外部插件可以通过 `gf/extensions/preset_paths` 提供业务组合 JSON，也可以在面板中通过“添加组合文件”选择项目内的 JSON 文件。点击“应用组合”只会更新当前勾选状态，仍需要点击“保存设置”持久化；“移除组合文件”只会移除项目 preset 路径，不能删除内置动态组合。

组合 JSON 只允许描述启用 ID、显示名、说明和标签。扩展管理器不会从 preset 读取下载地址、包仓库、Installer 覆盖或软依赖字段。GF 内置安装向导只应写入本地 ProjectSettings、preset 启用状态并提示导出审计；下载、registry、包仓库或复杂包安装只能由 `addons/gf` 外的独立插件或项目自管工具承担。

扩展管理器保存的是 GF 自己的扩展启用状态，不是 Godot 原生插件开关。Godot 仍会在编辑器中看到项目里存在的脚本和 `class_name`；真正影响运行时的是启用扩展的 Installer 是否自动执行，真正影响导出内容的是导出插件是否跳过禁用扩展目录。

## 编辑器贡献

GF 自带的扩展相关编辑器增强会读取同一套启用状态。扩展可以用 `editor_action_paths` 声明 GF 工具菜单动作和脚本模板记录，用 `editor_dock_paths` 声明 `GF` 工作区页面，并通过 `editor_dock_order` 与 `editor_dock_short_label` 给页面提供排序和短标签，用 `editor_inspector_paths` 声明 `EditorInspectorPlugin`，用 `import_plugin_paths` 声明 `EditorImportPlugin`，用 `export_plugin_paths` 声明导出插件入口，用 `gltf_document_extension_paths` 声明 `GLTFDocumentExtension` 导入桥接，用 `access_generator_extension_paths` 声明访问器生成扩展。

核心插件只负责按 manifest 装载启用扩展的贡献，不在 `kernel` 中硬编码可选扩展脚本、扩展 ID 或扩展内模板类型。

`access_generator_extension_paths` 会被 `GFAccessGenerator` 消费。扩展脚本建议继承 `RefCounted`，并实现 `append_access_source(builder, records)` 直接使用 `GFSourceBuilder` 追加源码；如果只需要返回静态片段，也可以实现 `get_access_source_sections(records)` 并返回字符串数组。扩展只会从当前启用扩展中读取，因此禁用扩展不会继续影响新生成的访问器。

## 引用审计与导出

面板提供“扫描引用”，底层由 `GFExtensionUsageAudit` 检查当前禁用扩展是否仍被项目文件直接引用。保存设置和导出开始时也会执行同类检查；如果发现项目脚本、场景或资源里仍出现禁用扩展根目录路径，或直接使用了禁用扩展导出的 `class_name`，会输出警告并列出文件位置。

引用审计默认只跳过 Godot / VCS 隐藏缓存目录和被检查扩展自身，不会默认排除 `docs`、`tests`、`tools` 或其他项目目录；项目自定义入口如果确实要跳过某些目录，应显式传入 `ignored_roots`。引用审计默认限制目录深度和扫描文件数量，项目自定义入口可通过 `max_scan_depth` / `max_scanned_files` 调整。

`gf/extensions/export_fail_on_disabled_references` 控制引用禁用扩展时是否阻止导出。保持开启可以避免导出产物缺少被项目脚本或资源仍在引用的扩展文件；只有在排查引用清理流程时才需要临时关闭。

导出排除有一个重要前提：项目不应直接引用禁用扩展里的脚本、场景或资源。如果某个场景、preload 或导出资源仍然依赖禁用扩展，排除该扩展会让导出产物缺文件。扩展管理器负责表达意图和执行排除，项目层仍需要保证依赖关系一致。

如果项目完全不使用某个 GF 内置扩展，也可以删除该扩展目录。`kernel` 与 `standard` 不会硬 preload 内置扩展脚本，也不会直接类型引用内置扩展；编辑器工具遇到缺失的可选扩展会动态跳过对应增强功能。删除目录前仍要确认项目代码、场景、资源和生成脚本没有直接引用被删除扩展。

扩展可以向标准库的通用扩展点贡献能力，但依赖方向必须从扩展指向标准库。例如 ActionQueue 扩展可以在运行时向 `GFDiagnosticsUtility` 注册自己的工具快照和监控项，Network 扩展可以注册 `network` 诊断分区；`GFDiagnosticsUtility` 本身不写死这些扩展的 ID、路径或类名。这样扩展禁用或删除时，贡献自然消失，标准库仍保持完整可运行。
