## GFSessionTraceUtility: 有界的运行时会话轨迹记录器。
##
## 项目必须先显式注册通道，才能记录输入、路由、存档、网络或其他语义事件。
## 轨迹只保存经过技术脱敏和字节预算约束的结构化数据，不扫描场景树、节点属性或业务状态。
## 长期保存的会话上下文与目录 metadata 始终使用 privacy 安全下限，避免运行期切换 profile 后泄漏旧值。
## 项目仍需通过字段白名单排除账号、令牌和其他无法由通用编码器识别的业务秘密。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFSessionTraceUtility
extends GFUtility


# --- 信号 ---

## 会话开始后发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param session_id: 当前会话标识。
## [br]
## @param context: 已脱敏的会话上下文副本。
## [br]
## @schema context: Dictionary，由项目定义并经过 GFReportValueCodec 隐私脱敏和预算限制。
signal session_started(session_id: StringName, context: Dictionary)

## 会话停止后发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param summary: 不含完整事件载荷的停止摘要。
## [br]
## @schema summary: Dictionary，包含 session_id、active、stop_reason、event_count、event_bytes、dropped_event_count、rejected_event_count、journal_event_count 和 journal_dropped_event_count。
signal session_stopped(summary: Dictionary)

## 事件成功进入有界轨迹后发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param event: 已脱敏的事件副本。
## [br]
## @schema event: Dictionary，包含 schema_version、session_id、sequence、elapsed_usec、simulation_tick、channel_id、event_id、include_in_snapshot、payload 和 metadata。
signal event_recorded(event: Dictionary)

## 事件被明确拒绝后发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param channel_id: 请求记录的通道标识。
## [br]
## @param event_id: 请求记录的事件标识。
## [br]
## @param reason: 稳定拒绝原因。
signal event_rejected(channel_id: StringName, event_id: StringName, reason: StringName)


# --- 常量 ---

## 默认最多保留的内存事件数量。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_EVENTS: int = 512

## 默认内存事件缓冲总字节预算。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_EVENT_BUFFER_BYTES: int = 1024 * 1024

## 默认单个事件字节预算。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_EVENT_BYTES: int = 16 * 1024

## 默认最多允许注册的通道数量。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_CHANNELS: int = 32

## 默认最多允许注册的同步快照 provider 数量。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_SNAPSHOT_PROVIDERS: int = 32

## 默认单次会话最多写入 journal 的事件数量。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_JOURNAL_EVENTS: int = 2048

## 拒绝原因：当前没有活动会话。
## [br]
## @api public
## [br]
## @since unreleased
const REJECT_SESSION_INACTIVE: StringName = &"session_inactive"

## 拒绝原因：通道未显式注册。
## [br]
## @api public
## [br]
## @since unreleased
const REJECT_UNKNOWN_CHANNEL: StringName = &"unknown_channel"

## 拒绝原因：通道当前被禁用。
## [br]
## @api public
## [br]
## @since unreleased
const REJECT_CHANNEL_DISABLED: StringName = &"channel_disabled"

## 拒绝原因：事件标识为空。
## [br]
## @api public
## [br]
## @since unreleased
const REJECT_INVALID_EVENT_ID: StringName = &"invalid_event_id"

## 拒绝原因：单个事件或总轨迹预算无法容纳事件。
## [br]
## @api public
## [br]
## @since unreleased
const REJECT_EVENT_TOO_LARGE: StringName = &"event_too_large"

## 拒绝原因：快照 provider 不存在或失效。
## [br]
## @api public
## [br]
## @since unreleased
const REJECT_INVALID_PROVIDER: StringName = &"invalid_provider"

## 拒绝原因：快照 provider 发生重入调用。
## [br]
## @api public
## [br]
## @since unreleased
const REJECT_PROVIDER_REENTRANT: StringName = &"provider_reentrant"

const _EVENT_SCHEMA_VERSION: int = 1
const _MAX_ID_LENGTH: int = 128
const _MIN_EVENT_BYTES: int = 512
const _PAYLOAD_ENVELOPE_RESERVE_BYTES: int = 768
const _REDACTION_PROFILE_RANKS: Dictionary = {
	GFReportValueCodec.REDACTION_PROFILE_DEBUG: 0,
	GFReportValueCodec.REDACTION_PROFILE_SUPPORT: 1,
	GFReportValueCodec.REDACTION_PROFILE_PUBLIC: 2,
	GFReportValueCodec.REDACTION_PROFILE_PRIVACY: 3,
}


# --- 公共变量 ---

## 最多保留的内存事件数量。0 表示不保留新事件。
## [br]
## @api public
## [br]
## @since unreleased
var max_events: int = DEFAULT_MAX_EVENTS:
	set(value):
		if maxi(value, 0) == max_events:
			return
		max_events = maxi(value, 0)
		_mark_trace_configuration_changed()
		_trim_to_global_limits()

## 内存事件缓冲总字节预算。会话上下文和有界目录 metadata 不计入该预算。
## 0 表示不保留新事件。
## [br]
## @api public
## [br]
## @since unreleased
var max_event_buffer_bytes: int = DEFAULT_MAX_EVENT_BUFFER_BYTES:
	set(value):
		if maxi(value, 0) == max_event_buffer_bytes:
			return
		max_event_buffer_bytes = maxi(value, 0)
		_mark_trace_configuration_changed()
		_trim_to_global_limits()

## 单个事件字节预算；小于最小安全包络时会提升到最小值。
## [br]
## @api public
## [br]
## @since unreleased
var max_event_bytes: int = DEFAULT_MAX_EVENT_BYTES:
	set(value):
		if maxi(value, _MIN_EVENT_BYTES) == max_event_bytes:
			return
		max_event_bytes = maxi(value, _MIN_EVENT_BYTES)
		_mark_trace_configuration_changed()

## 最多允许注册的通道数量。降低上限不会隐式删除既有通道。
## [br]
## @api public
## [br]
## @since unreleased
var max_channels: int = DEFAULT_MAX_CHANNELS:
	set(value):
		max_channels = maxi(value, 0)

## 最多允许注册的同步快照 provider 数量。降低上限不会隐式删除既有 provider。
## [br]
## @api public
## [br]
## @since unreleased
var max_snapshot_providers: int = DEFAULT_MAX_SNAPSHOT_PROVIDERS:
	set(value):
		max_snapshot_providers = maxi(value, 0)

## 单次会话最多写入 journal 的事件数量。0 表示禁用 journal 写入。
## [br]
## @api public
## [br]
## @since unreleased
var max_journal_events: int = DEFAULT_MAX_JOURNAL_EVENTS:
	set(value):
		max_journal_events = maxi(value, 0)

## 事件载荷与单次 metadata 的报告脱敏 profile。默认使用 privacy，不应为线上玩家数据改成 debug。
## 会话上下文、通道 metadata 和 provider metadata 始终使用 privacy 安全下限。
## [br]
## @api public
## [br]
## @since unreleased
var redaction_profile: String = GFReportValueCodec.REDACTION_PROFILE_PRIVACY:
	set(value):
		if value == redaction_profile:
			return
		redaction_profile = value
		_mark_trace_configuration_changed()


