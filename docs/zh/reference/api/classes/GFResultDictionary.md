# GFResultDictionary

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/validation/gf_result_dictionary.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

通用结果字典常量、归一化与轻量工厂。 用于统一 `ok`、`reason`、`message`、`data`、`metadata`、`issues` 等常见结果字段。 普通操作结果应使用该结构；需要严重级别、统计和下一步建议时再使用校验报告。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`KEY_OK`](#member-gfresultdictionary-constants-key_ok) | `const KEY_OK: String = "ok"` |
| 常量 | [`KEY_DATA`](#member-gfresultdictionary-constants-key_data) | `const KEY_DATA: String = "data"` |
| 常量 | [`KEY_METADATA`](#member-gfresultdictionary-constants-key_metadata) | `const KEY_METADATA: String = "metadata"` |
| 常量 | [`KEY_REASON`](#member-gfresultdictionary-constants-key_reason) | `const KEY_REASON: String = "reason"` |
| 常量 | [`KEY_MESSAGE`](#member-gfresultdictionary-constants-key_message) | `const KEY_MESSAGE: String = "message"` |
| 常量 | [`KEY_ERROR`](#member-gfresultdictionary-constants-key_error) | `const KEY_ERROR: String = "error"` |
| 常量 | [`KEY_ERRORS`](#member-gfresultdictionary-constants-key_errors) | `const KEY_ERRORS: String = "errors"` |
| 常量 | [`KEY_ISSUES`](#member-gfresultdictionary-constants-key_issues) | `const KEY_ISSUES: String = "issues"` |
| 常量 | [`KEY_ISSUE_COUNT`](#member-gfresultdictionary-constants-key_issue_count) | `const KEY_ISSUE_COUNT: String = "issue_count"` |
| 常量 | [`KEY_HEALTHY`](#member-gfresultdictionary-constants-key_healthy) | `const KEY_HEALTHY: String = "healthy"` |
| 常量 | [`KEY_SUMMARY`](#member-gfresultdictionary-constants-key_summary) | `const KEY_SUMMARY: String = "summary"` |
| 常量 | [`KEY_NEXT_ACTION`](#member-gfresultdictionary-constants-key_next_action) | `const KEY_NEXT_ACTION: String = "next_action"` |
| 常量 | [`KEY_INTEGRITY_VALID`](#member-gfresultdictionary-constants-key_integrity_valid) | `const KEY_INTEGRITY_VALID: String = "integrity_valid"` |
| 方法 | [`make`](#member-gfresultdictionary-methods-make) | `static func make(ok: bool, fields: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_success`](#member-gfresultdictionary-methods-make_success) | `static func make_success(fields: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_failure`](#member-gfresultdictionary-methods-make_failure) | `static func make_failure(error: String = "", fields: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_rejected`](#member-gfresultdictionary-methods-make_rejected) | `static func make_rejected(reason: StringName, message: String = "", fields: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_with_issues`](#member-gfresultdictionary-methods-make_with_issues) | `static func make_with_issues(ok: bool, issues: Array = [], fields: Dictionary = {}) -> Dictionary:` |
| 方法 | [`normalize`](#member-gfresultdictionary-methods-normalize) | `static func normalize(result: Dictionary, default_ok: bool = false, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`is_ok`](#member-gfresultdictionary-methods-is_ok) | `static func is_ok(result: Dictionary, default_value: bool = false) -> bool:` |
| 方法 | [`merge_metadata`](#member-gfresultdictionary-methods-merge_metadata) | `static func merge_metadata(result: Dictionary, metadata: Dictionary, overwrite: bool = true) -> Dictionary:` |

## 常量

<a id="member-gfresultdictionary-constants-key_ok"></a>

### `KEY_OK`

- API：`public`

```gdscript
const KEY_OK: String = "ok"
```

操作是否成功字段名。

<a id="member-gfresultdictionary-constants-key_data"></a>

### `KEY_DATA`

- API：`public`

```gdscript
const KEY_DATA: String = "data"
```

结果数据字段名。

<a id="member-gfresultdictionary-constants-key_metadata"></a>

### `KEY_METADATA`

- API：`public`

```gdscript
const KEY_METADATA: String = "metadata"
```

元数据字段名。

<a id="member-gfresultdictionary-constants-key_reason"></a>

### `KEY_REASON`

- API：`public`

```gdscript
const KEY_REASON: String = "reason"
```

机器可读原因字段名。

<a id="member-gfresultdictionary-constants-key_message"></a>

### `KEY_MESSAGE`

- API：`public`

```gdscript
const KEY_MESSAGE: String = "message"
```

人类可读说明字段名。

<a id="member-gfresultdictionary-constants-key_error"></a>

### `KEY_ERROR`

- API：`public`

```gdscript
const KEY_ERROR: String = "error"
```

单个错误字段名。

<a id="member-gfresultdictionary-constants-key_errors"></a>

### `KEY_ERRORS`

- API：`public`

```gdscript
const KEY_ERRORS: String = "errors"
```

多个错误字段名。

<a id="member-gfresultdictionary-constants-key_issues"></a>

### `KEY_ISSUES`

- API：`public`

```gdscript
const KEY_ISSUES: String = "issues"
```

问题列表字段名。

<a id="member-gfresultdictionary-constants-key_issue_count"></a>

### `KEY_ISSUE_COUNT`

- API：`public`

```gdscript
const KEY_ISSUE_COUNT: String = "issue_count"
```

问题总数字段名。

<a id="member-gfresultdictionary-constants-key_healthy"></a>

### `KEY_HEALTHY`

- API：`public`

```gdscript
const KEY_HEALTHY: String = "healthy"
```

健康状态字段名。

<a id="member-gfresultdictionary-constants-key_summary"></a>

### `KEY_SUMMARY`

- API：`public`

```gdscript
const KEY_SUMMARY: String = "summary"
```

摘要字段名。

<a id="member-gfresultdictionary-constants-key_next_action"></a>

### `KEY_NEXT_ACTION`

- API：`public`

```gdscript
const KEY_NEXT_ACTION: String = "next_action"
```

下一步建议字段名。

<a id="member-gfresultdictionary-constants-key_integrity_valid"></a>

### `KEY_INTEGRITY_VALID`

- API：`public`

```gdscript
const KEY_INTEGRITY_VALID: String = "integrity_valid"
```

完整性校验结果字段名。

## 方法

<a id="member-gfresultdictionary-methods-make"></a>

### `make`

- API：`public`

```gdscript
static func make(ok: bool, fields: Dictionary = {}) -> Dictionary:
```

创建结果字典，并写入 ok 字段。

参数：

| 名称 | 说明 |
|---|---|
| `ok` | 操作是否成功。 |
| `fields` | 需要合并到结果中的附加字段。 |

返回：新结果字典。

结构：

- `fields`: Dictionary fields copied into the result.
- `return`: Dictionary with ok plus caller-provided fields.

<a id="member-gfresultdictionary-methods-make_success"></a>

### `make_success`

- API：`public`

```gdscript
static func make_success(fields: Dictionary = {}) -> Dictionary:
```

创建成功结果字典。

参数：

| 名称 | 说明 |
|---|---|
| `fields` | 需要合并到结果中的附加字段。 |

返回：新结果字典。

结构：

- `fields`: Dictionary fields copied into the result.
- `return`: Dictionary with ok set to true plus caller-provided fields.

<a id="member-gfresultdictionary-methods-make_failure"></a>

### `make_failure`

- API：`public`

```gdscript
static func make_failure(error: String = "", fields: Dictionary = {}) -> Dictionary:
```

创建失败结果字典，并写入 reason、message 和 error 字段。

参数：

| 名称 | 说明 |
|---|---|
| `error` | 错误说明。该值会同时作为默认 reason 与 message，便于结果结构稳定读取。 |
| `fields` | 需要合并到结果中的附加字段。 |

返回：新结果字典。

结构：

- `fields`: Dictionary fields copied into the result.
- `return`: Dictionary with ok set to false, reason, message, error, and caller-provided fields.

<a id="member-gfresultdictionary-methods-make_rejected"></a>

### `make_rejected`

- API：`public`

```gdscript
static func make_rejected(reason: StringName, message: String = "", fields: Dictionary = {}) -> Dictionary:
```

创建带机器可读原因和人类可读说明的失败结果。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 稳定失败原因，推荐使用 snake_case。 |
| `message` | 面向开发者或工具 UI 的说明；为空时使用 reason。 |
| `fields` | 需要合并到结果中的附加字段。 |

返回：新结果字典。

结构：

- `fields`: Dictionary fields copied into the result.
- `return`: Dictionary with ok set to false, reason, message, and caller-provided fields.

<a id="member-gfresultdictionary-methods-make_with_issues"></a>

### `make_with_issues`

- API：`public`

```gdscript
static func make_with_issues(ok: bool, issues: Array = [], fields: Dictionary = {}) -> Dictionary:
```

创建带 issues 的结果字典。

参数：

| 名称 | 说明 |
|---|---|
| `ok` | 操作是否成功。 |
| `issues` | 问题数组。 |
| `fields` | 需要合并到结果中的附加字段。 |

返回：新结果字典。

结构：

- `issues`: Array of caller-defined issue dictionaries or values.
- `fields`: Dictionary fields copied into the result.
- `return`: Dictionary with ok, issues, issue_count, healthy, and caller-provided fields.

<a id="member-gfresultdictionary-methods-normalize"></a>

### `normalize`

- API：`public`

```gdscript
static func normalize(result: Dictionary, default_ok: bool = false, options: Dictionary = {}) -> Dictionary:
```

归一化已有结果字典，补齐标准字段并返回副本。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 输入结果字典。 |
| `default_ok` | 缺少 ok 字段时使用的默认值。 |
| `options` | 可选控制，支持 include_issue_count、include_healthy、default_reason、default_message。 |

返回：归一化后的结果副本。

结构：

- `result`: Dictionary result payload.
- `options`: Dictionary controlling normalization.
- `return`: Dictionary normalized result payload.

<a id="member-gfresultdictionary-methods-is_ok"></a>

### `is_ok`

- API：`public`

```gdscript
static func is_ok(result: Dictionary, default_value: bool = false) -> bool:
```

检查结果字典是否成功。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 输入结果字典。 |
| `default_value` | 缺少 ok 字段时的默认值。 |

返回：成功时返回 true。

结构：

- `result`: Dictionary result payload.

<a id="member-gfresultdictionary-methods-merge_metadata"></a>

### `merge_metadata`

- API：`public`

```gdscript
static func merge_metadata(result: Dictionary, metadata: Dictionary, overwrite: bool = true) -> Dictionary:
```

合并元数据到结果字典并返回同一个字典。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 目标结果字典。 |
| `metadata` | 要合并的元数据。 |
| `overwrite` | 为 true 时覆盖已有键。 |

返回：传入的 result。

结构：

- `result`: Dictionary result payload mutated in place.
- `metadata`: Dictionary metadata payload.
- `return`: Dictionary result payload mutated in place.
