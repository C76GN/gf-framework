# Network 同步协调器

`GFNetworkSyncCoordinator` 在项目模拟与 `GFNetworkMessage` 之间提供一个有界、显式的同步状态机。首版协议只处理全量权威快照、严格有序输入、可选客户端预测和事务式纠偏；它不创建 transport，不扫描场景树，也不推断实体或控制权。

配套类型：

- `GFNetworkInputFrame`：保存目标 tick、实际来源 peer、严格单调 sequence 和项目输入副本。
- `GFNetworkSimulationAdapter`：项目实现的同步协议，负责状态捕获、严格 Schema 校验、恢复、输入授权和单 tick 模拟。
- `GFNetworkSyncCoordinator`：绑定 role、authority、recipient、epoch、sequence、ack、历史与资源预算。

## Transport 前置条件

协调器的公开收包入口接收已经解码的 `GFNetworkMessage`。项目必须从 `GFNetworkUtility.message_received(peer_id, message)` 原样传入底层报告的 `peer_id`，不能使用 payload 自带身份。

```gdscript
var sync_channel := GFNetworkChannel.new()
sync_channel.channel_id = GFNetworkSyncCoordinator.DEFAULT_CHANNEL_ID
sync_channel.reliable = true
sync_channel.max_packet_size = 80 * 1024
network.register_channel(sync_channel)

# validator 必须保留，并在 serializer 解码前限制 raw bytes。
network.validator.max_packet_size = 80 * 1024
network.message_received.connect(func(peer_id: int, message: GFNetworkMessage) -> void:
	var _report := coordinator.handle_message(peer_id, message)
)
```

`max_payload_bytes` 限制的是项目输入或状态的 Variant 二进制大小；raw packet 还包含固定协议 envelope 和 serializer 开销。通道与 validator 的上限必须大于实际编码后的消息，并继续保持有限。默认接近 64 KiB 业务上限时，二进制 serializer 可采用上例的 80 KiB raw 上限；自定义上限或 JSON 编码必须按真实编码结果测量。

协调器的深度、节点和字节预算发生在解码后，不能阻止 decoder 自身处理恶意结构。面向非可信公网时应使用经过认证、加密且具有解码前包体限制的 transport/session；`JSON + typed codec` 当前不提供解码期递归预算，不应被当作敌对输入的独立安全边界。

## 项目 Adapter

Adapter 是受信项目代码。所有钩子必须同步完成，不能 `await`、发送网络消息或重入协调器。`_validate_state()`、`_validate_input()` 与 `_states_equal()` 必须是无副作用纯校验。Authority 会在输入收包排队时和目标 tick 模拟前分别调用 `_validate_input()`；因此控制权在排队后被撤销时，该输入会在最终模拟前裁决为拒绝。

```gdscript
class_name ProjectSimulationAdapter
extends GFNetworkSimulationAdapter

var state: Dictionary = {"position": Vector2.ZERO}

func _capture_state(_tick: int, _context: Dictionary) -> Dictionary:
	return {"ok": true, "state": state.duplicate(true)}

func _validate_state(candidate: Dictionary, _tick: int, _context: Dictionary) -> Dictionary:
	var position: Variant = candidate.get("position")
	return {"ok": position is Vector2}

func _restore_state(next_state: Dictionary, _tick: int, _context: Dictionary) -> Dictionary:
	state = next_state.duplicate(true)
	return {"ok": true}

func _validate_input(
	frame: GFNetworkInputFrame,
	actual_peer_id: int,
	_context: Dictionary
) -> Dictionary:
	# 必须按 actual_peer_id 查询项目控制权；payload.owner_id 不是授权。
	return {
		"ok": project_session_can_control(actual_peer_id, frame.payload.get("entity_id"))
	}

func _simulate_tick(
	_tick: int,
	inputs: Array[GFNetworkInputFrame],
	_context: Dictionary
) -> Dictionary:
	for frame: GFNetworkInputFrame in inputs:
		apply_project_input(frame.payload)
	simulate_project_tick()
	return {"ok": true}
```

GF 的通用 Variant 校验只拒绝不安全类型、循环引用、非有限数和超预算结构，不能替代项目字段 Schema、数值范围、实体存在性与控制权校验。

## 配置 Authority

```gdscript
var coordinator := GFNetworkSyncCoordinator.new()
var report := coordinator.configure(
	GFNetworkSyncCoordinator.Role.AUTHORITY,
	local_peer_id,
	local_peer_id,
	ProjectSimulationAdapter.new(),
	{
		"epoch_id": trusted_session_epoch,
		"history_capacity": 120,
		"max_replica_peers": 16,
		"max_pending_inputs": 256,
		"max_pending_input_bytes": 1024 * 1024,
		"max_inputs_per_tick": 64,
		"max_future_ticks": 8,
		"max_replay_ticks": 32,
		"max_payload_bytes": 64 * 1024,
	}
)

if report.ok and project_session_has_authorized(replica_peer_id):
	coordinator.register_replica_peer(replica_peer_id)
```

每个 replica 必须由受信 session 显式注册。transport 连接、lobby metadata、capability 或 payload 字段都不会自动授予输入权限。同一 epoch 内注销的 peer 会保留有界 tombstone，不能重新注册；重连必须使用从未在该 coordinator 实例中使用过的新 epoch。