# --- 私有变量 ---

var _channels: Dictionary = {}
var _snapshot_providers: Dictionary = {}
var _events: Array[Dictionary] = []
var _event_sizes: Array[int] = []
var _session_id: StringName = &""
var _session_context: Dictionary = {}
var _stop_reason: StringName = &""
var _active: bool = false
var _started_ticks_usec: int = 0
var _next_sequence: int = 1
var _total_event_bytes: int = 0
var _dropped_event_count: int = 0
var _rejected_event_count: int = 0
var _rejections_by_reason: Dictionary = {}
var _provider_capture_active: bool = false
var _journal_sink: GFLogSink = null
var _journal_shutdown_on_dispose: bool = false
var _journal_flush_after_write: bool = false
var _journal_event_count: int = 0
var _journal_dropped_event_count: int = 0
var _journal_callback_active: bool = false
var _journal_configuration_revision: int = 0
var _pending_journal_cleanup_sink: GFLogSink = null
var _pending_journal_cleanup_shutdown: bool = false
var _configured_recipe_id: StringName = &""
var _configured_recipe_fingerprint: String = ""
var _configured_recipe_runtime_fingerprint: String = ""
var _configured_recipe_runtime_revision: int = 0
var _trace_configuration_revision: int = 0


# --- GF 生命周期方法 ---

## 停止活动会话、刷新 journal 并释放所有注册数据。
## [br]
## @api public
## [br]
## @since unreleased
func dispose() -> void:
	if _active:
		var _stop_summary: Dictionary = stop_session(&"disposed")
	clear_journal_sink(_journal_shutdown_on_dispose)
	clear()
	_channels.clear()
	_snapshot_providers.clear()
	_session_id = &""
	_session_context.clear()
	_stop_reason = &""
	_active = false
	_started_ticks_usec = 0
	_next_sequence = 1
	_provider_capture_active = false
	_journal_event_count = 0
	_journal_dropped_event_count = 0
	_configured_recipe_id = &""
	_configured_recipe_fingerprint = ""
	_configured_recipe_runtime_fingerprint = ""
	_configured_recipe_runtime_revision = 0


# --- 公共方法 ---

## 开始新的会话。已有活动会话会先以 restarted 原因停止。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param requested_session_id: 可选的非敏感本地会话标识；为空时自动生成。该字段不会识别账号、令牌等业务秘密。
## [br]
## @param context: 项目显式提供的会话上下文。
## [br]
## @schema context: Dictionary，由项目定义；进入轨迹前会使用 privacy 安全下限和字节预算编码。
## [br]
## @param options: 可选参数，支持 started_ticks_usec。
## [br]
## @schema options: Dictionary，started_ticks_usec 可用于固定时钟或测试。
## [br]
## @return 实际会话标识。
func start_session(
	requested_session_id: StringName = &"",
	context: Dictionary = {},
	options: Dictionary = {}
) -> StringName:
	if _active:
		var _previous_summary: Dictionary = stop_session(&"restarted")
	clear()

	_session_id = _normalize_id(requested_session_id)
	if _session_id == &"":
		_session_id = _make_session_id()
	_session_context = _sanitize_persistent_dictionary(context, mini(max_event_bytes, 32 * 1024))
	_stop_reason = &""
	_started_ticks_usec = maxi(
		GFVariantData.get_option_int(options, "started_ticks_usec", Time.get_ticks_usec()),
		0
	)
	_next_sequence = 1
	_active = true
	_journal_event_count = 0
	_journal_dropped_event_count = 0
	session_started.emit(_session_id, _session_context.duplicate(true))
	return _session_id


## 停止当前会话并返回不含完整事件载荷的摘要。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param reason: 项目定义的停止原因。
## [br]
## @return 会话摘要。
## [br]
## @schema return: Dictionary，包含 session_id、active、stop_reason、event_count、event_bytes、dropped_event_count、rejected_event_count、journal_event_count 和 journal_dropped_event_count。
func stop_session(reason: StringName = &"completed") -> Dictionary:
	if not _active:
		return _make_summary()
	_stop_reason = _normalize_id(reason)
	if _stop_reason == &"":
		_stop_reason = &"completed"
	_active = false
	flush_journal()
	var summary: Dictionary = _make_summary()
	session_stopped.emit(summary.duplicate(true))
	return summary


## 清空内存事件和计数，但保留通道、provider、journal 与当前会话配置。
## [br]
## @api public
## [br]
## @since unreleased
func clear() -> void:
	_events.clear()
	_event_sizes.clear()
	_total_event_bytes = 0
	_dropped_event_count = 0
	_rejected_event_count = 0
	_rejections_by_reason.clear()


