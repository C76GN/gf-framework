# GFNetworkContractMessage

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/contracts/gf_network_contract_message.gd`
- 模块：`Network`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

网络契约中的单个消息定义。 消息定义描述 message_type、默认通道和 payload 字段集合，可用于构造、 校验和生成强类型辅助函数。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`message_type`](#member-gfnetworkcontractmessage-properties-message_type) | `var message_type: StringName = &""` |
| 属性 | [`display_name`](#member-gfnetworkcontractmessage-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`channel_id`](#member-gfnetworkcontractmessage-properties-channel_id) | `var channel_id: StringName = &""` |
| 属性 | [`fields`](#member-gfnetworkcontractmessage-properties-fields) | `var fields: Array[GFNetworkContractField] = []` |
| 属性 | [`metadata`](#member-gfnetworkcontractmessage-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_message_type`](#member-gfnetworkcontractmessage-methods-get_message_type) | `func get_message_type() -> StringName:` |
| 方法 | [`get_display_name`](#member-gfnetworkcontractmessage-methods-get_display_name) | `func get_display_name() -> String:` |
| 方法 | [`get_field`](#member-gfnetworkcontractmessage-methods-get_field) | `func get_field(target_field_name: StringName) -> GFNetworkContractField:` |
| 方法 | [`build_payload`](#member-gfnetworkcontractmessage-methods-build_payload) | `func build_payload(values: Dictionary = {}, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_message`](#member-gfnetworkcontractmessage-methods-make_message) | `func make_message(values: Dictionary = {}, options: Dictionary = {}) -> GFNetworkMessage:` |
| 方法 | [`validate_definition`](#member-gfnetworkcontractmessage-methods-validate_definition) | `func validate_definition() -> Dictionary:` |
| 方法 | [`validate_payload`](#member-gfnetworkcontractmessage-methods-validate_payload) | `func validate_payload(payload: Dictionary) -> Dictionary:` |
| 方法 | [`validate_message`](#member-gfnetworkcontractmessage-methods-validate_message) | `func validate_message(message: GFNetworkMessage) -> Dictionary:` |
| 方法 | [`describe`](#member-gfnetworkcontractmessage-methods-describe) | `func describe() -> Dictionary:` |

## 属性

<a id="member-gfnetworkcontractmessage-properties-message_type"></a>

### `message_type`

- API：`public`

```gdscript
var message_type: StringName = &""
```

消息类型标识。

<a id="member-gfnetworkcontractmessage-properties-display_name"></a>

### `display_name`

- API：`public`

```gdscript
var display_name: String = ""
```

编辑器展示名称。

<a id="member-gfnetworkcontractmessage-properties-channel_id"></a>

### `channel_id`

- API：`public`

```gdscript
var channel_id: StringName = &""
```

默认逻辑通道。为空时发送时不强制通道。

<a id="member-gfnetworkcontractmessage-properties-fields"></a>

### `fields`

- API：`public`

```gdscript
var fields: Array[GFNetworkContractField] = []
```

payload 字段定义。

结构：

- `fields`: Array[GFNetworkContractField]，按声明顺序保存 payload 字段定义。

<a id="member-gfnetworkcontractmessage-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，保存项目自定义消息元数据。

## 方法

<a id="member-gfnetworkcontractmessage-methods-get_message_type"></a>

### `get_message_type`

- API：`public`

```gdscript
func get_message_type() -> StringName:
```

获取消息类型。

返回：消息类型。

<a id="member-gfnetworkcontractmessage-methods-get_display_name"></a>

### `get_display_name`

- API：`public`

```gdscript
func get_display_name() -> String:
```

获取展示名称。

返回：展示名称。

<a id="member-gfnetworkcontractmessage-methods-get_field"></a>

### `get_field`

- API：`public`

```gdscript
func get_field(target_field_name: StringName) -> GFNetworkContractField:
```

查找字段定义。

参数：

| 名称 | 说明 |
|---|---|
| `target_field_name` | 字段名称。 |

返回：字段定义；不存在时返回 null。

<a id="member-gfnetworkcontractmessage-methods-build_payload"></a>

### `build_payload`

- API：`public`

```gdscript
func build_payload(values: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
```

构建 payload 字典。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 字段值字典，可使用 StringName 或 String 作为键。 |
| `options` | 可选项，支持 include_defaults。 |

返回：payload 字典。

结构：

- `values`: Dictionary[StringName|String, Variant]，字段名到字段值的映射。
- `options`: Dictionary，支持 include_defaults。
- `return`: Dictionary[StringName, Variant]，按字段契约归一化后的 payload。

<a id="member-gfnetworkcontractmessage-methods-make_message"></a>

### `make_message`

- API：`public`

```gdscript
func make_message(values: Dictionary = {}, options: Dictionary = {}) -> GFNetworkMessage:
```

构建 GFNetworkMessage。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 字段值字典。 |
| `options` | 可选元信息，支持 sequence、tick、sender_id、channel_id。 |

返回：网络消息。

结构：

- `values`: Dictionary[StringName|String, Variant]，字段名到字段值的映射。
- `options`: Dictionary，支持 include_defaults、sequence、tick、sender_id、channel_id。

<a id="member-gfnetworkcontractmessage-methods-validate_definition"></a>

### `validate_definition`

- API：`public`

```gdscript
func validate_definition() -> Dictionary:
```

校验消息定义是否完整。

返回：校验报告字典。

结构：

- `return`: Dictionary，GFValidationReportDictionary 格式，包含 ok、issues、issue_count 和 next_actions。

<a id="member-gfnetworkcontractmessage-methods-validate_payload"></a>

### `validate_payload`

- API：`public`

```gdscript
func validate_payload(payload: Dictionary) -> Dictionary:
```

校验 payload 是否符合字段契约。

参数：

| 名称 | 说明 |
|---|---|
| `payload` | payload 字典。 |

返回：校验报告字典。

结构：

- `payload`: Dictionary[StringName|String, Variant]，待校验 payload 字段值。
- `return`: Dictionary，GFValidationReportDictionary 格式，包含 ok、issues、issue_count 和 next_actions。

<a id="member-gfnetworkcontractmessage-methods-validate_message"></a>

### `validate_message`

- API：`public`

```gdscript
func validate_message(message: GFNetworkMessage) -> Dictionary:
```

校验 GFNetworkMessage 是否匹配该消息契约。

参数：

| 名称 | 说明 |
|---|---|
| `message` | 网络消息。 |

返回：校验报告字典。

结构：

- `return`: Dictionary，GFValidationReportDictionary 格式，包含 ok、issues、issue_count 和 next_actions。

<a id="member-gfnetworkcontractmessage-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

描述消息契约。

返回：描述字典。

结构：

- `return`: Dictionary，包含 message_type、display_name、channel_id、field_count、fields、metadata。
