# GFSaveTransactionParticipant

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/pipeline/gf_save_transaction_participant.gd`
- 模块：`Save`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`8.0.0`

存档应用事务参与者基类。 项目侧或流程步骤可在 GFSavePipelineContext 中登记参与者， 让 apply_scope 统一调度 prepare / commit / rollback，避免外部副作用绕过存档事务。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`participant_id`](#member-gfsavetransactionparticipant-properties-participant_id) | `var participant_id: StringName = &""` |
| 方法 | [`prepare`](#member-gfsavetransactionparticipant-methods-prepare) | `func prepare(context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`commit`](#member-gfsavetransactionparticipant-methods-commit) | `func commit(context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`rollback`](#member-gfsavetransactionparticipant-methods-rollback) | `func rollback(context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_result`](#member-gfsavetransactionparticipant-methods-make_result) | `func make_result(ok: bool, errors: Array[String] = []) -> Dictionary:` |
| 方法 | [`_prepare_transaction`](#member-gfsavetransactionparticipant-methods-_prepare_transaction) | `func _prepare_transaction(_context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`_commit_transaction`](#member-gfsavetransactionparticipant-methods-_commit_transaction) | `func _commit_transaction(_context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`_rollback_transaction`](#member-gfsavetransactionparticipant-methods-_rollback_transaction) | `func _rollback_transaction(_context: Dictionary = {}) -> Dictionary:` |

## 属性

<a id="member-gfsavetransactionparticipant-properties-participant_id"></a>

### `participant_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var participant_id: StringName = &""
```

参与者标识，用于诊断和流程 trace。

## 方法

<a id="member-gfsavetransactionparticipant-methods-prepare"></a>

### `prepare`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func prepare(context: Dictionary = {}) -> Dictionary:
```

执行 prepare 阶段。

参数：

| 名称 | 说明 |
|---|---|
| `context` | apply_scope 调用上下文字典。 |

返回：结果字典。

结构：

- `context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
- `return`: Dictionary，包含 ok、errors 和 participant_id。

<a id="member-gfsavetransactionparticipant-methods-commit"></a>

### `commit`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func commit(context: Dictionary = {}) -> Dictionary:
```

执行 commit 阶段。

参数：

| 名称 | 说明 |
|---|---|
| `context` | apply_scope 调用上下文字典。 |

返回：结果字典。

结构：

- `context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
- `return`: Dictionary，包含 ok、errors 和 participant_id。

<a id="member-gfsavetransactionparticipant-methods-rollback"></a>

### `rollback`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func rollback(context: Dictionary = {}) -> Dictionary:
```

执行 rollback 阶段。

参数：

| 名称 | 说明 |
|---|---|
| `context` | apply_scope 调用上下文字典。 |

返回：结果字典。

结构：

- `context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
- `return`: Dictionary，包含 ok、errors 和 participant_id。

<a id="member-gfsavetransactionparticipant-methods-make_result"></a>

### `make_result`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func make_result(ok: bool, errors: Array[String] = []) -> Dictionary:
```

构造统一结果。

参数：

| 名称 | 说明 |
|---|---|
| `ok` | 是否成功。 |
| `errors` | 错误列表。 |

返回：结果字典。

结构：

- `errors`: Array[String] 错误消息。
- `return`: Dictionary，包含 ok、errors 和 participant_id。

<a id="member-gfsavetransactionparticipant-methods-_prepare_transaction"></a>

### `_prepare_transaction`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _prepare_transaction(_context: Dictionary = {}) -> Dictionary:
```

prepare 阶段钩子。失败会阻止 commit，并触发统一 rollback。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | apply_scope 调用上下文字典。 |

返回：结果字典。

结构：

- `_context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
- `return`: Dictionary，包含 ok 与 errors；返回空字典视为成功。

<a id="member-gfsavetransactionparticipant-methods-_commit_transaction"></a>

### `_commit_transaction`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _commit_transaction(_context: Dictionary = {}) -> Dictionary:
```

commit 阶段钩子。失败会触发统一 rollback。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | apply_scope 调用上下文字典。 |

返回：结果字典。

结构：

- `_context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
- `return`: Dictionary，包含 ok 与 errors；返回空字典视为成功。

<a id="member-gfsavetransactionparticipant-methods-_rollback_transaction"></a>

### `_rollback_transaction`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _rollback_transaction(_context: Dictionary = {}) -> Dictionary:
```

rollback 阶段钩子。返回失败时只记录诊断，不再抛出新异常。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | apply_scope 调用上下文字典。 |

返回：结果字典。

结构：

- `_context`: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
- `return`: Dictionary，包含 ok 与 errors；返回空字典视为成功。
