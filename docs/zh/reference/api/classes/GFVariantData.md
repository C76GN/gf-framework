# GFVariantData

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/variant/gf_variant_data.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用 Variant 数据复制与默认值合并。 提供不依赖 GFArchitecture 的集合复制、Resource 可选复制、差异报告和默认值递归补齐。 JSON 兼容编码由 GFVariantJsonCodec 负责。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`duplicate_variant`](#member-gfvariantdata-methods-duplicate_variant) | `static func duplicate_variant(value: Variant, deep: bool = true, duplicate_resources: bool = false) -> Variant:` |
| 方法 | [`duplicate_collection`](#member-gfvariantdata-methods-duplicate_collection) | `static func duplicate_collection(value: Variant, deep: bool = true) -> Variant:` |
| 方法 | [`to_dictionary`](#member-gfvariantdata-methods-to_dictionary) | `static func to_dictionary(value: Variant, default_value: Dictionary = {}, deep: bool = true) -> Dictionary:` |
| 方法 | [`as_dictionary`](#member-gfvariantdata-methods-as_dictionary) | `static func as_dictionary(value: Variant, default_value: Variant = null) -> Dictionary:` |
| 方法 | [`to_array`](#member-gfvariantdata-methods-to_array) | `static func to_array(value: Variant, default_value: Array = [], deep: bool = true) -> Array:` |
| 方法 | [`as_array`](#member-gfvariantdata-methods-as_array) | `static func as_array(value: Variant, default_value: Variant = null) -> Array:` |
| 方法 | [`to_bool`](#member-gfvariantdata-methods-to_bool) | `static func to_bool(value: Variant, default_value: bool = false) -> bool:` |
| 方法 | [`to_int`](#member-gfvariantdata-methods-to_int) | `static func to_int(value: Variant, default_value: int = 0) -> int:` |
| 方法 | [`is_exact_integer`](#member-gfvariantdata-methods-is_exact_integer) | `static func is_exact_integer(value: Variant) -> bool:` |
| 方法 | [`to_exact_int`](#member-gfvariantdata-methods-to_exact_int) | `static func to_exact_int(value: Variant, default_value: int = 0) -> int:` |
| 方法 | [`to_float`](#member-gfvariantdata-methods-to_float) | `static func to_float(value: Variant, default_value: float = 0.0) -> float:` |
| 方法 | [`to_text`](#member-gfvariantdata-methods-to_text) | `static func to_text(value: Variant, default_value: String = "") -> String:` |
| 方法 | [`to_string_name`](#member-gfvariantdata-methods-to_string_name) | `static func to_string_name(value: Variant, default_value: StringName = &"") -> StringName:` |
| 方法 | [`to_vector2`](#member-gfvariantdata-methods-to_vector2) | `static func to_vector2(value: Variant, default_value: Vector2 = Vector2.ZERO) -> Vector2:` |
| 方法 | [`to_vector3`](#member-gfvariantdata-methods-to_vector3) | `static func to_vector3(value: Variant, default_value: Vector3 = Vector3.ZERO) -> Vector3:` |
| 方法 | [`to_string_array`](#member-gfvariantdata-methods-to_string_array) | `static func to_string_array(value: Variant, default_value: Array[String] = []) -> Array[String]:` |
| 方法 | [`to_string_name_array`](#member-gfvariantdata-methods-to_string_name_array) | `static func to_string_name_array(value: Variant, default_value: Array[StringName] = []) -> Array[StringName]:` |
| 方法 | [`to_int_array`](#member-gfvariantdata-methods-to_int_array) | `static func to_int_array(value: Variant, default_value: Array[int] = []) -> Array[int]:` |
| 方法 | [`duplicate_metadata`](#member-gfvariantdata-methods-duplicate_metadata) | `static func duplicate_metadata(metadata: Dictionary) -> Dictionary:` |
| 方法 | [`values_equal`](#member-gfvariantdata-methods-values_equal) | `static func values_equal(left: Variant, right: Variant, options: Dictionary = {}) -> bool:` |
| 方法 | [`merge_dictionary`](#member-gfvariantdata-methods-merge_dictionary) | `static func merge_dictionary( target: Dictionary, source: Dictionary, overwrite: bool = true, recursive: bool = true ) -> Dictionary:` |
| 方法 | [`merge_metadata`](#member-gfvariantdata-methods-merge_metadata) | `static func merge_metadata( target: Dictionary, source: Dictionary, overwrite: bool = true, recursive: bool = true ) -> Dictionary:` |
| 方法 | [`deep_merge_defaults`](#member-gfvariantdata-methods-deep_merge_defaults) | `static func deep_merge_defaults(base: Dictionary, defaults: Dictionary) -> Dictionary:` |
| 方法 | [`diff_variant`](#member-gfvariantdata-methods-diff_variant) | `static func diff_variant(before: Variant, after: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_option_value`](#member-gfvariantdata-methods-get_option_value) | `static func get_option_value(options: Dictionary, key: Variant, default_value: Variant = null) -> Variant:` |
| 方法 | [`get_option_bool`](#member-gfvariantdata-methods-get_option_bool) | `static func get_option_bool(options: Dictionary, key: Variant, default_value: bool = false) -> bool:` |
| 方法 | [`get_option_int`](#member-gfvariantdata-methods-get_option_int) | `static func get_option_int(options: Dictionary, key: Variant, default_value: int = 0) -> int:` |
| 方法 | [`get_option_float`](#member-gfvariantdata-methods-get_option_float) | `static func get_option_float(options: Dictionary, key: Variant, default_value: float = 0.0) -> float:` |
| 方法 | [`get_option_string`](#member-gfvariantdata-methods-get_option_string) | `static func get_option_string(options: Dictionary, key: Variant, default_value: String = "") -> String:` |
| 方法 | [`get_option_string_name`](#member-gfvariantdata-methods-get_option_string_name) | `static func get_option_string_name(options: Dictionary, key: Variant, default_value: StringName = &"") -> StringName:` |
| 方法 | [`get_option_vector2`](#member-gfvariantdata-methods-get_option_vector2) | `static func get_option_vector2(options: Dictionary, key: Variant, default_value: Vector2 = Vector2.ZERO) -> Vector2:` |
| 方法 | [`get_option_vector3`](#member-gfvariantdata-methods-get_option_vector3) | `static func get_option_vector3(options: Dictionary, key: Variant, default_value: Vector3 = Vector3.ZERO) -> Vector3:` |
| 方法 | [`get_option_dictionary`](#member-gfvariantdata-methods-get_option_dictionary) | `static func get_option_dictionary(options: Dictionary, key: Variant, default_value: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_option_array`](#member-gfvariantdata-methods-get_option_array) | `static func get_option_array(options: Dictionary, key: Variant, default_value: Array = []) -> Array:` |
| 方法 | [`get_option_string_array`](#member-gfvariantdata-methods-get_option_string_array) | `static func get_option_string_array( options: Dictionary, key: Variant, default_value: Array[String] = [] ) -> Array[String]:` |
| 方法 | [`get_option_string_name_array`](#member-gfvariantdata-methods-get_option_string_name_array) | `static func get_option_string_name_array( options: Dictionary, key: Variant, default_value: Array[StringName] = [] ) -> Array[StringName]:` |
| 方法 | [`get_option_int_array`](#member-gfvariantdata-methods-get_option_int_array) | `static func get_option_int_array( options: Dictionary, key: Variant, default_value: Array[int] = [] ) -> Array[int]:` |
| 方法 | [`get_option_packed_string_array`](#member-gfvariantdata-methods-get_option_packed_string_array) | `static func get_option_packed_string_array( options: Dictionary, key: Variant, default_value: PackedStringArray = PackedStringArray() ) -> PackedStringArray:` |

## 方法

<a id="member-gfvariantdata-methods-duplicate_variant"></a>

### `duplicate_variant`

- API：`public`

```gdscript
static func duplicate_variant(value: Variant, deep: bool = true, duplicate_resources: bool = false) -> Variant:
```

深拷贝 Dictionary 或 Array；其他 Variant 原样返回。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待复制的值。 |
| `deep` | 是否深拷贝集合或 Resource。 |
| `duplicate_resources` | 是否复制 Resource；默认为 false 以保留引用语义。 |

返回：复制后的值。

结构：

- `value`: 待复制的 Variant 值。
- `return`: 复制后的 Variant 值。

<a id="member-gfvariantdata-methods-duplicate_collection"></a>

### `duplicate_collection`

- API：`public`

```gdscript
static func duplicate_collection(value: Variant, deep: bool = true) -> Variant:
```

深拷贝集合值；语义同 duplicate_variant()，便于集合字段调用处表达意图。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待复制的值。 |
| `deep` | 是否深拷贝集合。 |

返回：复制后的值。

结构：

- `value`: 待复制的 Variant 集合值。
- `return`: 复制后的 Variant 集合值。

<a id="member-gfvariantdata-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
static func to_dictionary(value: Variant, default_value: Dictionary = {}, deep: bool = true) -> Dictionary:
```

将 Variant 归一为 Dictionary 副本。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待读取的值。 |
| `default_value` | value 不是 Dictionary 时使用的默认值。 |
| `deep` | 是否深拷贝集合。 |

返回：Dictionary 副本。

结构：

- `value`: 期望为 Dictionary 的 Variant 值。
- `default_value`: value 不是 Dictionary 时复制的默认 Dictionary。
- `return`: 复制后的 Dictionary 结果。

<a id="member-gfvariantdata-methods-as_dictionary"></a>

### `as_dictionary`

- API：`public`

```gdscript
static func as_dictionary(value: Variant, default_value: Variant = null) -> Dictionary:
```

将 Variant 收窄为 Dictionary 引用；value 不是 Dictionary 时返回 default_value 引用。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待读取的值。 |
| `default_value` | value 不是 Dictionary 时使用的默认值；不是 Dictionary 时忽略。 |

返回：Dictionary 引用。

结构：

- `value`: 期望为 Dictionary 的 Variant 值。
- `default_value`: 为 Dictionary 时按引用返回的 Variant 兜底值。
- `return`: 收窄后的 Dictionary 结果。

<a id="member-gfvariantdata-methods-to_array"></a>

### `to_array`

- API：`public`

```gdscript
static func to_array(value: Variant, default_value: Array = [], deep: bool = true) -> Array:
```

将 Variant 归一为 Array 副本。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待读取的值。 |
| `default_value` | value 不是 Array 时使用的默认值。 |
| `deep` | 是否深拷贝集合。 |

返回：Array 副本。

结构：

- `value`: 期望为 Array 的 Variant 值。
- `default_value`: value 不是 Array 时复制的默认 Array。
- `return`: 复制后的 Array 结果。

<a id="member-gfvariantdata-methods-as_array"></a>

### `as_array`

- API：`public`

```gdscript
static func as_array(value: Variant, default_value: Variant = null) -> Array:
```

将 Variant 收窄为 Array 引用；value 不是 Array 时返回 default_value 引用。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待读取的值。 |
| `default_value` | value 不是 Array 时使用的默认值；不是 Array 时忽略。 |

返回：Array 引用。

结构：

- `value`: 期望为 Array 的 Variant 值。
- `default_value`: 为 Array 时按引用返回的 Variant 兜底值。
- `return`: 收窄后的 Array 结果。

<a id="member-gfvariantdata-methods-to_bool"></a>

### `to_bool`

- API：`public`

```gdscript
static func to_bool(value: Variant, default_value: bool = false) -> bool:
```

将 Variant 安全归一为 bool。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待读取的值。 |
| `default_value` | 无法安全归一时返回的默认值。 |

返回：bool 值。

结构：

- `value`: 期望可表示 bool 的 Variant 值。

<a id="member-gfvariantdata-methods-to_int"></a>

### `to_int`

- API：`public`

```gdscript
static func to_int(value: Variant, default_value: int = 0) -> int:
```

将 Variant 安全归一为 int。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待读取的值。 |
| `default_value` | 无法安全归一时返回的默认值。 |

返回：int 值。

结构：

- `value`: 期望可表示 int 的 Variant 值。

<a id="member-gfvariantdata-methods-is_exact_integer"></a>

### `is_exact_integer`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
static func is_exact_integer(value: Variant) -> bool:
```

检查 Variant 是否为可无损解释为整数的数值。 接受 int，以及 JSON 解析产生的有限、无小数且位于安全整数范围内的 float。 不接受 bool、字符串、NaN、Infinity 或带小数的 float。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待检查的值。 |

返回：可无损解释为整数时返回 true。

结构：

- `value`: Variant expected to be an int or an exact JSON integer number.

<a id="member-gfvariantdata-methods-to_exact_int"></a>

### `to_exact_int`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
static func to_exact_int(value: Variant, default_value: int = 0) -> int:
```

将精确整数 Number 转为 int。 与宽松 to_int() 不同，该方法不会接受 bool 或文本，也不会截断小数。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待转换的精确整数 Number。 |
| `default_value` | 输入不满足精确整数约束时返回的值。 |

返回：精确整数或 default_value。

结构：

- `value`: Variant accepted by is_exact_integer().

<a id="member-gfvariantdata-methods-to_float"></a>

### `to_float`

- API：`public`

```gdscript
static func to_float(value: Variant, default_value: float = 0.0) -> float:
```

将 Variant 安全归一为 float。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待读取的值。 |
| `default_value` | 无法安全归一时返回的默认值。 |

返回：float 值。

结构：

- `value`: 期望可表示 float 的 Variant 值。

<a id="member-gfvariantdata-methods-to_text"></a>

### `to_text`

- API：`public`

```gdscript
static func to_text(value: Variant, default_value: String = "") -> String:
```

将 Variant 归一为 String。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待读取的值。 |
| `default_value` | value 为 null 时返回的默认值。 |

返回：String 值。

结构：

- `value`: 期望可表示文本的 Variant 值。

<a id="member-gfvariantdata-methods-to_string_name"></a>

### `to_string_name`

- API：`public`

```gdscript
static func to_string_name(value: Variant, default_value: StringName = &"") -> StringName:
```

将 Variant 归一为 StringName。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待读取的值。 |
| `default_value` | value 为 null 时返回的默认值。 |

返回：StringName 值。

结构：

- `value`: 期望可表示 StringName 的 Variant 值。

<a id="member-gfvariantdata-methods-to_vector2"></a>

### `to_vector2`

- API：`public`

```gdscript
static func to_vector2(value: Variant, default_value: Vector2 = Vector2.ZERO) -> Vector2:
```

将 Variant 归一为 Vector2。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待读取的值。 |
| `default_value` | 无法安全归一时返回的默认值。 |

返回：Vector2 值。

结构：

- `value`: 期望可表示 Vector2 的 Variant 值。

<a id="member-gfvariantdata-methods-to_vector3"></a>

### `to_vector3`

- API：`public`

```gdscript
static func to_vector3(value: Variant, default_value: Vector3 = Vector3.ZERO) -> Vector3:
```

将 Variant 归一为 Vector3。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待读取的值。 |
| `default_value` | 无法安全归一时返回的默认值。 |

返回：Vector3 值。

结构：

- `value`: 期望可表示 Vector3 的 Variant 值。

<a id="member-gfvariantdata-methods-to_string_array"></a>

### `to_string_array`

- API：`public`

```gdscript
static func to_string_array(value: Variant, default_value: Array[String] = []) -> Array[String]:
```

将 Variant 归一为 String 数组副本。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待读取的值。 |
| `default_value` | 无法安全归一时返回的默认数组。 |

返回：String 数组副本。

结构：

- `value`: 期望可表示 String 值集合的 Variant。
- `default_value`: value 无法收窄时复制的默认 Array[String]。
- `return`: 收窄后的 Array[String] 结果。

<a id="member-gfvariantdata-methods-to_string_name_array"></a>

### `to_string_name_array`

- API：`public`

```gdscript
static func to_string_name_array(value: Variant, default_value: Array[StringName] = []) -> Array[StringName]:
```

将 Variant 归一为 StringName 数组副本。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待读取的值。 |
| `default_value` | 无法安全归一时返回的默认数组。 |

返回：StringName 数组副本。

结构：

- `value`: 期望可表示 StringName 值集合的 Variant。
- `default_value`: value 无法收窄时复制的默认 Array[StringName]。
- `return`: 收窄后的 Array[StringName] 结果。

<a id="member-gfvariantdata-methods-to_int_array"></a>

### `to_int_array`

- API：`public`

```gdscript
static func to_int_array(value: Variant, default_value: Array[int] = []) -> Array[int]:
```

将 Variant 归一为 int 数组副本。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待读取的值。 |
| `default_value` | 无法安全归一时返回的默认数组。 |

返回：int 数组副本。

结构：

- `value`: 期望可表示 int 值集合的 Variant。
- `default_value`: value 无法收窄时复制的默认 Array[int]。
- `return`: 收窄后的 Array[int] 结果。

<a id="member-gfvariantdata-methods-duplicate_metadata"></a>

### `duplicate_metadata`

- API：`public`

```gdscript
static func duplicate_metadata(metadata: Dictionary) -> Dictionary:
```

复制元数据字典。

参数：

| 名称 | 说明 |
|---|---|
| `metadata` | 待复制的元数据。 |

返回：元数据副本。

结构：

- `metadata`: 调用方元数据 Dictionary。
- `return`: 复制后的元数据 Dictionary。

<a id="member-gfvariantdata-methods-values_equal"></a>

### `values_equal`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func values_equal(left: Variant, right: Variant, options: Dictionary = {}) -> bool:
```

安全比较两个 Variant 值是否等价。 int/int 始终精确比较；int/float 仅在 float 有限、为整数且双向转换安全时等价。 需要容忍两个 float 之间的误差时可传入 numeric_epsilon。

参数：

| 名称 | 说明 |
|---|---|
| `left` | 左值。 |
| `right` | 右值。 |
| `options` | 比较选项。支持 numeric_epsilon 和 match_string_names。 |

返回：两个值按 GF 通用 Variant 语义等价时返回 true。

结构：

- `left`: Variant comparison value.
- `right`: Variant comparison value.
- `options`: Dictionary，可选字段：numeric_epsilon 为 float/float 误差，默认 0；match_string_names 为 true 时 String 与 StringName 按文本比较。

<a id="member-gfvariantdata-methods-merge_dictionary"></a>

### `merge_dictionary`

- API：`public`
- 首次版本：`3.22.0`

```gdscript
static func merge_dictionary( target: Dictionary, source: Dictionary, overwrite: bool = true, recursive: bool = true ) -> Dictionary:
```

将 source 合并到 target。 `String` 与 `StringName` 等价键会复用 target 中已有字段，避免重复键。 合并前会统一预检 source 图；超过默认深度、节点或集合元素预算时会报告错误并保持 target 原样。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 会被原地修改的目标字典。 |
| `source` | 来源字典。 |
| `overwrite` | 为 true 时覆盖已有字段。 |
| `recursive` | 为 true 时递归合并嵌套 Dictionary。 |

返回：已合并的 target 字典；source 超出预算时返回未修改的 target。

结构：

- `target`: 会被原地修改的目标 Dictionary。
- `source`: 会复制到目标中的来源 Dictionary 值。
- `return`: 合并后的目标 Dictionary，或预算拒绝时保持原样的目标 Dictionary。

<a id="member-gfvariantdata-methods-merge_metadata"></a>

### `merge_metadata`

- API：`public`

```gdscript
static func merge_metadata( target: Dictionary, source: Dictionary, overwrite: bool = true, recursive: bool = true ) -> Dictionary:
```

将 source 元数据合并到 target 元数据。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 会被原地修改的目标元数据。 |
| `source` | 来源元数据。 |
| `overwrite` | 为 true 时覆盖已有字段。 |
| `recursive` | 为 true 时递归合并嵌套 Dictionary。 |

返回：已合并的 target 元数据。

结构：

- `target`: 会被原地修改的元数据 Dictionary。
- `source`: 会复制到目标中的元数据 Dictionary。
- `return`: 合并后的元数据 Dictionary。

<a id="member-gfvariantdata-methods-deep_merge_defaults"></a>

### `deep_merge_defaults`

- API：`public`

```gdscript
static func deep_merge_defaults(base: Dictionary, defaults: Dictionary) -> Dictionary:
```

将 defaults 中缺失的字段递归合并到 base。

参数：

| 名称 | 说明 |
|---|---|
| `base` | 会被原地补齐的目标字典。 |
| `defaults` | 默认值字典。 |

返回：已补齐的 base 字典。

结构：

- `base`: 会被原地修改的目标 Dictionary。
- `defaults`: 会合并到 base 中的默认 Dictionary 值。
- `return`: 合并后的 base Dictionary。

<a id="member-gfvariantdata-methods-diff_variant"></a>

### `diff_variant`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
static func diff_variant(before: Variant, after: Variant, options: Dictionary = {}) -> Dictionary:
```

对比两个 Variant 并返回结构化差异报告。 该方法只比较纯 Variant 数据形状，不读取文件、不实例化脚本，也不解释业务字段。 Array/Dictionary 按展开后的数据内容比较，不比较共享引用拓扑；活动引用 pair 重入只记录为 traversal diagnostic。

参数：

| 名称 | 说明 |
|---|---|
| `before` | 变更前的 Variant 值。 |
| `after` | 变更后的 Variant 值。 |
| `options` | 可选项。支持 max_changes、max_diagnostics、copy_values、max_depth、max_nodes 和 max_collection_items；所有资源预算 <=0 表示不限制。 |

返回：差异报告。内容差异与遍历诊断分别存放在 changes 和 diagnostics。

结构：

- `before`: 待比较的 Variant 值。
- `after`: 待比较的 Variant 值。
- `options`: Dictionary，可选字段：max_changes 为最多记录差异数，默认 1024；max_diagnostics 为最多记录遍历诊断数，默认 1024；max_depth、max_nodes 和 max_collection_items 分别限制递归深度、访问节点数和集合元素工作量；所有预算 <=0 表示不限；copy_values 默认为 true。
- `return`: Dictionary；changes 每项包含 kind、path、path_segments、old_value、new_value、old_type、new_type，kind 仅为 added、removed、changed 或 type_changed；diagnostics 每项包含 kind、path、path_segments，循环重入 kind 为 cycle_detected，资源预算耗尽 kind 为 traversal_budget_exceeded 并包含 reason；complete/traversal_truncated 独立描述遍历完整性，changed 不受 diagnostics 或不完整状态影响。

<a id="member-gfvariantdata-methods-get_option_value"></a>

### `get_option_value`

- API：`public`

```gdscript
static func get_option_value(options: Dictionary, key: Variant, default_value: Variant = null) -> Variant:
```

读取 options 字典中的原始值，支持 String 与 StringName 键互查。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项字典。 |
| `key` | 字段名，可传 String 或 StringName。 |
| `default_value` | 缺少字段时返回的默认值。 |

返回：读取到的值或默认值。

结构：

- `options`: 选项载荷 Dictionary。
- `key`: Variant 选项键。
- `default_value`: Variant 默认值。
- `return`: Variant 选项值或默认值。

<a id="member-gfvariantdata-methods-get_option_bool"></a>

### `get_option_bool`

- API：`public`

```gdscript
static func get_option_bool(options: Dictionary, key: Variant, default_value: bool = false) -> bool:
```

读取 bool 选项。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项字典。 |
| `key` | 字段名，可传 String 或 StringName。 |
| `default_value` | 缺少字段时返回的默认值。 |

返回：bool 值。

结构：

- `options`: 选项载荷 Dictionary。
- `key`: Variant 选项键。

<a id="member-gfvariantdata-methods-get_option_int"></a>

### `get_option_int`

- API：`public`

```gdscript
static func get_option_int(options: Dictionary, key: Variant, default_value: int = 0) -> int:
```

读取 int 选项。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项字典。 |
| `key` | 字段名，可传 String 或 StringName。 |
| `default_value` | 缺少字段时返回的默认值。 |

返回：int 值。

结构：

- `options`: 选项载荷 Dictionary。
- `key`: Variant 选项键。

<a id="member-gfvariantdata-methods-get_option_float"></a>

### `get_option_float`

- API：`public`

```gdscript
static func get_option_float(options: Dictionary, key: Variant, default_value: float = 0.0) -> float:
```

读取 float 选项。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项字典。 |
| `key` | 字段名，可传 String 或 StringName。 |
| `default_value` | 缺少字段时返回的默认值。 |

返回：float 值。

结构：

- `options`: 选项载荷 Dictionary。
- `key`: Variant 选项键。

<a id="member-gfvariantdata-methods-get_option_string"></a>

### `get_option_string`

- API：`public`

```gdscript
static func get_option_string(options: Dictionary, key: Variant, default_value: String = "") -> String:
```

读取 String 选项。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项字典。 |
| `key` | 字段名，可传 String 或 StringName。 |
| `default_value` | 缺少字段时返回的默认值。 |

返回：String 值。

结构：

- `options`: 选项载荷 Dictionary。
- `key`: Variant 选项键。

<a id="member-gfvariantdata-methods-get_option_string_name"></a>

### `get_option_string_name`

- API：`public`

```gdscript
static func get_option_string_name(options: Dictionary, key: Variant, default_value: StringName = &"") -> StringName:
```

读取 StringName 选项。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项字典。 |
| `key` | 字段名，可传 String 或 StringName。 |
| `default_value` | 缺少字段时返回的默认值。 |

返回：StringName 值。

结构：

- `options`: 选项载荷 Dictionary。
- `key`: Variant 选项键。

<a id="member-gfvariantdata-methods-get_option_vector2"></a>

### `get_option_vector2`

- API：`public`

```gdscript
static func get_option_vector2(options: Dictionary, key: Variant, default_value: Vector2 = Vector2.ZERO) -> Vector2:
```

读取 Vector2 选项。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项字典。 |
| `key` | 字段名，可传 String 或 StringName。 |
| `default_value` | 缺少字段时返回的默认值。 |

返回：Vector2 值。

结构：

- `options`: 选项载荷 Dictionary。
- `key`: Variant 选项键。

<a id="member-gfvariantdata-methods-get_option_vector3"></a>

### `get_option_vector3`

- API：`public`

```gdscript
static func get_option_vector3(options: Dictionary, key: Variant, default_value: Vector3 = Vector3.ZERO) -> Vector3:
```

读取 Vector3 选项。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项字典。 |
| `key` | 字段名，可传 String 或 StringName。 |
| `default_value` | 缺少字段时返回的默认值。 |

返回：Vector3 值。

结构：

- `options`: 选项载荷 Dictionary。
- `key`: Variant 选项键。

<a id="member-gfvariantdata-methods-get_option_dictionary"></a>

### `get_option_dictionary`

- API：`public`

```gdscript
static func get_option_dictionary(options: Dictionary, key: Variant, default_value: Dictionary = {}) -> Dictionary:
```

读取 Dictionary 选项副本。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项字典。 |
| `key` | 字段名，可传 String 或 StringName。 |
| `default_value` | 缺少字段时返回的默认值。 |

返回：Dictionary 副本。

结构：

- `options`: 选项载荷 Dictionary。
- `key`: Variant 选项键。
- `default_value`: 选项不是 Dictionary 时复制的默认 Dictionary。
- `return`: Dictionary 选项值。

<a id="member-gfvariantdata-methods-get_option_array"></a>

### `get_option_array`

- API：`public`

```gdscript
static func get_option_array(options: Dictionary, key: Variant, default_value: Array = []) -> Array:
```

读取 Array 选项副本。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项字典。 |
| `key` | 字段名，可传 String 或 StringName。 |
| `default_value` | 缺少字段时返回的默认值。 |

返回：Array 副本。

结构：

- `options`: 选项载荷 Dictionary。
- `key`: Variant 选项键。
- `default_value`: 选项不是 Array 时复制的默认 Array。
- `return`: Array 选项值。

<a id="member-gfvariantdata-methods-get_option_string_array"></a>

### `get_option_string_array`

- API：`public`

```gdscript
static func get_option_string_array( options: Dictionary, key: Variant, default_value: Array[String] = [] ) -> Array[String]:
```

读取 String 数组选项副本。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项字典。 |
| `key` | 字段名，可传 String 或 StringName。 |
| `default_value` | 缺少字段时返回的默认数组。 |

返回：String 数组副本。

结构：

- `options`: 选项载荷 Dictionary。
- `key`: Variant 选项键。
- `default_value`: 选项无法收窄时复制的默认 Array[String]。
- `return`: Array[String] 选项值。

<a id="member-gfvariantdata-methods-get_option_string_name_array"></a>

### `get_option_string_name_array`

- API：`public`

```gdscript
static func get_option_string_name_array( options: Dictionary, key: Variant, default_value: Array[StringName] = [] ) -> Array[StringName]:
```

读取 StringName 数组选项副本。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项字典。 |
| `key` | 字段名，可传 String 或 StringName。 |
| `default_value` | 缺少字段时返回的默认数组。 |

返回：StringName 数组副本。

结构：

- `options`: 选项载荷 Dictionary。
- `key`: Variant 选项键。
- `default_value`: 选项无法收窄时复制的默认 Array[StringName]。
- `return`: Array[StringName] 选项值。

<a id="member-gfvariantdata-methods-get_option_int_array"></a>

### `get_option_int_array`

- API：`public`

```gdscript
static func get_option_int_array( options: Dictionary, key: Variant, default_value: Array[int] = [] ) -> Array[int]:
```

读取 int 数组选项副本。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项字典。 |
| `key` | 字段名，可传 String 或 StringName。 |
| `default_value` | 缺少字段时返回的默认数组。 |

返回：int 数组副本。

结构：

- `options`: 选项载荷 Dictionary。
- `key`: Variant 选项键。
- `default_value`: 选项无法收窄时复制的默认 Array[int]。
- `return`: Array[int] 选项值。

<a id="member-gfvariantdata-methods-get_option_packed_string_array"></a>

### `get_option_packed_string_array`

- API：`public`

```gdscript
static func get_option_packed_string_array( options: Dictionary, key: Variant, default_value: PackedStringArray = PackedStringArray() ) -> PackedStringArray:
```

读取 PackedStringArray 选项。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项字典。 |
| `key` | 字段名，可传 String 或 StringName。 |
| `default_value` | 缺少字段时返回的默认值。 |

返回：PackedStringArray 值。

结构：

- `options`: 选项载荷 Dictionary。
- `key`: Variant 选项键。
