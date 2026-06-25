# GFPolicyProvider

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/policy/gf_policy_provider.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`6.0.0`

通用策略提供者协议。 描述可对某类 artifact 字典执行校验、治理或打分的策略扩展点。 Provider 只声明输入输出和执行协议，不规定具体业务类型。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`provider_id`](#member-gfpolicyprovider-properties-provider_id) | `var provider_id: StringName = &""` |
| 属性 | [`display_name`](#member-gfpolicyprovider-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`supported_artifact_kinds`](#member-gfpolicyprovider-properties-supported_artifact_kinds) | `var supported_artifact_kinds: PackedStringArray = PackedStringArray()` |
| 属性 | [`priority`](#member-gfpolicyprovider-properties-priority) | `var priority: int = 0` |
| 属性 | [`input_schema`](#member-gfpolicyprovider-properties-input_schema) | `var input_schema: Dictionary = {}` |
| 属性 | [`output_schema`](#member-gfpolicyprovider-properties-output_schema) | `var output_schema: Dictionary = {}` |
| 属性 | [`deterministic`](#member-gfpolicyprovider-properties-deterministic) | `var deterministic: bool = true` |
| 属性 | [`metadata`](#member-gfpolicyprovider-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfpolicyprovider-methods-configure) | `func configure( p_provider_id: StringName, p_supported_artifact_kinds: PackedStringArray = PackedStringArray(), p_metadata: Dictionary = {} ) -> GFPolicyProvider:` |
| 方法 | [`supports_artifact`](#member-gfpolicyprovider-methods-supports_artifact) | `func supports_artifact(artifact: Dictionary) -> bool:` |
| 方法 | [`evaluate`](#member-gfpolicyprovider-methods-evaluate) | `func evaluate(artifact: Dictionary, context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_result`](#member-gfpolicyprovider-methods-make_result) | `func make_result( ok: bool, status: StringName, artifact: Dictionary, issues: Array = [], data: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfpolicyprovider-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`_evaluate_policy`](#member-gfpolicyprovider-methods-_evaluate_policy) | `func _evaluate_policy(_artifact: Dictionary, _context: Dictionary) -> Dictionary:` |

## 属性

<a id="member-gfpolicyprovider-properties-provider_id"></a>

### `provider_id`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var provider_id: StringName = &""
```

Provider 稳定标识。

<a id="member-gfpolicyprovider-properties-display_name"></a>

### `display_name`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var display_name: String = ""
```

显示名称。

<a id="member-gfpolicyprovider-properties-supported_artifact_kinds"></a>

### `supported_artifact_kinds`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var supported_artifact_kinds: PackedStringArray = PackedStringArray()
```

支持的 artifact kind；为空表示支持所有 kind。

<a id="member-gfpolicyprovider-properties-priority"></a>

### `priority`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var priority: int = 0
```

策略优先级，较小值先执行。

<a id="member-gfpolicyprovider-properties-input_schema"></a>

### `input_schema`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var input_schema: Dictionary = {}
```

输入 schema 描述。GF 不解释字段业务含义。

结构：

- `input_schema`: Dictionary caller-defined policy input schema.

<a id="member-gfpolicyprovider-properties-output_schema"></a>

### `output_schema`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var output_schema: Dictionary = {}
```

输出 schema 描述。GF 不解释字段业务含义。

结构：

- `output_schema`: Dictionary caller-defined policy output schema.

<a id="member-gfpolicyprovider-properties-deterministic"></a>

### `deterministic`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var deterministic: bool = true
```

策略是否声明为确定性。

<a id="member-gfpolicyprovider-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方附加元数据。

结构：

- `metadata`: Dictionary for caller-defined policy metadata.

## 方法

<a id="member-gfpolicyprovider-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func configure( p_provider_id: StringName, p_supported_artifact_kinds: PackedStringArray = PackedStringArray(), p_metadata: Dictionary = {} ) -> GFPolicyProvider:
```

配置 Provider。

参数：

| 名称 | 说明 |
|---|---|
| `p_provider_id` | Provider 稳定标识。 |
| `p_supported_artifact_kinds` | 支持的 artifact kind；为空表示支持所有 kind。 |
| `p_metadata` | 调用方元数据。 |

返回：当前 Provider。

结构：

- `p_metadata`: Dictionary copied into metadata.

<a id="member-gfpolicyprovider-methods-supports_artifact"></a>

### `supports_artifact`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func supports_artifact(artifact: Dictionary) -> bool:
```

判断 Provider 是否支持该 artifact。

参数：

| 名称 | 说明 |
|---|---|
| `artifact` | artifact 字典。 |

返回：支持时返回 true。

结构：

- `artifact`: Dictionary with optional kind or artifact_kind.

<a id="member-gfpolicyprovider-methods-evaluate"></a>

### `evaluate`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func evaluate(artifact: Dictionary, context: Dictionary = {}) -> Dictionary:
```

执行策略。

参数：

| 名称 | 说明 |
|---|---|
| `artifact` | artifact 字典。 |
| `context` | 调用方上下文。 |

返回：策略结果。

结构：

- `artifact`: Dictionary policy input artifact.
- `context`: Dictionary caller-defined policy context.
- `return`: Dictionary with ok, status, provider_id, artifact_kind, issues, data, and metadata.

<a id="member-gfpolicyprovider-methods-make_result"></a>

### `make_result`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func make_result( ok: bool, status: StringName, artifact: Dictionary, issues: Array = [], data: Dictionary = {} ) -> Dictionary:
```

创建策略结果。

参数：

| 名称 | 说明 |
|---|---|
| `ok` | 策略是否通过。 |
| `status` | 策略状态。 |
| `artifact` | artifact 字典。 |
| `issues` | issue 字典数组。 |
| `data` | 策略输出数据。 |

返回：策略结果。

结构：

- `artifact`: Dictionary policy input artifact.
- `issues`: Array[Dictionary] policy issues.
- `data`: Dictionary policy output data.
- `return`: Dictionary with ok, status, provider_id, artifact_kind, issues, data, and metadata.

<a id="member-gfpolicyprovider-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary containing provider_id, supported_artifact_kinds, priority, deterministic, and metadata.

<a id="member-gfpolicyprovider-methods-_evaluate_policy"></a>

### `_evaluate_policy`

- API：`protected`
- 首次版本：`6.0.0`

```gdscript
func _evaluate_policy(_artifact: Dictionary, _context: Dictionary) -> Dictionary:
```

执行具体策略，供子类重写。

参数：

| 名称 | 说明 |
|---|---|
| `_artifact` | artifact 字典副本。 |
| `_context` | 调用方上下文字典副本。 |

返回：策略结果；返回空字典表示通过。

结构：

- `_artifact`: Dictionary policy input artifact.
- `_context`: Dictionary caller-defined policy context.
- `return`: Dictionary policy result; empty means passed.
