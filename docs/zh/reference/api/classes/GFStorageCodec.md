# GFStorageCodec

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_codec.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用存档字典编码与解码策略。 负责严格存储文档的字典序列化、可选压缩、完整性校验和轻量混淆。 JSON 格式会通过 GFVariantJsonCodec 保留 Godot 值类型和非有限浮点数。 业务载荷始终位于独立 payload 字段中，框架元数据不会进入业务字典。 它不负责路径、槽位、事务提交或云同步。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Format`](#member-gfstoragecodec-enums-format) | `enum Format` |
| 常量 | [`DOCUMENT_KEY`](#member-gfstoragecodec-constants-document_key) | `const DOCUMENT_KEY: String = "__gf_storage_document"` |
| 常量 | [`PAYLOAD_KEY`](#member-gfstoragecodec-constants-payload_key) | `const PAYLOAD_KEY: String = "payload"` |
| 常量 | [`SCHEMA_VERSION_KEY`](#member-gfstoragecodec-constants-schema_version_key) | `const SCHEMA_VERSION_KEY: String = "schema_version"` |
| 常量 | [`METADATA_KEY`](#member-gfstoragecodec-constants-metadata_key) | `const METADATA_KEY: String = "metadata"` |
| 常量 | [`INTEGRITY_KEY`](#member-gfstoragecodec-constants-integrity_key) | `const INTEGRITY_KEY: String = "integrity"` |
| 常量 | [`ALGORITHM_KEY`](#member-gfstoragecodec-constants-algorithm_key) | `const ALGORITHM_KEY: String = "algorithm"` |
| 常量 | [`DIGEST_KEY`](#member-gfstoragecodec-constants-digest_key) | `const DIGEST_KEY: String = "digest"` |
| 常量 | [`VERSION_KEY`](#member-gfstoragecodec-constants-version_key) | `const VERSION_KEY: String = "data_version"` |
| 常量 | [`TIMESTAMP_KEY`](#member-gfstoragecodec-constants-timestamp_key) | `const TIMESTAMP_KEY: String = "timestamp"` |
| 常量 | [`FORMAT_KEY`](#member-gfstoragecodec-constants-format_key) | `const FORMAT_KEY: String = "format"` |
| 常量 | [`COMPRESSION_KEY`](#member-gfstoragecodec-constants-compression_key) | `const COMPRESSION_KEY: String = "compression"` |
| 常量 | [`DOCUMENT_SCHEMA_VERSION`](#member-gfstoragecodec-constants-document_schema_version) | `const DOCUMENT_SCHEMA_VERSION: int = 2` |
| 属性 | [`format`](#member-gfstoragecodec-properties-format) | `var format: Format = Format.JSON` |
| 属性 | [`use_compression`](#member-gfstoragecodec-properties-use_compression) | `var use_compression: bool = false` |
| 属性 | [`use_integrity_checksum`](#member-gfstoragecodec-properties-use_integrity_checksum) | `var use_integrity_checksum: bool = false` |
| 属性 | [`strict_integrity`](#member-gfstoragecodec-properties-strict_integrity) | `var strict_integrity: bool = true` |
| 属性 | [`require_integrity_checksum`](#member-gfstoragecodec-properties-require_integrity_checksum) | `var require_integrity_checksum: bool = true` |
| 属性 | [`include_metadata`](#member-gfstoragecodec-properties-include_metadata) | `var include_metadata: bool = false` |
| 属性 | [`version`](#member-gfstoragecodec-properties-version) | `var version: int = 1:` |
| 属性 | [`obfuscation_key`](#member-gfstoragecodec-properties-obfuscation_key) | `var obfuscation_key: int = 0` |
| 属性 | [`max_decompressed_bytes`](#member-gfstoragecodec-properties-max_decompressed_bytes) | `var max_decompressed_bytes: int = 64 * 1024 * 1024` |
| 属性 | [`normalize_json_numbers`](#member-gfstoragecodec-properties-normalize_json_numbers) | `var normalize_json_numbers: bool = false` |
| 方法 | [`encode`](#member-gfstoragecodec-methods-encode) | `func encode(data: Dictionary, options: Dictionary = {}) -> PackedByteArray:` |
| 方法 | [`decode`](#member-gfstoragecodec-methods-decode) | `func decode(bytes: PackedByteArray, options: Dictionary = {}) -> GFStorageReadResult:` |
| 方法 | [`serialize_dictionary`](#member-gfstoragecodec-methods-serialize_dictionary) | `func serialize_dictionary(data: Dictionary, p_format: Format = Format.JSON) -> PackedByteArray:` |
| 方法 | [`deserialize_dictionary`](#member-gfstoragecodec-methods-deserialize_dictionary) | `func deserialize_dictionary(bytes: PackedByteArray, p_format: Format = Format.JSON) -> Dictionary:` |
| 方法 | [`calculate_checksum`](#member-gfstoragecodec-methods-calculate_checksum) | `func calculate_checksum(data: Dictionary, p_format: Format = Format.JSON) -> String:` |

## 枚举

<a id="member-gfstoragecodec-enums-format"></a>

### `Format`

- API：`public`

```gdscript
enum Format {
	## 稳定排序后的 JSON 文本。
	JSON,
	## Godot Variant 二进制格式。
	BINARY,
}
```

存档载荷序列化格式。

## 常量

<a id="member-gfstoragecodec-constants-document_key"></a>

### `DOCUMENT_KEY`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const DOCUMENT_KEY: String = "__gf_storage_document"
```

