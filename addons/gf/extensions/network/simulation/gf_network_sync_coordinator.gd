## GFNetworkSyncCoordinator: 有界的权威快照与预测纠偏协调器。
##
## 协调器在项目模拟 Adapter 与 GFNetworkMessage 之间编排固定 tick、输入顺序、
## 全量权威快照、有限历史和事务式预测重放。它不创建 transport、不扫描节点树、
## 不推断实体所有权，也不提供密码学认证或加密。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 10.0.0
class_name GFNetworkSyncCoordinator
extends RefCounted


# --- 信号 ---

## 公开状态变化后发出。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param previous_phase: 变化前状态。
## [br]
## @param current_phase: 变化后状态。
signal phase_changed(previous_phase: Phase, current_phase: Phase)

## 权威端最终裁决输入后发出。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param peer_id: 输入来源 peer。
## [br]
## @param sequence: 已裁决输入序号。
## [br]
## @param accepted: 输入是否进入模拟。
## [br]
## @param reason: 稳定裁决原因；不包含输入载荷。
signal input_finalized(peer_id: int, sequence: int, accepted: bool, reason: StringName)

## 权威端完成一个 tick 并生成全量快照后发出。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param snapshot: 权威快照副本。
signal authority_snapshot_created(snapshot: GFNetworkSnapshot)

## Replica 原子应用权威快照后发出。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param snapshot: 已应用权威快照副本。
## [br]
## @param corrected: 同 tick 预测状态是否与权威状态不等价。
## [br]
## @param replayed_tick_count: 成功重放的 tick 数。
signal authoritative_snapshot_applied(
	snapshot: GFNetworkSnapshot,
	corrected: bool,
	replayed_tick_count: int
)

## 同步消息被拒绝后发出。
##
## details 只包含协议元数据和稳定原因，不包含 state、input 或原始消息。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param peer_id: 实际传输 peer。
## [br]
## @param reason: 稳定拒绝原因。
## [br]
## @param details: 无业务载荷的拒绝详情。
## [br]
## @schema details: Dictionary，包含 role、phase，并最多包含 tick、sequence、expected_sequence、replayed_tick_count、message_type 和 message_type_known；未知远端类型不会原样回显。
signal synchronization_rejected(peer_id: int, reason: StringName, details: Dictionary)

## Replica 需要由项目显式重建同步流时发出。
##
## 进入 RESYNC_REQUIRED 后不会继续应用消息；项目应取得新的 epoch 并调用 reset_stream()。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param reason: 稳定重同步原因。
## [br]
## @param details: 无业务载荷的协议详情。
## [br]
## @schema details: Dictionary，包含 role、phase，并最多包含 tick、sequence、message_type、message_type_known、expected_sequence 和 replayed_tick_count；不包含业务载荷。
signal resync_required(reason: StringName, details: Dictionary)


# --- 枚举 ---

## 协调器角色。
## [br]
## @api public
## [br]
## @since 10.0.0
enum Role {
	## 尚未配置。
	NONE,
	## 负责模拟并发布全量权威快照。
	AUTHORITY,
	## 接收权威快照，可选执行本地输入预测。
	REPLICA,
}

## 同步流状态。
## [br]
## @api public
## [br]
## @since 10.0.0
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


# --- 常量 ---

## 同步消息协议版本。
## [br]
## @api public
## [br]
## @since 10.0.0
const PROTOCOL_VERSION: int = 1

## Replica 输入消息类型。
## [br]
## @api public
## [br]
## @since 10.0.0
const INPUT_MESSAGE_TYPE: StringName = &"gf.sync.input.v1"

## 权威全量快照消息类型。
## [br]
## @api public
## [br]
## @since 10.0.0
const SNAPSHOT_MESSAGE_TYPE: StringName = &"gf.sync.snapshot.v1"

## 默认同步通道。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_CHANNEL_ID: StringName = &"gf.sync"

const _TRANSPORT_VALUE_VALIDATOR = preload("res://addons/gf/extensions/network/runtime/gf_network_transport_value_validator.gd")
const _DEFAULT_HISTORY_CAPACITY: int = 120
const _MAX_HISTORY_CAPACITY: int = 512
const _DEFAULT_MAX_REPLICA_PEERS: int = 16
const _MAX_REPLICA_PEERS: int = 64
const _DEFAULT_MAX_PENDING_INPUTS: int = 256
const _MAX_PENDING_INPUTS: int = 2048
const _DEFAULT_MAX_PENDING_INPUT_BYTES: int = 1024 * 1024
const _MAX_PENDING_INPUT_BYTES: int = 4 * 1024 * 1024
const _DEFAULT_MAX_INPUTS_PER_TICK: int = 64
const _MAX_INPUTS_PER_TICK: int = 256
const _DEFAULT_MAX_FUTURE_TICKS: int = 8
const _MAX_FUTURE_TICKS: int = 120
const _DEFAULT_MAX_REPLAY_TICKS: int = 32
const _MAX_REPLAY_TICKS: int = 240
const _DEFAULT_MAX_SEQUENCE_JUMP: int = 1024
const _MAX_SEQUENCE_JUMP: int = 65_536
const _DEFAULT_MAX_VALUE_DEPTH: int = 16
const _MAX_VALUE_DEPTH: int = 32
const _DEFAULT_MAX_VALUE_NODES: int = 2048
const _MAX_VALUE_NODES: int = 8192
const _DEFAULT_MAX_PAYLOAD_BYTES: int = 64 * 1024
const _MAX_PAYLOAD_BYTES: int = 1024 * 1024
const _MAX_IDENTIFIER_LENGTH: int = 128
const _MAX_EPOCH_HISTORY: int = 1024
const _MESSAGE_ENVELOPE_NODE_OVERHEAD: int = 16
const _MESSAGE_ENVELOPE_BYTE_OVERHEAD: int = 2048
const _MAX_FINGERPRINT_OUTPUT_BYTES: int = 16 * 1024 * 1024
const _MAX_SAFE_SEQUENCE: int = 9_007_199_254_740_991


# --- 私有变量 ---

var _role: Role = Role.NONE
var _phase: Phase = Phase.IDLE
var _adapter: GFNetworkSimulationAdapter = null
var _local_peer_id: int = -1
var _authority_peer_id: int = -1
var _epoch_id: String = ""
var _channel_id: StringName = DEFAULT_CHANNEL_ID
var _current_tick: int = 0
var _prediction_enabled: bool = true
var _history_capacity: int = _DEFAULT_HISTORY_CAPACITY
var _max_replica_peers: int = _DEFAULT_MAX_REPLICA_PEERS
var _max_pending_inputs: int = _DEFAULT_MAX_PENDING_INPUTS
var _max_pending_input_bytes: int = _DEFAULT_MAX_PENDING_INPUT_BYTES
var _max_inputs_per_tick: int = _DEFAULT_MAX_INPUTS_PER_TICK
var _max_future_ticks: int = _DEFAULT_MAX_FUTURE_TICKS
var _max_replay_ticks: int = _DEFAULT_MAX_REPLAY_TICKS
var _max_sequence_jump: int = _DEFAULT_MAX_SEQUENCE_JUMP
var _max_value_depth: int = _DEFAULT_MAX_VALUE_DEPTH
var _max_value_nodes: int = _DEFAULT_MAX_VALUE_NODES
var _max_payload_bytes: int = _DEFAULT_MAX_PAYLOAD_BYTES
var _operation_active: bool = false
var _notification_active: bool = false
var _used_epoch_ids: Dictionary = {}
var _allowed_replica_peers: Dictionary = {}
var _retired_replica_peers: Dictionary = {}
var _pending_inputs_by_tick: Dictionary = {}
var _pending_input_count: int = 0
var _pending_input_bytes: int = 0
var _pending_finalization_count: int = 0
var _last_received_input_sequence: Dictionary = {}
var _last_received_input_tick: Dictionary = {}
var _last_received_input_fingerprint: Dictionary = {}
var _last_finalized_input_sequence: Dictionary = {}
var _finalized_input_sequences: Dictionary = {}
var _next_snapshot_sequence: int = 1
var _latest_snapshot_ack_by_peer: Dictionary = {}
var _last_snapshot_sequence: int = 0
var _last_snapshot_tick: int = -1
var _last_snapshot_fingerprint: String = ""
var _last_ack_input_sequence: int = 0
var _next_local_input_sequence: int = 1
var _local_input_bytes: int = 0
var _local_inputs: Array[GFNetworkInputFrame] = []
var _authoritative_history: GFNetworkHistoryBuffer = GFNetworkHistoryBuffer.new(_DEFAULT_HISTORY_CAPACITY)
var _prediction_history: GFNetworkHistoryBuffer = GFNetworkHistoryBuffer.new(_DEFAULT_HISTORY_CAPACITY)


