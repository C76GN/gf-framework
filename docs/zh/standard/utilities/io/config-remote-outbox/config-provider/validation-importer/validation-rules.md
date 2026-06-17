# 校验规则

需要更细的导入校验时，可以给字段、记录或整表挂载 `GFConfigValidationRule`。规则只负责把问题写入通用校验报告，不解释项目业务含义。

## 内置规则

- `GFConfigRangeValidationRule`：数值范围。
- `GFConfigRegexValidationRule`：字符串格式。
- `GFConfigSetValidationRule`：白名单集合。
- `GFConfigSizeValidationRule`：字段、记录或表大小。
- `GFConfigNotDefaultValidationRule`：非默认值。
- `GFConfigResourcePathValidationRule`：Godot 资源路径与扩展名，支持 `res://` 和可解析的 `uid://`。
- `GFConfigLocalizationKeyValidationRule`：文本 key 是否存在。

## 使用示例

```gdscript
var icon_column := GFConfigTableColumn.new()
icon_column.field_name = &"icon_path"
icon_column.value_type = GFConfigTableColumn.ValueType.STRING

var path_rule := GFConfigResourcePathValidationRule.new()
path_rule.allowed_extensions = PackedStringArray(["png", "webp"])
icon_column.validation_rules.append(path_rule)

var power_column := GFConfigTableColumn.new()
power_column.field_name = &"power"
power_column.value_type = GFConfigTableColumn.ValueType.FLOAT

var power_rule := GFConfigRangeValidationRule.new()
power_rule.has_minimum = true
power_rule.minimum = 0.0
power_column.validation_rules.append(power_rule)

var table_size := GFConfigSizeValidationRule.new()
table_size.has_maximum_size = true
table_size.maximum_size = 500
schema.table_validation_rules.append(table_size)
```

## 使用边界

字段规则在类型校验通过后执行；记录规则放在 `GFConfigTableSchema.record_validation_rules`，表规则放在 `table_validation_rules`。

校验上下文会写入 `table_name`、`row_key`、`field`、`rule_id`，并在导入器提供来源信息时附带 `source`、`line`、`column`。自定义规则继承 `GFConfigValidationRule`，重写 `_validate_value()`、`_validate_record()` 或 `_validate_table()`，再通过 `_add_issue()` 写入稳定 `kind`。

资源路径规则默认允许 `uid://`。当设置了 `allowed_extensions` 时，规则会先把 UID 解析回实际资源路径，再检查扩展名；无法解析的 UID 会按缺失或扩展名不匹配报告。需要严格限制旧式 `res://` 配置时，可以关闭 `allow_uid_paths`。
