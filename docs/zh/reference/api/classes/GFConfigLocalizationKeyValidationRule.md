# GFConfigLocalizationKeyValidationRule

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/validation/gf_config_localization_key_validation_rule.gd`
- 模块：`Standard`
- 继承：`GFConfigValidationRule`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

文本 key 校验规则。 用于检查配置字段中的本地化 key 是否存在于显式 key 列表、字典或 Godot 翻译表中。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`allow_empty`](#member-gfconfiglocalizationkeyvalidationrule-properties-allow_empty) | `var allow_empty: bool = true` |
| 属性 | [`known_keys`](#member-gfconfiglocalizationkeyvalidationrule-properties-known_keys) | `var known_keys: PackedStringArray = PackedStringArray()` |
| 属性 | [`text_map`](#member-gfconfiglocalizationkeyvalidationrule-properties-text_map) | `var text_map: Dictionary = {}` |
| 属性 | [`use_translation_server`](#member-gfconfiglocalizationkeyvalidationrule-properties-use_translation_server) | `var use_translation_server: bool = true` |
| 方法 | [`describe`](#member-gfconfiglocalizationkeyvalidationrule-methods-describe) | `func describe() -> Dictionary:` |

## 属性

<a id="member-gfconfiglocalizationkeyvalidationrule-properties-allow_empty"></a>

### `allow_empty`

- API：`public`

```gdscript
var allow_empty: bool = true
```

空字符串是否直接视为通过。

<a id="member-gfconfiglocalizationkeyvalidationrule-properties-known_keys"></a>

### `known_keys`

- API：`public`

```gdscript
var known_keys: PackedStringArray = PackedStringArray()
```

显式允许的文本 key。

<a id="member-gfconfiglocalizationkeyvalidationrule-properties-text_map"></a>

### `text_map`

- API：`public`

```gdscript
var text_map: Dictionary = {}
```

可选文本字典。只检查 key 是否存在，不解释 value。

结构：

- `text_map`: Dictionary，将本地化 key 映射到项目自有文本值。

<a id="member-gfconfiglocalizationkeyvalidationrule-properties-use_translation_server"></a>

### `use_translation_server`

- API：`public`

```gdscript
var use_translation_server: bool = true
```

是否尝试通过 TranslationServer 判断 key。

## 方法

<a id="member-gfconfiglocalizationkeyvalidationrule-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出规则摘要。

返回：规则摘要字典。

结构：

- `return`: Dictionary，包含基础规则字段和本地化 key 来源设置。
