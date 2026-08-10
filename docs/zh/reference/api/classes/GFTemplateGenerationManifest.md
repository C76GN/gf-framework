# GFTemplateGenerationManifest

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_template_generation_manifest.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`6.0.0`

代码生成模板清单辅助。 用普通字典描述模板 ID、模板路径、输出路径、变量、要求和产物所有权，并可从 JSON sidecar 读取。它不绑定具体模板引擎，也不规定项目目录结构，只为生成器提供稳定、 可校验、可汇总并可接入 GFGeneratedArtifactReport 的计划格式。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_READY`](#member-gftemplategenerationmanifest-constants-status_ready) | `const STATUS_READY: StringName = &"ready"` |
| 常量 | [`STATUS_INVALID`](#member-gftemplategenerationmanifest-constants-status_invalid) | `const STATUS_INVALID: StringName = &"invalid"` |
| 常量 | [`STATUS_PARSE_FAILED`](#member-gftemplategenerationmanifest-constants-status_parse_failed) | `const STATUS_PARSE_FAILED: StringName = &"parse_failed"` |
| 常量 | [`STATUS_LOAD_FAILED`](#member-gftemplategenerationmanifest-constants-status_load_failed) | `const STATUS_LOAD_FAILED: StringName = &"load_failed"` |
| 常量 | [`MAX_JSON_BYTES`](#member-gftemplategenerationmanifest-constants-max_json_bytes) | `const MAX_JSON_BYTES: int = 1_048_576` |
| 常量 | [`MAX_JSON_DEPTH`](#member-gftemplategenerationmanifest-constants-max_json_depth) | `const MAX_JSON_DEPTH: int = 64` |
| 方法 | [`make_manifest`](#member-gftemplategenerationmanifest-methods-make_manifest) | `static func make_manifest( template_id: StringName, template_path: String, output_path: String, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`from_dictionary`](#member-gftemplategenerationmanifest-methods-from_dictionary) | `static func from_dictionary(data: Dictionary, defaults: Dictionary = {}) -> Dictionary:` |
| 方法 | [`from_json_text`](#member-gftemplategenerationmanifest-methods-from_json_text) | `static func from_json_text(text: String, defaults: Dictionary = {}) -> Dictionary:` |
| 方法 | [`load_sidecar`](#member-gftemplategenerationmanifest-methods-load_sidecar) | `static func load_sidecar(sidecar_path: String, defaults: Dictionary = {}) -> Dictionary:` |
| 方法 | [`validate_manifest`](#member-gftemplategenerationmanifest-methods-validate_manifest) | `static func validate_manifest(manifest: Dictionary) -> Dictionary:` |
| 方法 | [`make_artifact_options`](#member-gftemplategenerationmanifest-methods-make_artifact_options) | `static func make_artifact_options(manifest: Dictionary, extra_options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`save_text_from_manifest`](#member-gftemplategenerationmanifest-methods-save_text_from_manifest) | `static func save_text_from_manifest(manifest: Dictionary, text: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`summarize_manifests`](#member-gftemplategenerationmanifest-methods-summarize_manifests) | `static func summarize_manifests(manifests: Array[Dictionary], options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gftemplategenerationmanifest-constants-status_ready"></a>

### `STATUS_READY`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const STATUS_READY: StringName = &"ready"
```

清单有效。

<a id="member-gftemplategenerationmanifest-constants-status_invalid"></a>

### `STATUS_INVALID`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const STATUS_INVALID: StringName = &"invalid"
```

清单缺少必要字段。

<a id="member-gftemplategenerationmanifest-constants-status_parse_failed"></a>

### `STATUS_PARSE_FAILED`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const STATUS_PARSE_FAILED: StringName = &"parse_failed"
```

清单 JSON 无法解析。

<a id="member-gftemplategenerationmanifest-constants-status_load_failed"></a>

### `STATUS_LOAD_FAILED`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const STATUS_LOAD_FAILED: StringName = &"load_failed"
```

清单文件无法读取。

<a id="member-gftemplategenerationmanifest-constants-max_json_bytes"></a>

### `MAX_JSON_BYTES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const MAX_JSON_BYTES: int = 1_048_576
```

JSON 清单允许的最大 UTF-8 字节数。

<a id="member-gftemplategenerationmanifest-constants-max_json_depth"></a>

### `MAX_JSON_DEPTH`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const MAX_JSON_DEPTH: int = 64
```

JSON 清单允许的最大对象/数组嵌套深度。

## 方法

<a id="member-gftemplategenerationmanifest-methods-make_manifest"></a>

### `make_manifest`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func make_manifest( template_id: StringName, template_path: String, output_path: String, options: Dictionary = {} ) -> Dictionary:
```

创建模板生成清单。

参数：

| 名称 | 说明 |
|---|---|
| `template_id` | 稳定模板 ID。 |
| `template_path` | 模板资源路径。 |
| `output_path` | 生成产物输出路径。 |
| `options` | 清单选项，支持 generator_id、source_id、artifact_owner、variables、requirements 和 metadata。 |

返回：模板生成清单字典。

结构：

- `options`: Dictionary with generator_id, source_id, artifact_owner, variables, requirements, and metadata.
- `return`: Dictionary containing valid, status, template_id, template_path, output_path, generator_id, source_id, artifact_owner, variables, requirements, metadata, and errors.

<a id="member-gftemplategenerationmanifest-methods-from_dictionary"></a>

### `from_dictionary`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func from_dictionary(data: Dictionary, defaults: Dictionary = {}) -> Dictionary:
```

从字典创建模板生成清单。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 清单字段。 |
| `defaults` | 默认字段，data 会覆盖 defaults。 |

返回：模板生成清单字典。

结构：

- `data`: Dictionary manifest fields.
- `defaults`: Dictionary default manifest fields.
- `return`: Dictionary containing valid, status, template_id, template_path, output_path, generator_id, source_id, artifact_owner, variables, requirements, metadata, and errors.

<a id="member-gftemplategenerationmanifest-methods-from_json_text"></a>

### `from_json_text`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func from_json_text(text: String, defaults: Dictionary = {}) -> Dictionary:
```

从 JSON 文本创建模板生成清单。

参数：

| 名称 | 说明 |
|---|---|
| `text` | JSON 文本。 |
| `defaults` | 默认字段。 |

返回：模板生成清单字典。

结构：

- `defaults`: Dictionary default manifest fields.
- `return`: Dictionary containing valid, status, fields, and errors.

<a id="member-gftemplategenerationmanifest-methods-load_sidecar"></a>

### `load_sidecar`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func load_sidecar(sidecar_path: String, defaults: Dictionary = {}) -> Dictionary:
```

从 JSON sidecar 文件创建模板生成清单。

参数：

| 名称 | 说明 |
|---|---|
| `sidecar_path` | JSON sidecar 路径。 |
| `defaults` | 默认字段。 |

返回：模板生成清单字典。

结构：

- `defaults`: Dictionary default manifest fields.
- `return`: Dictionary containing valid, status, fields, sidecar_path, and errors.

<a id="member-gftemplategenerationmanifest-methods-validate_manifest"></a>

### `validate_manifest`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func validate_manifest(manifest: Dictionary) -> Dictionary:
```

校验模板生成清单。

参数：

| 名称 | 说明 |
|---|---|
| `manifest` | 待校验清单。 |

返回：校验后的清单副本。

结构：

- `manifest`: Dictionary manifest fields.
- `return`: Dictionary containing valid, status, and errors.

<a id="member-gftemplategenerationmanifest-methods-make_artifact_options"></a>

### `make_artifact_options`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func make_artifact_options(manifest: Dictionary, extra_options: Dictionary = {}) -> Dictionary:
```

从清单生成 GFGeneratedArtifactReport 保存选项。

参数：

| 名称 | 说明 |
|---|---|
| `manifest` | 模板生成清单。 |
| `extra_options` | 额外保存选项，会覆盖清单派生字段。 |

返回：保存选项字典。

结构：

- `manifest`: Dictionary returned by make_manifest().
- `extra_options`: Dictionary GFGeneratedArtifactReport.save_text() options.
- `return`: Dictionary with artifact_owner, generator_id, source_id, metadata, and caller extra options.

<a id="member-gftemplategenerationmanifest-methods-save_text_from_manifest"></a>

### `save_text_from_manifest`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func save_text_from_manifest(manifest: Dictionary, text: String, options: Dictionary = {}) -> Dictionary:
```

按清单保存文本产物。

参数：

| 名称 | 说明 |
|---|---|
| `manifest` | 模板生成清单。 |
| `text` | 要保存的文本。 |
| `options` | 额外保存选项。 |

返回：生成产物报告。

结构：

- `manifest`: Dictionary returned by make_manifest().
- `options`: Dictionary GFGeneratedArtifactReport.save_text() options.
- `return`: Dictionary returned by GFGeneratedArtifactReport.save_text().

<a id="member-gftemplategenerationmanifest-methods-summarize_manifests"></a>

### `summarize_manifests`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func summarize_manifests(manifests: Array[Dictionary], options: Dictionary = {}) -> Dictionary:
```

汇总多份模板生成清单。

参数：

| 名称 | 说明 |
|---|---|
| `manifests` | 清单数组。 |
| `options` | 汇总选项，支持 include_manifests 和 metadata；metadata 与可选 manifests 会在返回摘要中编码为 JSON-safe 值。 |

返回：清单摘要。

结构：

- `manifests`: Array[Dictionary] template generation manifests.
- `options`: Dictionary with include_manifests and metadata; metadata may contain arbitrary Variant values and is encoded with GFReportValueCodec in the returned summary.
- `return`: JSON-safe Dictionary containing valid, manifest_count, valid_count, invalid_count, template_ids, output_paths, errors, metadata, and optional manifests.