## 原子应用一份 Session Trace 配方。
##
## 默认拒绝覆盖既有同名通道，也拒绝配方未声明的既有通道或在活动会话中改写容量。
## 一个 Utility 生命周期内只接受一份稳定配方；首次应用必须发生在任何会话开始之前，
## 完全相同的配方可幂等重复应用，应用后的完整通道目录漂移会 fail closed。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param recipe: 要应用的配方资源。
## [br]
## @param options: 应用选项。
## [br]
## @schema options: Dictionary with replace_existing_channels: bool.
## [br]
## @return 原子应用报告。
## [br]
## @schema return: Dictionary with ok, recipe_id, fingerprint, applied_channels, reused, error_code, and error_message.
func apply_recipe(
	recipe: GFSessionTraceRecipe,
	options: Dictionary = {}
) -> Dictionary:
	if recipe == null:
		return _make_recipe_result(false, &"", "", &"invalid_recipe", "Session trace recipe is null.")
	var validation: Dictionary = recipe.validate_recipe()
	if not GFVariantData.get_option_bool(validation, "ok", false):
		return _make_recipe_result(
			false,
			recipe.recipe_id,
			"",
			&"invalid_recipe",
			"Session trace recipe validation failed.",
			PackedStringArray(),
			false,
			validation
		)
	var fingerprint: String = recipe.get_fingerprint_for_framework()
	if _configured_recipe_id == recipe.recipe_id:
		if _configured_recipe_fingerprint != fingerprint:
			return _make_recipe_result(
				false,
				recipe.recipe_id,
				fingerprint,
				&"recipe_changed",
				"Session trace recipe changed after it was applied."
			)
		if (
			_trace_configuration_revision != _configured_recipe_runtime_revision
			or _make_recipe_runtime_fingerprint() != _configured_recipe_runtime_fingerprint
		):
			return _make_recipe_result(
				false,
				recipe.recipe_id,
				fingerprint,
				&"recipe_runtime_drift",
				"Session trace runtime configuration drifted from the applied recipe."
			)
		return _make_recipe_result(
			true,
			recipe.recipe_id,
			fingerprint,
			&"",
			"",
			PackedStringArray(),
			true
		)
	if _configured_recipe_id != &"":
		return _make_recipe_result(
			false,
			recipe.recipe_id,
			fingerprint,
			&"recipe_conflict",
			"A different session trace recipe is already configured."
		)
	if _active:
		return _make_recipe_result(
			false,
			recipe.recipe_id,
			fingerprint,
			&"session_active",
			"Session trace recipe cannot be applied during an active session."
		)
	if _session_id != &"" or not _events.is_empty():
		return _make_recipe_result(
			false,
			recipe.recipe_id,
			fingerprint,
			&"trace_not_empty",
			"Session trace recipe must be applied before the first session starts."
		)
	var replace_existing_channels: bool = GFVariantData.get_option_bool(
		options,
		"replace_existing_channels",
		false
	)
	var recipe_channel_ids: Dictionary = {}
	for channel: GFSessionTraceChannelDefinition in recipe.channels:
		recipe_channel_ids[channel.channel_id] = true
	for existing_channel_text: String in _get_sorted_channel_ids():
		var existing_channel_id: StringName = StringName(existing_channel_text)
		if not recipe_channel_ids.has(existing_channel_id):
			return _make_recipe_result(
				false,
				recipe.recipe_id,
				fingerprint,
				&"unmanaged_channel_conflict",
				"Session trace utility contains a channel not declared by the recipe: %s."
				% existing_channel_text
			)
	var new_channel_count: int = 0
	for channel: GFSessionTraceChannelDefinition in recipe.channels:
		if _channels.has(channel.channel_id):
			if not replace_existing_channels:
				return _make_recipe_result(
					false,
					recipe.recipe_id,
					fingerprint,
					&"channel_conflict",
					"Session trace recipe channel already exists: %s." % String(channel.channel_id)
				)
		else:
			new_channel_count += 1
	if _channels.size() + new_channel_count > max_channels:
		return _make_recipe_result(
			false,
			recipe.recipe_id,
			fingerprint,
			&"channel_limit_exceeded",
			"Session trace recipe exceeds the configured channel limit."
		)

	var previous_channels: Dictionary = _channels.duplicate(true)
	var previous_max_events: int = max_events
	var previous_max_event_buffer_bytes: int = max_event_buffer_bytes
	var previous_max_event_bytes: int = max_event_bytes
	var previous_redaction_profile: String = redaction_profile
	max_events = recipe.max_events
	max_event_buffer_bytes = recipe.max_event_buffer_bytes
	max_event_bytes = recipe.max_event_bytes
	redaction_profile = recipe.redaction_profile
	var applied_channels: PackedStringArray = PackedStringArray()
	for channel: GFSessionTraceChannelDefinition in recipe.channels:
		if not register_channel(channel.channel_id, channel.to_channel_options_for_framework()):
			_channels = previous_channels
			max_events = previous_max_events
			max_event_buffer_bytes = previous_max_event_buffer_bytes
			max_event_bytes = previous_max_event_bytes
			redaction_profile = previous_redaction_profile
			return _make_recipe_result(
				false,
				recipe.recipe_id,
				fingerprint,
				&"channel_apply_failed",
				"Session trace recipe channel could not be applied: %s." % String(channel.channel_id)
			)
		var _channel_appended: bool = applied_channels.append(String(channel.channel_id))
	_configured_recipe_id = recipe.recipe_id
	_configured_recipe_fingerprint = fingerprint
	_configured_recipe_runtime_fingerprint = _make_recipe_runtime_fingerprint()
	_configured_recipe_runtime_revision = _trace_configuration_revision
	return _make_recipe_result(
		true,
		recipe.recipe_id,
		fingerprint,
		&"",
		"",
		applied_channels
	)


## 执行配方中的一个显式检查点。
##
## Provider 按声明顺序逐个采集，单个失败不会中断后续项；只有必需 Provider 失败
## 才使检查点整体失败。配方在应用后发生变化时会 fail closed。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param recipe: 已应用且未变化的配方。
## [br]
## @param checkpoint_id: 要执行的检查点 ID。
## [br]
## @param options: 传给每次 Provider capture 的事件选项。
## [br]
## @schema options: Dictionary with ticks_usec, simulation_tick, and metadata.
## [br]
## @return 检查点采集报告。
## [br]
## @schema return: Dictionary with ok, recipe_id, checkpoint_id, success_count, failure_count, required_failure_count, optional_failure_count, and results.
func capture_recipe_checkpoint(
	recipe: GFSessionTraceRecipe,
	checkpoint_id: StringName,
	options: Dictionary = {}
) -> Dictionary:
	var recipe_issue: Dictionary = _get_configured_recipe_issue(recipe)
	if not recipe_issue.is_empty():
		return _make_checkpoint_result(
			false,
			recipe.recipe_id if recipe != null else &"",
			checkpoint_id,
			{},
			GFVariantData.get_option_string_name(recipe_issue, "error_code"),
			GFVariantData.get_option_string(recipe_issue, "error_message")
		)
	var checkpoint: GFSessionTraceCheckpoint = recipe.get_checkpoint(checkpoint_id)
	if checkpoint == null:
		return _make_checkpoint_result(
			false,
			recipe.recipe_id,
			checkpoint_id,
			{},
			&"checkpoint_not_found",
			"Session trace checkpoint was not found."
		)

	var results: Dictionary = {}
	var success_count: int = 0
	var required_failure_count: int = 0
	var optional_failure_count: int = 0
	for provider_text: String in checkpoint.provider_ids:
		var provider_id: StringName = StringName(provider_text)
		var capture_options: Dictionary = _duplicate_dictionary(options)
		var _metadata_removed: bool = capture_options.erase("metadata")
		var event_metadata: Dictionary = _sanitize_dictionary(
			checkpoint.metadata,
			mini(max_event_bytes, 4096)
		)
		var option_metadata: Dictionary = _sanitize_dictionary(
			GFVariantData.as_dictionary(
				GFVariantData.get_option_value(options, "metadata", {})
			),
			mini(max_event_bytes, 4096)
		)
		var _metadata_merge_result: Variant = GFVariantData.merge_metadata(
			event_metadata,
			option_metadata
		)
		event_metadata["recipe_id"] = String(recipe.recipe_id)
		event_metadata["checkpoint_id"] = String(checkpoint_id)
		capture_options["metadata"] = event_metadata
		var capture_result: Dictionary = capture_snapshot_provider(provider_id, capture_options)
		results[provider_id] = capture_result
		if GFVariantData.get_option_bool(capture_result, "ok"):
			success_count += 1
		elif checkpoint.is_provider_optional_for_framework(provider_id):
			optional_failure_count += 1
		else:
			required_failure_count += 1
	return {
		"ok": required_failure_count == 0,
		"recipe_id": recipe.recipe_id,
		"checkpoint_id": checkpoint_id,
		"success_count": success_count,
		"failure_count": required_failure_count + optional_failure_count,
		"required_failure_count": required_failure_count,
		"optional_failure_count": optional_failure_count,
		"error_code": &"checkpoint_required_provider_failed" if required_failure_count > 0 else &"",
		"error_message": "One or more required checkpoint providers failed." if required_failure_count > 0 else "",
		"results": results,
	}


