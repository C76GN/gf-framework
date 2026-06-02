# GFTagComponent

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/tags/gf_tag_component.gd`
- 模块：`Combat`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

标签组件。 基于 StringName 管理实体的标签及层数（如 &"State.Stun", &"Element.Fire"）。 标签系统通常用于技能释放前提检查、伤害加成判定等。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`tag_changed`](#member-gftagcomponent-signals-tag_changed) | `signal tag_changed(tag_name: StringName, count: int)` |
| 方法 | [`add_tag`](#member-gftagcomponent-methods-add_tag) | `func add_tag(p_tag: StringName, p_count: int = 1) -> void:` |
| 方法 | [`remove_tag`](#member-gftagcomponent-methods-remove_tag) | `func remove_tag(p_tag: StringName, p_count: int = 1) -> void:` |
| 方法 | [`has_tag`](#member-gftagcomponent-methods-has_tag) | `func has_tag(p_tag: StringName, p_min_count: int = 1) -> bool:` |
| 方法 | [`get_tag_count`](#member-gftagcomponent-methods-get_tag_count) | `func get_tag_count(p_tag: StringName) -> int:` |
| 方法 | [`get_tags`](#member-gftagcomponent-methods-get_tags) | `func get_tags() -> PackedStringArray:` |
| 方法 | [`get_tag_snapshot`](#member-gftagcomponent-methods-get_tag_snapshot) | `func get_tag_snapshot() -> Dictionary:` |
| 方法 | [`clear_all`](#member-gftagcomponent-methods-clear_all) | `func clear_all() -> void:` |

## 信号

<a id="member-gftagcomponent-signals-tag_changed"></a>

### `tag_changed`

- API：`public`

```gdscript
signal tag_changed(tag_name: StringName, count: int)
```

当标签层数发生变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `tag_name` | 标签名。 |
| `count` | 变化后的最终层数。 |

## 方法

<a id="member-gftagcomponent-methods-add_tag"></a>

### `add_tag`

- API：`public`

```gdscript
func add_tag(p_tag: StringName, p_count: int = 1) -> void:
```

添加标签。

参数：

| 名称 | 说明 |
|---|---|
| `p_tag` | 标签名。 |
| `p_count` | 增加的层数。 |

<a id="member-gftagcomponent-methods-remove_tag"></a>

### `remove_tag`

- API：`public`

```gdscript
func remove_tag(p_tag: StringName, p_count: int = 1) -> void:
```

移除标签或减少层数。

参数：

| 名称 | 说明 |
|---|---|
| `p_tag` | 标签名。 |
| `p_count` | 减少的层数，如果为 -1 则直接完全移除。 |

<a id="member-gftagcomponent-methods-has_tag"></a>

### `has_tag`

- API：`public`

```gdscript
func has_tag(p_tag: StringName, p_min_count: int = 1) -> bool:
```

检查是否拥有指定标签且层数达到要求。

参数：

| 名称 | 说明 |
|---|---|
| `p_tag` | 标签名。 |
| `p_min_count` | 要求的最小层数。 |

返回：拥有指定标签且层数不低于要求时返回 true。

<a id="member-gftagcomponent-methods-get_tag_count"></a>

### `get_tag_count`

- API：`public`

```gdscript
func get_tag_count(p_tag: StringName) -> int:
```

获取标签的当前层数。

参数：

| 名称 | 说明 |
|---|---|
| `p_tag` | 标签名。 |

返回：当前标签层数；不存在时返回 0。

<a id="member-gftagcomponent-methods-get_tags"></a>

### `get_tags`

- API：`public`

```gdscript
func get_tags() -> PackedStringArray:
```

获取当前持有的标签名。

返回：排序后的标签名。

<a id="member-gftagcomponent-methods-get_tag_snapshot"></a>

### `get_tag_snapshot`

- API：`public`

```gdscript
func get_tag_snapshot() -> Dictionary:
```

获取标签层数快照。

返回：标签层数字典副本。

结构：

- `return`: Dictionary，键为标签名，值为当前层数。

<a id="member-gftagcomponent-methods-clear_all"></a>

### `clear_all`

- API：`public`

```gdscript
func clear_all() -> void:
```

清空所有标签。