# --- 公共方法 ---

## 配置一个显式同步流。
##
## epoch_id 必须由受信 session/authority 提供。它只隔离重连与 peer ID 复用，不是密钥。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param role: 本地角色。
## [br]
## @param local_peer_id: 本地 transport peer。
## [br]
## @param authority_peer_id: 显式权威 peer；authority 角色必须与 local_peer_id 相同。
## [br]
## @param adapter: 项目同步模拟 Adapter。
## [br]
## @param options: 同步流与资源预算。
## [br]
## @schema options: Dictionary { epoch_id: String, channel_id?: StringName, prediction_enabled?: bool, history_capacity?: int, max_replica_peers?: int, max_pending_inputs?: int, max_pending_input_bytes?: int, max_inputs_per_tick?: int, max_future_ticks?: int, max_replay_ticks?: int, max_sequence_jump?: int, max_value_depth?: int, max_value_nodes?: int, max_payload_bytes?: int }.
## [br]
## @return 配置报告。
## [br]
## @schema return: Dictionary { ok: bool, status: StringName, reason: StringName, role?: int, phase?: int }.
func configure(
	role: Role,
	local_peer_id: int,
	authority_peer_id: int,
	adapter: GFNetworkSimulationAdapter,
	options: Dictionary
) -> Dictionary:
	if _is_busy():
		return _make_report(false, &"rejected", &"operation_in_progress")
	if _phase != Phase.IDLE or _role != Role.NONE:
		return _make_report(false, &"rejected", &"already_configured")
	if role not in [Role.AUTHORITY, Role.REPLICA]:
		return _make_report(false, &"rejected", &"invalid_role")
	if local_peer_id < 0 or authority_peer_id < 0 or adapter == null:
		return _make_report(false, &"rejected", &"invalid_configuration")
	if role == Role.AUTHORITY and local_peer_id != authority_peer_id:
		return _make_report(false, &"rejected", &"authority_identity_mismatch")
	var epoch_id: String = GFVariantData.get_option_string(options, "epoch_id").strip_edges()
	var channel_id: StringName = GFVariantData.get_option_string_name(
		options,
		"channel_id",
		DEFAULT_CHANNEL_ID
	)
	if not _is_valid_identifier(epoch_id) or not _is_valid_identifier(String(channel_id)):
		return _make_report(false, &"rejected", &"invalid_stream_identity")

	var limits: Dictionary = _read_limits(options)
	if not GFVariantData.get_option_bool(limits, "ok"):
		return _make_report(false, &"rejected", &"invalid_resource_budget")

	_role = role
	_adapter = adapter
	_local_peer_id = local_peer_id
	_authority_peer_id = authority_peer_id
	_epoch_id = epoch_id
	_used_epoch_ids[_epoch_id] = true
	_channel_id = channel_id
	_prediction_enabled = GFVariantData.get_option_bool(options, "prediction_enabled", true)
	_apply_limits(limits)
	_authoritative_history = GFNetworkHistoryBuffer.new(_history_capacity)
	_prediction_history = GFNetworkHistoryBuffer.new(_history_capacity)
	_set_phase(Phase.ACTIVE if _role == Role.AUTHORITY else Phase.AWAITING_BASELINE)
	return _make_report(true, &"configured", &"", {
		"role": _role,
		"phase": _phase,
	})


## 使用新 epoch 重置所有序号、历史和待处理输入。
##
## Replica 重置后回到 AWAITING_BASELINE；authority 可从 start_tick 继续一个全新同步流。
## new_epoch_id 在当前实例生命周期内不得复用；Authority 重置还会清空 peer 授权，项目必须
## 重新调用 register_replica_peer()。调用前项目必须已将 Adapter 状态重建并对齐到 start_tick。
## FAULTED 实例的 Adapter 状态未知，不能重置，必须连同 Adapter 一起重建。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param new_epoch_id: 新同步 epoch。
## [br]
## @param start_tick: 新流起始 tick。
## [br]
## @return 重置报告。
## [br]
## @schema return: Dictionary { ok: bool, status: StringName, reason: StringName, phase?: int }.
func reset_stream(new_epoch_id: String, start_tick: int = 0) -> Dictionary:
	if _is_busy():
		return _make_report(false, &"rejected", &"operation_in_progress")
	if _role == Role.NONE or _adapter == null:
		return _make_report(false, &"rejected", &"not_configured")
	if _phase == Phase.FAULTED:
		return _make_report(false, &"rejected", &"faulted_instance_terminal")
	var normalized_epoch: String = new_epoch_id.strip_edges()
	if (
		not _is_valid_identifier(normalized_epoch)
		or start_tick < 0
		or start_tick >= _MAX_SAFE_SEQUENCE
	):
		return _make_report(false, &"rejected", &"invalid_stream_identity")
	if _used_epoch_ids.has(normalized_epoch):
		return _make_report(false, &"rejected", &"epoch_reused")
	if _used_epoch_ids.size() >= _MAX_EPOCH_HISTORY:
		return _make_report(false, &"rejected", &"epoch_history_exhausted")
	_epoch_id = normalized_epoch
	_used_epoch_ids[_epoch_id] = true
	_current_tick = start_tick
	_allowed_replica_peers.clear()
	_retired_replica_peers.clear()
	_clear_stream_state()
	_set_phase(Phase.ACTIVE if _role == Role.AUTHORITY else Phase.AWAITING_BASELINE)
	return _make_report(true, &"reset", &"", {
		"phase": _phase,
	})


## Authority 显式注册可提交输入的 replica peer。
##
## transport 连接、capability 或 payload 不会自动授予输入权限。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param peer_id: 已由项目 session 验证的 replica peer。
## [br]
## @return 注册成功或已存在时返回 true。
func register_replica_peer(peer_id: int) -> bool:
	if (
		_is_busy()
		or _role != Role.AUTHORITY
		or _phase != Phase.ACTIVE
		or peer_id < 0
		or peer_id == _authority_peer_id
		or _retired_replica_peers.has(peer_id)
	):
		return false
	if _allowed_replica_peers.has(peer_id):
		return true
	if _allowed_replica_peers.size() + _retired_replica_peers.size() >= _max_replica_peers:
		return false
	_allowed_replica_peers[peer_id] = true
	_last_received_input_sequence[peer_id] = 0
	_last_received_input_tick[peer_id] = _current_tick
	_last_received_input_fingerprint[peer_id] = ""
	_last_finalized_input_sequence[peer_id] = 0
	_finalized_input_sequences[peer_id] = {}
	if _authoritative_history.get_latest_snapshot() != null:
		_latest_snapshot_ack_by_peer[peer_id] = 0
	return true


## Authority 注销 replica peer 并清除其尚未模拟的输入。
##
## 为阻止旧包重放，该 peer 在当前 epoch 内会保留有界 tombstone，不能重新注册；
## 需要重新加入时必须建立新 epoch。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param peer_id: Replica peer。
## [br]
## @return peer 曾存在时返回 true。
func unregister_replica_peer(peer_id: int) -> bool:
	if _is_busy() or _role != Role.AUTHORITY or _phase != Phase.ACTIVE:
		return false
	if not _allowed_replica_peers.erase(peer_id):
		return false
	_remove_pending_inputs_for_peer(peer_id)
	var finalized_value: Variant = GFVariantData.get_option_value(
		_finalized_input_sequences,
		peer_id,
		{}
	)
	if finalized_value is Dictionary:
		_pending_finalization_count = maxi(
			_pending_finalization_count - GFVariantData.as_dictionary(finalized_value).size(),
			0
		)
	var _received_erased: bool = _last_received_input_sequence.erase(peer_id)
	var _tick_erased: bool = _last_received_input_tick.erase(peer_id)
	var _fingerprint_erased: bool = _last_received_input_fingerprint.erase(peer_id)
	var _finalized_erased: bool = _last_finalized_input_sequence.erase(peer_id)
	var _set_erased: bool = _finalized_input_sequences.erase(peer_id)
	var _snapshot_ack_erased: bool = _latest_snapshot_ack_by_peer.erase(peer_id)
	_retired_replica_peers[peer_id] = true
	return true


