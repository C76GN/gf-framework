# GFArtifactFreshnessReport

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/policy/gf_artifact_freshness_report.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

通用 artifact 新鲜度与完整性报告。 检查本地 artifact 是否存在、可读、大小和 sha256 是否符合期望，以及生成时记录的 source digest 是否仍匹配当前 source digest。它只读取本地文件元数据，不解析业务内容。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`subject`](#member-gfartifactfreshnessreport-properties-subject) | `var subject: String = _DEFAULT_SUBJECT` |
| 属性 | [`artifacts`](#member-gfartifactfreshnessreport-properties-artifacts) | `var artifacts: Array[Dictionary] = []` |
| 属性 | [`metadata`](#member-gfartifactfreshnessreport-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfartifactfreshnessreport-methods-configure) | `func configure(p_subject: String = _DEFAULT_SUBJECT, p_metadata: Dictionary = {}) -> GFArtifactFreshnessReport:` |
| 方法 | [`clear`](#member-gfartifactfreshnessreport-methods-clear) | `func clear() -> void:` |
| 方法 | [`add_artifact`](#member-gfartifactfreshnessreport-methods-add_artifact) | `func add_artifact(artifact_id: StringName, path: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`add_artifacts`](#member-gfartifactfreshnessreport-methods-add_artifacts) | `func add_artifacts(entries: Array[Dictionary]) -> GFArtifactFreshnessReport:` |
| 方法 | [`get_report`](#member-gfartifactfreshnessreport-methods-get_report) | `func get_report(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`from_artifacts`](#member-gfartifactfreshnessreport-methods-from_artifacts) | `static func from_artifacts(entries: Array[Dictionary], options: Dictionary = {}) -> GFArtifactFreshnessReport:` |

## 属性

<a id="member-gfartifactfreshnessreport-properties-subject"></a>

### `subject`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var subject: String = _DEFAULT_SUBJECT
```

报告主题。

<a id="member-gfartifactfreshnessreport-properties-artifacts"></a>

### `artifacts`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var artifacts: Array[Dictionary] = []
```

artifact 条目列表。

结构：

- `artifacts`: Array[Dictionary]，每项包含 artifact_id/id、path、expected_sha256、expected_size_bytes、recorded_source_digest、current_source_digest 和 metadata。

<a id="member-gfartifactfreshnessreport-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义元数据。

结构：

- `metadata`: Dictionary caller-defined report metadata.

## 方法

<a id="member-gfartifactfreshnessreport-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure(p_subject: String = _DEFAULT_SUBJECT, p_metadata: Dictionary = {}) -> GFArtifactFreshnessReport:
```

配置报告构建器。

参数：

| 名称 | 说明 |
|---|---|
| `p_subject` | 报告主题。 |
| `p_metadata` | 调用方元数据。 |

返回：当前构建器。

结构：

- `p_metadata`: Dictionary caller-defined report metadata.

<a id="member-gfartifactfreshnessreport-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空 artifact 条目与元数据。

<a id="member-gfartifactfreshnessreport-methods-add_artifact"></a>

### `add_artifact`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_artifact(artifact_id: StringName, path: String, options: Dictionary = {}) -> Dictionary:
```

添加 artifact 条目。

参数：

| 名称 | 说明 |
|---|---|
| `artifact_id` | artifact ID。 |
| `path` | 本地文件路径。 |
| `options` | 附加字段，支持 expected_sha256、expected_size_bytes、minimum_modified_time、recorded_source_digest、current_source_digest、required 和 metadata。 |

返回：添加后的条目副本。

结构：

- `options`: Dictionary artifact freshness metadata.
- `return`: Dictionary artifact entry.

<a id="member-gfartifactfreshnessreport-methods-add_artifacts"></a>

### `add_artifacts`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_artifacts(entries: Array[Dictionary]) -> GFArtifactFreshnessReport:
```

批量添加 artifact 条目。

参数：

| 名称 | 说明 |
|---|---|
| `entries` | artifact 条目数组。 |

返回：当前构建器。

结构：

- `entries`: Array[Dictionary] artifact entries.

<a id="member-gfartifactfreshnessreport-methods-get_report"></a>

### `get_report`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_report(options: Dictionary = {}) -> Dictionary:
```

构建新鲜度报告。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 报告选项，支持 include_sha256、include_modified_time、warnings_as_errors、fallback_action 和 no_action。 |

返回：GFValidationReportDictionary 兼容报告。

结构：

- `options`: Dictionary report options.
- `return`: Dictionary with ok, healthy, artifacts, issues, summary, and next_action.

<a id="member-gfartifactfreshnessreport-methods-from_artifacts"></a>

### `from_artifacts`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func from_artifacts(entries: Array[Dictionary], options: Dictionary = {}) -> GFArtifactFreshnessReport:
```

从 artifact 条目数组创建报告构建器。

参数：

| 名称 | 说明 |
|---|---|
| `entries` | artifact 条目数组。 |
| `options` | 构建器选项，支持 subject 和 metadata。 |

返回：新构建器。

结构：

- `entries`: Array[Dictionary] artifact entries.
- `options`: Dictionary builder options.
