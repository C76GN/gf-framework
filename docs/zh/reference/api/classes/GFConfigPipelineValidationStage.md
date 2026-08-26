# GFConfigPipelineValidationStage

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_pipeline_validation_stage.gd`
- 模块：`Tools`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`9.0.0`

Config Pipeline 的内置语义校验阶段。 把 Layout 记录规范化，解析类型化表头，推导或复制 schema，执行类型转换与完整校验。 只有通过语义校验的数据才会形成 GFConfigPipelineTableIR。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STAGE_ID`](#member-gfconfigpipelinevalidationstage-constants-stage_id) | `const STAGE_ID: String = "gf.config.validation.builtin"` |
| 常量 | [`IMPLEMENTATION_VERSION`](#member-gfconfigpipelinevalidationstage-constants-implementation_version) | `const IMPLEMENTATION_VERSION: int = 2` |
| 方法 | [`compile_table`](#member-gfconfigpipelinevalidationstage-methods-compile_table) | `func compile_table( source: GFConfigPipelineTableSource, layout_result: Dictionary, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`get_stage_descriptor`](#member-gfconfigpipelinevalidationstage-methods-get_stage_descriptor) | `func get_stage_descriptor() -> Dictionary:` |

## 常量

<a id="member-gfconfigpipelinevalidationstage-constants-stage_id"></a>

### `STAGE_ID`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const STAGE_ID: String = "gf.config.validation.builtin"
```

Validation 阶段的稳定实现标识。

<a id="member-gfconfigpipelinevalidationstage-constants-implementation_version"></a>

### `IMPLEMENTATION_VERSION`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const IMPLEMENTATION_VERSION: int = 2
```

Validation 阶段的实现版本；改变语义校验或 IR 生成语义时递增。

## 方法

<a id="member-gfconfigpipelinevalidationstage-methods-compile_table"></a>

### `compile_table`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func compile_table( source: GFConfigPipelineTableSource, layout_result: Dictionary, options: Dictionary = {} ) -> Dictionary:
```

把 Layout 结果编译为通过校验的版本化单表 IR。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 单表来源声明。 |
| `layout_result` | Layout 阶段结果。 |
| `options` | 校验选项。 |

返回：Validation 阶段结果。

结构：

- `layout_result`: Dictionary，符合 gf.config_pipeline.layout_result@2。
- `options`: Dictionary，可包含 parse_options；其字段覆盖 source.parse_options 并传给 schema 校验上下文。
- `return`: Dictionary，包含 success、phase、ir、report、source_path、format、error_kind 和 error。

<a id="member-gfconfigpipelinevalidationstage-methods-get_stage_descriptor"></a>

### `get_stage_descriptor`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_stage_descriptor() -> Dictionary:
```

返回阶段实现的稳定描述，用于流水线诊断和编译指纹。

返回：阶段描述。

结构：

- `return`: Dictionary，包含 stage_id、implementation_version、implementation_dependencies、input_contract 和 output_contract。