## Replica 创建、校验并保存一帧本地输入，同时返回待发送消息。
##
## 该方法不发送消息；项目应通过 GFNetworkUtility.send_message_on_channel() 发送返回的 message。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param payload: 项目输入载荷。
## [br]
## @param target_tick: 目标 tick；小于 0 时使用 current_tick + 1。
## [br]
## @schema payload: Dictionary[StringName|String, Variant]，只允许网络传输安全值。
## [br]
## @return 提交报告；成功时包含独立 frame 和 message。
## [br]
## @schema return: Dictionary { ok: bool, status: StringName, reason: StringName, frame?: GFNetworkInputFrame, message?: GFNetworkMessage }.
func submit_local_input(payload: Dictionary, target_tick: int = -1) -> Dictionary:
	if _is_busy():
		return _make_report(false, &"rejected", &"operation_in_progress")
	if _role != Role.REPLICA or _phase != Phase.ACTIVE:
		return _make_report(false, &"rejected", &"replica_not_active")
	if _next_local_input_sequence > _MAX_SAFE_SEQUENCE:
		return _make_report(false, &"rejected", &"sequence_exhausted")
	var effective_tick: int = _current_tick + 1 if target_tick < 0 else target_tick
	if (
		effective_tick <= _current_tick
		or effective_tick > _MAX_SAFE_SEQUENCE
		or effective_tick > _current_tick + _max_future_ticks
	):
		return _make_report(false, &"rejected", &"input_tick_out_of_window")
	if not _local_inputs.is_empty() and effective_tick < _local_inputs[_local_inputs.size() - 1].tick:
		return _make_report(false, &"rejected", &"input_tick_regressed")
	if _local_inputs.size() >= _max_pending_inputs:
		return _make_report(false, &"rejected", &"pending_input_budget_exceeded")
	if _get_local_inputs_for_tick(effective_tick, 0).size() >= _max_inputs_per_tick:
		return _make_report(false, &"rejected", &"tick_input_budget_exceeded")

	var frame: GFNetworkInputFrame = GFNetworkInputFrame.new(
		effective_tick,
		_local_peer_id,
		_next_local_input_sequence,
		payload
	)
	var frame_report: Dictionary = frame.validate_frame(_value_budget_options())
	if not GFVariantData.get_option_bool(frame_report, "ok"):
		return _make_report(false, &"rejected", &"invalid_input_payload")
	var frame_bytes: int = GFVariantData.get_option_int(frame_report, "payload_bytes")
	if _local_input_bytes + frame_bytes > _max_pending_input_bytes:
		return _make_report(false, &"rejected", &"pending_input_byte_budget_exceeded")

	_operation_active = true
	var adapter_report: Dictionary = _adapter._validate_input(
		frame.duplicate_frame(),
		_local_peer_id,
		_make_adapter_context(&"validate_local_input")
	)
	_operation_active = false
	if not GFVariantData.get_option_bool(adapter_report, "ok"):
		return _make_report(false, &"rejected", &"adapter_rejected_input")

	var message: GFNetworkMessage = _build_input_message(frame)
	if message == null:
		return _make_report(false, &"rejected", &"message_envelope_budget_exceeded")
	_local_inputs.append(frame.duplicate_frame())
	_local_input_bytes += frame_bytes
	_next_local_input_sequence += 1
	return _make_report(true, &"accepted", &"", {
		"frame": frame.duplicate_frame(),
		"message": message,
	})


## 将本地输入帧打包为专用同步消息。
##
## 只接受当前 replica 流签发且尚在本地序号范围内的输入帧。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param frame: 本地输入帧。
## [br]
## @return 可交给 GFNetworkUtility 的消息；无效时返回 null。
func make_input_message(frame: GFNetworkInputFrame) -> GFNetworkMessage:
	if (
		_operation_active
		or _role != Role.REPLICA
		or _phase != Phase.ACTIVE
		or frame == null
		or frame.peer_id != _local_peer_id
		or frame.sequence <= 0
		or frame.sequence >= _next_local_input_sequence
	):
		return null
	var frame_report: Dictionary = frame.validate_frame(_value_budget_options())
	if not GFVariantData.get_option_bool(frame_report, "ok"):
		return null
	var stored_frame: GFNetworkInputFrame = _get_local_input_by_sequence(frame.sequence)
	if (
		stored_frame == null
		or stored_frame.tick != frame.tick
		or stored_frame.peer_id != frame.peer_id
		or stored_frame.payload != frame.payload
	):
		return null
	return _build_input_message(stored_frame)


## Authority 推进一个连续 tick，原子捕获并提交全量快照。
##
## 模拟或捕获失败会尝试恢复推进前状态；回滚失败时进入 FAULTED。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 推进报告；成功时包含权威快照副本。
## [br]
## @schema return: Dictionary { ok: bool, status: StringName, reason: StringName, tick?: int, input_count?: int, rejected_input_count?: int, snapshot?: GFNetworkSnapshot }.
func advance_authority_tick() -> Dictionary:
	if _is_busy():
		return _make_report(false, &"rejected", &"operation_in_progress")
	if _role != Role.AUTHORITY or _phase != Phase.ACTIVE:
		return _make_report(false, &"rejected", &"authority_not_active")
	if _next_snapshot_sequence > _MAX_SAFE_SEQUENCE or _current_tick >= _MAX_SAFE_SEQUENCE:
		return _make_report(false, &"rejected", &"sequence_exhausted")

	var next_tick: int = _current_tick + 1
	var queued_frames: Array[GFNetworkInputFrame] = _get_pending_inputs_for_tick(next_tick)
	queued_frames.sort_custom(_input_frame_less_than)
	_operation_active = true
	var frames: Array[GFNetworkInputFrame] = []
	var rejected_frames: Array[GFNetworkInputFrame] = []
	for frame: GFNetworkInputFrame in queued_frames:
		var input_report: Dictionary = _adapter._validate_input(
			frame.duplicate_frame(),
			frame.peer_id,
			_make_adapter_context(&"revalidate_remote_input")
		)
		if GFVariantData.get_option_bool(input_report, "ok"):
			frames.append(frame.duplicate_frame())
		else:
			rejected_frames.append(frame.duplicate_frame())
	var before_report: Dictionary = _capture_adapter_state(_current_tick, &"capture_rollback")
	if not GFVariantData.get_option_bool(before_report, "ok"):
		_operation_active = false
		return _make_report(false, &"failed", &"rollback_capture_failed")
	var before_state: Dictionary = GFVariantData.get_option_dictionary(before_report, "state")
	var simulate_report: Dictionary = _adapter._simulate_tick(
		next_tick,
		_duplicate_frames(frames),
		_make_adapter_context(&"authority_tick")
	)
	if not GFVariantData.get_option_bool(simulate_report, "ok"):
		var rollback_ok: bool = _restore_adapter_state(before_state, _current_tick, &"authority_rollback")
		_operation_active = false
		if not rollback_ok:
			_set_phase(Phase.FAULTED)
			return _make_report(false, &"faulted", &"rollback_failed")
		return _make_report(false, &"failed", &"simulation_failed")
	var after_report: Dictionary = _capture_adapter_state(next_tick, &"capture_authority")
	if not GFVariantData.get_option_bool(after_report, "ok"):
		var rollback_ok: bool = _restore_adapter_state(before_state, _current_tick, &"authority_rollback")
		_operation_active = false
		if not rollback_ok:
			_set_phase(Phase.FAULTED)
			return _make_report(false, &"faulted", &"rollback_failed")
		return _make_report(false, &"failed", &"state_capture_failed")
	var state: Dictionary = GFVariantData.get_option_dictionary(after_report, "state")
	var state_validation: Dictionary = _adapter._validate_state(
		state.duplicate(true),
		next_tick,
		_make_adapter_context(&"validate_authority_state")
	)
	if not GFVariantData.get_option_bool(state_validation, "ok"):
		var rollback_ok: bool = _restore_adapter_state(before_state, _current_tick, &"authority_rollback")
		_operation_active = false
		if not rollback_ok:
			_set_phase(Phase.FAULTED)
			return _make_report(false, &"faulted", &"rollback_failed")
		return _make_report(false, &"failed", &"adapter_rejected_state")

	var snapshot: GFNetworkSnapshot = GFNetworkSnapshot.new(
		next_tick,
		state,
		_local_peer_id,
		{
			"protocol_version": PROTOCOL_VERSION,
			"epoch_id": _epoch_id,
			"snapshot_sequence": _next_snapshot_sequence,
		}
	)
	_current_tick = next_tick
	_next_snapshot_sequence += 1
	var _history_added: bool = _authoritative_history.add_snapshot(snapshot)
	_commit_consumed_inputs(next_tick, queued_frames)
	_latest_snapshot_ack_by_peer.clear()
	for peer_value: Variant in _allowed_replica_peers.keys():
		var replica_peer_id: int = GFVariantData.to_int(peer_value)
		_latest_snapshot_ack_by_peer[replica_peer_id] = GFVariantData.get_option_int(
			_last_finalized_input_sequence,
			replica_peer_id
		)
	_operation_active = false
	_notification_active = true
	for frame: GFNetworkInputFrame in frames:
		input_finalized.emit(frame.peer_id, frame.sequence, true, &"simulated")
	for frame: GFNetworkInputFrame in rejected_frames:
		input_finalized.emit(
			frame.peer_id,
			frame.sequence,
			false,
			&"adapter_rejected_at_tick"
		)
	authority_snapshot_created.emit(snapshot.duplicate_snapshot())
	_notification_active = false
	return _make_report(true, &"advanced", &"", {
		"tick": next_tick,
		"input_count": frames.size(),
		"rejected_input_count": rejected_frames.size(),
		"snapshot": snapshot.duplicate_snapshot(),
	})


