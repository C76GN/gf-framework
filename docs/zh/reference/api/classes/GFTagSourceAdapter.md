# GFTagSourceAdapter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/tags/gf_tag_source_adapter.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用标签源适配器。 支持 GFTagSet、Array、PackedStringArray、Dictionary 以及具备 has_tag/get_tag_count/get_tags 方法的对象。它不维护全局标签表，也不规定标签语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`source_has_tag`](#member-gftagsourceadapter-methods-source_has_tag) | `static func source_has_tag( source: Variant, tag: StringName, minimum_count: int = 1, include_child_tags: bool = false ) -> bool:` |
| 方法 | [`get_tag_count`](#member-gftagsourceadapter-methods-get_tag_count) | `static func get_tag_count(source: Variant, tag: StringName, include_child_tags: bool = false) -> int:` |
| 方法 | [`get_tags`](#member-gftagsourceadapter-methods-get_tags) | `static func get_tags(source: Variant) -> PackedStringArray:` |
| 方法 | [`get_tag_counts`](#member-gftagsourceadapter-methods-get_tag_counts) | `static func get_tag_counts(source: Variant) -> Dictionary:` |
| 方法 | [`to_tag_set`](#member-gftagsourceadapter-methods-to_tag_set) | `static func to_tag_set(source: Variant) -> GFTagSet:` |
| 方法 | [`merge_sources`](#member-gftagsourceadapter-methods-merge_sources) | `static func merge_sources(sources: Array) -> GFTagSet:` |
| 方法 | [`matches_all`](#member-gftagsourceadapter-methods-matches_all) | `static func matches_all(source: Variant, tags: Array[StringName], include_child_tags: bool = false) -> bool:` |
| 方法 | [`matches_any`](#member-gftagsourceadapter-methods-matches_any) | `static func matches_any(source: Variant, tags: Array[StringName], include_child_tags: bool = false) -> bool:` |
| 方法 | [`matches_none`](#member-gftagsourceadapter-methods-matches_none) | `static func matches_none(source: Variant, tags: Array[StringName], include_child_tags: bool = false) -> bool:` |

## 方法

<a id="member-gftagsourceadapter-methods-source_has_tag"></a>

### `source_has_tag`

- API：`public`

```gdscript
static func source_has_tag( source: Variant, tag: StringName, minimum_count: int = 1, include_child_tags: bool = false ) -> bool:
```

检查标签源是否拥有指定标签。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 标签源。 |
| `tag` | 标签名。 |
| `minimum_count` | 要求的最小层数。 |
| `include_child_tags` | 为 true 时，\`state\` 可匹配 \`state.burning\`。 |

返回：满足要求返回 true。

结构：

- `source`: Variant tag source accepted by the adapter.

<a id="member-gftagsourceadapter-methods-get_tag_count"></a>

### `get_tag_count`

- API：`public`

```gdscript
static func get_tag_count(source: Variant, tag: StringName, include_child_tags: bool = false) -> int:
```

获取标签源中的标签层数。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 标签源。 |
| `tag` | 标签名。 |
| `include_child_tags` | 为 true 时合并子标签层数。 |

返回：标签层数。

结构：

- `source`: Variant tag source accepted by the adapter.

<a id="member-gftagsourceadapter-methods-get_tags"></a>

### `get_tags`

- API：`public`

```gdscript
static func get_tags(source: Variant) -> PackedStringArray:
```

获取标签源中的标签名。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 标签源。 |

返回：排序后的标签名。

结构：

- `source`: Variant tag source accepted by the adapter.

<a id="member-gftagsourceadapter-methods-get_tag_counts"></a>

### `get_tag_counts`

- API：`public`

```gdscript
static func get_tag_counts(source: Variant) -> Dictionary:
```

获取标签源中的标签层数字典。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 标签源。 |

返回：标签名到层数的字典。

结构：

- `source`: Variant tag source accepted by the adapter.
- `return`: Dictionary[StringName, int]，只包含层数大于 0 的标签。

<a id="member-gftagsourceadapter-methods-to_tag_set"></a>

### `to_tag_set`

- API：`public`

```gdscript
static func to_tag_set(source: Variant) -> GFTagSet:
```

将任意标签源规范化为 GFTagSet。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 标签源。 |

返回：新的标签集合。

结构：

- `source`: Variant tag source accepted by the adapter.

<a id="member-gftagsourceadapter-methods-merge_sources"></a>

### `merge_sources`

- API：`public`

```gdscript
static func merge_sources(sources: Array) -> GFTagSet:
```

合并多个标签源并返回新的 GFTagSet。

参数：

| 名称 | 说明 |
|---|---|
| `sources` | 标签源数组。 |

返回：合并后的标签集合。

结构：

- `sources`: Array[Variant]，每个元素都可被 GFTagSourceAdapter 读取。

<a id="member-gftagsourceadapter-methods-matches_all"></a>

### `matches_all`

- API：`public`

```gdscript
static func matches_all(source: Variant, tags: Array[StringName], include_child_tags: bool = false) -> bool:
```

检查标签源是否包含所有标签。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 标签源。 |
| `tags` | 需要全部满足的标签。 |
| `include_child_tags` | 是否启用层级匹配。 |

返回：全部满足返回 true。

结构：

- `source`: Variant tag source accepted by the adapter.

<a id="member-gftagsourceadapter-methods-matches_any"></a>

### `matches_any`

- API：`public`

```gdscript
static func matches_any(source: Variant, tags: Array[StringName], include_child_tags: bool = false) -> bool:
```

检查标签源是否包含任意标签。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 标签源。 |
| `tags` | 需要满足任意一个的标签；空数组返回 true。 |
| `include_child_tags` | 是否启用层级匹配。 |

返回：满足任意标签返回 true。

结构：

- `source`: Variant tag source accepted by the adapter.

<a id="member-gftagsourceadapter-methods-matches_none"></a>

### `matches_none`

- API：`public`

```gdscript
static func matches_none(source: Variant, tags: Array[StringName], include_child_tags: bool = false) -> bool:
```

检查标签源是否不包含任何禁止标签。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 标签源。 |
| `tags` | 禁止出现的标签。 |
| `include_child_tags` | 是否启用层级匹配。 |

返回：未命中禁止标签返回 true。

结构：

- `source`: Variant tag source accepted by the adapter.
