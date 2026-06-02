# GFDialogueResource

[API Reference](../index.md) / [Dialogue](../extensions-dialogue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/dialogue/resources/gf_dialogue_resource.gd`
- 模块：`Dialogue`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用对话资源。 资源只保存对话行集合、起始行和自定义元数据。导入格式、剧本 DSL、 本地化表和编辑器 UI 均由项目或独立插件决定。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`start_line_id`](#member-gfdialogueresource-properties-start_line_id) | `var start_line_id: StringName = &""` |
| 属性 | [`lines`](#member-gfdialogueresource-properties-lines) | `var lines: Array[GFDialogueLine] = []` |
| 属性 | [`metadata`](#member-gfdialogueresource-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`set_line`](#member-gfdialogueresource-methods-set_line) | `func set_line(line: GFDialogueLine) -> void:` |
| 方法 | [`get_line`](#member-gfdialogueresource-methods-get_line) | `func get_line(line_id: StringName) -> GFDialogueLine:` |
| 方法 | [`get_start_line`](#member-gfdialogueresource-methods-get_start_line) | `func get_start_line(override_line_id: StringName = &"") -> GFDialogueLine:` |
| 方法 | [`get_line_ids`](#member-gfdialogueresource-methods-get_line_ids) | `func get_line_ids() -> PackedStringArray:` |
| 方法 | [`validate_resource`](#member-gfdialogueresource-methods-validate_resource) | `func validate_resource() -> Dictionary:` |
| 方法 | [`duplicate_dialogue`](#member-gfdialogueresource-methods-duplicate_dialogue) | `func duplicate_dialogue() -> GFDialogueResource:` |
| 方法 | [`to_dictionary`](#member-gfdialogueresource-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |

## 属性

<a id="member-gfdialogueresource-properties-start_line_id"></a>

### `start_line_id`

- API：`public`

```gdscript
var start_line_id: StringName = &""
```

默认起始行 ID。

<a id="member-gfdialogueresource-properties-lines"></a>

### `lines`

- API：`public`

```gdscript
var lines: Array[GFDialogueLine] = []
```

对话行集合。

<a id="member-gfdialogueresource-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: 项目自定义元数据 Dictionary；框架保留并复制该字段，但不解释其中键值。

## 方法

<a id="member-gfdialogueresource-methods-set_line"></a>

### `set_line`

- API：`public`

```gdscript
func set_line(line: GFDialogueLine) -> void:
```

设置或追加对话行。

参数：

| 名称 | 说明 |
|---|---|
| `line` | 对话行。 |

<a id="member-gfdialogueresource-methods-get_line"></a>

### `get_line`

- API：`public`

```gdscript
func get_line(line_id: StringName) -> GFDialogueLine:
```

获取对话行。

参数：

| 名称 | 说明 |
|---|---|
| `line_id` | 行 ID。 |

返回：对话行；不存在时返回 null。

<a id="member-gfdialogueresource-methods-get_start_line"></a>

### `get_start_line`

- API：`public`

```gdscript
func get_start_line(override_line_id: StringName = &"") -> GFDialogueLine:
```

获取起始行。

参数：

| 名称 | 说明 |
|---|---|
| `override_line_id` | 可选覆盖起点。 |

返回：起始行；不存在时返回 null。

<a id="member-gfdialogueresource-methods-get_line_ids"></a>

### `get_line_ids`

- API：`public`

```gdscript
func get_line_ids() -> PackedStringArray:
```

获取全部行 ID。

返回：行 ID 列表。

<a id="member-gfdialogueresource-methods-validate_resource"></a>

### `validate_resource`

- API：`public`

```gdscript
func validate_resource() -> Dictionary:
```

校验资源结构。

返回：兼容 GFValidationReportDictionary 的报告字典。

结构：

- `return`: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，包含 ok、healthy、summary、issues、next_action、error_count、warning_count 和 issue_count 等字段。

<a id="member-gfdialogueresource-methods-duplicate_dialogue"></a>

### `duplicate_dialogue`

- API：`public`

```gdscript
func duplicate_dialogue() -> GFDialogueResource:
```

创建深拷贝。

返回：对话资源副本。

<a id="member-gfdialogueresource-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为字典。

返回：资源快照。

结构：

- `return`: 包含 start_line_id、lines 和 metadata 字段的 Dictionary；lines 为行快照字典数组。
