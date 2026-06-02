# GFNodeStateMachineValidator

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/state_machine/node/gf_node_state_machine_validator.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

节点状态机结构校验工具。 只检查状态机、状态组和状态资源挂接是否自洽，不执行状态切换， 也不推断项目业务中的转移规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`validate_machine`](#member-gfnodestatemachinevalidator-methods-validate_machine) | `static func validate_machine(machine: GFNodeStateMachine, options: Dictionary = {}) -> GFValidationReport:` |
| 方法 | [`validate_group`](#member-gfnodestatemachinevalidator-methods-validate_group) | `static func validate_group(group: GFNodeStateGroup, options: Dictionary = {}) -> GFValidationReport:` |
| 方法 | [`validate_state_list`](#member-gfnodestatemachinevalidator-methods-validate_state_list) | `static func validate_state_list( states: Array[GFNodeState], initial_state: StringName = &"", subject: String = "GFNodeStateList", options: Dictionary = {} ) -> GFValidationReport:` |

## 方法

<a id="member-gfnodestatemachinevalidator-methods-validate_machine"></a>

### `validate_machine`

- API：`public`

```gdscript
static func validate_machine(machine: GFNodeStateMachine, options: Dictionary = {}) -> GFValidationReport:
```

校验一个节点状态机的直接子状态和显式状态组。

参数：

| 名称 | 说明 |
|---|---|
| `machine` | 要校验的节点状态机。 |
| `options` | 可选校验选项，支持 check_state_resources、require_initial_state。 |

返回：校验报告。

结构：

- `options`: 校验选项 Dictionary；支持 check_state_resources: bool 和 require_initial_state: bool。

<a id="member-gfnodestatemachinevalidator-methods-validate_group"></a>

### `validate_group`

- API：`public`

```gdscript
static func validate_group(group: GFNodeStateGroup, options: Dictionary = {}) -> GFValidationReport:
```

校验一个节点状态组的直接子状态。

参数：

| 名称 | 说明 |
|---|---|
| `group` | 要校验的状态组。 |
| `options` | 可选校验选项，支持 check_state_resources、require_initial_state。 |

返回：校验报告。

结构：

- `options`: 校验选项 Dictionary；支持 check_state_resources: bool 和 require_initial_state: bool。

<a id="member-gfnodestatemachinevalidator-methods-validate_state_list"></a>

### `validate_state_list`

- API：`public`

```gdscript
static func validate_state_list( states: Array[GFNodeState], initial_state: StringName = &"", subject: String = "GFNodeStateList", options: Dictionary = {} ) -> GFValidationReport:
```

校验一组状态名、初始状态和状态资源挂接。

参数：

| 名称 | 说明 |
|---|---|
| `states` | 要校验的状态列表。 |
| `initial_state` | 可选初始状态名。 |
| `subject` | 报告主题。 |
| `options` | 可选校验选项，支持 check_state_resources、require_initial_state。 |

返回：校验报告。

结构：

- `states`: 元素为 GFNodeState 的状态列表。
- `options`: 校验选项 Dictionary；支持 check_state_resources: bool 和 require_initial_state: bool。
