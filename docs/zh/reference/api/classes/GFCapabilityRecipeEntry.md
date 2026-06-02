# GFCapabilityRecipeEntry

[API Reference](../index.md) / [Capability](../extensions-capability.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/capability/recipes/gf_capability_recipe_entry.gd`
- 模块：`Capability`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

能力组合资源中的单个能力条目。 条目只描述能力提供方式、注册类型和默认启停状态，不解释项目业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`capability_type`](#member-gfcapabilityrecipeentry-properties-capability_type) | `var capability_type: Script = null` |
| 属性 | [`scene`](#member-gfcapabilityrecipeentry-properties-scene) | `var scene: PackedScene = null` |
| 属性 | [`active`](#member-gfcapabilityrecipeentry-properties-active) | `var active: bool = true` |
| 属性 | [`metadata`](#member-gfcapabilityrecipeentry-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`is_valid_entry`](#member-gfcapabilityrecipeentry-methods-is_valid_entry) | `func is_valid_entry() -> bool:` |
| 方法 | [`describe_entry`](#member-gfcapabilityrecipeentry-methods-describe_entry) | `func describe_entry() -> Dictionary:` |

## 属性

<a id="member-gfcapabilityrecipeentry-properties-capability_type"></a>

### `capability_type`

- API：`public`

```gdscript
var capability_type: Script = null
```

能力注册类型。为空且 scene 不为空时，会使用实例脚本类型。

<a id="member-gfcapabilityrecipeentry-properties-scene"></a>

### `scene`

- API：`public`

```gdscript
var scene: PackedScene = null
```

可选场景能力。为空时通过 capability_type.new() 创建纯对象能力。

<a id="member-gfcapabilityrecipeentry-properties-active"></a>

### `active`

- API：`public`

```gdscript
var active: bool = true
```

应用 Recipe 后是否启用该能力。

<a id="member-gfcapabilityrecipeentry-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: 项目自定义元数据 Dictionary；框架保留并复制该字段，但不解释其中键值。

## 方法

<a id="member-gfcapabilityrecipeentry-methods-is_valid_entry"></a>

### `is_valid_entry`

- API：`public`

```gdscript
func is_valid_entry() -> bool:
```

检查条目是否至少提供了一种能力创建方式。

返回：有效返回 true。

<a id="member-gfcapabilityrecipeentry-methods-describe_entry"></a>

### `describe_entry`

- API：`public`

```gdscript
func describe_entry() -> Dictionary:
```

描述条目。

返回：条目描述字典。

结构：

- `return`: 包含 capability_type、scene_path、active 和 metadata 字段的 Dictionary。
