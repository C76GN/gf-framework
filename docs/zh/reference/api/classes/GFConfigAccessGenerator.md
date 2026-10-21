# GFConfigAccessGenerator

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_access_generator.gd`
- 模块：`Tools`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`3.17.0`

生成静态导表访问器脚本。 默认生成结果只封装 provider 的 `get_record()` / `get_table()` 调用， 也可按 schema 字段声明生成可选记录包装类；生成器本身不规定项目表结构语义。 结构化字段只接纳正式 Schema/Column/TypeDefinition Resource，经同一类型编译器检查； Dictionary 或自定义 Object 声明仅支持既有非结构化列，不能导入 describe 报告。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_OUTPUT_PATH`](#member-gfconfigaccessgenerator-constants-default_output_path) | `const DEFAULT_OUTPUT_PATH: String = _GF_PROJECT_ARTIFACT_PATHS_SCRIPT.CONFIG_ACCESS_OUTPUT_PATH` |
| 常量 | [`DEFAULT_CLASS_NAME`](#member-gfconfigaccessgenerator-constants-default_class_name) | `const DEFAULT_CLASS_NAME: String = "GFConfigAccess"` |
| 常量 | [`DEFAULT_PROVIDER_ACCESSOR`](#member-gfconfigaccessgenerator-constants-default_provider_accessor) | `const DEFAULT_PROVIDER_ACCESSOR: String = "null"` |
| 方法 | [`get_capabilities`](#member-gfconfigaccessgenerator-methods-get_capabilities) | `static func get_capabilities() -> Dictionary:` |
| 方法 | [`generate`](#member-gfconfigaccessgenerator-methods-generate) | `func generate( schemas: Array, output_path: String = DEFAULT_OUTPUT_PATH, overwrite_existing: bool = true, access_class_name: String = DEFAULT_CLASS_NAME, provider_accessor: String = DEFAULT_PROVIDER_ACCESSOR, options: Dictionary = {} ) -> Error:` |
| 方法 | [`generate_with_report`](#member-gfconfigaccessgenerator-methods-generate_with_report) | `func generate_with_report( schemas: Array, output_path: String = DEFAULT_OUTPUT_PATH, access_class_name: String = DEFAULT_CLASS_NAME, provider_accessor: String = DEFAULT_PROVIDER_ACCESSOR, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`build_source_with_report`](#member-gfconfigaccessgenerator-methods-build_source_with_report) | `func build_source_with_report( schemas: Array, access_class_name: String = DEFAULT_CLASS_NAME, provider_accessor: String = DEFAULT_PROVIDER_ACCESSOR, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`build_source`](#member-gfconfigaccessgenerator-methods-build_source) | `func build_source( schemas: Array, access_class_name: String = DEFAULT_CLASS_NAME, provider_accessor: String = DEFAULT_PROVIDER_ACCESSOR, options: Dictionary = {} ) -> String:` |
| 方法 | [`save_source`](#member-gfconfigaccessgenerator-methods-save_source) | `func save_source( output_path: String, source: String, overwrite_existing: bool = true ) -> Error:` |
| 方法 | [`save_source_with_report`](#member-gfconfigaccessgenerator-methods-save_source_with_report) | `func save_source_with_report( output_path: String, source: String, options: Dictionary = {} ) -> Dictionary:` |

## 常量

<a id="member-gfconfigaccessgenerator-constants-default_output_path"></a>

### `DEFAULT_OUTPUT_PATH`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
const DEFAULT_OUTPUT_PATH: String = _GF_PROJECT_ARTIFACT_PATHS_SCRIPT.CONFIG_ACCESS_OUTPUT_PATH
```

默认生成输出路径。

<a id="member-gfconfigaccessgenerator-constants-default_class_name"></a>

### `DEFAULT_CLASS_NAME`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
const DEFAULT_CLASS_NAME: String = "GFConfigAccess"
```

默认生成 class_name。

<a id="member-gfconfigaccessgenerator-constants-default_provider_accessor"></a>

### `DEFAULT_PROVIDER_ACCESSOR`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
const DEFAULT_PROVIDER_ACCESSOR: String = "null"
```

默认 provider 获取表达式。

## 方法

<a id="member-gfconfigaccessgenerator-methods-get_capabilities"></a>

### `get_capabilities`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func get_capabilities() -> Dictionary:
```

返回此 GDScript 后端实际支持的源声明与生成表示。 结构包装是已接纳配置数据的类型投影，不代替运行时 schema 校验。 可空标量使用存在性查询及类型默认值；容器使用包装对象而非嵌套泛型声明。

返回：每次调用新建的能力描述。

结构：

- `return`: Dictionary，包含 version、backend、structured_source_admission、legacy_dictionary_schemas、descriptor_import、kinds、struct_inheritance、containers、nullable_scalars、enum、polymorphism、ownership 和 runtime_validation。

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
| `schemas` | 带有 \`table_name\` 或 \`table_key\` 属性的 schema 列表。 |
| `output_path` | res:// 或 user:// 生成文件输出 URI。 |
| `overwrite_existing` | 为 false 时目标已存在会返回 ERR_ALREADY_EXISTS。 |
| `access_class_name` | 生成脚本的 class_name。 |
| `provider_accessor` | 无显式 provider 参数时用于获取 provider 的表达式。 |
| `options` | 可选生成选项，支持 method_name_style、constant_prefix、record_method_pattern、table_method_pattern、include_schema_comments、include_typed_records、typed_record_method_pattern、typed_record_class_suffix。 |

返回：未发生物理提交时返回原始错误码；物理提交已发生时返回 OK。需要区分后置失败时使用 generate_with_report() 并检查 written。

结构：

- `schemas`: Array of Dictionary or Object schemas with table_name/table_key and optional metadata.
- `options`: Dictionary controlling method_name_style, constant_prefix, record_method_pattern, table_method_pattern, include_schema_comments, include_typed_records, typed_record_method_pattern, and typed_record_class_suffix.

<a id="member-gfconfigaccessgenerator-methods-generate_with_report"></a>

### `generate_with_report`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func generate_with_report( schemas: Array, output_path: String = DEFAULT_OUTPUT_PATH, access_class_name: String = DEFAULT_CLASS_NAME, provider_accessor: String = DEFAULT_PROVIDER_ACCESSOR, options: Dictionary = {} ) -> Dictionary:
```

根据 schema 列表生成访问器并返回生成产物报告。

参数：

| 名称 | 说明 |
|---|---|
| `schemas` | 带有 \`table_name\` 或 \`table_key\` 属性的 schema 列表。 |
| `output_path` | res:// 或 user:// 生成文件输出 URI；成功报告会返回规范化后的 URI。 |
| `access_class_name` | 生成脚本的 class_name。 |
| `provider_accessor` | 无显式 provider 参数时用于获取 provider 的表达式。 |
| `options` | 可选生成与保存选项，支持 build_source 选项、overwrite_existing、dry_run、scan_filesystem 和 metadata。 |

返回：生成产物报告。

结构：

- `schemas`: Array of Dictionary or Object schemas with table_name/table_key and optional metadata.
- `options`: Dictionary，可包含 method_name_style、constant_prefix、record_method_pattern、table_method_pattern、include_schema_comments、include_typed_records、typed_record_method_pattern、typed_record_class_suffix、overwrite_existing、dry_run、scan_filesystem 和 metadata。
- `return`: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes、input_schema_count、emitted_schema_count、skipped_schema_count、issues 和 metadata。

<a id="member-gfconfigaccessgenerator-methods-build_source_with_report"></a>

### `build_source_with_report`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func build_source_with_report( schemas: Array, access_class_name: String = DEFAULT_CLASS_NAME, provider_accessor: String = DEFAULT_PROVIDER_ACCESSOR, options: Dictionary = {} ) -> Dictionary:
```

根据 schema 列表生成源码与机器可读的完整性报告。

参数：

| 名称 | 说明 |
|---|---|
| `schemas` | 带有非空 table_name 或 table_key 的 schema 列表。 |
| `access_class_name` | 生成脚本的 class_name。 |
| `provider_accessor` | 无显式 provider 参数时用于获取 provider 的表达式。 |
| `options` | 访问器命名、注释与 typed record 生成选项。 |

返回：生成结果；success 仅在每个输入 schema 都已发射时为 true。

结构：

- `schemas`: Array of Dictionary or Object schemas with table_name/table_key and optional metadata.
- `options`: Dictionary controlling method_name_style, constant_prefix, record_method_pattern, table_method_pattern, include_schema_comments, include_typed_records, typed_record_method_pattern, and typed_record_class_suffix.
- `return`: Dictionary，包含 success、source、input_schema_count、emitted_schema_count、skipped_schema_count、issues 和 error。

<a id="member-gfconfigaccessgenerator-methods-build_source"></a>

### `build_source`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func build_source( schemas: Array, access_class_name: String = DEFAULT_CLASS_NAME, provider_accessor: String = DEFAULT_PROVIDER_ACCESSOR, options: Dictionary = {} ) -> String:
```

根据 schema 列表生成访问器源码。 SHA-256 后缀；缺少 table_name/table_key 的输入不会出现在该便利方法的结果中。 结构化定义无效时返回空字符串；需要验证完整发射及原因时，使用 build_source_with_report()。

参数：

| 名称 | 说明 |
|---|---|
| `schemas` | 带有 \`table_name\` 或 \`table_key\` 属性的 schema 列表。 |
| `access_class_name` | 生成脚本的 class_name。 |
| `provider_accessor` | 无显式 provider 参数时用于获取 provider 的表达式。 |
| `options` | 可选生成选项。 |

返回：GDScript 源码。非空但无法直接转为 ASCII 标识符的表名会使用稳定

结构：

- `schemas`: Array of Dictionary or Object schemas with table_name/table_key and optional metadata.
- `options`: Dictionary controlling method_name_style, constant_prefix, record_method_pattern, table_method_pattern, include_schema_comments, include_typed_records, typed_record_method_pattern, and typed_record_class_suffix.

<a id="member-gfconfigaccessgenerator-methods-save_source"></a>

### `save_source`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func save_source( output_path: String, source: String, overwrite_existing: bool = true ) -> Error:
```

保存生成源码到指定路径。

参数：

| 名称 | 说明 |
|---|---|
| `output_path` | res:// 或 user:// 生成文件输出 URI。 |
| `source` | GDScript 源码。 |
| `overwrite_existing` | 为 false 时目标已存在会返回 ERR_ALREADY_EXISTS。 |

返回：未发生物理提交时返回原始错误码；物理提交已发生时返回 OK。需要区分后置失败时使用 save_source_with_report() 并检查 written。

<a id="member-gfconfigaccessgenerator-methods-save_source_with_report"></a>

### `save_source_with_report`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func save_source_with_report( output_path: String, source: String, options: Dictionary = {} ) -> Dictionary:
```

保存生成源码到指定路径并返回生成产物报告。

参数：

| 名称 | 说明 |
|---|---|
| `output_path` | res:// 或 user:// 生成文件输出 URI；成功报告会返回规范化后的 URI。 |
| `source` | GDScript 源码。 |
| `options` | 保存选项，支持 overwrite_existing、dry_run、scan_filesystem 和 metadata。 |

返回：生成产物报告。

结构：

- `options`: Dictionary，可包含 overwrite_existing、dry_run、scan_filesystem 和 metadata。
- `return`: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes 和 metadata。
