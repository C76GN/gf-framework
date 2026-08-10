# GFContentPackageQuery

[API Reference](../index.md) / [Extensions / Content Package](../extensions-content-package.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/content_package/resources/gf_content_package_query.gd`
- 模块：`Extensions / Content Package`
- 继承：`Resource`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`10.0.0`

内容包目录的确定性通用查询条件。 查询只描述 package、content type、依赖、资源键、安全分类和 metadata 约束， 不解释项目业务语义。所有非空条件采用 AND 语义，列表条件要求 manifest 包含全部值。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`query_id`](#member-gfcontentpackagequery-properties-query_id) | `var query_id: StringName = &""` |
| 属性 | [`package_ids`](#member-gfcontentpackagequery-properties-package_ids) | `var package_ids: PackedStringArray = PackedStringArray()` |
| 属性 | [`search_text`](#member-gfcontentpackagequery-properties-search_text) | `var search_text: String = ""` |
| 属性 | [`required_content_types`](#member-gfcontentpackagequery-properties-required_content_types) | `var required_content_types: PackedStringArray = PackedStringArray()` |
| 属性 | [`required_dependencies`](#member-gfcontentpackagequery-properties-required_dependencies) | `var required_dependencies: PackedStringArray = PackedStringArray()` |
| 属性 | [`required_resource_keys`](#member-gfcontentpackagequery-properties-required_resource_keys) | `var required_resource_keys: PackedStringArray = PackedStringArray()` |
| 属性 | [`allowed_safety_kinds`](#member-gfcontentpackagequery-properties-allowed_safety_kinds) | `var allowed_safety_kinds: PackedStringArray = PackedStringArray()` |
| 属性 | [`required_metadata`](#member-gfcontentpackagequery-properties-required_metadata) | `var required_metadata: Dictionary = {}` |
| 属性 | [`include_dependencies`](#member-gfcontentpackagequery-properties-include_dependencies) | `var include_dependencies: bool = false` |
| 属性 | [`max_results`](#member-gfcontentpackagequery-properties-max_results) | `var max_results: int = 0` |
| 属性 | [`metadata`](#member-gfcontentpackagequery-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`matches`](#member-gfcontentpackagequery-methods-matches) | `func matches(manifest: GFContentPackageManifest) -> bool:` |
| 方法 | [`apply_dict`](#member-gfcontentpackagequery-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`to_dict`](#member-gfcontentpackagequery-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`to_report_dictionary`](#member-gfcontentpackagequery-methods-to_report_dictionary) | `func to_report_dictionary(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`duplicate_query`](#member-gfcontentpackagequery-methods-duplicate_query) | `func duplicate_query() -> GFContentPackageQuery:` |
| 方法 | [`from_dict`](#member-gfcontentpackagequery-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFContentPackageQuery:` |

## 属性

<a id="member-gfcontentpackagequery-properties-query_id"></a>

### `query_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var query_id: StringName = &""
```

查询稳定标识，仅用于诊断和追踪。

<a id="member-gfcontentpackagequery-properties-package_ids"></a>

### `package_ids`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var package_ids: PackedStringArray = PackedStringArray()
```

允许返回的 package ID；为空表示不限制。

<a id="member-gfcontentpackagequery-properties-search_text"></a>

### `search_text`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var search_text: String = ""
```

在 package ID、显示名、版本和 content type 中匹配的大小写无关文本。

<a id="member-gfcontentpackagequery-properties-required_content_types"></a>

### `required_content_types`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var required_content_types: PackedStringArray = PackedStringArray()
```

manifest 必须包含的全部 content type。

<a id="member-gfcontentpackagequery-properties-required_dependencies"></a>

### `required_dependencies`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var required_dependencies: PackedStringArray = PackedStringArray()
```

manifest 必须声明的全部直接依赖 ID。

<a id="member-gfcontentpackagequery-properties-required_resource_keys"></a>

### `required_resource_keys`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var required_resource_keys: PackedStringArray = PackedStringArray()
```

manifest 必须声明的全部资源键。

<a id="member-gfcontentpackagequery-properties-allowed_safety_kinds"></a>

### `allowed_safety_kinds`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var allowed_safety_kinds: PackedStringArray = PackedStringArray()
```

允许的安全分类；为空表示不限制。

<a id="member-gfcontentpackagequery-properties-required_metadata"></a>

### `required_metadata`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var required_metadata: Dictionary = {}
```

manifest metadata 必须精确匹配的键值。

结构：

- `required_metadata`: Dictionary with exact manifest metadata key/value filters.

<a id="member-gfcontentpackagequery-properties-include_dependencies"></a>

### `include_dependencies`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var include_dependencies: bool = false
```

是否把直接命中包的传递依赖加入结果。

<a id="member-gfcontentpackagequery-properties-max_results"></a>

### `max_results`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var max_results: int = 0
```

直接命中包的最大数量；小于等于 0 表示不限制。依赖闭包不计入该限制。

<a id="member-gfcontentpackagequery-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义查询元数据；GF 只负责复制和序列化。

结构：

- `metadata`: Dictionary with caller-defined query metadata.

## 方法

<a id="member-gfcontentpackagequery-methods-matches"></a>

### `matches`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func matches(manifest: GFContentPackageManifest) -> bool:
```

检查 manifest 是否满足全部非空查询条件。

参数：

| 名称 | 说明 |
|---|---|
| `manifest` | 要检查的内容包 manifest。 |

返回：满足查询条件返回 true。

<a id="member-gfcontentpackagequery-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用查询字段并执行集合归一化。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 查询字典。 |

结构：

- `data`: Dictionary with query_id, package_ids, search_text, required_content_types, required_dependencies, required_resource_keys, allowed_safety_kinds, required_metadata, include_dependencies, max_results, and metadata.

<a id="member-gfcontentpackagequery-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为归一化字典。

返回：查询字典副本。

结构：

- `return`: Dictionary with query_id, package_ids, search_text, required_content_types, required_dependencies, required_resource_keys, allowed_safety_kinds, required_metadata, include_dependencies, max_results, and metadata.

<a id="member-gfcontentpackagequery-methods-to_report_dictionary"></a>

### `to_report_dictionary`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_report_dictionary(options: Dictionary = {}) -> Dictionary:
```

转换为 JSON-safe 报告字典。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 传给 GFReportValueCodec 的编码选项。 |

返回：查询报告字典。

结构：

- `options`: Dictionary with GFReportValueCodec encoding options.
- `return`: JSON-safe Dictionary based on the normalized query state.

<a id="member-gfcontentpackagequery-methods-duplicate_query"></a>

### `duplicate_query`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func duplicate_query() -> GFContentPackageQuery:
```

创建查询深拷贝。

返回：新查询。

<a id="member-gfcontentpackagequery-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFContentPackageQuery:
```

从字典创建查询。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 查询字典。 |

返回：新查询。

结构：

- `data`: Dictionary with query_id, package_ids, search_text, required_content_types, required_dependencies, required_resource_keys, allowed_safety_kinds, required_metadata, include_dependencies, max_results, and metadata.
