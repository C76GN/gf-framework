## GFBgmSessionHandle: 已提交 BGM 播放会话的类型化控制句柄。
##
## 句柄只代表一个精确的逻辑会话身份，不暴露本地播放器或后端对象。替换后的旧句柄
## 不能停止新会话；会话终态只由 Audio Utility 写入一次。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
## [br]
## @layer standard/utilities/audio
class_name GFBgmSessionHandle
extends RefCounted


# --- 信号 ---

## 会话进入终态时发出一次。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param handle: 当前规范会话句柄。
## [br]
## @param end_kind: 会话的唯一终结原因。
signal ended(handle: GFBgmSessionHandle, end_kind: EndKind)


# --- 枚举 ---

## BGM 会话的物理播放 owner。
## [br]
## @api public
## [br]
## @since unreleased
enum OwnerKind {
	## 尚未配置或没有播放 owner。
	NONE,
	## GF 本地 AudioStreamPlayer 会话。
	LOCAL,
	## GFAudioBackend 持有的会话。
	BACKEND,
}

## BGM 会话的终结原因。
## [br]
## @api public
## [br]
## @since unreleased
enum EndKind {
	## 会话仍在活动中；不是终态。
	NONE,
	## 音频自然播放完毕。
	NATURAL_FINISH,
	## 调用方或全局通道显式停止会话。
	STOPPED,
	## 新会话替换了当前会话。
	REPLACED,
	## 会话 owner 已退出生命周期。
	OWNER_RELEASED,
	## Audio Utility 已释放。
	UTILITY_DISPOSED,
	## 已提交的播放会话随后发生物理播放失败。
	PLAYBACK_FAILED,
}


# --- 私有变量 ---

var _session_id: int = 0
var _request_id: int = 0
var _history_key: String = ""
var _owner_kind: OwnerKind = OwnerKind.NONE
var _end_kind: EndKind = EndKind.NONE
var _stop_delegate: GFWeakMethodInvocation = null
var _configured: bool = false
var _stop_requested: bool = false
var _ended_signal_emitted: bool = false


# --- 公共方法 ---

## 获取 Utility 内唯一会话 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 大于零的会话 ID；尚未配置时返回 0。
func get_session_id() -> int:
	return _session_id


## 获取创建当前会话的 BGM start request ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 大于零的请求 ID；尚未配置时返回 0。
func get_request_id() -> int:
	return _request_id


## 获取提交会话时冻结的 BGM history key。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 会话 history key；未提供时为空字符串。
func get_history_key() -> String:
	return _history_key


## 获取提交会话的物理播放 owner。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `LOCAL`、`BACKEND` 或尚未配置时的 `NONE`。
func get_owner_kind() -> OwnerKind:
	return _owner_kind


## 检查会话是否仍处于活动状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已配置且尚未终结时返回 true。
func is_active() -> bool:
	return _configured and _end_kind == EndKind.NONE


## 检查会话是否已经进入终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已配置并终结时返回 true。
func is_terminal() -> bool:
	return _configured and _end_kind != EndKind.NONE


## 获取会话终结原因。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 活动会话返回 `NONE`；终态会话返回其唯一终结原因。
func get_end_kind() -> EndKind:
	return _end_kind


## 请求停止当前精确会话。
##
## 返回 true 只表示 Audio Utility 接受了该会话的停止请求；淡出可能在之后完成。
## 句柄已终结、会话已被替换、Utility 已释放或参数非法时返回 false。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param fade_seconds: 非负且有限的淡出秒数。
## [br]
## @return 本次精确会话停止请求被接受时返回 true。
func stop(fade_seconds: float = 0.0) -> bool:
	if (
		not Thread.is_main_thread()
		or not is_active()
		or not is_finite(fade_seconds)
		or fade_seconds < 0.0
		or _stop_delegate == null
		or _stop_requested
	):
		return false
	_stop_requested = true
	var accepted: bool = _invocation_returned_true(
		_stop_delegate.invoke([self, fade_seconds])
	)
	if not accepted and is_active():
		_stop_requested = false
	return accepted


