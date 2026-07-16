# GFConfigLocalizationKeyValidationRule

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/validation/gf_config_localization_key_validation_rule.gd`
- 模块：`Standard`
- 继承：`GFConfigValidationRule`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

文本 key 校验规则。 用于检查配置字段中的本地化 key 是否存在于显式 key 列表或字典中。 非严格模式可把 Godot TranslationServer 作为弱 fallback，但不能替代显式 key catalog。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`allow_empty`](#member-gfconfiglocalizationkeyvalidationrule-properties-allow_empty) | `var allow_empty: bool = true` |
| 属性 | [`known_keys`](#member-gfconfiglocalizationkeyvalidationrule-properties-known_keys) | `var known_keys: PackedStringArray = PackedStringArray()` |
| 属性 | [`text_map`](#member-gfconfiglocalizationkeyvalidationrule-properties-text_map) | `var text_map: Dictionary = {}` |
| 属性 | [`require_explicit_key_source`](#member-gfconfiglocalizationkeyvalidationrule-properties-require_explicit_key_source) | `var require_explicit_key_source: bool = true` |
| 属性 | [`use_translation_server`](#member-gfconfiglocalizationkeyvalidationrule-properties-use_translation_server) | `var use_translation_server: bool = true` |
| 方法 | [`describe`](#member-gfconfiglocalizationkeyvalidationrule-methods-describe) | `func describe() -> Dictionary:` |
| 方法 | [`_get_default_rule_id`](#member-gfconfiglocalizationkeyvalidationrule-methods-_get_default_rule_id) | `func _get_default_rule_id() -> StringName:` |
| 方法 | [`_validate_value`](#member-gfconfiglocalizationkeyvalidationrule-methods-_validate_value) | `func _validate_value(value: Variant, context: Dictionary, report: Dictionary) -> void:` |

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

<a id="member-gfconfiglocalizationkeyvalidationrule-properties-require_explicit_key_source"></a>

### `require_explicit_key_source`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var require_explicit_key_source: bool = true
```

是否要求提供 known_keys 或 text_map 作为精确 key 来源。

<a id="member-gfconfiglocalizationkeyvalidationrule-properties-use_translation_server"></a>

### `use_translation_server`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var use_translation_server: bool = true
```

是否在非严格模式下尝试通过 TranslationServer 判断 key。

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

<a id="member-gfconfiglocalizationkeyvalidationrule-methods-_get_default_rule_id"></a>

### `_get_default_rule_id`

- API：`protected`

```gdscript
func _get_default_rule_id() -> StringName:
```

返回本地化 key 规则的默认稳定标识。

返回：默认规则标识。

<a id="member-gfconfiglocalizationkeyvalidationrule-methods-_validate_value"></a>

### `_validate_value`

- API：`protected`

```gdscript
func _validate_value(value: Variant, context: Dictionary, report: Dictionary) -> void:
```

校验单个字段值是否存在于配置的文本 key 来源中。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待校验值。 |
| `context` | 校验上下文。 |
| `report` | 当前校验报告。 |

结构：

- `value`: Variant，期望为 String 或 StringName 本地化 key。
- `context`: Dictionary，可包含 table_name、row_key、field、source、line 和 column 字段。
- `report`: GFConfigValidationReport 兼容 Dictionary，会被当前规则修改。
