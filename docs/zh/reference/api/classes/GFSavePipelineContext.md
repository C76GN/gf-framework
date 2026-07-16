# GFSavePipelineContext

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/pipeline/gf_save_pipeline_context.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

存档图流程上下文。 在一次 gather/apply 操作中收集通用事件、警告、错误与共享数据。 上下文通过调用者传入的 context 字典传播，不要求存档载荷写死任何字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`operation`](#member-gfsavepipelinecontext-properties-operation) | `var operation: StringName = &""` |
| 属性 | [`root_scope_key`](#member-gfsavepipelinecontext-properties-root_scope_key) | `var root_scope_key: StringName = &""` |
| 属性 | [`shared`](#member-gfsavepipelinecontext-properties-shared) | `var shared: Dictionary = {}` |
| 属性 | [`events`](#member-gfsavepipelinecontext-properties-events) | `var events: Array[GFSavePipelineEvent] = []` |
| 属性 | [`warnings`](#member-gfsavepipelinecontext-properties-warnings) | `var warnings: PackedStringArray = PackedStringArray()` |
| 属性 | [`errors`](#member-gfsavepipelinecontext-properties-errors) | `var errors: PackedStringArray = PackedStringArray()` |
| 属性 | [`transaction_participants`](#member-gfsavepipelinecontext-properties-transaction_participants) | `var transaction_participants: Array[GFSaveTransactionParticipant] = []` |
| 属性 | [`started_at_msec`](#member-gfsavepipelinecontext-properties-started_at_msec) | `var started_at_msec: int = 0` |
| 属性 | [`finished_at_msec`](#member-gfsavepipelinecontext-properties-finished_at_msec) | `var finished_at_msec: int = 0` |
| 方法 | [`begin_operation`](#member-gfsavepipelinecontext-methods-begin_operation) | `func begin_operation( p_operation: StringName, p_root_scope_key: StringName = &"", p_shared: Dictionary = {} ) -> GFSavePipelineContext:` |
| 方法 | [`record_event`](#member-gfsavepipelinecontext-methods-record_event) | `func record_event( stage: StringName, scope: Object = null, source: Object = null, message: String = "", payload: Dictionary = {}, severity: StringName = &"info" ) -> GFSavePipelineEvent:` |
| 方法 | [`add_warning`](#member-gfsavepipelinecontext-methods-add_warning) | `func add_warning(message: String, payload: Dictionary = {}) -> void:` |
| 方法 | [`add_error`](#member-gfsavepipelinecontext-methods-add_error) | `func add_error(message: String, payload: Dictionary = {}) -> void:` |
| 方法 | [`register_transaction_participant`](#member-gfsavepipelinecontext-methods-register_transaction_participant) | `func register_transaction_participant(participant: GFSaveTransactionParticipant) -> void:` |
| 方法 | [`unregister_transaction_participant`](#member-gfsavepipelinecontext-methods-unregister_transaction_participant) | `func unregister_transaction_participant(participant: GFSaveTransactionParticipant) -> void:` |
| 方法 | [`get_transaction_participants`](#member-gfsavepipelinecontext-methods-get_transaction_participants) | `func get_transaction_participants() -> Array[GFSaveTransactionParticipant]:` |
| 方法 | [`clear_transaction_participants`](#member-gfsavepipelinecontext-methods-clear_transaction_participants) | `func clear_transaction_participants() -> void:` |
| 方法 | [`finish`](#member-gfsavepipelinecontext-methods-finish) | `func finish() -> void:` |
| 方法 | [`is_finished`](#member-gfsavepipelinecontext-methods-is_finished) | `func is_finished() -> bool:` |
| 方法 | [`get_elapsed_msec`](#member-gfsavepipelinecontext-methods-get_elapsed_msec) | `func get_elapsed_msec() -> int:` |
| 方法 | [`to_dict`](#member-gfsavepipelinecontext-methods-to_dict) | `func to_dict(include_events: bool = true) -> Dictionary:` |

## 属性

<a id="member-gfsavepipelinecontext-properties-operation"></a>

### `operation`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var operation: StringName = &""
```

当前操作类型，如 gather 或 apply。

<a id="member-gfsavepipelinecontext-properties-root_scope_key"></a>

### `root_scope_key`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var root_scope_key: StringName = &""
```

根作用域键。

<a id="member-gfsavepipelinecontext-properties-shared"></a>

### `shared`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var shared: Dictionary = {}
```

流程共享数据。项目层可写入自己的临时状态。

结构：

- `shared`: Dictionary，一次流程中的临时共享字段，不会自动写入存档载荷。

<a id="member-gfsavepipelinecontext-properties-events"></a>

### `events`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var events: Array[GFSavePipelineEvent] = []
```

流程事件列表。

<a id="member-gfsavepipelinecontext-properties-warnings"></a>

### `warnings`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var warnings: PackedStringArray = PackedStringArray()
```

通用警告信息。

<a id="member-gfsavepipelinecontext-properties-errors"></a>

### `errors`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var errors: PackedStringArray = PackedStringArray()
```

通用错误信息。

<a id="member-gfsavepipelinecontext-properties-transaction_participants"></a>

### `transaction_participants`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var transaction_participants: Array[GFSaveTransactionParticipant] = []
```

本次 apply 事务参与者列表。

<a id="member-gfsavepipelinecontext-properties-started_at_msec"></a>

### `started_at_msec`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var started_at_msec: int = 0
```

开始时间。

<a id="member-gfsavepipelinecontext-properties-finished_at_msec"></a>

### `finished_at_msec`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var finished_at_msec: int = 0
```

结束时间。

## 方法

<a id="member-gfsavepipelinecontext-methods-begin_operation"></a>

### `begin_operation`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func begin_operation( p_operation: StringName, p_root_scope_key: StringName = &"", p_shared: Dictionary = {} ) -> GFSavePipelineContext:
```

开始一次流程操作。

参数：

| 名称 | 说明 |
|---|---|
| `p_operation` | 操作类型。 |
| `p_root_scope_key` | 根作用域键。 |
| `p_shared` | 初始共享数据。 |

返回：当前上下文。

结构：

- `p_shared`: Dictionary，一次流程中的临时共享字段，不会自动写入存档载荷。

<a id="member-gfsavepipelinecontext-methods-record_event"></a>

### `record_event`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func record_event( stage: StringName, scope: Object = null, source: Object = null, message: String = "", payload: Dictionary = {}, severity: StringName = &"info" ) -> GFSavePipelineEvent:
```

记录流程事件。

参数：

| 名称 | 说明 |
|---|---|
| `stage` | 阶段标识。 |
| `scope` | 可选 Scope。 |
| `source` | 可选 Source。 |
| `message` | 调试消息。 |
| `payload` | 附加载荷。 |
| `severity` | 严重级别。 |

返回：新事件。

结构：

- `payload`: Dictionary，项目或流程步骤附加的诊断字段。

<a id="member-gfsavepipelinecontext-methods-add_warning"></a>

### `add_warning`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func add_warning(message: String, payload: Dictionary = {}) -> void:
```

记录警告并同步生成 warning 事件。

参数：

| 名称 | 说明 |
|---|---|
| `message` | 警告内容。 |
| `payload` | 附加载荷。 |

结构：

- `payload`: Dictionary，项目或流程步骤附加的诊断字段。

<a id="member-gfsavepipelinecontext-methods-add_error"></a>

### `add_error`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func add_error(message: String, payload: Dictionary = {}) -> void:
```

记录错误并同步生成 error 事件。

参数：

| 名称 | 说明 |
|---|---|
| `message` | 错误内容。 |
| `payload` | 附加载荷。 |

结构：

- `payload`: Dictionary，项目或流程步骤附加的诊断字段。

<a id="member-gfsavepipelinecontext-methods-register_transaction_participant"></a>

### `register_transaction_participant`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_transaction_participant(participant: GFSaveTransactionParticipant) -> void:
```

登记本次 apply 事务参与者。

参数：

| 名称 | 说明 |
|---|---|
| `participant` | 参与 prepare / commit / rollback 的事务对象。 |

<a id="member-gfsavepipelinecontext-methods-unregister_transaction_participant"></a>

### `unregister_transaction_participant`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_transaction_participant(participant: GFSaveTransactionParticipant) -> void:
```

注销本次 apply 事务参与者。

参数：

| 名称 | 说明 |
|---|---|
| `participant` | 要注销的事务对象。 |

<a id="member-gfsavepipelinecontext-methods-get_transaction_participants"></a>

### `get_transaction_participants`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_transaction_participants() -> Array[GFSaveTransactionParticipant]:
```

获取本次 apply 事务参与者副本。

返回：事务参与者数组。

<a id="member-gfsavepipelinecontext-methods-clear_transaction_participants"></a>

### `clear_transaction_participants`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_transaction_participants() -> void:
```

清空本次 apply 事务参与者。

<a id="member-gfsavepipelinecontext-methods-finish"></a>

### `finish`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func finish() -> void:
```

标记流程结束。

<a id="member-gfsavepipelinecontext-methods-is_finished"></a>

### `is_finished`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func is_finished() -> bool:
```

当前流程是否已结束。

返回：已结束返回 true。

<a id="member-gfsavepipelinecontext-methods-get_elapsed_msec"></a>

### `get_elapsed_msec`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_elapsed_msec() -> int:
```

获取耗时毫秒。

返回：耗时。

<a id="member-gfsavepipelinecontext-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func to_dict(include_events: bool = true) -> Dictionary:
```

转换为 Dictionary。

参数：

| 名称 | 说明 |
|---|---|
| `include_events` | 是否包含事件列表。 |

返回：上下文字典。

结构：

- `return`: Dictionary，包含 operation、root_scope_key、JSON-safe shared、warnings、errors、started_at_msec、finished_at_msec、elapsed_msec、event_count；include_events 为 true 时包含 events: Array[Dictionary]。
