# GFConfigTypeDefinition

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_type_definition.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`unreleased`

配置值的结构化类型声明。 同一资源用于导入规范化、校验和生成描述；每次调用建立有限编译会话， 不缓存调用之间可能改变的资源。结构字段使用 GFConfigTableColumn 的约束。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Kind`](#member-gfconfigtypedefinition-enums-kind) | `enum Kind` |
| 属性 | [`kind`](#member-gfconfigtypedefinition-properties-kind) | `var kind: Kind = Kind.SCALAR` |
| 属性 | [`type_name`](#member-gfconfigtypedefinition-properties-type_name) | `var type_name: StringName = &""` |
| 属性 | [`allow_null`](#member-gfconfigtypedefinition-properties-allow_null) | `var allow_null: bool = false` |
| 属性 | [`scalar_type`](#member-gfconfigtypedefinition-properties-scalar_type) | `var scalar_type: GFConfigTableColumn.ValueType = GFConfigTableColumn.ValueType.STRING` |
| 属性 | [`fields`](#member-gfconfigtypedefinition-properties-fields) | `var fields: Array[GFConfigTableColumn] = []` |
| 属性 | [`base_type`](#member-gfconfigtypedefinition-properties-base_type) | `var base_type: GFConfigTypeDefinition = null` |
| 属性 | [`element_type`](#member-gfconfigtypedefinition-properties-element_type) | `var element_type: GFConfigTypeDefinition = null` |
| 属性 | [`map_key_type`](#member-gfconfigtypedefinition-properties-map_key_type) | `var map_key_type: GFConfigTableColumn.ValueType = GFConfigTableColumn.ValueType.STRING` |
| 属性 | [`map_value_type`](#member-gfconfigtypedefinition-properties-map_value_type) | `var map_value_type: GFConfigTypeDefinition = null` |
| 属性 | [`symbols`](#member-gfconfigtypedefinition-properties-symbols) | `var symbols: Dictionary = {}` |
| 属性 | [`discriminator`](#member-gfconfigtypedefinition-properties-discriminator) | `var discriminator: StringName = &"type"` |
| 属性 | [`variants`](#member-gfconfigtypedefinition-properties-variants) | `var variants: Array[Resource] = []` |
| 方法 | [`validate_definition`](#member-gfconfigtypedefinition-methods-validate_definition) | `func validate_definition(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`compile_definition`](#member-gfconfigtypedefinition-methods-compile_definition) | `func compile_definition(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`try_normalize`](#member-gfconfigtypedefinition-methods-try_normalize) | `func try_normalize(value: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`describe`](#member-gfconfigtypedefinition-methods-describe) | `func describe(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`try_duplicate_definition`](#member-gfconfigtypedefinition-methods-try_duplicate_definition) | `func try_duplicate_definition(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`duplicate_definition`](#member-gfconfigtypedefinition-methods-duplicate_definition) | `func duplicate_definition(options: Dictionary = {}) -> GFConfigTypeDefinition:` |

## 枚举

<a id="member-gfconfigtypedefinition-enums-kind"></a>

### `Kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Kind {
	## 沿用字段标量转换。
	SCALAR,
	## 具有明确字段及可选基类的字典。
	STRUCT,
	## 具有统一元素类型的数组。
	ARRAY,
	## 具有受限键类型及统一值类型的字典。
	MAP,
	## 具有明确符号及整数值的枚举。
	ENUM,
	## 由判别字段选择具名结构分支的字典。
	POLYMORPHIC,
}
```

配置值的可编译形状。

## 属性

<a id="member-gfconfigtypedefinition-properties-kind"></a>

### `kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var kind: Kind = Kind.SCALAR
```

类型形状；只有对应形状的字段可以设置非默认值。

<a id="member-gfconfigtypedefinition-properties-type_name"></a>

### `type_name`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var type_name: StringName = &""
```

供生成器及多态分支使用的稳定名称；多态分支必须非空且唯一。

<a id="member-gfconfigtypedefinition-properties-allow_null"></a>

### `allow_null`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var allow_null: bool = false
```

容器元素或直接类型调用是否允许 null；字段位置由 column.allow_null 决定。

<a id="member-gfconfigtypedefinition-properties-scalar_type"></a>

### `scalar_type`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var scalar_type: GFConfigTableColumn.ValueType = GFConfigTableColumn.ValueType.STRING
```

SCALAR 的标量类型；不接受 ANY、ARRAY 或 DICTIONARY。

<a id="member-gfconfigtypedefinition-properties-fields"></a>

### `fields`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var fields: Array[GFConfigTableColumn] = []
```

STRUCT 自己声明的字段；继承字段在前，禁止覆盖任何基类字段。

<a id="member-gfconfigtypedefinition-properties-base_type"></a>

### `base_type`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var base_type: GFConfigTypeDefinition = null
```

STRUCT 的可选基类；只接受 STRUCT，整个定义图不允许循环。

<a id="member-gfconfigtypedefinition-properties-element_type"></a>

