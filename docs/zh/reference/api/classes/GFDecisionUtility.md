# GFDecisionUtility

[API Reference](../index.md) / [Decision](../extensions-decision.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/decision/runtime/gf_decision_utility.gd`
- 模块：`Decision`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`4.3.0`

通用决策集合注册与评分服务。 在架构中集中管理 GFDecisionSet，并为项目系统提供创建上下文、评分候选和选择最佳候选的入口。 它不执行候选动作，也不解释具体 AI 业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`decision_set_registered`](#member-gfdecisionutility-signals-decision_set_registered) | `signal decision_set_registered(decision_set_id: StringName, decision_set: GFDecisionSet)` |
| 信号 | [`decision_set_unregistered`](#member-gfdecisionutility-signals-decision_set_unregistered) | `signal decision_set_unregistered(decision_set_id: StringName)` |
| 方法 | [`make_context`](#member-gfdecisionutility-methods-make_context) | `func make_context( values: Dictionary = {}, subject: Object = null, target: Object = null, metadata: Dictionary = {} ) -> GFDecisionContext:` |
| 方法 | [`register_decision_set`](#member-gfdecisionutility-methods-register_decision_set) | `func register_decision_set(decision_set_id: StringName, decision_set: GFDecisionSet) -> bool:` |
| 方法 | [`unregister_decision_set`](#member-gfdecisionutility-methods-unregister_decision_set) | `func unregister_decision_set(decision_set_id: StringName) -> bool:` |
| 方法 | [`has_decision_set`](#member-gfdecisionutility-methods-has_decision_set) | `func has_decision_set(decision_set_id: StringName) -> bool:` |
| 方法 | [`get_decision_set`](#member-gfdecisionutility-methods-get_decision_set) | `func get_decision_set(decision_set_id: StringName) -> GFDecisionSet:` |
| 方法 | [`get_decision_set_ids`](#member-gfdecisionutility-methods-get_decision_set_ids) | `func get_decision_set_ids() -> PackedStringArray:` |
| 方法 | [`clear_decision_sets`](#member-gfdecisionutility-methods-clear_decision_sets) | `func clear_decision_sets() -> void:` |
| 方法 | [`score_all`](#member-gfdecisionutility-methods-score_all) | `func score_all(decision_set_id: StringName, context: GFDecisionContext) -> Array[GFDecisionScore]:` |
| 方法 | [`evaluate`](#member-gfdecisionutility-methods-evaluate) | `func evaluate(decision_set_id: StringName, context: GFDecisionContext) -> GFDecisionEvaluation:` |
| 方法 | [`select_best`](#member-gfdecisionutility-methods-select_best) | `func select_best(decision_set_id: StringName, context: GFDecisionContext) -> GFDecisionScore:` |
| 方法 | [`get_debug_snapshot`](#member-gfdecisionutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfdecisionutility-signals-decision_set_registered"></a>

### `decision_set_registered`

- API：`public`

```gdscript
signal decision_set_registered(decision_set_id: StringName, decision_set: GFDecisionSet)
```

当决策集合注册后发出。

参数：

| 名称 | 说明 |
|---|---|
| `decision_set_id` | 决策集合标识。 |
| `decision_set` | 已注册的决策集合。 |

<a id="member-gfdecisionutility-signals-decision_set_unregistered"></a>

### `decision_set_unregistered`

- API：`public`

```gdscript
signal decision_set_unregistered(decision_set_id: StringName)
```

当决策集合注销后发出。

参数：

| 名称 | 说明 |
|---|---|
| `decision_set_id` | 决策集合标识。 |

## 方法

<a id="member-gfdecisionutility-methods-make_context"></a>

### `make_context`

- API：`public`

```gdscript
func make_context( values: Dictionary = {}, subject: Object = null, target: Object = null, metadata: Dictionary = {} ) -> GFDecisionContext:
```

创建决策上下文。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 初始黑板值。 |
| `subject` | 决策主体。 |
| `target` | 可选决策目标。 |
| `metadata` | 上下文元数据。 |

返回：新决策上下文。

结构：

- `values`: Dictionary[StringName, Variant] initial blackboard values.
- `metadata`: Dictionary[StringName, Variant] project-defined decision metadata.

<a id="member-gfdecisionutility-methods-register_decision_set"></a>

### `register_decision_set`

- API：`public`
- 首次版本：`4.3.0`

```gdscript
func register_decision_set(decision_set_id: StringName, decision_set: GFDecisionSet) -> bool:
```

注册决策集合。 registry key 是注册期权威身份；同一 Resource 实例不能同时注册到第二个 key，注册后的 ID 漂移会在 Utility 访问边界恢复。

参数：

| 名称 | 说明 |
|---|---|
| `decision_set_id` | 决策集合标识。 |
| `decision_set` | 决策集合资源。 |

返回：注册成功返回 true。

<a id="member-gfdecisionutility-methods-unregister_decision_set"></a>

### `unregister_decision_set`

- API：`public`

```gdscript
func unregister_decision_set(decision_set_id: StringName) -> bool:
```

注销决策集合。

参数：

| 名称 | 说明 |
|---|---|
| `decision_set_id` | 决策集合标识。 |

返回：注销成功返回 true。

<a id="member-gfdecisionutility-methods-has_decision_set"></a>

### `has_decision_set`

- API：`public`
- 首次版本：`4.3.0`

```gdscript
func has_decision_set(decision_set_id: StringName) -> bool:
```

检查决策集合是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `decision_set_id` | 决策集合标识。 |

返回：存在返回 true。

<a id="member-gfdecisionutility-methods-get_decision_set"></a>

### `get_decision_set`

- API：`public`
- 首次版本：`4.3.0`

```gdscript
func get_decision_set(decision_set_id: StringName) -> GFDecisionSet:
```

获取决策集合。

参数：

| 名称 | 说明 |
|---|---|
| `decision_set_id` | 决策集合标识。 |

返回：决策集合；不存在时返回 null。

<a id="member-gfdecisionutility-methods-get_decision_set_ids"></a>

### `get_decision_set_ids`

- API：`public`
- 首次版本：`4.3.0`

```gdscript
func get_decision_set_ids() -> PackedStringArray:
```

获取已注册决策集合标识。

返回：排序后的决策集合标识。

<a id="member-gfdecisionutility-methods-clear_decision_sets"></a>

### `clear_decision_sets`

- API：`public`

```gdscript
func clear_decision_sets() -> void:
```

清空全部决策集合。

<a id="member-gfdecisionutility-methods-score_all"></a>

### `score_all`

- API：`public`
- 首次版本：`4.3.0`

```gdscript
func score_all(decision_set_id: StringName, context: GFDecisionContext) -> Array[GFDecisionScore]:
```

计算指定决策集合中的所有候选分数。

参数：

| 名称 | 说明 |
|---|---|
| `decision_set_id` | 决策集合标识。 |
| `context` | 决策上下文。 |

返回：按分数降序排列的评分结果。

结构：

- `return`: Array[GFDecisionScore]，每个候选的评分结果；集合不存在时为空数组。

<a id="member-gfdecisionutility-methods-evaluate"></a>

### `evaluate`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func evaluate(decision_set_id: StringName, context: GFDecisionContext) -> GFDecisionEvaluation:
```

一次性评价指定决策集合。

参数：

| 名称 | 说明 |
|---|---|
| `decision_set_id` | 决策集合标识。 |
| `context` | 决策上下文。 |

返回：决策评价结果；集合不存在时返回空评价和 rejected best_score。

<a id="member-gfdecisionutility-methods-select_best"></a>

### `select_best`

- API：`public`

```gdscript
func select_best(decision_set_id: StringName, context: GFDecisionContext) -> GFDecisionScore:
```

选择指定决策集合中的最佳候选。

参数：

| 名称 | 说明 |
|---|---|
| `decision_set_id` | 决策集合标识。 |
| `context` | 决策上下文。 |

返回：最佳评分结果；集合不存在时返回 rejected score。

<a id="member-gfdecisionutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取决策服务调试快照。

返回：调试快照字典。

结构：

- `return`: 包含 decision_set_count 和 decision_set_ids 字段的 Dictionary。
