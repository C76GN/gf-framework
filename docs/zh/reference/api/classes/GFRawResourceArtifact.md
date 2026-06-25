# GFRawResourceArtifact

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_raw_resource_artifact.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`6.0.0`

原始文件数据资源。 保存一个外部或导入前源文件的相对路径、字节数据和元数据，并可显式物化到 user:// 或授权路径。 它不绑定任何第三方格式或运行库，只提供通用的原始资源载荷封装。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MATERIALIZE_DIR`](#member-gfrawresourceartifact-constants-default_materialize_dir) | `const DEFAULT_MATERIALIZE_DIR: String = "user://gf/artifacts"` |
| 属性 | [`source_path`](#member-gfrawresourceartifact-properties-source_path) | `var source_path: String = ""` |
| 属性 | [`data`](#member-gfrawresourceartifact-properties-data) | `var data: PackedByteArray = PackedByteArray()` |
| 属性 | [`type_hint`](#member-gfrawresourceartifact-properties-type_hint) | `var type_hint: String = ""` |
| 属性 | [`metadata`](#member-gfrawresourceartifact-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfrawresourceartifact-methods-configure) | `func configure( p_source_path: String, p_data: PackedByteArray, p_type_hint: String = "", p_metadata: Dictionary = {} ) -> GFRawResourceArtifact:` |
| 方法 | [`has_data`](#member-gfrawresourceartifact-methods-has_data) | `func has_data() -> bool:` |
| 方法 | [`get_size_bytes`](#member-gfrawresourceartifact-methods-get_size_bytes) | `func get_size_bytes() -> int:` |
| 方法 | [`materialize_to_path`](#member-gfrawresourceartifact-methods-materialize_to_path) | `func materialize_to_path(target_path: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`materialize_temp`](#member-gfrawresourceartifact-methods-materialize_temp) | `func materialize_temp(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`to_summary_dictionary`](#member-gfrawresourceartifact-methods-to_summary_dictionary) | `func to_summary_dictionary() -> Dictionary:` |

## 常量

<a id="member-gfrawresourceartifact-constants-default_materialize_dir"></a>

### `DEFAULT_MATERIALIZE_DIR`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const DEFAULT_MATERIALIZE_DIR: String = "user://gf/artifacts"
```

默认物化目录。

## 属性

<a id="member-gfrawresourceartifact-properties-source_path"></a>

### `source_path`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var source_path: String = ""
```

原始源路径。可以是项目相对路径、res:// 路径或调用方自定义路径文本。

<a id="member-gfrawresourceartifact-properties-data"></a>

### `data`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var data: PackedByteArray = PackedByteArray()
```

原始文件字节数据。

<a id="member-gfrawresourceartifact-properties-type_hint"></a>

### `type_hint`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var type_hint: String = ""
```

可选类型提示或格式名。

<a id="member-gfrawresourceartifact-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义元数据。

结构：

- `metadata`: Dictionary project-defined artifact metadata.

## 方法

<a id="member-gfrawresourceartifact-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func configure( p_source_path: String, p_data: PackedByteArray, p_type_hint: String = "", p_metadata: Dictionary = {} ) -> GFRawResourceArtifact:
```

配置原始文件资源。

参数：

| 名称 | 说明 |
|---|---|
| `p_source_path` | 原始源路径。 |
| `p_data` | 原始文件字节数据。 |
| `p_type_hint` | 可选类型提示或格式名。 |
| `p_metadata` | 调用方自定义元数据。 |

返回：当前资源。

结构：

- `p_metadata`: Dictionary project-defined artifact metadata.

<a id="member-gfrawresourceartifact-methods-has_data"></a>

### `has_data`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func has_data() -> bool:
```

检查是否包含字节数据。

返回：包含数据时返回 true。

<a id="member-gfrawresourceartifact-methods-get_size_bytes"></a>

### `get_size_bytes`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_size_bytes() -> int:
```

获取数据字节数。

返回：数据字节数。

<a id="member-gfrawresourceartifact-methods-materialize_to_path"></a>

### `materialize_to_path`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func materialize_to_path(target_path: String, options: Dictionary = {}) -> Dictionary:
```

物化到指定路径。 默认只允许写入 user://，需要写入 res:// 时必须显式传入 allow_res_path。

参数：

| 名称 | 说明 |
|---|---|
| `target_path` | 输出文件路径。 |
| `options` | 写入选项。 |

返回：写入报告。

结构：

- `options`: Dictionary，可包含 allow_user_path、allow_res_path、overwrite 和 create_directories。
- `return`: Dictionary with ok, path, reason, size_bytes, and metadata.

<a id="member-gfrawresourceartifact-methods-materialize_temp"></a>

### `materialize_temp`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func materialize_temp(options: Dictionary = {}) -> Dictionary:
```

物化到临时 artifact 目录。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 写入选项，可包含 directory_path、file_name、extension、overwrite。 |

返回：写入报告。

结构：

- `options`: Dictionary，可包含 directory_path、file_name、extension、overwrite、allow_user_path、allow_res_path。
- `return`: Dictionary with ok, path, reason, size_bytes, and metadata.

<a id="member-gfrawresourceartifact-methods-to_summary_dictionary"></a>

### `to_summary_dictionary`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func to_summary_dictionary() -> Dictionary:
```

转换为轻量字典，不包含完整 data。

返回：摘要字典。

结构：

- `return`: Dictionary with source_path, type_hint, size_bytes, and metadata.