## 使用配方默认值构建轨迹快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param recipe: 已应用且未变化的配方。
## [br]
## @param options: 覆盖配方默认值的 `build_snapshot()` 选项。
## [br]
## @schema options: Dictionary with limit, filters, include_context, include_channel_catalog, and include_provider_catalog.
## [br]
## @return 带配方身份的有界轨迹快照；配方不匹配时返回结构化失败。
## [br]
## @schema return: 成功时为 build_snapshot() 字典并附加 recipe_id 和 recipe_fingerprint；失败时包含 ok=false、error_code 和 error_message。
func build_recipe_snapshot(
	recipe: GFSessionTraceRecipe,
	options: Dictionary = {}
) -> Dictionary:
	var recipe_issue: Dictionary = _get_configured_recipe_issue(recipe)
	if not recipe_issue.is_empty():
		return recipe_issue
	var snapshot_options: Dictionary = recipe.get_snapshot_options_for_framework()
	var _options_merge_result: Variant = GFVariantData.merge_metadata(
		snapshot_options,
		options
	)
	var result: Dictionary = build_snapshot(snapshot_options)
	result["ok"] = true
	result["recipe_id"] = recipe.recipe_id
	result["recipe_fingerprint"] = _configured_recipe_fingerprint
	return result


## 注册一个允许记录的事件通道。未知通道始终 fail closed。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param channel_id: 稳定通道标识。
## [br]
## @param options: 通道选项。
## [br]
## @schema options: Dictionary，可包含 enabled、include_in_snapshot、max_events、max_event_bytes 和 metadata；0 上限表示仅使用全局限制，metadata 始终使用 privacy 安全下限。
## [br]
## @return 注册或更新成功时返回 true。
func register_channel(channel_id: StringName, options: Dictionary = {}) -> bool:
	var normalized_id: StringName = _normalize_id(channel_id)
	if normalized_id == &"":
		return false
	if not _channels.has(normalized_id) and _channels.size() >= max_channels:
		return false

	var next_options: Dictionary = {
		"enabled": GFVariantData.get_option_bool(options, "enabled", true),
		"include_in_snapshot": GFVariantData.get_option_bool(options, "include_in_snapshot", true),
		"max_events": maxi(GFVariantData.get_option_int(options, "max_events", 0), 0),
		"max_event_bytes": maxi(GFVariantData.get_option_int(options, "max_event_bytes", 0), 0),
		"metadata": _sanitize_persistent_dictionary(
			_get_dictionary(options, "metadata"),
			mini(max_event_bytes, 4096)
		),
	}
	if (
		not _channels.has(normalized_id)
		or _get_dictionary(_channels, normalized_id) != next_options
	):
		_mark_trace_configuration_changed()
	_channels[normalized_id] = next_options
	_trim_channel_to_limit(normalized_id)
	return true


## 注销事件通道。既有事件不会被删除。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param channel_id: 通道标识。
## [br]
## @return 通道此前存在时返回 true。
func unregister_channel(channel_id: StringName) -> bool:
	var normalized_id: StringName = _normalize_id(channel_id)
	var provider_ids: PackedStringArray = _get_sorted_provider_ids()
	for provider_text: String in provider_ids:
		var provider_id: StringName = StringName(provider_text)
		var provider_entry: Dictionary = _get_dictionary(_snapshot_providers, provider_id)
		if GFVariantData.get_option_string_name(provider_entry, "channel_id") == normalized_id:
			var _provider_erased: bool = _snapshot_providers.erase(provider_id)
	var removed: bool = _channels.erase(normalized_id)
	if removed:
		_mark_trace_configuration_changed()
	return removed


## 检查通道是否已显式注册。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param channel_id: 通道标识。
## [br]
## @return 已注册时返回 true。
func has_channel(channel_id: StringName) -> bool:
	return _channels.has(_normalize_id(channel_id))


## 启用或禁用已注册通道。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param channel_id: 通道标识。
## [br]
## @param enabled: 新状态。
## [br]
## @return 通道存在并更新成功时返回 true。
func set_channel_enabled(channel_id: StringName, enabled: bool) -> bool:
	var normalized_id: StringName = _normalize_id(channel_id)
	if not _channels.has(normalized_id):
		return false
	var channel_options: Dictionary = _get_dictionary(_channels, normalized_id)
	if GFVariantData.get_option_bool(channel_options, "enabled", true) == enabled:
		return true
	channel_options["enabled"] = enabled
	_channels[normalized_id] = channel_options
	_mark_trace_configuration_changed()
	return true


## 获取不含回调或事件载荷的通道目录。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 以通道 ID 为键的配置副本。
## [br]
## @schema return: Dictionary[StringName, Dictionary]，子字典包含 enabled、include_in_snapshot、max_events、max_event_bytes、event_count 和 metadata。
func get_channel_catalog() -> Dictionary:
	var result: Dictionary = {}
	for channel_text: String in _get_sorted_channel_ids():
		var channel_id: StringName = StringName(channel_text)
		var options: Dictionary = _get_dictionary(_channels, channel_id)
		result[channel_id] = {
			"enabled": GFVariantData.get_option_bool(options, "enabled", true),
			"include_in_snapshot": GFVariantData.get_option_bool(options, "include_in_snapshot", true),
			"max_events": GFVariantData.get_option_int(options, "max_events", 0),
			"max_event_bytes": GFVariantData.get_option_int(options, "max_event_bytes", 0),
			"event_count": _count_channel_events(channel_id),
			"metadata": GFVariantData.get_option_dictionary(options, "metadata").duplicate(true),
		}
	return result


## 记录一个显式通道事件。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param channel_id: 已注册通道标识。
## [br]
## @param event_id: 项目定义的稳定事件标识。
## [br]
## @param payload: 项目显式提供的事件载荷。
## [br]
## @schema payload: Variant，由项目定义；进入轨迹前会按当前 redaction_profile 和单事件字节预算编码为 JSON-safe 值。
## [br]
## @param options: 记录选项。
## [br]
## @schema options: Dictionary，可包含 ticks_usec、simulation_tick 和 metadata；metadata 会与通道 metadata 合并后脱敏。
## [br]
## @return 结构化记录结果。
## [br]
## @schema return: Dictionary，成功时包含 ok、event 和 dropped_event_count；失败时包含 ok=false 与 reason。
func record_event(
	channel_id: StringName,
	event_id: StringName,
	payload: Variant = null,
	options: Dictionary = {}
) -> Dictionary:
	return _record_event_internal(channel_id, event_id, payload, options)


