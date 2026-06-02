# GFTagQuery

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/tags/gf_tag_query.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用标签查询资源。 使用 all/any/none 三组标签描述条件，可直接匹配标签集合、标签组件或普通数据。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`all_tags`](#member-gftagquery-properties-all_tags) | `var all_tags: Array[StringName] = []` |
| 属性 | [`any_tags`](#member-gftagquery-properties-any_tags) | `var any_tags: Array[StringName] = []` |
| 属性 | [`none_tags`](#member-gftagquery-properties-none_tags) | `var none_tags: Array[StringName] = []` |
| 属性 | [`include_child_tags`](#member-gftagquery-properties-include_child_tags) | `var include_child_tags: bool = false` |
| 方法 | [`is_empty`](#member-gftagquery-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`matches`](#member-gftagquery-methods-matches) | `func matches(source: Variant) -> bool:` |
| 方法 | [`get_match_report`](#member-gftagquery-methods-get_match_report) | `func get_match_report(source: Variant) -> Dictionary:` |
| 方法 | [`configure`](#member-gftagquery-methods-configure) | `func configure( required_all: Array[StringName] = [], required_any: Array[StringName] = [], rejected_none: Array[StringName] = [], hierarchical: bool = false ) -> GFTagQuery:` |
| 方法 | [`duplicate_query`](#member-gftagquery-methods-duplicate_query) | `func duplicate_query() -> GFTagQuery:` |
| 方法 | [`to_dictionary`](#member-gftagquery-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`from_dictionary`](#member-gftagquery-methods-from_dictionary) | `static func from_dictionary(data: Dictionary) -> GFTagQuery:` |

## 属性

<a id="member-gftagquery-properties-all_tags"></a>

### `all_tags`

- API：`public`

```gdscript
var all_tags: Array[StringName] = []
```

必须全部存在的标签。

<a id="member-gftagquery-properties-any_tags"></a>

### `any_tags`

- API：`public`

```gdscript
var any_tags: Array[StringName] = []
```

至少存在一个的标签；为空时跳过该条件。

<a id="member-gftagquery-properties-none_tags"></a>

### `none_tags`

- API：`public`

```gdscript
var none_tags: Array[StringName] = []
```

不允许存在的标签。

<a id="member-gftagquery-properties-include_child_tags"></a>

### `include_child_tags`

- API：`public`

```gdscript
var include_child_tags: bool = false
```

是否启用层级匹配。例如查询 `state` 时可匹配 `state.burning`。

## 方法

<a id="member-gftagquery-methods-is_empty"></a>

### `is_empty`

- API：`public`

```gdscript
func is_empty() -> bool:
```

检查查询是否为空。

返回：无任何条件时返回 true。

<a id="member-gftagquery-methods-matches"></a>

### `matches`

- API：`public`

```gdscript
func matches(source: Variant) -> bool:
```

匹配标签源。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 标签源。 |

返回：满足查询返回 true。

结构：

- `source`: Variant accepted by GFTagSourceAdapter.

<a id="member-gftagquery-methods-get_match_report"></a>

### `get_match_report`

- API：`public`

```gdscript
func get_match_report(source: Variant) -> Dictionary:
```

获取匹配报告。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 标签源。 |

返回：包含 ok、missing_all、missing_any、blocked_tags 的报告。

结构：

- `source`: Variant accepted by GFTagSourceAdapter.
- `return`: Dictionary with ok, missing_all, missing_any, blocked_tags, include_child_tags.

<a id="member-gftagquery-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure( required_all: Array[StringName] = [], required_any: Array[StringName] = [], rejected_none: Array[StringName] = [], hierarchical: bool = false ) -> GFTagQuery:
```

配置查询条件。

参数：

| 名称 | 说明 |
|---|---|
| `required_all` | 必须全部存在的标签。 |
| `required_any` | 至少存在一个的标签。 |
| `rejected_none` | 不允许存在的标签。 |
| `hierarchical` | 是否启用层级匹配。 |

返回：当前查询。

<a id="member-gftagquery-methods-duplicate_query"></a>

### `duplicate_query`

- API：`public`

```gdscript
func duplicate_query() -> GFTagQuery:
```

创建同内容拷贝。

返回：新查询。

<a id="member-gftagquery-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

导出为字典。

返回：查询字典。

结构：

- `return`: Dictionary serialized tag query.

<a id="member-gftagquery-methods-from_dictionary"></a>

### `from_dictionary`

- API：`public`

```gdscript
static func from_dictionary(data: Dictionary) -> GFTagQuery:
```

从字典创建查询。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 查询字典。 |

返回：新查询。

结构：

- `data`: Dictionary serialized tag query.
