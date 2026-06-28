# GFActivationTransaction

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/policy/gf_activation_transaction.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

非代码动态内容的激活事务。 将“验证、应用、失败回滚、报告”收敛为通用事务流程。它只调度调用方显式传入的 Callable，不加载脚本、不执行远端载荷，也不规定内容包、配置或资源注册表的业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATE_PENDING`](#member-gfactivationtransaction-constants-state_pending) | `const STATE_PENDING: StringName = &"pending"` |
| 常量 | [`STATE_PREPARED`](#member-gfactivationtransaction-constants-state_prepared) | `const STATE_PREPARED: StringName = &"prepared"` |
| 常量 | [`STATE_COMMITTED`](#member-gfactivationtransaction-constants-state_committed) | `const STATE_COMMITTED: StringName = &"committed"` |
| 常量 | [`STATE_ROLLED_BACK`](#member-gfactivationtransaction-constants-state_rolled_back) | `const STATE_ROLLED_BACK: StringName = &"rolled_back"` |
| 常量 | [`STATE_FAILED`](#member-gfactivationtransaction-constants-state_failed) | `const STATE_FAILED: StringName = &"failed"` |
| 属性 | [`transaction_id`](#member-gfactivationtransaction-properties-transaction_id) | `var transaction_id: StringName = &""` |
| 属性 | [`subject`](#member-gfactivationtransaction-properties-subject) | `var subject: String = _DEFAULT_SUBJECT` |
| 属性 | [`state`](#member-gfactivationtransaction-properties-state) | `var state: StringName = STATE_PENDING` |
| 属性 | [`metadata`](#member-gfactivationtransaction-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfactivationtransaction-methods-configure) | `func configure( p_transaction_id: StringName, p_subject: String = _DEFAULT_SUBJECT, p_metadata: Dictionary = {} ) -> GFActivationTransaction:` |
| 方法 | [`clear`](#member-gfactivationtransaction-methods-clear) | `func clear() -> void:` |
| 方法 | [`add_step`](#member-gfactivationtransaction-methods-add_step) | `func add_step( step_id: StringName, apply_callback: Callable, rollback_callback: Callable = Callable(), options: Dictionary = {} ) -> bool:` |
| 方法 | [`prepare`](#member-gfactivationtransaction-methods-prepare) | `func prepare(context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`commit`](#member-gfactivationtransaction-methods-commit) | `func commit(context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`rollback`](#member-gfactivationtransaction-methods-rollback) | `func rollback(context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_report`](#member-gfactivationtransaction-methods-get_report) | `func get_report(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`is_step_applied`](#member-gfactivationtransaction-methods-is_step_applied) | `func is_step_applied(step_id: StringName) -> bool:` |

## 常量

<a id="member-gfactivationtransaction-constants-state_pending"></a>

### `STATE_PENDING`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATE_PENDING: StringName = &"pending"
```

事务尚未准备。

<a id="member-gfactivationtransaction-constants-state_prepared"></a>

### `STATE_PREPARED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATE_PREPARED: StringName = &"prepared"
```

事务已通过验证。

<a id="member-gfactivationtransaction-constants-state_committed"></a>

### `STATE_COMMITTED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATE_COMMITTED: StringName = &"committed"
```

事务已提交。

<a id="member-gfactivationtransaction-constants-state_rolled_back"></a>

### `STATE_ROLLED_BACK`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATE_ROLLED_BACK: StringName = &"rolled_back"
```

事务失败后已执行回滚。

<a id="member-gfactivationtransaction-constants-state_failed"></a>

### `STATE_FAILED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATE_FAILED: StringName = &"failed"
```

事务失败且未完成回滚。

## 属性

<a id="member-gfactivationtransaction-properties-transaction_id"></a>

### `transaction_id`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var transaction_id: StringName = &""
```

事务 ID。

<a id="member-gfactivationtransaction-properties-subject"></a>

### `subject`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var subject: String = _DEFAULT_SUBJECT
```

报告主题。

<a id="member-gfactivationtransaction-properties-state"></a>

### `state`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var state: StringName = STATE_PENDING
```

当前事务状态。

<a id="member-gfactivationtransaction-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义元数据。

结构：

- `metadata`: Dictionary caller-defined transaction metadata.

## 方法

<a id="member-gfactivationtransaction-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure( p_transaction_id: StringName, p_subject: String = _DEFAULT_SUBJECT, p_metadata: Dictionary = {} ) -> GFActivationTransaction:
```

配置事务。

参数：

| 名称 | 说明 |
|---|---|
| `p_transaction_id` | 事务 ID。 |
| `p_subject` | 报告主题。 |
| `p_metadata` | 调用方元数据。 |

返回：当前事务。

结构：

- `p_metadata`: Dictionary caller-defined transaction metadata.

<a id="member-gfactivationtransaction-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空事务。

<a id="member-gfactivationtransaction-methods-add_step"></a>

### `add_step`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_step( step_id: StringName, apply_callback: Callable, rollback_callback: Callable = Callable(), options: Dictionary = {} ) -> bool:
```

添加事务步骤。 apply_callback 与 rollback_callback 的推荐签名为 `func(context: Dictionary) -> Variant`。 validate_callback 可通过 options 传入，签名相同。返回 false、非 OK Error、或 `{ "ok": false }` 会进入失败报告。

参数：

| 名称 | 说明 |
|---|---|
| `step_id` | 步骤 ID。 |
| `apply_callback` | 应用回调。 |
| `rollback_callback` | 回滚回调。 |
| `options` | 步骤选项，支持 label、metadata、validate_callback 和 rollback_required。 |

返回：添加成功返回 true。

结构：

- `options`: Dictionary step metadata.

<a id="member-gfactivationtransaction-methods-prepare"></a>

### `prepare`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func prepare(context: Dictionary = {}) -> Dictionary:
```

验证事务步骤。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 调用方上下文。 |

返回：GFValidationReportDictionary 兼容报告。

结构：

- `context`: Dictionary caller-defined activation context.
- `return`: Dictionary with ok, healthy, transaction_id, state, steps, issues, summary, and next_action.

<a id="member-gfactivationtransaction-methods-commit"></a>

### `commit`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func commit(context: Dictionary = {}) -> Dictionary:
```

提交事务，失败时自动回滚已应用步骤。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 调用方上下文。 |

返回：GFValidationReportDictionary 兼容报告。

结构：

- `context`: Dictionary caller-defined activation context.
- `return`: Dictionary with ok, healthy, transaction_id, state, steps, issues, summary, and next_action.

<a id="member-gfactivationtransaction-methods-rollback"></a>

### `rollback`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func rollback(context: Dictionary = {}) -> Dictionary:
```

显式回滚已应用步骤。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 调用方上下文。 |

返回：GFValidationReportDictionary 兼容报告。

结构：

- `context`: Dictionary caller-defined activation context.
- `return`: Dictionary with ok, healthy, transaction_id, state, steps, issues, summary, and next_action.

<a id="member-gfactivationtransaction-methods-get_report"></a>

### `get_report`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_report(options: Dictionary = {}) -> Dictionary:
```

获取事务报告。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 报告选项，支持 fallback_action、no_action 和 warnings_as_errors。 |

返回：GFValidationReportDictionary 兼容报告。

结构：

- `options`: Dictionary report options.
- `return`: Dictionary with ok, healthy, transaction_id, state, steps, issues, summary, and next_action.

<a id="member-gfactivationtransaction-methods-is_step_applied"></a>

### `is_step_applied`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_step_applied(step_id: StringName) -> bool:
```

检查步骤是否已应用。

参数：

| 名称 | 说明 |
|---|---|
| `step_id` | 步骤 ID。 |

返回：已应用返回 true。
