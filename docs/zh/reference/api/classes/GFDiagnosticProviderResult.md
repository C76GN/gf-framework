# GFDiagnosticProviderResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_diagnostic_provider_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

惰性诊断 Provider 的类型化采集结果。 成功结果携带尚未编码的临时值；失败结果携带稳定错误码和面向维护者的说明。 非法错误码会归一为 `provider_failed`，错误说明最多保留 1024 个字符。 `GFDiagnosticsUtility` 会在把结果纳入快照前执行结构预算、脱敏和 JSON-safe 编码。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`succeeded`](#member-gfdiagnosticproviderresult-methods-succeeded) | `static func succeeded(value: Variant, metadata: Dictionary = {}) -> GFDiagnosticProviderResult:` |
| 方法 | [`failed`](#member-gfdiagnosticproviderresult-methods-failed) | `static func failed( error_code: StringName, error_message: String = "", metadata: Dictionary = {} ) -> GFDiagnosticProviderResult:` |
| 方法 | [`is_successful`](#member-gfdiagnosticproviderresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_value`](#member-gfdiagnosticproviderresult-methods-get_value) | `func get_value() -> Variant:` |
| 方法 | [`get_error_code`](#member-gfdiagnosticproviderresult-methods-get_error_code) | `func get_error_code() -> StringName:` |
| 方法 | [`get_error_message`](#member-gfdiagnosticproviderresult-methods-get_error_message) | `func get_error_message() -> String:` |
| 方法 | [`get_metadata`](#member-gfdiagnosticproviderresult-methods-get_metadata) | `func get_metadata() -> Dictionary:` |

## 方法

<a id="member-gfdiagnosticproviderresult-methods-succeeded"></a>

### `succeeded`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func succeeded(value: Variant, metadata: Dictionary = {}) -> GFDiagnosticProviderResult:
```

创建成功结果。

参数：

| 名称 | 说明 |
|---|---|
| `value` | Provider 采集的临时值。 |
| `metadata` | 本次采集的附加元数据。 |

返回：新的成功结果。

结构：

- `value`: Variant with provider-defined ephemeral diagnostic data.
- `metadata`: Dictionary with provider-defined ephemeral metadata.

<a id="member-gfdiagnosticproviderresult-methods-failed"></a>

### `failed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func failed( error_code: StringName, error_message: String = "", metadata: Dictionary = {} ) -> GFDiagnosticProviderResult:
```

创建失败结果。

参数：

| 名称 | 说明 |
|---|---|
| `error_code` | 非空、无首尾空白且不超过 128 个字符的稳定错误码；非法值回退为 provider_failed。 |
| `error_message` | 面向维护者的失败说明；最多保留 1024 个字符。 |
| `metadata` | 本次失败的附加元数据。 |

返回：新的失败结果。

结构：

- `metadata`: Dictionary with provider-defined ephemeral metadata.

<a id="member-gfdiagnosticproviderresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

查询采集是否成功。

返回：成功时返回 true。

<a id="member-gfdiagnosticproviderresult-methods-get_value"></a>

### `get_value`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_value() -> Variant:
```

获取成功值副本。

返回：Provider 值副本；失败时返回 null。

结构：

- `return`: Provider-defined Variant copy, or null for a failed result.

<a id="member-gfdiagnosticproviderresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_code() -> StringName:
```

获取稳定错误码。

返回：失败错误码；成功时为空。

<a id="member-gfdiagnosticproviderresult-methods-get_error_message"></a>

### `get_error_message`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_message() -> String:
```

获取错误说明。

返回：失败说明；成功时为空。

<a id="member-gfdiagnosticproviderresult-methods-get_metadata"></a>

### `get_metadata`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_metadata() -> Dictionary:
```

获取采集元数据副本。

返回：Provider 元数据副本。

结构：

- `return`: Dictionary with provider-defined ephemeral metadata.
