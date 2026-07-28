# GFShaderParameterProfile

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/display/gf_shader_parameter_profile.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`4.3.0`

通用 ShaderMaterial 参数集合资源。 用 Resource 保存一组 shader uniform 参数值，便于项目把视觉 profile、天气表现、 选中态或后处理参数声明为可合并、可复制、可插值的数据。它不提供具体 shader、 色彩风格或业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`parameters`](#member-gfshaderparameterprofile-properties-parameters) | `var parameters: Dictionary = {}` |
| 属性 | [`metadata`](#member-gfshaderparameterprofile-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`set_parameter`](#member-gfshaderparameterprofile-methods-set_parameter) | `func set_parameter(parameter_name: StringName, value: Variant) -> GFShaderParameterProfile:` |
| 方法 | [`get_parameter`](#member-gfshaderparameterprofile-methods-get_parameter) | `func get_parameter(parameter_name: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`has_parameter`](#member-gfshaderparameterprofile-methods-has_parameter) | `func has_parameter(parameter_name: StringName) -> bool:` |
| 方法 | [`erase_parameter`](#member-gfshaderparameterprofile-methods-erase_parameter) | `func erase_parameter(parameter_name: StringName) -> bool:` |
| 方法 | [`clear_parameters`](#member-gfshaderparameterprofile-methods-clear_parameters) | `func clear_parameters() -> void:` |
| 方法 | [`get_parameter_names`](#member-gfshaderparameterprofile-methods-get_parameter_names) | `func get_parameter_names() -> Array[StringName]:` |
| 方法 | [`validate_against`](#member-gfshaderparameterprofile-methods-validate_against) | `func validate_against( interface_snapshot: GFShaderInterfaceSnapshot, options: Dictionary = {} ) -> GFValidationReport:` |
| 方法 | [`merge_from`](#member-gfshaderparameterprofile-methods-merge_from) | `func merge_from(source: GFShaderParameterProfile, overwrite: bool = true) -> GFShaderParameterProfile:` |
| 方法 | [`blend_with`](#member-gfshaderparameterprofile-methods-blend_with) | `func blend_with( target_profile: GFShaderParameterProfile, weight: float, options: Dictionary = {} ) -> GFShaderParameterProfile:` |
| 方法 | [`duplicate_profile`](#member-gfshaderparameterprofile-methods-duplicate_profile) | `func duplicate_profile() -> GFShaderParameterProfile:` |
| 方法 | [`to_dict`](#member-gfshaderparameterprofile-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfshaderparameterprofile-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`from_dict`](#member-gfshaderparameterprofile-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFShaderParameterProfile:` |

## 属性

<a id="member-gfshaderparameterprofile-properties-parameters"></a>

### `parameters`

- API：`public`

```gdscript
var parameters: Dictionary = {}
```

Shader 参数字典。键应为 StringName 或 String，值为项目 shader uniform 接受的 Variant。

结构：

- `parameters`: Dictionary[StringName, Variant]，保存 shader uniform 名到参数值的映射。

<a id="member-gfshaderparameterprofile-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary[String, Variant]，项目自定义元数据；框架不会读取或改写其中字段。

## 方法

<a id="member-gfshaderparameterprofile-methods-set_parameter"></a>

### `set_parameter`

- API：`public`

```gdscript
func set_parameter(parameter_name: StringName, value: Variant) -> GFShaderParameterProfile:
```

设置一个 shader 参数值。

参数：

| 名称 | 说明 |
|---|---|
| `parameter_name` | Shader uniform 参数名。 |
| `value` | 要保存的参数值。 |

返回：当前 profile，便于链式配置。

结构：

- `value`: Variant，可被 ShaderMaterial.set_shader_parameter() 接受的参数值。

<a id="member-gfshaderparameterprofile-methods-get_parameter"></a>

### `get_parameter`

- API：`public`

```gdscript
func get_parameter(parameter_name: StringName, default_value: Variant = null) -> Variant:
```

获取一个 shader 参数值。

参数：

| 名称 | 说明 |
|---|---|
| `parameter_name` | Shader uniform 参数名。 |
| `default_value` | 参数不存在时返回的默认值。 |

返回：参数值副本或默认值。

结构：

- `default_value`: Variant fallback value returned unchanged when the parameter is missing.
- `return`: Variant shader parameter value or the supplied default value.

<a id="member-gfshaderparameterprofile-methods-has_parameter"></a>

### `has_parameter`

- API：`public`

```gdscript
func has_parameter(parameter_name: StringName) -> bool:
```

检查 profile 是否包含指定参数。

参数：

| 名称 | 说明 |
|---|---|
| `parameter_name` | Shader uniform 参数名。 |

返回：存在时返回 true。

<a id="member-gfshaderparameterprofile-methods-erase_parameter"></a>

### `erase_parameter`

- API：`public`

```gdscript
func erase_parameter(parameter_name: StringName) -> bool:
```

移除指定 shader 参数。

参数：

| 名称 | 说明 |
|---|---|
| `parameter_name` | Shader uniform 参数名。 |

返回：实际移除参数时返回 true。

<a id="member-gfshaderparameterprofile-methods-clear_parameters"></a>

### `clear_parameters`

- API：`public`

```gdscript
func clear_parameters() -> void:
```

清空所有 shader 参数。

<a id="member-gfshaderparameterprofile-methods-get_parameter_names"></a>

### `get_parameter_names`

- API：`public`
- 首次版本：`4.3.0`

```gdscript
func get_parameter_names() -> Array[StringName]:
```

获取参数名列表。

返回：参数名数组。

结构：

- `return`: Array[StringName]，当前 profile 中可识别的 shader 参数名。

<a id="member-gfshaderparameterprofile-methods-validate_against"></a>

### `validate_against`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate_against( interface_snapshot: GFShaderInterfaceSnapshot, options: Dictionary = {} ) -> GFValidationReport:
```

根据 Shader 接口快照校验当前参数。

参数：

| 名称 | 说明 |
|---|---|
| `interface_snapshot` | 期望接口快照。 |
| `options` | 传给 GFShaderInterfaceSnapshot.validate_parameters() 的选项。 |

返回：标准校验报告。

结构：

- `options`: Dictionary shader parameter validation options.

<a id="member-gfshaderparameterprofile-methods-merge_from"></a>

### `merge_from`

- API：`public`

```gdscript
func merge_from(source: GFShaderParameterProfile, overwrite: bool = true) -> GFShaderParameterProfile:
```

合并另一个 profile。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 来源 profile。 |
| `overwrite` | 为 true 时覆盖当前已有参数和 metadata 字段。 |

返回：当前 profile，便于链式配置。

<a id="member-gfshaderparameterprofile-methods-blend_with"></a>

### `blend_with`

- API：`public`

```gdscript
func blend_with( target_profile: GFShaderParameterProfile, weight: float, options: Dictionary = {} ) -> GFShaderParameterProfile:
```

构建当前 profile 到目标 profile 的插值副本。

参数：

| 名称 | 说明 |
|---|---|
| `target_profile` | 目标 profile。 |
| `weight` | 插值权重，0 返回当前值，1 返回目标值。 |
| `options` | 可选项，支持 include_unmatched。 |

返回：新的插值 profile。

结构：

- `options`: Dictionary，include_unmatched 为 true 时会把只存在于目标 profile 的参数复制到结果中。未在两端同时提供默认值的参数无法平滑过渡。

<a id="member-gfshaderparameterprofile-methods-duplicate_profile"></a>

### `duplicate_profile`

- API：`public`

```gdscript
func duplicate_profile() -> GFShaderParameterProfile:
```

复制 profile。

返回：深拷贝后的 profile。

<a id="member-gfshaderparameterprofile-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转换为 Dictionary。

返回：profile 字典。

结构：

- `return`: Dictionary，包含 parameters 和 metadata 字段。

<a id="member-gfshaderparameterprofile-methods-apply_dict"></a>

### `apply_dict`

- API：`public`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

应用 Dictionary 数据。

参数：

| 名称 | 说明 |
|---|---|
| `data` | profile 字典。 |

结构：

- `data`: Dictionary，可包含 parameters 和 metadata 字段。

<a id="member-gfshaderparameterprofile-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
static func from_dict(data: Dictionary) -> GFShaderParameterProfile:
```

从 Dictionary 创建 profile。

参数：

| 名称 | 说明 |
|---|---|
| `data` | profile 字典。 |

返回：新 profile。

结构：

- `data`: Dictionary，可包含 parameters 和 metadata 字段。
