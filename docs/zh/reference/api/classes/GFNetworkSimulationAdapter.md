# GFNetworkSimulationAdapter

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/simulation/gf_network_simulation_adapter.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`unreleased`

网络协调器的项目模拟协议。 项目继承该类型并实现同步状态捕获、校验、恢复、输入授权和单 tick 模拟。 所有钩子必须同步完成，不应执行 await、网络发送或协调器重入。 _validate_state() 与 _validate_input() 还必须是无副作用的纯校验；项目 Adapter 属于 受信代码，协调器无法撤销校验钩子私自修改的项目状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`_capture_state`](#member-gfnetworksimulationadapter-methods-_capture_state) | `func _capture_state(_tick: int, _context: Dictionary) -> Dictionary:` |
| 方法 | [`_validate_state`](#member-gfnetworksimulationadapter-methods-_validate_state) | `func _validate_state(_state: Dictionary, _tick: int, _context: Dictionary) -> Dictionary:` |
| 方法 | [`_restore_state`](#member-gfnetworksimulationadapter-methods-_restore_state) | `func _restore_state(_state: Dictionary, _tick: int, _context: Dictionary) -> Dictionary:` |
| 方法 | [`_validate_input`](#member-gfnetworksimulationadapter-methods-_validate_input) | `func _validate_input( _frame: GFNetworkInputFrame, _actual_peer_id: int, _context: Dictionary ) -> Dictionary:` |
| 方法 | [`_simulate_tick`](#member-gfnetworksimulationadapter-methods-_simulate_tick) | `func _simulate_tick( _tick: int, _inputs: Array[GFNetworkInputFrame], _context: Dictionary ) -> Dictionary:` |
| 方法 | [`_states_equal`](#member-gfnetworksimulationadapter-methods-_states_equal) | `func _states_equal( predicted_state: Dictionary, authoritative_state: Dictionary, _tick: int, _context: Dictionary ) -> bool:` |

## 方法

<a id="member-gfnetworksimulationadapter-methods-_capture_state"></a>

### `_capture_state`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _capture_state(_tick: int, _context: Dictionary) -> Dictionary:
```

捕获指定 tick 的完整项目同步状态。

参数：

| 名称 | 说明 |
|---|---|
| `_tick` | 待捕获状态的模拟 tick。 |
| `_context` | 协调器提供的无业务载荷上下文副本。 |

返回：捕获报告。

结构：

- `_context`: Dictionary，包含 role、phase、epoch_id、local_peer_id、authority_peer_id 和 operation。
- `return`: Dictionary { ok: bool, state?: Dictionary, error?: String }.

<a id="member-gfnetworksimulationadapter-methods-_validate_state"></a>

### `_validate_state`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _validate_state(_state: Dictionary, _tick: int, _context: Dictionary) -> Dictionary:
```

校验来自权威端的完整同步状态。 项目应在此执行字段 schema、范围和不变量校验；GF 的通用结构预算不能替代项目 schema。 该钩子必须无副作用，不得修改项目模拟状态。

参数：

| 名称 | 说明 |
|---|---|
| `_state` | 待应用的完整状态副本。 |
| `_tick` | 状态所属 tick。 |
| `_context` | 协调器上下文副本。 |

返回：校验报告。

结构：

- `_state`: Dictionary，项目定义的完整同步状态。
- `_context`: Dictionary，包含 role、phase、epoch_id、local_peer_id、authority_peer_id 和 operation。
- `return`: Dictionary { ok: bool, error?: String }.

<a id="member-gfnetworksimulationadapter-methods-_restore_state"></a>

### `_restore_state`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _restore_state(_state: Dictionary, _tick: int, _context: Dictionary) -> Dictionary:
```

恢复指定 tick 的完整同步状态。

参数：

| 名称 | 说明 |
|---|---|
| `_state` | 待恢复的状态副本。 |
| `_tick` | 状态所属 tick。 |
| `_context` | 协调器上下文副本。 |

返回：恢复报告。

结构：

- `_state`: Dictionary，项目定义的完整同步状态。
- `_context`: Dictionary，包含 role、phase、epoch_id、local_peer_id、authority_peer_id 和 operation。
- `return`: Dictionary { ok: bool, error?: String }.

<a id="member-gfnetworksimulationadapter-methods-_validate_input"></a>

### `_validate_input`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _validate_input( _frame: GFNetworkInputFrame, _actual_peer_id: int, _context: Dictionary ) -> Dictionary:
```

校验并授权一帧输入。 项目必须使用 actual_peer_id 判断实体控制权；payload 中自带的 owner 字段不能作为授权。 Authority 会在收包排队时和目标 tick 模拟前各调用一次，以避免控制权变化产生 time-of-check/time-of-use 间隙；两次调用都必须只读取当前授权状态。 该钩子必须无副作用，不得修改项目模拟状态。

参数：

| 名称 | 说明 |
|---|---|
| `_frame` | 待校验输入帧副本。 |
| `_actual_peer_id` | 底层 transport 报告的实际来源 peer。 |
| `_context` | 协调器上下文副本。 |

返回：输入校验报告。

结构：

- `_context`: Dictionary，包含 role、phase、epoch_id、local_peer_id、authority_peer_id 和 operation。
- `return`: Dictionary { ok: bool, error?: String }.

<a id="member-gfnetworksimulationadapter-methods-_simulate_tick"></a>

### `_simulate_tick`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _simulate_tick( _tick: int, _inputs: Array[GFNetworkInputFrame], _context: Dictionary ) -> Dictionary:
```

执行一个完整模拟 tick。 inputs 已在当前 authority tick 重新授权，并按 peer_id、sequence 稳定排序； 无输入 tick 也会收到空数组。

参数：

| 名称 | 说明 |
|---|---|
| `_tick` | 要执行的连续模拟 tick。 |
| `_inputs` | 该 tick 的输入帧副本。 |
| `_context` | 协调器上下文副本。 |

返回：模拟报告。

结构：

- `_inputs`: Array[GFNetworkInputFrame]，按 peer_id、sequence 升序排列。
- `_context`: Dictionary，包含 role、phase、epoch_id、local_peer_id、authority_peer_id 和 operation。
- `return`: Dictionary { ok: bool, error?: String }.

<a id="member-gfnetworksimulationadapter-methods-_states_equal"></a>

### `_states_equal`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _states_equal( predicted_state: Dictionary, authoritative_state: Dictionary, _tick: int, _context: Dictionary ) -> bool:
```

比较预测状态与权威状态是否等价。 默认使用 Godot Variant 相等比较；项目可重写以加入量化容差。 该钩子必须无副作用，不得修改项目模拟状态。

参数：

| 名称 | 说明 |
|---|---|
| `predicted_state` | 本地预测状态副本。 |
| `authoritative_state` | 权威状态副本。 |
| `_tick` | 两份状态所属 tick。 |
| `_context` | 协调器上下文副本。 |

返回：项目认为两份状态等价时返回 true。

结构：

- `predicted_state`: Dictionary，项目定义的预测状态。
- `authoritative_state`: Dictionary，项目定义的权威状态。
- `_context`: Dictionary，包含 role、phase、epoch_id、local_peer_id、authority_peer_id 和 operation。
