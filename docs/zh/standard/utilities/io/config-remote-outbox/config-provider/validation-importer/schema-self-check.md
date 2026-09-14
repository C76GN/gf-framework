# Schema 自检

`coerce_values` 是“导入期宽松转换 + 校验报告”，不是无条件吞错。`GFConfigTableColumn.try_coerce_value()` 会返回转换状态；`GFConfigTableSchema.fail_on_coerce_error` 默认开启，非法 int/float、无法解析的 Vector/Color/Array/Dictionary 等转换会记录 `coerce_failed`。

如果项目确实需要旧式宽松导入，可以显式关闭 `fail_on_coerce_error`，但 CI 和正式导表建议保持开启。Array 或 Dictionary 表需要检测重复 ID 时，开启 `require_unique_id`。

schema 本身可以先用 `validate_definition()` 做结构自检。

它只检查通用声明一致性，例如空字段、重复字段、无效或重复索引 ID、引用来源字段不存在、空校验规则等。

`element_validation_rules` 只允许用于 `ValueType.ARRAY` 列，每列最多 64 条，不能包含空规则。定义自检也会检查 Schema 的元素数与规则调用预算是否处于有效范围；这些限制及数据校验顺序见 [校验规则](validation-rules.md#数组逐元素校验)。

它不读取项目业务表，也不解释字段背后的业务含义。

```gdscript
var schema_report := schema.validate_definition({
	"source": "res://configs/items.schema.tres",
})
if not schema_report["ok"]:
	print(schema_report["issues"])
```

编辑器导入按钮或 CI 可以先跑定义自检，再校验具体表数据。
