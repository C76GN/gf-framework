# GFConfigAccessGenerator

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_config_access_generator.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

生成静态导表访问器脚本。 默认生成结果只封装 provider 的 `get_record()` / `get_table()` 调用， 也可按 schema 字段声明生成可选记录包装类；生成器本身不规定项目表结构语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_OUTPUT_PATH`](#member-gfconfigaccessgenerator-constants-default_output_path) | `const DEFAULT_OUTPUT_PATH: String = "res://gf/generated/gf_config_access.gd"` |
| 常量 | [`DEFAULT_CLASS_NAME`](#member-gfconfigaccessgenerator-constants-default_class_name) | `const DEFAULT_CLASS_NAME: String = "GFConfigAccess"` |
| 常量 | [`DEFAULT_PROVIDER_ACCESSOR`](#member-gfconfigaccessgenerator-constants-default_provider_accessor) | `const DEFAULT_PROVIDER_ACCESSOR: String = "null"` |
| 方法 | [`generate`](#member-gfconfigaccessgenerator-methods-generate) | `func generate( schemas: Array, output_path: String = DEFAULT_OUTPUT_PATH, overwrite_existing: bool = true, access_class_name: String = DEFAULT_CLASS_NAME, provider_accessor: String = DEFAULT_PROVIDER_ACCESSOR, options: Dictionary = {} ) -> Error:` |
| 方法 | [`build_source`](#member-gfconfigaccessgenerator-methods-build_source) | `func build_source( schemas: Array, access_class_name: String = DEFAULT_CLASS_NAME, provider_accessor: String = DEFAULT_PROVIDER_ACCESSOR, options: Dictionary = {} ) -> String:` |
| 方法 | [`save_source`](#member-gfconfigaccessgenerator-methods-save_source) | `func save_source(output_path: String, source: String, overwrite_existing: bool = true) -> Error:` |

## 常量

<a id="member-gfconfigaccessgenerator-constants-default_output_path"></a>

### `DEFAULT_OUTPUT_PATH`

- API：`public`

```gdscript
const DEFAULT_OUTPUT_PATH: String = "res://gf/generated/gf_config_access.gd"
```

默认生成输出路径。

<a id="member-gfconfigaccessgenerator-constants-default_class_name"></a>

### `DEFAULT_CLASS_NAME`

- API：`public`

```gdscript
const DEFAULT_CLASS_NAME: String = "GFConfigAccess"
```

默认生成 class_name。

<a id="member-gfconfigaccessgenerator-constants-default_provider_accessor"></a>

### `DEFAULT_PROVIDER_ACCESSOR`

- API：`public`

```gdscript
const DEFAULT_PROVIDER_ACCESSOR: String = "null"
```

默认 provider 获取表达式。

## 方法

<a id="member-gfconfigaccessgenerator-methods-generate"></a>

### `generate`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func generate( schemas: Array, output_path: String = DEFAULT_OUTPUT_PATH, overwrite_existing: bool = true, access_class_name: String = DEFAULT_CLASS_NAME, provider_accessor: String = DEFAULT_PROVIDER_ACCESSOR, options: Dictionary = {} ) -> Error:
```

根据 schema 列表生成访问器并写入文件。

参数：

| 名称 | 说明 |
|---|---|
| `schemas` | 带有 `table_name` 或 `table_key` 属性的 schema 列表。 |
| `output_path` | 生成文件输出路径。 |
| `overwrite_existing` | 为 false 时目标已存在会返回 ERR_ALREADY_EXISTS。 |
| `access_class_name` | 生成脚本的 class_name。 |
| `provider_accessor` | 无显式 provider 参数时用于获取 provider 的表达式。 |
| `options` | 可选生成选项，支持 method_name_style、constant_prefix、record_method_pattern、table_method_pattern、include_schema_comments、include_typed_records、typed_record_method_pattern、typed_record_class_suffix。 |

返回：写入结果错误码。

结构：

- `schemas`: Array of Dictionary or Object schemas with table_name/table_key and optional metadata.
- `options`: Dictionary controlling method_name_style, constant_prefix, record_method_pattern, table_method_pattern, include_schema_comments, include_typed_records, typed_record_method_pattern, and typed_record_class_suffix.

<a id="member-gfconfigaccessgenerator-methods-build_source"></a>

### `build_source`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func build_source( schemas: Array, access_class_name: String = DEFAULT_CLASS_NAME, provider_accessor: String = DEFAULT_PROVIDER_ACCESSOR, options: Dictionary = {} ) -> String:
```

根据 schema 列表生成访问器源码。

参数：

| 名称 | 说明 |
|---|---|
| `schemas` | 带有 `table_name` 或 `table_key` 属性的 schema 列表。 |
| `access_class_name` | 生成脚本的 class_name。 |
| `provider_accessor` | 无显式 provider 参数时用于获取 provider 的表达式。 |
| `options` | 可选生成选项。 |

返回：GDScript 源码。

结构：

- `schemas`: Array of Dictionary or Object schemas with table_name/table_key and optional metadata.
- `options`: Dictionary controlling method_name_style, constant_prefix, record_method_pattern, table_method_pattern, include_schema_comments, include_typed_records, typed_record_method_pattern, and typed_record_class_suffix.

<a id="member-gfconfigaccessgenerator-methods-save_source"></a>

### `save_source`

- API：`public`

```gdscript
func save_source(output_path: String, source: String, overwrite_existing: bool = true) -> Error:
```

保存生成源码到指定路径。

参数：

| 名称 | 说明 |
|---|---|
| `output_path` | 生成文件输出路径。 |
| `source` | GDScript 源码。 |
| `overwrite_existing` | 为 false 时目标已存在会返回 ERR_ALREADY_EXISTS。 |

返回：写入结果错误码。
