# GFInputConflictAnalyzer

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/rebinding/gf_input_conflict_analyzer.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

输入上下文冲突分析工具。 只读取输入资源与可选重映射配置，不参与运行时输入分发。适合设置界面、 编辑器工具或测试在应用重绑定前检查同一输入是否被多个抽象动作占用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`analyze_context`](#member-gfinputconflictanalyzer-methods-analyze_context) | `static func analyze_context( context: GFInputContext, remap_config: GFInputRemapConfig = null, include_non_remappable: bool = true ) -> Array[Dictionary]:` |
| 方法 | [`analyze_contexts`](#member-gfinputconflictanalyzer-methods-analyze_contexts) | `static func analyze_contexts( contexts: Array[GFInputContext], remap_config: GFInputRemapConfig = null, include_cross_context: bool = false, include_non_remappable: bool = true ) -> Array[Dictionary]:` |
| 方法 | [`build_rebind_report`](#member-gfinputconflictanalyzer-methods-build_rebind_report) | `static func build_rebind_report( contexts: Array[GFInputContext], remap_config: GFInputRemapConfig = null, include_cross_context: bool = false, include_non_remappable: bool = true ) -> Dictionary:` |
| 方法 | [`collect_binding_items`](#member-gfinputconflictanalyzer-methods-collect_binding_items) | `static func collect_binding_items( contexts: Array[GFInputContext], remap_config: GFInputRemapConfig = null, include_non_remappable: bool = true ) -> Array[Dictionary]:` |
| 方法 | [`get_event_signature`](#member-gfinputconflictanalyzer-methods-get_event_signature) | `static func get_event_signature(input_event: InputEvent, match_device: bool = false) -> String:` |
| 方法 | [`are_events_equivalent`](#member-gfinputconflictanalyzer-methods-are_events_equivalent) | `static func are_events_equivalent( left_event: InputEvent, right_event: InputEvent, left_match_device: bool = false, right_match_device: bool = false ) -> bool:` |

## 方法

<a id="member-gfinputconflictanalyzer-methods-analyze_context"></a>

### `analyze_context`

- API：`public`

```gdscript
static func analyze_context( context: GFInputContext, remap_config: GFInputRemapConfig = null, include_non_remappable: bool = true ) -> Array[Dictionary]:
```

分析单个上下文内的绑定冲突。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 输入上下文。 |
| `remap_config` | 可选重映射配置。 |
| `include_non_remappable` | 是否包含不可重绑动作或绑定。 |

返回：冲突列表。

结构：

- `return`: Array，包含冲突 Dictionary 记录，字段包括 context/action/binding id、other_* id、event_text、signature 和 items。

<a id="member-gfinputconflictanalyzer-methods-analyze_contexts"></a>

### `analyze_contexts`

- API：`public`

```gdscript
static func analyze_contexts( contexts: Array[GFInputContext], remap_config: GFInputRemapConfig = null, include_cross_context: bool = false, include_non_remappable: bool = true ) -> Array[Dictionary]:
```

分析多个上下文的绑定冲突。

参数：

| 名称 | 说明 |
|---|---|
| `contexts` | 输入上下文列表。 |
| `remap_config` | 可选重映射配置。 |
| `include_cross_context` | 是否报告跨上下文冲突。 |
| `include_non_remappable` | 是否包含不可重绑动作或绑定。 |

返回：冲突列表。

结构：

- `contexts`: Array[GFInputContext] of contexts to analyze.
- `return`: Array，包含冲突 Dictionary 记录，字段包括 context/action/binding id、other_* id、event_text、signature 和 items。

<a id="member-gfinputconflictanalyzer-methods-build_rebind_report"></a>

### `build_rebind_report`

- API：`public`

```gdscript
static func build_rebind_report( contexts: Array[GFInputContext], remap_config: GFInputRemapConfig = null, include_cross_context: bool = false, include_non_remappable: bool = true ) -> Dictionary:
```

构建重绑定诊断报告。

参数：

| 名称 | 说明 |
|---|---|
| `contexts` | 输入上下文列表。 |
| `remap_config` | 可选重映射配置。 |
| `include_cross_context` | 是否报告跨上下文冲突。 |
| `include_non_remappable` | 是否包含不可重绑动作或绑定。 |

返回：包含条目与冲突的报告。

结构：

- `contexts`: Array[GFInputContext] of contexts to analyze.
- `return`: Dictionary，包含 ok、context_count、item_count、conflict_count、items 和 conflicts。

<a id="member-gfinputconflictanalyzer-methods-collect_binding_items"></a>

### `collect_binding_items`

- API：`public`

```gdscript
static func collect_binding_items( contexts: Array[GFInputContext], remap_config: GFInputRemapConfig = null, include_non_remappable: bool = true ) -> Array[Dictionary]:
```

收集上下文中的有效绑定条目。

参数：

| 名称 | 说明 |
|---|---|
| `contexts` | 输入上下文列表。 |
| `remap_config` | 可选重映射配置。 |
| `include_non_remappable` | 是否包含不可重绑动作或绑定。 |

返回：绑定条目列表。

结构：

- `contexts`: Array[GFInputContext] of contexts to inspect.
- `return`: Array，包含 item Dictionary 记录，字段包括 context/action/binding id、event、event_text、event_key、signature、device_scope 和 match_device。

<a id="member-gfinputconflictanalyzer-methods-get_event_signature"></a>

### `get_event_signature`

- API：`public`

```gdscript
static func get_event_signature(input_event: InputEvent, match_device: bool = false) -> String:
```

获取输入事件的稳定签名。

参数：

| 名称 | 说明 |
|---|---|
| `input_event` | 输入事件。 |
| `match_device` | 是否把设备 ID 纳入签名。 |

返回：签名字符串；空事件返回空字符串。

<a id="member-gfinputconflictanalyzer-methods-are_events_equivalent"></a>

### `are_events_equivalent`

- API：`public`

```gdscript
static func are_events_equivalent( left_event: InputEvent, right_event: InputEvent, left_match_device: bool = false, right_match_device: bool = false ) -> bool:
```

判断两个输入事件是否会在绑定层互相冲突。

参数：

| 名称 | 说明 |
|---|---|
| `left_event` | 左侧输入事件。 |
| `right_event` | 右侧输入事件。 |
| `left_match_device` | 左侧是否要求设备精确匹配。 |
| `right_match_device` | 右侧是否要求设备精确匹配。 |

返回：冲突返回 true。
