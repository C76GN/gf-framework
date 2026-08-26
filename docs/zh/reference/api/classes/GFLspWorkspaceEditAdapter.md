# GFLspWorkspaceEditAdapter

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/lsp_workspace_edit/gf_lsp_workspace_edit_adapter.gd`
- 模块：`Tools`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`unreleased`

调用方提供的闭合 LSP WorkspaceEdit 安全适配器。 该工具只把已完成的 `documentChanges` 文本编辑转换为一次性预检计划，并在 工作区、文档版本和磁盘来源摘要仍一致时通过 GFArtifactWriteTransaction 提交。 它不建立 LSP 连接、不请求 rename/code action、不处理 create/rename/delete 文件操作、不读取未保存缓冲区、不驱动 UI，也不触发编辑器文件系统扫描。 允许目标严格限定为当前 `res://` 内已存在且未经过链接的 portable `.gd` 文件。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`POSITION_ENCODING_UTF8`](#member-gflspworkspaceeditadapter-constants-position_encoding_utf8) | `const POSITION_ENCODING_UTF8: String = "utf-8"` |
| 常量 | [`POSITION_ENCODING_UTF16`](#member-gflspworkspaceeditadapter-constants-position_encoding_utf16) | `const POSITION_ENCODING_UTF16: String = "utf-16"` |
| 方法 | [`build_plan`](#member-gflspworkspaceeditadapter-methods-build_plan) | `static func build_plan( workspace_edit: Dictionary, workspace_snapshot: Dictionary, options: Dictionary = {} ) -> GFLspWorkspaceEditPlan:` |
| 方法 | [`commit_plan`](#member-gflspworkspaceeditadapter-methods-commit_plan) | `static func commit_plan( plan: GFLspWorkspaceEditPlan, workspace_snapshot: Dictionary ) -> Dictionary:` |

## 常量

<a id="member-gflspworkspaceeditadapter-constants-position_encoding_utf8"></a>

### `POSITION_ENCODING_UTF8`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const POSITION_ENCODING_UTF8: String = "utf-8"
```

LSP UTF-8 position encoding 标识。

<a id="member-gflspworkspaceeditadapter-constants-position_encoding_utf16"></a>

### `POSITION_ENCODING_UTF16`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const POSITION_ENCODING_UTF16: String = "utf-16"
```

LSP UTF-16 position encoding 标识。

## 方法

<a id="member-gflspworkspaceeditadapter-methods-build_plan"></a>

### `build_plan`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func build_plan( workspace_edit: Dictionary, workspace_snapshot: Dictionary, options: Dictionary = {} ) -> GFLspWorkspaceEditPlan:
```

预检调用方已经取得的闭合 WorkspaceEdit。 只接受带版本的 `documentChanges` / `TextDocumentEdit`，每个目标必须在 workspace_snapshot 中恰好出现一次且 saved=true。计划阶段会读取严格 UTF-8 磁盘字节、精确换算 UTF-8 或 UTF-16 坐标、拒绝重叠并执行底层写事务预检， 但不会写文件。

参数：

| 名称 | 说明 |
|---|---|
| `workspace_edit` | 调用方提供且已闭合的 LSP WorkspaceEdit。 |
| `workspace_snapshot` | 调用方提供的工作区与已保存文档状态。 |
| `options` | position encoding 与资源预算。 |

返回：有效或带拒绝证据的 WorkspaceEdit 计划。

结构：

- `workspace_edit`: closed Dictionary，仅包含 documentChanges；每项仅包含 textDocument={uri:String,version:int} 和 edits；每个 edit 仅包含 range={start={line:int,character:int},end={line:int,character:int}} 与 newText:String。
- `workspace_snapshot`: closed Dictionary，仅包含 workspace_uri:String、workspace_version:int 和 documents:Array；每个 document 仅包含 uri:String、version:int、saved:bool、source_sha256:String，且 documents 必须与 edit 目标集合完全一致。
- `options`: closed Dictionary，必须包含 position_encoding=utf-8|utf-16；可包含 max_file_count、max_edits_per_file、max_file_bytes、max_total_bytes、max_workspace_edit_bytes，均为正整数且不得超过工具绝对上限。
- `return`: GFLspWorkspaceEditPlan；使用 get_report() 读取不含源码正文的 JSON-safe 证据。

<a id="member-gflspworkspaceeditadapter-methods-commit_plan"></a>

### `commit_plan`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func commit_plan( plan: GFLspWorkspaceEditPlan, workspace_snapshot: Dictionary ) -> Dictionary:
```

在绑定状态仍一致时一次性提交计划。 提交前会重新验证计划 SHA、当前工作区身份与版本、全部文档 saved/version/hash， 并重新读取磁盘严格 UTF-8 字节。通过后计划先被消费，再以 scan_filesystem=false 调用 GFArtifactWriteTransaction；失败报告会原样保留需要调用方处理的恢复句柄。

参数：

| 名称 | 说明 |
|---|---|
| `plan` | build_plan() 返回且尚未消费的计划。 |
| `workspace_snapshot` | 提交瞬间由调用方重新采集的已保存工作区状态。 |

返回：不含源码正文的闭合提交报告。

结构：

- `workspace_snapshot`: 与 build_plan() 的 workspace_snapshot 相同，且工作区身份/版本、目标集合、文档版本与来源 SHA-256 必须仍匹配计划。
- `return`: closed Dictionary，仅包含 ok、status、plan_sha256、written_count、unchanged_count、recovery_required、recovery_action、recovery_transaction、issues、artifact_report；recovery_required=true 时调用方必须按 recovery_action 将 recovery_transaction 原样交给 GFArtifactWriteTransaction.rollback() 或 complete()。
