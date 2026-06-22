# Provider 与 Schema

当项目使用 JSON、CSV 或自定义导表流水线时，可以继承 `GFConfigProvider` 提供统一读取入口，并把具体加载和查询逻辑留在项目侧实现。需要 Godot 原生资源产物时，单表可用 `GFConfigTableResource`，多表整包可用 `GFConfigDatabaseResource`，再通过 `GFResourceConfigProvider` 接入运行时查询。

## 阅读入口

- [Provider 适配器](provider-adapter.md)：`GFConfigProvider` 的读取入口、Resource 表/数据库适配、返回值边界和加载建议。
- [Schema 声明](schema-declaration.md)：`GFConfigTableColumn`、`GFConfigTableSchema`、字段约束、表校验入口和 schema 副本语义。

## 使用边界

标准库只定义通用表数据读取入口、字段结构声明和校验报告。具体表结构、业务枚举、资源分类、热更策略和构建分端规则仍由项目声明。
