# GFShaderParameterBinder

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/display/gf_shader_parameter_binder.gd`
- 模块：`Standard`
- 继承：`Node`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`4.3.0`

场景中的 Shader 参数 Profile 绑定节点。 将 `GFShaderParameterProfile` 应用到目标节点或材质，便于项目用可复用 Resource 管理 ShaderMaterial uniform 参数。它只负责目标解析、材质复制选项、 profile 变化监听和批量写入，不规定 shader、uniform 命名或视觉语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`profile_applied`](#member-gfshaderparameterbinder-signals-profile_applied) | `signal profile_applied(applied_count: int)` |
| 属性 | [`profile`](#member-gfshaderparameterbinder-properties-profile) | `var profile: GFShaderParameterProfile = null:` |
| 属性 | [`target_path`](#member-gfshaderparameterbinder-properties-target_path) | `var target_path: NodePath = ^".."` |
| 属性 | [`material_property`](#member-gfshaderparameterbinder-properties-material_property) | `var material_property: NodePath = ^"material"` |
| 属性 | [`apply_on_ready`](#member-gfshaderparameterbinder-properties-apply_on_ready) | `var apply_on_ready: bool = true` |
| 属性 | [`apply_each_process`](#member-gfshaderparameterbinder-properties-apply_each_process) | `var apply_each_process: bool = false:` |
| 属性 | [`auto_apply_on_profile_changed`](#member-gfshaderparameterbinder-properties-auto_apply_on_profile_changed) | `var auto_apply_on_profile_changed: bool = true` |
| 属性 | [`duplicate_material_on_apply`](#member-gfshaderparameterbinder-properties-duplicate_material_on_apply) | `var duplicate_material_on_apply: bool = false` |
| 属性 | [`require_declared_parameters`](#member-gfshaderparameterbinder-properties-require_declared_parameters) | `var require_declared_parameters: bool = true` |
| 属性 | [`warn_on_invalid_target`](#member-gfshaderparameterbinder-properties-warn_on_invalid_target) | `var warn_on_invalid_target: bool = true` |
| 属性 | [`warn_on_missing_parameters`](#member-gfshaderparameterbinder-properties-warn_on_missing_parameters) | `var warn_on_missing_parameters: bool = true` |
| 属性 | [`copy_values`](#member-gfshaderparameterbinder-properties-copy_values) | `var copy_values: bool = true` |
| 方法 | [`apply`](#member-gfshaderparameterbinder-methods-apply) | `func apply() -> int:` |
| 方法 | [`resolve_target`](#member-gfshaderparameterbinder-methods-resolve_target) | `func resolve_target() -> Object:` |

## 信号

<a id="member-gfshaderparameterbinder-signals-profile_applied"></a>

### `profile_applied`

- API：`public`

```gdscript
signal profile_applied(applied_count: int)
```

Profile 应用完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `applied_count` | 实际写入的参数数量。 |

## 属性

<a id="member-gfshaderparameterbinder-properties-profile"></a>

### `profile`

- API：`public`

```gdscript
var profile: GFShaderParameterProfile = null:
```

要应用的 Shader 参数 Profile。

<a id="member-gfshaderparameterbinder-properties-target_path"></a>

### `target_path`

- API：`public`

```gdscript
var target_path: NodePath = ^".."
```

目标节点路径。默认指向父节点，适合把 Binder 作为材质节点的子节点使用。

<a id="member-gfshaderparameterbinder-properties-material_property"></a>

### `material_property`

- API：`public`

```gdscript
var material_property: NodePath = ^"material"
```

当目标不是 ShaderMaterial 时，用于读取材质的属性路径。

<a id="member-gfshaderparameterbinder-properties-apply_on_ready"></a>

### `apply_on_ready`

- API：`public`

```gdscript
var apply_on_ready: bool = true
```

进入场景树 ready 阶段时是否自动应用 profile。

<a id="member-gfshaderparameterbinder-properties-apply_each_process"></a>

### `apply_each_process`

- API：`public`

```gdscript
var apply_each_process: bool = false:
```

是否在每帧 `_process()` 中重新应用 profile。

<a id="member-gfshaderparameterbinder-properties-auto_apply_on_profile_changed"></a>

### `auto_apply_on_profile_changed`

- API：`public`

```gdscript
var auto_apply_on_profile_changed: bool = true
```

Profile 通过公开方法发出 changed 信号时是否自动应用。

<a id="member-gfshaderparameterbinder-properties-duplicate_material_on_apply"></a>

### `duplicate_material_on_apply`

- API：`public`

```gdscript
var duplicate_material_on_apply: bool = false
```

应用前是否复制目标材质并写回 material_property，避免修改共享材质资源。

<a id="member-gfshaderparameterbinder-properties-require_declared_parameters"></a>

### `require_declared_parameters`

- API：`public`

```gdscript
var require_declared_parameters: bool = true
```

是否要求 shader 已声明 profile 中的 uniform 参数。

<a id="member-gfshaderparameterbinder-properties-warn_on_invalid_target"></a>

### `warn_on_invalid_target`

- API：`public`

```gdscript
var warn_on_invalid_target: bool = true
```

目标或材质无效时是否输出 warning。

<a id="member-gfshaderparameterbinder-properties-warn_on_missing_parameters"></a>

### `warn_on_missing_parameters`

- API：`public`

```gdscript
var warn_on_missing_parameters: bool = true
```

profile 中存在 shader 未声明参数时是否输出 warning。

<a id="member-gfshaderparameterbinder-properties-copy_values"></a>

### `copy_values`

- API：`public`

```gdscript
var copy_values: bool = true
```

写入参数前是否复制集合值，避免外部可变集合污染材质参数。

## 方法

<a id="member-gfshaderparameterbinder-methods-apply"></a>

### `apply`

- API：`public`

```gdscript
func apply() -> int:
```

将当前 profile 应用到目标材质。

返回：实际写入的参数数量。

<a id="member-gfshaderparameterbinder-methods-resolve_target"></a>

### `resolve_target`

- API：`public`

```gdscript
func resolve_target() -> Object:
```

解析当前目标对象。

返回：目标节点；解析失败时返回 null。
