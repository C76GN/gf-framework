# 黑板 Schema

`GFBlackboardEntry` 和 `GFBlackboardSchema` 用于给运行时字典提供轻量字段契约：字段键、类型、必填性、空值策略、默认值和元数据。

它适合状态机、行为树、任务流程、编辑器工具或项目自己的 AI/流程系统共享同一套字典校验逻辑，但不规定字段含义。

```gdscript
var hp := GFBlackboardEntry.new()
hp.key = &"hp"
hp.value_type = GFBlackboardEntry.ValueType.INT
hp.required = true
hp.allow_null = false

var schema := GFBlackboardSchema.new()
schema.entries = [hp]
schema.coerce_values = true

var values := schema.apply_defaults({ "hp": "10" })
var report := schema.validate_values(values)
print(report["ok"]) # true
```

`GFBlackboardSchema` 默认允许额外字段，便于渐进接入；需要严格资源或导入校验时可关闭 `allow_extra_keys`。

类型转换只做通用 Variant 转换，不做业务范围、权限、冷却、目标合法性或状态机规则判断。

Color 字段接受 Godot HTML 颜色字符串、数组或字典通道；无效颜色字符串会返回转换失败，不会静默落成黑色。

`coerce_dictionary()` 和 `apply_defaults()` 会保留无法转换的原始值，避免把 `"bad"` 这类输入静默降级成 `0`、`false` 或空集合。需要诊断错误时，继续调用 `validate_values(values, { "coerce_values": true })` 读取 `coerce_failed` 报告。
