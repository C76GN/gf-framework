# 读取与校验

## 发现职责与缓存

`GFExtensionManifest` 负责读取和校验 manifest。

`GFExtensionCatalog` 负责扫描 GF 内置扩展目录，以及项目在 `gf/extensions/external_roots` 中声明的额外扩展集合根目录。每个集合根目录下一层目录视为一个独立扩展，扩展目录内应放置 `gf_extension.json`。

`GFExtensionSettings` 负责读取项目启用状态、查询扩展是否存在或启用、补齐依赖闭包、收集启用扩展的 Installer 路径和编辑器扩展路径，并提供按扩展 ID 解析扩展内资源或加载启用扩展脚本的统一入口。

`GFExtensionSettings` 会缓存 manifest、preset 与启用选择快照，避免编辑器 Inspector、扩展面板和扩展查询在同一会话里重复解析和构图。缓存身份来自完整内容摘要和规范化语义；manifest 的展示字段、版本、类型、默认启用状态、标签或 `installer_paths` 变化，以及 tool contribution 的任一路径字段变化，都必须使启用选择快照失效。不能用 mtime 或文件大小代替内容身份，因为同时间戳、同大小改写仍可能改变授权路径或校验结果。

扩展目录或 `gf/extensions/external_roots` 发生变化时可调用 `clear_manifest_cache()` 刷新。通过 `GFExtensionSettings.set_external_extension_roots()` 保存根目录时会自动刷新缓存。额外扩展根目录和禁用扩展引用审计的扫描/忽略根会复用 `GFPathTools` 做路径集合规范化，反斜杠、尾随斜杠和重复根目录不会改变扫描语义。

## Schema 与读取预算

读取 `gf_extension.json` 时，`GFExtensionManifest` 会裁剪标量文本字段，依赖 ID 和标签会按首次出现顺序去空、去重。`installer_paths` 只做空白裁剪、斜杠统一和 `.` / `..` 简化，不会在读取阶段丢弃空路径，因此 `get_validation_errors()` 仍能报告无效声明。七类编辑器路径与 `debugger_plugin_paths` 不属于 manifest schema，只由 tool contribution 解析。

Manifest 与 preset 会在规范化前检查原始字段类型。字段缺失时可以使用协议默认值；字段存在但容器、元素或标量类型错误时必须产生字段级诊断，不能静默退化为默认值。程序内构造允许等价的 `StringName`、`PackedStringArray` 和整数值，但 JSON 输入仍必须能无歧义地映射到声明类型。

Manifest、preset 和 tool contribution 共用有界 JSON reader。默认硬上限为单文件 1 MiB、一次发现操作累计 64 MiB、嵌套深度 64；调用方只能进一步收紧，不能放宽。文件长度会在正文物化和 JSON 解析前检查，cache 内容摘要使用分块 SHA-256；签名读取与随后解析共用累计字节预算。超限会进入对应 load error、preset report 或 tool contribution error，不会保留为有效路径。

`GFExtensionManifest.from_json_file()` 只在文件可读、JSON 为对象且校验通过时返回 manifest；需要给编辑器面板或 CI 展示失败原因时，使用 `from_json_file_report()` 读取 `ok`、`errors` 和 JSON-safe 的 `manifest_data`。公开报告不携带运行时对象引用，适合继续写入日志、诊断快照或工具 JSON 输出。

## 依赖图与路径授权

依赖补齐会检测循环依赖并停止递归。

正常无环时，`resolve_extension_dependencies()`、`get_enabled_manifests()` 和启用扩展路径收集都会保持依赖优先顺序，不依赖 manifest 扫描顺序。

启用选择使用三态状态，而不是让一个 `ok` 同时承担完整性与可用性：

- `valid`：manifest 图、配置 ID 与所有已存在的 tool contribution 都有效；`ok=true`。
- `partial`：manifest 图仍有效，但存在未知启用 ID 或某个已存在的 tool contribution 无效；问题扩展的无效贡献被隔离，已验证的已知扩展路径和 manifest 中的有效 `installer_paths` 仍可使用，`paths_allowed=true`。
- `invalid`：manifest 图存在重复 ID、缺失依赖、循环依赖、无效 manifest 或 manifest load error；所有扩展路径被阻断，`paths_allowed=false`。

`GFExtensionSettings.get_extension_selection_report()` 会投影 `status`、`partial`、`paths_allowed` 和 `tool_contribution_errors`。路径 getter 只依据明确的 `paths_allowed` 授权，不再让调用方猜测 `ok` 或 `graph_ok` 的隐含副作用语义。框架会把错误提前暴露在扩展加载或导出阶段，而不是等到脚本加载、Installer 执行或导出产物缺文件时再失败。

`get_extension_resource_path()` 和 `load_enabled_extension_script()` 只解析扩展根目录内资源。相对路径会拼接到 manifest root；`res://` 绝对路径必须仍位于该 root 下；`user://`、其他扩展目录和 `..` 越界路径会返回空结果。manifest 中缺失或无效的 Installer 脚本会使 manifest 图校验失败；tool contribution 中缺失或无效的工具脚本则被隔离为 `partial`，不会拖累运行时 manifest 图。

`get_manifest_graph_report()` 可一次性报告重复扩展 ID、缺失硬依赖、无效 manifest 与依赖环。需要把上一次目录扫描中的 JSON 读取失败也纳入报告时，传入 `include_cached_load_errors = true`。

## 禁用扩展引用审计

禁用扩展引用审计由“扩展 `class_name` 预扫描”和“项目引用扫描”两个阶段组成。两个阶段共享 `max_scan_depth`、`max_scanned_files`、`max_file_bytes` 与 `max_total_bytes`；任一阶段截断都会传播为 `partial_scan`、`skipped_files`、`scan_warnings` 和结构化 `issues`。只需要引用数组时可继续使用 `find_references_to_root()`；需要判断“未发现引用”是否建立在完整扫描上时，必须使用 `find_references_to_root_report()` 并检查 `ok` / `partial_scan`。
