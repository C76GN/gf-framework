# GFReadOnlyBindableProperty

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_read_only_bindable_property.gd`
- 模块：`Kernel`
- 继承：`GFBindableProperty`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

只读响应式属性视图。 复用 `GFBindableProperty` 的读取、信号和生命周期绑定能力， 但阻止外部直接调用 `set_value()` 修改底层值。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`_init`](#member-gfreadonlybindableproperty-methods-_init) | `func _init(default_value: Variant = null) -> void:` |
| 方法 | [`set_value`](#member-gfreadonlybindableproperty-methods-set_value) | `func set_value(_new_value: Variant) -> void:` |
| 方法 | [`mutate`](#member-gfreadonlybindableproperty-methods-mutate) | `func mutate(_mutator: Callable) -> bool:` |
| 方法 | [`append_to_array`](#member-gfreadonlybindableproperty-methods-append_to_array) | `func append_to_array(_item: Variant) -> bool:` |
| 方法 | [`append_array`](#member-gfreadonlybindableproperty-methods-append_array) | `func append_array(_items: Array) -> bool:` |
| 方法 | [`erase_from_array`](#member-gfreadonlybindableproperty-methods-erase_from_array) | `func erase_from_array(_item: Variant) -> bool:` |
| 方法 | [`set_dictionary_value`](#member-gfreadonlybindableproperty-methods-set_dictionary_value) | `func set_dictionary_value(_key: Variant, _new_value: Variant) -> bool:` |
| 方法 | [`erase_dictionary_key`](#member-gfreadonlybindableproperty-methods-erase_dictionary_key) | `func erase_dictionary_key(_key: Variant) -> bool:` |
| 方法 | [`clear_collection`](#member-gfreadonlybindableproperty-methods-clear_collection) | `func clear_collection() -> bool:` |

## 方法

<a id="member-gfreadonlybindableproperty-methods-_init"></a>

### `_init`

- API：`public`

```gdscript
func _init(default_value: Variant = null) -> void:
```

构造函数。 "type": "Variant", "description": "属性的初始值。" }

参数：

| 名称 | 说明 |
|---|---|
| `default_value` | 属性的初始值。 |

结构：

- `default_value {`:

<a id="member-gfreadonlybindableproperty-methods-set_value"></a>

### `set_value`

- API：`public`

```gdscript
func set_value(_new_value: Variant) -> void:
```

只读视图不允许外部直接写入值。 "type": "Variant", "description": "调用方尝试写入的新值。" }

参数：

| 名称 | 说明 |
|---|---|
| `_new_value` | 调用方尝试写入的新值。 |

结构：

- `_new_value {`:

<a id="member-gfreadonlybindableproperty-methods-mutate"></a>

### `mutate`

- API：`public`

```gdscript
func mutate(_mutator: Callable) -> bool:
```

只读视图不允许外部原地修改值。

参数：

| 名称 | 说明 |
|---|---|
| `_mutator` | 调用方尝试执行的修改回调。 |

返回：始终返回 false。

<a id="member-gfreadonlybindableproperty-methods-append_to_array"></a>

### `append_to_array`

- API：`public`

```gdscript
func append_to_array(_item: Variant) -> bool:
```

只读视图不允许外部向数组追加元素。 "type": "Variant", "description": "调用方尝试追加的元素。" }

参数：

| 名称 | 说明 |
|---|---|
| `_item` | 调用方尝试追加的元素。 |

返回：始终返回 false。

结构：

- `_item {`:

<a id="member-gfreadonlybindableproperty-methods-append_array"></a>

### `append_array`

- API：`public`

```gdscript
func append_array(_items: Array) -> bool:
```

只读视图不允许外部向数组追加元素列表。 "type": "Array", "description": "调用方尝试追加的元素列表。" }

参数：

| 名称 | 说明 |
|---|---|
| `_items` | 调用方尝试追加的元素列表。 |

返回：始终返回 false。

结构：

- `_items {`:

<a id="member-gfreadonlybindableproperty-methods-erase_from_array"></a>

### `erase_from_array`

- API：`public`

```gdscript
func erase_from_array(_item: Variant) -> bool:
```

只读视图不允许外部从数组删除元素。 "type": "Variant", "description": "调用方尝试删除的元素。" }

参数：

| 名称 | 说明 |
|---|---|
| `_item` | 调用方尝试删除的元素。 |

返回：始终返回 false。

结构：

- `_item {`:

<a id="member-gfreadonlybindableproperty-methods-set_dictionary_value"></a>

### `set_dictionary_value`

- API：`public`

```gdscript
func set_dictionary_value(_key: Variant, _new_value: Variant) -> bool:
```

只读视图不允许外部设置字典键值。 "type": "Variant", "description": "调用方尝试设置的键。" } "type": "Variant", "description": "调用方尝试设置的新值。" }

参数：

| 名称 | 说明 |
|---|---|
| `_key` | 调用方尝试设置的键。 |
| `_new_value` | 调用方尝试设置的新值。 |

返回：始终返回 false。

结构：

- `_key {`:
- `_new_value {`:

<a id="member-gfreadonlybindableproperty-methods-erase_dictionary_key"></a>

### `erase_dictionary_key`

- API：`public`

```gdscript
func erase_dictionary_key(_key: Variant) -> bool:
```

只读视图不允许外部删除字典键。 "type": "Variant", "description": "调用方尝试删除的键。" }

参数：

| 名称 | 说明 |
|---|---|
| `_key` | 调用方尝试删除的键。 |

返回：始终返回 false。

结构：

- `_key {`:

<a id="member-gfreadonlybindableproperty-methods-clear_collection"></a>

### `clear_collection`

- API：`public`

```gdscript
func clear_collection() -> bool:
```

只读视图不允许外部清空集合。

返回：始终返回 false。
