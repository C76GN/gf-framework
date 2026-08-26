# GFLspWorkspaceEditPlan

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/lsp_workspace_edit/gf_lsp_workspace_edit_plan.gd`
- 模块：`Tools`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

已预检 LSP WorkspaceEdit 的一次性提交计划。 该值对象由 GFLspWorkspaceEditAdapter 创建，绑定工作区身份与版本、文档版本、 来源 SHA-256、结果 SHA-256 和完整计划 SHA-256。公开读取只返回隔离副本， 不暴露待写入源码；计划一旦进入底层写事务即被消费，不能重复提交。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`is_valid`](#member-gflspworkspaceeditplan-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`is_consumed`](#member-gflspworkspaceeditplan-methods-is_consumed) | `func is_consumed() -> bool:` |
| 方法 | [`get_plan_sha256`](#member-gflspworkspaceeditplan-methods-get_plan_sha256) | `func get_plan_sha256() -> String:` |
| 方法 | [`get_report`](#member-gflspworkspaceeditplan-methods-get_report) | `func get_report() -> Dictionary:` |

## 方法

<a id="member-gflspworkspaceeditplan-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_valid() -> bool:
```

返回计划当前是否可提交。

返回：计划已成功预检且尚未被消费时为 true。

<a id="member-gflspworkspaceeditplan-methods-is_consumed"></a>

### `is_consumed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_consumed() -> bool:
```

返回计划是否已经进入过底层写事务。

返回：计划已被一次性消费时为 true。

<a id="member-gflspworkspaceeditplan-methods-get_plan_sha256"></a>

### `get_plan_sha256`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_plan_sha256() -> String:
```

返回绑定完整计划内容的 SHA-256。

返回：有效计划的 64 位小写十六进制摘要；无效计划返回空字符串。

<a id="member-gflspworkspaceeditplan-methods-get_report"></a>

### `get_report`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_report() -> Dictionary:
```

返回不含源码正文的隔离计划报告。

返回：JSON-safe 报告副本。

结构：

- `return`: closed Dictionary，包含 ok、status、plan_sha256、workspace_uri、workspace_version、position_encoding、document_count、edit_count、changed_count、source_bytes、result_bytes、issues、documents、consumed。
