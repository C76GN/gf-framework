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
