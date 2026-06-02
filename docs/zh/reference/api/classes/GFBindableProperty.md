# GFBindableProperty

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_bindable_property.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

响应式数据绑定属性容器。 封装一个 Variant 值，当值发生变化时自动发出 value_changed 信号。 可用于 Controller 直接监听 Model 数据变化，无需通过事件总线中转。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`value_changed`](#member-gfbindableproperty-signals-value_changed) | `signal value_changed(old_value: Variant, new_value: Variant)` |
| 属性 | [`value`](#member-gfbindableproperty-properties-value) | `var value: Variant:` |
| 方法 | [`get_value`](#member-gfbindableproperty-methods-get_value) | `func get_value() -> Variant:` |
| 方法 | [`set_value`](#member-gfbindableproperty-methods-set_value) | `func set_value(new_value: Variant) -> void:` |
| 方法 | [`subscribe`](#member-gfbindableproperty-methods-subscribe) | `func subscribe(callback: Callable, emit_current: bool = false) -> Callable:` |
| 方法 | [`force_emit`](#member-gfbindableproperty-methods-force_emit) | `func force_emit() -> void:` |
| 方法 | [`mutate`](#member-gfbindableproperty-methods-mutate) | `func mutate(mutator: Callable) -> bool:` |
| 方法 | [`append_to_array`](#member-gfbindableproperty-methods-append_to_array) | `func append_to_array(item: Variant) -> bool:` |
| 方法 | [`append_array`](#member-gfbindableproperty-methods-append_array) | `func append_array(items: Array) -> bool:` |
| 方法 | [`erase_from_array`](#member-gfbindableproperty-methods-erase_from_array) | `func erase_from_array(item: Variant) -> bool:` |
| 方法 | [`set_dictionary_value`](#member-gfbindableproperty-methods-set_dictionary_value) | `func set_dictionary_value(key: Variant, new_value: Variant) -> bool:` |
| 方法 | [`erase_dictionary_key`](#member-gfbindableproperty-methods-erase_dictionary_key) | `func erase_dictionary_key(key: Variant) -> bool:` |
| 方法 | [`clear_collection`](#member-gfbindableproperty-methods-clear_collection) | `func clear_collection() -> bool:` |
| 方法 | [`unbind`](#member-gfbindableproperty-methods-unbind) | `func unbind(node: Variant, callable: Callable) -> void:` |
| 方法 | [`unbind_all`](#member-gfbindableproperty-methods-unbind_all) | `func unbind_all() -> void:` |
| 方法 | [`unbind_all_node_bindings`](#member-gfbindableproperty-methods-unbind_all_node_bindings) | `func unbind_all_node_bindings() -> void:` |
| 方法 | [`disconnect_all_subscribers`](#member-gfbindableproperty-methods-disconnect_all_subscribers) | `func disconnect_all_subscribers() -> void:` |
| 方法 | [`bind_to`](#member-gfbindableproperty-methods-bind_to) | `func bind_to(node: Node, callable: Callable) -> void:` |

## 信号

<a id="member-gfbindableproperty-signals-value_changed"></a>

### `value_changed`

- API：`public`

```gdscript
signal value_changed(old_value: Variant, new_value: Variant)
```

当属性值被设置为不同的新值时发出。 "type": "Variant", "description": "变化前的旧值。" } "type": "Variant", "description": "变化后的新值。" }

参数：

| 名称 | 说明 |
|---|---|
| `old_value` | 变化前的旧值。 |
| `new_value` | 变化后的新值。 |

结构：

- `old_value {`:
- `new_value {`:

## 属性

<a id="member-gfbindableproperty-properties-value"></a>

### `value`

- API：`public`

```gdscript
var value: Variant:
```

当前属性值。设置该属性等价于调用 `set_value()`。 "type": "Variant", "description": "当前属性值。" }

结构：

- `value {`:

## 方法

<a id="member-gfbindableproperty-methods-get_value"></a>

### `get_value`

- API：`public`

```gdscript
func get_value() -> Variant:
```

获取当前属性值。 "type": "Variant", "description": "当前存储的值。" }

返回：当前存储的值。

结构：

- `return {`:

<a id="member-gfbindableproperty-methods-set_value"></a>

### `set_value`

- API：`public`

```gdscript
func set_value(new_value: Variant) -> void:
```

设置属性值。仅当新值与旧值不同时，才会更新并发出 value_changed 信号。 "type": "Variant", "description": "要设置的新值。" }

参数：

| 名称 | 说明 |
|---|---|
| `new_value` | 要设置的新值。 |

结构：

- `new_value {`:

<a id="member-gfbindableproperty-methods-subscribe"></a>

### `subscribe`

- API：`public`
- 首次版本：`3.20.0`

```gdscript
func subscribe(callback: Callable, emit_current: bool = false) -> Callable:
```

订阅属性变化，并返回取消订阅函数。

参数：

| 名称 | 说明 |
|---|---|
| `callback` | 变化回调，签名应为 func(old_value: Variant, new_value: Variant)。 |
| `emit_current` | 是否立即以当前值调用一次回调；为 true 时 old_value 和 new_value 都是当前值。 |

返回：可调用的取消订阅函数；callback 无效时返回空 Callable。

<a id="member-gfbindableproperty-methods-force_emit"></a>

### `force_emit`

- API：`public`

```gdscript
func force_emit() -> void:
```

强制发出 value_changed 信号。 适合在 Array、Dictionary 或 Object 发生原地变更后，由业务层显式通知监听者。

<a id="member-gfbindableproperty-methods-mutate"></a>

### `mutate`

- API：`public`

```gdscript
func mutate(mutator: Callable) -> bool:
```

通过回调修改当前值并强制广播。

参数：

| 名称 | 说明 |
|---|---|
| `mutator` | 修改当前值的回调。 |

返回：回调有效时返回 true。

<a id="member-gfbindableproperty-methods-append_to_array"></a>

### `append_to_array`

- API：`public`

```gdscript
func append_to_array(item: Variant) -> bool:
```

向当前 Array 追加一个元素。 "type": "Variant", "description": "要追加的元素。" }

参数：

| 名称 | 说明 |
|---|---|
| `item` | 要追加的元素。 |

返回：成功返回 true。

结构：

- `item {`:

<a id="member-gfbindableproperty-methods-append_array"></a>

### `append_array`

- API：`public`

```gdscript
func append_array(items: Array) -> bool:
```

向当前 Array 追加多个元素。 "type": "Array", "description": "要追加的元素列表。" }

参数：

| 名称 | 说明 |
|---|---|
| `items` | 要追加的元素列表。 |

返回：成功返回 true。

结构：

- `items {`:

<a id="member-gfbindableproperty-methods-erase_from_array"></a>

### `erase_from_array`

- API：`public`

```gdscript
func erase_from_array(item: Variant) -> bool:
```

从当前 Array 删除一个元素。 "type": "Variant", "description": "要删除的元素。" }

参数：

| 名称 | 说明 |
|---|---|
| `item` | 要删除的元素。 |

返回：成功返回 true。

结构：

- `item {`:

<a id="member-gfbindableproperty-methods-set_dictionary_value"></a>

### `set_dictionary_value`

- API：`public`

```gdscript
func set_dictionary_value(key: Variant, new_value: Variant) -> bool:
```

设置当前 Dictionary 的一个键值。 "type": "Variant", "description": "Dictionary 键。" } "type": "Variant", "description": "Dictionary 新值。" }

参数：

| 名称 | 说明 |
|---|---|
| `key` | 键。 |
| `new_value` | 新值。 |

返回：成功返回 true。

结构：

- `key {`:
- `new_value {`:

<a id="member-gfbindableproperty-methods-erase_dictionary_key"></a>

### `erase_dictionary_key`

- API：`public`

```gdscript
func erase_dictionary_key(key: Variant) -> bool:
```

从当前 Dictionary 删除一个键。 "type": "Variant", "description": "Dictionary 键。" }

参数：

| 名称 | 说明 |
|---|---|
| `key` | 键。 |

返回：成功返回 true。

结构：

- `key {`:

<a id="member-gfbindableproperty-methods-clear_collection"></a>

### `clear_collection`

- API：`public`

```gdscript
func clear_collection() -> bool:
```

清空当前 Array 或 Dictionary。

返回：成功返回 true。

<a id="member-gfbindableproperty-methods-unbind"></a>

### `unbind`

- API：`public`

```gdscript
func unbind(node: Variant, callable: Callable) -> void:
```

断开指定 Node 与 Callable 的绑定关系。 "type": "Variant", "description": "绑定生命周期的 Node；已失效对象会触发失效绑定清理。" }

参数：

| 名称 | 说明 |
|---|---|
| `node` | 绑定生命周期的节点；已失效对象会触发失效绑定清理。 |
| `callable` | 要解绑的回调函数。 |

结构：

- `node {`:

<a id="member-gfbindableproperty-methods-unbind_all"></a>

### `unbind_all`

- API：`public`

```gdscript
func unbind_all() -> void:
```

断开所有由 bind_to() 创建的 Node 生命周期绑定。

<a id="member-gfbindableproperty-methods-unbind_all_node_bindings"></a>

### `unbind_all_node_bindings`

- API：`public`

```gdscript
func unbind_all_node_bindings() -> void:
```

断开所有由 bind_to() 创建的 Node 生命周期绑定。

<a id="member-gfbindableproperty-methods-disconnect_all_subscribers"></a>

### `disconnect_all_subscribers`

- API：`public`

```gdscript
func disconnect_all_subscribers() -> void:
```

断开 value_changed 信号上的所有订阅者，并清理 bind_to() 创建的 Node 生命周期绑定。

<a id="member-gfbindableproperty-methods-bind_to"></a>

### `bind_to`

- API：`public`

```gdscript
func bind_to(node: Node, callable: Callable) -> void:
```

绑定信号到一个 Node 的 Callable。当该 Node 退出场景树时，自动断开连接。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 监听生命周期的节点。 |
| `callable` | 绑定的回调函数。 |
