# GFStorageReadResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_read_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`9.0.0`

严格存储读取结果。 将业务载荷、框架存储元数据、完整性状态和失败原因分离，避免调用方 把空字典误判为成功，也避免存储层保留字段渗入业务数据。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`IntegrityStatus`](#member-gfstoragereadresult-enums-integritystatus) | `enum IntegrityStatus` |
| 枚举 | [`FailureKind`](#member-gfstoragereadresult-enums-failurekind) | `enum FailureKind` |
| 属性 | [`ok`](#member-gfstoragereadresult-properties-ok) | `var ok: bool = false` |
| 属性 | [`payload`](#member-gfstoragereadresult-properties-payload) | `var payload: Dictionary = {}` |
| 属性 | [`metadata`](#member-gfstoragereadresult-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`integrity_status`](#member-gfstoragereadresult-properties-integrity_status) | `var integrity_status: IntegrityStatus = IntegrityStatus.NOT_CHECKED` |
| 属性 | [`error_code`](#member-gfstoragereadresult-properties-error_code) | `var error_code: Error = OK` |
| 属性 | [`error`](#member-gfstoragereadresult-properties-error) | `var error: String = ""` |
| 属性 | [`failure_kind`](#member-gfstoragereadresult-properties-failure_kind) | `var failure_kind: FailureKind = FailureKind.NONE` |
| 属性 | [`document_schema_version`](#member-gfstoragereadresult-properties-document_schema_version) | `var document_schema_version: int = 0` |
| 属性 | [`source_data_version`](#member-gfstoragereadresult-properties-source_data_version) | `var source_data_version: int = 0` |
| 属性 | [`data_version`](#member-gfstoragereadresult-properties-data_version) | `var data_version: int = 0` |
| 属性 | [`migrated`](#member-gfstoragereadresult-properties-migrated) | `var migrated: bool = false` |
| 方法 | [`configure_success`](#member-gfstoragereadresult-methods-configure_success) | `func configure_success( p_payload: Dictionary, p_metadata: Dictionary = {}, p_integrity_status: IntegrityStatus = IntegrityStatus.NOT_CHECKED, p_document_schema_version: int = 0 ) -> GFStorageReadResult:` |
| 方法 | [`configure_failure`](#member-gfstoragereadresult-methods-configure_failure) | `func configure_failure( p_error: String, p_error_code: Error = ERR_INVALID_DATA, p_metadata: Dictionary = {}, p_integrity_status: IntegrityStatus = IntegrityStatus.NOT_CHECKED, p_document_schema_version: int = 0, p_failure_kind: FailureKind = FailureKind.IO_FAILED ) -> GFStorageReadResult:` |
| 方法 | [`is_integrity_accepted`](#member-gfstoragereadresult-methods-is_integrity_accepted) | `func is_integrity_accepted() -> bool:` |
| 方法 | [`duplicate_result`](#member-gfstoragereadresult-methods-duplicate_result) | `func duplicate_result() -> GFStorageReadResult:` |
| 方法 | [`to_dict`](#member-gfstoragereadresult-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfstoragereadresult-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`from_dict`](#member-gfstoragereadresult-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFStorageReadResult:` |

## 枚举

<a id="member-gfstoragereadresult-enums-integritystatus"></a>

### `IntegrityStatus`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
enum IntegrityStatus {
	## 文档没有声明完整性校验，且调用方没有要求校验。
	NOT_CHECKED,
	## 文档完整性校验通过。
	VALID,
	## 调用方要求完整性校验，但文档没有校验信息。
	MISSING,
	## 文档完整性校验失败。
	INVALID,
}
```

存储文档完整性状态。

<a id="member-gfstoragereadresult-enums-failurekind"></a>

### `FailureKind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum FailureKind {
	## 没有失败。
	NONE,
	## 请求参数或路径无效。
	INVALID_REQUEST,
	## 文件不存在。
	NOT_FOUND,
	## 文件 IO 或异步执行失败。
	IO_FAILED,
	## 文件格式、载荷或完整性损坏。
	CORRUPT,
	## 物理存储版本高于当前运行时。
	FUTURE_VERSION,
	## 物理存储迁移链缺失或迁移失败。
	MIGRATION_FAILED,
	## 请求在执行前被底层服务终止。
	UNAVAILABLE,
}
```

读取失败的稳定分类。 调用方必须依据该分类选择恢复策略，不得从 Error 码或错误文本推断数据语义。

## 属性

<a id="member-gfstoragereadresult-properties-ok"></a>

### `ok`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var ok: bool = false
```

读取、解码和迁移是否全部成功。

<a id="member-gfstoragereadresult-properties-payload"></a>

### `payload`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var payload: Dictionary = {}
```

与框架存储字段完全隔离的业务载荷。

结构：

- `payload`: Dictionary，项目写入的原始业务数据。

<a id="member-gfstoragereadresult-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var metadata: Dictionary = {}
```

框架存储文档元数据。

结构：

- `metadata`: Dictionary，包含 data_version 以及可选时间戳、格式和压缩信息。

<a id="member-gfstoragereadresult-properties-integrity_status"></a>

### `integrity_status`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var integrity_status: IntegrityStatus = IntegrityStatus.NOT_CHECKED
```

完整性校验状态。

<a id="member-gfstoragereadresult-properties-error_code"></a>

### `error_code`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var error_code: Error = OK
```

Godot 错误码；成功时为 OK。

<a id="member-gfstoragereadresult-properties-error"></a>

### `error`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var error: String = ""
```

稳定、可展示的错误描述；成功时为空字符串。

<a id="member-gfstoragereadresult-properties-failure_kind"></a>

### `failure_kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var failure_kind: FailureKind = FailureKind.NONE
```

读取失败的稳定分类；成功时为 `FailureKind.NONE`。

<a id="member-gfstoragereadresult-properties-document_schema_version"></a>

### `document_schema_version`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var document_schema_version: int = 0
```

物理存储文档 schema 版本。

<a id="member-gfstoragereadresult-properties-source_data_version"></a>

### `source_data_version`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var source_data_version: int = 0
```

读取时发现的数据 schema 版本。

<a id="member-gfstoragereadresult-properties-data_version"></a>

### `data_version`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var data_version: int = 0
```

完成迁移后的数据 schema 版本。

<a id="member-gfstoragereadresult-properties-migrated"></a>

### `migrated`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var migrated: bool = false
```

本次读取是否执行过数据迁移。

## 方法

<a id="member-gfstoragereadresult-methods-configure_success"></a>

### `configure_success`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func configure_success( p_payload: Dictionary, p_metadata: Dictionary = {}, p_integrity_status: IntegrityStatus = IntegrityStatus.NOT_CHECKED, p_document_schema_version: int = 0 ) -> GFStorageReadResult:
```

配置成功结果。

参数：

| 名称 | 说明 |
|---|---|
| `p_payload` | 业务载荷。 |
| `p_metadata` | 框架存储元数据。 |
| `p_integrity_status` | 完整性状态。 |
| `p_document_schema_version` | 物理文档 schema 版本。 |

返回：当前结果。

结构：

- `p_payload`: Dictionary，项目写入的业务数据。
- `p_metadata`: Dictionary，框架存储元数据。

<a id="member-gfstoragereadresult-methods-configure_failure"></a>

### `configure_failure`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func configure_failure( p_error: String, p_error_code: Error = ERR_INVALID_DATA, p_metadata: Dictionary = {}, p_integrity_status: IntegrityStatus = IntegrityStatus.NOT_CHECKED, p_document_schema_version: int = 0, p_failure_kind: FailureKind = FailureKind.IO_FAILED ) -> GFStorageReadResult:
```

配置失败结果。

参数：

| 名称 | 说明 |
|---|---|
| `p_error` | 错误描述。 |
| `p_error_code` | Godot 错误码。 |
| `p_metadata` | 已能安全恢复的框架存储元数据。 |
| `p_integrity_status` | 完整性状态。 |
| `p_document_schema_version` | 物理文档 schema 版本。 |
| `p_failure_kind` | 稳定失败分类。 |

返回：当前结果。

结构：

- `p_metadata`: Dictionary，失败时仍可安全展示或诊断的框架存储元数据。

<a id="member-gfstoragereadresult-methods-is_integrity_accepted"></a>

### `is_integrity_accepted`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func is_integrity_accepted() -> bool:
```

完整性状态是否允许调用方使用载荷。

返回：状态不是 MISSING 或 INVALID 时返回 true。

<a id="member-gfstoragereadresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func duplicate_result() -> GFStorageReadResult:
```

创建读取结果深拷贝。

返回：新读取结果。

<a id="member-gfstoragereadresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为线程、报告和工具可传递的字典。

返回：读取结果字典。

结构：

- `return`: Dictionary，包含 ok、payload、metadata、integrity_status、error_code、error、failure_kind、document_schema_version、source_data_version、data_version 和 migrated。

<a id="member-gfstoragereadresult-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用读取结果字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 读取结果字典。 |

结构：

- `data`: Dictionary，GFStorageReadResult.to_dict() 输出。

<a id="member-gfstoragereadresult-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFStorageReadResult:
```

从字典创建读取结果。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 读取结果字典。 |

返回：新读取结果。

结构：

- `data`: Dictionary，GFStorageReadResult.to_dict() 输出。
