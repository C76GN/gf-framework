# 通用 Dictionary Schema

`GFSchemaField` 与 `GFDictionarySchema` 提供最小化的 Dictionary 结构声明：字段名、类型、必填性、空值策略、默认值、宽松转换、嵌套 Dictionary、数组元素 schema 和字段级校验规则。

它们位于 Foundation 层，只表达数据形状，不读取项目设置、不访问场景树，也不解释字段的业务含义。适合给 manifest、工具参数、轻量元数据、诊断命令 payload 或项目自定义资源字典提供统一校验报告。

## 基本声明

```gdscript
var schema := GFDictionarySchema.new()
schema.schema_id = &"tool_options"
schema.allow_extra_fields = false
schema.coerce_values = true

var path_field := GFSchemaField.new().configure(&"path", GFSchemaField.ValueType.STRING, {
	"required": true,
	"allow_null": false,
})
var retry_field := GFSchemaField.new().configure(&"retry_count", GFSchemaField.ValueType.INT, {
	"default_value": 0,
})

schema.add_field(path_field)
schema.add_field(retry_field)

var report := schema.validate_dictionary({
	"path": "res://data/items.json",
	"retry_count": "3",
})
```

也可以用 `configure()` 一次性写入 schema ID、字段列表和 options。`allow_extra_fields`、`coerce_values`、`fail_on_coerce_error` 与 `metadata` 属于 schema 自身，即使字段列表为空也会立即生效，并会被 `describe()` 与 `duplicate_schema()` 保留。

`validate_dictionary()` 返回 `GFValidationReport`，问题条目使用稳定的 `kind` 和 `path`，便于编辑器工具、导入器或测试按字段定位。

## 默认值与转换

- `build_defaults()` 创建默认 Dictionary。
- `apply_defaults()` 在输入字典上补齐默认值。
- `coerce_dictionary()` 按字段类型转换已有值和默认值。
- `coerce_values = true` 时，`validate_dictionary()` 会先尝试转换字段值。
- `fail_on_coerce_error = false` 时，转换失败会记录 warning，并使用该字段类型的安全兜底值继续校验。

转换只覆盖常见 Variant 类型：bool、int、float、String、StringName、Vector2/3、Vector2i/3i、Color、Dictionary、Array、Object、Resource 和 NodePath。复杂字符串格式、枚举集、资源存在性、跨字段关系和跨表引用应由字段级 `GFValidationRule`、更高层 schema 或项目工具处理。

## 嵌套结构

Dictionary 字段可挂接另一个 `GFDictionarySchema`；Array 字段可挂接一个元素 `GFSchemaField`。

```gdscript
var stats_schema := GFDictionarySchema.new()
stats_schema.add_field(GFSchemaField.new().configure(&"power", GFSchemaField.ValueType.INT, {
	"required": true,
}))

var root_schema := GFDictionarySchema.new()
root_schema.add_field(GFSchemaField.new().configure(&"stats", GFSchemaField.ValueType.DICTIONARY, {
	"dictionary_schema": stats_schema,
}))
root_schema.add_field(GFSchemaField.new().configure(&"tags", GFSchemaField.ValueType.ARRAY, {
	"array_item_schema": GFSchemaField.new().configure(&"", GFSchemaField.ValueType.STRING),
}))
```

嵌套问题会保留路径，例如 `stats/power` 或 `tags[1]`。`validate_definition()` 也会递归检查嵌套 schema 的空字段名、重复字段名和 null 字段。

## 字段级规则

`GFSchemaField.validation_rules` 可挂接通用 `GFValidationRule`。这些规则会在基础类型、空值和嵌套 schema 通过后执行，适合表达范围、集合、格式或项目自定义约束，而不需要把所有可能的校验关键字都写进 Foundation 字段类型。

```gdscript
var positive_rule := GFValidationRule.new().configure(
	&"positive_value",
	func(value, _report, _context):
		return "" if int(value) > 0 else "Value must be positive."
)

var score_field := GFSchemaField.new().configure(&"score", GFSchemaField.ValueType.INT, {
	"validation_rules": [positive_rule],
})
```

规则返回的普通 issue 会继承字段路径与 key；需要更细粒度定位时，规则回调也可以直接向传入的 `GFValidationReport` 写入自定义 issue。

## 与其他 Schema 的边界

- `GFDictionarySchema` 是通用字典形状工具，适合被 Foundation、Utilities、扩展和项目代码复用。
- `GFBlackboardSchema` 面向运行时黑板，保留黑板字段契约和默认值语义。
- `GFConfigTableSchema` 面向导表和配置表，包含列、索引、跨表引用、导入期转换和配置校验规则。
- 需要完整 JSON Schema 兼容、项目枚举库、资源解析、导入器 UI、存档迁移或业务规则时，应在 Utilities、扩展或项目层组合实现，不应塞进 Foundation schema primitives。

## API Reference

- [`GFDictionarySchema`](../../../reference/api/classes/GFDictionarySchema.md)
- [`GFSchemaField`](../../../reference/api/classes/GFSchemaField.md)