## 注册一个由项目显式触发的同步快照 provider。
## Provider 必须是无参数、快速、同步且不会修改游戏状态的 Callable；GF 不会自动轮询它。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param provider_id: provider 稳定标识。
## [br]
## @param channel_id: provider 结果写入的已注册通道。
## [br]
## @param provider: 无参数同步 Callable。
## [br]
## @param options: provider 选项。
## [br]
## @schema options: Dictionary，可包含 enabled、event_id 和 metadata；metadata 始终使用 privacy 安全下限。
## [br]
## @return 注册或更新成功时返回 true。
func register_snapshot_provider(
	provider_id: StringName,
	channel_id: StringName,
	provider: Callable,
	options: Dictionary = {}
) -> bool:
	var normalized_provider_id: StringName = _normalize_id(provider_id)
	var normalized_channel_id: StringName = _normalize_id(channel_id)
	if normalized_provider_id == &"" or not provider.is_valid() or not has_channel(normalized_channel_id):
		return false
	if not _snapshot_providers.has(normalized_provider_id) and _snapshot_providers.size() >= max_snapshot_providers:
		return false
	var event_id: StringName = _normalize_id(
		GFVariantData.get_option_string_name(options, "event_id", normalized_provider_id)
	)
	if event_id == &"":
		return false
	_snapshot_providers[normalized_provider_id] = {
		"channel_id": normalized_channel_id,
		"event_id": event_id,
		"provider": provider,
		"enabled": GFVariantData.get_option_bool(options, "enabled", true),
		"metadata": _sanitize_persistent_dictionary(
			_get_dictionary(options, "metadata"),
			mini(max_event_bytes, 4096)
		),
	}
	return true


## 注销同步快照 provider。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param provider_id: provider 标识。
## [br]
## @return provider 此前存在时返回 true。
func unregister_snapshot_provider(provider_id: StringName) -> bool:
	return _snapshot_providers.erase(_normalize_id(provider_id))


## 显式调用一个同步快照 provider 并把结果记录为事件。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param provider_id: provider 标识。
## [br]
## @param options: 传给 record_event() 的 ticks_usec、simulation_tick 和附加 metadata。
## [br]
## @schema options: Dictionary，可包含 ticks_usec、simulation_tick 和 metadata。
## [br]
## @return record_event() 结构化结果。
## [br]
## @schema return: Dictionary，成功时包含 ok、event 和 dropped_event_count；失败时包含 ok=false 与 reason。
func capture_snapshot_provider(provider_id: StringName, options: Dictionary = {}) -> Dictionary:
	var normalized_provider_id: StringName = _normalize_id(provider_id)
	var provider_entry: Dictionary = _get_dictionary(_snapshot_providers, normalized_provider_id)
	if provider_entry.is_empty() or not GFVariantData.get_option_bool(provider_entry, "enabled", true):
		return _reject_event(&"", normalized_provider_id, REJECT_INVALID_PROVIDER)
	if _provider_capture_active:
		return _reject_event(
			GFVariantData.get_option_string_name(provider_entry, "channel_id"),
			GFVariantData.get_option_string_name(provider_entry, "event_id"),
			REJECT_PROVIDER_REENTRANT
		)
	var provider: Callable = _get_callable(provider_entry, "provider")
	if not provider.is_valid():
		return _reject_event(&"", normalized_provider_id, REJECT_INVALID_PROVIDER)
	var channel_id: StringName = GFVariantData.get_option_string_name(provider_entry, "channel_id")
	var event_id: StringName = GFVariantData.get_option_string_name(provider_entry, "event_id")
	var rejection_reason: StringName = _get_record_rejection_reason(channel_id, event_id)
	if rejection_reason != &"":
		return _reject_event(channel_id, event_id, rejection_reason)

	_provider_capture_active = true
	var payload: Variant = provider.call()
	_provider_capture_active = false
	var record_options: Dictionary = _duplicate_dictionary(options)
	var _metadata_removed: bool = record_options.erase("metadata")
	var _metadata_name_removed: bool = record_options.erase(&"metadata")
	var metadata: Dictionary = GFVariantData.get_option_dictionary(provider_entry, "metadata").duplicate(true)
	var capture_metadata: Dictionary = _sanitize_dictionary(
		_get_dictionary(options, "metadata"),
		mini(max_event_bytes, 4096)
	)
	var _metadata_merge_result: Variant = GFVariantData.merge_metadata(
		metadata,
		capture_metadata
	)
	metadata["provider_id"] = String(normalized_provider_id)
	return _record_event_internal(
		channel_id,
		event_id,
		payload,
		record_options,
		metadata
	)


## 获取同步快照 provider 目录，不包含 Callable 本身。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 以 provider ID 为键的配置副本。
## [br]
## @schema return: Dictionary[StringName, Dictionary]，子字典包含 channel_id、event_id、enabled 和 metadata。
func get_snapshot_provider_catalog() -> Dictionary:
	var result: Dictionary = {}
	for provider_text: String in _get_sorted_provider_ids():
		var provider_id: StringName = StringName(provider_text)
		var provider_entry: Dictionary = _get_dictionary(_snapshot_providers, provider_id)
		result[provider_id] = {
			"channel_id": GFVariantData.get_option_string_name(provider_entry, "channel_id"),
			"event_id": GFVariantData.get_option_string_name(provider_entry, "event_id"),
			"enabled": GFVariantData.get_option_bool(provider_entry, "enabled", true),
			"metadata": GFVariantData.get_option_dictionary(provider_entry, "metadata").duplicate(true),
		}
	return result


## 配置可选 journal sink。GF 不会默认创建文件或上传边界。
## 当前 redaction_profile 必须不弱于 sink 声明的输出 profile；运行期若被改弱，后续 journal 事件会 fail closed。
## 若使用专用 GFJsonLineLogSink，可通过 options.initialize 与 shutdown_on_dispose 让当前工具拥有其生命周期。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param sink: 接收已脱敏事件的 sink；传入 null 表示清除。
## [br]
## @param options: journal 生命周期选项。
## [br]
## @schema options: Dictionary，可包含 initialize、shutdown_on_dispose 和 flush_after_write。
## [br]
## @return sink 的输出 profile 与当前轨迹 profile 兼容且配置成功，或已成功清除时返回 true。
func configure_journal_sink(sink: GFLogSink, options: Dictionary = {}) -> bool:
	if sink == null:
		clear_journal_sink(_journal_shutdown_on_dispose)
		return true
	if _journal_callback_active:
		return false
	var revision_before_profile: int = _journal_configuration_revision
	_journal_callback_active = true
	var sink_profile: String = _normalize_redaction_profile(sink.get_report_redaction_profile())
	_finish_journal_callback()
	if _journal_configuration_revision != revision_before_profile:
		return false
	if sink_profile.is_empty() or not _is_journal_profile_compatible(sink_profile):
		return false

	if _journal_sink != sink:
		var revision_before_clear: int = _journal_configuration_revision
		clear_journal_sink(_journal_shutdown_on_dispose)
		if _journal_configuration_revision != revision_before_clear + 1:
			return false
	_journal_sink = sink
	_journal_shutdown_on_dispose = GFVariantData.get_option_bool(options, "shutdown_on_dispose", false)
	_journal_flush_after_write = GFVariantData.get_option_bool(options, "flush_after_write", false)
	_journal_configuration_revision += 1
	var configured_revision: int = _journal_configuration_revision
	if GFVariantData.get_option_bool(options, "initialize", false):
		_journal_callback_active = true
		_journal_sink.init(self)
		_finish_journal_callback()
	return _journal_sink == sink and _journal_configuration_revision == configured_revision


