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
| 方法 | [`apply_global_profile`](#member-gfshaderparameterutility-methods-apply_global_profile) | `func apply_global_profile(profile: GFShaderParameterProfile, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply_parameters`](#member-gfshaderparameterutility-methods-apply_parameters) | `func apply_parameters(target: Object, parameters: Dictionary, options: Dictionary = {}) -> int:` |
| 方法 | [`apply_global_parameters`](#member-gfshaderparameterutility-methods-apply_global_parameters) | `func apply_global_parameters(parameters: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`resolve_shader_material`](#member-gfshaderparameterutility-methods-resolve_shader_material) | `func resolve_shader_material( target: Object, material_property: NodePath = DEFAULT_MATERIAL_PROPERTY ) -> ShaderMaterial:` |
| 方法 | [`capture_shader_interface`](#member-gfshaderparameterutility-methods-capture_shader_interface) | `func capture_shader_interface( material: ShaderMaterial ) -> GFShaderInterfaceSnapshot:` |
| 方法 | [`validate_profile`](#member-gfshaderparameterutility-methods-validate_profile) | `func validate_profile( material: ShaderMaterial, profile: GFShaderParameterProfile, options: Dictionary = {} ) -> GFValidationReport:` |
| 方法 | [`validate_parameters`](#member-gfshaderparameterutility-methods-validate_parameters) | `func validate_parameters( material: ShaderMaterial, parameters: Dictionary, options: Dictionary = {} ) -> GFValidationReport:` |
| 方法 | [`get_shader_parameter_names`](#member-gfshaderparameterutility-methods-get_shader_parameter_names) | `func get_shader_parameter_names(material: ShaderMaterial) -> Array[StringName]:` |
| 方法 | [`has_shader_parameter`](#member-gfshaderparameterutility-methods-has_shader_parameter) | `func has_shader_parameter(material: ShaderMaterial, parameter_name: StringName) -> bool:` |
| 方法 | [`ensure_global_parameter`](#member-gfshaderparameterutility-methods-ensure_global_parameter) | `func ensure_global_parameter( parameter_name: StringName, parameter_type: int, default_value: Variant = null, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`get_global_parameter_names`](#member-gfshaderparameterutility-methods-get_global_parameter_names) | `func get_global_parameter_names() -> Array[StringName]:` |
| 方法 | [`get_global_parameter_live_names`](#member-gfshaderparameterutility-methods-get_global_parameter_live_names) | `func get_global_parameter_live_names() -> Array[StringName]:` |
| 方法 | [`get_global_parameter_declaration_names`](#member-gfshaderparameterutility-methods-get_global_parameter_declaration_names) | `func get_global_parameter_declaration_names() -> Array[StringName]:` |
| 方法 | [`has_global_parameter`](#member-gfshaderparameterutility-methods-has_global_parameter) | `func has_global_parameter(parameter_name: StringName) -> bool:` |
| 方法 | [`has_global_parameter_live`](#member-gfshaderparameterutility-methods-has_global_parameter_live) | `func has_global_parameter_live(parameter_name: StringName) -> bool:` |
| 方法 | [`has_global_parameter_declaration`](#member-gfshaderparameterutility-methods-has_global_parameter_declaration) | `func has_global_parameter_declaration(parameter_name: StringName) -> bool:` |

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
- 首次版本：`4.3.0`

```gdscript
func apply_profile( target: Object, profile: GFShaderParameterProfile, options: Dictionary = {} ) -> int:
```

将 shader 参数 profile 应用到目标对象。

参数：

| 名称 | 说明 |
|---|---|
| `target` | ShaderMaterial，或持有材质属性的对象。 |
| `profile` | 要应用的 shader 参数 profile。 |
| `options` | 可选项，支持 material_property、duplicate_material、require_declared_parameters、validate_parameter_types、warn_on_invalid_target、warn_on_missing_parameters、warn_on_type_mismatch 和 copy_values。 |

返回：实际写入的参数数量。

结构：

- `options`: Dictionary，material_property 为 NodePath/String，默认 material；duplicate_material 为 true 时会复制目标材质并写回属性；require_declared_parameters 默认为 true，会跳过 shader 未声明的 uniform；validate_parameter_types 默认为 true，会跳过与 uniform 声明不兼容的值；warn_on_invalid_target、warn_on_missing_parameters 和 warn_on_type_mismatch 控制警告；copy_values 默认为 true，会复制集合参数值后再写入。

<a id="member-gfshaderparameterutility-methods-apply_global_profile"></a>

### `apply_global_profile`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_global_profile(profile: GFShaderParameterProfile, options: Dictionary = {}) -> Dictionary:
```

将 shader 参数 profile 应用到 RenderingServer 全局 shader 参数。

参数：

| 名称 | 说明 |
|---|---|
| `profile` | 要应用的 shader 参数 profile。 |
| `options` | 可选项，支持 parameter_types、persist_project_setting、project_setting_types、project_setting_definitions、overwrite_project_setting、save_project_settings、register_live_parameter、copy_values、warn_on_invalid_parameter 和 dry_run。 |

返回：批量应用报告。

结构：

- `options`: Dictionary，parameter_types 为 Dictionary[StringName, int]，用于覆盖 RenderingServer 全局参数类型；persist_project_setting 为 true 时写入 ProjectSettings 的 shader_globals/<name>；project_setting_types 为 Dictionary[StringName, String]，用于覆盖持久化 type；project_setting_definitions 为 Dictionary[StringName, Dictionary]，用于传入完整 ProjectSettings 定义；overwrite_project_setting 控制是否覆盖已有设置；save_project_settings 控制是否立即保存 project.godot；register_live_parameter 控制是否补当前会话 RenderingServer 注册；copy_values 控制写入前是否复制集合值；warn_on_invalid_parameter 控制无效参数 warning；dry_run 为 true 时只生成报告。
- `return`: Dictionary，包含 ok、applied_count、registered_count、updated_count、project_setting_written_count、project_settings_saved、parameters 和 issues；每个参数报告区分 live 与 declaration 状态。

<a id="member-gfshaderparameterutility-methods-apply_parameters"></a>

### `apply_parameters`

- API：`public`
- 首次版本：`4.3.0`

```gdscript
func apply_parameters(target: Object, parameters: Dictionary, options: Dictionary = {}) -> int:
```

将 shader 参数字典应用到目标对象。

参数：

| 名称 | 说明 |
|---|---|
| `target` | ShaderMaterial，或持有材质属性的对象。 |
| `parameters` | 要应用的 shader 参数字典。 |
| `options` | 可选项，支持 material_property、duplicate_material、require_declared_parameters、validate_parameter_types、warn_on_invalid_target、warn_on_missing_parameters、warn_on_type_mismatch 和 copy_values。 |

返回：实际写入的参数数量。

结构：

- `parameters`: Dictionary[StringName, Variant]，shader uniform 名到参数值的映射。
- `options`: Dictionary，material_property 为 NodePath/String，默认 material；duplicate_material 为 true 时会复制目标材质并写回属性；require_declared_parameters 默认为 true，会跳过 shader 未声明的 uniform；validate_parameter_types 默认为 true，会跳过与 uniform 声明不兼容的值；warn_on_invalid_target、warn_on_missing_parameters 和 warn_on_type_mismatch 控制警告；copy_values 默认为 true，会复制集合参数值后再写入。

<a id="member-gfshaderparameterutility-methods-apply_global_parameters"></a>

### `apply_global_parameters`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_global_parameters(parameters: Dictionary, options: Dictionary = {}) -> Dictionary:
```

将 shader 参数字典应用到 RenderingServer 全局 shader 参数。

参数：

| 名称 | 说明 |
|---|---|
| `parameters` | 要应用的全局 shader 参数字典。 |
| `options` | 可选项，支持 parameter_types、persist_project_setting、project_setting_types、project_setting_definitions、overwrite_project_setting、save_project_settings、register_live_parameter、copy_values、warn_on_invalid_parameter 和 dry_run。 |

返回：批量应用报告。

结构：

- `parameters`: Dictionary[StringName, Variant]，全局 shader uniform 名到参数值的映射。
- `options`: Dictionary，parameter_types 为 Dictionary[StringName, int]，用于覆盖 RenderingServer 全局参数类型；persist_project_setting 为 true 时写入 ProjectSettings 的 shader_globals/<name>；project_setting_types 为 Dictionary[StringName, String]，用于覆盖持久化 type；project_setting_definitions 为 Dictionary[StringName, Dictionary]，用于传入完整 ProjectSettings 定义；overwrite_project_setting 控制是否覆盖已有设置；save_project_settings 控制是否立即保存 project.godot；register_live_parameter 控制是否补当前会话 RenderingServer 注册；copy_values 控制写入前是否复制集合值；warn_on_invalid_parameter 控制无效参数 warning；dry_run 为 true 时只生成报告。
- `return`: Dictionary，包含 ok、applied_count、registered_count、updated_count、project_setting_written_count、project_settings_saved、parameters 和 issues；每个参数报告区分 live 与 declaration 状态。

<a id="member-gfshaderparameterutility-methods-resolve_shader_material"></a>

### `resolve_shader_material`

- API：`public`
- 首次版本：`4.3.0`

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

<a id="member-gfshaderparameterutility-methods-capture_shader_interface"></a>

### `capture_shader_interface`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func capture_shader_interface( material: ShaderMaterial ) -> GFShaderInterfaceSnapshot:
```

捕获 ShaderMaterial 当前 uniform 接口。

参数：

| 名称 | 说明 |
|---|---|
| `material` | 目标 ShaderMaterial。 |

返回：接口快照；材质或 Shader 为空时返回 null。

<a id="member-gfshaderparameterutility-methods-validate_profile"></a>

### `validate_profile`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate_profile( material: ShaderMaterial, profile: GFShaderParameterProfile, options: Dictionary = {} ) -> GFValidationReport:
```

校验 profile 是否符合 ShaderMaterial 当前 uniform 接口。

参数：

| 名称 | 说明 |
|---|---|
| `material` | 目标 ShaderMaterial。 |
| `profile` | 要校验的 profile。 |
| `options` | 传给 GFShaderInterfaceSnapshot.validate_parameters() 的选项。 |

返回：标准校验报告。

结构：

- `options`: Dictionary shader parameter validation options.

<a id="member-gfshaderparameterutility-methods-validate_parameters"></a>

### `validate_parameters`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate_parameters( material: ShaderMaterial, parameters: Dictionary, options: Dictionary = {} ) -> GFValidationReport:
```

校验参数字典是否符合 ShaderMaterial 当前 uniform 接口。

参数：

| 名称 | 说明 |
|---|---|
| `material` | 目标 ShaderMaterial。 |
| `parameters` | uniform 参数字典。 |
| `options` | 传给 GFShaderInterfaceSnapshot.validate_parameters() 的选项。 |

返回：标准校验报告。

结构：

- `parameters`: Dictionary[StringName|String, Variant] shader parameter values.
- `options`: Dictionary shader parameter validation options.

<a id="member-gfshaderparameterutility-methods-get_shader_parameter_names"></a>

### `get_shader_parameter_names`

- API：`public`
- 首次版本：`4.3.0`

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
- 首次版本：`4.3.0`

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

<a id="member-gfshaderparameterutility-methods-ensure_global_parameter"></a>

### `ensure_global_parameter`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func ensure_global_parameter( parameter_name: StringName, parameter_type: int, default_value: Variant = null, options: Dictionary = {} ) -> Dictionary:
```

确保 RenderingServer 全局 shader 参数存在，并可选写入 ProjectSettings。

参数：

| 名称 | 说明 |
|---|---|
| `parameter_name` | 全局 shader uniform 参数名。 |
| `parameter_type` | RenderingServer.GLOBAL_VAR_TYPE_* 参数类型。 |
| `default_value` | 参数缺失时用于注册或持久化的默认值。 |
| `options` | 可选项，支持 persist_project_setting、project_setting_type、project_setting_definition、overwrite_project_setting、save_project_settings、register_live_parameter、update_live_value、copy_values、warn_on_invalid_parameter 和 dry_run。 |

返回：参数处理报告。

结构：

- `default_value`: Variant，可被 RenderingServer.global_shader_parameter_add() 或 ProjectSettings shader_globals 定义接受的默认值。
- `options`: Dictionary，persist_project_setting 为 true 时写入由参数名唯一派生的 shader_globals/<name>；project_setting_type 覆盖持久化 type；project_setting_definition 提供完整声明；overwrite_project_setting 控制是否覆盖已有设置；save_project_settings 控制是否立即保存 project.godot；register_live_parameter 控制是否补当前会话 RenderingServer 注册；update_live_value 控制是否同时设置当前值；copy_values 控制写入前是否复制集合值；warn_on_invalid_parameter 控制无效参数 warning；dry_run 为 true 时只生成报告。
- `return`: Dictionary，包含 ok、parameter_name、parameter_type、live_registered、live_already_registered、live_available、live_updated、project_setting_path、project_setting_written、project_setting_already_present、declaration_written、declaration_already_present、declaration_available、project_settings_saved 和 error。

<a id="member-gfshaderparameterutility-methods-get_global_parameter_names"></a>

### `get_global_parameter_names`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_global_parameter_names() -> Array[StringName]:
```

获取 GF 可稳定识别的全局 shader 参数名。

返回：全局 shader 参数名数组。

结构：

- `return`: Array[StringName]，包含 GF 本次会话通过本工具注册的 live 参数，以及 ProjectSettings shader_globals/<name> declaration 参数。

<a id="member-gfshaderparameterutility-methods-get_global_parameter_live_names"></a>

### `get_global_parameter_live_names`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_global_parameter_live_names() -> Array[StringName]:
```

获取 GF 本次会话通过本工具注册的 live 全局 shader 参数名。

返回：live 全局 shader 参数名数组。

结构：

- `return`: Array[StringName]，只包含本工具在当前会话中注册的 RenderingServer 全局参数。

<a id="member-gfshaderparameterutility-methods-get_global_parameter_declaration_names"></a>

### `get_global_parameter_declaration_names`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_global_parameter_declaration_names() -> Array[StringName]:
```

获取 ProjectSettings 中声明的全局 shader 参数名。

返回：declaration 全局 shader 参数名数组。

结构：

- `return`: Array[StringName]，只包含 ProjectSettings shader_globals/<name> declaration。

<a id="member-gfshaderparameterutility-methods-has_global_parameter"></a>

### `has_global_parameter`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_global_parameter(parameter_name: StringName) -> bool:
```

检查当前会话是否已通过本工具注册指定 live 全局 shader 参数。

参数：

| 名称 | 说明 |
|---|---|
| `parameter_name` | 全局 shader uniform 参数名。 |

返回：live 参数存在时返回 true。

<a id="member-gfshaderparameterutility-methods-has_global_parameter_live"></a>

### `has_global_parameter_live`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_global_parameter_live(parameter_name: StringName) -> bool:
```

检查当前会话是否已通过本工具注册指定 live 全局 shader 参数。

参数：

| 名称 | 说明 |
|---|---|
| `parameter_name` | 全局 shader uniform 参数名。 |

返回：live 参数存在时返回 true。

<a id="member-gfshaderparameterutility-methods-has_global_parameter_declaration"></a>

### `has_global_parameter_declaration`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_global_parameter_declaration(parameter_name: StringName) -> bool:
```

检查 ProjectSettings 是否声明了指定全局 shader 参数。

参数：

| 名称 | 说明 |
|---|---|
| `parameter_name` | 全局 shader uniform 参数名。 |

返回：declaration 存在时返回 true。
