# 读取与校验

`GFExtensionManifest` 负责读取和校验 manifest。

`GFExtensionCatalog` 负责扫描 GF 内置扩展目录，以及项目在 `gf/extensions/external_roots` 中声明的额外扩展集合根目录。每个集合根目录下一层目录视为一个独立扩展，扩展目录内应放置 `gf_extension.json`。

`GFExtensionSettings` 负责读取项目启用状态、查询扩展是否存在或启用、补齐依赖闭包、收集启用扩展的 Installer 路径和编辑器扩展路径，并提供按扩展 ID 解析扩展内资源或加载启用扩展脚本的统一入口。

`GFExtensionSettings` 会缓存一次 manifest 扫描结果，避免编辑器 Inspector、扩展面板和扩展查询在同一会话里反复读盘。

扩展目录或 `gf/extensions/external_roots` 发生变化时可调用 `clear_manifest_cache()` 刷新。通过 `GFExtensionSettings.set_external_extension_roots()` 保存根目录时会自动刷新缓存。额外扩展根目录和禁用扩展引用审计的扫描/忽略根会复用 `GFPathTools` 做路径集合规范化，反斜杠、尾随斜杠和重复根目录不会改变扫描语义。

读取 `gf_extension.json` 时，`GFExtensionManifest` 会裁剪标量文本字段，依赖 ID 和标签会按首次出现顺序去空、去重。扩展脚本路径列表只做空白裁剪、斜杠统一和 `.` / `..` 简化，不会在读取阶段丢弃空路径，因此 `get_validation_errors()` 仍能报告无效声明。

依赖补齐会检测循环依赖并停止递归。

正常无环时，`resolve_extension_dependencies()`、`get_enabled_manifests()` 和启用扩展路径收集都会保持依赖优先顺序，不依赖 manifest 扫描顺序。

扩展 manifest 图存在重复 ID、缺失依赖、循环依赖或无效 manifest 时，启用扩展 manifest 查询、Installer 路径收集、编辑器扩展路径收集、`load_enabled_extension_script()` 和导出扩展过滤会被阻断。框架会把错误提前暴露在扩展加载或导出阶段，而不是等到脚本加载、Installer 执行或导出产物缺文件时再失败。

`get_extension_resource_path()` 和 `load_enabled_extension_script()` 只解析扩展根目录内资源。相对路径会拼接到 manifest root；`res://` 绝对路径必须仍位于该 root 下；`user://`、其他扩展目录和 `..` 越界路径会返回空结果。

`get_manifest_graph_report()` 可一次性报告重复扩展 ID、缺失硬依赖、无效 manifest 与依赖环。
