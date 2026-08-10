# GFNetworkSyncCoordinator

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/simulation/gf_network_sync_coordinator.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`10.0.0`

有界的权威快照与预测纠偏协调器。 协调器在项目模拟 Adapter 与 GFNetworkMessage 之间编排固定 tick、输入顺序、 全量权威快照、有限历史和事务式预测重放。它不创建 transport、不扫描节点树、 不推断实体所有权，也不提供密码学认证或加密。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`phase_changed`](#member-gfnetworksynccoordinator-signals-phase_changed) | `signal phase_changed(previous_phase: Phase, current_phase: Phase)` |
| 信号 | [`input_finalized`](#member-gfnetworksynccoordinator-signals-input_finalized) | `signal input_finalized(peer_id: int, sequence: int, accepted: bool, reason: StringName)` |
| 信号 | [`authority_snapshot_created`](#member-gfnetworksynccoordinator-signals-authority_snapshot_created) | `signal authority_snapshot_created(snapshot: GFNetworkSnapshot)` |
| 信号 | [`authoritative_snapshot_applied`](#member-gfnetworksynccoordinator-signals-authoritative_snapshot_applied) | `signal authoritative_snapshot_applied( snapshot: GFNetworkSnapshot, corrected: bool, replayed_tick_count: int )` |
| 信号 | [`synchronization_rejected`](#member-gfnetworksynccoordinator-signals-synchronization_rejected) | `signal synchronization_rejected(peer_id: int, reason: StringName, details: Dictionary)` |
| 信号 | [`resync_required`](#member-gfnetworksynccoordinator-signals-resync_required) | `signal resync_required(reason: StringName, details: Dictionary)` |
| 枚举 | [`Role`](#member-gfnetworksynccoordinator-enums-role) | `enum Role` |
| 枚举 | [`Phase`](#member-gfnetworksynccoordinator-enums-phase) | `enum Phase` |
| 常量 | [`PROTOCOL_VERSION`](#member-gfnetworksynccoordinator-constants-protocol_version) | `const PROTOCOL_VERSION: int = 1` |
| 常量 | [`INPUT_MESSAGE_TYPE`](#member-gfnetworksynccoordinator-constants-input_message_type) | `const INPUT_MESSAGE_TYPE: StringName = &"gf.sync.input.v1"` |
| 常量 | [`SNAPSHOT_MESSAGE_TYPE`](#member-gfnetworksynccoordinator-constants-snapshot_message_type) | `const SNAPSHOT_MESSAGE_TYPE: StringName = &"gf.sync.snapshot.v1"` |
| 常量 | [`DEFAULT_CHANNEL_ID`](#member-gfnetworksynccoordinator-constants-default_channel_id) | `const DEFAULT_CHANNEL_ID: StringName = &"gf.sync"` |
| 方法 | [`configure`](#member-gfnetworksynccoordinator-methods-configure) | `func configure( role: Role, local_peer_id: int, authority_peer_id: int, adapter: GFNetworkSimulationAdapter, options: Dictionary ) -> Dictionary:` |
| 方法 | [`reset_stream`](#member-gfnetworksynccoordinator-methods-reset_stream) | `func reset_stream(new_epoch_id: String, start_tick: int = 0) -> Dictionary:` |
| 方法 | [`register_replica_peer`](#member-gfnetworksynccoordinator-methods-register_replica_peer) | `func register_replica_peer(peer_id: int) -> bool:` |
| 方法 | [`unregister_replica_peer`](#member-gfnetworksynccoordinator-methods-unregister_replica_peer) | `func unregister_replica_peer(peer_id: int) -> bool:` |
| 方法 | [`submit_local_input`](#member-gfnetworksynccoordinator-methods-submit_local_input) | `func submit_local_input(payload: Dictionary, target_tick: int = -1) -> Dictionary:` |
| 方法 | [`make_input_message`](#member-gfnetworksynccoordinator-methods-make_input_message) | `func make_input_message(frame: GFNetworkInputFrame) -> GFNetworkMessage:` |
| 方法 | [`advance_authority_tick`](#member-gfnetworksynccoordinator-methods-advance_authority_tick) | `func advance_authority_tick() -> Dictionary:` |
| 方法 | [`advance_prediction_tick`](#member-gfnetworksynccoordinator-methods-advance_prediction_tick) | `func advance_prediction_tick() -> Dictionary:` |
| 方法 | [`make_snapshot_message`](#member-gfnetworksynccoordinator-methods-make_snapshot_message) | `func make_snapshot_message( snapshot: GFNetworkSnapshot, replica_peer_id: int ) -> GFNetworkMessage:` |
| 方法 | [`handle_message`](#member-gfnetworksynccoordinator-methods-handle_message) | `func handle_message(actual_peer_id: int, message: GFNetworkMessage) -> Dictionary:` |
| 方法 | [`get_role`](#member-gfnetworksynccoordinator-methods-get_role) | `func get_role() -> Role:` |
| 方法 | [`get_phase`](#member-gfnetworksynccoordinator-methods-get_phase) | `func get_phase() -> Phase:` |
| 方法 | [`get_epoch_id`](#member-gfnetworksynccoordinator-methods-get_epoch_id) | `func get_epoch_id() -> String:` |
| 方法 | [`get_current_tick`](#member-gfnetworksynccoordinator-methods-get_current_tick) | `func get_current_tick() -> int:` |
| 方法 | [`get_authoritative_history`](#member-gfnetworksynccoordinator-methods-get_authoritative_history) | `func get_authoritative_history() -> GFNetworkHistoryBuffer:` |
| 方法 | [`get_prediction_history`](#member-gfnetworksynccoordinator-methods-get_prediction_history) | `func get_prediction_history() -> GFNetworkHistoryBuffer:` |
| 方法 | [`get_debug_snapshot`](#member-gfnetworksynccoordinator-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfnetworksynccoordinator-signals-phase_changed"></a>

### `phase_changed`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal phase_changed(previous_phase: Phase, current_phase: Phase)
```

公开状态变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `previous_phase` | 变化前状态。 |
| `current_phase` | 变化后状态。 |

<a id="member-gfnetworksynccoordinator-signals-input_finalized"></a>

### `input_finalized`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal input_finalized(peer_id: int, sequence: int, accepted: bool, reason: StringName)
```

权威端最终裁决输入后发出。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 输入来源 peer。 |
| `sequence` | 已裁决输入序号。 |
| `accepted` | 输入是否进入模拟。 |
| `reason` | 稳定裁决原因；不包含输入载荷。 |

<a id="member-gfnetworksynccoordinator-signals-authority_snapshot_created"></a>

### `authority_snapshot_created`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal authority_snapshot_created(snapshot: GFNetworkSnapshot)
```

权威端完成一个 tick 并生成全量快照后发出。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 权威快照副本。 |

<a id="member-gfnetworksynccoordinator-signals-authoritative_snapshot_applied"></a>

### `authoritative_snapshot_applied`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal authoritative_snapshot_applied( snapshot: GFNetworkSnapshot, corrected: bool, replayed_tick_count: int )
```

Replica 原子应用权威快照后发出。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 已应用权威快照副本。 |
| `corrected` | 同 tick 预测状态是否与权威状态不等价。 |
| `replayed_tick_count` | 成功重放的 tick 数。 |

<a id="member-gfnetworksynccoordinator-signals-synchronization_rejected"></a>

### `synchronization_rejected`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal synchronization_rejected(peer_id: int, reason: StringName, details: Dictionary)
```

同步消息被拒绝后发出。 details 只包含协议元数据和稳定原因，不包含 state、input 或原始消息。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 实际传输 peer。 |
| `reason` | 稳定拒绝原因。 |
| `details` | 无业务载荷的拒绝详情。 |

结构：

- `details`: Dictionary，包含 role、phase，并最多包含 tick、sequence、expected_sequence、replayed_tick_count、message_type 和 message_type_known；未知远端类型不会原样回显。

<a id="member-gfnetworksynccoordinator-signals-resync_required"></a>

### `resync_required`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal resync_required(reason: StringName, details: Dictionary)
```

Replica 需要由项目显式重建同步流时发出。 进入 RESYNC_REQUIRED 后不会继续应用消息；项目应取得新的 epoch 并调用 reset_stream()。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 稳定重同步原因。 |
| `details` | 无业务载荷的协议详情。 |

结构：

- `details`: Dictionary，包含 role、phase，并最多包含 tick、sequence、message_type、message_type_known、expected_sequence 和 replayed_tick_count；不包含业务载荷。

## 枚举

<a id="member-gfnetworksynccoordinator-enums-role"></a>

### `Role`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
enum Role {
	## 尚未配置。
	NONE,
	## 负责模拟并发布全量权威快照。
	AUTHORITY,
	## 接收权威快照，可选执行本地输入预测。
	REPLICA,
}
```

协调器角色。

<a id="member-gfnetworksynccoordinator-enums-phase"></a>

### `Phase`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
enum Phase {
	## 尚未配置。
	IDLE,
	## Replica 等待首个权威基线。
	AWAITING_BASELINE,
	## 可推进 tick 或处理同步消息。
	ACTIVE,
	## 协议历史无法安全续接，需要显式新 epoch。
	RESYNC_REQUIRED,
	## Adapter 回滚失败，当前实例不可继续使用。
	FAULTED,
}
```

同步流状态。

## 常量

<a id="member-gfnetworksynccoordinator-constants-protocol_version"></a>

### `PROTOCOL_VERSION`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const PROTOCOL_VERSION: int = 1
```

同步消息协议版本。

<a id="member-gfnetworksynccoordinator-constants-input_message_type"></a>

### `INPUT_MESSAGE_TYPE`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const INPUT_MESSAGE_TYPE: StringName = &"gf.sync.input.v1"
```

Replica 输入消息类型。

<a id="member-gfnetworksynccoordinator-constants-snapshot_message_type"></a>

### `SNAPSHOT_MESSAGE_TYPE`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const SNAPSHOT_MESSAGE_TYPE: StringName = &"gf.sync.snapshot.v1"
```

权威全量快照消息类型。

<a id="member-gfnetworksynccoordinator-constants-default_channel_id"></a>

### `DEFAULT_CHANNEL_ID`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const DEFAULT_CHANNEL_ID: StringName = &"gf.sync"
```

默认同步通道。

## 方法

<a id="member-gfnetworksynccoordinator-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func configure( role: Role, local_peer_id: int, authority_peer_id: int, adapter: GFNetworkSimulationAdapter, options: Dictionary ) -> Dictionary:
```

配置一个显式同步流。 epoch_id 必须由受信 session/authority 提供。它只隔离重连与 peer ID 复用，不是密钥。

参数：

| 名称 | 说明 |
|---|---|
| `role` | 本地角色。 |
| `local_peer_id` | 本地 transport peer。 |
| `authority_peer_id` | 显式权威 peer；authority 角色必须与 local_peer_id 相同。 |
| `adapter` | 项目同步模拟 Adapter。 |
| `options` | 同步流与资源预算。 |

返回：配置报告。

结构：

- `options`: Dictionary { epoch_id: String, channel_id?: StringName, prediction_enabled?: bool, history_capacity?: int, max_replica_peers?: int, max_pending_inputs?: int, max_pending_input_bytes?: int, max_inputs_per_tick?: int, max_future_ticks?: int, max_replay_ticks?: int, max_sequence_jump?: int, max_value_depth?: int, max_value_nodes?: int, max_payload_bytes?: int }.
- `return`: Dictionary { ok: bool, status: StringName, reason: StringName, role?: int, phase?: int }.

<a id="member-gfnetworksynccoordinator-methods-reset_stream"></a>

### `reset_stream`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func reset_stream(new_epoch_id: String, start_tick: int = 0) -> Dictionary:
```

使用新 epoch 重置所有序号、历史和待处理输入。 Replica 重置后回到 AWAITING_BASELINE；authority 可从 start_tick 继续一个全新同步流。 new_epoch_id 在当前实例生命周期内不得复用；Authority 重置还会清空 peer 授权，项目必须 重新调用 register_replica_peer()。调用前项目必须已将 Adapter 状态重建并对齐到 start_tick。 FAULTED 实例的 Adapter 状态未知，不能重置，必须连同 Adapter 一起重建。

参数：

| 名称 | 说明 |
|---|---|
| `new_epoch_id` | 新同步 epoch。 |
| `start_tick` | 新流起始 tick。 |

返回：重置报告。

结构：

- `return`: Dictionary { ok: bool, status: StringName, reason: StringName, phase?: int }.

<a id="member-gfnetworksynccoordinator-methods-register_replica_peer"></a>

### `register_replica_peer`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func register_replica_peer(peer_id: int) -> bool:
```

Authority 显式注册可提交输入的 replica peer。 transport 连接、capability 或 payload 不会自动授予输入权限。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 已由项目 session 验证的 replica peer。 |

返回：注册成功或已存在时返回 true。

<a id="member-gfnetworksynccoordinator-methods-unregister_replica_peer"></a>

### `unregister_replica_peer`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func unregister_replica_peer(peer_id: int) -> bool:
```

Authority 注销 replica peer 并清除其尚未模拟的输入。 为阻止旧包重放，该 peer 在当前 epoch 内会保留有界 tombstone，不能重新注册； 需要重新加入时必须建立新 epoch。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | Replica peer。 |

返回：peer 曾存在时返回 true。

<a id="member-gfnetworksynccoordinator-methods-submit_local_input"></a>

### `submit_local_input`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func submit_local_input(payload: Dictionary, target_tick: int = -1) -> Dictionary:
```

Replica 创建、校验并保存一帧本地输入，同时返回待发送消息。 该方法不发送消息；项目应通过 GFNetworkUtility.send_message_on_channel() 发送返回的 message。

参数：

| 名称 | 说明 |
|---|---|
| `payload` | 项目输入载荷。 |
| `target_tick` | 目标 tick；小于 0 时使用 current_tick + 1。 |

返回：提交报告；成功时包含独立 frame 和 message。

结构：

- `payload`: Dictionary[StringName|String, Variant]，只允许网络传输安全值。
- `return`: Dictionary { ok: bool, status: StringName, reason: StringName, frame?: GFNetworkInputFrame, message?: GFNetworkMessage }.

<a id="member-gfnetworksynccoordinator-methods-make_input_message"></a>

### `make_input_message`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func make_input_message(frame: GFNetworkInputFrame) -> GFNetworkMessage:
```

将本地输入帧打包为专用同步消息。 只接受当前 replica 流签发且尚在本地序号范围内的输入帧。

参数：

| 名称 | 说明 |
|---|---|
| `frame` | 本地输入帧。 |

返回：可交给 GFNetworkUtility 的消息；无效时返回 null。

<a id="member-gfnetworksynccoordinator-methods-advance_authority_tick"></a>

### `advance_authority_tick`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func advance_authority_tick() -> Dictionary:
```

Authority 推进一个连续 tick，原子捕获并提交全量快照。 模拟或捕获失败会尝试恢复推进前状态；回滚失败时进入 FAULTED。

返回：推进报告；成功时包含权威快照副本。

结构：

- `return`: Dictionary { ok: bool, status: StringName, reason: StringName, tick?: int, input_count?: int, rejected_input_count?: int, snapshot?: GFNetworkSnapshot }.

<a id="member-gfnetworksynccoordinator-methods-advance_prediction_tick"></a>

### `advance_prediction_tick`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func advance_prediction_tick() -> Dictionary:
```

Replica 在当前权威基线上推进一个本地预测 tick。 prediction_enabled=false 时该入口保持关闭；项目仍可提交输入并等待权威快照。

返回：预测推进报告。

结构：

- `return`: Dictionary { ok: bool, status: StringName, reason: StringName, tick?: int, input_count?: int }.

<a id="member-gfnetworksynccoordinator-methods-make_snapshot_message"></a>

### `make_snapshot_message`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func make_snapshot_message( snapshot: GFNetworkSnapshot, replica_peer_id: int ) -> GFNetworkMessage:
```

Authority 为指定 replica 构建最新的全量快照消息。 只接受最近一次 advance_authority_tick() 签发且内容未被调用方修改的快照。 ack_input_sequence 是该 replica 在该最新 tick 已连续最终裁决的输入序号；消息构建不执行发送。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | advance_authority_tick() 生成的快照。 |
| `replica_peer_id` | 已注册 replica peer。 |

返回：可交给 GFNetworkUtility 的消息；无效时返回 null。

<a id="member-gfnetworksynccoordinator-methods-handle_message"></a>

### `handle_message`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func handle_message(actual_peer_id: int, message: GFNetworkMessage) -> Dictionary:
```

处理 GFNetworkUtility 已解码并绑定实际来源 peer 的同步消息。 调用方必须把 GFNetworkUtility.message_received 的 peer_id 原样传入；payload 中的身份 永远不会覆盖该参数。GFNetworkUtility 必须保留非空 validator，并在反序列化前配置 有限 raw packet 上限；本方法的 Variant 预算发生在解码后，不能替代该前置边界。 未知消息类型会被拒绝。

参数：

| 名称 | 说明 |
|---|---|
| `actual_peer_id` | 底层 transport 报告的实际来源 peer。 |
| `message` | 已解码消息。 |

返回：处理报告。

结构：

- `return`: Dictionary { ok: bool, status: StringName, reason: StringName, role?: int, phase?: int, tick?: int, sequence?: int, expected_sequence?: int, message_type?: StringName, message_type_known?: bool, duplicate?: bool, corrected?: bool, replayed_tick_count?: int }.

<a id="member-gfnetworksynccoordinator-methods-get_role"></a>

### `get_role`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_role() -> Role:
```

获取当前角色。

返回：当前角色。

<a id="member-gfnetworksynccoordinator-methods-get_phase"></a>

### `get_phase`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_phase() -> Phase:
```

获取当前同步流状态。

返回：当前状态。

<a id="member-gfnetworksynccoordinator-methods-get_epoch_id"></a>

### `get_epoch_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_epoch_id() -> String:
```

获取当前同步 epoch。

返回：Epoch ID。

<a id="member-gfnetworksynccoordinator-methods-get_current_tick"></a>

### `get_current_tick`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_current_tick() -> int:
```

获取当前本地模拟 tick。

返回：当前 tick。

<a id="member-gfnetworksynccoordinator-methods-get_authoritative_history"></a>

### `get_authoritative_history`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_authoritative_history() -> GFNetworkHistoryBuffer:
```

获取权威历史的独立副本。

返回：有界权威快照历史副本。

<a id="member-gfnetworksynccoordinator-methods-get_prediction_history"></a>

### `get_prediction_history`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_prediction_history() -> GFNetworkHistoryBuffer:
```

获取预测历史的独立副本。

返回：有界预测快照历史副本。

<a id="member-gfnetworksynccoordinator-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取无业务载荷的调试快照。

返回：同步状态、游标和资源计数字典。

结构：

- `return`: Dictionary，包含 role、phase、epoch_id、peer IDs、tick、序号、历史大小、输入计数和预算；不包含 state 或 input payload。
