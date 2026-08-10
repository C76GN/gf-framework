# GFTagSet

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/tags/gf_tag_set.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用标签集合资源。 只维护标签到层数的映射，不规定标签命名、业务含义或全局注册表。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`tag_counts`](#member-gftagset-properties-tag_counts) | `var tag_counts: Dictionary = {}` |
| 方法 | [`set_tags`](#member-gftagset-methods-set_tags) | `func set_tags(source_tags: Variant) -> GFTagSet:` |
| 方法 | [`add_tag`](#member-gftagset-methods-add_tag) | `func add_tag(tag: StringName, count: int = 1) -> GFTagSet:` |
| 方法 | [`remove_tag`](#member-gftagset-methods-remove_tag) | `func remove_tag(tag: StringName, count: int = 1) -> GFTagSet:` |
| 方法 | [`has_tag`](#member-gftagset-methods-has_tag) | `func has_tag(tag: StringName, minimum_count: int = 1, include_child_tags: bool = false) -> bool:` |
| 方法 | [`get_tag_count`](#member-gftagset-methods-get_tag_count) | `func get_tag_count(tag: StringName, include_child_tags: bool = false) -> int:` |
| 方法 | [`get_tags`](#member-gftagset-methods-get_tags) | `func get_tags() -> PackedStringArray:` |
| 方法 | [`get_tag_counts`](#member-gftagset-methods-get_tag_counts) | `func get_tag_counts() -> Dictionary:` |
| 方法 | [`clear`](#member-gftagset-methods-clear) | `func clear() -> void:` |
| 方法 | [`duplicate_set`](#member-gftagset-methods-duplicate_set) | `func duplicate_set() -> GFTagSet:` |
| 方法 | [`to_dictionary`](#member-gftagset-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`from_dictionary`](#member-gftagset-methods-from_dictionary) | `static func from_dictionary(data: Dictionary) -> GFTagSet:` |

## 属性

<a id="member-gftagset-properties-tag_counts"></a>

### `tag_counts`

- API：`public`

```gdscript
var tag_counts: Dictionary = {}
```

标签层数字典。键建议使用 StringName，值为正整数层数。

结构：

- `tag_counts`: Dictionary mapping tag names to positive integer counts.

## 方法

<a id="member-gftagset-methods-set_tags"></a>

### `set_tags`

- API：`public`

```gdscript
func set_tags(source_tags: Variant) -> GFTagSet:
```

清空并设置标签集合。

参数：

| 名称 | 说明 |
|---|---|
| `source_tags` | Array、PackedStringArray 或 Dictionary 标签数据。 |

返回：当前标签集合。

结构：

- `source_tags`: Variant tag source accepted as Array, PackedStringArray, or Dictionary.

<a id="member-gftagset-methods-add_tag"></a>

### `add_tag`

- API：`public`

```gdscript
func add_tag(tag: StringName, count: int = 1) -> GFTagSet:
```

添加标签层数。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 标签名。 |
| `count` | 增加层数。 |

返回：当前标签集合。

<a id="member-gftagset-methods-remove_tag"></a>

### `remove_tag`

- API：`public`

```gdscript
func remove_tag(tag: StringName, count: int = 1) -> GFTagSet:
```

移除标签层数。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 标签名。 |
| `count` | 移除层数；-1 表示完全移除。 |

返回：当前标签集合。

<a id="member-gftagset-methods-has_tag"></a>

### `has_tag`

- API：`public`

```gdscript
func has_tag(tag: StringName, minimum_count: int = 1, include_child_tags: bool = false) -> bool:
```

检查是否拥有指定标签且层数达到要求。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 标签名。 |
| `minimum_count` | 要求的最小层数。 |
| `include_child_tags` | 为 true 时，\`state\` 可匹配 \`state.burning\`。 |

返回：满足要求返回 true。

<a id="member-gftagset-methods-get_tag_count"></a>

### `get_tag_count`

- API：`public`

```gdscript
func get_tag_count(tag: StringName, include_child_tags: bool = false) -> int:
```

获取标签层数。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 标签名。 |
| `include_child_tags` | 为 true 时合并子标签层数。 |

返回：标签层数。

<a id="member-gftagset-methods-get_tags"></a>

### `get_tags`

- API：`public`

```gdscript
func get_tags() -> PackedStringArray:
```

获取所有标签名。

返回：排序后的标签名。

<a id="member-gftagset-methods-get_tag_counts"></a>

### `get_tag_counts`

- API：`public`

```gdscript
func get_tag_counts() -> Dictionary:
```

获取标签层数字典副本。

返回：标签层数字典。

结构：

- `return`: Dictionary mapping tag names to positive integer counts.

<a id="member-gftagset-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空标签集合。

<a id="member-gftagset-methods-duplicate_set"></a>

### `duplicate_set`

- API：`public`

```gdscript
func duplicate_set() -> GFTagSet:
```

创建同内容拷贝。

返回：新标签集合。

<a id="member-gftagset-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

导出为字典。

返回：标签集合字典。

结构：

- `return`: Dictionary serialized tag set.

<a id="member-gftagset-methods-from_dictionary"></a>

### `from_dictionary`

- API：`public`

```gdscript
static func from_dictionary(data: Dictionary) -> GFTagSet:
```

从字典创建标签集合。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 标签集合字典。 |

返回：新标签集合。

结构：

- `data`: Dictionary serialized tag set or tag count map.