## Replica 在当前权威基线上推进一个本地预测 tick。
##
## prediction_enabled=false 时该入口保持关闭；项目仍可提交输入并等待权威快照。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 预测推进报告。
## [br]
## @schema return: Dictionary { ok: bool, status: StringName, reason: StringName, tick?: int, input_count?: int }.
func advance_prediction_tick() -> Dictionary:
	if _is_busy():
		return _make_report(false, &"rejected", &"operation_in_progress")
	if _role != Role.REPLICA or _phase != Phase.ACTIVE or not _prediction_enabled:
		return _make_report(false, &"rejected", &"prediction_not_active")
	if _current_tick >= _MAX_SAFE_SEQUENCE:
		return _make_report(false, &"rejected", &"sequence_exhausted")
	var next_tick: int = _current_tick + 1
	var frames: Array[GFNetworkInputFrame] = _get_local_inputs_for_tick(next_tick, 0)
	frames.sort_custom(_input_frame_less_than)
	_operation_active = true
	var before_report: Dictionary = _capture_adapter_state(_current_tick, &"capture_rollback")
	if not GFVariantData.get_option_bool(before_report, "ok"):
		_operation_active = false
		return _make_report(false, &"failed", &"rollback_capture_failed")
	var before_state: Dictionary = GFVariantData.get_option_dictionary(before_report, "state")
	var simulate_report: Dictionary = _adapter._simulate_tick(
		next_tick,
		_duplicate_frames(frames),
		_make_adapter_context(&"prediction_tick")
	)
	if not GFVariantData.get_option_bool(simulate_report, "ok"):
		var rollback_ok: bool = _restore_adapter_state(before_state, _current_tick, &"prediction_rollback")
		_operation_active = false
		if not rollback_ok:
			_set_phase(Phase.FAULTED)
			return _make_report(false, &"faulted", &"rollback_failed")
		return _make_report(false, &"failed", &"simulation_failed")
	var state_report: Dictionary = _capture_adapter_state(next_tick, &"capture_prediction")
	if not GFVariantData.get_option_bool(state_report, "ok"):
		var rollback_ok: bool = _restore_adapter_state(before_state, _current_tick, &"prediction_rollback")
		_operation_active = false
		if not rollback_ok:
			_set_phase(Phase.FAULTED)
			return _make_report(false, &"faulted", &"rollback_failed")
		return _make_report(false, &"failed", &"state_capture_failed")
	var state: Dictionary = GFVariantData.get_option_dictionary(state_report, "state")
	_current_tick = next_tick
	var _history_added: bool = _prediction_history.add_state(
		next_tick,
		state,
		_local_peer_id,
		{"predicted": true}
	) != null
	_operation_active = false
	return _make_report(true, &"predicted", &"", {
		"tick": next_tick,
		"input_count": frames.size(),
	})


## Authority 为指定 replica 构建最新的全量快照消息。
##
## 只接受最近一次 advance_authority_tick() 签发且内容未被调用方修改的快照。
## ack_input_sequence 是该 replica 在该最新 tick 已连续最终裁决的输入序号；消息构建不执行发送。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param snapshot: advance_authority_tick() 生成的快照。
## [br]
## @param replica_peer_id: 已注册 replica peer。
## [br]
## @return 可交给 GFNetworkUtility 的消息；无效时返回 null。
func make_snapshot_message(
	snapshot: GFNetworkSnapshot,
	replica_peer_id: int
) -> GFNetworkMessage:
	if (
		_operation_active
		or _role != Role.AUTHORITY
		or _phase != Phase.ACTIVE
		or snapshot == null
		or not _allowed_replica_peers.has(replica_peer_id)
		or snapshot.peer_id != _authority_peer_id
	):
		return null
	var stored_snapshot: GFNetworkSnapshot = _authoritative_history.get_latest_snapshot()
	if stored_snapshot == null or snapshot.to_dict() != stored_snapshot.to_dict():
		return null
	var sequence: int = GFVariantData.get_option_int(
		stored_snapshot.metadata,
		"snapshot_sequence"
	)
	if (
		sequence <= 0
		or sequence != _next_snapshot_sequence - 1
		or sequence > _MAX_SAFE_SEQUENCE
		or stored_snapshot.tick != _current_tick
		or GFVariantData.get_option_string(stored_snapshot.metadata, "epoch_id") != _epoch_id
	):
		return null
	var state_report: Dictionary = _validate_transport_value(stored_snapshot.state)
	if not GFVariantData.get_option_bool(state_report, "ok"):
		return null
	if not _latest_snapshot_ack_by_peer.has(replica_peer_id):
		return null
	var ack_sequence: int = GFVariantData.get_option_int(
		_latest_snapshot_ack_by_peer,
		replica_peer_id
	)
	var payload: Dictionary = {
		"protocol_version": PROTOCOL_VERSION,
		"epoch_id": _epoch_id,
		"recipient_peer_id": replica_peer_id,
		"state": stored_snapshot.state.duplicate(true),
		"ack_input_sequence": ack_sequence,
	}
	if not GFVariantData.get_option_bool(_validate_message_payload(payload), "ok"):
		return null
	return GFNetworkMessage.new(
		SNAPSHOT_MESSAGE_TYPE,
		payload,
		sequence,
		stored_snapshot.tick,
		_authority_peer_id,
		_channel_id
	)


## 处理 GFNetworkUtility 已解码并绑定实际来源 peer 的同步消息。
##
## 调用方必须把 GFNetworkUtility.message_received 的 peer_id 原样传入；payload 中的身份
## 永远不会覆盖该参数。GFNetworkUtility 必须保留非空 validator，并在反序列化前配置
## 有限 raw packet 上限；本方法的 Variant 预算发生在解码后，不能替代该前置边界。
## 未知消息类型会被拒绝。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param actual_peer_id: 底层 transport 报告的实际来源 peer。
## [br]
## @param message: 已解码消息。
## [br]
## @return 处理报告。
## [br]
## @schema return: Dictionary { ok: bool, status: StringName, reason: StringName, role?: int, phase?: int, tick?: int, sequence?: int, expected_sequence?: int, message_type?: StringName, message_type_known?: bool, duplicate?: bool, corrected?: bool, replayed_tick_count?: int }.
func handle_message(actual_peer_id: int, message: GFNetworkMessage) -> Dictionary:
	if _is_busy():
		return _make_report(false, &"rejected", &"operation_in_progress")
	if _role == Role.NONE or _phase in [Phase.IDLE, Phase.RESYNC_REQUIRED, Phase.FAULTED]:
		return _reject(actual_peer_id, &"stream_not_active", message)
	if message == null:
		return _reject(actual_peer_id, &"message_is_null", null)
	if message.message_type == INPUT_MESSAGE_TYPE:
		return _handle_input_message(actual_peer_id, message)
	if message.message_type == SNAPSHOT_MESSAGE_TYPE:
		return _handle_snapshot_message(actual_peer_id, message)
	return _reject(actual_peer_id, &"unexpected_message_type", message)


## 获取当前角色。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 当前角色。
func get_role() -> Role:
	return _role


## 获取当前同步流状态。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 当前状态。
func get_phase() -> Phase:
	return _phase


## 获取当前同步 epoch。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return Epoch ID。
func get_epoch_id() -> String:
	return _epoch_id


## 获取当前本地模拟 tick。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 当前 tick。
func get_current_tick() -> int:
	return _current_tick


## 获取权威历史的独立副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 有界权威快照历史副本。
func get_authoritative_history() -> GFNetworkHistoryBuffer:
	return _duplicate_history(_authoritative_history)


## 获取预测历史的独立副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 有界预测快照历史副本。
func get_prediction_history() -> GFNetworkHistoryBuffer:
	return _duplicate_history(_prediction_history)


