# GFNetworkContract

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/contracts/gf_network_contract.gd`
- 模块：`Network`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

网络消息契约集合。 契约集合用于集中描述一组 GFNetworkMessage 的 message_type、字段和默认通道， 方便项目生成强类型辅助代码或在运行前校验消息结构。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`contract_id`](#member-gfnetworkcontract-properties-contract_id) | `var contract_id: StringName = &""` |
| 属性 | [`display_name`](#member-gfnetworkcontract-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`messages`](#member-gfnetworkcontract-properties-messages) | `var messages: Array[GFNetworkContractMessage] = []` |
| 属性 | [`metadata`](#member-gfnetworkcontract-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_display_name`](#member-gfnetworkcontract-methods-get_display_name) | `func get_display_name() -> String:` |
| 方法 | [`set_message_contract`](#member-gfnetworkcontract-methods-set_message_contract) | `func set_message_contract(message_contract: GFNetworkContractMessage) -> void:` |
| 方法 | [`get_message_contract`](#member-gfnetworkcontract-methods-get_message_contract) | `func get_message_contract(message_type: StringName) -> GFNetworkContractMessage:` |
| 方法 | [`has_message_contract`](#member-gfnetworkcontract-methods-has_message_contract) | `func has_message_contract(message_type: StringName) -> bool:` |
| 方法 | [`make_message`](#member-gfnetworkcontract-methods-make_message) | `func make_message(message_type: StringName, values: Dictionary = {}, options: Dictionary = {}) -> GFNetworkMessage:` |
| 方法 | [`validate_message`](#member-gfnetworkcontract-methods-validate_message) | `func validate_message(message: GFNetworkMessage) -> Dictionary:` |
| 方法 | [`validate_contract`](#member-gfnetworkcontract-methods-validate_contract) | `func validate_contract() -> Dictionary:` |
| 方法 | [`describe`](#member-gfnetworkcontract-methods-describe) | `func describe() -> Dictionary:` |

## 属性

<a id="member-gfnetworkcontract-properties-contract_id"></a>

### `contract_id`

- API：`public`

```gdscript
var contract_id: StringName = &""
```

契约稳定标识。

<a id="member-gfnetworkcontract-properties-display_name"></a>

### `display_name`

- API：`public`

```gdscript
var display_name: String = ""
```

编辑器展示名称。

<a id="member-gfnetworkcontract-properties-messages"></a>

### `messages`

- API：`public`

```gdscript
var messages: Array[GFNetworkContractMessage] = []
```

消息契约列表。

结构：

- `messages`: Array[GFNetworkContractMessage]，按声明顺序保存消息契约。

<a id="member-gfnetworkcontract-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，保存项目自定义契约元数据。

## 方法

<a id="member-gfnetworkcontract-methods-get_display_name"></a>

### `get_display_name`

- API：`public`

```gdscript
func get_display_name() -> String:
```

获取展示名称。

返回：展示名称。

<a id="member-gfnetworkcontract-methods-set_message_contract"></a>

### `set_message_contract`

- API：`public`

```gdscript
func set_message_contract(message_contract: GFNetworkContractMessage) -> void:
```

设置或替换一个消息契约。

参数：

| 名称 | 说明 |
|---|---|
| `message_contract` | 消息契约。 |

<a id="member-gfnetworkcontract-methods-get_message_contract"></a>

### `get_message_contract`

- API：`public`

```gdscript
func get_message_contract(message_type: StringName) -> GFNetworkContractMessage:
```

获取消息契约。

参数：

| 名称 | 说明 |
|---|---|
| `message_type` | 消息类型。 |

返回：消息契约；不存在时返回 null。

<a id="member-gfnetworkcontract-methods-has_message_contract"></a>

### `has_message_contract`

- API：`public`

```gdscript
func has_message_contract(message_type: StringName) -> bool:
```

检查消息契约是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `message_type` | 消息类型。 |

返回：存在返回 true。

<a id="member-gfnetworkcontract-methods-make_message"></a>

### `make_message`

- API：`public`

```gdscript
func make_message(message_type: StringName, values: Dictionary = {}, options: Dictionary = {}) -> GFNetworkMessage:
```

按消息契约创建 GFNetworkMessage。

参数：

| 名称 | 说明 |
|---|---|
| `message_type` | 消息类型。 |
| `values` | 字段值字典。 |
| `options` | 可选元信息。 |

返回：网络消息；契约不存在时返回 null。

结构：

- `values`: Dictionary[StringName|String, Variant]，字段名到字段值的映射。
- `options`: Dictionary，支持 include_defaults、sequence、tick、sender_id、channel_id。

<a id="member-gfnetworkcontract-methods-validate_message"></a>

### `validate_message`

- API：`public`

```gdscript
func validate_message(message: GFNetworkMessage) -> Dictionary:
```

校验网络消息是否匹配本契约集合。

参数：

| 名称 | 说明 |
|---|---|
| `message` | 网络消息。 |

返回：校验报告字典。

结构：

- `return`: Dictionary，GFValidationReportDictionary 格式，包含 ok、issues、issue_count 和 next_actions。

<a id="member-gfnetworkcontract-methods-validate_contract"></a>

### `validate_contract`

- API：`public`

```gdscript
func validate_contract() -> Dictionary:
```

校验契约定义是否完整。

返回：校验报告字典。

结构：

- `return`: Dictionary，GFValidationReportDictionary 格式，包含 ok、issues、issue_count 和 next_actions。

<a id="member-gfnetworkcontract-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

描述契约集合。

返回：描述字典。

结构：

- `return`: Dictionary，包含 contract_id、display_name、message_count、messages、metadata。
