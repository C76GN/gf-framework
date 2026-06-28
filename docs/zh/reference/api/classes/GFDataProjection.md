# GFDataProjection

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/variant/gf_data_projection.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

显式安全数据投影辅助。 用于把 Dictionary、Object 或 Resource 的少量字段转换成纯 Variant 数据模型， 供生成器、编辑器工具、诊断面板或文本上下文使用。对象投影必须提供字段名单； 不会默认暴露宿主对象的全部属性。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`project_dictionary`](#member-gfdataprojection-methods-project_dictionary) | `static func project_dictionary(values: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`project_object`](#member-gfdataprojection-methods-project_object) | `static func project_object( object_ref: Object, fields: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`project_value`](#member-gfdataprojection-methods-project_value) | `static func project_value(value: Variant, options: Dictionary = {}) -> Variant:` |
| 方法 | [`project_with_report`](#member-gfdataprojection-methods-project_with_report) | `static func project_with_report(source: Variant, options: Dictionary = {}) -> Dictionary:` |

## 方法

<a id="member-gfdataprojection-methods-project_dictionary"></a>

### `project_dictionary`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func project_dictionary(values: Dictionary, options: Dictionary = {}) -> Dictionary:
```

投影 Dictionary 为安全数据副本。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 输入字典。 |
| `options` | 可选配置，支持 allowed_fields、rename_fields、schema、max_depth、unsupported、include_null 和 defaults。 |

返回：投影后的字典。

结构：

- `values`: Dictionary，来源数据。
- `options`: Dictionary，包含投影配置。
- `return`: Dictionary，投影后的纯数据。

<a id="member-gfdataprojection-methods-project_object"></a>

### `project_object`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func project_object( object_ref: Object, fields: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> Dictionary:
```

投影 Object 或 Resource 的显式字段。

参数：

| 名称 | 说明 |
|---|---|
| `object_ref` | 输入对象。 |
| `fields` | 要读取的字段名单；为空时不暴露任何字段。 |
| `options` | 可选配置，支持 rename_fields、max_depth、unsupported、include_null 和 defaults。 |

返回：投影后的字典。

结构：

- `fields`: PackedStringArray，显式允许读取的属性名。
- `options`: Dictionary，包含投影配置。
- `return`: Dictionary，投影后的纯数据。

<a id="member-gfdataprojection-methods-project_value"></a>

### `project_value`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func project_value(value: Variant, options: Dictionary = {}) -> Variant:
```

投影任意 Variant 值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 输入值。 |
| `options` | 可选配置，支持 max_depth、unsupported 和 include_null。 |

返回：投影后的值；无法投影且 unsupported 为 drop 时返回 null。

结构：

- `value`: Variant，来源值。
- `options`: Dictionary，包含投影配置。
- `return`: Variant，投影后的纯数据。

<a id="member-gfdataprojection-methods-project_with_report"></a>

### `project_with_report`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func project_with_report(source: Variant, options: Dictionary = {}) -> Dictionary:
```

投影数据并返回带报告的结果字典。

参数：

| 名称 | 说明 |
|---|---|
| `source` | Dictionary、Object 或 Resource。 |
| `options` | 可选配置。Object 来源必须提供 fields。 |

返回：结果字典，包含 ok、data 和 report。

结构：

- `source`: Variant，支持 Dictionary 或 Object。
- `options`: Dictionary，包含投影配置。
- `return`: Dictionary，包含投影结果和校验报告。
