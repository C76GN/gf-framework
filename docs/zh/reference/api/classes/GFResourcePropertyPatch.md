# GFResourcePropertyPatch

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_resource_property_patch.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`7.0.0`

通用资源属性差异补丁。 用声明式属性列表和覆盖值描述一份 Resource 或 Object 的小范围差异。 它只会写入声明过的属性路径，不规定资源类型、主题语义或项目业务规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`KEY_PROPERTY_PATH`](#member-gfresourcepropertypatch-constants-key_property_path) | `const KEY_PROPERTY_PATH: String = "property_path"` |
| 常量 | [`KEY_TYPE`](#member-gfresourcepropertypatch-constants-key_type) | `const KEY_TYPE: String = "type"` |
| 常量 | [`KEY_HINT`](#member-gfresourcepropertypatch-constants-key_hint) | `const KEY_HINT: String = "hint"` |
| 常量 | [`KEY_HINT_STRING`](#member-gfresourcepropertypatch-constants-key_hint_string) | `const KEY_HINT_STRING: String = "hint_string"` |
| 常量 | [`KEY_GROUP`](#member-gfresourcepropertypatch-constants-key_group) | `const KEY_GROUP: String = "group"` |
| 常量 | [`KEY_DEFAULT_VALUE`](#member-gfresourcepropertypatch-constants-key_default_value) | `const KEY_DEFAULT_VALUE: String = "default_value"` |
| 常量 | [`KEY_ALLOW_NULL`](#member-gfresourcepropertypatch-constants-key_allow_null) | `const KEY_ALLOW_NULL: String = "allow_null"` |
| 属性 | [`definitions`](#member-gfresourcepropertypatch-properties-definitions) | `var definitions: Array = []` |
| 属性 | [`values`](#member-gfresourcepropertypatch-properties-values) | `var values: Dictionary = {}` |
| 属性 | [`metadata`](#member-gfresourcepropertypatch-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`duplicate_base_on_build`](#member-gfresourcepropertypatch-properties-duplicate_base_on_build) | `var duplicate_base_on_build: bool = true` |
| 属性 | [`require_existing_property`](#member-gfresourcepropertypatch-properties-require_existing_property) | `var require_existing_property: bool = true` |
| 属性 | [`copy_values`](#member-gfresourcepropertypatch-properties-copy_values) | `var copy_values: bool = true` |
| 属性 | [`duplicate_resources`](#member-gfresourcepropertypatch-properties-duplicate_resources) | `var duplicate_resources: bool = false` |
| 方法 | [`set_patch_value`](#member-gfresourcepropertypatch-methods-set_patch_value) | `func set_patch_value(property_path: StringName, value: Variant) -> bool:` |
| 方法 | [`has_patch_value`](#member-gfresourcepropertypatch-methods-has_patch_value) | `func has_patch_value(property_path: StringName) -> bool:` |
| 方法 | [`get_patch_value`](#member-gfresourcepropertypatch-methods-get_patch_value) | `func get_patch_value(property_path: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`clear_patch_value`](#member-gfresourcepropertypatch-methods-clear_patch_value) | `func clear_patch_value(property_path: StringName) -> bool:` |
| 方法 | [`has_definition`](#member-gfresourcepropertypatch-methods-has_definition) | `func has_definition(property_path: StringName) -> bool:` |
| 方法 | [`apply`](#member-gfresourcepropertypatch-methods-apply) | `func apply(target: Object, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`build`](#member-gfresourcepropertypatch-methods-build) | `func build(base_resource: Resource, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`collect_from`](#member-gfresourcepropertypatch-methods-collect_from) | `func collect_from(target: Object, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_patch_values`](#member-gfresourcepropertypatch-methods-get_patch_values) | `func get_patch_values() -> Dictionary:` |
| 方法 | [`make_definition`](#member-gfresourcepropertypatch-methods-make_definition) | `static func make_definition( property_path: StringName, property_type: int = TYPE_NIL, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`make_property_list`](#member-gfresourcepropertypatch-methods-make_property_list) | `static func make_property_list( patch_definitions: Array, patch_values: Dictionary = {}, options: Dictionary = {} ) -> Array[Dictionary]:` |
| 方法 | [`collect_values`](#member-gfresourcepropertypatch-methods-collect_values) | `static func collect_values(target: Object, patch_definitions: Array, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply_values`](#member-gfresourcepropertypatch-methods-apply_values) | `static func apply_values( target: Object, patch_definitions: Array, patch_values: Dictionary, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`build_resource`](#member-gfresourcepropertypatch-methods-build_resource) | `static func build_resource( base_resource: Resource, patch_definitions: Array, patch_values: Dictionary, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`apply_patch_chain`](#member-gfresourcepropertypatch-methods-apply_patch_chain) | `static func apply_patch_chain(target: Object, patch_chain: Array, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`build_resource_chain`](#member-gfresourcepropertypatch-methods-build_resource_chain) | `static func build_resource_chain(base_resource: Resource, patch_chain: Array, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfresourcepropertypatch-constants-key_property_path"></a>

### `KEY_PROPERTY_PATH`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KEY_PROPERTY_PATH: String = "property_path"
```

定义字段：属性路径。

<a id="member-gfresourcepropertypatch-constants-key_type"></a>

### `KEY_TYPE`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KEY_TYPE: String = "type"
```

定义字段：Godot Variant 类型。

<a id="member-gfresourcepropertypatch-constants-key_hint"></a>

### `KEY_HINT`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KEY_HINT: String = "hint"
```

定义字段：Inspector hint。

<a id="member-gfresourcepropertypatch-constants-key_hint_string"></a>

### `KEY_HINT_STRING`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KEY_HINT_STRING: String = "hint_string"
```

定义字段：Inspector hint_string。

<a id="member-gfresourcepropertypatch-constants-key_group"></a>

### `KEY_GROUP`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KEY_GROUP: String = "group"
```

定义字段：Inspector 分组名。

<a id="member-gfresourcepropertypatch-constants-key_default_value"></a>

### `KEY_DEFAULT_VALUE`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KEY_DEFAULT_VALUE: String = "default_value"
```

定义字段：属性默认值。

<a id="member-gfresourcepropertypatch-constants-key_allow_null"></a>

### `KEY_ALLOW_NULL`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KEY_ALLOW_NULL: String = "allow_null"
```

定义字段：是否允许补丁值为 null。

## 属性

<a id="member-gfresourcepropertypatch-properties-definitions"></a>

### `definitions`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var definitions: Array = []
```

可被补丁写入的属性定义列表。

结构：

- `definitions`: Array[Dictionary]，每项可由 make_definition() 创建，包含 property_path、type、hint、hint_string、group、default_value 与 allow_null。

<a id="member-gfresourcepropertypatch-properties-values"></a>

### `values`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var values: Dictionary = {}
```

当前启用的覆盖值。键为属性路径，值为要写入目标的 Variant。

结构：

- `values`: Dictionary[StringName, Variant]，只会应用 definitions 声明过的属性路径。

<a id="member-gfresourcepropertypatch-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。GF 不解释该字段。

结构：

- `metadata`: Dictionary[String, Variant]，项目工具或编辑器 UI 自行读取的补充信息。

<a id="member-gfresourcepropertypatch-properties-duplicate_base_on_build"></a>

### `duplicate_base_on_build`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var duplicate_base_on_build: bool = true
```

build() 时是否默认复制 base Resource 后再应用补丁。

<a id="member-gfresourcepropertypatch-properties-require_existing_property"></a>

### `require_existing_property`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var require_existing_property: bool = true
```

应用补丁时是否默认要求目标对象已经声明对应属性。

<a id="member-gfresourcepropertypatch-properties-copy_values"></a>

### `copy_values`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var copy_values: bool = true
```

写入目标前是否默认复制 Array、Dictionary 与 Resource 值。

<a id="member-gfresourcepropertypatch-properties-duplicate_resources"></a>

### `duplicate_resources`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var duplicate_resources: bool = false
```

复制值时是否默认复制 Resource 实例。

## 方法

<a id="member-gfresourcepropertypatch-methods-set_patch_value"></a>

### `set_patch_value`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func set_patch_value(property_path: StringName, value: Variant) -> bool:
```

设置一个补丁值。

参数：

| 名称 | 说明 |
|---|---|
| `property_path` | 已声明的属性路径。 |
| `value` | 要保存的补丁值。 |

返回：设置成功返回 true。

结构：

- `value`: Variant，必须符合对应 definition 的类型与 allow_null 约束。

<a id="member-gfresourcepropertypatch-methods-has_patch_value"></a>

### `has_patch_value`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_patch_value(property_path: StringName) -> bool:
```

检查当前补丁是否包含指定属性值。

参数：

| 名称 | 说明 |
|---|---|
| `property_path` | 属性路径。 |

返回：已设置补丁值时返回 true。

<a id="member-gfresourcepropertypatch-methods-get_patch_value"></a>

### `get_patch_value`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_patch_value(property_path: StringName, default_value: Variant = null) -> Variant:
```

获取一个补丁值。

参数：

| 名称 | 说明 |
|---|---|
| `property_path` | 属性路径。 |
| `default_value` | 未设置时返回的默认值。 |

返回：补丁值副本或默认值。

结构：

- `default_value`: Variant fallback value returned unchanged when no patch value exists.
- `return`: Variant patch value copy or default value.

<a id="member-gfresourcepropertypatch-methods-clear_patch_value"></a>

### `clear_patch_value`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear_patch_value(property_path: StringName) -> bool:
```

移除一个补丁值。

参数：

| 名称 | 说明 |
|---|---|
| `property_path` | 属性路径。 |

返回：实际移除时返回 true。

<a id="member-gfresourcepropertypatch-methods-has_definition"></a>

### `has_definition`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_definition(property_path: StringName) -> bool:
```

检查属性路径是否已被 definitions 声明。

参数：

| 名称 | 说明 |
|---|---|
| `property_path` | 属性路径。 |

返回：已声明时返回 true。

<a id="member-gfresourcepropertypatch-methods-apply"></a>

### `apply`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func apply(target: Object, options: Dictionary = {}) -> Dictionary:
```

应用当前补丁到目标对象。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `options` | 应用选项。 |

返回：应用报告。

结构：

- `options`: Dictionary，支持 require_existing_property、copy_values、duplicate_resources、skip_unchanged。
- `return`: Dictionary，包含 ok、applied_count、failed_count、skipped_count、unchanged_count、applied_paths、skipped_paths 与 errors。

<a id="member-gfresourcepropertypatch-methods-build"></a>

### `build`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func build(base_resource: Resource, options: Dictionary = {}) -> Dictionary:
```

复制或修改 base Resource，并应用当前补丁。

参数：

| 名称 | 说明 |
|---|---|
| `base_resource` | 来源资源。 |
| `options` | 构建选项。 |

返回：构建报告，成功或部分成功时 resource 字段为结果资源。

结构：

- `options`: Dictionary，支持 duplicate_base、require_existing_property、copy_values、duplicate_resources、skip_unchanged。
- `return`: Dictionary，包含 apply_values() 报告字段和 resource。

<a id="member-gfresourcepropertypatch-methods-collect_from"></a>

### `collect_from`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func collect_from(target: Object, options: Dictionary = {}) -> Dictionary:
```

收集目标对象上的当前属性值，替换当前补丁值。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `options` | 收集选项。 |

返回：收集到的补丁值。

结构：

- `options`: Dictionary，支持 require_existing_property、include_null、copy_values、duplicate_resources。
- `return`: Dictionary[StringName, Variant]，以声明属性路径为键的值字典。

<a id="member-gfresourcepropertypatch-methods-get_patch_values"></a>

### `get_patch_values`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_patch_values() -> Dictionary:
```

获取当前补丁值副本。

返回：补丁值字典副本。

结构：

- `return`: Dictionary[StringName, Variant]，当前 patch values 的副本。

<a id="member-gfresourcepropertypatch-methods-make_definition"></a>

### `make_definition`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func make_definition( property_path: StringName, property_type: int = TYPE_NIL, options: Dictionary = {} ) -> Dictionary:
```

创建一个属性定义。

参数：

| 名称 | 说明 |
|---|---|
| `property_path` | 属性路径。 |
| `property_type` | Godot Variant 类型；TYPE_NIL 表示不做类型约束。 |
| `options` | 定义选项。 |

返回：属性定义字典。

结构：

- `options`: Dictionary，支持 hint、hint_string、group、default_value、allow_null。
- `return`: Dictionary resource property patch definition.

<a id="member-gfresourcepropertypatch-methods-make_property_list"></a>

### `make_property_list`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func make_property_list( patch_definitions: Array, patch_values: Dictionary = {}, options: Dictionary = {} ) -> Array[Dictionary]:
```

构建通用 Inspector 属性列表。

参数：

| 名称 | 说明 |
|---|---|
| `patch_definitions` | 属性定义列表。 |
| `patch_values` | 当前启用的覆盖值。 |
| `options` | 属性列表选项。 |

返回：Godot _get_property_list() 可返回的属性列表。

结构：

- `patch_definitions`: Array[Dictionary] created by make_definition() or compatible dictionaries.
- `patch_values`: Dictionary[StringName, Variant] patch values used to mark storage usage.
- `options`: Dictionary，支持 group_prefix、usage。
- `return`: Array[Dictionary] property list entries.

<a id="member-gfresourcepropertypatch-methods-collect_values"></a>

### `collect_values`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func collect_values(target: Object, patch_definitions: Array, options: Dictionary = {}) -> Dictionary:
```

收集目标对象上的属性值。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `patch_definitions` | 属性定义列表。 |
| `options` | 收集选项。 |

返回：以声明属性路径为键的值字典。

结构：

- `patch_definitions`: Array[Dictionary] created by make_definition() or compatible dictionaries.
- `options`: Dictionary，支持 require_existing_property、include_null、copy_values、duplicate_resources。
- `return`: Dictionary[StringName, Variant] collected values.

<a id="member-gfresourcepropertypatch-methods-apply_values"></a>

### `apply_values`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func apply_values( target: Object, patch_definitions: Array, patch_values: Dictionary, options: Dictionary = {} ) -> Dictionary:
```

应用属性值到目标对象。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `patch_definitions` | 属性定义列表。 |
| `patch_values` | 要应用的补丁值。 |
| `options` | 应用选项。 |

返回：应用报告。

结构：

- `patch_definitions`: Array[Dictionary] created by make_definition() or compatible dictionaries.
- `patch_values`: Dictionary[StringName, Variant] patch values.
- `options`: Dictionary，支持 require_existing_property、copy_values、duplicate_resources、skip_unchanged。
- `return`: Dictionary，包含 ok、applied_count、failed_count、skipped_count、unchanged_count、applied_paths、skipped_paths 与 errors。

<a id="member-gfresourcepropertypatch-methods-build_resource"></a>

### `build_resource`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func build_resource( base_resource: Resource, patch_definitions: Array, patch_values: Dictionary, options: Dictionary = {} ) -> Dictionary:
```

复制或修改 base Resource，并应用补丁值。

参数：

| 名称 | 说明 |
|---|---|
| `base_resource` | 来源资源。 |
| `patch_definitions` | 属性定义列表。 |
| `patch_values` | 要应用的补丁值。 |
| `options` | 构建选项。 |

返回：构建报告，成功或部分成功时 resource 字段为结果资源。

结构：

- `patch_definitions`: Array[Dictionary] created by make_definition() or compatible dictionaries.
- `patch_values`: Dictionary[StringName, Variant] patch values.
- `options`: Dictionary，支持 duplicate_base、require_existing_property、copy_values、duplicate_resources、skip_unchanged。
- `return`: Dictionary，包含 apply_values() 报告字段和 resource。

<a id="member-gfresourcepropertypatch-methods-apply_patch_chain"></a>

### `apply_patch_chain`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func apply_patch_chain(target: Object, patch_chain: Array, options: Dictionary = {}) -> Dictionary:
```

按顺序把一组补丁应用到目标对象。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标对象。 |
| `patch_chain` | 补丁链。 |
| `options` | 应用选项。 |

返回：覆盖链应用报告。

结构：

- `patch_chain`: Array[GFResourcePropertyPatch]，按数组顺序应用，越靠后的补丁优先级越高。
- `options`: Dictionary，支持 require_existing_property、copy_values、duplicate_resources、skip_unchanged、include_patch_reports、stop_on_failure 和 metadata。
- `return`: Dictionary，包含 ok、patch_count、计数、路径、errors、patch_reports 和 metadata。

<a id="member-gfresourcepropertypatch-methods-build_resource_chain"></a>

### `build_resource_chain`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func build_resource_chain(base_resource: Resource, patch_chain: Array, options: Dictionary = {}) -> Dictionary:
```

复制或修改 base Resource，并按顺序应用一组补丁。

参数：

| 名称 | 说明 |
|---|---|
| `base_resource` | 来源资源。 |
| `patch_chain` | 补丁链。 |
| `options` | 构建选项。 |

返回：覆盖链构建报告，成功或部分成功时 resource 字段为结果资源。

结构：

- `patch_chain`: Array[GFResourcePropertyPatch]，按数组顺序应用，越靠后的补丁优先级越高。
- `options`: Dictionary，支持 duplicate_base、require_existing_property、copy_values、duplicate_resources、skip_unchanged、include_patch_reports、stop_on_failure 和 metadata。
- `return`: Dictionary，包含 apply_patch_chain() 报告字段和 resource。
