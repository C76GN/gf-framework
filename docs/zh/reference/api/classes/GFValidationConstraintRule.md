# GFValidationConstraintRule

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/validation/gf_validation_constraint_rule.gd`
- 模块：`Standard`
- 继承：`GFValidationRule`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`6.0.0`

通用约束校验规则资源。 为 `GFValidationRule` 补齐范围、集合、正则和尺寸这类跨模块常用约束。 规则只检查传入值，不解释字段业务语义；调用方可把它挂到 `GFSchemaField`、 设置定义、导入计划或项目自己的校验套件中。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`ConstraintKind`](#member-gfvalidationconstraintrule-enums-constraintkind) | `enum ConstraintKind` |
| 属性 | [`constraint_kind`](#member-gfvalidationconstraintrule-properties-constraint_kind) | `var constraint_kind: ConstraintKind = ConstraintKind.RANGE` |
| 属性 | [`has_minimum`](#member-gfvalidationconstraintrule-properties-has_minimum) | `var has_minimum: bool = false` |
| 属性 | [`minimum`](#member-gfvalidationconstraintrule-properties-minimum) | `var minimum: float = 0.0` |
| 属性 | [`inclusive_minimum`](#member-gfvalidationconstraintrule-properties-inclusive_minimum) | `var inclusive_minimum: bool = true` |
| 属性 | [`has_maximum`](#member-gfvalidationconstraintrule-properties-has_maximum) | `var has_maximum: bool = false` |
| 属性 | [`maximum`](#member-gfvalidationconstraintrule-properties-maximum) | `var maximum: float = 0.0` |
| 属性 | [`inclusive_maximum`](#member-gfvalidationconstraintrule-properties-inclusive_maximum) | `var inclusive_maximum: bool = true` |
| 属性 | [`allowed_values`](#member-gfvalidationconstraintrule-properties-allowed_values) | `var allowed_values: Array = []` |
| 属性 | [`case_sensitive`](#member-gfvalidationconstraintrule-properties-case_sensitive) | `var case_sensitive: bool = true` |
| 属性 | [`pattern`](#member-gfvalidationconstraintrule-properties-pattern) | `var pattern: String = ""` |
| 属性 | [`require_full_match`](#member-gfvalidationconstraintrule-properties-require_full_match) | `var require_full_match: bool = false` |
| 属性 | [`allow_empty`](#member-gfvalidationconstraintrule-properties-allow_empty) | `var allow_empty: bool = true` |
| 属性 | [`has_minimum_size`](#member-gfvalidationconstraintrule-properties-has_minimum_size) | `var has_minimum_size: bool = false` |
| 属性 | [`minimum_size`](#member-gfvalidationconstraintrule-properties-minimum_size) | `var minimum_size: int = 0` |
| 属性 | [`has_maximum_size`](#member-gfvalidationconstraintrule-properties-has_maximum_size) | `var has_maximum_size: bool = false` |
| 属性 | [`maximum_size`](#member-gfvalidationconstraintrule-properties-maximum_size) | `var maximum_size: int = 0` |
| 方法 | [`configure_range`](#member-gfvalidationconstraintrule-methods-configure_range) | `func configure_range( p_minimum: float, p_maximum: float, options: Dictionary = {} ) -> GFValidationConstraintRule:` |
| 方法 | [`configure_set`](#member-gfvalidationconstraintrule-methods-configure_set) | `func configure_set(p_allowed_values: Array, options: Dictionary = {}) -> GFValidationConstraintRule:` |
| 方法 | [`configure_regex`](#member-gfvalidationconstraintrule-methods-configure_regex) | `func configure_regex(p_pattern: String, options: Dictionary = {}) -> GFValidationConstraintRule:` |
| 方法 | [`configure_size`](#member-gfvalidationconstraintrule-methods-configure_size) | `func configure_size( p_minimum_size: int, p_maximum_size: int, options: Dictionary = {} ) -> GFValidationConstraintRule:` |
| 方法 | [`duplicate_rule`](#member-gfvalidationconstraintrule-methods-duplicate_rule) | `func duplicate_rule() -> GFValidationRule:` |
| 方法 | [`describe`](#member-gfvalidationconstraintrule-methods-describe) | `func describe() -> Dictionary:` |
| 方法 | [`constraint_kind_to_name`](#member-gfvalidationconstraintrule-methods-constraint_kind_to_name) | `static func constraint_kind_to_name(value: ConstraintKind) -> String:` |
| 方法 | [`_validate`](#member-gfvalidationconstraintrule-methods-_validate) | `func _validate(_target: Variant, _report: GFValidationReport, _context: Dictionary) -> Variant:` |

## 枚举

<a id="member-gfvalidationconstraintrule-enums-constraintkind"></a>

### `ConstraintKind`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
enum ConstraintKind {
	## 数值范围。
	RANGE,
	## 允许值集合。
	SET,
	## 字符串正则表达式。
	REGEX,
	## String、Array、Dictionary 或 PackedArray 尺寸。
	SIZE,
}
```