## 获取无业务载荷的调试快照。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 同步状态、游标和资源计数字典。
## [br]
## @schema return: Dictionary，包含 role、phase、epoch_id、peer IDs、tick、序号、历史大小、输入计数和预算；不包含 state 或 input payload。
func get_debug_snapshot() -> Dictionary:
	return {
		"role": _role,
		"role_name": Role.keys()[_role],
		"phase": _phase,
		"phase_name": Phase.keys()[_phase],
		"epoch_id": _epoch_id,
		"local_peer_id": _local_peer_id,
		"authority_peer_id": _authority_peer_id,
		"channel_id": _channel_id,
		"current_tick": _current_tick,
		"prediction_enabled": _prediction_enabled,
		"used_epoch_count": _used_epoch_ids.size(),
		"allowed_replica_peer_count": _allowed_replica_peers.size(),
		"retired_replica_peer_count": _retired_replica_peers.size(),
		"pending_input_count": _pending_input_count,
		"pending_input_bytes": _pending_input_bytes,
		"pending_finalization_count": _pending_finalization_count,
		"local_input_count": _local_inputs.size(),
		"local_input_bytes": _local_input_bytes,
		"next_snapshot_sequence": _next_snapshot_sequence,
		"last_snapshot_sequence": _last_snapshot_sequence,
		"last_snapshot_tick": _last_snapshot_tick,
		"last_ack_input_sequence": _last_ack_input_sequence,
		"next_local_input_sequence": _next_local_input_sequence,
		"authoritative_history_size": _authoritative_history.size(),
		"prediction_history_size": _prediction_history.size(),
		"history_capacity": _history_capacity,
		"max_replica_peers": _max_replica_peers,
		"max_pending_inputs": _max_pending_inputs,
		"max_pending_input_bytes": _max_pending_input_bytes,
		"max_inputs_per_tick": _max_inputs_per_tick,
		"max_future_ticks": _max_future_ticks,
		"max_replay_ticks": _max_replay_ticks,
		"max_sequence_jump": _max_sequence_jump,
		"max_value_depth": _max_value_depth,
		"max_value_nodes": _max_value_nodes,
		"max_payload_bytes": _max_payload_bytes,
		"operation_active": _operation_active,
		"notification_active": _notification_active,
	}


# --- 私有/辅助方法 ---

func _handle_input_message(actual_peer_id: int, message: GFNetworkMessage) -> Dictionary:
	if _role != Role.AUTHORITY or _phase != Phase.ACTIVE:
		return _reject(actual_peer_id, &"authority_not_active", message)
	if not _allowed_replica_peers.has(actual_peer_id):
		return _reject(actual_peer_id, &"replica_peer_not_registered", message)
	var envelope_reason: StringName = _validate_envelope(actual_peer_id, message, INPUT_MESSAGE_TYPE)
	if envelope_reason != &"":
		return _reject(actual_peer_id, envelope_reason, message)
	if not _has_exact_keys(
		message.payload,
		["protocol_version", "epoch_id", "recipient_peer_id", "input"]
	):
		return _reject(actual_peer_id, &"invalid_input_envelope", message)
	if not _protocol_matches(message.payload):
		return _reject(actual_peer_id, &"protocol_version_mismatch", message)
	if GFVariantData.get_option_string(message.payload, "epoch_id") != _epoch_id:
		return _reject(actual_peer_id, &"epoch_mismatch", message)
	var recipient_value: Variant = GFVariantData.get_option_value(
		message.payload,
		"recipient_peer_id"
	)
	if not _is_integer_value(recipient_value):
		return _reject(actual_peer_id, &"invalid_input_recipient", message)
	if GFVariantData.to_int(recipient_value) != _local_peer_id:
		return _reject(actual_peer_id, &"unexpected_input_recipient", message)
	var input_value: Variant = GFVariantData.get_option_value(message.payload, "input")
	if not (input_value is Dictionary):
		return _reject(actual_peer_id, &"input_not_dictionary", message)

	var expected_sequence: int = GFVariantData.get_option_int(
		_last_received_input_sequence,
		actual_peer_id
	) + 1
	var fingerprint: String = _message_fingerprint(message)
	if fingerprint.is_empty():
		return _reject(actual_peer_id, &"message_fingerprint_failed", message)
	if message.sequence < expected_sequence:
		if (
			message.sequence == expected_sequence - 1
			and fingerprint == GFVariantData.get_option_string(
				_last_received_input_fingerprint,
				actual_peer_id
			)
		):
			return _make_report(true, &"duplicate", &"", {
				"tick": message.tick,
				"sequence": message.sequence,
				"duplicate": true,
			})
		return _reject(actual_peer_id, &"input_sequence_stale", message)
	if message.sequence > expected_sequence:
		return _reject(actual_peer_id, &"input_sequence_gap", message, {
			"expected_sequence": expected_sequence,
		})
	var last_tick: int = GFVariantData.get_option_int(
		_last_received_input_tick,
		actual_peer_id,
		_current_tick
	)
	if message.tick < last_tick:
		return _reject(actual_peer_id, &"input_tick_regressed", message)
	if message.tick <= _current_tick or message.tick > _current_tick + _max_future_ticks:
		return _reject(actual_peer_id, &"input_tick_out_of_window", message)
	if _pending_input_count + _pending_finalization_count >= _max_pending_inputs:
		return _reject(actual_peer_id, &"pending_input_budget_exceeded", message)
	var frames_at_tick: Array[GFNetworkInputFrame] = _get_pending_inputs_for_tick(message.tick)
	if frames_at_tick.size() >= _max_inputs_per_tick:
		return _reject(actual_peer_id, &"tick_input_budget_exceeded", message)

	var frame: GFNetworkInputFrame = GFNetworkInputFrame.new(
		message.tick,
		actual_peer_id,
		message.sequence,
		GFVariantData.as_dictionary(input_value)
	)
	var frame_report: Dictionary = frame.validate_frame(_value_budget_options())
	if not GFVariantData.get_option_bool(frame_report, "ok"):
		return _reject(actual_peer_id, &"invalid_input_payload", message)
	var frame_bytes: int = GFVariantData.get_option_int(frame_report, "payload_bytes")
	if _pending_input_bytes + frame_bytes > _max_pending_input_bytes:
		return _reject(actual_peer_id, &"pending_input_byte_budget_exceeded", message)

	_operation_active = true
	var adapter_report: Dictionary = _adapter._validate_input(
		frame.duplicate_frame(),
		actual_peer_id,
		_make_adapter_context(&"validate_remote_input")
	)
	_operation_active = false
	_last_received_input_sequence[actual_peer_id] = message.sequence
	_last_received_input_tick[actual_peer_id] = message.tick
	_last_received_input_fingerprint[actual_peer_id] = fingerprint
	if not GFVariantData.get_option_bool(adapter_report, "ok"):
		_mark_input_finalized(actual_peer_id, message.sequence)
		_notification_active = true
		input_finalized.emit(actual_peer_id, message.sequence, false, &"adapter_rejected")
		_notification_active = false
		return _make_report(false, &"finalized_rejected", &"adapter_rejected_input", {
			"tick": message.tick,
			"sequence": message.sequence,
		})

	frames_at_tick.append(frame.duplicate_frame())
	_pending_inputs_by_tick[message.tick] = frames_at_tick
	_pending_input_count += 1
	_pending_input_bytes += frame_bytes
	return _make_report(true, &"queued", &"", {
		"tick": message.tick,
		"sequence": message.sequence,
	})


