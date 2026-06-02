# GFCapabilityRecipe

[API Reference](../index.md) / [Capability](../extensions-capability.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/capability/recipes/gf_capability_recipe.gd`
- 模块：`Capability`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

可复用的能力组合资源。 Recipe 用于把一组通用 Capability 条目批量应用到 receiver。它只描述组合结构， 不规定实体类型、玩法规则、UI 或存档字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`recipe_id`](#member-gfcapabilityrecipe-properties-recipe_id) | `var recipe_id: StringName = &""` |
| 属性 | [`display_name`](#member-gfcapabilityrecipe-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`entries`](#member-gfcapabilityrecipe-properties-entries) | `var entries: Array[GFCapabilityRecipeEntry] = []` |
| 属性 | [`groups`](#member-gfcapabilityrecipe-properties-groups) | `var groups: Array[StringName] = []` |
| 属性 | [`metadata`](#member-gfcapabilityrecipe-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_display_name`](#member-gfcapabilityrecipe-methods-get_display_name) | `func get_display_name() -> String:` |
| 方法 | [`describe_recipe`](#member-gfcapabilityrecipe-methods-describe_recipe) | `func describe_recipe() -> Dictionary:` |
| 方法 | [`validate_recipe`](#member-gfcapabilityrecipe-methods-validate_recipe) | `func validate_recipe() -> Dictionary:` |

## 属性

<a id="member-gfcapabilityrecipe-properties-recipe_id"></a>

### `recipe_id`

- API：`public`

```gdscript
var recipe_id: StringName = &""
```

Recipe 稳定标识。为空时可由项目层按资源路径管理。

<a id="member-gfcapabilityrecipe-properties-display_name"></a>

### `display_name`

- API：`public`

```gdscript
var display_name: String = ""
```

Recipe 展示名，仅供编辑器和项目工具显示。

<a id="member-gfcapabilityrecipe-properties-entries"></a>

### `entries`

- API：`public`

```gdscript
var entries: Array[GFCapabilityRecipeEntry] = []
```

能力条目列表。

<a id="member-gfcapabilityrecipe-properties-groups"></a>

### `groups`

- API：`public`

```gdscript
var groups: Array[StringName] = []
```

应用 Recipe 时附加到 receiver 的能力查询分组。

<a id="member-gfcapabilityrecipe-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: 项目自定义元数据 Dictionary；框架保留并复制该字段，但不解释其中键值。

## 方法

<a id="member-gfcapabilityrecipe-methods-get_display_name"></a>

### `get_display_name`

- API：`public`

```gdscript
func get_display_name() -> String:
```

获取展示名。

返回：展示名。

<a id="member-gfcapabilityrecipe-methods-describe_recipe"></a>

### `describe_recipe`

- API：`public`

```gdscript
func describe_recipe() -> Dictionary:
```

描述 Recipe。

返回：Recipe 描述字典。

结构：

- `return`: 包含 recipe_id、display_name、entry_count、entries、groups 和 metadata 字段的 Dictionary；entries 为各条目的 describe_entry() 快照数组。

<a id="member-gfcapabilityrecipe-methods-validate_recipe"></a>

### `validate_recipe`

- API：`public`

```gdscript
func validate_recipe() -> Dictionary:
```

校验 Recipe 结构。

返回：校验报告。

结构：

- `return`: GFValidationReport.to_dict() 生成的 Dictionary，包含 ok、healthy、summary、issues、next_action 和 entry_count 等字段。