### `element_type`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var element_type: GFConfigTypeDefinition = null
```

ARRAY 的元素类型。

<a id="member-gfconfigtypedefinition-properties-map_key_type"></a>

### `map_key_type`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var map_key_type: GFConfigTableColumn.ValueType = GFConfigTableColumn.ValueType.STRING
```

MAP 的键类型；只允许 STRING、STRING_NAME 和 INT，转换后重复键失败。

<a id="member-gfconfigtypedefinition-properties-map_value_type"></a>

### `map_value_type`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var map_value_type: GFConfigTypeDefinition = null
```

MAP 的值类型。

<a id="member-gfconfigtypedefinition-properties-symbols"></a>

### `symbols`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var symbols: Dictionary = {}
```

ENUM 的具名整数值；符号及整数值均必须唯一。

结构：

- `symbols`: Dictionary，非空 String 或 StringName 符号映射到唯一 int 值。

<a id="member-gfconfigtypedefinition-properties-discriminator"></a>

### `discriminator`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var discriminator: StringName = &"type"
```

POLYMORPHIC 的必需判别字段；不得与任何分支的结构字段重名。

<a id="member-gfconfigtypedefinition-properties-variants"></a>

### `variants`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var variants: Array[Resource] = []
```

POLYMORPHIC 的可选分支；每项必须是具名 GFConfigTypeDefinition STRUCT。 使用 Resource 数组避免默认值数组持有当前脚本自身，正式编译逐项检查类型。

## 方法

<a id="member-gfconfigtypedefinition-methods-validate_definition"></a>

### `validate_definition`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func validate_definition(options: Dictionary = {}) -> Dictionary:
```

校验类型图、字段约束和默认值，不修改声明资源。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 调用期预算与诊断上下文。 |

返回：校验报告，错误保留字段路径。

结构：

- `options`: Dictionary，可包含 work_budget 或 work_limits，以及 source、field、field_path 和 field_segments。
- `return`: Dictionary，包含 ok、issues、error_count、warning_count。

<a id="member-gfconfigtypedefinition-methods-compile_definition"></a>

### `compile_definition`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func compile_definition(options: Dictionary = {}) -> Dictionary:
```

在同一有限会话内编译类型并返回纯数据描述。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 调用期预算与诊断上下文。 |

返回：编译报告；失败时 definition 为空字典且 issues 保留原因。

结构：

- `options`: Dictionary，可包含 work_budget 或 work_limits，以及来源上下文。
- `return`: Dictionary，校验报告附加 definition；成功描述包含 kind、type_name、allow_null 及当前形状的字段，不含 Resource 引用。

<a id="member-gfconfigtypedefinition-methods-try_normalize"></a>

### `try_normalize`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func try_normalize(value: Variant, options: Dictionary = {}) -> Dictionary:
```

规范化并校验一个值，始终返回隔离副本。 任一类型、规则、预算或未知字段失败时 value 为 null，不返回部分成功数据。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 不会被修改的输入值。 |
| `options` | 预算、来源与标量转换选项。 |

返回：校验报告及规范化值。

结构：

- `value`: Variant，符合所声明结构的标量、Array 或 Dictionary；不接受循环集合或对象。
- `options`: Dictionary，可包含 work_budget 或 work_limits、coerce_values（默认 true）及 field_path、field_segments 等来源上下文。
- `return`: Dictionary，包含 ok、value、issues、error_count、warning_count 和 message；失败时 value 为 null。

<a id="member-gfconfigtypedefinition-methods-describe"></a>

### `describe`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func describe(options: Dictionary = {}) -> Dictionary:
```

有界描述声明结构，不执行默认值及业务值规则。 ok 只说明结构可描述，不代替 validate_definition 或 compile_definition 的默认值准入。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 调用期预算与来源上下文。 |

返回：包含 definition 的结构报告；无效结构不会伪装成空的合法定义。

结构：

- `options`: Dictionary，与 compile_definition 的选项相同。
- `return`: Dictionary，与 compile_definition 具有相同报告形状；仅校验声明结构，失败 definition 为空且 ok 为 false。

<a id="member-gfconfigtypedefinition-methods-try_duplicate_definition"></a>

### `try_duplicate_definition`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func try_duplicate_definition(options: Dictionary = {}) -> Dictionary:
```

有界复制原始类型图，保留待校验声明且不执行值规则。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 调用期预算。 |

返回：校验报告与复制后的 definition；失败时为 null。

结构：

- `options`: Dictionary，可包含 work_budget 或 work_limits。
- `return`: Dictionary，包含 ok、issues、error_count、warning_count、definition；definition 为独立 GFConfigTypeDefinition 或 null。

<a id="member-gfconfigtypedefinition-methods-duplicate_definition"></a>

### `duplicate_definition`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_definition(options: Dictionary = {}) -> GFConfigTypeDefinition:
```

复制原始声明；循环或超预算时返回 null，详细原因由 try_duplicate_definition 提供。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 调用期预算。 |

返回：独立类型资源；失败时为 null。

结构：

- `options`: Dictionary，可包含 work_budget 或 work_limits。
