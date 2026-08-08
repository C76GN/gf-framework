# GFTableRowPredicateResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_table_row_predicate_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

类型化行谓词求值结果。 成功结果明确表示包含或排除当前行；失败结果携带稳定错误码和有界说明， 供 GFTableDataView 中止候选投影并保留上一份已提交视图。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`included`](#member-gftablerowpredicateresult-methods-included) | `static func included() -> GFTableRowPredicateResult:` |
| 方法 | [`excluded`](#member-gftablerowpredicateresult-methods-excluded) | `static func excluded() -> GFTableRowPredicateResult:` |
| 方法 | [`failed`](#member-gftablerowpredicateresult-methods-failed) | `static func failed( error_code: StringName, error_message: String = "" ) -> GFTableRowPredicateResult:` |
| 方法 | [`is_successful`](#member-gftablerowpredicateresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`should_include`](#member-gftablerowpredicateresult-methods-should_include) | `func should_include() -> bool:` |
| 方法 | [`get_error_code`](#member-gftablerowpredicateresult-methods-get_error_code) | `func get_error_code() -> StringName:` |
| 方法 | [`get_error_message`](#member-gftablerowpredicateresult-methods-get_error_message) | `func get_error_message() -> String:` |

## 方法

<a id="member-gftablerowpredicateresult-methods-included"></a>

### `included`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func included() -> GFTableRowPredicateResult:
```

创建包含当前行的成功结果。

返回：新的包含结果。

<a id="member-gftablerowpredicateresult-methods-excluded"></a>

### `excluded`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func excluded() -> GFTableRowPredicateResult:
```

创建排除当前行的成功结果。

返回：新的排除结果。

<a id="member-gftablerowpredicateresult-methods-failed"></a>

### `failed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func failed( error_code: StringName, error_message: String = "" ) -> GFTableRowPredicateResult:
```

创建求值失败结果。

参数：

| 名称 | 说明 |
|---|---|
| `error_code` | 非空、无首尾空白且 UTF-8 编码不超过 128 字节的稳定错误码。 |
| `error_message` | 面向维护者的失败说明；最多保留 1024 个 UTF-8 字节。 |

返回：新的失败结果。

<a id="member-gftablerowpredicateresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

查询求值是否成功。

返回：成功时返回 true。

<a id="member-gftablerowpredicateresult-methods-should_include"></a>

### `should_include`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func should_include() -> bool:
```

查询成功结果是否包含当前行。

返回：成功且应包含当前行时返回 true。

<a id="member-gftablerowpredicateresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_code() -> StringName:
```

获取稳定错误码。

返回：失败错误码；成功时为空。

<a id="member-gftablerowpredicateresult-methods-get_error_message"></a>

### `get_error_message`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_message() -> String:
```

获取有界错误说明。

返回：失败说明；成功时为空。