func _handle_snapshot_message(actual_peer_id: int, message: GFNetworkMessage) -> Dictionary:
	if _role != Role.REPLICA or _phase not in [Phase.AWAITING_BASELINE, Phase.ACTIVE]:
		return _reject(actual_peer_id, &"replica_not_receiving", message)
	if actual_peer_id != _authority_peer_id:
		return _reject(actual_peer_id, &"unexpected_authority_peer", message)
	var envelope_reason: StringName = _validate_envelope(
		actual_peer_id,
		message,
		SNAPSHOT_MESSAGE_TYPE
	)
	if envelope_reason != &"":
		return _reject(actual_peer_id, envelope_reason, message)
	if not _has_exact_keys(
		message.payload,
		[
			"protocol_version",
			"epoch_id",
			"recipient_peer_id",
			"state",
			"ack_input_sequence",
		]
	):
		return _reject(actual_peer_id, &"invalid_snapshot_envelope", message)
	if not _protocol_matches(message.payload):
		return _reject(actual_peer_id, &"protocol_version_mismatch", message)
	if GFVariantData.get_option_string(message.payload, "epoch_id") != _epoch_id:
		return _reject(actual_peer_id, &"epoch_mismatch", message)
	var recipient_value: Variant = GFVariantData.get_option_value(
		message.payload,
		"recipient_peer_id"
	)
	if not _is_integer_value(recipient_value):
		return _reject(actual_peer_id, &"invalid_snapshot_recipient", message)
	if GFVariantData.to_int(recipient_value) != _local_peer_id:
		return _reject(actual_peer_id, &"unexpected_snapshot_recipient", message)
	var state_value: Variant = GFVariantData.get_option_value(message.payload, "state")
	var ack_value: Variant = GFVariantData.get_option_value(message.payload, "ack_input_sequence")
	if not (state_value is Dictionary) or not _is_integer_value(ack_value):
		return _reject(actual_peer_id, &"invalid_snapshot_payload", message)
	var ack_sequence: int = GFVariantData.to_int(ack_value)
	var fingerprint: String = _message_fingerprint(message)
	if fingerprint.is_empty():
		return _reject(actual_peer_id, &"message_fingerprint_failed", message)
	if message.sequence == _last_snapshot_sequence:
		if fingerprint == _last_snapshot_fingerprint:
			return _make_report(true, &"duplicate", &"", {
				"tick": message.tick,
				"sequence": message.sequence,
				"duplicate": true,
			})
		return _require_resync(actual_peer_id, &"snapshot_sequence_conflict", message)
	if message.sequence < _last_snapshot_sequence:
		return _reject(actual_peer_id, &"snapshot_sequence_stale", message)
	if (
		_last_snapshot_sequence > 0
		and message.sequence - _last_snapshot_sequence > _max_sequence_jump
	):
		return _require_resync(actual_peer_id, &"snapshot_sequence_jump_exceeded", message)
	if _last_snapshot_tick >= 0 and message.tick <= _last_snapshot_tick:
		return _require_resync(actual_peer_id, &"snapshot_tick_conflict", message)
	if (
		ack_sequence < 0
		or ack_sequence < _last_ack_input_sequence
		or ack_sequence >= _next_local_input_sequence
	):
		return _require_resync(actual_peer_id, &"invalid_input_ack", message)

	var state: Dictionary = GFVariantData.as_dictionary(state_value).duplicate(true)
	var transport_report: Dictionary = _validate_transport_value(state)
	if not GFVariantData.get_option_bool(transport_report, "ok"):
		return _reject(actual_peer_id, &"unsafe_snapshot_state", message)
	var previous_tick: int = _current_tick
	var replayed_tick_count: int = maxi(previous_tick - message.tick, 0)
	if _prediction_enabled and replayed_tick_count > _max_replay_ticks:
		return _require_resync(actual_peer_id, &"replay_budget_exceeded", message, {
			"replayed_tick_count": replayed_tick_count,
		})
	var remaining_inputs: Array[GFNetworkInputFrame] = _get_unacknowledged_local_inputs(ack_sequence)
	for frame: GFNetworkInputFrame in remaining_inputs:
		if frame.tick <= message.tick:
			return _require_resync(
				actual_peer_id,
				&"local_input_precedes_baseline",
				message
			)

	_operation_active = true
	var state_validation: Dictionary = _adapter._validate_state(
		state.duplicate(true),
		message.tick,
		_make_adapter_context(&"validate_snapshot_state")
	)
	if not GFVariantData.get_option_bool(state_validation, "ok"):
		_operation_active = false
		return _reject(actual_peer_id, &"adapter_rejected_state", message)
	var rollback_report: Dictionary = _capture_adapter_state(
		_current_tick,
		&"capture_reconciliation_rollback"
	)
	if not GFVariantData.get_option_bool(rollback_report, "ok"):
		_operation_active = false
		return _make_report(false, &"failed", &"rollback_capture_failed")
	var rollback_state: Dictionary = GFVariantData.get_option_dictionary(rollback_report, "state")
	var predicted_snapshot: GFNetworkSnapshot = _prediction_history.get_snapshot(message.tick)
	var corrected: bool = false
	if predicted_snapshot != null:
		corrected = not _adapter._states_equal(
			predicted_snapshot.state.duplicate(true),
			state.duplicate(true),
			message.tick,
			_make_adapter_context(&"compare_prediction")
		)
	if not _restore_adapter_state(state, message.tick, &"apply_authoritative_snapshot"):
		var rollback_ok: bool = _restore_adapter_state(
			rollback_state,
			previous_tick,
			&"reconciliation_rollback"
		)
		_operation_active = false
		if not rollback_ok:
			_set_phase(Phase.FAULTED)
			return _make_report(false, &"faulted", &"rollback_failed")
		return _make_report(false, &"failed", &"snapshot_apply_failed")

	var replay_snapshots: Array[GFNetworkSnapshot] = []
	if _prediction_enabled:
		for replay_tick: int in range(message.tick + 1, previous_tick + 1):
			var replay_inputs: Array[GFNetworkInputFrame] = _get_frames_for_tick(
				remaining_inputs,
				replay_tick
			)
			replay_inputs.sort_custom(_input_frame_less_than)
			var replay_report: Dictionary = _adapter._simulate_tick(
				replay_tick,
				_duplicate_frames(replay_inputs),
				_make_adapter_context(&"replay_prediction")
			)
			if not GFVariantData.get_option_bool(replay_report, "ok"):
				var rollback_ok: bool = _restore_adapter_state(
					rollback_state,
					previous_tick,
					&"reconciliation_rollback"
				)
				_operation_active = false
				if not rollback_ok:
					_set_phase(Phase.FAULTED)
					return _make_report(false, &"faulted", &"rollback_failed")
				return _make_report(false, &"failed", &"prediction_replay_failed")
			var replay_state_report: Dictionary = _capture_adapter_state(
				replay_tick,
				&"capture_replayed_state"
			)
			if not GFVariantData.get_option_bool(replay_state_report, "ok"):
				var rollback_ok: bool = _restore_adapter_state(
					rollback_state,
					previous_tick,
					&"reconciliation_rollback"
				)
				_operation_active = false
				if not rollback_ok:
					_set_phase(Phase.FAULTED)
					return _make_report(false, &"faulted", &"rollback_failed")
				return _make_report(false, &"failed", &"replay_capture_failed")
			replay_snapshots.append(GFNetworkSnapshot.new(
				replay_tick,
				GFVariantData.get_option_dictionary(replay_state_report, "state"),
				_local_peer_id,
				{"predicted": true}
			))

	var snapshot: GFNetworkSnapshot = GFNetworkSnapshot.new(
		message.tick,
		state,
		_authority_peer_id,
		{
			"protocol_version": PROTOCOL_VERSION,
			"epoch_id": _epoch_id,
			"snapshot_sequence": message.sequence,
			"ack_input_sequence": ack_sequence,
		}
	)
	_commit_snapshot_application(
		snapshot,
		message.sequence,
		fingerprint,
		ack_sequence,
		remaining_inputs,
		replay_snapshots,
		previous_tick
	)
	_operation_active = false
	_set_phase(Phase.ACTIVE)
	_notification_active = true
	authoritative_snapshot_applied.emit(
		snapshot.duplicate_snapshot(),
		corrected,
		replayed_tick_count if _prediction_enabled else 0
	)
	_notification_active = false
	return _make_report(true, &"applied", &"", {
		"tick": message.tick,
		"sequence": message.sequence,
		"corrected": corrected,
		"replayed_tick_count": replayed_tick_count if _prediction_enabled else 0,
	})


func _commit_snapshot_application(
	snapshot: GFNetworkSnapshot,
	sequence: int,
	fingerprint: String,
	ack_sequence: int,
	remaining_inputs: Array[GFNetworkInputFrame],
	replay_snapshots: Array[GFNetworkSnapshot],
	previous_tick: int
) -> void:
	_last_snapshot_sequence = sequence
	_last_snapshot_tick = snapshot.tick
	_last_snapshot_fingerprint = fingerprint
	_last_ack_input_sequence = ack_sequence
	_current_tick = maxi(previous_tick, snapshot.tick) if _prediction_enabled else snapshot.tick
	var _history_added: bool = _authoritative_history.add_snapshot(snapshot)
	_local_inputs = _duplicate_frames(remaining_inputs)
	_local_input_bytes = _calculate_frame_bytes(_local_inputs)
	_prediction_history.clear()
	if _prediction_enabled:
		var _baseline_added: bool = _prediction_history.add_snapshot(snapshot)
		for replay_snapshot: GFNetworkSnapshot in replay_snapshots:
			var _replay_added: bool = _prediction_history.add_snapshot(replay_snapshot)


func _validate_envelope(
	actual_peer_id: int,
	message: GFNetworkMessage,
	expected_type: StringName
) -> StringName:
	if message.sender_id != actual_peer_id:
		return &"sender_peer_mismatch"
	if message.message_type != expected_type:
		return &"unexpected_message_type"
	if message.channel_id != _channel_id:
		return &"sync_channel_mismatch"
	if (
		message.sequence <= 0
		or message.sequence > _MAX_SAFE_SEQUENCE
		or message.tick < 0
		or message.tick > _MAX_SAFE_SEQUENCE
	):
		return &"message_cursor_out_of_range"
	var payload_report: Dictionary = _validate_message_payload(message.payload)
	if not GFVariantData.get_option_bool(payload_report, "ok"):
		return &"unsafe_message_payload"
	return &""


func _protocol_matches(payload: Dictionary) -> bool:
	var version_value: Variant = GFVariantData.get_option_value(payload, "protocol_version")
	return _is_integer_value(version_value) and GFVariantData.to_int(version_value) == PROTOCOL_VERSION


