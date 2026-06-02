# GFDialogueResponse

[API Reference](../index.md) / [Dialogue](../extensions-dialogue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/dialogue/resources/gf_dialogue_response.gd`
- 模块：`Dialogue`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用对话响应选项。 响应只描述玩家或系统可选择的一条后继路径，不决定 UI 样式、 输入方式、角色关系或业务副作用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`response_id`](#member-gfdialogueresponse-properties-response_id) | `var response_id: StringName = &""` |
| 属性 | [`text`](#member-gfdialogueresponse-properties-text) | `var text: String = ""` |
| 属性 | [`next_line_id`](#member-gfdialogueresponse-properties-next_line_id) | `var next_line_id: StringName = &""` |
| 属性 | [`condition_id`](#member-gfdialogueresponse-properties-condition_id) | `var condition_id: StringName = &""` |
| 属性 | [`condition_payload`](#member-gfdialogueresponse-properties-condition_payload) | `var condition_payload: Variant = null` |
| 属性 | [`mutation_id`](#member-gfdialogueresponse-properties-mutation_id) | `var mutation_id: StringName = &""` |
| 属性 | [`mutation_payload`](#member-gfdialogueresponse-properties-mutation_payload) | `var mutation_payload: Variant = null` |
| 属性 | [`tags`](#member-gfdialogueresponse-properties-tags) | `var tags: PackedStringArray = PackedStringArray()` |
| 属性 | [`metadata`](#member-gfdialogueresponse-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`is_available`](#member-gfdialogueresponse-methods-is_available) | `func is_available(context: GFDialogueContext) -> bool:` |
| 方法 | [`duplicate_response`](#member-gfdialogueresponse-methods-duplicate_response) | `func duplicate_response() -> GFDialogueResponse:` |
| 方法 | [`to_dictionary`](#member-gfdialogueresponse-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |

## 属性

<a id="member-gfdialogueresponse-properties-response_id"></a>

### `response_id`

- API：`public`

```gdscript
var response_id: StringName = &""
```

响应 ID。

<a id="member-gfdialogueresponse-properties-text"></a>

### `text`

- API：`public`

```gdscript
var text: String = ""
```

响应文本或项目自定义文本键。

<a id="member-gfdialogueresponse-properties-next_line_id"></a>

### `next_line_id`

- API：`public`

```gdscript
var next_line_id: StringName = &""
```

选择后跳转到的行 ID。为空时使用当前行的默认后继。

<a id="member-gfdialogueresponse-properties-condition_id"></a>

### `condition_id`

- API：`public`

```gdscript
var condition_id: StringName = &""
```

条件 ID。为空表示不需要条件判断。

<a id="member-gfdialogueresponse-properties-condition_payload"></a>

### `condition_payload`

- API：`public`

```gdscript
var condition_payload: Variant = null
```

条件载荷。框架只透传给上下文处理器。

结构：

- `condition_payload`: 条件处理器接收的任意项目载荷；框架只透传，不解释其中结构。

<a id="member-gfdialogueresponse-properties-mutation_id"></a>

### `mutation_id`

- API：`public`

```gdscript
var mutation_id: StringName = &""
```

选择该响应时请求执行的通用 mutation ID。为空表示无副作用请求。

<a id="member-gfdialogueresponse-properties-mutation_payload"></a>

### `mutation_payload`

- API：`public`

```gdscript
var mutation_payload: Variant = null
```

mutation 载荷。框架只透传给上下文处理器。

结构：

- `mutation_payload`: mutation 处理器接收的任意项目载荷；框架只透传，不解释其中结构。

<a id="member-gfdialogueresponse-properties-tags"></a>

### `tags`

- API：`public`

```gdscript
var tags: PackedStringArray = PackedStringArray()
```

语义标签。框架不解释标签含义。

<a id="member-gfdialogueresponse-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: 项目自定义元数据 Dictionary；框架保留并复制该字段，但不解释其中键值。

## 方法

<a id="member-gfdialogueresponse-methods-is_available"></a>

### `is_available`

- API：`public`

```gdscript
func is_available(context: GFDialogueContext) -> bool:
```

检查响应是否可用。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 对话上下文。 |

返回：可用时返回 true。

<a id="member-gfdialogueresponse-methods-duplicate_response"></a>

### `duplicate_response`

- API：`public`

```gdscript
func duplicate_response() -> GFDialogueResponse:
```

创建深拷贝。

返回：响应副本。

<a id="member-gfdialogueresponse-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为字典。

返回：响应快照。

结构：

- `return`: 包含 response_id、text、next_line_id、condition_id、condition_payload、mutation_id、mutation_payload、tags 和 metadata 字段的 Dictionary。
