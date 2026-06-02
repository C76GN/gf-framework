# GFControlValueAdapter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_control_value_adapter.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

常见 Control 节点的值读写适配器。 用于表单、设置页和编辑工具中统一读写控件值，不持有状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_value`](#member-gfcontrolvalueadapter-methods-get_value) | `static func get_value(control: Control, fallback: Variant = null) -> Variant:` |
| 方法 | [`set_value`](#member-gfcontrolvalueadapter-methods-set_value) | `static func set_value(control: Control, value: Variant) -> bool:` |
| 方法 | [`connect_value_changed`](#member-gfcontrolvalueadapter-methods-connect_value_changed) | `static func connect_value_changed(control: Control, callback: Callable) -> bool:` |
| 方法 | [`connect_value_changed_with_handles`](#member-gfcontrolvalueadapter-methods-connect_value_changed_with_handles) | `static func connect_value_changed_with_handles(control: Control, callback: Callable) -> Array[Dictionary]:` |
| 方法 | [`disconnect_value_changed_handles`](#member-gfcontrolvalueadapter-methods-disconnect_value_changed_handles) | `static func disconnect_value_changed_handles(connections: Array) -> void:` |

## 方法

<a id="member-gfcontrolvalueadapter-methods-get_value"></a>

### `get_value`

- API：`public`

```gdscript
static func get_value(control: Control, fallback: Variant = null) -> Variant:
```

从控件读取值。

参数：

| 名称 | 说明 |
|---|---|
| `control` | 控件节点。 |
| `fallback` | 不支持读取时返回的值。 |

返回：控件值。

结构：

- `fallback`: Variant，控件无效或不支持读取时返回的回退值。
- `return`: Variant，控件当前值；无法读取时返回 fallback。

<a id="member-gfcontrolvalueadapter-methods-set_value"></a>

### `set_value`

- API：`public`

```gdscript
static func set_value(control: Control, value: Variant) -> bool:
```

向控件写入值。

参数：

| 名称 | 说明 |
|---|---|
| `control` | 控件节点。 |
| `value` | 值。 |

返回：成功写入时返回 true。

结构：

- `value`: Variant，要写入控件的值，具体类型取决于控件类型。

<a id="member-gfcontrolvalueadapter-methods-connect_value_changed"></a>

### `connect_value_changed`

- API：`public`

```gdscript
static func connect_value_changed(control: Control, callback: Callable) -> bool:
```

连接控件值变化信号。

参数：

| 名称 | 说明 |
|---|---|
| `control` | 控件节点。 |
| `callback` | 值变化后调用的回调，不接收参数。 |

返回：成功连接时返回 true。

<a id="member-gfcontrolvalueadapter-methods-connect_value_changed_with_handles"></a>

### `connect_value_changed_with_handles`

- API：`public`

```gdscript
static func connect_value_changed_with_handles(control: Control, callback: Callable) -> Array[Dictionary]:
```

连接控件值变化信号并返回可断开的连接句柄。

参数：

| 名称 | 说明 |
|---|---|
| `control` | 控件节点。 |
| `callback` | 值变化后调用的回调，不接收参数。 |

返回：连接句柄数组，可传给 disconnect_value_changed_handles()。

结构：

- `return`: Array[Dictionary]，每个条目包含 control_ref、signal_name 和 callable。

<a id="member-gfcontrolvalueadapter-methods-disconnect_value_changed_handles"></a>

### `disconnect_value_changed_handles`

- API：`public`

```gdscript
static func disconnect_value_changed_handles(connections: Array) -> void:
```

断开 connect_value_changed_with_handles() 返回的连接句柄。

参数：

| 名称 | 说明 |
|---|---|
| `connections` | 连接句柄数组。 |

结构：

- `connections`: Array，包含 connect_value_changed_with_handles() 返回的连接句柄 Dictionary。
