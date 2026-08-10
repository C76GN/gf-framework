# GFGeneratedArtifactReport

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_generated_artifact_report.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`6.0.0`

生成文本产物的保存报告辅助。 用于编辑器代码生成、导表导出或项目工具在写入前后获得统一的 new / changed / unchanged / skipped / failed 状态，不绑定具体生成器语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_NEW`](#member-gfgeneratedartifactreport-constants-status_new) | `const STATUS_NEW: StringName = &"new"` |
| 常量 | [`STATUS_CHANGED`](#member-gfgeneratedartifactreport-constants-status_changed) | `const STATUS_CHANGED: StringName = &"changed"` |
| 常量 | [`STATUS_UNCHANGED`](#member-gfgeneratedartifactreport-constants-status_unchanged) | `const STATUS_UNCHANGED: StringName = &"unchanged"` |
| 常量 | [`STATUS_SKIPPED`](#member-gfgeneratedartifactreport-constants-status_skipped) | `const STATUS_SKIPPED: StringName = &"skipped"` |
| 常量 | [`STATUS_FAILED`](#member-gfgeneratedartifactreport-constants-status_failed) | `const STATUS_FAILED: StringName = &"failed"` |
| 常量 | [`OWNER_GENERATED`](#member-gfgeneratedartifactreport-constants-owner_generated) | `const OWNER_GENERATED: StringName = &"generated"` |
| 常量 | [`OWNER_USER`](#member-gfgeneratedartifactreport-constants-owner_user) | `const OWNER_USER: StringName = &"user"` |
| 常量 | [`OWNER_EXTERNAL`](#member-gfgeneratedartifactreport-constants-owner_external) | `const OWNER_EXTERNAL: StringName = &"external"` |
| 方法 | [`make_report`](#member-gfgeneratedartifactreport-methods-make_report) | `static func make_report( output_path: String, status: StringName, error_code: Error = OK, message: String = "", options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`summarize_reports`](#member-gfgeneratedartifactreport-methods-summarize_reports) | `static func summarize_reports( reports: Array[Dictionary], subject: String = "", options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`save_text`](#member-gfgeneratedartifactreport-methods-save_text) | `static func save_text(output_path: String, text: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_error_code`](#member-gfgeneratedartifactreport-methods-get_error_code) | `static func get_error_code(report: Dictionary) -> Error:` |

## 常量

<a id="member-gfgeneratedartifactreport-constants-status_new"></a>

### `STATUS_NEW`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const STATUS_NEW: StringName = &"new"
```

目标文件不存在，本次产物是新增内容。

<a id="member-gfgeneratedartifactreport-constants-status_changed"></a>

### `STATUS_CHANGED`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const STATUS_CHANGED: StringName = &"changed"
```

目标文件存在且内容不同。

<a id="member-gfgeneratedartifactreport-constants-status_unchanged"></a>

### `STATUS_UNCHANGED`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const STATUS_UNCHANGED: StringName = &"unchanged"
```

目标文件存在且内容相同。

<a id="member-gfgeneratedartifactreport-constants-status_skipped"></a>

### `STATUS_SKIPPED`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const STATUS_SKIPPED: StringName = &"skipped"
```

目标文件因保存策略跳过。

<a id="member-gfgeneratedartifactreport-constants-status_failed"></a>

### `STATUS_FAILED`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const STATUS_FAILED: StringName = &"failed"
```

产物写入或准备失败。

<a id="member-gfgeneratedartifactreport-constants-owner_generated"></a>

### `OWNER_GENERATED`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const OWNER_GENERATED: StringName = &"generated"
```

框架或项目工具生成并可安全重建的产物。

<a id="member-gfgeneratedartifactreport-constants-owner_user"></a>

### `OWNER_USER`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const OWNER_USER: StringName = &"user"
```

用户手写或需要人工维护的产物。

<a id="member-gfgeneratedartifactreport-constants-owner_external"></a>

### `OWNER_EXTERNAL`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const OWNER_EXTERNAL: StringName = &"external"
```

外部工具或框架边界外来源管理的产物。

## 方法

<a id="member-gfgeneratedartifactreport-methods-make_report"></a>

### `make_report`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func make_report( output_path: String, status: StringName, error_code: Error = OK, message: String = "", options: Dictionary = {} ) -> Dictionary:
```

创建统一生成产物报告。

参数：

| 名称 | 说明 |
|---|---|
| `output_path` | 产物输出路径。 |
| `status` | 产物状态。 |
| `error_code` | Godot Error 错误码。 |
| `message` | 错误或跳过说明。 |
| `options` | 报告选项，支持 written、changed、dry_run、conflict、size_bytes、metadata、artifact_owner、generator_id、source_id、content_sha256、previous_sha256、expected_previous_sha256 和 encoding；metadata 会在返回报告中编码为 JSON-safe Dictionary。 |

返回：生成产物报告。success 只表示产物状态不是 failed；skipped 可保留非 OK error_code 供调用方决定是否阻断。

结构：

- `options`: Dictionary，可包含 written、changed、dry_run、conflict、size_bytes、metadata、artifact_owner、generator_id、source_id、content_sha256、previous_sha256、expected_previous_sha256 和 encoding；metadata 允许任意 Variant，返回时会通过 GFReportValueCodec 收束。
- `return`: JSON-safe Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、conflict、size_bytes、artifact_owner、generator_id、source_id、content_sha256、previous_sha256、expected_previous_sha256、encoding 和 metadata。

<a id="member-gfgeneratedartifactreport-methods-summarize_reports"></a>

### `summarize_reports`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func summarize_reports( reports: Array[Dictionary], subject: String = "", options: Dictionary = {} ) -> Dictionary:
```

汇总多份生成产物报告。 用于访问器生成、导表导出或批处理工具在一次操作后得到稳定的状态计数、 写入数量、dry-run 数量和产物所有权分布。

参数：

| 名称 | 说明 |
|---|---|
| `reports` | make_report() 或 save_text() 返回的报告数组。 |
| `subject` | 汇总主题。 |
| `options` | 汇总选项，支持 include_reports 和 metadata；metadata 与可选 reports 会在返回摘要中编码为 JSON-safe 值。 |

返回：批量产物报告摘要。

结构：

- `reports`: Array of Dictionary artifact reports.
- `options`: Dictionary，可包含 include_reports 和 metadata；metadata 允许任意 Variant，返回时会通过 GFReportValueCodec 收束。
- `return`: JSON-safe Dictionary，包含 success、subject、artifact_count、status_counts、owner_counts、written_count、changed_count、dry_run_count、failed_count、skipped_count、paths、errors、metadata 和可选 reports。

<a id="member-gfgeneratedartifactreport-methods-save_text"></a>

### `save_text`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func save_text(output_path: String, text: String, options: Dictionary = {}) -> Dictionary:
```

保存文本产物并返回统一报告。 dry_run 为 true 时只比较目标文件状态，不创建目录或写入文件。 overwrite_existing 为 false 且目标文件需要改写时返回 skipped / ERR_ALREADY_EXISTS。

参数：

| 名称 | 说明 |
|---|---|
| `output_path` | 产物输出路径。 |
| `text` | 要写入的文本内容。 |
| `options` | 保存选项，支持 overwrite_existing、expected_previous_sha256、dry_run、scan_filesystem、label、metadata、artifact_owner、generator_id、source_id 和 allowed_roots。 |

返回：生成产物保存报告。

结构：

- `options`: Dictionary，可包含 overwrite_existing、expected_previous_sha256、dry_run、scan_filesystem、label、metadata、artifact_owner、generator_id、source_id 和 allowed_roots；expected_previous_sha256 存在时要求保存前目标内容仍匹配该 SHA-256，空字符串表示要求目标不存在；allowed_roots 为可选 res:// / user:// 根目录数组。
- `return`: JSON-safe Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、conflict、size_bytes、artifact_owner、generator_id、source_id、content_sha256、previous_sha256、expected_previous_sha256、encoding 和 metadata。

<a id="member-gfgeneratedartifactreport-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func get_error_code(report: Dictionary) -> Error:
```

从报告读取 Error 错误码。

参数：

| 名称 | 说明 |
|---|---|
| `report` | make_report() 或 save_text() 返回的报告。 |

返回：Godot Error 错误码。

结构：

- `report`: Dictionary，包含 error_code 字段。
