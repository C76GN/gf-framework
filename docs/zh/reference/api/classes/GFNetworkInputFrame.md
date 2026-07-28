# GFNetworkInputFrame

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/simulation/gf_network_input_frame.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`10.0.0`

网络同步输入帧值对象。 保存目标 tick、来源 peer、单调序号和项目输入载荷。该类型只负责值语义； 非可信消息仍必须由 GFNetworkSyncCoordinator 结合实际传输 peer 校验。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`tick`](#member-gfnetworkinputframe-properties-tick) | `var tick: int = 0` |
| 属性 | [`peer_id`](#member-gfnetworkinputframe-properties-peer_id) | `var peer_id: int = -1` |
| 属性 | [`sequence`](#member-gfnetworkinputframe-properties-sequence) | `var sequence: int = 0` |
| 属性 | [`payload`](#member-gfnetworkinputframe-properties-payload) | `var payload: Dictionary = {}` |
| 方法 | [`to_dict`](#member-gfnetworkinputframe-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfnetworkinputframe-methods-from_dict) | `func from_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_frame`](#member-gfnetworkinputframe-methods-duplicate_frame) | `func duplicate_frame() -> GFNetworkInputFrame:` |
| 方法 | [`validate_frame`](#member-gfnetworkinputframe-methods-validate_frame) | `func validate_frame(options: Dictionary = {}) -> Dictionary:` |

## 属性

<a id="member-gfnetworkinputframe-properties-tick"></a>

### `tick`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var tick: int = 0
```

输入应被模拟的目标 tick。

<a id="member-gfnetworkinputframe-properties-peer_id"></a>

### `peer_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var peer_id: int = -1
```

输入来源 peer。

<a id="member-gfnetworkinputframe-properties-sequence"></a>

### `sequence`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var sequence: int = 0
```

来源 peer 内严格单调的输入序号。

<a id="member-gfnetworkinputframe-properties-payload"></a>

### `payload`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var payload: Dictionary = {}
```

项目定义的输入载荷。

结构：

- `payload`: Dictionary[StringName|String, Variant]，只允许网络传输安全值。

## 方法

<a id="member-gfnetworkinputframe-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转为字典副本。

返回：输入帧字典。

结构：

- `return`: Dictionary { tick: int, peer_id: int, sequence: int, payload: Dictionary }.

<a id="member-gfnetworkinputframe-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func from_dict(data: Dictionary) -> void:
```

从已由调用方校验的字典恢复。 该便利方法不建立传输身份或防重放边界；非可信数据应交给 GFNetworkSyncCoordinator.handle_message()。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 输入帧字典。 |

结构：

- `data`: Dictionary { tick: int, peer_id: int, sequence: int, payload: Dictionary }.

<a id="member-gfnetworkinputframe-methods-duplicate_frame"></a>

### `duplicate_frame`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func duplicate_frame() -> GFNetworkInputFrame:
```

复制输入帧。

返回：独立输入帧副本。

<a id="member-gfnetworkinputframe-methods-validate_frame"></a>

### `validate_frame`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate_frame(options: Dictionary = {}) -> Dictionary:
```

校验值对象的基础字段和载荷预算。 该方法不校验 authority、epoch、顺序窗口或项目实体所有权。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 结构预算；支持 max_depth、max_nodes 和 max_payload_bytes。 |

返回：统一校验报告。

结构：

- `options`: Dictionary { max_depth?: int, max_nodes?: int, max_payload_bytes?: int }.
- `return`: Dictionary { ok: bool, error: String, path: String, payload_bytes: int }.
