# GFComputedProperty

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_computed_property.gd`
- 模块：`Kernel`
- 继承：`GFBindableProperty`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

由多个 GFBindableProperty 派生的只读响应式属性。 通过 compute 回调计算自身值，并在任一来源属性变化时自动刷新。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`bind_sources`](#member-gfcomputedproperty-methods-bind_sources) | `func bind_sources( sources: Array[GFBindableProperty], compute: Callable, owner: Node = null, run_immediately: bool = true ) -> void:` |
| 方法 | [`stop`](#member-gfcomputedproperty-methods-stop) | `func stop() -> void:` |
| 方法 | [`dispose`](#member-gfcomputedproperty-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`set_value`](#member-gfcomputedproperty-methods-set_value) | `func set_value(_new_value: Variant) -> void:` |
| 方法 | [`mutate`](#member-gfcomputedproperty-methods-mutate) | `func mutate(_mutator: Callable) -> bool:` |
| 方法 | [`append_to_array`](#member-gfcomputedproperty-methods-append_to_array) | `func append_to_array(_item: Variant) -> bool:` |
| 方法 | [`append_array`](#member-gfcomputedproperty-methods-append_array) | `func append_array(_items: Array) -> bool:` |
| 方法 | [`erase_from_array`](#member-gfcomputedproperty-methods-erase_from_array) | `func erase_from_array(_item: Variant) -> bool:` |
| 方法 | [`set_dictionary_value`](#member-gfcomputedproperty-methods-set_dictionary_value) | `func set_dictionary_value(_key: Variant, _new_value: Variant) -> bool:` |
| 方法 | [`erase_dictionary_key`](#member-gfcomputedproperty-methods-erase_dictionary_key) | `func erase_dictionary_key(_key: Variant) -> bool:` |
| 方法 | [`clear_collection`](#member-gfcomputedproperty-methods-clear_collection) | `func clear_collection() -> bool:` |
| 方法 | [`is_computing`](#member-gfcomputedproperty-methods-is_computing) | `func is_computing() -> bool:` |

## 方法

<a id="member-gfcomputedproperty-methods-bind_sources"></a>

### `bind_sources`

- API：`public`

```gdscript
func bind_sources( sources: Array[GFBindableProperty], compute: Callable, owner: Node = null, run_immediately: bool = true ) -> void:
```

绑定来源属性与计算回调。重复调用会替换旧绑定。

参数：

| 名称 | 说明 |
|---|---|
| `sources` | 要监听的 GFBindableProperty 列表。 |
| `compute` | 用于计算当前值的回调。 |
| `owner` | 可选 Node 生命周期宿主。 |
| `run_immediately` | 是否立即计算一次。 |

<a id="member-gfcomputedproperty-methods-stop"></a>

### `stop`

- API：`public`

```gdscript
func stop() -> void:
```

停止自动刷新。

<a id="member-gfcomputedproperty-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放派生属性持有的监听。

<a id="member-gfcomputedproperty-methods-set_value"></a>

### `set_value`

- API：`public`

```gdscript
func set_value(_new_value: Variant) -> void:
```

只读派生属性不允许外部直接写入值。 "type": "Variant", "description": "调用方尝试写入的新值。" }

参数：

| 名称 | 说明 |
|---|---|
| `_new_value` | 调用方尝试写入的新值。 |

结构：

- `_new_value {`:

<a id="member-gfcomputedproperty-methods-mutate"></a>

### `mutate`

- API：`public`

```gdscript
func mutate(_mutator: Callable) -> bool:
```

只读派生属性不允许外部原地修改值。

参数：

| 名称 | 说明 |
|---|---|
| `_mutator` | 调用方尝试执行的修改回调。 |

返回：始终返回 false。

<a id="member-gfcomputedproperty-methods-append_to_array"></a>

### `append_to_array`

- API：`public`

```gdscript
func append_to_array(_item: Variant) -> bool:
```

只读派生属性不允许外部向数组追加元素。 "type": "Variant", "description": "调用方尝试追加的元素。" }

参数：

| 名称 | 说明 |
|---|---|
| `_item` | 调用方尝试追加的元素。 |

返回：始终返回 false。

结构：

- `_item {`:

<a id="member-gfcomputedproperty-methods-append_array"></a>

### `append_array`

- API：`public`

```gdscript
func append_array(_items: Array) -> bool:
```

只读派生属性不允许外部向数组追加元素列表。 "type": "Array", "description": "调用方尝试追加的元素列表。" }

参数：

| 名称 | 说明 |
|---|---|
| `_items` | 调用方尝试追加的元素列表。 |

返回：始终返回 false。

结构：

- `_items {`:

<a id="member-gfcomputedproperty-methods-erase_from_array"></a>

### `erase_from_array`

- API：`public`

```gdscript
func erase_from_array(_item: Variant) -> bool:
```

只读派生属性不允许外部从数组删除元素。 "type": "Variant", "description": "调用方尝试删除的元素。" }

参数：

| 名称 | 说明 |
|---|---|
| `_item` | 调用方尝试删除的元素。 |

返回：始终返回 false。

结构：

- `_item {`:

<a id="member-gfcomputedproperty-methods-set_dictionary_value"></a>

### `set_dictionary_value`

- API：`public`

```gdscript
func set_dictionary_value(_key: Variant, _new_value: Variant) -> bool:
```

只读派生属性不允许外部设置字典键值。 "type": "Variant", "description": "调用方尝试设置的键。" } "type": "Variant", "description": "调用方尝试设置的新值。" }

参数：

| 名称 | 说明 |
|---|---|
| `_key` | 调用方尝试设置的键。 |
| `_new_value` | 调用方尝试设置的新值。 |

返回：始终返回 false。

结构：

- `_key {`:
- `_new_value {`:

<a id="member-gfcomputedproperty-methods-erase_dictionary_key"></a>

### `erase_dictionary_key`

- API：`public`

```gdscript
func erase_dictionary_key(_key: Variant) -> bool:
```

只读派生属性不允许外部删除字典键。 "type": "Variant", "description": "调用方尝试删除的键。" }

参数：

| 名称 | 说明 |
|---|---|
| `_key` | 调用方尝试删除的键。 |

返回：始终返回 false。

结构：

- `_key {`:

<a id="member-gfcomputedproperty-methods-clear_collection"></a>

### `clear_collection`

- API：`public`

```gdscript
func clear_collection() -> bool:
```

只读派生属性不允许外部清空集合。

返回：始终返回 false。

<a id="member-gfcomputedproperty-methods-is_computing"></a>

### `is_computing`

- API：`public`

```gdscript
func is_computing() -> bool:
```

获取内部 effect 是否激活。

返回：激活时返回 true。
