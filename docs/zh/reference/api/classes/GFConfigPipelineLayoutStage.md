# GFConfigPipelineLayoutStage

[API Reference](../index.md) / [Tool Packages](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_pipeline_layout_stage.gd`
- 模块：`Tool Packages`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`9.0.0`

Config Pipeline 的内置布局解析阶段。 把 Reader 原始载荷解码为记录、表头和来源位置，不推导 schema、不转换字段类型。 内置实现支持 CSV、JSON、ConfigFile 与 XLSX，格式专属细节在此阶段内收敛。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STAGE_ID`](#member-gfconfigpipelinelayoutstage-constants-stage_id) | `const STAGE_ID: String = "gf.config.layout.builtin"` |
| 常量 | [`IMPLEMENTATION_VERSION`](#member-gfconfigpipelinelayoutstage-constants-implementation_version) | `const IMPLEMENTATION_VERSION: int = 3` |
| 方法 | [`decode_source`](#member-gfconfigpipelinelayoutstage-methods-decode_source) | `func decode_source( source: GFConfigPipelineTableSource, read_result: Dictionary, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`get_stage_descriptor`](#member-gfconfigpipelinelayoutstage-methods-get_stage_descriptor) | `func get_stage_descriptor() -> Dictionary:` |

## 常量

<a id="member-gfconfigpipelinelayoutstage-constants-stage_id"></a>

### `STAGE_ID`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const STAGE_ID: String = "gf.config.layout.builtin"
```

Layout 阶段的稳定实现标识。

<a id="member-gfconfigpipelinelayoutstage-constants-implementation_version"></a>

### `IMPLEMENTATION_VERSION`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const IMPLEMENTATION_VERSION: int = 3
```

Layout 阶段的实现版本；改变布局解析语义时递增。

## 方法

<a id="member-gfconfigpipelinelayoutstage-methods-decode_source"></a>

### `decode_source`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func decode_source( source: GFConfigPipelineTableSource, read_result: Dictionary, options: Dictionary = {} ) -> Dictionary:
```

解码 Reader 阶段载荷并保留格式无关的来源定位信息。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 单表来源声明。 |
| `read_result` | Reader 阶段结果。 |
| `options` | 布局解析选项。 |

返回：Layout 阶段结果。

结构：

- `read_result`: Dictionary，符合 gf.config_pipeline.reader_result@1。
- `options`: Dictionary，可包含 parse_options；其字段覆盖 source.parse_options。
- `return`: Dictionary，包含 success、phase、data、header、row_locations、source、source_path、format、error_kind、error、error_line 和 error_column，并可包含格式专属字段。

<a id="member-gfconfigpipelinelayoutstage-methods-get_stage_descriptor"></a>

### `get_stage_descriptor`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_stage_descriptor() -> Dictionary:
```

返回阶段实现的稳定描述，用于流水线诊断和编译指纹。

返回：阶段描述。

结构：

- `return`: Dictionary，包含 stage_id、implementation_version、implementation_dependencies、input_contract、output_contract 和 supported_formats。
