# GFAssetAttributionTools

[API Reference](../index.md) / [Asset Metadata](../extensions-asset-metadata.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/asset_metadata/runtime/gf_asset_attribution_tools.gd`
- 模块：`Asset Metadata`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

资产授权与署名元数据工具。 提供纯数据归一、路径覆盖检查和通知文本格式化，便于项目导入管线、CI 或 Credits 页面复用同一套资产归因字段约定。它不内置许可证模板、不下载外部数据， 也不替项目做法律判断。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`normalize_attribution`](#member-gfassetattributiontools-methods-normalize_attribution) | `static func normalize_attribution(data: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`resolve_attribution`](#member-gfassetattributiontools-methods-resolve_attribution) | `static func resolve_attribution(path: String, entries: Array, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`build_attribution_report`](#member-gfassetattributiontools-methods-build_attribution_report) | `static func build_attribution_report( entries: Array, resource_paths: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`format_notice_text`](#member-gfassetattributiontools-methods-format_notice_text) | `static func format_notice_text(report: Dictionary, options: Dictionary = {}) -> String:` |

## 方法

<a id="member-gfassetattributiontools-methods-normalize_attribution"></a>

### `normalize_attribution`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func normalize_attribution(data: Dictionary, options: Dictionary = {}) -> Dictionary:
```

将资产归因字典归一为稳定字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 输入归因字典；也可传入 GFAssetMetadataRecord.to_dict() 形状的字典。 |
| `options` | 可选项，支持 attribution_key。 |

返回：归一化归因条目。

结构：

- `data`: Dictionary，可包含 path/resource_path/source_path、license_id/license、title/name、creator/author、source_url/source、notice、copyright、metadata 或 metadata.attribution。
- `options`: Dictionary，可包含 attribution_key 字段；默认为 attribution。
- `return`: Dictionary，包含 path、license_id、title、creator、source_url、notice、copyright、metadata、subject_path 与 subject_kind 字段。

<a id="member-gfassetattributiontools-methods-resolve_attribution"></a>

### `resolve_attribution`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func resolve_attribution(path: String, entries: Array, options: Dictionary = {}) -> Dictionary:
```

按资源路径解析最匹配的归因条目。 精确路径优先；inherit_from_parent 为 true 时，父目录归因可覆盖其子资源。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 要解析的资源路径。 |
| `entries` | 归因条目数组；每项可为 Dictionary 或 GFAssetMetadataRecord。 |
| `options` | 可选项，支持 inherit_from_parent 与 attribution_key。 |

返回：解析结果。

结构：

- `entries`: Array，每项可为归因 Dictionary、GFAssetMetadataRecord 或 GFAssetMetadataRecord.to_dict() 形状字典。
- `options`: Dictionary，可包含 inherit_from_parent 和 attribution_key。
- `return`: Dictionary，包含 found、path、attribution_path、inherited、inherited_from 和 entry 字段。

<a id="member-gfassetattributiontools-methods-build_attribution_report"></a>

### `build_attribution_report`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func build_attribution_report( entries: Array, resource_paths: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> Dictionary:
```

构建资产归因覆盖报告。 传入 resource_paths 时，报告会检查每个资源路径是否能命中归因条目。 缺少 path、重复 path、缺少 license_id 或未覆盖资源路径都会作为错误报告。

参数：

| 名称 | 说明 |
|---|---|
| `entries` | 归因条目数组；每项可为 Dictionary 或 GFAssetMetadataRecord。 |
| `resource_paths` | 需要被归因覆盖的资源路径。 |
| `options` | 可选项，支持 require_license_id、inherit_from_parent 与 attribution_key。 |

返回：GFValidationReport 兼容字典，并附带 entries、covered_paths、uncovered_paths 和 license_ids。

结构：

- `entries`: Array，每项可为归因 Dictionary、GFAssetMetadataRecord 或 GFAssetMetadataRecord.to_dict() 形状字典。
- `resource_paths`: PackedStringArray，通常来自资源扫描或导入计划。
- `options`: Dictionary，可包含 require_license_id、inherit_from_parent 和 attribution_key。
- `return`: Dictionary，包含 ok、healthy、summary、entries、entry_count、resource_path_count、covered_paths、uncovered_paths、license_ids 等字段。

<a id="member-gfassetattributiontools-methods-format_notice_text"></a>

### `format_notice_text`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func format_notice_text(report: Dictionary, options: Dictionary = {}) -> String:
```

将归因报告格式化为稳定的通知文本。 该方法只输出条目摘要，不注入许可证全文；项目应自行决定最终 Credits 或 NOTICE 格式。

参数：

| 名称 | 说明 |
|---|---|
| `report` | build_attribution_report() 返回的报告字典。 |
| `options` | 可选项，支持 title 与 include_paths。 |

返回：通知文本。

结构：

- `report`: Dictionary，包含 entries 字段的归因报告。
- `options`: Dictionary，可包含 title 和 include_paths。
