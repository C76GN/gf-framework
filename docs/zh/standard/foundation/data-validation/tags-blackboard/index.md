# Foundation 标签、黑板与数据契约

这一组文档说明标签查询和黑板 Schema 的基础能力。它们适合描述可组合的数据条件和运行时字典契约，但不维护全局标签命名表，也不把业务规则写入 Foundation 层。

## 阅读入口

- [标签集合与查询](tag-query.md)：`GFTagSet`、`GFTagQuery` 的标签、层数、all/any/none 查询和层级匹配。
- [标签目录与重定向](tag-catalog.md)：`GFTagCatalog` 的可选标签定义、旧标签重定向、目录外标签校验和规范化。
- [标签表达式与来源适配](tag-expression-source.md)：`GFTagExpression` 组合查询，以及 `GFTagSourceAdapter` 读取不同对象形态。
- [黑板 Schema](blackboard-schema.md)：`GFBlackboardEntry`、`GFBlackboardSchema` 的字段契约、默认值、转换和校验边界。

## 使用边界

标签工具只处理 `StringName` 标签和通用查询语义；`GFTagCatalog` 只是调用方显式使用的可选目录，不会让全局标签表成为框架要求。黑板 Schema 只校验字典结构，不解释业务字段含义。