约束类别。

## 属性

<a id="member-gfvalidationconstraintrule-properties-constraint_kind"></a>

### `constraint_kind`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var constraint_kind: ConstraintKind = ConstraintKind.RANGE
```

约束类别。

<a id="member-gfvalidationconstraintrule-properties-has_minimum"></a>

### `has_minimum`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var has_minimum: bool = false
```

是否检查最小数值。

<a id="member-gfvalidationconstraintrule-properties-minimum"></a>

### `minimum`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var minimum: float = 0.0
```

最小数值。

<a id="member-gfvalidationconstraintrule-properties-inclusive_minimum"></a>

### `inclusive_minimum`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var inclusive_minimum: bool = true
```

最小数值是否包含边界。

<a id="member-gfvalidationconstraintrule-properties-has_maximum"></a>

### `has_maximum`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var has_maximum: bool = false
```

是否检查最大数值。

<a id="member-gfvalidationconstraintrule-properties-maximum"></a>

### `maximum`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var maximum: float = 0.0
```

最大数值。

<a id="member-gfvalidationconstraintrule-properties-inclusive_maximum"></a>

### `inclusive_maximum`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var inclusive_maximum: bool = true
```

最大数值是否包含边界。

<a id="member-gfvalidationconstraintrule-properties-allowed_values"></a>

### `allowed_values`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var allowed_values: Array = []
```

允许值集合。

结构：

- `allowed_values`: Array of accepted Variant values.

<a id="member-gfvalidationconstraintrule-properties-case_sensitive"></a>

### `case_sensitive`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var case_sensitive: bool = true
```

字符串集合比较是否区分大小写。

<a id="member-gfvalidationconstraintrule-properties-pattern"></a>

### `pattern`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var pattern: String = ""
```

正则表达式。

<a id="member-gfvalidationconstraintrule-properties-require_full_match"></a>

### `require_full_match`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var require_full_match: bool = false
```

是否要求正则匹配覆盖整个字符串。

<a id="member-gfvalidationconstraintrule-properties-allow_empty"></a>

### `allow_empty`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var allow_empty: bool = true
```

是否允许空字符串跳过正则检查。

<a id="member-gfvalidationconstraintrule-properties-has_minimum_size"></a>

### `has_minimum_size`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var has_minimum_size: bool = false
```

是否检查最小尺寸。

<a id="member-gfvalidationconstraintrule-properties-minimum_size"></a>

### `minimum_size`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var minimum_size: int = 0
```

最小尺寸。

<a id="member-gfvalidationconstraintrule-properties-has_maximum_size"></a>

### `has_maximum_size`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var has_maximum_size: bool = false
```

是否检查最大尺寸。

<a id="member-gfvalidationconstraintrule-properties-maximum_size"></a>

### `maximum_size`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var maximum_size: int = 0
```

