# GFDialogueLine

[API Reference](../index.md) / [Dialogue](../extensions-dialogue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/dialogue/resources/gf_dialogue_line.gd`
- 模块：`Dialogue`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用对话流程行。 行可以表示可展示文本、跳转、mutation 请求或结束点。它不规定剧本语法、 对话框 UI、角色表或项目状态字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`LineKind`](#member-gfdialogueline-enums-linekind) | `enum LineKind` |
| 属性 | [`line_id`](#member-gfdialogueline-properties-line_id) | `var line_id: StringName = &""` |
| 属性 | [`kind`](#member-gfdialogueline-properties-kind) | `var kind: LineKind = LineKind.TEXT` |
| 属性 | [`speaker_id`](#member-gfdialogueline-properties-speaker_id) | `var speaker_id: StringName = &""` |
| 属性 | [`text`](#member-gfdialogueline-properties-text) | `var text: String = ""` |
| 属性 | [`next_line_id`](#member-gfdialogueline-properties-next_line_id) | `var next_line_id: StringName = &""` |
| 属性 | [`jump_line_id`](#member-gfdialogueline-properties-jump_line_id) | `var jump_line_id: StringName = &""` |
| 属性 | [`condition_id`](#member-gfdialogueline-properties-condition_id) | `var condition_id: StringName = &""` |
| 属性 | [`condition_payload`](#member-gfdialogueline-properties-condition_payload) | `var condition_payload: Variant = null` |
| 属性 | [`fallback_line_id`](#member-gfdialogueline-properties-fallback_line_id) | `var fallback_line_id: StringName = &""` |
| 属性 | [`mutation_id`](#member-gfdialogueline-properties-mutation_id) | `var mutation_id: StringName = &""` |
| 属性 | [`mutation_payload`](#member-gfdialogueline-properties-mutation_payload) | `var mutation_payload: Variant = null` |
| 属性 | [`responses`](#member-gfdialogueline-properties-responses) | `var responses: Array[GFDialogueResponse] = []` |
| 属性 | [`tags`](#member-gfdialogueline-properties-tags) | `var tags: PackedStringArray = PackedStringArray()` |
| 属性 | [`metadata`](#member-gfdialogueline-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`has_responses`](#member-gfdialogueline-methods-has_responses) | `func has_responses() -> bool:` |
| 方法 | [`get_available_responses`](#member-gfdialogueline-methods-get_available_responses) | `func get_available_responses(context: GFDialogueContext = null) -> Array[GFDialogueResponse]:` |
| 方法 | [`get_response`](#member-gfdialogueline-methods-get_response) | `func get_response(response_id: StringName) -> GFDialogueResponse:` |
| 方法 | [`can_enter`](#member-gfdialogueline-methods-can_enter) | `func can_enter(context: GFDialogueContext) -> bool:` |
| 方法 | [`get_default_next_line_id`](#member-gfdialogueline-methods-get_default_next_line_id) | `func get_default_next_line_id() -> StringName:` |
| 方法 | [`duplicate_line`](#member-gfdialogueline-methods-duplicate_line) | `func duplicate_line() -> GFDialogueLine:` |
| 方法 | [`to_dictionary`](#member-gfdialogueline-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |

## 枚举

<a id="member-gfdialogueline-enums-linekind"></a>

### `LineKind`

- API：`public`

```gdscript
enum LineKind { ## 可展示文本行。 TEXT, ## 请求执行上下文 mutation 后继续。 MUTATION, ## 直接跳转到另一行。 JUMP, ## 结束当前对话。 END, }
```

对话行类型。

## 属性

<a id="member-gfdialogueline-properties-line_id"></a>

### `line_id`

- API：`public`

```gdscript
var line_id: StringName = &""
```

行 ID。

<a id="member-gfdialogueline-properties-kind"></a>

### `kind`

- API：`public`

```gdscript
var kind: LineKind = LineKind.TEXT
```

行类型。

<a id="member-gfdialogueline-properties-speaker_id"></a>

### `speaker_id`

- API：`public`

```gdscript
var speaker_id: StringName = &""
```

说话者 ID 或项目自定义主体键。

<a id="member-gfdialogueline-properties-text"></a>

### `text`

- API：`public`

```gdscript
var text: String = ""
```

文本或项目自定义文本键。

<a id="member-gfdialogueline-properties-next_line_id"></a>

### `next_line_id`

- API：`public`

```gdscript
var next_line_id: StringName = &""
```

默认后继行 ID。

<a id="member-gfdialogueline-properties-jump_line_id"></a>

### `jump_line_id`

- API：`public`

```gdscript
var jump_line_id: StringName = &""
```

跳转行 ID。`kind == JUMP` 时优先使用。

<a id="member-gfdialogueline-properties-condition_id"></a>

### `condition_id`

- API：`public`

```gdscript
var condition_id: StringName = &""
```

条件 ID。为空表示不需要条件判断。

<a id="member-gfdialogueline-properties-condition_payload"></a>

### `condition_payload`

- API：`public`

```gdscript
var condition_payload: Variant = null
```

条件载荷。框架只透传给上下文处理器。

结构：

- `condition_payload`: 条件处理器接收的任意项目载荷；框架只透传，不解释其中结构。

<a id="member-gfdialogueline-properties-fallback_line_id"></a>

### `fallback_line_id`

- API：`public`

```gdscript
var fallback_line_id: StringName = &""
```

条件不通过时的后继行 ID。为空时由 Runner 按策略跳过或结束。

<a id="member-gfdialogueline-properties-mutation_id"></a>

### `mutation_id`

- API：`public`

```gdscript
var mutation_id: StringName = &""
```

mutation ID。`kind == MUTATION` 时由 Runner 请求上下文处理。

<a id="member-gfdialogueline-properties-mutation_payload"></a>

### `mutation_payload`

- API：`public`

```gdscript
var mutation_payload: Variant = null
```

mutation 载荷。框架只透传给上下文处理器。

结构：

- `mutation_payload`: mutation 处理器接收的任意项目载荷；框架只透传，不解释其中结构。

<a id="member-gfdialogueline-properties-responses"></a>

### `responses`

- API：`public`

```gdscript
var responses: Array[GFDialogueResponse] = []
```

响应选项。

<a id="member-gfdialogueline-properties-tags"></a>

### `tags`

- API：`public`

```gdscript
var tags: PackedStringArray = PackedStringArray()
```

语义标签。框架不解释标签含义。

<a id="member-gfdialogueline-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: 项目自定义元数据 Dictionary；框架保留并复制该字段，但不解释其中键值。

## 方法

<a id="member-gfdialogueline-methods-has_responses"></a>

### `has_responses`

- API：`public`

```gdscript
func has_responses() -> bool:
```

检查行是否有响应。

返回：存在响应时返回 true。

<a id="member-gfdialogueline-methods-get_available_responses"></a>

### `get_available_responses`

- API：`public`

```gdscript
func get_available_responses(context: GFDialogueContext = null) -> Array[GFDialogueResponse]:
```

获取可用响应。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 对话上下文。 |

返回：可用响应列表。

<a id="member-gfdialogueline-methods-get_response"></a>

### `get_response`

- API：`public`

```gdscript
func get_response(response_id: StringName) -> GFDialogueResponse:
```

按 ID 获取响应。

参数：

| 名称 | 说明 |
|---|---|
| `response_id` | 响应 ID。 |

返回：响应；不存在时返回 null。

<a id="member-gfdialogueline-methods-can_enter"></a>

### `can_enter`

- API：`public`

```gdscript
func can_enter(context: GFDialogueContext) -> bool:
```

检查行是否可进入。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 对话上下文。 |

返回：可进入时返回 true。

<a id="member-gfdialogueline-methods-get_default_next_line_id"></a>

### `get_default_next_line_id`

- API：`public`

```gdscript
func get_default_next_line_id() -> StringName:
```

获取默认后继行 ID。

返回：后继行 ID。

<a id="member-gfdialogueline-methods-duplicate_line"></a>

### `duplicate_line`

- API：`public`

```gdscript
func duplicate_line() -> GFDialogueLine:
```

创建深拷贝。

返回：行副本。

<a id="member-gfdialogueline-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为字典。

返回：行快照。

结构：

- `return`: 包含 line_id、kind、speaker_id、text、next_line_id、jump_line_id、condition_id、condition_payload、fallback_line_id、mutation_id、mutation_payload、responses、tags 和 metadata 字段的 Dictionary。
