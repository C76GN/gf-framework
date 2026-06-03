# 公式与 Variant 数据

本组页面说明资源化公式和通用 Variant 处理能力。它们用于把计算策略、深拷贝、metadata 合并、options 读取、默认值合并、JSON 兼容转换和显式引用标记集中到可复用基础层，避免各模块重复手写数据转换逻辑。

## 阅读入口

- [资源化公式](formulas.md)：`GFFormula`、`GFFormulaParameter`、`GFFormulaSet` 和类型兜底计算。
- [Variant 深拷贝与 JSON 转换](variant-data-json.md)：`GFVariantData`、metadata / options 字典语义、`GFVariantJsonCodec`、`GFVariantReferenceCodec`、Godot 类型标记和对象引用边界。

## 使用边界

这些能力只处理通用计算资源和 Variant 数据转换。公式含义、参数来源、业务校验、网络协议和存档 schema 应由项目层明确声明。
