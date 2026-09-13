# 校验规则

需要更细的导入校验时，可以给字段、记录或整表挂载 `GFConfigValidationRule`。规则只负责把问题写入通用校验报告，不解释项目业务含义。

## 内置规则

- `GFConfigRangeValidationRule`：数值范围。
- `GFConfigRegexValidationRule`：字符串格式。
- `GFConfigSetValidationRule`：白名单集合；小集合直接输出 `supported_values`，大集合输出数量、样本和 hash，避免报告膨胀。
- `GFConfigSizeValidationRule`：字段、记录或表大小。
- `GFConfigNotDefaultValidationRule`：非默认值。
- `GFConfigResourcePathValidationRule`：Godot 资源路径与扩展名，支持 `res://` 和可解析的 `uid://`。
- `GFConfigLocalizationKeyValidationRule`：文本 key 是否存在。默认要求显式 `known_keys` 或 `text_map`，避免把 `TranslationServer.translate(key) == key` 误当作可靠存在性证明。

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

## 数组逐元素校验

`ValueType.ARRAY` 字段可以通过 `element_validation_rules` 对每个元素复用普通值规则。`validation_rules` 先检查整个数组，例如限制长度；元素规则再按原始下标和规则声明顺序执行。

```gdscript
var weights_column: GFConfigTableColumn = GFConfigTableColumn.new()
weights_column.field_name = &"weights"
weights_column.value_type = GFConfigTableColumn.ValueType.ARRAY

var count_rule: GFConfigSizeValidationRule = GFConfigSizeValidationRule.new()
count_rule.has_maximum_size = true
count_rule.maximum_size = 8
weights_column.validation_rules.append(count_rule)

var weight_rule: GFConfigRangeValidationRule = GFConfigRangeValidationRule.new()
weight_rule.has_minimum = true
weight_rule.minimum = 0.0
weight_rule.has_maximum = true
weight_rule.maximum = 1.0
weights_column.element_validation_rules.append(weight_rule)
schema.columns.append(weights_column)
```

当 `weights = [0.2, -0.1, 0.9]` 时，范围问题保留 `field = "weights"`，并附带零基 `element_index = 1`、原元素值和 `range_below_minimum`。表、记录和来源位置沿用字段上下文；不会把字段名改成 `weights[1]`，也不虚构单个元素在源文件中的行列位置。

缺失字段和整个数组的 `null` 由列的 `required`、`allow_null` 控制；数组内部的 `null` 则由各规则的 `allow_null` 控制，默认跳过。空数组没有元素调用；未配置元素规则或全部规则禁用时，也不会展开数组或限制其元素内容。

元素校验只处理一维 Array，不转换元素类型。嵌套 Array、Dictionary、Packed 数组、Object、Callable、Signal 和 RID 会产生 `invalid_element_validation_value`，保留原始下标，并跳过该元素的规则。需要跨表引用时，继续使用既有引用声明；递归数据结构或业务关系由项目自己的校验规则处理。

开启 `coerce_values` 时，配置了启用元素规则的数组会在记录深复制前检查外层元素类型，包括字段默认值。出现上述不支持的元素时，该记录直接失败，不进入字段或记录自定义规则，也不进入后续索引及整表规则的输入集合。这样可以直接定位深嵌套或自引用元素，无需递归访问其内容。独立调用 `coerce_record()` 仍只负责转换，不替代 `validate_record()` 或 `validate_table()`。

## 元素工作量预算

Schema 为一次 `validate_record()` 或 `validate_table()` 设置独立预算；整表中的全部记录和字段共享该次预算。

| Schema 字段 | 默认值 | 有效范围 |
| --- | --- | --- |
| `max_elements_per_validation` | 4096 | 1 至 65536 |
| `max_element_rule_checks_per_validation` | 16384 | 1 至 262144 |

每列最多声明 64 条元素规则，禁用规则不计入调用预算。执行前会为当前字段预留完整元素数与启用规则调用数；任一预算不足时报告 `element_validation_budget_exhausted`，该字段的元素规则全部不执行，避免只校验数组前半部分。整值规则仍会执行，调用方必须检查报告是否成功。

这两个预算限制元素规则的展开和调用次数，不限制整次导入、类型转换或自定义规则内部的运行时间。每次规则调用获得独立的公开上下文集合副本，资源路径探测会话仍按本次验证共享。

## 使用边界

字段规则在类型校验通过后执行；记录规则放在 `GFConfigTableSchema.record_validation_rules`，表规则放在 `table_validation_rules`。

校验上下文会写入 `table_name`、`row_key`、`field`、`rule_id`，并在导入器提供来源信息时附带 `source`、`line`、`column`。自定义规则继承 `GFConfigValidationRule`，重写 `_validate_value()`、`_validate_record()` 或 `_validate_table()`，再通过 `_add_issue()` 写入稳定 `kind`；元素规则同样调用 `_validate_value()`，上下文另带 `element_index`。

资源路径规则默认允许 `uid://`。当设置了 `allowed_extensions` 时，规则会先把 UID 解析回实际资源路径，再检查扩展名；无法解析的 UID 会按缺失或扩展名不匹配报告。需要严格限制旧式 `res://` 配置时，可以关闭 `allow_uid_paths`。

`GFConfigTableSchema.max_resource_path_checks_per_validation` 为一次记录或整表校验设置唯一资源路径探测硬预算，默认值为 1024。整值规则和元素规则共享该次校验的路径预算与缓存；相同路径和相同探测策略共享结果。不同校验操作不会复用缓存，因此文件变化不会被长期 stale cache 隐藏。预算耗尽时报告 `resource_path_check_budget_exhausted`，不会继续同步扫描剩余唯一路径。路径探测预算独立于元素数和元素规则调用预算。

本地化 key 规则默认是严格模式：必须提供 `known_keys` 或 `text_map` 作为精确 key catalog；没有显式来源时会报告 `localization_key_source_missing`。如果项目只需要弱检查，可以显式关闭 `require_explicit_key_source`，再决定是否让 `TranslationServer` 参与 fallback。
