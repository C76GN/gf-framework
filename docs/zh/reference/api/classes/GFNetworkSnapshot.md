# GFNetworkSnapshot

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/snapshot/gf_network_snapshot.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

通用网络状态快照。 保存 tick、peer_id、纯字典状态和元数据，可用于同步、回放、插值或项目自定义差量流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`tick`](#member-gfnetworksnapshot-properties-tick) | `var tick: int = 0` |
| 属性 | [`peer_id`](#member-gfnetworksnapshot-properties-peer_id) | `var peer_id: int = -1` |
| 属性 | [`state`](#member-gfnetworksnapshot-properties-state) | `var state: Dictionary = {}` |
| 属性 | [`metadata`](#member-gfnetworksnapshot-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`to_dict`](#member-gfnetworksnapshot-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfnetworksnapshot-methods-from_dict) | `func from_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_snapshot`](#member-gfnetworksnapshot-methods-duplicate_snapshot) | `func duplicate_snapshot() -> GFNetworkSnapshot:` |
| 方法 | [`has_value`](#member-gfnetworksnapshot-methods-has_value) | `func has_value(key: StringName) -> bool:` |
| 方法 | [`get_value`](#member-gfnetworksnapshot-methods-get_value) | `func get_value(key: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`set_value`](#member-gfnetworksnapshot-methods-set_value) | `func set_value(key: StringName, value: Variant) -> void:` |
| 方法 | [`erase_value`](#member-gfnetworksnapshot-methods-erase_value) | `func erase_value(key: StringName) -> void:` |
| 方法 | [`make_delta_to`](#member-gfnetworksnapshot-methods-make_delta_to) | `func make_delta_to(target: GFNetworkSnapshot) -> Dictionary:` |
| 方法 | [`apply_delta`](#member-gfnetworksnapshot-methods-apply_delta) | `func apply_delta(delta: Dictionary) -> GFNetworkSnapshot:` |
| 方法 | [`make_patch_to`](#member-gfnetworksnapshot-methods-make_patch_to) | `func make_patch_to(target: GFNetworkSnapshot, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`apply_patch`](#member-gfnetworksnapshot-methods-apply_patch) | `func apply_patch(patch: Dictionary) -> GFNetworkSnapshot:` |
| 方法 | [`make_message`](#member-gfnetworksnapshot-methods-make_message) | `func make_message(message_type: StringName = &"snapshot", channel_id: StringName = &"") -> GFNetworkMessage:` |

## 属性

<a id="member-gfnetworksnapshot-properties-tick"></a>

### `tick`

- API：`public`

```gdscript
var tick: int = 0
```

快照所属 tick。

<a id="member-gfnetworksnapshot-properties-peer_id"></a>

### `peer_id`

- API：`public`

```gdscript
var peer_id: int = -1
```

快照来源 peer；-1 表示未指定。

<a id="member-gfnetworksnapshot-properties-state"></a>

### `state`

- API：`public`

```gdscript
var state: Dictionary = {}
```

快照状态字典。

结构：

- `state`: Dictionary[StringName|String, Variant]，保存项目自定义同步状态。

<a id="member-gfnetworksnapshot-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。

结构：

- `metadata`: Dictionary，保存项目自定义快照元数据。

## 方法

<a id="member-gfnetworksnapshot-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转为字典。

返回：快照字典。

结构：

- `return`: Dictionary，包含 tick、peer_id、state、metadata。

<a id="member-gfnetworksnapshot-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
func from_dict(data: Dictionary) -> void:
```

从字典恢复。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 快照字典。 |

结构：

- `data`: Dictionary，包含 tick、peer_id、state、metadata。

<a id="member-gfnetworksnapshot-methods-duplicate_snapshot"></a>

### `duplicate_snapshot`

- API：`public`

```gdscript
func duplicate_snapshot() -> GFNetworkSnapshot:
```

复制快照。

返回：新快照。

<a id="member-gfnetworksnapshot-methods-has_value"></a>

### `has_value`

- API：`public`

```gdscript
func has_value(key: StringName) -> bool:
```

检查状态字段是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 字段名。 |

返回：存在返回 true。

<a id="member-gfnetworksnapshot-methods-get_value"></a>

### `get_value`

- API：`public`

```gdscript
func get_value(key: StringName, default_value: Variant = null) -> Variant:
```

读取状态字段。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 字段名。 |
| `default_value` | 缺失时返回的默认值。 |

返回：字段值。

结构：

- `default_value`: Variant，状态字段缺失时返回的默认值。
- `return`: Variant，字段值或 default_value。

<a id="member-gfnetworksnapshot-methods-set_value"></a>

### `set_value`

- API：`public`

```gdscript
func set_value(key: StringName, value: Variant) -> void:
```

设置状态字段。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 字段名。 |
| `value` | 字段值。 |

结构：

- `value`: Variant，字段值，会通过 GFVariantData.duplicate_variant() 复制后保存。

<a id="member-gfnetworksnapshot-methods-erase_value"></a>

### `erase_value`

- API：`public`

```gdscript
func erase_value(key: StringName) -> void:
```

删除状态字段。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 字段名。 |

<a id="member-gfnetworksnapshot-methods-make_delta_to"></a>

### `make_delta_to`

- API：`public`

```gdscript
func make_delta_to(target: GFNetworkSnapshot) -> Dictionary:
```

生成当前快照到目标快照的浅层差量。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标快照。 |

返回：差量字典。

结构：

- `return`: Dictionary，成功时包含 ok、from_tick、to_tick、peer_id、set、erase、metadata；失败时包含 ok、error。

<a id="member-gfnetworksnapshot-methods-apply_delta"></a>

### `apply_delta`

- API：`public`

```gdscript
func apply_delta(delta: Dictionary) -> GFNetworkSnapshot:
```

应用浅层差量并返回新快照。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | make_delta_to() 生成的差量字典。 |

返回：新快照。

结构：

- `delta`: Dictionary，make_delta_to() 返回的差量结构。

<a id="member-gfnetworksnapshot-methods-make_patch_to"></a>

### `make_patch_to`

- API：`public`

```gdscript
func make_patch_to(target: GFNetworkSnapshot, options: Dictionary = {}) -> Dictionary:
```

生成当前快照到目标快照的路径级 patch。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标快照。 |
| `options` | 生成选项。 |

返回：patch 字典。

结构：

- `options`: Dictionary，可选 recursive: bool = true，max_depth: int = 8。
- `return`: Dictionary，成功时包含 ok、format、version、from_tick、to_tick、peer_id、set、erase、metadata；失败时包含 ok、error。

<a id="member-gfnetworksnapshot-methods-apply_patch"></a>

### `apply_patch`

- API：`public`

```gdscript
func apply_patch(patch: Dictionary) -> GFNetworkSnapshot:
```

应用路径级 patch 并返回新快照。

参数：

| 名称 | 说明 |
|---|---|
| `patch` | make_patch_to() 生成的 patch 字典。 |

返回：新快照。

结构：

- `patch`: Dictionary，make_patch_to() 返回的 patch 结构。

<a id="member-gfnetworksnapshot-methods-make_message"></a>

### `make_message`

- API：`public`

```gdscript
func make_message(message_type: StringName = &"snapshot", channel_id: StringName = &"") -> GFNetworkMessage:
```

打包为网络消息。

参数：

| 名称 | 说明 |
|---|---|
| `message_type` | 消息类型。 |
| `channel_id` | 逻辑通道标识。 |

返回：网络消息。