存储文档描述字段名。

<a id="member-gfstoragecodec-constants-payload_key"></a>

### `PAYLOAD_KEY`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const PAYLOAD_KEY: String = "payload"
```

存储文档业务载荷字段名。

<a id="member-gfstoragecodec-constants-schema_version_key"></a>

### `SCHEMA_VERSION_KEY`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const SCHEMA_VERSION_KEY: String = "schema_version"
```

文档 schema 版本字段名。

<a id="member-gfstoragecodec-constants-metadata_key"></a>

### `METADATA_KEY`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const METADATA_KEY: String = "metadata"
```

存储元信息字段名。

<a id="member-gfstoragecodec-constants-integrity_key"></a>

### `INTEGRITY_KEY`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const INTEGRITY_KEY: String = "integrity"
```

存储完整性描述字段名。

<a id="member-gfstoragecodec-constants-algorithm_key"></a>

### `ALGORITHM_KEY`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const ALGORITHM_KEY: String = "algorithm"
```

完整性算法字段名。

<a id="member-gfstoragecodec-constants-digest_key"></a>

### `DIGEST_KEY`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const DIGEST_KEY: String = "digest"
```

完整性摘要字段名。

<a id="member-gfstoragecodec-constants-version_key"></a>

### `VERSION_KEY`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const VERSION_KEY: String = "data_version"
```

存储版本字段名。

<a id="member-gfstoragecodec-constants-timestamp_key"></a>

### `TIMESTAMP_KEY`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const TIMESTAMP_KEY: String = "timestamp"
```

存储时间戳字段名。

<a id="member-gfstoragecodec-constants-format_key"></a>

### `FORMAT_KEY`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const FORMAT_KEY: String = "format"
```

存储编码格式字段名。

<a id="member-gfstoragecodec-constants-compression_key"></a>

### `COMPRESSION_KEY`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const COMPRESSION_KEY: String = "compression"
```

存储压缩方式字段名。

<a id="member-gfstoragecodec-constants-document_schema_version"></a>

### `DOCUMENT_SCHEMA_VERSION`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const DOCUMENT_SCHEMA_VERSION: int = 2
```

当前存储文档 schema 版本。

## 属性

<a id="member-gfstoragecodec-properties-format"></a>

### `format`

- API：`public`

```gdscript
var format: Format = Format.JSON
```

默认序列化格式。

<a id="member-gfstoragecodec-properties-use_compression"></a>

### `use_compression`

- API：`public`

```gdscript
var use_compression: bool = false
```

是否压缩载荷。

<a id="member-gfstoragecodec-properties-use_integrity_checksum"></a>

### `use_integrity_checksum`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var use_integrity_checksum: bool = false
```

是否在文档完整性描述中写入 SHA-256 摘要。

<a id="member-gfstoragecodec-properties-strict_integrity"></a>

### `strict_integrity`

- API：`public`

```gdscript
var strict_integrity: bool = true
```

校验失败时是否拒绝读取。

<a id="member-gfstoragecodec-properties-require_integrity_checksum"></a>

