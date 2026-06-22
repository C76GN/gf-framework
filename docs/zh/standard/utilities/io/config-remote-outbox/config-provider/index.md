# 静态导表数据适配器与表校验

本组文档说明配置表 Provider、表结构声明、导入校验、跨表引用、表合并、构建 profile、静态访问器生成和编辑器辅助工具。标准库只定义通用表数据边界，不规定项目业务字段、表名含义、ID 规则或枚举来源。

## 适用范围

- 项目使用 JSON、CSV、自研导表流水线或外部表工具，需要统一运行时读取入口。
- 项目希望把导表结果保存为 Godot 原生 `.tres/.res` 资源，并在运行时通过统一 Provider 读取。
- 团队需要在导入期或 CI 中校验表结构、字段类型、跨表引用和资源路径。
- 项目希望基于 schema 生成静态访问器，减少散落的表名字符串。
- 编辑器工具需要复用通用 Resource 表格编辑和属性输入控件。

## 阅读入口

- [Provider 与 Schema](provider-schema/index.md)：`GFConfigProvider`、`GFResourceConfigProvider`、`GFConfigTableResource`、`GFConfigDatabaseResource`、`GFConfigTableColumn` 和 `GFConfigTableSchema`。
- [导入校验与规则](validation-importer/index.md)：值转换、schema 自检、校验规则、JSON/CSV 导入和报告结构；制作期 Resource 导出入口见 [Config Pipeline 导表工具包](../../../../../editor/tools/config-pipeline.md)。
- [引用、合并与构建 Profile](relations-builds/index.md)：唯一索引、跨表引用、补丁合并、构建 profile 和 schema 推导。
- [访问器生成与编辑器工具](access-editor-tools.md)：`GFConfigAccessGenerator`、`GFResourceTableEditor` 和 `GFEditorValueField`。

## 使用边界

配置表工具只提供通用数据形状、校验报告和访问入口。具体表结构、业务枚举、资源分类、热更策略、构建分端规则和编辑器提交流程仍由项目声明。