## 刷新当前 journal sink。
## [br]
## @api public
## [br]
## @since unreleased
func flush_journal() -> void:
	if _journal_sink == null or _journal_callback_active:
		return
	var sink: GFLogSink = _journal_sink
	_journal_callback_active = true
	sink.flush()
	_finish_journal_callback()


## 清除 journal sink，并可选关闭其资源。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param shutdown: 是否调用 sink.shutdown()。
func clear_journal_sink(shutdown: bool = false) -> void:
	var sink: GFLogSink = _journal_sink
	_journal_sink = null
	_journal_shutdown_on_dispose = false
	_journal_flush_after_write = false
	_journal_configuration_revision += 1
	if sink == null:
		return
	if _journal_callback_active:
		_pending_journal_cleanup_sink = sink
		_pending_journal_cleanup_shutdown = _pending_journal_cleanup_shutdown or shutdown
		return
	_finalize_journal_sink(sink, shutdown)


## 获取过滤后的事件副本。limit 保留最新 N 条并维持时间顺序。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param limit: 最大返回数量；0 表示不限制。
## [br]
## @param filters: 可选过滤器。
## [br]
## @schema filters: Dictionary，可包含 channel_id、event_id、min_sequence、max_sequence 和 include_hidden_channels。
## [br]
## @return 事件副本数组。
## [br]
## @schema return: Array[Dictionary]，元素遵循 event_recorded 的事件 schema。
func get_events(limit: int = 0, filters: Dictionary = {}) -> Array[Dictionary]:
	var matched: Array[Dictionary] = []
	for event: Dictionary in _events:
		if _matches_filters(event, filters):
			matched.append(event.duplicate(true))
	var effective_limit: int = maxi(limit, 0)
	if effective_limit <= 0 or matched.size() <= effective_limit:
		return matched
	var result: Array[Dictionary] = []
	for index: int in range(matched.size() - effective_limit, matched.size()):
		result.append(matched[index])
	return result


## 构建适合诊断快照或支持报告分区的结构化轨迹。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param options: 快照选项。
## [br]
## @schema options: Dictionary，可包含 limit、filters、include_context、include_channel_catalog 和 include_provider_catalog。
## [br]
## @return 有界轨迹快照。
## [br]
## @schema return: Dictionary，包含 schema_version、summary、events，并按选项包含 context、channel_catalog 和 provider_catalog。
func build_snapshot(options: Dictionary = {}) -> Dictionary:
	var filters: Dictionary = GFVariantData.get_option_dictionary(options, "filters")
	var result: Dictionary = {
		"schema_version": _EVENT_SCHEMA_VERSION,
		"summary": _make_summary(),
		"events": get_events(GFVariantData.get_option_int(options, "limit", 0), filters),
	}
	if GFVariantData.get_option_bool(options, "include_context", true):
		result["context"] = _session_context.duplicate(true)
	if GFVariantData.get_option_bool(options, "include_channel_catalog", false):
		result["channel_catalog"] = get_channel_catalog()
	if GFVariantData.get_option_bool(options, "include_provider_catalog", false):
		result["provider_catalog"] = get_snapshot_provider_catalog()
	return result


