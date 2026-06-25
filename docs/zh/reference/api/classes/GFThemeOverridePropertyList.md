# GFThemeOverridePropertyList

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_theme_override_property_list.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`6.0.0`

Control 主题覆盖属性列表构建器。 帮助自定义 Control 把一组主题覆盖项暴露到 Inspector。它只生成 Godot 属性列表 与 revert 信息，不规定控件外观、主题命名或业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`KEY_NAME`](#member-gfthemeoverridepropertylist-constants-key_name) | `const KEY_NAME: String = "name"` |
| 常量 | [`KEY_DATA_TYPE`](#member-gfthemeoverridepropertylist-constants-key_data_type) | `const KEY_DATA_TYPE: String = "data_type"` |
| 常量 | [`KEY_HINT`](#member-gfthemeoverridepropertylist-constants-key_hint) | `const KEY_HINT: String = "hint"` |
| 常量 | [`KEY_HINT_STRING`](#member-gfthemeoverridepropertylist-constants-key_hint_string) | `const KEY_HINT_STRING: String = "hint_string"` |
| 方法 | [`make_definition`](#member-gfthemeoverridepropertylist-methods-make_definition) | `static func make_definition(override_name: StringName, data_type: int, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_property_list`](#member-gfthemeoverridepropertylist-methods-make_property_list) | `static func make_property_list( control: Control, definitions: Array, options: Dictionary = {} ) -> Array[Dictionary]:` |
| 方法 | [`get_property_path`](#member-gfthemeoverridepropertylist-methods-get_property_path) | `static func get_property_path(definition: Dictionary) -> String:` |
| 方法 | [`has_property_path`](#member-gfthemeoverridepropertylist-methods-has_property_path) | `static func has_property_path(property_path: StringName, definitions: Array) -> bool:` |
| 方法 | [`can_revert`](#member-gfthemeoverridepropertylist-methods-can_revert) | `static func can_revert(property_path: StringName, definitions: Array) -> bool:` |
| 方法 | [`get_revert_value`](#member-gfthemeoverridepropertylist-methods-get_revert_value) | `static func get_revert_value(_property_path: StringName) -> Variant:` |
| 方法 | [`collect_override_values`](#member-gfthemeoverridepropertylist-methods-collect_override_values) | `static func collect_override_values( control: Control, definitions: Array, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`clear_overrides`](#member-gfthemeoverridepropertylist-methods-clear_overrides) | `static func clear_overrides(control: Control, definitions: Array) -> Dictionary:` |
| 方法 | [`make_theme_from_control`](#member-gfthemeoverridepropertylist-methods-make_theme_from_control) | `static func make_theme_from_control( control: Control, definitions: Array, theme_type: StringName = &"", options: Dictionary = {} ) -> Theme:` |
| 方法 | [`make_theme_from_values`](#member-gfthemeoverridepropertylist-methods-make_theme_from_values) | `static func make_theme_from_values( definitions: Array, values: Dictionary, theme_type: StringName ) -> Theme:` |

## 常量

<a id="member-gfthemeoverridepropertylist-constants-key_name"></a>

### `KEY_NAME`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const KEY_NAME: String = "name"
```

定义字段：主题项名称。

<a id="member-gfthemeoverridepropertylist-constants-key_data_type"></a>

### `KEY_DATA_TYPE`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const KEY_DATA_TYPE: String = "data_type"
```

定义字段：Theme.DataType。

<a id="member-gfthemeoverridepropertylist-constants-key_hint"></a>

### `KEY_HINT`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const KEY_HINT: String = "hint"
```

定义字段：可选 hint。

<a id="member-gfthemeoverridepropertylist-constants-key_hint_string"></a>

### `KEY_HINT_STRING`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const KEY_HINT_STRING: String = "hint_string"
```

定义字段：可选 hint_string。

## 方法

<a id="member-gfthemeoverridepropertylist-methods-make_definition"></a>

### `make_definition`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func make_definition(override_name: StringName, data_type: int, options: Dictionary = {}) -> Dictionary:
```

创建主题覆盖定义。

参数：

| 名称 | 说明 |
|---|---|
| `override_name` | 主题项名称。 |
| `data_type` | Theme.DataType 值。 |
| `options` | 可选 hint/hint_string。 |

返回：定义字典。

结构：

- `options`: Dictionary with optional hint and hint_string.
- `return`: Dictionary theme override definition.

<a id="member-gfthemeoverridepropertylist-methods-make_property_list"></a>

### `make_property_list`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func make_property_list( control: Control, definitions: Array, options: Dictionary = {} ) -> Array[Dictionary]:
```

构建 Inspector 属性列表。

参数：

| 名称 | 说明 |
|---|---|
| `control` | 目标 Control；用于判断当前 override 是否需要 storage usage。 |
| `definitions` | 主题覆盖定义列表。 |
| `options` | 可选参数，支持 group_prefix。 |

返回：Godot _get_property_list() 可返回的属性列表。

结构：

- `definitions`: Array[Dictionary] created by make_definition() or compatible dictionaries.
- `options`: Dictionary with optional `group_prefix: String`.
- `return`: Array[Dictionary] property list entries.

<a id="member-gfthemeoverridepropertylist-methods-get_property_path"></a>

### `get_property_path`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func get_property_path(definition: Dictionary) -> String:
```

获取定义对应的 Control 属性路径。

参数：

| 名称 | 说明 |
|---|---|
| `definition` | 主题覆盖定义。 |

返回：形如 theme_override_colors/accent 的属性路径。

结构：

- `definition`: Dictionary theme override definition.

<a id="member-gfthemeoverridepropertylist-methods-has_property_path"></a>

### `has_property_path`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func has_property_path(property_path: StringName, definitions: Array) -> bool:
```

检查属性是否由定义列表声明。

参数：

| 名称 | 说明 |
|---|---|
| `property_path` | Control 属性路径。 |
| `definitions` | 主题覆盖定义列表。 |

返回：存在返回 true。

结构：

- `definitions`: Array[Dictionary] theme override definitions.

<a id="member-gfthemeoverridepropertylist-methods-can_revert"></a>

### `can_revert`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func can_revert(property_path: StringName, definitions: Array) -> bool:
```

判断属性是否可以 revert。

参数：

| 名称 | 说明 |
|---|---|
| `property_path` | Control 属性路径。 |
| `definitions` | 主题覆盖定义列表。 |

返回：由定义声明时返回 true。

结构：

- `definitions`: Array[Dictionary] theme override definitions.

<a id="member-gfthemeoverridepropertylist-methods-get_revert_value"></a>

### `get_revert_value`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func get_revert_value(_property_path: StringName) -> Variant:
```

获取主题覆盖属性的 revert 值。

参数：

| 名称 | 说明 |
|---|---|
| `_property_path` | Control 属性路径。 |

返回：Godot theme override 的默认空值。

结构：

- `return`: null clears the override.

<a id="member-gfthemeoverridepropertylist-methods-collect_override_values"></a>

### `collect_override_values`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func collect_override_values( control: Control, definitions: Array, options: Dictionary = {} ) -> Dictionary:
```

收集控件当前已设置的主题覆盖值。

参数：

| 名称 | 说明 |
|---|---|
| `control` | 目标 Control。 |
| `definitions` | 主题覆盖定义列表。 |
| `options` | 可选参数，支持 include_null、copy_values、duplicate_resources。 |

返回：以属性路径为键的覆盖值字典。

结构：

- `definitions`: Array[Dictionary] created by make_definition() or compatible dictionaries.
- `options`: Dictionary with optional include_null: bool, copy_values: bool, duplicate_resources: bool.
- `return`: Dictionary[String, Variant] mapping theme override property paths to values.

<a id="member-gfthemeoverridepropertylist-methods-clear_overrides"></a>

### `clear_overrides`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func clear_overrides(control: Control, definitions: Array) -> Dictionary:
```

清空控件上由定义列表声明的主题覆盖。

参数：

| 名称 | 说明 |
|---|---|
| `control` | 目标 Control。 |
| `definitions` | 主题覆盖定义列表。 |

返回：清空报告。

结构：

- `definitions`: Array[Dictionary] created by make_definition() or compatible dictionaries.
- `return`: Dictionary { ok: bool, cleared_count: int, skipped_count: int, issues: Array[Dictionary] }.

<a id="member-gfthemeoverridepropertylist-methods-make_theme_from_control"></a>

### `make_theme_from_control`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func make_theme_from_control( control: Control, definitions: Array, theme_type: StringName = &"", options: Dictionary = {} ) -> Theme:
```

从控件当前主题覆盖创建 Theme。

参数：

| 名称 | 说明 |
|---|---|
| `control` | 目标 Control。 |
| `definitions` | 主题覆盖定义列表。 |
| `theme_type` | Theme 类型名；为空时使用 control.get_class()。 |
| `options` | 透传给 collect_override_values()。 |

返回：新建 Theme，包含定义列表中已设置的有效覆盖值。

结构：

- `definitions`: Array[Dictionary] created by make_definition() or compatible dictionaries.
- `options`: Dictionary with optional include_null: bool, copy_values: bool, duplicate_resources: bool.

<a id="member-gfthemeoverridepropertylist-methods-make_theme_from_values"></a>

### `make_theme_from_values`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func make_theme_from_values( definitions: Array, values: Dictionary, theme_type: StringName ) -> Theme:
```

从已收集的主题覆盖值创建 Theme。

参数：

| 名称 | 说明 |
|---|---|
| `definitions` | 主题覆盖定义列表。 |
| `values` | 以属性路径为键的覆盖值字典。 |
| `theme_type` | Theme 类型名。 |

返回：新建 Theme，包含定义列表中已设置的有效覆盖值。

结构：

- `definitions`: Array[Dictionary] created by make_definition() or compatible dictionaries.
- `values`: Dictionary[String, Variant] mapping theme override property paths to values.
