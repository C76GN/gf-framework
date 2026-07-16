# GFTagCatalog

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/tags/gf_tag_catalog.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`8.0.0`

可选标签目录与重定向资源。 用于声明项目可识别的标签、说明文本、迁移重定向和元数据。它只提供 定义校验和标签源规范化，不强制所有 GFTagSet 或 GFTagQuery 必须依赖全局目录。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`catalog_id`](#member-gftagcatalog-properties-catalog_id) | `var catalog_id: StringName = &""` |
| 属性 | [`tag_definitions`](#member-gftagcatalog-properties-tag_definitions) | `var tag_definitions: Array[Dictionary] = []` |
| 属性 | [`allow_undefined_tags`](#member-gftagcatalog-properties-allow_undefined_tags) | `var allow_undefined_tags: bool = true` |
| 属性 | [`metadata`](#member-gftagcatalog-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gftagcatalog-methods-configure) | `func configure( p_catalog_id: StringName, p_definitions: Array[Dictionary] = [], options: Dictionary = {} ) -> GFTagCatalog:` |
| 方法 | [`add_tag`](#member-gftagcatalog-methods-add_tag) | `func add_tag(tag: StringName, options: Dictionary = {}) -> bool:` |
| 方法 | [`add_redirect`](#member-gftagcatalog-methods-add_redirect) | `func add_redirect(source_tag: StringName, target_tag: StringName, options: Dictionary = {}) -> bool:` |
| 方法 | [`has_tag`](#member-gftagcatalog-methods-has_tag) | `func has_tag(tag: StringName, include_redirects: bool = true) -> bool:` |
| 方法 | [`get_tag_definition`](#member-gftagcatalog-methods-get_tag_definition) | `func get_tag_definition(tag: StringName, include_redirects: bool = true) -> Dictionary:` |
| 方法 | [`get_tags`](#member-gftagcatalog-methods-get_tags) | `func get_tags() -> PackedStringArray:` |
| 方法 | [`get_redirect_tags`](#member-gftagcatalog-methods-get_redirect_tags) | `func get_redirect_tags() -> PackedStringArray:` |
| 方法 | [`resolve_tag`](#member-gftagcatalog-methods-resolve_tag) | `func resolve_tag(tag: StringName, max_depth: int = 16) -> StringName:` |
| 方法 | [`normalize_tag_source`](#member-gftagcatalog-methods-normalize_tag_source) | `func normalize_tag_source(source: Variant, options: Dictionary = {}) -> GFTagSet:` |
| 方法 | [`validate_tag_source`](#member-gftagcatalog-methods-validate_tag_source) | `func validate_tag_source(source: Variant, options: Dictionary = {}) -> GFValidationReport:` |
| 方法 | [`validate_definition`](#member-gftagcatalog-methods-validate_definition) | `func validate_definition(options: Dictionary = {}) -> GFValidationReport:` |
| 方法 | [`duplicate_catalog`](#member-gftagcatalog-methods-duplicate_catalog) | `func duplicate_catalog() -> GFTagCatalog:` |
| 方法 | [`to_dictionary`](#member-gftagcatalog-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`from_dictionary`](#member-gftagcatalog-methods-from_dictionary) | `static func from_dictionary(data: Dictionary) -> GFTagCatalog:` |

## 属性

<a id="member-gftagcatalog-properties-catalog_id"></a>

### `catalog_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var catalog_id: StringName = &""
```

目录标识。为空时调用方可自行决定报告主题。

<a id="member-gftagcatalog-properties-tag_definitions"></a>

### `tag_definitions`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var tag_definitions: Array[Dictionary] = []
```

标签定义列表。 每项是 Dictionary，至少包含 tag，可选 redirect_to、description 和 metadata。

结构：

- `tag_definitions`: Array[Dictionary]，每项包含 tag: StringName/String、redirect_to: StringName/String、description: String、metadata: Dictionary。

<a id="member-gftagcatalog-properties-allow_undefined_tags"></a>

### `allow_undefined_tags`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var allow_undefined_tags: bool = true
```

校验标签源时是否允许目录外标签。

<a id="member-gftagcatalog-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata: Dictionary = {}
```

目录元数据。GF 不解释其中业务字段。

结构：

- `metadata`: Dictionary caller-defined catalog metadata.

## 方法

<a id="member-gftagcatalog-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure( p_catalog_id: StringName, p_definitions: Array[Dictionary] = [], options: Dictionary = {} ) -> GFTagCatalog:
```

配置标签目录。

参数：

| 名称 | 说明 |
|---|---|
| `p_catalog_id` | 目录标识。 |
| `p_definitions` | 标签定义列表。 |
| `options` | 可选配置，支持 allow_undefined_tags 和 metadata。 |

返回：当前目录。

结构：

- `p_definitions`: Array[Dictionary] 标签定义列表。
- `options`: Dictionary catalog options.

<a id="member-gftagcatalog-methods-add_tag"></a>

### `add_tag`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func add_tag(tag: StringName, options: Dictionary = {}) -> bool:
```

添加标签定义。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 标签名。 |
| `options` | 定义选项，支持 redirect_to、description 和 metadata。 |

返回：添加成功返回 true。

结构：

- `options`: Dictionary tag definition options.

<a id="member-gftagcatalog-methods-add_redirect"></a>

### `add_redirect`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func add_redirect(source_tag: StringName, target_tag: StringName, options: Dictionary = {}) -> bool:
```

添加标签重定向定义。

参数：

| 名称 | 说明 |
|---|---|
| `source_tag` | 旧标签名。 |
| `target_tag` | 目标标签名。 |
| `options` | 定义选项，支持 description 和 metadata。 |

返回：添加成功返回 true。

结构：

- `options`: Dictionary redirect definition options.

<a id="member-gftagcatalog-methods-has_tag"></a>

### `has_tag`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_tag(tag: StringName, include_redirects: bool = true) -> bool:
```

检查目录中是否声明了标签。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 标签名。 |
| `include_redirects` | 是否把重定向源也视作已声明。 |

返回：已声明返回 true。

<a id="member-gftagcatalog-methods-get_tag_definition"></a>

### `get_tag_definition`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_tag_definition(tag: StringName, include_redirects: bool = true) -> Dictionary:
```

获取标签定义。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 标签名。 |
| `include_redirects` | 是否允许返回重定向源定义。 |

返回：定义副本；未声明时返回空 Dictionary。

结构：

- `return`: Dictionary tag definition.

<a id="member-gftagcatalog-methods-get_tags"></a>

### `get_tags`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_tags() -> PackedStringArray:
```

获取所有正式标签名。

返回：排序后的标签名，不包含重定向源。

<a id="member-gftagcatalog-methods-get_redirect_tags"></a>

### `get_redirect_tags`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_redirect_tags() -> PackedStringArray:
```

获取所有重定向源标签。

返回：排序后的重定向源标签。

<a id="member-gftagcatalog-methods-resolve_tag"></a>

### `resolve_tag`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func resolve_tag(tag: StringName, max_depth: int = 16) -> StringName:
```

解析标签重定向。 连续重定向会被追踪到最终目标；遇到循环或空标签时返回原始标签。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 原始标签。 |
| `max_depth` | 最大重定向层数。 |

返回：解析后的标签。

<a id="member-gftagcatalog-methods-normalize_tag_source"></a>

### `normalize_tag_source`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func normalize_tag_source(source: Variant, options: Dictionary = {}) -> GFTagSet:
```

规范化标签源。 会读取任意 GFTagSourceAdapter 支持的来源，解析重定向并合并重复标签层数。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 标签源。 |
| `options` | 规范化选项，支持 drop_undefined 和 max_redirect_depth。 |

返回：新的标签集合。

结构：

- `source`: Variant accepted by GFTagSourceAdapter.
- `options`: Dictionary normalization options.

<a id="member-gftagcatalog-methods-validate_tag_source"></a>

### `validate_tag_source`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func validate_tag_source(source: Variant, options: Dictionary = {}) -> GFValidationReport:
```

校验标签源是否满足目录声明。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 标签源。 |
| `options` | 校验选项，支持 subject、allow_undefined_tags 和 max_redirect_depth。 |

返回：校验报告。

结构：

- `source`: Variant accepted by GFTagSourceAdapter.
- `options`: Dictionary validation options.

<a id="member-gftagcatalog-methods-validate_definition"></a>

### `validate_definition`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func validate_definition(options: Dictionary = {}) -> GFValidationReport:
```

校验目录定义自身。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 校验选项，支持 subject。 |

返回：校验报告。

结构：

- `options`: Dictionary validation options.

<a id="member-gftagcatalog-methods-duplicate_catalog"></a>

### `duplicate_catalog`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_catalog() -> GFTagCatalog:
```

创建同内容拷贝。

返回：新标签目录。

<a id="member-gftagcatalog-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dictionary() -> Dictionary:
```

导出为字典。

返回：标签目录字典。

结构：

- `return`: Dictionary serialized tag catalog.

<a id="member-gftagcatalog-methods-from_dictionary"></a>

### `from_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dictionary(data: Dictionary) -> GFTagCatalog:
```

从字典创建标签目录。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 标签目录字典。 |

返回：新标签目录。

结构：

- `data`: Dictionary serialized tag catalog.