func _build_input_message(frame: GFNetworkInputFrame) -> GFNetworkMessage:
	var payload: Dictionary = {
		"protocol_version": PROTOCOL_VERSION,
		"epoch_id": _epoch_id,
		"recipient_peer_id": _authority_peer_id,
		"input": frame.payload.duplicate(true),
	}
	if not GFVariantData.get_option_bool(_validate_message_payload(payload), "ok"):
		return null
	return GFNetworkMessage.new(
		INPUT_MESSAGE_TYPE,
		payload,
		frame.sequence,
		frame.tick,
		frame.peer_id,
		_channel_id
	)


func _capture_adapter_state(tick: int, operation: StringName) -> Dictionary:
	var report: Dictionary = _adapter._capture_state(
		tick,
		_make_adapter_context(operation)
	)
	if not GFVariantData.get_option_bool(report, "ok"):
		return {"ok": false}
	var state_value: Variant = GFVariantData.get_option_value(report, "state")
	if not (state_value is Dictionary):
		return {"ok": false}
	var state: Dictionary = GFVariantData.as_dictionary(state_value).duplicate(true)
	var validation: Dictionary = _validate_transport_value(state)
	if not GFVariantData.get_option_bool(validation, "ok"):
		return {"ok": false}
	return {
		"ok": true,
		"state": state,
	}


func _restore_adapter_state(
	state: Dictionary,
	tick: int,
	operation: StringName
) -> bool:
	var report: Dictionary = _adapter._restore_state(
		state.duplicate(true),
		tick,
		_make_adapter_context(operation)
	)
	return GFVariantData.get_option_bool(report, "ok")


func _make_adapter_context(operation: StringName) -> Dictionary:
	return {
		"role": _role,
		"phase": _phase,
		"epoch_id": _epoch_id,
		"local_peer_id": _local_peer_id,
		"authority_peer_id": _authority_peer_id,
		"operation": operation,
	}


func _validate_transport_value(value: Variant) -> Dictionary:
	var report: Dictionary = _TRANSPORT_VALUE_VALIDATOR.validate(
		value,
		_value_budget_options()
	)
	if not GFVariantData.get_option_bool(report, "ok"):
		return report
	var payload_bytes: int = var_to_bytes(value).size()
	if payload_bytes > _max_payload_bytes:
		return {
			"ok": false,
			"error": "payload_budget_exceeded",
			"path": "$",
			"payload_bytes": payload_bytes,
		}
	report["payload_bytes"] = payload_bytes
	return report


func _validate_message_payload(value: Variant) -> Dictionary:
	var report: Dictionary = _TRANSPORT_VALUE_VALIDATOR.validate(
		value,
		{
			"max_depth": _max_value_depth + 1,
			"max_nodes": _max_value_nodes + _MESSAGE_ENVELOPE_NODE_OVERHEAD,
		}
	)
	if not GFVariantData.get_option_bool(report, "ok"):
		return report
	var payload_bytes: int = var_to_bytes(value).size()
	if payload_bytes > _max_payload_bytes + _MESSAGE_ENVELOPE_BYTE_OVERHEAD:
		return {
			"ok": false,
			"error": "message_payload_budget_exceeded",
			"path": "$",
			"payload_bytes": payload_bytes,
		}
	report["payload_bytes"] = payload_bytes
	return report


func _value_budget_options() -> Dictionary:
	return {
		"max_depth": _max_value_depth,
		"max_nodes": _max_value_nodes,
		"max_payload_bytes": _max_payload_bytes,
	}


func _has_exact_keys(data: Dictionary, expected_keys: Array[String]) -> bool:
	if data.size() != expected_keys.size():
		return false
	var observed: PackedStringArray = PackedStringArray()
	for key: Variant in data.keys():
		if not (key is String) and not (key is StringName):
			return false
		var text_key: String = GFVariantData.to_text(key)
		if observed.has(text_key) or not expected_keys.has(text_key):
			return false
		var _appended: bool = observed.append(text_key)
	return observed.size() == expected_keys.size()


