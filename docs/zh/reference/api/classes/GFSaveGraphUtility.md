# GFSaveGraphUtility

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/graph/gf_save_graph_utility.gd`
- 模块：`Save`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用节点存档图编排工具。 负责遍历 GFSaveScope/GFSaveSource，采集、应用和落盘存档图。具体数据结构 由 Source、Serializer 或项目继承类决定，Utility 本身不绑定业务字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`FORMAT_ID`](#member-gfsavegraphutility-constants-format_id) | `const FORMAT_ID: String = "gf_save_graph"` |
| 常量 | [`FORMAT_VERSION`](#member-gfsavegraphutility-constants-format_version) | `const FORMAT_VERSION: int = 1` |
| 常量 | [`DOCUMENT_SCHEMA_ID`](#member-gfsavegraphutility-constants-document_schema_id) | `const DOCUMENT_SCHEMA_ID: StringName = &"gf.save_graph"` |
| 常量 | [`DOCUMENT_SCHEMA_VERSION`](#member-gfsavegraphutility-constants-document_schema_version) | `const DOCUMENT_SCHEMA_VERSION: int = 1` |
| 常量 | [`DOCUMENT_SECTION_ID`](#member-gfsavegraphutility-constants-document_section_id) | `const DOCUMENT_SECTION_ID: StringName = &"save_graph"` |
| 属性 | [`serializer_registry`](#member-gfsavegraphutility-properties-serializer_registry) | `var serializer_registry: GFNodeSerializerRegistry = GFNodeSerializerRegistry.new()` |
| 属性 | [`pipeline_steps`](#member-gfsavegraphutility-properties-pipeline_steps) | `var pipeline_steps: Array[GFSavePipelineStep] = []` |
| 方法 | [`ready`](#member-gfsavegraphutility-methods-ready) | `func ready() -> void:` |
| 方法 | [`set_clock`](#member-gfsavegraphutility-methods-set_clock) | `func set_clock(clock: GFClock) -> bool:` |
| 方法 | [`get_clock`](#member-gfsavegraphutility-methods-get_clock) | `func get_clock() -> GFClock:` |
| 方法 | [`register_entity_factory`](#member-gfsavegraphutility-methods-register_entity_factory) | `func register_entity_factory(factory: GFSaveEntityFactory) -> void:` |
| 方法 | [`unregister_entity_factory`](#member-gfsavegraphutility-methods-unregister_entity_factory) | `func unregister_entity_factory(type_key: StringName) -> void:` |
| 方法 | [`clear_entity_factories`](#member-gfsavegraphutility-methods-clear_entity_factories) | `func clear_entity_factories() -> void:` |
| 方法 | [`add_pipeline_step`](#member-gfsavegraphutility-methods-add_pipeline_step) | `func add_pipeline_step(step: GFSavePipelineStep) -> void:` |
| 方法 | [`remove_pipeline_step`](#member-gfsavegraphutility-methods-remove_pipeline_step) | `func remove_pipeline_step(step: GFSavePipelineStep) -> void:` |
| 方法 | [`clear_pipeline_steps`](#member-gfsavegraphutility-methods-clear_pipeline_steps) | `func clear_pipeline_steps() -> void:` |
| 方法 | [`create_pipeline_context`](#member-gfsavegraphutility-methods-create_pipeline_context) | `func create_pipeline_context( operation: StringName, scope: GFSaveScope = null, shared: Dictionary = {} ) -> GFSavePipelineContext:` |
| 方法 | [`create_document_schema`](#member-gfsavegraphutility-methods-create_document_schema) | `func create_document_schema() -> GFSaveDocumentSchema:` |
| 方法 | [`gather_section`](#member-gfsavegraphutility-methods-gather_section) | `func gather_section( scope: GFSaveScope, section_id: StringName = DOCUMENT_SECTION_ID, context: Dictionary = {} ) -> GFSaveSection:` |
| 方法 | [`apply_section`](#member-gfsavegraphutility-methods-apply_section) | `func apply_section( scope: GFSaveScope, section: GFSaveSection, context: Dictionary = {}, strict: bool = false ) -> Dictionary:` |
| 方法 | [`gather_document`](#member-gfsavegraphutility-methods-gather_document) | `func gather_document( scope: GFSaveScope, metadata: Dictionary = {}, context: Dictionary = {} ) -> GFSaveDocument:` |
| 方法 | [`apply_document`](#member-gfsavegraphutility-methods-apply_document) | `func apply_document( scope: GFSaveScope, document: GFSaveDocument, context: Dictionary = {}, strict: bool = false ) -> Dictionary:` |
| 方法 | [`inspect_scope`](#member-gfsavegraphutility-methods-inspect_scope) | `func inspect_scope(scope: GFSaveScope, context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`build_scope_health_report`](#member-gfsavegraphutility-methods-build_scope_health_report) | `func build_scope_health_report(scope: GFSaveScope, context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`validate_payload_for_scope`](#member-gfsavegraphutility-methods-validate_payload_for_scope) | `func validate_payload_for_scope(scope: GFSaveScope, payload: Dictionary, strict: bool = false) -> Dictionary:` |
| 方法 | [`build_payload_health_report`](#member-gfsavegraphutility-methods-build_payload_health_report) | `func build_payload_health_report(scope: GFSaveScope, payload: Dictionary, strict: bool = false) -> Dictionary:` |
| 方法 | [`gather_scope`](#member-gfsavegraphutility-methods-gather_scope) | `func gather_scope(scope: GFSaveScope, context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply_scope`](#member-gfsavegraphutility-methods-apply_scope) | `func apply_scope( scope: GFSaveScope, payload: Dictionary, context: Dictionary = {}, strict: bool = false ) -> Dictionary:` |
| 方法 | [`save_scope`](#member-gfsavegraphutility-methods-save_scope) | `func save_scope( file_name: String, scope: GFSaveScope, metadata: Dictionary = {}, context: Dictionary = {} ) -> Error:` |
| 方法 | [`load_scope`](#member-gfsavegraphutility-methods-load_scope) | `func load_scope( file_name: String, scope: GFSaveScope, context: Dictionary = {}, strict: bool = false ) -> Dictionary:` |

## 常量

<a id="member-gfsavegraphutility-constants-format_id"></a>

### `FORMAT_ID`

- API：`public`

```gdscript
const FORMAT_ID: String = "gf_save_graph"
```

存档图载荷格式标识。

<a id="member-gfsavegraphutility-constants-format_version"></a>

### `FORMAT_VERSION`

- API：`public`

```gdscript
const FORMAT_VERSION: int = 1
```

当前存档图载荷格式版本。

<a id="member-gfsavegraphutility-constants-document_schema_id"></a>

### `DOCUMENT_SCHEMA_ID`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const DOCUMENT_SCHEMA_ID: StringName = &"gf.save_graph"
```

独立 SaveGraph 文档使用的 schema ID。

<a id="member-gfsavegraphutility-constants-document_schema_version"></a>

### `DOCUMENT_SCHEMA_VERSION`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const DOCUMENT_SCHEMA_VERSION: int = 1
```

独立 SaveGraph 文档的当前 schema 版本。

<a id="member-gfsavegraphutility-constants-document_section_id"></a>

### `DOCUMENT_SECTION_ID`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const DOCUMENT_SECTION_ID: StringName = &"save_graph"
```

SaveGraph 在版本化文档中的默认分区 ID。

## 属性

<a id="member-gfsavegraphutility-properties-serializer_registry"></a>

### `serializer_registry`

- API：`public`

```gdscript
var serializer_registry: GFNodeSerializerRegistry = GFNodeSerializerRegistry.new()
```

节点序列化器注册表。

<a id="member-gfsavegraphutility-properties-pipeline_steps"></a>

### `pipeline_steps`

- API：`public`

```gdscript
var pipeline_steps: Array[GFSavePipelineStep] = []
```

存档图流程步骤。按数组顺序执行，适合压缩前校验、调试标记、版本适配等通用处理。

## 方法

<a id="member-gfsavegraphutility-methods-ready"></a>

### `ready`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func ready() -> void:
```

在架构中自动采用已注册 GFTimeProvider 的底层时钟。 构造函数或 `set_clock()` 的显式注入不会被自动覆盖。

<a id="member-gfsavegraphutility-methods-set_clock"></a>

### `set_clock`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func set_clock(clock: GFClock) -> bool:
```

设置存档流水线诊断使用的单调时钟。

参数：

| 名称 | 说明 |
|---|---|
| `clock` | 新单调时钟。 |

返回：时钟合法并完成设置时返回 true。

<a id="member-gfsavegraphutility-methods-get_clock"></a>

### `get_clock`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_clock() -> GFClock:
```

获取存档流水线诊断使用的时钟。

返回：当前时钟。

<a id="member-gfsavegraphutility-methods-register_entity_factory"></a>

### `register_entity_factory`

- API：`public`

```gdscript
func register_entity_factory(factory: GFSaveEntityFactory) -> void:
```

注册实体工厂。

参数：

| 名称 | 说明 |
|---|---|
| `factory` | 实体工厂。 |

<a id="member-gfsavegraphutility-methods-unregister_entity_factory"></a>

### `unregister_entity_factory`

- API：`public`

```gdscript
func unregister_entity_factory(type_key: StringName) -> void:
```

注销实体工厂。

参数：

| 名称 | 说明 |
|---|---|
| `type_key` | 实体类型键。 |

<a id="member-gfsavegraphutility-methods-clear_entity_factories"></a>

### `clear_entity_factories`

- API：`public`

```gdscript
func clear_entity_factories() -> void:
```

清空实体工厂。

<a id="member-gfsavegraphutility-methods-add_pipeline_step"></a>

### `add_pipeline_step`

- API：`public`

```gdscript
func add_pipeline_step(step: GFSavePipelineStep) -> void:
```

添加存档流程步骤。

参数：

| 名称 | 说明 |
|---|---|
| `step` | 流程步骤。 |

<a id="member-gfsavegraphutility-methods-remove_pipeline_step"></a>

### `remove_pipeline_step`

- API：`public`

```gdscript
func remove_pipeline_step(step: GFSavePipelineStep) -> void:
```

移除存档流程步骤。

参数：

| 名称 | 说明 |
|---|---|
| `step` | 流程步骤。 |

<a id="member-gfsavegraphutility-methods-clear_pipeline_steps"></a>

### `clear_pipeline_steps`

- API：`public`

```gdscript
func clear_pipeline_steps() -> void:
```

清空存档流程步骤。

<a id="member-gfsavegraphutility-methods-create_pipeline_context"></a>

### `create_pipeline_context`

- API：`public`

```gdscript
func create_pipeline_context( operation: StringName, scope: GFSaveScope = null, shared: Dictionary = {} ) -> GFSavePipelineContext:
```

创建存档流程上下文。

参数：

| 名称 | 说明 |
|---|---|
| `operation` | 操作类型。 |
| `scope` | 可选根 Scope。 |
| `shared` | 初始共享数据。 |

返回：新上下文。

结构：

- `shared`: Dictionary，流程共享数据，可由步骤写入调试标记、迁移状态或项目自定义键。

<a id="member-gfsavegraphutility-methods-create_document_schema"></a>

### `create_document_schema`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func create_document_schema() -> GFSaveDocumentSchema:
```

创建独立 SaveGraph 文档的当前 schema。

返回：要求默认 SaveGraph 分区的 schema。

<a id="member-gfsavegraphutility-methods-gather_section"></a>

### `gather_section`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func gather_section( scope: GFSaveScope, section_id: StringName = DOCUMENT_SECTION_ID, context: Dictionary = {} ) -> GFSaveSection:
```

把 Scope 图采集为可组合版本化分区。

参数：

| 名称 | 说明 |
|---|---|
| `scope` | 根 Scope。 |
| `section_id` | 项目文档中的分区 ID。 |
| `context` | 调用上下文字典。 |

返回：分区；采集失败时返回 null。

结构：

- `context`: Dictionary accepted by gather_scope().

<a id="member-gfsavegraphutility-methods-apply_section"></a>

### `apply_section`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func apply_section( scope: GFSaveScope, section: GFSaveSection, context: Dictionary = {}, strict: bool = false ) -> Dictionary:
```

应用可组合 SaveGraph 分区。

参数：

| 名称 | 说明 |
|---|---|
| `scope` | 根 Scope。 |
| `section` | SaveGraph 分区。 |
| `context` | 调用上下文字典。 |
| `strict` | 为 true 时缺失 Source/Scope 会记录错误。 |

返回：apply_scope() 结果。

结构：

- `context`: Dictionary accepted by apply_scope().
- `return`: Dictionary with ok, applied, errors, missing, and optional pipeline_trace.

<a id="member-gfsavegraphutility-methods-gather_document"></a>

### `gather_document`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func gather_document( scope: GFSaveScope, metadata: Dictionary = {}, context: Dictionary = {} ) -> GFSaveDocument:
```

采集独立 SaveGraph 文档。

参数：

| 名称 | 说明 |
|---|---|
| `scope` | 根 Scope。 |
| `metadata` | 可持久化文档元数据。 |
| `context` | 调用上下文字典。 |

返回：独立文档；采集失败时返回 null。

结构：

- `metadata`: Dictionary with project-defined persisted metadata.
- `context`: Dictionary accepted by gather_scope().

<a id="member-gfsavegraphutility-methods-apply_document"></a>

### `apply_document`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func apply_document( scope: GFSaveScope, document: GFSaveDocument, context: Dictionary = {}, strict: bool = false ) -> Dictionary:
```

应用独立 SaveGraph 文档。

参数：

| 名称 | 说明 |
|---|---|
| `scope` | 根 Scope。 |
| `document` | 独立 SaveGraph 文档。 |
| `context` | 调用上下文字典。 |
| `strict` | 为 true 时缺失 Source/Scope 会记录错误。 |

返回：apply_section() 结果。

结构：

- `context`: Dictionary accepted by apply_scope().
- `return`: Dictionary with ok, applied, errors, missing, and optional pipeline_trace.

<a id="member-gfsavegraphutility-methods-inspect_scope"></a>

### `inspect_scope`

- API：`public`

```gdscript
func inspect_scope(scope: GFSaveScope, context: Dictionary = {}) -> Dictionary:
```

检查 Scope 树的可保存结构。

参数：

| 名称 | 说明 |
|---|---|
| `scope` | 根 Scope。 |
| `context` | 调用上下文字典。 |

返回：诊断报告。

结构：

- `context`: Dictionary，可包含诊断调用方自定义键，不会被 Utility 写入私有状态。
- `return`: Dictionary，包含 ok、healthy、scope_key、计数字段、issue_counts_by_kind、summary、next_action、scopes、sources 与 issues。

<a id="member-gfsavegraphutility-methods-build_scope_health_report"></a>

### `build_scope_health_report`

- API：`public`

```gdscript
func build_scope_health_report(scope: GFSaveScope, context: Dictionary = {}) -> Dictionary:
```

构建 Scope 健康报告。

参数：

| 名称 | 说明 |
|---|---|
| `scope` | 根 Scope。 |
| `context` | 调用上下文字典。 |

返回：含 summary、next_action 与 issue 统计的诊断报告。

结构：

- `context`: Dictionary，可包含诊断调用方自定义键，不会被 Utility 写入私有状态。
- `return`: Dictionary，结构与 inspect_scope 的返回诊断报告一致。

<a id="member-gfsavegraphutility-methods-validate_payload_for_scope"></a>

### `validate_payload_for_scope`

- API：`public`

```gdscript
func validate_payload_for_scope(scope: GFSaveScope, payload: Dictionary, strict: bool = false) -> Dictionary:
```

校验载荷是否能匹配当前 Scope 树。

参数：

| 名称 | 说明 |
|---|---|
| `scope` | 根 Scope。 |
| `payload` | 待校验载荷。 |
| `strict` | 为 true 时把缺失 Source/Scope 视为错误；否则视为警告。 |

返回：诊断报告。

结构：

- `payload`: Dictionary，存档图载荷，包含 format、format_version、scope、sources、scopes，可选 metadata 与 pipeline_trace。
- `return`: Dictionary，包含 ok、healthy、scope_key、checked_source_count、checked_scope_count、missing、issues、summary 与 next_action。

<a id="member-gfsavegraphutility-methods-build_payload_health_report"></a>

### `build_payload_health_report`

- API：`public`

```gdscript
func build_payload_health_report(scope: GFSaveScope, payload: Dictionary, strict: bool = false) -> Dictionary:
```

构建载荷匹配健康报告。

参数：

| 名称 | 说明 |
|---|---|
| `scope` | 根 Scope。 |
| `payload` | 待校验载荷。 |
| `strict` | 为 true 时把缺失 Source/Scope 视为错误；否则视为警告。 |

返回：含 summary、next_action 与 issue 统计的诊断报告。

结构：

- `payload`: Dictionary，存档图载荷，包含 format、format_version、scope、sources、scopes，可选 metadata 与 pipeline_trace。
- `return`: Dictionary，结构与 validate_payload_for_scope 的返回诊断报告一致。

<a id="member-gfsavegraphutility-methods-gather_scope"></a>

### `gather_scope`

- API：`public`

```gdscript
func gather_scope(scope: GFSaveScope, context: Dictionary = {}) -> Dictionary:
```

采集 Scope 存档图。

参数：

| 名称 | 说明 |
|---|---|
| `scope` | 根 Scope。 |
| `context` | 调用上下文字典。 |

返回：存档载荷。

结构：

- `context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
- `return`: Dictionary，存档图载荷，包含 format、format_version、scope、sources、scopes，可选 metadata 与 pipeline_trace。

<a id="member-gfsavegraphutility-methods-apply_scope"></a>

### `apply_scope`

- API：`public`

```gdscript
func apply_scope( scope: GFSaveScope, payload: Dictionary, context: Dictionary = {}, strict: bool = false ) -> Dictionary:
```

应用 Scope 存档图。

参数：

| 名称 | 说明 |
|---|---|
| `scope` | 根 Scope。 |
| `payload` | 存档载荷。 |
| `context` | 调用上下文字典。 |
| `strict` | 为 true 时缺失 Source/Scope 会记录错误。 |

返回：结果字典。

结构：

- `payload`: Dictionary，存档图载荷，包含 format、format_version、scope、sources、scopes，可选 metadata 与 pipeline_trace。
- `context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
- `return`: Dictionary，包含 ok、applied、errors、missing，可选 pipeline_trace。

<a id="member-gfsavegraphutility-methods-save_scope"></a>

### `save_scope`

- API：`public`

```gdscript
func save_scope( file_name: String, scope: GFSaveScope, metadata: Dictionary = {}, context: Dictionary = {} ) -> Error:
```

采集并保存 Scope。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 目标文件名。 |
| `scope` | 根 Scope。 |
| `metadata` | 附加元信息。 |
| `context` | 调用上下文字典。 |

返回：Godot 错误码。

结构：

- `metadata`: Dictionary，写入载荷 metadata 字段的项目元信息。
- `context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 及项目自定义键。

<a id="member-gfsavegraphutility-methods-load_scope"></a>

### `load_scope`

- API：`public`

```gdscript
func load_scope( file_name: String, scope: GFSaveScope, context: Dictionary = {}, strict: bool = false ) -> Dictionary:
```

从文件读取并应用 Scope。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 目标文件名。 |
| `scope` | 根 Scope。 |
| `context` | 调用上下文字典。 |
| `strict` | 为 true 时缺失 Source/Scope 会记录错误。 |

返回：结果字典。

结构：

- `context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
- `return`: Dictionary，包含 ok、applied、errors、missing，可选 pipeline_trace。