最大尺寸。

## 方法

<a id="member-gfvalidationconstraintrule-methods-configure_range"></a>

### `configure_range`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func configure_range( p_minimum: float, p_maximum: float, options: Dictionary = {} ) -> GFValidationConstraintRule:
```

配置数值范围约束。

参数：

| 名称 | 说明 |
|---|---|
| `p_minimum` | 最小值。 |
| `p_maximum` | 最大值。 |
| `options` | 可选字段，支持 rule_id、description、enabled、severity、metadata、has_minimum、has_maximum、inclusive_minimum 和 inclusive_maximum。 |

返回：当前规则。

结构：

- `options`: Dictionary range constraint configuration.

<a id="member-gfvalidationconstraintrule-methods-configure_set"></a>

### `configure_set`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func configure_set(p_allowed_values: Array, options: Dictionary = {}) -> GFValidationConstraintRule:
```

配置允许值集合约束。

参数：

| 名称 | 说明 |
|---|---|
| `p_allowed_values` | 允许值数组。 |
| `options` | 可选字段，支持 rule_id、description、enabled、severity、metadata 和 case_sensitive。 |

返回：当前规则。

结构：

- `p_allowed_values`: Array of accepted Variant values.
- `options`: Dictionary set constraint configuration.

<a id="member-gfvalidationconstraintrule-methods-configure_regex"></a>

### `configure_regex`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func configure_regex(p_pattern: String, options: Dictionary = {}) -> GFValidationConstraintRule:
```

配置字符串正则约束。

参数：

| 名称 | 说明 |
|---|---|
| `p_pattern` | 正则表达式。 |
| `options` | 可选字段，支持 rule_id、description、enabled、severity、metadata、require_full_match 和 allow_empty。 |

返回：当前规则。

结构：

- `options`: Dictionary regex constraint configuration.

<a id="member-gfvalidationconstraintrule-methods-configure_size"></a>

### `configure_size`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func configure_size( p_minimum_size: int, p_maximum_size: int, options: Dictionary = {} ) -> GFValidationConstraintRule:
```

配置尺寸约束。

参数：

| 名称 | 说明 |
|---|---|
| `p_minimum_size` | 最小尺寸。 |
| `p_maximum_size` | 最大尺寸。 |
| `options` | 可选字段，支持 rule_id、description、enabled、severity、metadata、has_minimum_size 和 has_maximum_size。 |

返回：当前规则。

结构：

- `options`: Dictionary size constraint configuration.

<a id="member-gfvalidationconstraintrule-methods-duplicate_rule"></a>

### `duplicate_rule`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func duplicate_rule() -> GFValidationRule:
```

创建当前约束规则的配置副本。

返回：新规则。

<a id="member-gfvalidationconstraintrule-methods-describe"></a>

### `describe`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func describe() -> Dictionary:
```

导出规则摘要。

返回：规则描述字典。

结构：

- `return`: Dictionary validation constraint rule descriptor.

<a id="member-gfvalidationconstraintrule-methods-constraint_kind_to_name"></a>

### `constraint_kind_to_name`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func constraint_kind_to_name(value: ConstraintKind) -> String:
```

将约束类别转换为稳定名称。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 约束类别。 |

返回：类别名称。

<a id="member-gfvalidationconstraintrule-methods-_validate"></a>

### `_validate`

- API：`protected`
- 首次版本：`6.0.0`

```gdscript
func _validate(_target: Variant, _report: GFValidationReport, _context: Dictionary) -> Variant:
```

执行约束校验逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `_target` | 待校验值。 |
| `_report` | 当前规则报告。 |
| `_context` | 调用方上下文。 |

返回：约束校验结果。

结构：

- `_target`: Variant validation target.
- `_context`: Dictionary validation context.
- `return`: Variant validation hook result.