func _is_integer_value(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var number: float = GFVariantData.to_float(value)
	return (
		not is_nan(number)
		and not is_inf(number)
		and number == floor(number)
		and absf(number) <= float(_MAX_SAFE_SEQUENCE)
	)


func _is_valid_identifier(value: String) -> bool:
	return (
		not value.is_empty()
		and value.length() <= _MAX_IDENTIFIER_LENGTH
		and value == value.strip_edges()
	)


func _read_limits(options: Dictionary) -> Dictionary:
	var values: Dictionary = {
		"history_capacity": GFVariantData.get_option_int(
			options,
			"history_capacity",
			_DEFAULT_HISTORY_CAPACITY
		),
		"max_replica_peers": GFVariantData.get_option_int(
			options,
			"max_replica_peers",
			_DEFAULT_MAX_REPLICA_PEERS
		),
		"max_pending_inputs": GFVariantData.get_option_int(
			options,
			"max_pending_inputs",
			_DEFAULT_MAX_PENDING_INPUTS
		),
		"max_pending_input_bytes": GFVariantData.get_option_int(
			options,
			"max_pending_input_bytes",
			_DEFAULT_MAX_PENDING_INPUT_BYTES
		),
		"max_inputs_per_tick": GFVariantData.get_option_int(
			options,
			"max_inputs_per_tick",
			_DEFAULT_MAX_INPUTS_PER_TICK
		),
		"max_future_ticks": GFVariantData.get_option_int(
			options,
			"max_future_ticks",
			_DEFAULT_MAX_FUTURE_TICKS
		),
		"max_replay_ticks": GFVariantData.get_option_int(
			options,
			"max_replay_ticks",
			_DEFAULT_MAX_REPLAY_TICKS
		),
		"max_sequence_jump": GFVariantData.get_option_int(
			options,
			"max_sequence_jump",
			_DEFAULT_MAX_SEQUENCE_JUMP
		),
		"max_value_depth": GFVariantData.get_option_int(
			options,
			"max_value_depth",
			_DEFAULT_MAX_VALUE_DEPTH
		),
		"max_value_nodes": GFVariantData.get_option_int(
			options,
			"max_value_nodes",
			_DEFAULT_MAX_VALUE_NODES
		),
		"max_payload_bytes": GFVariantData.get_option_int(
			options,
			"max_payload_bytes",
			_DEFAULT_MAX_PAYLOAD_BYTES
		),
	}
	var maxima: Dictionary = {
		"history_capacity": _MAX_HISTORY_CAPACITY,
		"max_replica_peers": _MAX_REPLICA_PEERS,
		"max_pending_inputs": _MAX_PENDING_INPUTS,
		"max_pending_input_bytes": _MAX_PENDING_INPUT_BYTES,
		"max_inputs_per_tick": _MAX_INPUTS_PER_TICK,
		"max_future_ticks": _MAX_FUTURE_TICKS,
		"max_replay_ticks": _MAX_REPLAY_TICKS,
		"max_sequence_jump": _MAX_SEQUENCE_JUMP,
		"max_value_depth": _MAX_VALUE_DEPTH,
		"max_value_nodes": _MAX_VALUE_NODES,
		"max_payload_bytes": _MAX_PAYLOAD_BYTES,
	}
	for key: String in values:
		var value: int = GFVariantData.get_option_int(values, key)
		if value <= 0 or value > GFVariantData.get_option_int(maxima, key):
			return {"ok": false}
	values["ok"] = true
	return values


func _apply_limits(limits: Dictionary) -> void:
	_history_capacity = GFVariantData.get_option_int(limits, "history_capacity")
	_max_replica_peers = GFVariantData.get_option_int(limits, "max_replica_peers")
	_max_pending_inputs = GFVariantData.get_option_int(limits, "max_pending_inputs")
	_max_pending_input_bytes = GFVariantData.get_option_int(
		limits,
		"max_pending_input_bytes"
	)
	_max_inputs_per_tick = GFVariantData.get_option_int(limits, "max_inputs_per_tick")
	_max_future_ticks = GFVariantData.get_option_int(limits, "max_future_ticks")
	_max_replay_ticks = GFVariantData.get_option_int(limits, "max_replay_ticks")
	_max_sequence_jump = GFVariantData.get_option_int(limits, "max_sequence_jump")
	_max_value_depth = GFVariantData.get_option_int(limits, "max_value_depth")
	_max_value_nodes = GFVariantData.get_option_int(limits, "max_value_nodes")
	_max_payload_bytes = GFVariantData.get_option_int(limits, "max_payload_bytes")


func _clear_stream_state() -> void:
	_pending_inputs_by_tick.clear()
	_pending_input_count = 0
	_pending_input_bytes = 0
	_pending_finalization_count = 0
	_last_received_input_sequence.clear()
	_last_received_input_tick.clear()
	_last_received_input_fingerprint.clear()
	_last_finalized_input_sequence.clear()
	_finalized_input_sequences.clear()
	for peer_value: Variant in _allowed_replica_peers.keys():
		var peer_id: int = GFVariantData.to_int(peer_value)
		_last_received_input_sequence[peer_id] = 0
		_last_received_input_tick[peer_id] = _current_tick
		_last_received_input_fingerprint[peer_id] = ""
		_last_finalized_input_sequence[peer_id] = 0
		_finalized_input_sequences[peer_id] = {}
	_next_snapshot_sequence = 1
	_latest_snapshot_ack_by_peer.clear()
	_last_snapshot_sequence = 0
	_last_snapshot_tick = -1
	_last_snapshot_fingerprint = ""
	_last_ack_input_sequence = 0
	_next_local_input_sequence = 1
	_local_input_bytes = 0
	_local_inputs.clear()
	_authoritative_history = GFNetworkHistoryBuffer.new(_history_capacity)
	_prediction_history = GFNetworkHistoryBuffer.new(_history_capacity)


func _get_pending_inputs_for_tick(tick: int) -> Array[GFNetworkInputFrame]:
	var result: Array[GFNetworkInputFrame] = []
	var value: Variant = GFVariantData.get_option_value(_pending_inputs_by_tick, tick, [])
	if value is Array:
		for item: Variant in value:
			if item is GFNetworkInputFrame:
				var frame: GFNetworkInputFrame = item
				result.append(frame.duplicate_frame())
	return result


func _get_local_inputs_for_tick(
	tick: int,
	minimum_sequence_exclusive: int
) -> Array[GFNetworkInputFrame]:
	return _get_frames_for_tick(
		_get_unacknowledged_local_inputs(minimum_sequence_exclusive),
		tick
	)


func _get_unacknowledged_local_inputs(
	ack_sequence: int
) -> Array[GFNetworkInputFrame]:
	var result: Array[GFNetworkInputFrame] = []
	for frame: GFNetworkInputFrame in _local_inputs:
		if frame.sequence > ack_sequence:
			result.append(frame.duplicate_frame())
	return result


func _get_local_input_by_sequence(sequence: int) -> GFNetworkInputFrame:
	for frame: GFNetworkInputFrame in _local_inputs:
		if frame.sequence == sequence:
			return frame.duplicate_frame()
	return null


func _get_frames_for_tick(
	source: Array[GFNetworkInputFrame],
	tick: int
) -> Array[GFNetworkInputFrame]:
	var result: Array[GFNetworkInputFrame] = []
	for frame: GFNetworkInputFrame in source:
		if frame.tick == tick:
			result.append(frame.duplicate_frame())
	return result


func _duplicate_frames(
	source: Array[GFNetworkInputFrame]
) -> Array[GFNetworkInputFrame]:
	var result: Array[GFNetworkInputFrame] = []
	for frame: GFNetworkInputFrame in source:
		if frame != null:
			result.append(frame.duplicate_frame())
	return result


func _input_frame_less_than(a: GFNetworkInputFrame, b: GFNetworkInputFrame) -> bool:
	if a.peer_id != b.peer_id:
		return a.peer_id < b.peer_id
	return a.sequence < b.sequence


func _commit_consumed_inputs(
	tick: int,
	frames: Array[GFNetworkInputFrame]
) -> void:
	var _tick_erased: bool = _pending_inputs_by_tick.erase(tick)
	for frame: GFNetworkInputFrame in frames:
		_pending_input_count = maxi(_pending_input_count - 1, 0)
		_pending_input_bytes = maxi(
			_pending_input_bytes - var_to_bytes(frame.payload).size(),
			0
		)
		_mark_input_finalized(frame.peer_id, frame.sequence)


func _mark_input_finalized(peer_id: int, sequence: int) -> void:
	var set_value: Variant = GFVariantData.get_option_value(
		_finalized_input_sequences,
		peer_id,
		{}
	)
	var finalized_set: Dictionary = (
		GFVariantData.as_dictionary(set_value)
		if set_value is Dictionary
		else {}
	)
	if not finalized_set.has(sequence):
		finalized_set[sequence] = true
		_pending_finalization_count += 1
	var cursor: int = GFVariantData.get_option_int(
		_last_finalized_input_sequence,
		peer_id
	)
	while finalized_set.has(cursor + 1):
		var _erased: bool = finalized_set.erase(cursor + 1)
		_pending_finalization_count = maxi(_pending_finalization_count - 1, 0)
		cursor += 1
	_last_finalized_input_sequence[peer_id] = cursor
	_finalized_input_sequences[peer_id] = finalized_set


func _remove_pending_inputs_for_peer(peer_id: int) -> void:
	for tick_value: Variant in _pending_inputs_by_tick.keys():
		var tick: int = GFVariantData.to_int(tick_value)
		var kept: Array[GFNetworkInputFrame] = []
		for frame: GFNetworkInputFrame in _get_pending_inputs_for_tick(tick):
			if frame.peer_id == peer_id:
				_pending_input_count = maxi(_pending_input_count - 1, 0)
				_pending_input_bytes = maxi(
					_pending_input_bytes - var_to_bytes(frame.payload).size(),
					0
				)
			else:
				kept.append(frame)
		if kept.is_empty():
			var _erased: bool = _pending_inputs_by_tick.erase(tick)
		else:
			_pending_inputs_by_tick[tick] = kept


func _calculate_frame_bytes(frames: Array[GFNetworkInputFrame]) -> int:
	var result: int = 0
	for frame: GFNetworkInputFrame in frames:
		result += var_to_bytes(frame.payload).size()
	return result


func _duplicate_history(source: GFNetworkHistoryBuffer) -> GFNetworkHistoryBuffer:
	var result: GFNetworkHistoryBuffer = GFNetworkHistoryBuffer.new(_history_capacity)
	for tick: int in source.get_ticks():
		var snapshot: GFNetworkSnapshot = source.get_snapshot(tick)
		if snapshot != null:
			var _added: bool = result.add_snapshot(snapshot)
	return result


func _message_fingerprint(message: GFNetworkMessage) -> String:
	return GFDeterministicVariantSerializer.sha256({
		"type": message.message_type,
		"sequence": message.sequence,
		"tick": message.tick,
		"sender_id": message.sender_id,
		"channel_id": message.channel_id,
		"payload": message.payload,
	}, {
		"allow_floats": true,
		"max_depth": _max_value_depth + 4,
		"max_items": (_max_value_nodes * 2) + _MESSAGE_ENVELOPE_NODE_OVERHEAD + 16,
		"max_string_length": _max_payload_bytes,
		"max_output_bytes": _MAX_FINGERPRINT_OUTPUT_BYTES,
	})


func _make_report(
	ok: bool,
	status: StringName,
	reason: StringName,
	extra: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = extra.duplicate(true)
	report["ok"] = ok
	report["status"] = status
	report["reason"] = reason
	return report


func _is_busy() -> bool:
	return _operation_active or _notification_active


func _reject(
	peer_id: int,
	reason: StringName,
	message: GFNetworkMessage,
	extra: Dictionary = {}
) -> Dictionary:
	var details: Dictionary = _make_protocol_details(message, extra)
	_notification_active = true
	synchronization_rejected.emit(peer_id, reason, details.duplicate(true))
	_notification_active = false
	return _make_report(false, &"rejected", reason, details)


func _require_resync(
	peer_id: int,
	reason: StringName,
	message: GFNetworkMessage,
	extra: Dictionary = {}
) -> Dictionary:
	var details: Dictionary = _make_protocol_details(message, extra)
	_set_phase(Phase.RESYNC_REQUIRED)
	_notification_active = true
	synchronization_rejected.emit(peer_id, reason, details.duplicate(true))
	resync_required.emit(reason, details.duplicate(true))
	_notification_active = false
	return _make_report(false, &"resync_required", reason, details)


func _make_protocol_details(
	message: GFNetworkMessage,
	extra: Dictionary = {}
) -> Dictionary:
	var details: Dictionary = {
		"role": _role,
		"phase": _phase,
	}
	if message != null:
		details["tick"] = message.tick
		details["sequence"] = message.sequence
		if message.message_type in [INPUT_MESSAGE_TYPE, SNAPSHOT_MESSAGE_TYPE]:
			details["message_type"] = message.message_type
		else:
			details["message_type_known"] = false
	for key: String in [
		"expected_sequence",
		"replayed_tick_count",
	]:
		if extra.has(key):
			details[key] = extra[key]
	return details


func _set_phase(next_phase: Phase) -> void:
	if _phase == next_phase:
		return
	var previous_phase: Phase = _phase
	_phase = next_phase
	_notification_active = true
	phase_changed.emit(previous_phase, _phase)
	_notification_active = false
