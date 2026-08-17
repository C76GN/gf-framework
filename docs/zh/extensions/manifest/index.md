# Manifest 规范

每个扩展应提供 `gf_extension.json`。它声明扩展 ID、版本、依赖、运行时 Installer、工作区页面展示元数据和默认启用状态；编辑器工具路径由独立的 `editor/gf_tool_contribution.json` 声明。

## 阅读入口

- [基础格式](format.md)：`gf_extension.json` 的标准字段示例。
- [版本字段](version-fields.md)：`version` 与 `extension_version` 的职责和递增规则。
- [路径贡献](path-contributions.md)：运行时 Installer 与独立编辑器 tool contribution 的所有权边界。
- [读取与校验](loading-validation.md)：`GFExtensionManifest`、`GFExtensionCatalog`、`GFExtensionSettings` 与图报告。

## 使用边界

Manifest 是轻量文件约定，不是下载器、preset 文件或跨扩展编排入口。外部插件如果要组合多个 GF 内置扩展，应在自己的代码、Installer 或文档中表达组合关系，不写回 GF 内置扩展。

GF 内置扩展 manifest 采用字段白名单。`optional_dependencies`、`peer_dependencies`、`extension_pack`、`preset`、`suggests`、`recommends`、`load_after` 等软依赖或组合字段都不允许出现在内置扩展 manifest 中。

## 类型与依赖

`kind` 对 GF 内置扩展使用 `extension`；标准库内部 manifest 使用 `standard`。扩展工具只处理这两个稳定类型。

`dependencies` 是硬依赖。启用当前扩展时，`GFExtensionSettings` 会自动补齐这些依赖，并让依赖扩展排在依赖方之前。GF 内置扩展只允许声明 `gf.kernel` 与 `gf.standard`，并且源码只能引用自身、`kernel` 和稳定的 `standard`。

跨扩展协作应通过项目侧组合或独立插件完成。需要贡献 Installer 时写入运行时 manifest；需要贡献调试项、编辑器页、导入器、导出器或访问器生成入口时写入 `editor/gf_tool_contribution.json`，或使用 `standard` 的通用注册点主动贡献，不让 `kernel`、`standard` 或其他内置扩展反向探测它。