### `require_integrity_checksum`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var require_integrity_checksum: bool = true
```

启用完整性校验时，是否要求文档必须包含 SHA-256 摘要。

<a id="member-gfstoragecodec-properties-include_metadata"></a>

### `include_metadata`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var include_metadata: bool = false
```

是否写入时间戳、编码格式和压缩方式等诊断元数据。 数据版本始终写入，不受该选项影响。

<a id="member-gfstoragecodec-properties-version"></a>

### `version`

- API：`public`

```gdscript
var version: int = 1:
```

当前数据版本。

<a id="member-gfstoragecodec-properties-obfuscation_key"></a>

### `obfuscation_key`

- API：`public`

```gdscript
var obfuscation_key: int = 0
```

轻量 XOR 混淆密钥；为 0 时写入原始 bytes。该字段不提供安全加密能力。

<a id="member-gfstoragecodec-properties-max_decompressed_bytes"></a>

### `max_decompressed_bytes`

- API：`public`

```gdscript
var max_decompressed_bytes: int = 64 * 1024 * 1024
```

解压时允许的最大输出字节数。

<a id="member-gfstoragecodec-properties-normalize_json_numbers"></a>

### `normalize_json_numbers`

- API：`public`

```gdscript
var normalize_json_numbers: bool = false
```

JSON 解码时是否把接近整数的 float 归一为 int。Binary 格式不受影响。

## 方法

<a id="member-gfstoragecodec-methods-encode"></a>

### `encode`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func encode(data: Dictionary, options: Dictionary = {}) -> PackedByteArray:
```

将字典编码为可写入文件的 bytes。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 要编码的数据。 |
| `options` | 临时覆盖当前 codec 设置的选项字典。 |

返回：编码后的 bytes。

结构：

- `data`: Dictionary，要序列化的业务载荷；所有键都会原样保存在独立 payload 中。
- `options`: Dictionary，可包含 format、use_compression、obfuscation_key、use_integrity_checksum、include_metadata、version 和 max_decompressed_bytes。

<a id="member-gfstoragecodec-methods-decode"></a>

### `decode`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func decode(bytes: PackedByteArray, options: Dictionary = {}) -> GFStorageReadResult:
```

从 bytes 解码字典。

参数：

| 名称 | 说明 |
|---|---|
| `bytes` | 文件读取到的 bytes。 |
| `options` | 临时覆盖当前 codec 设置的选项字典。 |

返回：强类型读取结果；业务载荷与框架元数据保持隔离。

结构：

- `options`: Dictionary，可包含 format、use_compression、obfuscation_key、use_integrity_checksum、strict_integrity、normalize_json_numbers、require_integrity_checksum 和 max_decompressed_bytes。

<a id="member-gfstoragecodec-methods-serialize_dictionary"></a>

### `serialize_dictionary`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func serialize_dictionary(data: Dictionary, p_format: Format = Format.JSON) -> PackedByteArray:
```

序列化字典。JSON 格式会递归排序字典键，并把 Godot 值类型转为 JSON 安全标记。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 要序列化的数据。 |
| `p_format` | 目标格式。 |

返回：字节数组。

结构：

- `data`: Dictionary，要序列化的数据载荷。

<a id="member-gfstoragecodec-methods-deserialize_dictionary"></a>

### `deserialize_dictionary`

- API：`public`

```gdscript
func deserialize_dictionary(bytes: PackedByteArray, p_format: Format = Format.JSON) -> Dictionary:
```

反序列化字典。

参数：

| 名称 | 说明 |
|---|---|
| `bytes` | 源 bytes。 |
| `p_format` | 源格式。 |

返回：字典；失败时返回空字典。

结构：

- `return`: Dictionary，从字节解析出的数据；解析失败时为空字典。

<a id="member-gfstoragecodec-methods-calculate_checksum"></a>

### `calculate_checksum`

- API：`public`

```gdscript
func calculate_checksum(data: Dictionary, p_format: Format = Format.JSON) -> String:
```

计算当前数据按指定格式序列化后的 SHA-256。 JSON 格式会在 checksum 输入中规范化整数字面量，避免不同 Godot 版本解析 JSON 数字类型导致误判损坏。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 输入数据。 |
| `p_format` | 序列化格式。 |

返回：checksum hex 字符串。

结构：

- `data`: Dictionary，用作校验和输入的数据载荷。
