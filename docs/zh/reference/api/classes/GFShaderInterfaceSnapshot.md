# GFShaderInterfaceSnapshot

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/display/gf_shader_interface_snapshot.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`10.0.0`

可持久化的 Shader uniform 接口快照。 从 Shader 反射结果捕获稳定排序的 uniform 声明，并用同一份数据校验参数集合 或比较接口漂移。快照只保存公开接口字段，不保存 shader 源码、材质当前值、 渲染后端产物或项目视觉语义。直接 new() 的实例保持未配置，必须经 capture() 或 from_dict() 建立后再使用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`CURRENT_SCHEMA_VERSION`](#member-gfshaderinterfacesnapshot-constants-current_schema_version) | `const CURRENT_SCHEMA_VERSION: int = 1` |
| 方法 | [`capture`](#member-gfshaderinterfacesnapshot-methods-capture) | `static func capture(shader: Shader) -> GFShaderInterfaceSnapshot:` |
| 方法 | [`from_dict`](#member-gfshaderinterfacesnapshot-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFShaderInterfaceSnapshot:` |
| 方法 | [`get_schema_version`](#member-gfshaderinterfacesnapshot-methods-get_schema_version) | `func get_schema_version() -> int:` |
| 方法 | [`get_shader_mode`](#member-gfshaderinterfacesnapshot-methods-get_shader_mode) | `func get_shader_mode() -> int:` |
| 方法 | [`get_uniforms`](#member-gfshaderinterfacesnapshot-methods-get_uniforms) | `func get_uniforms() -> Array[Dictionary]:` |
| 方法 | [`get_uniform_names`](#member-gfshaderinterfacesnapshot-methods-get_uniform_names) | `func get_uniform_names() -> Array[StringName]:` |
| 方法 | [`has_uniform`](#member-gfshaderinterfacesnapshot-methods-has_uniform) | `func has_uniform(parameter_name: StringName) -> bool:` |
| 方法 | [`get_uniform`](#member-gfshaderinterfacesnapshot-methods-get_uniform) | `func get_uniform(parameter_name: StringName) -> Dictionary:` |
| 方法 | [`accepts_parameter_value`](#member-gfshaderinterfacesnapshot-methods-accepts_parameter_value) | `func accepts_parameter_value( parameter_name: StringName, value: Variant, options: Dictionary = {} ) -> bool:` |
| 方法 | [`validate_definition`](#member-gfshaderinterfacesnapshot-methods-validate_definition) | `func validate_definition(options: Dictionary = {}) -> GFValidationReport:` |
| 方法 | [`validate_parameters`](#member-gfshaderinterfacesnapshot-methods-validate_parameters) | `func validate_parameters( parameters: Dictionary, options: Dictionary = {} ) -> GFValidationReport:` |
| 方法 | [`compare_with`](#member-gfshaderinterfacesnapshot-methods-compare_with) | `func compare_with( actual: GFShaderInterfaceSnapshot, options: Dictionary = {} ) -> GFValidationReport:` |
| 方法 | [`validate_shader`](#member-gfshaderinterfacesnapshot-methods-validate_shader) | `func validate_shader( shader: Shader, options: Dictionary = {} ) -> GFValidationReport:` |
| 方法 | [`duplicate_snapshot`](#member-gfshaderinterfacesnapshot-methods-duplicate_snapshot) | `func duplicate_snapshot() -> GFShaderInterfaceSnapshot:` |
| 方法 | [`to_dict`](#member-gfshaderinterfacesnapshot-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 常量

<a id="member-gfshaderinterfacesnapshot-constants-current_schema_version"></a>

### `CURRENT_SCHEMA_VERSION`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const CURRENT_SCHEMA_VERSION: int = 1
```

当前快照字典 schema 版本。

## 方法

<a id="member-gfshaderinterfacesnapshot-methods-capture"></a>

### `capture`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
static func capture(shader: Shader) -> GFShaderInterfaceSnapshot:
```

从 Shader 当前反射接口创建快照。 参数分组提示不会进入快照；uniform 会按名称和签名稳定排序。

参数：

| 名称 | 说明 |
|---|---|
| `shader` | 要捕获的 Shader；为空时返回 null。 |

返回：新快照，或 null。

<a id="member-gfshaderinterfacesnapshot-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFShaderInterfaceSnapshot:
```

从字典创建快照。 输入会被深复制并规范化，但不会强转字段类型；不支持的 schema、缺失数组和 无效条目由 validate_definition() 报告。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 快照字典。 |

返回：新快照。

结构：

- `data`: Dictionary，包含 schema_version、shader_mode 和 uniforms；uniform 字段为 name、type、class_name、hint、hint_string、usage。

<a id="member-gfshaderinterfacesnapshot-methods-get_schema_version"></a>

### `get_schema_version`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_schema_version() -> int:
```

获取快照 schema 版本。

返回：schema 版本。

<a id="member-gfshaderinterfacesnapshot-methods-get_shader_mode"></a>

### `get_shader_mode`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_shader_mode() -> int:
```

获取捕获时的 Shader 模式。

返回：Shader.Mode 对应整数。

<a id="member-gfshaderinterfacesnapshot-methods-get_uniforms"></a>

### `get_uniforms`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_uniforms() -> Array[Dictionary]:
```

获取稳定排序的 uniform 条目深拷贝。

返回：uniform 条目数组。

结构：

- `return`: Array[Dictionary]，每项包含 name、type、class_name、hint、hint_string 和 usage。

<a id="member-gfshaderinterfacesnapshot-methods-get_uniform_names"></a>

### `get_uniform_names`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_uniform_names() -> Array[StringName]:
```

获取稳定排序的 uniform 名。

返回：uniform 名数组。

结构：

- `return`: Array[StringName]，按名称稳定排序。

<a id="member-gfshaderinterfacesnapshot-methods-has_uniform"></a>

### `has_uniform`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func has_uniform(parameter_name: StringName) -> bool:
```

检查接口是否声明 uniform。

参数：

| 名称 | 说明 |
|---|---|
| `parameter_name` | uniform 名。 |

返回：已声明时返回 true。

<a id="member-gfshaderinterfacesnapshot-methods-get_uniform"></a>

### `get_uniform`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_uniform(parameter_name: StringName) -> Dictionary:
```

获取 uniform 条目深拷贝。

参数：

| 名称 | 说明 |
|---|---|
| `parameter_name` | uniform 名。 |

返回：uniform 条目；不存在时返回空字典。

结构：

- `return`: Dictionary，包含 name、type、class_name、hint、hint_string 和 usage。

<a id="member-gfshaderinterfacesnapshot-methods-accepts_parameter_value"></a>

### `accepts_parameter_value`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func accepts_parameter_value( parameter_name: StringName, value: Variant, options: Dictionary = {} ) -> bool:
```

检查一个值是否符合已声明 uniform 类型。 数字类型严格匹配，不做 int/float 隐式转换；Object 参数会继续检查资源类。

参数：

| 名称 | 说明 |
|---|---|
| `parameter_name` | uniform 名。 |
| `value` | 候选值。 |
| `options` | 支持 allow_null_object，默认 true。 |

返回：已声明且值兼容时返回 true。

结构：

- `value`: Variant shader parameter value.
- `options`: Dictionary，allow_null_object 控制 TYPE_OBJECT uniform 是否接受 null。

<a id="member-gfshaderinterfacesnapshot-methods-validate_definition"></a>

### `validate_definition`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate_definition(options: Dictionary = {}) -> GFValidationReport:
```

校验快照 schema、Shader 模式、uniform 字段和重复名称。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 支持 subject 和 metadata。 |

返回：标准校验报告。

结构：

- `options`: Dictionary，subject 覆盖报告主题，metadata 为调用方报告元数据。

<a id="member-gfshaderinterfacesnapshot-methods-validate_parameters"></a>

### `validate_parameters`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate_parameters( parameters: Dictionary, options: Dictionary = {} ) -> GFValidationReport:
```

根据快照校验参数字典。 Profile 默认按部分覆盖处理，因此缺失 uniform 默认忽略；未知参数和错型值默认报错。

参数：

| 名称 | 说明 |
|---|---|
| `parameters` | uniform 名到参数值的映射。 |
| `options` | 支持 subject、metadata、missing_severity、extra_severity、type_mismatch_severity 和 allow_null_object。 |

返回：标准校验报告。

结构：

- `parameters`: Dictionary[StringName|String, Variant] shader parameter values.
- `options`: Dictionary，severity 可为 ignore、info、warning 或 error；missing 默认 ignore，extra/type mismatch 默认 error；allow_null_object 默认 true。

<a id="member-gfshaderinterfacesnapshot-methods-compare_with"></a>

### `compare_with`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func compare_with( actual: GFShaderInterfaceSnapshot, options: Dictionary = {} ) -> GFValidationReport:
```

比较期望快照与实际快照。 当前快照作为 expected；actual 缺失和签名变化默认报错，新增 uniform 默认 warning。

参数：

| 名称 | 说明 |
|---|---|
| `actual` | 实际接口快照。 |
| `options` | 支持 subject、metadata、mode_mismatch_severity、missing_severity、extra_severity、signature_severity 和 usage_severity。 |

返回：标准校验报告。

结构：

- `options`: Dictionary，severity 可为 ignore、info、warning 或 error；mode/missing/signature 默认 error，extra/usage 默认 warning。

<a id="member-gfshaderinterfacesnapshot-methods-validate_shader"></a>

### `validate_shader`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate_shader( shader: Shader, options: Dictionary = {} ) -> GFValidationReport:
```

将 Shader 当前接口与本快照比较。

参数：

| 名称 | 说明 |
|---|---|
| `shader` | 实际 Shader。 |
| `options` | 传给 compare_with() 的报告和 severity 选项。 |

返回：标准校验报告。

结构：

- `options`: Dictionary compare_with() options.

<a id="member-gfshaderinterfacesnapshot-methods-duplicate_snapshot"></a>

### `duplicate_snapshot`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func duplicate_snapshot() -> GFShaderInterfaceSnapshot:
```

创建快照深拷贝。

返回：新快照。

<a id="member-gfshaderinterfacesnapshot-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为稳定排序的快照字典。

返回：快照字典。

结构：

- `return`: Dictionary，包含 schema_version、shader_mode 和 uniforms。
