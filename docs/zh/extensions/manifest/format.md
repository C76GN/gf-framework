# 基础格式

```json
{
  "id": "gf.combat",
  "display_name": "GF Combat",
  "version": "3.5.0",
  "extension_version": "1.5.0",
  "kind": "extension",
  "description": "Abstract combat attributes, modifiers, buffs, skills, gauges, and hit detection bridges.",
  "dependencies": ["gf.kernel", "gf.standard"],
  "installer_paths": [
    "res://addons/gf/extensions/combat/extension.gd"
  ],
  "editor_dock_order": 1000,
  "editor_dock_short_label": "",
  "enabled_by_default": false,
  "tags": ["combat", "attributes", "hit-detection"]
}
```

## 字段语义

`dependencies` 只表示硬依赖。启用当前扩展时，GF 会先补齐这些依赖，再按依赖优先顺序收集 manifest 中的 Installer 与独立 tool contribution 中的编辑器工具路径。

GF 内置扩展必须保持原子化，`dependencies` 只允许包含 `gf.kernel` 与 `gf.standard`。推荐组合、项目模板、扩展选择 preset、可选协作和加载顺序不要写进 manifest。

Manifest 只允许使用示例中的稳定字段。`optional_dependencies`、`peer_dependencies`、`extension_pack`、`preset`、`suggests`、`recommends`、`load_after` 等软依赖、组合包、推荐和加载顺序字段会被基础校验和维护检查拒绝。

`editor_action_paths`、`editor_dock_paths`、`editor_inspector_paths`、`import_plugin_paths`、`export_plugin_paths`、`gltf_document_extension_paths`、`access_generator_extension_paths` 和 `debugger_plugin_paths` 都不是运行时 manifest 字段；这些路径只能写入扩展目录下 schema v2 的 `editor/gf_tool_contribution.json`。`editor_dock_order` 与 `editor_dock_short_label` 仍保留在 manifest，作为 tool contribution 所声明工作区页面的展示元数据。旧 manifest 中的上述路径字段会被拒绝，七个迁移字段会明确提示新的声明位置；不存在双读兼容。

`enabled_by_default` 对 GF 内置可选扩展必须显式为 `false`。新项目只启用 kernel 与 standard 基础能力，业务型扩展由项目在 `GF Extensions` 页面、扩展选择 preset 或项目脚本中显式选择。