## 获取不含完整事件载荷的调试快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前容量、计数、配方和 journal 状态。
## [br]
## @schema return: Dictionary，包含 summary、channel_count、provider_count、configured_recipe_id、configured_recipe_fingerprint、max_events、max_event_buffer_bytes、max_event_bytes、max_journal_events、journal_configured 和 rejections_by_reason。
func get_debug_snapshot() -> Dictionary:
	return {
		"summary": _make_summary(),
		"channel_count": _channels.size(),
		"provider_count": _snapshot_providers.size(),
		"configured_recipe_id": _configured_recipe_id,
		"configured_recipe_fingerprint": _configured_recipe_fingerprint,
		"max_events": max_events,
		"max_event_buffer_bytes": max_event_buffer_bytes,
		"max_event_bytes": max_event_bytes,
		"max_journal_events": max_journal_events,
		"journal_configured": _journal_sink != null,
		"rejections_by_reason": _rejections_by_reason.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _make_recipe_result(
	ok: bool,
	recipe_id: StringName,
	fingerprint: String,
	error_code: StringName,
	error_message: String,
	applied_channels: PackedStringArray = PackedStringArray(),
	reused: bool = false,
	validation: Dictionary = {}
) -> Dictionary:
	return {
		"ok": ok,
		"recipe_id": recipe_id,
		"fingerprint": fingerprint,
		"applied_channels": applied_channels.duplicate(),
		"reused": reused,
		"error_code": error_code,
		"error_message": error_message,
		"validation": validation.duplicate(true),
	}


func _get_configured_recipe_issue(recipe: GFSessionTraceRecipe) -> Dictionary:
	if recipe == null:
		return {
			"ok": false,
			"error_code": &"invalid_recipe",
			"error_message": "Session trace recipe is null.",
		}
	var validation: Dictionary = recipe.validate_recipe()
	if not GFVariantData.get_option_bool(validation, "ok", false):
		return {
			"ok": false,
			"recipe_id": recipe.recipe_id,
			"error_code": &"invalid_recipe",
			"error_message": "Session trace recipe validation failed.",
			"validation": validation,
		}
	if _configured_recipe_id != recipe.recipe_id:
		return {
			"ok": false,
			"recipe_id": recipe.recipe_id,
			"error_code": &"recipe_not_configured",
			"error_message": "Session trace recipe is not configured on this utility.",
		}
	var current_fingerprint: String = recipe.get_fingerprint_for_framework()
	if current_fingerprint != _configured_recipe_fingerprint:
		return {
			"ok": false,
			"recipe_id": recipe.recipe_id,
			"error_code": &"recipe_changed",
			"error_message": "Session trace recipe changed after it was applied.",
		}
	if (
		_trace_configuration_revision != _configured_recipe_runtime_revision
		or _make_recipe_runtime_fingerprint() != _configured_recipe_runtime_fingerprint
	):
		return {
			"ok": false,
			"recipe_id": recipe.recipe_id,
			"error_code": &"recipe_runtime_drift",
			"error_message": "Session trace runtime configuration drifted from the applied recipe.",
		}
	return {}


func _make_checkpoint_result(
	ok: bool,
	recipe_id: StringName,
	checkpoint_id: StringName,
	results: Dictionary,
	error_code: StringName,
	error_message: String
) -> Dictionary:
	return {
		"ok": ok,
		"recipe_id": recipe_id,
		"checkpoint_id": checkpoint_id,
		"success_count": 0,
		"failure_count": 0,
		"required_failure_count": 0,
		"optional_failure_count": 0,
		"error_code": error_code,
		"error_message": error_message,
		"results": results.duplicate(true),
	}


func _make_recipe_runtime_fingerprint() -> String:
	var channel_records: Array[Dictionary] = []
	for channel_text: String in _get_sorted_channel_ids():
		var channel_id: StringName = StringName(channel_text)
		var channel_options: Dictionary = _get_dictionary(_channels, channel_id)
		channel_records.append({
			"channel_id": channel_text,
			"options": channel_options.duplicate(true),
		})
	var runtime_record: Dictionary = {
		"max_events": max_events,
		"max_event_buffer_bytes": max_event_buffer_bytes,
		"max_event_bytes": max_event_bytes,
		"redaction_profile": redaction_profile,
		"channels": channel_records,
	}
	return JSON.stringify(runtime_record, "", true).sha256_text()


func _mark_trace_configuration_changed() -> void:
	_trace_configuration_revision += 1


func _record_event_internal(
	channel_id: StringName,
	event_id: StringName,
	payload: Variant,
	options: Dictionary,
	presanitized_metadata: Dictionary = {}
) -> Dictionary:
	var normalized_channel_id: StringName = _normalize_id(channel_id)
	var normalized_event_id: StringName = _normalize_id(event_id)
	var rejection_reason: StringName = _get_record_rejection_reason(
		normalized_channel_id,
		normalized_event_id
	)
	if rejection_reason != &"":
		return _reject_event(normalized_channel_id, normalized_event_id, rejection_reason)

	var channel_options: Dictionary = _get_dictionary(_channels, normalized_channel_id)
	var event_budget: int = _get_event_budget(channel_options)
	var ticks_usec: int = maxi(
		GFVariantData.get_option_int(options, "ticks_usec", Time.get_ticks_usec()),
		0
	)
	var payload_budget: int = maxi(event_budget - _PAYLOAD_ENVELOPE_RESERVE_BYTES, 0)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(channel_options, "metadata").duplicate(true)
	var option_metadata: Dictionary = _sanitize_dictionary(
		_get_dictionary(options, "metadata"),
		mini(payload_budget, 4096)
	)
	var _metadata_merge_result: Variant = GFVariantData.merge_metadata(metadata, option_metadata)
	var _presanitized_merge_result: Variant = GFVariantData.merge_metadata(
		metadata,
		presanitized_metadata
	)
	var event: Dictionary = {
		"schema_version": _EVENT_SCHEMA_VERSION,
		"session_id": _session_id,
		"sequence": _next_sequence,
		"elapsed_usec": maxi(ticks_usec - _started_ticks_usec, 0),
		"simulation_tick": GFVariantData.get_option_int(options, "simulation_tick", -1),
		"channel_id": normalized_channel_id,
		"event_id": normalized_event_id,
		"include_in_snapshot": GFVariantData.get_option_bool(
			channel_options,
			"include_in_snapshot",
			true
		),
		"payload": _sanitize_value(payload, payload_budget),
		"metadata": metadata,
	}
	var event_size: int = JSON.stringify(event).to_utf8_buffer().size()
	if event_size > event_budget or event_size > max_event_buffer_bytes:
		return _reject_event(normalized_channel_id, normalized_event_id, REJECT_EVENT_TOO_LARGE)

	_trim_channel_before_append(
		normalized_channel_id,
		GFVariantData.get_option_int(channel_options, "max_events", 0)
	)
	_trim_before_append(event_size)
	_events.append(event)
	_event_sizes.append(event_size)
	_total_event_bytes += event_size
	_next_sequence += 1
	_write_journal_event(event)
	event_recorded.emit(event.duplicate(true))
	return {
		"ok": true,
		"event": event.duplicate(true),
		"dropped_event_count": _dropped_event_count,
	}


func _get_record_rejection_reason(
	channel_id: StringName,
	event_id: StringName
) -> StringName:
	if not _active:
		return REJECT_SESSION_INACTIVE
	if event_id == &"":
		return REJECT_INVALID_EVENT_ID
	if not _channels.has(channel_id):
		return REJECT_UNKNOWN_CHANNEL
	var channel_options: Dictionary = _get_dictionary(_channels, channel_id)
	if not GFVariantData.get_option_bool(channel_options, "enabled", true):
		return REJECT_CHANNEL_DISABLED
	var event_budget: int = _get_event_budget(channel_options)
	if (
		max_events <= 0
		or max_event_buffer_bytes <= 0
		or event_budget < _MIN_EVENT_BYTES
	):
		return REJECT_EVENT_TOO_LARGE
	return &""


func _reject_event(
	channel_id: StringName,
	event_id: StringName,
	reason: StringName
) -> Dictionary:
	_rejected_event_count += 1
	_rejections_by_reason[reason] = GFVariantData.get_option_int(_rejections_by_reason, reason, 0) + 1
	event_rejected.emit(channel_id, event_id, reason)
	return {
		"ok": false,
		"reason": reason,
	}


func _sanitize_dictionary(value: Dictionary, byte_budget: int) -> Dictionary:
	var sanitized: Variant = _sanitize_value(value, byte_budget)
	if sanitized is Dictionary:
		var dictionary_value: Dictionary = sanitized
		return dictionary_value
	return {}


func _sanitize_persistent_dictionary(value: Dictionary, byte_budget: int) -> Dictionary:
	var sanitized: Variant = _sanitize_value_with_profile(
		value,
		byte_budget,
		GFReportValueCodec.REDACTION_PROFILE_PRIVACY
	)
	if sanitized is Dictionary:
		var dictionary_value: Dictionary = sanitized
		return dictionary_value
	return {}


func _sanitize_value(value: Variant, byte_budget: int) -> Variant:
	return _sanitize_value_with_profile(value, byte_budget, _resolve_redaction_profile())


func _sanitize_value_with_profile(
	value: Variant,
	byte_budget: int,
	profile: String
) -> Variant:
	var options: Dictionary = GFReportValueCodec.make_redaction_options(
		profile,
		{
			"max_depth": 12,
			"max_string_length": 2048,
			"max_collection_items": 128,
			"max_packed_length": 256,
			"max_total_nodes": 2048,
			"max_total_bytes": maxi(byte_budget, 0),
		}
	)
	return GFReportValueCodec.to_json_compatible(value, options)


func _resolve_redaction_profile() -> String:
	if (
		redaction_profile == GFReportValueCodec.REDACTION_PROFILE_DEBUG
		or redaction_profile == GFReportValueCodec.REDACTION_PROFILE_SUPPORT
		or redaction_profile == GFReportValueCodec.REDACTION_PROFILE_PUBLIC
		or redaction_profile == GFReportValueCodec.REDACTION_PROFILE_PRIVACY
	):
		return redaction_profile
	return GFReportValueCodec.REDACTION_PROFILE_PRIVACY


func _get_event_budget(channel_options: Dictionary) -> int:
	var channel_budget: int = GFVariantData.get_option_int(channel_options, "max_event_bytes", 0)
	if channel_budget <= 0:
		return max_event_bytes
	return mini(max_event_bytes, maxi(channel_budget, _MIN_EVENT_BYTES))


func _trim_channel_before_append(channel_id: StringName, channel_limit: int) -> void:
	if channel_limit <= 0:
		return
	while _count_channel_events(channel_id) >= channel_limit:
		var index: int = _find_first_channel_event(channel_id)
		if index < 0:
			return
		_remove_event_at(index, true)


func _trim_channel_to_limit(channel_id: StringName) -> void:
	var options: Dictionary = _get_dictionary(_channels, channel_id)
	var channel_limit: int = GFVariantData.get_option_int(options, "max_events", 0)
	if channel_limit <= 0:
		return
	while _count_channel_events(channel_id) > channel_limit:
		var index: int = _find_first_channel_event(channel_id)
		if index < 0:
			return
		_remove_event_at(index, true)


func _trim_before_append(event_size: int) -> void:
	while not _events.is_empty() and (
		_events.size() >= max_events
		or _total_event_bytes + event_size > max_event_buffer_bytes
	):
		_remove_event_at(0, true)


func _trim_to_global_limits() -> void:
	while not _events.is_empty() and (
		_events.size() > max_events
		or _total_event_bytes > max_event_buffer_bytes
	):
		_remove_event_at(0, true)


func _remove_event_at(index: int, count_as_dropped: bool) -> void:
	if index < 0 or index >= _events.size() or index >= _event_sizes.size():
		return
	_total_event_bytes = maxi(_total_event_bytes - _event_sizes[index], 0)
	_events.remove_at(index)
	_event_sizes.remove_at(index)
	if count_as_dropped:
		_dropped_event_count += 1


func _count_channel_events(channel_id: StringName) -> int:
	var count: int = 0
	for event: Dictionary in _events:
		if GFVariantData.get_option_string_name(event, "channel_id") == channel_id:
			count += 1
	return count


func _find_first_channel_event(channel_id: StringName) -> int:
	for index: int in range(_events.size()):
		if GFVariantData.get_option_string_name(_events[index], "channel_id") == channel_id:
			return index
	return -1


func _write_journal_event(event: Dictionary) -> void:
	if _journal_callback_active:
		_journal_dropped_event_count += 1
		return
	if _journal_sink == null:
		return
	if max_journal_events <= 0 or _journal_event_count >= max_journal_events:
		_journal_dropped_event_count += 1
		return
	var sink: GFLogSink = _journal_sink
	_journal_callback_active = true
	var sink_profile: String = _normalize_redaction_profile(sink.get_report_redaction_profile())
	if (
		_journal_sink != sink
		or sink_profile.is_empty()
		or not _is_journal_profile_compatible(sink_profile)
	):
		_journal_dropped_event_count += 1
		_finish_journal_callback()
		return
	_journal_event_count += 1
	sink.write({
		"schema_version": _EVENT_SCHEMA_VERSION,
		"kind": &"session_trace_event",
		"event": event.duplicate(true),
	})
	if _journal_sink == sink and _journal_flush_after_write:
		sink.flush()
	_finish_journal_callback()


func _finish_journal_callback() -> void:
	_journal_callback_active = false
	if _pending_journal_cleanup_sink == null:
		return
	var pending_sink: GFLogSink = _pending_journal_cleanup_sink
	var pending_shutdown: bool = _pending_journal_cleanup_shutdown
	_pending_journal_cleanup_sink = null
	_pending_journal_cleanup_shutdown = false
	_finalize_journal_sink(pending_sink, pending_shutdown)


func _finalize_journal_sink(sink: GFLogSink, shutdown: bool) -> void:
	if sink == null:
		return
	_journal_callback_active = true
	sink.flush()
	if shutdown:
		sink.shutdown()
	_finish_journal_callback()


func _normalize_redaction_profile(profile: String) -> String:
	if _get_redaction_profile_rank(profile) < 0:
		return ""
	return profile


func _get_redaction_profile_rank(profile: String) -> int:
	return GFVariantData.get_option_int(_REDACTION_PROFILE_RANKS, profile, -1)


func _is_journal_profile_compatible(sink_profile: String) -> bool:
	var trace_rank: int = _get_redaction_profile_rank(_resolve_redaction_profile())
	var sink_rank: int = _get_redaction_profile_rank(sink_profile)
	return trace_rank >= 0 and sink_rank >= 0 and trace_rank >= sink_rank


func _matches_filters(event: Dictionary, filters: Dictionary) -> bool:
	var channel_filter: StringName = GFVariantData.get_option_string_name(filters, "channel_id")
	if channel_filter != &"" and GFVariantData.get_option_string_name(event, "channel_id") != channel_filter:
		return false
	var event_filter: StringName = GFVariantData.get_option_string_name(filters, "event_id")
	if event_filter != &"" and GFVariantData.get_option_string_name(event, "event_id") != event_filter:
		return false
	var sequence: int = GFVariantData.get_option_int(event, "sequence", 0)
	var min_sequence: int = GFVariantData.get_option_int(filters, "min_sequence", 0)
	if min_sequence > 0 and sequence < min_sequence:
		return false
	var max_sequence: int = GFVariantData.get_option_int(filters, "max_sequence", 0)
	if max_sequence > 0 and sequence > max_sequence:
		return false
	if (
		not GFVariantData.get_option_bool(filters, "include_hidden_channels", false)
		and not GFVariantData.get_option_bool(event, "include_in_snapshot", true)
	):
		return false
	return true


func _make_summary() -> Dictionary:
	return {
		"session_id": _session_id,
		"active": _active,
		"stop_reason": _stop_reason,
		"event_count": _events.size(),
		"event_bytes": _total_event_bytes,
		"dropped_event_count": _dropped_event_count,
		"rejected_event_count": _rejected_event_count,
		"journal_event_count": _journal_event_count,
		"journal_dropped_event_count": _journal_dropped_event_count,
	}


func _get_sorted_channel_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in _channels.keys():
		var channel_id: StringName = GFVariantData.to_string_name(key)
		if channel_id != &"":
			var _appended: bool = result.append(String(channel_id))
	result.sort()
	return result


func _get_sorted_provider_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in _snapshot_providers.keys():
		var provider_id: StringName = GFVariantData.to_string_name(key)
		if provider_id != &"":
			var _appended: bool = result.append(String(provider_id))
	result.sort()
	return result


func _get_dictionary(source: Dictionary, key: Variant) -> Dictionary:
	var value: Variant = GFVariantData.get_option_value(source, key)
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value
	return {}


func _duplicate_dictionary(value: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.duplicate_variant(value))


func _get_callable(source: Dictionary, key: Variant) -> Callable:
	var value: Variant = source.get(key)
	if value is Callable:
		var callable_value: Callable = value
		return callable_value
	return Callable()


func _normalize_id(value: StringName) -> StringName:
	var text: String = String(value).strip_edges()
	if text.length() > _MAX_ID_LENGTH:
		return &""
	return StringName(text)


func _make_session_id() -> StringName:
	return StringName("session_%d_%d" % [Time.get_ticks_usec(), get_instance_id()])
