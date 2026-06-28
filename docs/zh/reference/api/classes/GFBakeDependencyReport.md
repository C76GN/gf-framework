# GFBakeDependencyReport

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_bake_dependency_report.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`7.0.0`

编辑器烘焙依赖与失效报告。 用于编辑器工具、导入流程或项目构建脚本记录输入、输出、依赖项和失效原因。 它只生成结构化诊断报告，不执行烘焙、不规定项目目录，也不写入任何资源。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_CURRENT`](#member-gfbakedependencyreport-constants-status_current) | `const STATUS_CURRENT: StringName = &"current"` |
| 常量 | [`STATUS_STALE`](#member-gfbakedependencyreport-constants-status_stale) | `const STATUS_STALE: StringName = &"stale"` |
| 常量 | [`STATUS_MISSING`](#member-gfbakedependencyreport-constants-status_missing) | `const STATUS_MISSING: StringName = &"missing"` |
| 常量 | [`STATUS_FAILED`](#member-gfbakedependencyreport-constants-status_failed) | `const STATUS_FAILED: StringName = &"failed"` |
| 常量 | [`STATUS_UNKNOWN`](#member-gfbakedependencyreport-constants-status_unknown) | `const STATUS_UNKNOWN: StringName = &"unknown"` |
| 属性 | [`report_id`](#member-gfbakedependencyreport-properties-report_id) | `var report_id: StringName = &""` |
| 属性 | [`label`](#member-gfbakedependencyreport-properties-label) | `var label: String = ""` |
| 属性 | [`metadata`](#member-gfbakedependencyreport-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfbakedependencyreport-methods-configure) | `func configure( p_report_id: StringName, p_label: String = "", p_metadata: Dictionary = {} ) -> GFBakeDependencyReport:` |
| 方法 | [`add_input`](#member-gfbakedependencyreport-methods-add_input) | `func add_input(path: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`add_output`](#member-gfbakedependencyreport-methods-add_output) | `func add_output(path: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`add_dependency`](#member-gfbakedependencyreport-methods-add_dependency) | `func add_dependency(dependency_id: StringName, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`mark_stale`](#member-gfbakedependencyreport-methods-mark_stale) | `func mark_stale(reason: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`add_artifact_report`](#member-gfbakedependencyreport-methods-add_artifact_report) | `func add_artifact_report(report: Dictionary) -> void:` |
| 方法 | [`get_inputs`](#member-gfbakedependencyreport-methods-get_inputs) | `func get_inputs() -> Array[Dictionary]:` |
| 方法 | [`get_outputs`](#member-gfbakedependencyreport-methods-get_outputs) | `func get_outputs() -> Array[Dictionary]:` |
| 方法 | [`get_dependencies`](#member-gfbakedependencyreport-methods-get_dependencies) | `func get_dependencies() -> Array[Dictionary]:` |
| 方法 | [`get_invalidations`](#member-gfbakedependencyreport-methods-get_invalidations) | `func get_invalidations() -> Array[Dictionary]:` |
| 方法 | [`get_artifact_reports`](#member-gfbakedependencyreport-methods-get_artifact_reports) | `func get_artifact_reports() -> Array[Dictionary]:` |
| 方法 | [`clear`](#member-gfbakedependencyreport-methods-clear) | `func clear() -> void:` |
| 方法 | [`summarize`](#member-gfbakedependencyreport-methods-summarize) | `func summarize(options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfbakedependencyreport-constants-status_current"></a>

### `STATUS_CURRENT`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_CURRENT: StringName = &"current"
```

依赖当前有效。

<a id="member-gfbakedependencyreport-constants-status_stale"></a>

### `STATUS_STALE`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_STALE: StringName = &"stale"
```

依赖或输出需要重建。

<a id="member-gfbakedependencyreport-constants-status_missing"></a>

### `STATUS_MISSING`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_MISSING: StringName = &"missing"
```

必需输入或输出缺失。

<a id="member-gfbakedependencyreport-constants-status_failed"></a>

### `STATUS_FAILED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_FAILED: StringName = &"failed"
```

依赖分析或产物处理失败。

<a id="member-gfbakedependencyreport-constants-status_unknown"></a>

### `STATUS_UNKNOWN`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_UNKNOWN: StringName = &"unknown"
```

没有足够信息判断状态。

## 属性

<a id="member-gfbakedependencyreport-properties-report_id"></a>

### `report_id`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var report_id: StringName = &""
```

报告稳定标识。

<a id="member-gfbakedependencyreport-properties-label"></a>

### `label`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var label: String = ""
```

报告显示名称。

<a id="member-gfbakedependencyreport-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方元数据。

结构：

- `metadata`: Dictionary for caller-defined bake metadata.

## 方法

<a id="member-gfbakedependencyreport-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure( p_report_id: StringName, p_label: String = "", p_metadata: Dictionary = {} ) -> GFBakeDependencyReport:
```

配置报告。

参数：

| 名称 | 说明 |
|---|---|
| `p_report_id` | 报告稳定标识。 |
| `p_label` | 显示名称。 |
| `p_metadata` | 调用方元数据。 |

返回：当前报告。

结构：

- `p_metadata`: Dictionary copied into metadata.

<a id="member-gfbakedependencyreport-methods-add_input"></a>

### `add_input`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_input(path: String, options: Dictionary = {}) -> Dictionary:
```

添加一个输入资源或文件记录。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 输入路径或稳定资源标识。 |
| `options` | 输入选项，支持 dependency_id、exists、required、status、content_sha256、modified_time、check_filesystem 和 metadata。 |

返回：输入记录副本。

结构：

- `options`: Dictionary，可包含 dependency_id、exists、required、status、content_sha256、modified_time、check_filesystem 和 metadata。
- `return`: Dictionary，包含 path、dependency_id、exists、required、status、content_sha256、modified_time 和 metadata。

<a id="member-gfbakedependencyreport-methods-add_output"></a>

### `add_output`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_output(path: String, options: Dictionary = {}) -> Dictionary:
```

添加一个输出产物记录。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 输出路径或稳定产物标识。 |
| `options` | 输出选项，支持 dependency_id、exists、required、status、content_sha256、modified_time、check_filesystem 和 metadata。 |

返回：输出记录副本。

结构：

- `options`: Dictionary，可包含 dependency_id、exists、required、status、content_sha256、modified_time、check_filesystem 和 metadata。
- `return`: Dictionary，包含 path、dependency_id、exists、required、status、content_sha256、modified_time 和 metadata。

<a id="member-gfbakedependencyreport-methods-add_dependency"></a>

### `add_dependency`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_dependency(dependency_id: StringName, options: Dictionary = {}) -> Dictionary:
```

添加一个逻辑依赖项记录。

参数：

| 名称 | 说明 |
|---|---|
| `dependency_id` | 依赖稳定标识。 |
| `options` | 依赖选项，支持 status、version、content_sha256、error 和 metadata。 |

返回：依赖记录副本。

结构：

- `options`: Dictionary，可包含 status、version、content_sha256、error 和 metadata。
- `return`: Dictionary，包含 dependency_id、status、version、content_sha256、error 和 metadata。

<a id="member-gfbakedependencyreport-methods-mark_stale"></a>

### `mark_stale`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func mark_stale(reason: String, options: Dictionary = {}) -> Dictionary:
```

记录一个失效原因。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 失效原因。 |
| `options` | 失效选项，支持 path、dependency_id、severity 和 metadata。 |

返回：失效记录副本。

结构：

- `options`: Dictionary，可包含 path、dependency_id、severity 和 metadata。
- `return`: Dictionary，包含 reason、path、dependency_id、severity、timestamp_msec 和 metadata。

<a id="member-gfbakedependencyreport-methods-add_artifact_report"></a>

### `add_artifact_report`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_artifact_report(report: Dictionary) -> void:
```

添加生成产物报告。

参数：

| 名称 | 说明 |
|---|---|
| `report` | GFGeneratedArtifactReport 兼容报告。 |

结构：

- `report`: Dictionary，包含 status、path、error_code、dry_run 等字段。

<a id="member-gfbakedependencyreport-methods-get_inputs"></a>

### `get_inputs`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_inputs() -> Array[Dictionary]:
```

获取输入记录副本。

返回：输入记录数组。

结构：

- `return`: Array[Dictionary]，每个元素为 add_input() 返回结构。

<a id="member-gfbakedependencyreport-methods-get_outputs"></a>

### `get_outputs`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_outputs() -> Array[Dictionary]:
```

获取输出记录副本。

返回：输出记录数组。

结构：

- `return`: Array[Dictionary]，每个元素为 add_output() 返回结构。

<a id="member-gfbakedependencyreport-methods-get_dependencies"></a>

### `get_dependencies`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_dependencies() -> Array[Dictionary]:
```

获取依赖记录副本。

返回：依赖记录数组。

结构：

- `return`: Array[Dictionary]，每个元素为 add_dependency() 返回结构。

<a id="member-gfbakedependencyreport-methods-get_invalidations"></a>

### `get_invalidations`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_invalidations() -> Array[Dictionary]:
```

获取失效记录副本。

返回：失效记录数组。

结构：

- `return`: Array[Dictionary]，每个元素为 mark_stale() 返回结构。

<a id="member-gfbakedependencyreport-methods-get_artifact_reports"></a>

### `get_artifact_reports`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_artifact_reports() -> Array[Dictionary]:
```

获取生成产物报告副本。

返回：生成产物报告数组。

结构：

- `return`: Array[Dictionary]，每个元素为 GFGeneratedArtifactReport 兼容报告。

<a id="member-gfbakedependencyreport-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空输入、输出、依赖、失效和产物记录。

<a id="member-gfbakedependencyreport-methods-summarize"></a>

### `summarize`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func summarize(options: Dictionary = {}) -> Dictionary:
```

汇总烘焙依赖状态。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 汇总选项，支持 include_inputs、include_outputs、include_dependencies、include_invalidations、include_artifacts 和 metadata。 |

返回：烘焙依赖摘要。

结构：

- `options`: Dictionary，可包含 include_inputs、include_outputs、include_dependencies、include_invalidations、include_artifacts 和 metadata。
- `return`: Dictionary，包含 success、current、status、report_id、label、计数、缺失路径、失效记录、artifact_summary 和 metadata。
