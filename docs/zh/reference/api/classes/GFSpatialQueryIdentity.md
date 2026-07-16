# GFSpatialQueryIdentity

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_spatial_query_identity.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`8.0.0`

空间查询实体身份值对象。 将 Object、StringName、String 与 int 统一成稳定 key。Object 使用 weakref 保存，避免空间索引因为查询身份持有场景对象生命周期；值类型会复制保存。 Array、Dictionary 等可变复合值不会被接受为稳定空间查询身份。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`KIND_OBJECT`](#member-gfspatialqueryidentity-constants-kind_object) | `const KIND_OBJECT: StringName = &"object"` |
| 常量 | [`KIND_STRING_NAME`](#member-gfspatialqueryidentity-constants-kind_string_name) | `const KIND_STRING_NAME: StringName = &"string_name"` |
| 常量 | [`KIND_STRING`](#member-gfspatialqueryidentity-constants-kind_string) | `const KIND_STRING: StringName = &"string"` |
| 常量 | [`KIND_INT`](#member-gfspatialqueryidentity-constants-kind_int) | `const KIND_INT: StringName = &"int"` |
| 属性 | [`key`](#member-gfspatialqueryidentity-properties-key) | `var key: String = ""` |
| 属性 | [`kind`](#member-gfspatialqueryidentity-properties-kind) | `var kind: StringName = &""` |
| 属性 | [`entity_id`](#member-gfspatialqueryidentity-properties-entity_id) | `var entity_id: int = 0` |
| 属性 | [`object_instance_id`](#member-gfspatialqueryidentity-properties-object_instance_id) | `var object_instance_id: int = 0` |
| 属性 | [`string_value`](#member-gfspatialqueryidentity-properties-string_value) | `var string_value: String = ""` |
| 方法 | [`from_value`](#member-gfspatialqueryidentity-methods-from_value) | `static func from_value(entity: Variant) -> GFSpatialQueryIdentity:` |
| 方法 | [`make_key`](#member-gfspatialqueryidentity-methods-make_key) | `static func make_key(entity: Variant) -> String:` |
| 方法 | [`supports_value`](#member-gfspatialqueryidentity-methods-supports_value) | `static func supports_value(entity: Variant) -> bool:` |
| 方法 | [`sort_keys`](#member-gfspatialqueryidentity-methods-sort_keys) | `static func sort_keys(left_key: String, right_key: String) -> bool:` |
| 方法 | [`get_key_kind`](#member-gfspatialqueryidentity-methods-get_key_kind) | `static func get_key_kind(identity_key: String) -> String:` |
| 方法 | [`get_int_key_value`](#member-gfspatialqueryidentity-methods-get_int_key_value) | `static func get_int_key_value(identity_key: String) -> int:` |
| 方法 | [`is_valid`](#member-gfspatialqueryidentity-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`get_value`](#member-gfspatialqueryidentity-methods-get_value) | `func get_value() -> Variant:` |
| 方法 | [`get_object`](#member-gfspatialqueryidentity-methods-get_object) | `func get_object() -> Object:` |
| 方法 | [`to_dictionary`](#member-gfspatialqueryidentity-methods-to_dictionary) | `func to_dictionary(include_value: bool = false) -> Dictionary:` |

## 常量

<a id="member-gfspatialqueryidentity-constants-kind_object"></a>

### `KIND_OBJECT`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KIND_OBJECT: StringName = &"object"
```

Object 身份类型。

<a id="member-gfspatialqueryidentity-constants-kind_string_name"></a>

### `KIND_STRING_NAME`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KIND_STRING_NAME: StringName = &"string_name"
```

StringName 身份类型。

<a id="member-gfspatialqueryidentity-constants-kind_string"></a>

### `KIND_STRING`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KIND_STRING: StringName = &"string"
```

String 身份类型。

<a id="member-gfspatialqueryidentity-constants-kind_int"></a>

### `KIND_INT`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const KIND_INT: StringName = &"int"
```

int 身份类型。

## 属性

<a id="member-gfspatialqueryidentity-properties-key"></a>

### `key`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var key: String = ""
```

稳定查询 key，格式为 `kind:value`。

<a id="member-gfspatialqueryidentity-properties-kind"></a>

### `kind`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var kind: StringName = &""
```

身份类型。

<a id="member-gfspatialqueryidentity-properties-entity_id"></a>

### `entity_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var entity_id: int = 0
```

int 身份值；非 int 身份时为 0。

<a id="member-gfspatialqueryidentity-properties-object_instance_id"></a>

### `object_instance_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var object_instance_id: int = 0
```

Object 实例 ID；非 Object 身份时为 0。

<a id="member-gfspatialqueryidentity-properties-string_value"></a>

### `string_value`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var string_value: String = ""
```

String 或 StringName 身份文本；其他身份时为空字符串。

## 方法

<a id="member-gfspatialqueryidentity-methods-from_value"></a>

### `from_value`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_value(entity: Variant) -> GFSpatialQueryIdentity:
```

从实体值创建空间查询身份。

参数：

| 名称 | 说明 |
|---|---|
| `entity` | Object、StringName、String 或 int 实体身份。 |

返回：空间查询身份；不支持的实体值会返回空 key 身份。

结构：

- `entity`: Object, StringName, String, or int identity.

<a id="member-gfspatialqueryidentity-methods-make_key"></a>

### `make_key`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func make_key(entity: Variant) -> String:
```

直接获取实体值对应的稳定 key。

参数：

| 名称 | 说明 |
|---|---|
| `entity` | Object、StringName、String 或 int 实体身份。 |

返回：支持的实体值返回稳定 key；不支持时返回空字符串。

结构：

- `entity`: Object, StringName, String, or int identity.

<a id="member-gfspatialqueryidentity-methods-supports_value"></a>

### `supports_value`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func supports_value(entity: Variant) -> bool:
```

判断实体值是否可作为稳定空间查询身份。

参数：

| 名称 | 说明 |
|---|---|
| `entity` | 待检测实体身份。 |

返回：支持时返回 true。

结构：

- `entity`: Object, StringName, String, or int identity candidate.

<a id="member-gfspatialqueryidentity-methods-sort_keys"></a>

### `sort_keys`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func sort_keys(left_key: String, right_key: String) -> bool:
```

按空间身份 key 稳定排序。

参数：

| 名称 | 说明 |
|---|---|
| `left_key` | 左侧 key。 |
| `right_key` | 右侧 key。 |

返回：left_key 应排在 right_key 前方时返回 true。

<a id="member-gfspatialqueryidentity-methods-get_key_kind"></a>

### `get_key_kind`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_key_kind(identity_key: String) -> String:
```

从稳定 key 中取出类型前缀。

参数：

| 名称 | 说明 |
|---|---|
| `identity_key` | 稳定空间身份 key。 |

返回：key 类型；格式无效时返回空字符串。

<a id="member-gfspatialqueryidentity-methods-get_int_key_value"></a>

### `get_int_key_value`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_int_key_value(identity_key: String) -> int:
```

从 int 类型稳定 key 中取出数值。

参数：

| 名称 | 说明 |
|---|---|
| `identity_key` | 稳定空间身份 key。 |

返回：int key 的数值；非 int key 返回 0。

<a id="member-gfspatialqueryidentity-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_valid() -> bool:
```

当前身份是否有效。

返回：key 非空且 Object 身份未释放时返回 true。

<a id="member-gfspatialqueryidentity-methods-get_value"></a>

### `get_value`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_value() -> Variant:
```

取回原始实体值。

返回：Object 身份返回 live Object；值身份返回保存的值；无效身份返回 null。

结构：

- `return`: Object, StringName, String, int, or null entity value.

<a id="member-gfspatialqueryidentity-methods-get_object"></a>

### `get_object`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_object() -> Object:
```

取回 Object 身份引用。

返回：Object 身份未释放时返回 Object；否则返回 null。

<a id="member-gfspatialqueryidentity-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dictionary(include_value: bool = false) -> Dictionary:
```

转换为可序列化快照。

参数：

| 名称 | 说明 |
|---|---|
| `include_value` | 为 true 时为非 Object 身份附带原始值。 |

返回：身份快照。

结构：

- `return`: Dictionary with key, kind, entity_id, object_instance_id, string_value, valid, and optional value.
