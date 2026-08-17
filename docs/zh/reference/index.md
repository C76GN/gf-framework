# 参考资料

本组页面收纳查阅型内容。指南页负责解释概念、边界和工作流；参考页负责给出可检索的 API、版本和补充资料。

## 阅读入口

- [API Reference](api/index.md)：从 XML API Catalog 生成的类、受控 AutoLoad、属性、信号和方法签名索引。
- [更新日志](../changelog.md)：当前发布版本的变更摘要、API 变化和迁移提示。

## 使用方式

先通过指南页理解模块职责，再在 API Reference 中按 owner kind 查找具体类、受控 AutoLoad 和签名。生成链路是 `addons/gf` 源码注释 -> `docs/api_catalog` XML Catalog -> Markdown Reference。当前源码仍是签名事实来源；XML Catalog 是可校验的中间层，不直接手写 Markdown。
