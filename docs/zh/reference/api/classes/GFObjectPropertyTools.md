# GFObjectPropertyTools

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_object_property_tools.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

Godot Object 属性访问辅助。 集中处理属性列表查询、属性路径读写、可写性判断和基础类型校验。 它不负责属性绑定、自动派发、表达式执行或业务字段解释。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_property_infos`](#member-gfobjectpropertytools-methods-get_property_infos) | `static func get_property_infos(object: Object, usage_filter: int = -1) -> Array[Dictionary]:` |
| 方法 | [`get_property_info_map`](#member-gfobjectpropertytools-methods-get_property_info_map) | `static func get_property_info_map(object: Object, usage_filter: int = -1) -> Dictionary:` |
| 方法 | [`get_property_names`](#member-gfobjectpropertytools-methods-get_property_names) | `static func get_property_names(object: Object, usage_filter: int = -1) -> PackedStringArray:` |
| 方法 | [`get_property_info`](#member-gfobjectpropertytools-methods-get_property_info) | `static func get_property_info(object: Object, property_name: StringName) -> Dictionary:` |
| 方法 | [`has_property`](#member-gfobjectpropertytools-methods-has_property) | `static func has_property(object: Object, property_name: StringName) -> bool:` |
| 方法 | [`has_property_path`](#member-gfobjectpropertytools-methods-has_property_path) | `static func has_property_path(object: Object, property_path: NodePath) -> bool:` |
| 方法 | [`is_property_writable`](#member-gfobjectpropertytools-methods-is_property_writable) | `static func is_property_writable(property_info: Dictionary) -> bool:` |
| 方法 | [`can_write_property`](#member-gfobjectpropertytools-methods-can_write_property) | `static func can_write_property(object: Object, property_path: NodePath) -> bool:` |
| 方法 | [`read_property`](#member-gfobjectpropertytools-methods-read_property) | `static func read_property( object: Object, property_path: NodePath, default_value: Variant = null ) -> Variant:` |
| 方法 | [`write_property`](#member-gfobjectpropertytools-methods-write_property) | `static func write_property( object: Object, property_path: NodePath, value: Variant, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`value_matches_property_type`](#member-gfobjectpropertytools-methods-value_matches_property_type) | `static func value_matches_property_type(value: Variant, property_type: int) -> bool:` |
| 方法 | [`coerce_property_value`](#member-gfobjectpropertytools-methods-coerce_property_value) | `static func coerce_property_value(value: Variant, property_type: int) -> Variant:` |
| 方法 | [`get_root_property_name`](#member-gfobjectpropertytools-methods-get_root_property_name) | `static func get_root_property_name(property_path: NodePath) -> StringName:` |

## 方法

<a id="member-gfobjectpropertytools-methods-get_property_infos"></a>

### `get_property_infos`

- API：`public`

```gdscript
static func get_property_infos(object: Object, usage_filter: int = -1) -> Array[Dictionary]:
```

获取对象属性信息列表。

参数：

| 名称 | 说明 |
|---|---|
| `object` | 目标对象。 |
| `usage_filter` | 属性 usage 过滤掩码；小于 0 时不过滤。 |

返回：属性信息字典列表副本。

结构：

- `return`: Array of Godot property info Dictionary values.

<a id="member-gfobjectpropertytools-methods-get_property_info_map"></a>

### `get_property_info_map`

- API：`public`

```gdscript
static func get_property_info_map(object: Object, usage_filter: int = -1) -> Dictionary:
```

获取对象属性信息映射。

参数：

| 名称 | 说明 |
|---|---|
| `object` | 目标对象。 |
| `usage_filter` | 属性 usage 过滤掩码；小于 0 时不过滤。 |

返回：以属性名为键的属性信息字典。

结构：

- `return`: Dictionary[StringName, Dictionary]

<a id="member-gfobjectpropertytools-methods-get_property_names"></a>

### `get_property_names`

- API：`public`

```gdscript
static func get_property_names(object: Object, usage_filter: int = -1) -> PackedStringArray:
```

获取对象属性名列表。

参数：

| 名称 | 说明 |
|---|---|
| `object` | 目标对象。 |
| `usage_filter` | 属性 usage 过滤掩码；小于 0 时不过滤。 |

返回：属性名列表。

<a id="member-gfobjectpropertytools-methods-get_property_info"></a>

### `get_property_info`

- API：`public`

```gdscript
static func get_property_info(object: Object, property_name: StringName) -> Dictionary:
```

获取单个属性信息。

参数：

| 名称 | 说明 |
|---|---|
| `object` | 目标对象。 |
| `property_name` | 属性名。 |

返回：属性信息字典副本；不存在时返回空字典。

结构：

- `return`: Godot property info dictionary.

<a id="member-gfobjectpropertytools-methods-has_property"></a>

### `has_property`

- API：`public`

```gdscript
static func has_property(object: Object, property_name: StringName) -> bool:
```

检查对象是否声明了指定属性。

参数：

| 名称 | 说明 |
|---|---|
| `object` | 目标对象。 |
| `property_name` | 属性名。 |

返回：属性存在时返回 true。

<a id="member-gfobjectpropertytools-methods-has_property_path"></a>

### `has_property_path`

- API：`public`

```gdscript
static func has_property_path(object: Object, property_path: NodePath) -> bool:
```

检查对象是否声明了属性路径的根属性。

参数：

| 名称 | 说明 |
|---|---|
| `object` | 目标对象。 |
| `property_path` | 属性路径。 |

返回：根属性存在时返回 true。

<a id="member-gfobjectpropertytools-methods-is_property_writable"></a>

### `is_property_writable`

- API：`public`

```gdscript
static func is_property_writable(property_info: Dictionary) -> bool:
```

判断属性信息是否可写。

参数：

| 名称 | 说明 |
|---|---|
| `property_info` | Godot 属性信息字典。 |

返回：未标记为只读时返回 true。

结构：

- `property_info`: Godot property info dictionary.

<a id="member-gfobjectpropertytools-methods-can_write_property"></a>

### `can_write_property`

- API：`public`

```gdscript
static func can_write_property(object: Object, property_path: NodePath) -> bool:
```

检查对象属性路径是否可写。

参数：

| 名称 | 说明 |
|---|---|
| `object` | 目标对象。 |
| `property_path` | 属性路径。 |

返回：根属性存在且未标记为只读时返回 true。

<a id="member-gfobjectpropertytools-methods-read_property"></a>

### `read_property`

- API：`public`

```gdscript
static func read_property( object: Object, property_path: NodePath, default_value: Variant = null ) -> Variant:
```

读取对象属性路径。

参数：

| 名称 | 说明 |
|---|---|
| `object` | 目标对象。 |
| `property_path` | 属性路径。 |
| `default_value` | 对象、路径或根属性无效时返回的默认值。 |

返回：属性值或默认值。

结构：

- `default_value`: Variant fallback returned unchanged when the property cannot be read.
- `return`: Variant property value or the supplied default value.

<a id="member-gfobjectpropertytools-methods-write_property"></a>

### `write_property`

- API：`public`

```gdscript
static func write_property( object: Object, property_path: NodePath, value: Variant, options: Dictionary = {} ) -> Dictionary:
```

写入对象属性路径。

参数：

| 名称 | 说明 |
|---|---|
| `object` | 目标对象。 |
| `property_path` | 属性路径。 |
| `value` | 请求写入的值。 |
| `options` | 可选项，支持 check_writable、check_type、coerce_value。 |

返回：写入结果字典，包含 ok、error、property_name、old_value 与 new_value。

结构：

- `value`: Variant value requested for assignment.
- `options`: Dictionary with optional bool keys check_writable, check_type, and coerce_value.
- `return`: Dictionary { ok: bool, error: String, property_name: StringName, old_value: Variant, new_value: Variant }.

<a id="member-gfobjectpropertytools-methods-value_matches_property_type"></a>

### `value_matches_property_type`

- API：`public`

```gdscript
static func value_matches_property_type(value: Variant, property_type: int) -> bool:
```

检查值是否可写入指定 Variant 类型。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 输入值。 |
| `property_type` | Variant.Type 常量。 |

返回：类型兼容时返回 true。

结构：

- `value`: Variant value to compare against the requested Variant.Type.

<a id="member-gfobjectpropertytools-methods-coerce_property_value"></a>

### `coerce_property_value`

- API：`public`

```gdscript
static func coerce_property_value(value: Variant, property_type: int) -> Variant:
```

将值转换为指定 Variant 类型的基础兼容形式。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 输入值。 |
| `property_type` | Variant.Type 常量。 |

返回：转换后的值；不支持转换时返回原值。

结构：

- `value`: Variant value to coerce.
- `return`: Variant coerced value or original value.

<a id="member-gfobjectpropertytools-methods-get_root_property_name"></a>

### `get_root_property_name`

- API：`public`

```gdscript
static func get_root_property_name(property_path: NodePath) -> StringName:
```

获取属性路径的根属性名。

参数：

| 名称 | 说明 |
|---|---|
| `property_path` | 属性路径。 |

返回：根属性名；无效路径返回空 StringName。