# --- 框架内部方法 ---

## 由 Audio Utility 初始化规范会话身份和弱停止委托。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/audio
## [br]
## @since unreleased
## [br]
## @param session_id: Utility 内唯一且大于零的会话 ID。
## [br]
## @param request_id: 创建会话的 start request ID。
## [br]
## @param history_key: 提交会话时冻结的 history key。
## [br]
## @param owner_kind: `LOCAL` 或 `BACKEND`。
## [br]
## @param stop_delegate: 无绑定参数的 Utility 对象方法，签名为 `(handle, fade_seconds) -> bool`。
## [br]
## @return 首次完整配置成功返回 true。
func configure_for_framework(
	session_id: int,
	request_id: int,
	history_key: String,
	owner_kind: OwnerKind,
	stop_delegate: Callable
) -> bool:
	if (
		not Thread.is_main_thread()
		or _configured
		or session_id <= 0
		or request_id <= 0
		or owner_kind not in [OwnerKind.LOCAL, OwnerKind.BACKEND]
	):
		return false
	var invocation: GFWeakMethodInvocation = _make_weak_invocation(stop_delegate)
	if invocation == null:
		return false

	_session_id = session_id
	_request_id = request_id
	_history_key = history_key
	_owner_kind = owner_kind
	_stop_delegate = invocation
	_configured = true
	return true


## 由 Audio Utility 写入唯一会话终态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/audio
## [br]
## @since unreleased
## [br]
## @param end_kind: 非 `NONE` 的闭合终结原因。
## [br]
## @param should_emit_signal: false 时只冻结终态，由 `emit_ended_for_framework()` 延后通知。
## [br]
## @return 首次写入合法终态时返回 true。
func complete_for_framework(
	end_kind: EndKind,
	should_emit_signal: bool = true
) -> bool:
	if (
		not Thread.is_main_thread()
		or not is_active()
		or not EndKind.values().has(int(end_kind))
		or end_kind == EndKind.NONE
	):
		return false
	_end_kind = end_kind
	_stop_delegate = null
	if should_emit_signal:
		var _emitted: bool = emit_ended_for_framework()
	return true


## 发出已经冻结的唯一会话终态通知。
##
## Audio Utility 可先用 `complete_for_framework(..., false)` 原子冻结 replacement 涉及的
## 全部句柄与 start operation，再调用本方法，避免首个用户回调观察到半提交状态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/audio
## [br]
## @since unreleased
## [br]
## @return 首次发出已冻结终态时返回 true。
func emit_ended_for_framework() -> bool:
	if (
		not Thread.is_main_thread()
		or not is_terminal()
		or _ended_signal_emitted
	):
		return false
	_ended_signal_emitted = true
	ended.emit(self, _end_kind)
	return true


## 检查句柄是否已由 Audio Utility 完整配置。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/audio
## [br]
## @since unreleased
## [br]
## @return 身份和 owner 已冻结时返回 true。
func is_configured_for_framework() -> bool:
	return _configured


# --- 私有/辅助方法 ---

static func _make_weak_invocation(method_delegate: Callable) -> GFWeakMethodInvocation:
	if (
		not method_delegate.is_valid()
		or method_delegate.get_bound_arguments_count() != 0
	):
		return null
	var delegate_owner: Object = method_delegate.get_object()
	var delegate_method: StringName = method_delegate.get_method()
	if (
		delegate_owner == null
		or not is_instance_valid(delegate_owner)
		or delegate_method.is_empty()
	):
		return null
	return GFWeakMethodInvocation.new(delegate_owner, delegate_method)


static func _invocation_returned_true(invocation_result: Dictionary) -> bool:
	var invoked_value: Variant = invocation_result.get("invoked", false)
	var return_value: Variant = invocation_result.get("value", false)
	return (
		invoked_value is bool
		and invoked_value
		and return_value is bool
		and return_value
	)
