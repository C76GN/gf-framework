# GFSupportReportUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_support_report_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用支持报告构建工具。 聚合用户描述、项目元数据、诊断快照、日志和可扩展分区，并提供 JSON / Markdown 导出与回调提交入口。 它不绑定任何工单系统、上传服务或反馈 UI。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`report_built`](#member-gfsupportreportutility-signals-report_built) | `signal report_built(report: Dictionary)` |
| 信号 | [`report_saved`](#member-gfsupportreportutility-signals-report_saved) | `signal report_saved(path: String, error: Error)` |
| 信号 | [`report_submitted`](#member-gfsupportreportutility-signals-report_submitted) | `signal report_submitted(result: Dictionary)` |
| 枚举 | [`RuntimeDetail`](#member-gfsupportreportutility-enums-runtimedetail) | `enum RuntimeDetail` |
| 常量 | [`DEFAULT_SCENE_COUNT_MAX_DEPTH`](#member-gfsupportreportutility-constants-default_scene_count_max_depth) | `const DEFAULT_SCENE_COUNT_MAX_DEPTH: int = 64` |
| 常量 | [`DEFAULT_SCENE_COUNT_MAX_NODES`](#member-gfsupportreportutility-constants-default_scene_count_max_nodes) | `const DEFAULT_SCENE_COUNT_MAX_NODES: int = 10000` |
| 属性 | [`include_diagnostics_by_default`](#member-gfsupportreportutility-properties-include_diagnostics_by_default) | `var include_diagnostics_by_default: bool = false` |
| 属性 | [`include_scene_by_default`](#member-gfsupportreportutility-properties-include_scene_by_default) | `var include_scene_by_default: bool = false` |
| 属性 | [`include_runtime_by_default`](#member-gfsupportreportutility-properties-include_runtime_by_default) | `var include_runtime_by_default: bool = true` |
| 属性 | [`runtime_detail_by_default`](#member-gfsupportreportutility-properties-runtime_detail_by_default) | `var runtime_detail_by_default: RuntimeDetail = RuntimeDetail.MINIMAL` |
| 属性 | [`include_sections_by_default`](#member-gfsupportreportutility-properties-include_sections_by_default) | `var include_sections_by_default: bool = false` |
| 属性 | [`default_scene_count_max_depth`](#member-gfsupportreportutility-properties-default_scene_count_max_depth) | `var default_scene_count_max_depth: int = DEFAULT_SCENE_COUNT_MAX_DEPTH` |
| 属性 | [`default_scene_count_max_nodes`](#member-gfsupportreportutility-properties-default_scene_count_max_nodes) | `var default_scene_count_max_nodes: int = DEFAULT_SCENE_COUNT_MAX_NODES` |
| 属性 | [`default_recent_log_count`](#member-gfsupportreportutility-properties-default_recent_log_count) | `var default_recent_log_count: int = 50` |
| 属性 | [`default_max_attachment_bytes`](#member-gfsupportreportutility-properties-default_max_attachment_bytes) | `var default_max_attachment_bytes: int = 2 * 1024 * 1024` |
| 属性 | [`include_screenshot_by_default`](#member-gfsupportreportutility-properties-include_screenshot_by_default) | `var include_screenshot_by_default: bool = false` |
| 方法 | [`dispose`](#member-gfsupportreportutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`register_section`](#member-gfsupportreportutility-methods-register_section) | `func register_section(section_id: StringName, provider: Callable, options: Dictionary = {}) -> bool:` |
| 方法 | [`unregister_section`](#member-gfsupportreportutility-methods-unregister_section) | `func unregister_section(section_id: StringName) -> void:` |
| 方法 | [`has_section`](#member-gfsupportreportutility-methods-has_section) | `func has_section(section_id: StringName) -> bool:` |
| 方法 | [`get_section_catalog`](#member-gfsupportreportutility-methods-get_section_catalog) | `func get_section_catalog() -> Dictionary:` |
| 方法 | [`build_report`](#member-gfsupportreportutility-methods-build_report) | `func build_report(description: String = "", options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`collect_runtime_snapshot`](#member-gfsupportreportutility-methods-collect_runtime_snapshot) | `func collect_runtime_snapshot(detail: RuntimeDetail = RuntimeDetail.MINIMAL) -> Dictionary:` |
| 方法 | [`collect_sections`](#member-gfsupportreportutility-methods-collect_sections) | `func collect_sections(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`collect_attachments`](#member-gfsupportreportutility-methods-collect_attachments) | `func collect_attachments(attachments: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`add_attachment_to_report`](#member-gfsupportreportutility-methods-add_attachment_to_report) | `func add_attachment_to_report( report: Dictionary, attachment_id: StringName, content: Variant, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`export_report_json`](#member-gfsupportreportutility-methods-export_report_json) | `func export_report_json(report: Dictionary, indent: String = "\t") -> String:` |
| 方法 | [`export_report_markdown`](#member-gfsupportreportutility-methods-export_report_markdown) | `func export_report_markdown(report: Dictionary, options: Dictionary = {}) -> String:` |
| 方法 | [`save_report`](#member-gfsupportreportutility-methods-save_report) | `func save_report(report: Dictionary, path: String) -> Error:` |
| 方法 | [`build_and_save_report`](#member-gfsupportreportutility-methods-build_and_save_report) | `func build_and_save_report(path: String, description: String = "", options: Dictionary = {}) -> Error:` |
| 方法 | [`submit_report`](#member-gfsupportreportutility-methods-submit_report) | `func submit_report(report: Dictionary, transport: Callable, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfsupportreportutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfsupportreportutility-signals-report_built"></a>

### `report_built`

- API：`public`

```gdscript
signal report_built(report: Dictionary)
```

报告构建完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 已构建的支持报告。 |

结构：

- `report`: Dictionary，build_report() 返回结构。

<a id="member-gfsupportreportutility-signals-report_saved"></a>

### `report_saved`

- API：`public`

```gdscript
signal report_saved(path: String, error: Error)
```

报告写入文件后发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标路径。 |
| `error` | 写入结果错误码。 |

<a id="member-gfsupportreportutility-signals-report_submitted"></a>

### `report_submitted`

- API：`public`

```gdscript
signal report_submitted(result: Dictionary)
```

报告通过外部回调提交后发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 提交结果。 |

结构：

- `result`: Dictionary，包含 ok、value、error、metadata，可选 submitted_at_unix。

## 枚举

<a id="member-gfsupportreportutility-enums-runtimedetail"></a>

### `RuntimeDetail`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
enum RuntimeDetail {
	## 只保留平台等非精确排查信息。
	MINIMAL,
	## 额外保留语言和运行时计数的分桶范围。
	COARSE,
	## 保留完整 locale 与精确运行时计数。
	FULL,
}
```

运行时快照的数据精度。

## 常量

<a id="member-gfsupportreportutility-constants-default_scene_count_max_depth"></a>

### `DEFAULT_SCENE_COUNT_MAX_DEPTH`

- API：`public`

```gdscript
const DEFAULT_SCENE_COUNT_MAX_DEPTH: int = 64
```

场景节点统计默认最大深度。

<a id="member-gfsupportreportutility-constants-default_scene_count_max_nodes"></a>

### `DEFAULT_SCENE_COUNT_MAX_NODES`

- API：`public`

```gdscript
const DEFAULT_SCENE_COUNT_MAX_NODES: int = 10000
```

场景节点统计默认最大节点数。

## 属性

<a id="member-gfsupportreportutility-properties-include_diagnostics_by_default"></a>

### `include_diagnostics_by_default`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var include_diagnostics_by_default: bool = false
```

默认是否包含 GFDiagnosticsUtility 快照。

<a id="member-gfsupportreportutility-properties-include_scene_by_default"></a>

### `include_scene_by_default`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var include_scene_by_default: bool = false
```

默认是否包含场景快照。

<a id="member-gfsupportreportutility-properties-include_runtime_by_default"></a>

### `include_runtime_by_default`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var include_runtime_by_default: bool = true
```

默认是否包含运行时快照。

<a id="member-gfsupportreportutility-properties-runtime_detail_by_default"></a>

### `runtime_detail_by_default`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var runtime_detail_by_default: RuntimeDetail = RuntimeDetail.MINIMAL
```

默认运行时快照精度。

<a id="member-gfsupportreportutility-properties-include_sections_by_default"></a>

### `include_sections_by_default`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var include_sections_by_default: bool = false
```

默认是否采集已注册的自定义分区。

<a id="member-gfsupportreportutility-properties-default_scene_count_max_depth"></a>

### `default_scene_count_max_depth`

- API：`public`

```gdscript
var default_scene_count_max_depth: int = DEFAULT_SCENE_COUNT_MAX_DEPTH
```

场景节点数量统计默认最大深度。0 表示不限制。

<a id="member-gfsupportreportutility-properties-default_scene_count_max_nodes"></a>

### `default_scene_count_max_nodes`

- API：`public`

```gdscript
var default_scene_count_max_nodes: int = DEFAULT_SCENE_COUNT_MAX_NODES
```

场景节点数量统计默认最大节点数。0 表示不限制。

<a id="member-gfsupportreportutility-properties-default_recent_log_count"></a>

### `default_recent_log_count`

- API：`public`

```gdscript
var default_recent_log_count: int = 50
```

默认最近日志数量。

<a id="member-gfsupportreportutility-properties-default_max_attachment_bytes"></a>

### `default_max_attachment_bytes`

- API：`public`

```gdscript
var default_max_attachment_bytes: int = 2 * 1024 * 1024
```

默认单个附件最大字节数。小于等于 0 表示不限制。

<a id="member-gfsupportreportutility-properties-include_screenshot_by_default"></a>

### `include_screenshot_by_default`

- API：`public`

```gdscript
var include_screenshot_by_default: bool = false
```

默认是否包含当前 Viewport 截图。

## 方法

<a id="member-gfsupportreportutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放支持报告工具的运行时状态。

<a id="member-gfsupportreportutility-methods-register_section"></a>

### `register_section`

- API：`public`

```gdscript
func register_section(section_id: StringName, provider: Callable, options: Dictionary = {}) -> bool:
```

注册自定义报告分区。

参数：

| 名称 | 说明 |
|---|---|
| `section_id` | 分区标识。 |
| `provider` | 分区回调，建议签名为 func(options: Dictionary) -> Variant。 |
| `options` | 分区元数据，支持 label、metadata。 |

返回：注册成功返回 true。

结构：

- `options`: Dictionary，支持 label、metadata。

<a id="member-gfsupportreportutility-methods-unregister_section"></a>

### `unregister_section`

- API：`public`

```gdscript
func unregister_section(section_id: StringName) -> void:
```

注销自定义报告分区。

参数：

| 名称 | 说明 |
|---|---|
| `section_id` | 分区标识。 |

<a id="member-gfsupportreportutility-methods-has_section"></a>

### `has_section`

- API：`public`

```gdscript
func has_section(section_id: StringName) -> bool:
```

检查自定义分区是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `section_id` | 分区标识。 |

返回：存在返回 true。

<a id="member-gfsupportreportutility-methods-get_section_catalog"></a>

### `get_section_catalog`

- API：`public`

```gdscript
func get_section_catalog() -> Dictionary:
```

获取自定义分区目录。

返回：分区元数据字典。

结构：

- `return`: Dictionary[StringName, Dictionary]，每个值包含 label 和 metadata。

<a id="member-gfsupportreportutility-methods-build_report"></a>

### `build_report`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func build_report(description: String = "", options: Dictionary = {}) -> Dictionary:
```

构建支持报告。

参数：

| 名称 | 说明 |
|---|---|
| `description` | 用户描述或问题摘要。 |
| `options` | 可选参数，支持 metadata、tags、include_runtime、runtime_detail、include_diagnostics、diagnostics_options、include_scene、scene_options、include_sections、section_options、attachments、max_attachment_bytes、include_screenshot、viewport、screenshot_path。 |

返回：报告字典。

结构：

- `options`: Dictionary，支持 report_id、metadata、tags、include_runtime、runtime_detail、include_diagnostics、diagnostics_options、include_scene、scene_options、include_sections、section_options、attachments、max_attachment_bytes、include_screenshot、viewport、screenshot_path。
- `return`: Dictionary，包含 report_id、timestamp_unix、description、metadata、tags、build、runtime、scene、diagnostics、sections、attachments。

<a id="member-gfsupportreportutility-methods-collect_runtime_snapshot"></a>

### `collect_runtime_snapshot`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func collect_runtime_snapshot(detail: RuntimeDetail = RuntimeDetail.MINIMAL) -> Dictionary:
```

采集指定精度的运行时快照。 默认只返回平台；coarse 使用不可逆分桶，full 才返回精确 locale、处理器、内存和对象计数。

参数：

| 名称 | 说明 |
|---|---|
| `detail` | 运行时快照精度。 |

返回：运行时快照。

结构：

- `return`: Dictionary，始终包含 detail、platform；coarse 额外包含 locale_language、processor_count_range、static_memory_mib_range、object_count_range；full 额外包含 engine、locale、processor_count、static_memory_bytes、object_count。

<a id="member-gfsupportreportutility-methods-collect_sections"></a>

### `collect_sections`

- API：`public`

```gdscript
func collect_sections(options: Dictionary = {}) -> Dictionary:
```

采集所有自定义分区。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 传给每个 provider 的选项。 |

返回：分区结果字典。

结构：

- `options`: Dictionary，原样传给各分区 provider。
- `return`: Dictionary[StringName, Dictionary]，每个值包含 label、metadata、value、ok、error。

<a id="member-gfsupportreportutility-methods-collect_attachments"></a>

### `collect_attachments`

- API：`public`

```gdscript
func collect_attachments(attachments: Variant, options: Dictionary = {}) -> Dictionary:
```

采集并规范化报告附件。

参数：

| 名称 | 说明 |
|---|---|
| `attachments` | 附件集合。Dictionary 使用键作为附件标识；Array 中的 Dictionary 可提供 id 或 attachment_id。 |
| `options` | 可选参数，支持 max_attachment_bytes。 |

返回：附件字典。

结构：

- `attachments`: Variant，支持 Dictionary[StringName, Variant] 或 Array[Dictionary]。
- `options`: Dictionary，支持 filename、mime_type、metadata、max_attachment_bytes、save_path。
- `return`: Dictionary[StringName, Dictionary]，每个值为规范化附件条目。

<a id="member-gfsupportreportutility-methods-add_attachment_to_report"></a>

### `add_attachment_to_report`

- API：`public`

```gdscript
func add_attachment_to_report( report: Dictionary, attachment_id: StringName, content: Variant, options: Dictionary = {} ) -> Dictionary:
```

向已有报告追加附件。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 报告字典。 |
| `attachment_id` | 附件标识。 |
| `content` | 附件内容，可为 PackedByteArray、String 或带 bytes/text/path 字段的 Dictionary。 |
| `options` | 可选参数，支持 filename、mime_type、metadata、max_attachment_bytes、save_path。 |

返回：规范化附件结果。

结构：

- `report`: Dictionary，build_report() 返回结构或带 attachments 字段的兼容结构。
- `content`: Variant，支持 PackedByteArray、String 或包含 bytes、text、path 字段的 Dictionary。
- `options`: Dictionary，支持 filename、mime_type、metadata、max_attachment_bytes、save_path。
- `return`: Dictionary，包含 ok、filename、mime_type、size_bytes、encoding、data、metadata，失败时包含 reason。

<a id="member-gfsupportreportutility-methods-export_report_json"></a>

### `export_report_json`

- API：`public`

```gdscript
func export_report_json(report: Dictionary, indent: String = "\t") -> String:
```

将报告导出为 JSON 文本。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 报告字典。 |
| `indent` | JSON 缩进字符串。 |

返回：JSON 文本。

结构：

- `report`: Dictionary，build_report() 返回结构。

<a id="member-gfsupportreportutility-methods-export_report_markdown"></a>

### `export_report_markdown`

- API：`public`

```gdscript
func export_report_markdown(report: Dictionary, options: Dictionary = {}) -> String:
```

将报告导出为 Markdown 文本。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 报告字典。 |
| `options` | 可选参数，支持 title、include_metadata、include_diagnostics_summary、include_sections、include_attachments。 |

返回：Markdown 文本。

结构：

- `report`: Dictionary，build_report() 返回结构。
- `options`: Dictionary，支持 title、include_metadata、include_diagnostics_summary、include_sections、include_attachments。

<a id="member-gfsupportreportutility-methods-save_report"></a>

### `save_report`

- API：`public`

```gdscript
func save_report(report: Dictionary, path: String) -> Error:
```

保存报告到文件。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 报告字典。 |
| `path` | 目标路径。 |

返回：Godot 错误码。

结构：

- `report`: Dictionary，build_report() 返回结构。

<a id="member-gfsupportreportutility-methods-build_and_save_report"></a>

### `build_and_save_report`

- API：`public`

```gdscript
func build_and_save_report(path: String, description: String = "", options: Dictionary = {}) -> Error:
```

构建并保存支持报告。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 目标路径。 |
| `description` | 用户描述或问题摘要。 |
| `options` | 构建选项。 |

返回：Godot 错误码。

结构：

- `options`: Dictionary，build_report() 支持的构建选项。

<a id="member-gfsupportreportutility-methods-submit_report"></a>

### `submit_report`

- API：`public`

```gdscript
func submit_report(report: Dictionary, transport: Callable, options: Dictionary = {}) -> Dictionary:
```

通过外部回调提交报告。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 报告字典。 |
| `transport` | 提交回调，签名为 func(report: Dictionary, options: Dictionary) -> Variant。 |
| `options` | 提交选项。 |

返回：提交结果字典。

结构：

- `report`: Dictionary，build_report() 返回结构。
- `options`: Dictionary，提交回调使用的选项。
- `return`: Dictionary，包含 ok、value、error、metadata，可选 submitted_at_unix。

<a id="member-gfsupportreportutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary，包含 section_count、reports_built_count、reports_saved_count、reports_submitted_count 和默认配置字段。
