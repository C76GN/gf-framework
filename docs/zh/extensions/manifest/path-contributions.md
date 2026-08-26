# 路径贡献

## 运行时 Manifest

`gf_extension.json` 中与启用和路径装配相关的字段可省略：

- `enabled_by_default`
- `installer_paths`
- `editor_dock_order`
- `editor_dock_short_label`

`enabled_by_default` 省略时，可选扩展默认不进入 GF 的默认扩展选择。GF 内置可选扩展应显式写为 `false`，由项目按需启用。

没有运行时安装器的扩展可以省略 `installer_paths` 或把它留空。

manifest 声明的 Installer 脚本路径必须位于扩展根目录内，避免扩展通过 manifest 越界绑定其他扩展或项目脚本。

校验时会先规范化路径，所以包含 `..` 后实际逃出根目录的路径也会被拒绝。

`editor_dock_order` 只影响 tool contribution 中工作区页面的排序，数值越小越靠前。

`editor_dock_short_label` 只影响顶部页面入口短标签，不改变页面脚本路径或运行时行为。

## 编辑器 Tool Contribution

以下八类路径只能写入扩展目录下 schema v2 的 `editor/gf_tool_contribution.json`，不能写入运行时 manifest：

- `editor_action_paths`
- `editor_dock_paths`
- `editor_inspector_paths`
- `import_plugin_paths`
- `export_plugin_paths`
- `gltf_document_extension_paths`
- `access_generator_extension_paths`
- `debugger_plugin_paths`

工具贡献路径必须位于所属扩展根目录内，并随完整 GF 插件一起分发。扩展启用后，有效路径才会进入根编辑器插件生命周期；禁用扩展时，对应编辑器贡献不会装载，导出过滤也可以排除其目录。`editor_dock_paths` 指向的页面继续使用运行时 manifest 中的 `editor_dock_order` 和 `editor_dock_short_label` 作为展示元数据。

不存在 `editor/gf_tool_contribution.json` 表示扩展没有工具贡献，不是错误。文件存在但 schema、扩展 ID、路径边界、资源或脚本类型无效时，选择报告进入 `partial` 并隔离该文件的无效路径；运行时 manifest 图及其有效 `installer_paths` 仍可使用。把上述八类字段写入 `gf_extension.json` 会被拒绝，七个迁移字段会明确提示新的声明位置；不提供永久双读兼容。

schema v1 不再兼容，现有 tool contribution 必须整体升级为 `schema_version: 2`，即使该文件暂时没有声明 Debugger 插件。
