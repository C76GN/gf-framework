# GFShaderParameterUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/display/gf_shader_parameter_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`4.3.0`

通用 ShaderMaterial 参数应用工具。 将 `GFShaderParameterProfile` 或参数字典写入 ShaderMaterial，也可以从持有 `material` 属性的节点解析材质。它只处理参数存在性校验、共享材质复制和批量写入， 不提供具体 shader、后处理算法或项目视觉规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MATERIAL_PROPERTY`](#member-gfshaderparameterutility-constants-default_material_property) | `const DEFAULT_MATERIAL_PROPERTY: NodePath = ^"material"` |
| 方法 | [`apply_profile`](#member-gfshaderparameterutility-methods-apply_profile) | `func apply_profile( target: Object, profile: GFShaderParameterProfile, options: Dictionary = {} ) -> int:` |
| 方法 | [`apply_parameters`](#member-gfshaderparameterutility-methods-apply_parameters) | `func apply_parameters(target: Object, parameters: Dictionary, options: Dictionary = {}) -> int:` |
| 方法 | [`resolve_shader_material`](#member-gfshaderparameterutility-methods-resolve_shader_material) | `func resolve_shader_material( target: Object, material_property: NodePath = DEFAULT_MATERIAL_PROPERTY ) -> ShaderMaterial:` |
| 方法 | [`get_shader_parameter_names`](#member-gfshaderparameterutility-methods-get_shader_parameter_names) | `func get_shader_parameter_names(material: ShaderMaterial) -> Array[StringName]:` |
| 方法 | [`has_shader_parameter`](#member-gfshaderparameterutility-methods-has_shader_parameter) | `func has_shader_parameter(material: ShaderMaterial, parameter_name: StringName) -> bool:` |

## 常量

<a id="member-gfshaderparameterutility-constants-default_material_property"></a>

### `DEFAULT_MATERIAL_PROPERTY`

- API：`public`

```gdscript
const DEFAULT_MATERIAL_PROPERTY: NodePath = ^"material"
```

默认材质属性路径。

## 方法

<a id="member-gfshaderparameterutility-methods-apply_profile"></a>

### `apply_profile`

- API：`public`

```gdscript
func apply_profile( target: Object, profile: GFShaderParameterProfile, options: Dictionary = {} ) -> int:
```

将 shader 参数 profile 应用到目标对象。

参数：

| 名称 | 说明 |
|---|---|
| `target` | ShaderMaterial，或持有材质属性的对象。 |
| `profile` | 要应用的 shader 参数 profile。 |
| `options` | 可选项，支持 material_property、duplicate_material、require_declared_parameters、warn_on_invalid_target、warn_on_missing_parameters 和 copy_values。 |

返回：实际写入的参数数量。

结构：

- `options`: Dictionary，material_property 为 NodePath/String，默认 material；duplicate_material 为 true 时会复制目标材质并写回属性；require_declared_parameters 默认为 true，会跳过 shader 未声明的 uniform；warn_on_invalid_target 和 warn_on_missing_parameters 控制警告；copy_values 默认为 true，会复制集合参数值后再写入。

<a id="member-gfshaderparameterutility-methods-apply_parameters"></a>

### `apply_parameters`

- API：`public`

```gdscript
func apply_parameters(target: Object, parameters: Dictionary, options: Dictionary = {}) -> int:
```

将 shader 参数字典应用到目标对象。

参数：

| 名称 | 说明 |
|---|---|
| `target` | ShaderMaterial，或持有材质属性的对象。 |
| `parameters` | 要应用的 shader 参数字典。 |
| `options` | 可选项，支持 material_property、duplicate_material、require_declared_parameters、warn_on_invalid_target、warn_on_missing_parameters 和 copy_values。 |

返回：实际写入的参数数量。

结构：

- `parameters`: Dictionary[StringName, Variant]，shader uniform 名到参数值的映射。
- `options`: Dictionary，material_property 为 NodePath/String，默认 material；duplicate_material 为 true 时会复制目标材质并写回属性；require_declared_parameters 默认为 true，会跳过 shader 未声明的 uniform；warn_on_invalid_target 和 warn_on_missing_parameters 控制警告；copy_values 默认为 true，会复制集合参数值后再写入。

<a id="member-gfshaderparameterutility-methods-resolve_shader_material"></a>

### `resolve_shader_material`

- API：`public`

```gdscript
func resolve_shader_material( target: Object, material_property: NodePath = DEFAULT_MATERIAL_PROPERTY ) -> ShaderMaterial:
```

从目标对象解析 ShaderMaterial。

参数：

| 名称 | 说明 |
|---|---|
| `target` | ShaderMaterial，或持有材质属性的对象。 |
| `material_property` | 当 target 不是 ShaderMaterial 时读取的材质属性路径。 |

返回：解析出的 ShaderMaterial；失败时返回 null。

<a id="member-gfshaderparameterutility-methods-get_shader_parameter_names"></a>

### `get_shader_parameter_names`

- API：`public`

```gdscript
func get_shader_parameter_names(material: ShaderMaterial) -> Array[StringName]:
```

获取 ShaderMaterial 当前 shader 声明的 uniform 参数名。

参数：

| 名称 | 说明 |
|---|---|
| `material` | 目标 ShaderMaterial。 |

返回：参数名数组。

结构：

- `return`: Array[StringName]，material.shader 声明的 shader uniform 名称。

<a id="member-gfshaderparameterutility-methods-has_shader_parameter"></a>

### `has_shader_parameter`

- API：`public`

```gdscript
func has_shader_parameter(material: ShaderMaterial, parameter_name: StringName) -> bool:
```

检查 ShaderMaterial 的 shader 是否声明了指定 uniform。

参数：

| 名称 | 说明 |
|---|---|
| `material` | 目标 ShaderMaterial。 |
| `parameter_name` | Shader uniform 参数名。 |

返回：参数存在时返回 true。