Authority 每次只推进一个连续 tick：

```gdscript
var advance := coordinator.advance_authority_tick()
if advance.ok:
	var message := coordinator.make_snapshot_message(advance.snapshot, replica_peer_id)
	if message != null:
		var _send_error := network.send_message_on_channel(
			replica_peer_id,
			message,
			GFNetworkSyncCoordinator.DEFAULT_CHANNEL_ID
		)
```

`make_snapshot_message()` 只接受最近一次推进生成、内容未被调用方修改的内部快照，并把目标 `recipient_peer_id` 和该 peer 的连续最终裁决 ack 写入消息。旧快照不能携带更新后的 ack 再次签发。状态与 ack 在 `authority_snapshot_created` 发出前已提交，因此也可在该同步信号回调内为各 peer 构建只读消息；改变协调器状态的重入仍会被拒绝。

## 配置 Replica 与预测

```gdscript
var coordinator := GFNetworkSyncCoordinator.new()
var report := coordinator.configure(
	GFNetworkSyncCoordinator.Role.REPLICA,
	local_peer_id,
	authority_peer_id,
	ProjectSimulationAdapter.new(),
	{
		"epoch_id": trusted_session_epoch,
		"prediction_enabled": true,
	}
)
```

Replica 从 `AWAITING_BASELINE` 开始，只接受配置 authority 发给本地 recipient 的首个快照。基线成功应用后才能提交输入：

```gdscript
var submitted := coordinator.submit_local_input({
	"entity_id": selected_entity_id,
	"move": Vector2i(1, 0),
})
if submitted.ok:
	var _send_error := network.send_message_on_channel(
		authority_peer_id,
		submitted.message,
		GFNetworkSyncCoordinator.DEFAULT_CHANNEL_ID
	)

var _prediction := coordinator.advance_prediction_tick()
```

启用预测时，Replica 收到权威快照后会：

1. 校验 actual sender、authority、recipient、协议版本与 epoch。
2. 先处理 duplicate、stale、sequence conflict 和 tick 顺序，再校验 ack。
3. 捕获当前状态作为临时 rollback 点。
4. 恢复全量权威状态。
5. 删除已经最终裁决的本地输入，并按 tick、sequence 重放剩余输入。
6. 全部成功后才提交游标、历史和公开信号。

恢复、模拟或重放失败会尝试恢复事务前状态；rollback 自身失败时进入永久 `FAULTED`，当前 coordinator 与 Adapter 都必须重建。

## 状态与重同步

```text
IDLE
  ├─ configure(AUTHORITY) ─> ACTIVE
  └─ configure(REPLICA) ───> AWAITING_BASELINE

AWAITING_BASELINE ──成功应用首个快照──> ACTIVE
ACTIVE ──协议/ack/历史冲突──> RESYNC_REQUIRED
ACTIVE ──rollback 失败──────> FAULTED
RESYNC_REQUIRED ──reset_stream(全新 epoch)──> AWAITING_BASELINE / ACTIVE
FAULTED ──> 只能重建 coordinator 与 Adapter
```

`reset_stream()` 要求从未使用过的新 epoch。项目必须先把 Adapter 状态重建并对齐到 `start_tick`；Authority 的 peer 注册会被清空，必须重新授权。`epoch_id` 只隔离重连、旧包和 peer ID 复用，不是密钥。

## 资源与公平性

协调器拒绝零值、负值和超过框架硬上限的容量。以下结构始终有界：

- 权威与预测快照历史；
- 待模拟输入的数量与总字节；
- 已接收但尚未形成连续 ack 的裁决缺口；
- 每 tick 输入数、未来 tick 窗口与单次重放 tick；
- peer 数、同 epoch 退网 tombstone、已使用 epoch 数；
- Variant 深度、节点、业务字节、envelope 字节和指纹规范编码。

这些上限保证资源不会无界增长，但不提供多 peer 公平调度或每 peer 速率政策。项目 session 应在协调器外增加连接级限流、滥用处置和服务质量策略。

若项目把模拟交给第三方原生物理后端，后端仍应由项目 Adapter 独立验证身份、能力和每个目标组合的重放证据；协调器只调用 `GFNetworkSimulationAdapter`，不会从后端名称、构建风味或状态哈希能力推断跨平台确定性。完整组合边界见 [Physics 的第三方原生物理后端 Adapter 配方](../physics/index.md)。

## 明确不负责

首版协调器只使用全量快照，不接收入站 delta/patch。以下内容仍由项目负责：

- matchmaking、lobby、账号、加密、认证与 host migration；
- authority 选择、实体身份、控制权、interest management 与业务冲突政策；
- 场景树复制、节点生成销毁、RPC facade 与视觉插值；
- 物理跨平台确定性、输入采样语义和游戏规则；
- lockstep、peer-to-peer 共识、断线续传和增量 baseline 协议。

`GFFixedTickClock`、`GFNetworkSnapshot`、`GFNetworkHistoryBuffer` 与 Schema 仍可独立使用；协调器只是基于这些原语提供一个严格限定的权威快照流程。
