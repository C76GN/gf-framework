# 路径贡献

这些字段可省略：

- `enabled_by_default`
- `installer_paths`
- `editor_action_paths`
- `editor_dock_paths`
- `editor_dock_order`
- `editor_dock_short_label`
- `editor_inspector_paths`
- `import_plugin_paths`
- `export_plugin_paths`
- `gltf_document_extension_paths`
- `access_generator_extension_paths`

`enabled_by_default` 省略时，可选扩展默认不进入 GF 的默认扩展选择。GF 内置可选扩展应显式写为 `false`，由项目按需启用。

没有安装器或编辑器扩展的扩展可以把对应数组留空。

manifest 声明的扩展脚本路径必须位于扩展根目录内，避免扩展通过 manifest 越界绑定其他扩展或项目脚本。

校验时会先规范化路径，所以包含 `..` 后实际逃出根目录的路径也会被拒绝。

`editor_dock_order` 只影响 GF 工作区页面排序，数值越小越靠前。

`editor_dock_short_label` 只影响顶部页面入口短标签，不改变页面脚本路径或运行时行为。

## Tool-only Debugger 贡献

`debugger_plugin_paths` 不属于上述 manifest 路径字段，只能写入扩展目录下 schema v2 的 `editor/gf_tool_contribution.json`。这样只安装 runtime package 的项目不会隐式获得制作期 Debugger 脚本；安装 tool package 后，当前启用扩展的有效路径才会进入根编辑器插件生命周期。

schema v1 不再兼容，现有 tool contribution 必须整体升级为 `schema_version: 2`，即使该文件暂时没有声明 Debugger 插件。
