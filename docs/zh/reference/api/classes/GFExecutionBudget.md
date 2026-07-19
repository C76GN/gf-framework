# GFExecutionBudget

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_execution_budget.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`7.0.0`

通用执行预算与取消检查器。 用于给生成器、导入器、批处理或受控规则循环提供统一的步数、深度、 输出长度、耗时和取消 token 检查。它不调度任务，也不执行调用方逻辑。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`max_steps`](#member-gfexecutionbudget-properties-max_steps) | `var max_steps: int = 0` |
| 属性 | [`max_depth`](#member-gfexecutionbudget-properties-max_depth) | `var max_depth: int = 0` |
| 属性 | [`max_output_length`](#member-gfexecutionbudget-properties-max_output_length) | `var max_output_length: int = 0` |
| 属性 | [`max_elapsed_msec`](#member-gfexecutionbudget-properties-max_elapsed_msec) | `var max_elapsed_msec: int = 0` |
| 属性 | [`cancel_token`](#member-gfexecutionbudget-properties-cancel_token) | `var cancel_token: GFCancellationToken = null` |
| 属性 | [`metadata`](#member-gfexecutionbudget-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`_init`](#member-gfexecutionbudget-methods-_init) | `func _init(options: Dictionary = {}, clock: GFClock = null) -> void:` |
| 方法 | [`configure`](#member-gfexecutionbudget-methods-configure) | `func configure(options: Dictionary = {}) -> GFExecutionBudget:` |
| 方法 | [`set_clock`](#member-gfexecutionbudget-methods-set_clock) | `func set_clock(clock: GFClock) -> bool:` |
| 方法 | [`get_clock`](#member-gfexecutionbudget-methods-get_clock) | `func get_clock() -> GFClock:` |
| 方法 | [`reset`](#member-gfexecutionbudget-methods-reset) | `func reset() -> void:` |
| 方法 | [`bind_cancel_token`](#member-gfexecutionbudget-methods-bind_cancel_token) | `func bind_cancel_token(token: GFCancellationToken) -> GFExecutionBudget:` |
| 方法 | [`consume_steps`](#member-gfexecutionbudget-methods-consume_steps) | `func consume_steps(amount: int = 1, source_span: Variant = null) -> bool:` |
| 方法 | [`enter_depth`](#member-gfexecutionbudget-methods-enter_depth) | `func enter_depth(source_span: Variant = null) -> bool:` |
| 方法 | [`exit_depth`](#member-gfexecutionbudget-methods-exit_depth) | `func exit_depth() -> void:` |
| 方法 | [`check_output_length`](#member-gfexecutionbudget-methods-check_output_length) | `func check_output_length(output_length: int, source_span: Variant = null) -> bool:` |
| 方法 | [`check`](#member-gfexecutionbudget-methods-check) | `func check(source_span: Variant = null) -> bool:` |
| 方法 | [`is_exceeded`](#member-gfexecutionbudget-methods-is_exceeded) | `func is_exceeded() -> bool:` |
| 方法 | [`get_steps`](#member-gfexecutionbudget-methods-get_steps) | `func get_steps() -> int:` |
| 方法 | [`get_depth`](#member-gfexecutionbudget-methods-get_depth) | `func get_depth() -> int:` |
| 方法 | [`get_elapsed_msec`](#member-gfexecutionbudget-methods-get_elapsed_msec) | `func get_elapsed_msec() -> int:` |
| 方法 | [`get_violation_reason`](#member-gfexecutionbudget-methods-get_violation_reason) | `func get_violation_reason() -> StringName:` |
| 方法 | [`get_violation_message`](#member-gfexecutionbudget-methods-get_violation_message) | `func get_violation_message() -> String:` |
| 方法 | [`make_report`](#member-gfexecutionbudget-methods-make_report) | `func make_report(subject: String = "Execution budget") -> GFValidationReport:` |
| 方法 | [`get_debug_snapshot`](#member-gfexecutionbudget-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfexecutionbudget-properties-max_steps"></a>

### `max_steps`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_steps: int = 0
```

最大步数；小于等于 0 表示不限制。

<a id="member-gfexecutionbudget-properties-max_depth"></a>

### `max_depth`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_depth: int = 0
```

最大嵌套深度；小于等于 0 表示不限制。

<a id="member-gfexecutionbudget-properties-max_output_length"></a>

### `max_output_length`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_output_length: int = 0
```

最大输出文本长度；小于等于 0 表示不限制。

<a id="member-gfexecutionbudget-properties-max_elapsed_msec"></a>

### `max_elapsed_msec`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_elapsed_msec: int = 0
```

最大运行毫秒数；小于等于 0 表示不限制。

<a id="member-gfexecutionbudget-properties-cancel_token"></a>

### `cancel_token`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var cancel_token: GFCancellationToken = null
```

关联的取消 token；为空时不检查取消状态。

<a id="member-gfexecutionbudget-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方附加元数据。

结构：

- `metadata`: Dictionary，包含调用方定义的预算上下文。

## 方法

<a id="member-gfexecutionbudget-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func _init(options: Dictionary = {}, clock: GFClock = null) -> void:
```

创建执行预算。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选配置，支持 max_steps、max_depth、max_output_length、max_elapsed_msec、cancel_token 和 metadata。 |
| `clock` | 可选单调时钟；为空时使用系统时钟。 |

结构：

- `options`: Dictionary，包含执行预算配置。

<a id="member-gfexecutionbudget-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure(options: Dictionary = {}) -> GFExecutionBudget:
```

配置执行预算并重置运行状态。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选配置，支持 max_steps、max_depth、max_output_length、max_elapsed_msec、cancel_token 和 metadata。 |

返回：当前预算。

结构：

- `options`: Dictionary，包含执行预算配置。

<a id="member-gfexecutionbudget-methods-set_clock"></a>

### `set_clock`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func set_clock(clock: GFClock) -> bool:
```

替换预算耗时检查使用的单调时钟并重置计数状态。

参数：

| 名称 | 说明 |
|---|---|
| `clock` | 新单调时钟。 |

返回：时钟合法并完成替换时返回 true。

<a id="member-gfexecutionbudget-methods-get_clock"></a>

### `get_clock`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_clock() -> GFClock:
```

获取预算耗时检查使用的时钟。

返回：当前时钟。

<a id="member-gfexecutionbudget-methods-reset"></a>

### `reset`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func reset() -> void:
```

重置计数器和违规状态。

<a id="member-gfexecutionbudget-methods-bind_cancel_token"></a>

### `bind_cancel_token`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func bind_cancel_token(token: GFCancellationToken) -> GFExecutionBudget:
```

绑定取消 token。

参数：

| 名称 | 说明 |
|---|---|
| `token` | 取消 token。 |

返回：当前预算。

<a id="member-gfexecutionbudget-methods-consume_steps"></a>

### `consume_steps`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func consume_steps(amount: int = 1, source_span: Variant = null) -> bool:
```

消耗执行步数并检查预算。

参数：

| 名称 | 说明 |
|---|---|
| `amount` | 消耗步数。 |
| `source_span` | 可选源码定位。 |

返回：仍在预算内时返回 true。

结构：

- `source_span`: Variant，可传 GFSourceSpan 或兼容字典。

<a id="member-gfexecutionbudget-methods-enter_depth"></a>

### `enter_depth`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func enter_depth(source_span: Variant = null) -> bool:
```

进入一层嵌套并检查深度预算。

参数：

| 名称 | 说明 |
|---|---|
| `source_span` | 可选源码定位。 |

返回：仍在预算内时返回 true。

结构：

- `source_span`: Variant，可传 GFSourceSpan 或兼容字典。

<a id="member-gfexecutionbudget-methods-exit_depth"></a>

### `exit_depth`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func exit_depth() -> void:
```

退出一层嵌套。

<a id="member-gfexecutionbudget-methods-check_output_length"></a>

### `check_output_length`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func check_output_length(output_length: int, source_span: Variant = null) -> bool:
```

检查输出长度预算。

参数：

| 名称 | 说明 |
|---|---|
| `output_length` | 当前或即将写入后的输出长度。 |
| `source_span` | 可选源码定位。 |

返回：仍在预算内时返回 true。

结构：

- `source_span`: Variant，可传 GFSourceSpan 或兼容字典。

<a id="member-gfexecutionbudget-methods-check"></a>

### `check`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func check(source_span: Variant = null) -> bool:
```

检查取消、耗时和既有违规状态。

参数：

| 名称 | 说明 |
|---|---|
| `source_span` | 可选源码定位。 |

返回：仍可继续执行时返回 true。

结构：

- `source_span`: Variant，可传 GFSourceSpan 或兼容字典。

<a id="member-gfexecutionbudget-methods-is_exceeded"></a>

### `is_exceeded`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_exceeded() -> bool:
```

检查预算是否已经违规。

返回：已违规时返回 true。

<a id="member-gfexecutionbudget-methods-get_steps"></a>

### `get_steps`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_steps() -> int:
```

获取已消耗步数。

返回：已消耗步数。

<a id="member-gfexecutionbudget-methods-get_depth"></a>

### `get_depth`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_depth() -> int:
```

获取当前嵌套深度。

返回：当前嵌套深度。

<a id="member-gfexecutionbudget-methods-get_elapsed_msec"></a>

### `get_elapsed_msec`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_elapsed_msec() -> int:
```

获取已运行毫秒数。

返回：从最近一次 reset 起经过的毫秒数。

<a id="member-gfexecutionbudget-methods-get_violation_reason"></a>

### `get_violation_reason`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_violation_reason() -> StringName:
```

获取违规原因。

返回：稳定违规原因。

<a id="member-gfexecutionbudget-methods-get_violation_message"></a>

### `get_violation_message`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_violation_message() -> String:
```

获取违规说明。

返回：违规说明。

<a id="member-gfexecutionbudget-methods-make_report"></a>

### `make_report`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func make_report(subject: String = "Execution budget") -> GFValidationReport:
```

创建预算违规报告。

参数：

| 名称 | 说明 |
|---|---|
| `subject` | 报告主题。 |

返回：校验报告。

<a id="member-gfexecutionbudget-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：预算状态字典。

结构：

- `return`: Dictionary，包含预算限制、计数器、取消状态和违规信息。
