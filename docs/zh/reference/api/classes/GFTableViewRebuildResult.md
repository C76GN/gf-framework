# GFTableViewRebuildResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_table_view_rebuild_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`11.0.0`

表格投影事务的类型化结果。 成功结果描述一次提交或 no-op；失败结果描述未提交的阶段、谓词和行身份。 结果不携带源 row，从而可安全交给 UI 诊断层。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`is_successful`](#member-gftableviewrebuildresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`was_committed`](#member-gftableviewrebuildresult-methods-was_committed) | `func was_committed() -> bool:` |
| 方法 | [`get_view_revision`](#member-gftableviewrebuildresult-methods-get_view_revision) | `func get_view_revision() -> int:` |
| 方法 | [`get_visible_count`](#member-gftableviewrebuildresult-methods-get_visible_count) | `func get_visible_count() -> int:` |
| 方法 | [`get_scanned_row_count`](#member-gftableviewrebuildresult-methods-get_scanned_row_count) | `func get_scanned_row_count() -> int:` |
| 方法 | [`get_predicate_evaluation_count`](#member-gftableviewrebuildresult-methods-get_predicate_evaluation_count) | `func get_predicate_evaluation_count() -> int:` |
| 方法 | [`get_error_code`](#member-gftableviewrebuildresult-methods-get_error_code) | `func get_error_code() -> StringName:` |
| 方法 | [`get_error_message`](#member-gftableviewrebuildresult-methods-get_error_message) | `func get_error_message() -> String:` |
| 方法 | [`get_failed_predicate_id`](#member-gftableviewrebuildresult-methods-get_failed_predicate_id) | `func get_failed_predicate_id() -> StringName:` |
| 方法 | [`get_failed_source_row_index`](#member-gftableviewrebuildresult-methods-get_failed_source_row_index) | `func get_failed_source_row_index() -> int:` |
| 方法 | [`get_failed_row_id`](#member-gftableviewrebuildresult-methods-get_failed_row_id) | `func get_failed_row_id() -> Variant:` |
| 方法 | [`duplicate_result`](#member-gftableviewrebuildresult-methods-duplicate_result) | `func duplicate_result() -> GFTableViewRebuildResult:` |

## 方法

<a id="member-gftableviewrebuildresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_successful() -> bool:
```

查询事务是否成功。

返回：成功时返回 true。

<a id="member-gftableviewrebuildresult-methods-was_committed"></a>

### `was_committed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func was_committed() -> bool:
```

查询事务是否提交了新 revision。

返回：提交时返回 true；成功 no-op 返回 false。

<a id="member-gftableviewrebuildresult-methods-get_view_revision"></a>

### `get_view_revision`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_view_revision() -> int:
```

获取结果对应的已提交 revision。

返回：当前已提交 revision。

<a id="member-gftableviewrebuildresult-methods-get_visible_count"></a>

### `get_visible_count`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_visible_count() -> int:
```

获取当前已提交可见行数量。

返回：可见行数量。

<a id="member-gftableviewrebuildresult-methods-get_scanned_row_count"></a>

### `get_scanned_row_count`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_scanned_row_count() -> int:
```

获取本次候选扫描的源行数量。

返回：已扫描行数量。

<a id="member-gftableviewrebuildresult-methods-get_predicate_evaluation_count"></a>

### `get_predicate_evaluation_count`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_predicate_evaluation_count() -> int:
```

获取本次候选执行的谓词次数。

返回：谓词求值次数。

<a id="member-gftableviewrebuildresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_error_code() -> StringName:
```

获取稳定错误码。

返回：失败错误码；成功时为空。

<a id="member-gftableviewrebuildresult-methods-get_error_message"></a>

### `get_error_message`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_error_message() -> String:
```

获取有界错误说明。

返回：失败说明；成功时为空。

<a id="member-gftableviewrebuildresult-methods-get_failed_predicate_id"></a>

### `get_failed_predicate_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_failed_predicate_id() -> StringName:
```

获取失败谓词 ID。

返回：失败谓词 ID；非谓词失败时为空。

<a id="member-gftableviewrebuildresult-methods-get_failed_source_row_index"></a>

### `get_failed_source_row_index`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_failed_source_row_index() -> int:
```

获取失败源行索引。

返回：失败行索引；非行失败时为 -1。

<a id="member-gftableviewrebuildresult-methods-get_failed_row_id"></a>

### `get_failed_row_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_failed_row_id() -> Variant:
```

获取失败行 ID 副本。

返回：失败行 ID；非行失败时为 null。

结构：

- `return`: Variant stable row identity copy, or null.

<a id="member-gftableviewrebuildresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func duplicate_result() -> GFTableViewRebuildResult:
```

创建结果的隔离副本。

返回：新结果对象；未配置实例返回新的未配置实例。
