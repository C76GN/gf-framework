# GFConfigPipelineReaderStage

[API Reference](../index.md) / [Tool Packages](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_pipeline_reader_stage.gd`
- 模块：`Tool Packages`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`9.0.0`

Config Pipeline 的内置来源读取阶段。 只负责来源存在性、读取预算和原始载荷取得，不解析表布局或业务字段。 文本来源返回原文，XLSX 来源返回已完成预算检查的文件载荷描述。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STAGE_ID`](#member-gfconfigpipelinereaderstage-constants-stage_id) | `const STAGE_ID: String = "gf.config.reader.builtin"` |
| 常量 | [`IMPLEMENTATION_VERSION`](#member-gfconfigpipelinereaderstage-constants-implementation_version) | `const IMPLEMENTATION_VERSION: int = 1` |
| 方法 | [`read_source`](#member-gfconfigpipelinereaderstage-methods-read_source) | `func read_source(source: GFConfigPipelineTableSource, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_stage_descriptor`](#member-gfconfigpipelinereaderstage-methods-get_stage_descriptor) | `func get_stage_descriptor() -> Dictionary:` |

## 常量

<a id="member-gfconfigpipelinereaderstage-constants-stage_id"></a>

### `STAGE_ID`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const STAGE_ID: String = "gf.config.reader.builtin"
```

Reader 阶段的稳定实现标识。

<a id="member-gfconfigpipelinereaderstage-constants-implementation_version"></a>

### `IMPLEMENTATION_VERSION`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const IMPLEMENTATION_VERSION: int = 1
```

Reader 阶段的实现版本；改变读取语义时递增。

## 方法

<a id="member-gfconfigpipelinereaderstage-methods-read_source"></a>

### `read_source`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func read_source(source: GFConfigPipelineTableSource, options: Dictionary = {}) -> Dictionary:
```

读取来源的原始载荷，并在分配大载荷前执行大小预算检查。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 单表来源声明。 |
| `options` | 读取选项。 |

返回：Reader 阶段结果。

结构：

- `options`: Dictionary，可包含 max_source_file_bytes 和 max_xlsx_file_bytes；负值表示不限制。
- `return`: Dictionary，包含 success、phase、source_path、format、payload_kind、text、size_bytes、error_code、error_kind、error 和 context。

<a id="member-gfconfigpipelinereaderstage-methods-get_stage_descriptor"></a>

### `get_stage_descriptor`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_stage_descriptor() -> Dictionary:
```

返回阶段实现的稳定描述，用于流水线诊断和编译指纹。

返回：阶段描述。

结构：

- `return`: Dictionary，包含 stage_id、implementation_version、input_contract、output_contract 和 supported_formats。
