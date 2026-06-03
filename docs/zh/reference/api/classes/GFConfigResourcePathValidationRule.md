# GFConfigResourcePathValidationRule

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/validation/gf_config_resource_path_validation_rule.gd`
- 模块：`Standard`
- 继承：`GFConfigValidationRule`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

Godot 资源路径校验规则。 用于检查配置字段中的 `res://` 路径是否存在，并可按扩展名限制资源类型。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`allow_empty`](#member-gfconfigresourcepathvalidationrule-properties-allow_empty) | `var allow_empty: bool = true` |
| 属性 | [`require_resource_prefix`](#member-gfconfigresourcepathvalidationrule-properties-require_resource_prefix) | `var require_resource_prefix: bool = true` |
| 属性 | [`allowed_extensions`](#member-gfconfigresourcepathvalidationrule-properties-allowed_extensions) | `var allowed_extensions: PackedStringArray = PackedStringArray()` |
| 属性 | [`use_resource_loader`](#member-gfconfigresourcepathvalidationrule-properties-use_resource_loader) | `var use_resource_loader: bool = true` |
| 属性 | [`use_file_access_fallback`](#member-gfconfigresourcepathvalidationrule-properties-use_file_access_fallback) | `var use_file_access_fallback: bool = true` |
| 方法 | [`describe`](#member-gfconfigresourcepathvalidationrule-methods-describe) | `func describe() -> Dictionary:` |
| 方法 | [`_get_default_rule_id`](#member-gfconfigresourcepathvalidationrule-methods-_get_default_rule_id) | `func _get_default_rule_id() -> StringName:` |
| 方法 | [`_validate_value`](#member-gfconfigresourcepathvalidationrule-methods-_validate_value) | `func _validate_value(value: Variant, context: Dictionary, report: Dictionary) -> void:` |

## 属性

<a id="member-gfconfigresourcepathvalidationrule-properties-allow_empty"></a>

### `allow_empty`

- API：`public`

```gdscript
var allow_empty: bool = true
```

空字符串是否直接视为通过。

<a id="member-gfconfigresourcepathvalidationrule-properties-require_resource_prefix"></a>

### `require_resource_prefix`

- API：`public`

```gdscript
var require_resource_prefix: bool = true
```

是否要求路径以 res:// 开头。

<a id="member-gfconfigresourcepathvalidationrule-properties-allowed_extensions"></a>

### `allowed_extensions`

- API：`public`

```gdscript
var allowed_extensions: PackedStringArray = PackedStringArray()
```

允许的扩展名。为空时不限制扩展名，可写 png 或 .png。

<a id="member-gfconfigresourcepathvalidationrule-properties-use_resource_loader"></a>

### `use_resource_loader`

- API：`public`

```gdscript
var use_resource_loader: bool = true
```

是否使用 ResourceLoader.exists() 检查导入资源。

<a id="member-gfconfigresourcepathvalidationrule-properties-use_file_access_fallback"></a>

### `use_file_access_fallback`

- API：`public`

```gdscript
var use_file_access_fallback: bool = true
```

ResourceLoader 检查失败时是否再用 FileAccess.file_exists() 检查原始文件。

## 方法

<a id="member-gfconfigresourcepathvalidationrule-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出规则摘要。

返回：规则摘要字典。

结构：

- `return`: Dictionary，包含基础规则字段和资源路径校验设置。

<a id="member-gfconfigresourcepathvalidationrule-methods-_get_default_rule_id"></a>

### `_get_default_rule_id`

- API：`protected`

```gdscript
func _get_default_rule_id() -> StringName:
```

返回资源路径规则的默认稳定标识。

返回：默认规则标识。

<a id="member-gfconfigresourcepathvalidationrule-methods-_validate_value"></a>

### `_validate_value`

- API：`protected`

```gdscript
func _validate_value(value: Variant, context: Dictionary, report: Dictionary) -> void:
```

校验单个字段值是否是存在且扩展名允许的资源路径。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待校验值。 |
| `context` | 校验上下文。 |
| `report` | 当前校验报告。 |

结构：

- `value`: Variant，期望为 String 或 StringName 资源路径。
- `context`: Dictionary，可包含 table_name、row_key、field、source、line 和 column 字段。
- `report`: GFConfigValidationReport 兼容 Dictionary，会被当前规则修改。
