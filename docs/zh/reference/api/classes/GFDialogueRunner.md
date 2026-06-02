# GFDialogueRunner

[API Reference](../index.md) / [Dialogue](../extensions-dialogue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/dialogue/runtime/gf_dialogue_runner.gd`
- 模块：`Dialogue`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用对话资源执行器。 Runner 只沿 GFDialogueResource 的行、响应、跳转、条件和 mutation 推进， 并发出结构化事件。显示、输入、存档和业务状态由项目层决定。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`dialogue_started`](#member-gfdialoguerunner-signals-dialogue_started) | `signal dialogue_started(resource: GFDialogueResource)` |
| 信号 | [`line_reached`](#member-gfdialoguerunner-signals-line_reached) | `signal line_reached(line: GFDialogueLine)` |
| 信号 | [`mutation_requested`](#member-gfdialoguerunner-signals-mutation_requested) | `signal mutation_requested(mutation_id: StringName, payload: Variant, line: GFDialogueLine)` |
| 信号 | [`dialogue_ended`](#member-gfdialoguerunner-signals-dialogue_ended) | `signal dialogue_ended(resource: GFDialogueResource)` |
| 信号 | [`line_blocked`](#member-gfdialoguerunner-signals-line_blocked) | `signal line_blocked(line_id: StringName, reason: StringName)` |
| 属性 | [`max_steps_per_advance`](#member-gfdialoguerunner-properties-max_steps_per_advance) | `var max_steps_per_advance: int = 1024` |
| 属性 | [`skip_blocked_lines`](#member-gfdialoguerunner-properties-skip_blocked_lines) | `var skip_blocked_lines: bool = true` |
| 方法 | [`start`](#member-gfdialoguerunner-methods-start) | `func start( resource: GFDialogueResource, start_line_id: StringName = &"", context: GFDialogueContext = null ) -> GFDialogueLine:` |
| 方法 | [`advance`](#member-gfdialoguerunner-methods-advance) | `func advance(response_id: StringName = &"") -> GFDialogueLine:` |
| 方法 | [`choose_response`](#member-gfdialoguerunner-methods-choose_response) | `func choose_response(response_id: StringName) -> GFDialogueLine:` |
| 方法 | [`stop`](#member-gfdialoguerunner-methods-stop) | `func stop() -> void:` |
| 方法 | [`get_current_line`](#member-gfdialoguerunner-methods-get_current_line) | `func get_current_line() -> GFDialogueLine:` |
| 方法 | [`get_available_responses`](#member-gfdialoguerunner-methods-get_available_responses) | `func get_available_responses() -> Array[GFDialogueResponse]:` |
| 方法 | [`is_running`](#member-gfdialoguerunner-methods-is_running) | `func is_running() -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfdialoguerunner-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfdialoguerunner-signals-dialogue_started"></a>

### `dialogue_started`

- API：`public`

```gdscript
signal dialogue_started(resource: GFDialogueResource)
```

对话开始时发出。

参数：

| 名称 | 说明 |
|---|---|
| `resource` | 对话资源。 |

<a id="member-gfdialoguerunner-signals-line_reached"></a>

### `line_reached`

- API：`public`

```gdscript
signal line_reached(line: GFDialogueLine)
```

到达可展示文本行时发出。

参数：

| 名称 | 说明 |
|---|---|
| `line` | 当前行。 |

<a id="member-gfdialoguerunner-signals-mutation_requested"></a>

### `mutation_requested`

- API：`public`

```gdscript
signal mutation_requested(mutation_id: StringName, payload: Variant, line: GFDialogueLine)
```

请求执行 mutation 时发出。

参数：

| 名称 | 说明 |
|---|---|
| `mutation_id` | mutation ID。 |
| `payload` | mutation 载荷。 |
| `line` | 当前行。 |

结构：

- `payload`: mutation 处理器接收的任意项目载荷；框架只透传。

<a id="member-gfdialoguerunner-signals-dialogue_ended"></a>

### `dialogue_ended`

- API：`public`

```gdscript
signal dialogue_ended(resource: GFDialogueResource)
```

对话结束时发出。

参数：

| 名称 | 说明 |
|---|---|
| `resource` | 对话资源。 |

<a id="member-gfdialoguerunner-signals-line_blocked"></a>

### `line_blocked`

- API：`public`

```gdscript
signal line_blocked(line_id: StringName, reason: StringName)
```

推进被阻止时发出。

参数：

| 名称 | 说明 |
|---|---|
| `line_id` | 被阻止的行 ID。 |
| `reason` | 原因。 |

## 属性

<a id="member-gfdialoguerunner-properties-max_steps_per_advance"></a>

### `max_steps_per_advance`

- API：`public`

```gdscript
var max_steps_per_advance: int = 1024
```

最多连续推进的非展示行数量，避免错误资源无限循环。

<a id="member-gfdialoguerunner-properties-skip_blocked_lines"></a>

### `skip_blocked_lines`

- API：`public`

```gdscript
var skip_blocked_lines: bool = true
```

条件不通过且没有 fallback 时，是否尝试跳到默认后继。

## 方法

<a id="member-gfdialoguerunner-methods-start"></a>

### `start`

- API：`public`

```gdscript
func start( resource: GFDialogueResource, start_line_id: StringName = &"", context: GFDialogueContext = null ) -> GFDialogueLine:
```

开始对话。

参数：

| 名称 | 说明 |
|---|---|
| `resource` | 对话资源。 |
| `start_line_id` | 可选起始行 ID。 |
| `context` | 可选上下文。 |

返回：到达的第一条可展示行；结束或失败时返回 null。

<a id="member-gfdialoguerunner-methods-advance"></a>

### `advance`

- API：`public`

```gdscript
func advance(response_id: StringName = &"") -> GFDialogueLine:
```

推进对话。

参数：

| 名称 | 说明 |
|---|---|
| `response_id` | 可选响应 ID；非空时从当前行选择响应后推进。 |

返回：到达的下一条可展示行；结束或失败时返回 null。

<a id="member-gfdialoguerunner-methods-choose_response"></a>

### `choose_response`

- API：`public`

```gdscript
func choose_response(response_id: StringName) -> GFDialogueLine:
```

选择当前行响应并推进。

参数：

| 名称 | 说明 |
|---|---|
| `response_id` | 响应 ID。 |

返回：到达的下一条可展示行；结束或失败时返回 null。

<a id="member-gfdialoguerunner-methods-stop"></a>

### `stop`

- API：`public`

```gdscript
func stop() -> void:
```

结束当前对话。

<a id="member-gfdialoguerunner-methods-get_current_line"></a>

### `get_current_line`

- API：`public`

```gdscript
func get_current_line() -> GFDialogueLine:
```

获取当前行。

返回：当前可展示行；没有时返回 null。

<a id="member-gfdialoguerunner-methods-get_available_responses"></a>

### `get_available_responses`

- API：`public`

```gdscript
func get_available_responses() -> Array[GFDialogueResponse]:
```

获取当前可用响应。

返回：响应列表。

<a id="member-gfdialoguerunner-methods-is_running"></a>

### `is_running`

- API：`public`

```gdscript
func is_running() -> bool:
```

检查是否正在运行。

返回：运行中返回 true。

<a id="member-gfdialoguerunner-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取运行快照。

返回：调试快照。

结构：

- `return`: 包含 is_running、current_line_id、has_resource 和 context_values 字段的 Dictionary。
