extends GutTest


# --- 测试方法 ---

func test_session_trace_requires_explicit_channel_and_active_session() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	var inactive: Dictionary = trace.record_event(&"input", &"pressed")
	assert_eq(
		GFVariantData.get_option_string_name(inactive, "reason"),
		GFSessionTraceUtility.REJECT_SESSION_INACTIVE,
		"未开始会话时应拒绝事件。"
	)

	var _session_id: StringName = trace.start_session(&"session-a", {}, { "started_ticks_usec": 100 })
	var unknown: Dictionary = trace.record_event(&"input", &"pressed")
	assert_eq(
		GFVariantData.get_option_string_name(unknown, "reason"),
		GFSessionTraceUtility.REJECT_UNKNOWN_CHANNEL,
		"未注册通道应 fail closed。"
	)

	assert_true(trace.register_channel(&"input"), "显式通道应注册成功。")
	var recorded: Dictionary = trace.record_event(
		&"input",
		&"pressed",
		{ "action": &"jump" },
		{ "ticks_usec": 125, "simulation_tick": 4 }
	)
	var event: Dictionary = GFVariantData.get_option_dictionary(recorded, "event")

	assert_true(GFVariantData.get_option_bool(recorded, "ok"), "注册通道应允许记录。")
	assert_eq(GFVariantData.get_option_int(event, "elapsed_usec"), 25, "事件应记录相对会话时钟。")
	assert_eq(GFVariantData.get_option_int(event, "simulation_tick"), 4, "事件应保留显式模拟 tick。")
	assert_eq(GFVariantData.get_option_string_name(event, "channel_id"), &"input", "事件应保留通道标识。")


func test_session_trace_trims_by_global_and_channel_limits() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	trace.max_events = 3
	assert_true(trace.register_channel(&"route", { "max_events": 2 }), "路由通道应注册成功。")
	var _session_id: StringName = trace.start_session(&"session-b", {}, { "started_ticks_usec": 0 })

	var _first: Dictionary = trace.record_event(&"route", &"opened", 1, { "ticks_usec": 10 })
	var _second: Dictionary = trace.record_event(&"route", &"opened", 2, { "ticks_usec": 20 })
	var _third: Dictionary = trace.record_event(&"route", &"opened", 3, { "ticks_usec": 30 })
	var events: Array[Dictionary] = trace.get_events()
	var snapshot: Dictionary = trace.get_debug_snapshot()
	var summary: Dictionary = GFVariantData.get_option_dictionary(snapshot, "summary")

	assert_eq(events.size(), 2, "通道上限应只保留最近两条事件。")
	assert_eq(GFVariantData.get_option_int(events[0], "sequence"), 2, "丢弃旧事件后序列不应重排。")
	assert_eq(GFVariantData.get_option_int(events[1], "sequence"), 3, "最新事件序列应保持单调。")
	assert_eq(GFVariantData.get_option_int(summary, "dropped_event_count"), 1, "容量淘汰应进入 dropped 计数。")


func test_session_trace_applies_privacy_redaction_before_storage() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	assert_true(trace.register_channel(&"state"), "状态通道应注册成功。")
	var _session_id: StringName = trace.start_session(&"session-c")
	var recorded: Dictionary = trace.record_event(&"state", &"snapshot", {
		"owner": self,
		"path": "res://private/player_state.json",
	})
	var event: Dictionary = GFVariantData.get_option_dictionary(recorded, "event")
	var payload: Dictionary = GFVariantData.get_option_dictionary(event, "payload")
	var owner_value: Dictionary = GFVariantData.get_option_dictionary(payload, "owner")
	var owner_marker: Dictionary = GFVariantData.get_option_dictionary(owner_value, "__gf_report_value__")

	assert_true(GFVariantData.get_option_bool(owner_marker, "redacted"), "运行时对象应在进入内存前脱敏。")
	assert_eq(GFVariantData.get_option_string(payload, "path"), "<redacted_path>", "资源路径默认应脱敏。")
	assert_false(JSON.stringify(event).contains("player_state.json"), "轨迹中不应残留原始私有路径。")


func test_session_trace_persistent_metadata_uses_privacy_floor() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	trace.redaction_profile = GFReportValueCodec.REDACTION_PROFILE_DEBUG
	assert_true(
		trace.register_channel(
			&"state",
			{
				"metadata": {
					"channel_owner": self,
					"channel_path": "res://private/channel_metadata.json",
				},
			}
		),
		"带 metadata 的通道应注册成功。"
	)
	assert_true(
		trace.register_snapshot_provider(
			&"state_provider",
			&"state",
			func() -> Dictionary:
				return { "value": 1 },
			{
				"metadata": {
					"provider_owner": self,
					"provider_path": "res://private/provider_metadata.json",
				},
			}
		),
		"带 metadata 的 provider 应注册成功。"
	)

	var _session_id: StringName = trace.start_session(
		&"metadata-profile",
		{
			"session_owner": self,
			"session_path": "res://private/session_context.json",
		}
	)
	trace.redaction_profile = GFReportValueCodec.REDACTION_PROFILE_PRIVACY
	var direct: Dictionary = trace.record_event(&"state", &"direct")
	var captured: Dictionary = trace.capture_snapshot_provider(&"state_provider")
	var context: Dictionary = GFVariantData.get_option_dictionary(trace.build_snapshot(), "context")
	var direct_event: Dictionary = GFVariantData.get_option_dictionary(direct, "event")
	var captured_event: Dictionary = GFVariantData.get_option_dictionary(captured, "event")
	var direct_metadata: Dictionary = GFVariantData.get_option_dictionary(direct_event, "metadata")
	var captured_metadata: Dictionary = GFVariantData.get_option_dictionary(captured_event, "metadata")
	var channel_owner: Dictionary = GFVariantData.get_option_dictionary(direct_metadata, "channel_owner")
	var channel_marker: Dictionary = GFVariantData.get_option_dictionary(
		channel_owner,
		"__gf_report_value__"
	)
	var provider_owner: Dictionary = GFVariantData.get_option_dictionary(
		captured_metadata,
		"provider_owner"
	)
	var provider_marker: Dictionary = GFVariantData.get_option_dictionary(
		provider_owner,
		"__gf_report_value__"
	)
	var session_owner: Dictionary = GFVariantData.get_option_dictionary(context, "session_owner")
	var session_marker: Dictionary = GFVariantData.get_option_dictionary(
		session_owner,
		"__gf_report_value__"
	)

	assert_false(session_marker.has("instance_id"), "长期 session context 不应保留对象实例 ID。")
	assert_false(session_marker.has("node_name"), "长期 session context 不应保留节点名称。")
	assert_false(channel_marker.has("instance_id"), "长期通道 metadata 不应保留对象实例 ID。")
	assert_false(channel_marker.has("node_name"), "长期通道 metadata 不应保留节点名称。")
	assert_false(provider_marker.has("instance_id"), "长期 provider metadata 不应保留对象实例 ID。")
	assert_false(provider_marker.has("node_name"), "长期 provider metadata 不应保留节点名称。")
	assert_eq(
		GFVariantData.get_option_string(context, "session_path"),
		"<redacted_path>",
		"长期 session context 应始终使用 privacy 路径脱敏。"
	)
	assert_eq(
		GFVariantData.get_option_string(direct_metadata, "channel_path"),
		"<redacted_path>",
		"长期通道 metadata 应始终使用 privacy 路径脱敏。"
	)
	assert_eq(
		GFVariantData.get_option_string(captured_metadata, "provider_path"),
		"<redacted_path>",
		"长期 provider metadata 应始终使用 privacy 路径脱敏。"
	)


func test_session_trace_snapshot_provider_is_explicit_and_bounded() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	assert_true(trace.register_channel(&"model"), "模型通道应注册成功。")
	var _session_id: StringName = trace.start_session(&"session-d")
	assert_true(
		trace.register_snapshot_provider(
			&"player_model",
			&"model",
			func() -> Dictionary:
				return { "health": 7 },
			{ "event_id": &"checkpoint", "metadata": { "scope": &"player" } }
		),
		"同步 provider 应显式注册。"
	)

	var result: Dictionary = trace.capture_snapshot_provider(
		&"player_model",
		{ "simulation_tick": 9 }
	)
	var event: Dictionary = GFVariantData.get_option_dictionary(result, "event")
	var payload: Dictionary = GFVariantData.get_option_dictionary(event, "payload")
	var metadata: Dictionary = GFVariantData.get_option_dictionary(event, "metadata")

	assert_true(GFVariantData.get_option_bool(result, "ok"), "显式 capture 应记录 provider 结果。")
	assert_eq(GFVariantData.get_option_int(payload, "health"), 7, "provider 载荷应进入事件。")
	assert_eq(GFVariantData.get_option_string(metadata, "provider_id"), "player_model", "事件应标明 provider 来源。")
	assert_eq(
		_get_variant_marker_value(metadata, "scope"),
		"player",
		"provider metadata 应保留且只编码一次。"
	)


func test_session_trace_hidden_channels_require_explicit_snapshot_override() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	assert_true(
		trace.register_channel(&"private", { "include_in_snapshot": false }),
		"隐藏通道应注册成功。"
	)
	var _session_id: StringName = trace.start_session(&"session-e")
	var _recorded: Dictionary = trace.record_event(&"private", &"internal", { "value": 1 })

	assert_eq(trace.get_events().size(), 0, "默认快照不应包含隐藏通道。")
	assert_eq(
		trace.get_events(0, { "include_hidden_channels": true }).size(),
		1,
		"调用方必须显式请求隐藏通道。"
	)
	assert_true(trace.unregister_channel(&"private"), "隐藏通道应可注销。")
	assert_eq(trace.get_events().size(), 0, "注销通道不能改变历史事件的快照可见性。")
	assert_true(trace.register_channel(&"private"), "同 ID 通道应可重新注册为可见。")
	var _visible_recorded: Dictionary = trace.record_event(&"private", &"visible", { "value": 2 })
	assert_eq(trace.get_events().size(), 1, "重新注册后只有新事件应按新可见性进入默认快照。")
	assert_eq(
		trace.get_events(0, { "include_hidden_channels": true }).size(),
		2,
		"显式读取隐藏通道时应同时保留历史事件。"
	)


func test_session_trace_provider_preflight_does_not_call_when_recording_is_rejected() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	var call_count: Array[int] = [0]
	var provider: Callable = func() -> Dictionary:
		call_count[0] += 1
		return { "value": 1 }
	assert_true(trace.register_channel(&"model"), "模型通道应注册成功。")
	assert_true(
		trace.register_snapshot_provider(&"model", &"model", provider),
		"provider 应注册成功。"
	)

	var inactive: Dictionary = trace.capture_snapshot_provider(&"model")
	assert_eq(
		GFVariantData.get_option_string_name(inactive, "reason"),
		GFSessionTraceUtility.REJECT_SESSION_INACTIVE,
		"非活动会话应在调用 provider 前拒绝。"
	)
	var _session_id: StringName = trace.start_session(&"provider-preflight")
	assert_true(trace.set_channel_enabled(&"model", false), "模型通道应可禁用。")
	var disabled: Dictionary = trace.capture_snapshot_provider(&"model")
	assert_eq(
		GFVariantData.get_option_string_name(disabled, "reason"),
		GFSessionTraceUtility.REJECT_CHANNEL_DISABLED,
		"禁用通道应在调用 provider 前拒绝。"
	)
	assert_eq(call_count[0], 0, "被拒绝的 capture 不应执行项目回调。")


func test_session_trace_forwards_only_bounded_events_to_journal_sink() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	var sink: MemoryJournalSink = MemoryJournalSink.new()
	trace.max_journal_events = 1
	assert_true(
		trace.configure_journal_sink(sink, { "flush_after_write": true }),
		"内存 journal sink 应配置成功。"
	)
	assert_true(trace.register_channel(&"route"), "路由通道应注册成功。")
	var _session_id: StringName = trace.start_session(&"session-f")
	var _first: Dictionary = trace.record_event(&"route", &"opened", &"home")
	var _second: Dictionary = trace.record_event(&"route", &"opened", &"settings")
	var snapshot: Dictionary = trace.get_debug_snapshot()
	var summary: Dictionary = GFVariantData.get_option_dictionary(snapshot, "summary")

	assert_eq(sink.entries.size(), 1, "journal 应遵守单会话写入上限。")
	assert_eq(sink.flush_count, 1, "逐条 flush 选项应立即刷新。")
	assert_eq(GFVariantData.get_option_int(summary, "journal_event_count"), 1, "成功 journal 写入应计数。")
	assert_eq(GFVariantData.get_option_int(summary, "journal_dropped_event_count"), 1, "超出 journal 上限应计入丢弃数。")


func test_session_trace_reconfigures_same_journal_sink_without_shutdown() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	var sink: StatefulJournalSink = StatefulJournalSink.new()
	assert_true(
		trace.configure_journal_sink(
			sink,
			{
				"initialize": true,
				"shutdown_on_dispose": true,
			}
		),
		"有状态 journal sink 应完成首次配置。"
	)
	assert_true(
		trace.configure_journal_sink(
			sink,
			{
				"shutdown_on_dispose": true,
				"flush_after_write": true,
			}
		),
		"同一 sink 应能原位更新生命周期选项。"
	)
	assert_eq(sink.init_count, 1, "未请求 initialize 时不应重复初始化同一 sink。")
	assert_eq(sink.flush_count, 0, "原位重配不应提前刷新同一 sink。")
	assert_eq(sink.shutdown_count, 0, "原位重配不应关闭仍在使用的 sink。")

	assert_true(trace.register_channel(&"route"), "路由通道应注册成功。")
	var _session_id: StringName = trace.start_session(&"journal-reconfigure")
	var _recorded: Dictionary = trace.record_event(&"route", &"opened")
	assert_eq(sink.entries.size(), 1, "原位重配后 sink 仍应保持可写。")
	assert_eq(sink.flush_count, 1, "更新后的逐条 flush 选项应生效。")
	trace.dispose()
	assert_eq(sink.shutdown_count, 1, "最终 dispose 应按更新后的所有权关闭 sink 一次。")


func test_session_trace_stop_and_snapshot_expose_structured_summary() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	assert_true(trace.register_channel(&"save"), "存档通道应注册成功。")
	var _session_id: StringName = trace.start_session(
		&"session-g",
		{ "build": "test" },
		{ "started_ticks_usec": 50 }
	)
	var _recorded: Dictionary = trace.record_event(&"save", &"completed", {}, { "ticks_usec": 80 })
	var stopped: Dictionary = trace.stop_session(&"quit")
	var snapshot: Dictionary = trace.build_snapshot({ "include_channel_catalog": true })
	var context: Dictionary = GFVariantData.get_option_dictionary(snapshot, "context")
	var summary: Dictionary = GFVariantData.get_option_dictionary(snapshot, "summary")

	assert_false(GFVariantData.get_option_bool(stopped, "active", true), "停止摘要应标明会话已结束。")
	assert_eq(GFVariantData.get_option_string_name(stopped, "stop_reason"), &"quit", "停止摘要应保留原因。")
	assert_eq(GFVariantData.get_option_string(context, "build"), "test", "快照应包含已脱敏上下文。")
	assert_eq(GFVariantData.get_option_int(summary, "event_count"), 1, "快照摘要应包含事件数量。")
	assert_true(snapshot.has("channel_catalog"), "显式选项应包含通道目录。")


func test_session_trace_clear_preserves_sequence_and_stop_is_idempotent() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	assert_true(trace.register_channel(&"route"), "路由通道应注册成功。")
	var _session_id: StringName = trace.start_session(&"sequence", {}, { "started_ticks_usec": 0 })
	var _first: Dictionary = trace.record_event(&"route", &"first", {}, { "ticks_usec": 1 })
	trace.clear()
	var second: Dictionary = trace.record_event(&"route", &"second", {}, { "ticks_usec": 2 })
	var event: Dictionary = GFVariantData.get_option_dictionary(second, "event")

	assert_eq(GFVariantData.get_option_int(event, "sequence"), 2, "活动会话 clear 后序号仍应单调。")
	var first_stop: Dictionary = trace.stop_session(&"quit")
	var second_stop: Dictionary = trace.stop_session(&"ignored")
	assert_eq(GFVariantData.get_option_string_name(first_stop, "stop_reason"), &"quit", "首次停止原因应保留。")
	assert_eq(
		GFVariantData.get_option_string_name(second_stop, "stop_reason"),
		&"quit",
		"重复停止不应覆盖既有终态。"
	)


func test_session_trace_rejects_overlong_channel_aliases_and_disabled_buffer() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	var allowed_id: StringName = StringName("x".repeat(128))
	var overlong_id: StringName = StringName("x".repeat(129))
	assert_true(trace.register_channel(allowed_id), "边界长度 ID 应可注册。")
	assert_false(trace.register_channel(overlong_id), "超长 ID 应 fail closed，而不是静默截断。")
	var _session_id: StringName = trace.start_session(&"id-boundary")
	var aliased: Dictionary = trace.record_event(overlong_id, &"event")
	assert_eq(
		GFVariantData.get_option_string_name(aliased, "reason"),
		GFSessionTraceUtility.REJECT_UNKNOWN_CHANNEL,
		"超长 ID 不应别名到相同前缀的已注册通道。"
	)

	trace.max_event_buffer_bytes = 0
	var disabled: Dictionary = trace.record_event(allowed_id, &"event")
	assert_eq(
		GFVariantData.get_option_string_name(disabled, "reason"),
		GFSessionTraceUtility.REJECT_EVENT_TOO_LARGE,
		"关闭事件缓冲后应在编码载荷前拒绝。"
	)


func test_session_trace_dispose_clears_context_and_owned_journal() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	var sink: MemoryJournalSink = MemoryJournalSink.new()
	assert_true(
		trace.configure_journal_sink(sink, { "shutdown_on_dispose": true }),
		"测试 journal 应配置成功。"
	)
	var _session_id: StringName = trace.start_session(&"dispose", { "secret": "temporary" })
	trace.dispose()
	var snapshot: Dictionary = trace.build_snapshot()
	var summary: Dictionary = GFVariantData.get_option_dictionary(snapshot, "summary")

	assert_true(GFVariantData.get_option_dictionary(snapshot, "context").is_empty(), "dispose 应清除会话上下文。")
	assert_eq(GFVariantData.get_option_string_name(summary, "session_id"), &"", "dispose 应清除会话标识。")
	assert_eq(sink.shutdown_count, 1, "由工具拥有生命周期的 journal 应关闭一次。")


func test_session_trace_prevents_reentrant_journal_recursion() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	var sink: ReentrantJournalSink = ReentrantJournalSink.new()
	sink.trace = trace
	assert_true(trace.configure_journal_sink(sink), "重入测试 sink 应配置成功。")
	assert_true(trace.register_channel(&"route"), "路由通道应注册成功。")
	var _session_id: StringName = trace.start_session(&"journal-reentry")
	var _recorded: Dictionary = trace.record_event(&"route", &"outer")
	var summary: Dictionary = GFVariantData.get_option_dictionary(trace.get_debug_snapshot(), "summary")

	assert_eq(sink.write_count, 1, "嵌套事件不应再次递归写入同一 journal。")
	assert_eq(trace.get_events().size(), 2, "journal 回调产生的事件仍应遵守普通内存轨迹语义。")
	assert_eq(GFVariantData.get_option_int(summary, "journal_event_count"), 1, "外层 journal 写入应计数。")
	assert_eq(GFVariantData.get_option_int(summary, "journal_dropped_event_count"), 1, "重入 journal 应计入丢弃。")


func test_session_trace_guards_flush_and_deferred_sink_cleanup_reentry() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	var sink: LifecycleReentrantJournalSink = LifecycleReentrantJournalSink.new()
	sink.trace = trace
	assert_true(
		trace.configure_journal_sink(
			sink,
			{
				"flush_after_write": true,
				"shutdown_on_dispose": true,
			}
		),
		"生命周期重入测试 sink 应配置成功。"
	)
	assert_true(trace.register_channel(&"route"), "路由通道应注册成功。")
	var _session_id: StringName = trace.start_session(&"journal-lifecycle-reentry")
	var _recorded: Dictionary = trace.record_event(&"route", &"outer")
	var summary: Dictionary = GFVariantData.get_option_dictionary(trace.get_debug_snapshot(), "summary")

	assert_eq(sink.write_count, 1, "flush 回写事件不应再次写入 journal。")
	assert_eq(sink.flush_count, 1, "逐条 flush 应只执行一次。")
	assert_eq(trace.get_events().size(), 2, "flush 回写事件仍应进入普通内存轨迹。")
	assert_eq(GFVariantData.get_option_int(summary, "journal_event_count"), 1, "外层写入应计数一次。")
	assert_eq(GFVariantData.get_option_int(summary, "journal_dropped_event_count"), 1, "flush 重入应计入 journal 丢弃。")

	sink.clear_on_write = true
	var _clearing_recorded: Dictionary = trace.record_event(&"route", &"clear_sink")
	assert_false(
		GFVariantData.get_option_bool(trace.get_debug_snapshot(), "journal_configured", true),
		"sink 在 write 回调中请求清除时应先原子脱离。"
	)
	assert_eq(sink.shutdown_count, 1, "延迟清理应在外层 write 返回后关闭 sink 一次。")


func test_session_trace_allows_reentrant_configure_null_journal_clear() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	var sink: ConfigureNullJournalSink = ConfigureNullJournalSink.new()
	sink.trace = trace
	assert_true(
		trace.configure_journal_sink(sink, { "shutdown_on_dispose": true }),
		"回调清除测试 sink 应配置成功。"
	)
	assert_true(trace.register_channel(&"route"), "路由通道应注册成功。")
	var _session_id: StringName = trace.start_session(&"journal-configure-null")
	var _recorded: Dictionary = trace.record_event(&"route", &"clear_sink")

	assert_true(sink.configure_null_result, "write 回调中的 configure_journal_sink(null) 应成功。")
	assert_false(
		GFVariantData.get_option_bool(trace.get_debug_snapshot(), "journal_configured", true),
		"null 配置应在回调内先原子断开 sink。"
	)
	assert_eq(sink.shutdown_count, 1, "回调结束后应按既有所有权关闭 sink 一次。")


func test_session_trace_preserves_reentrant_clear_during_sink_replacement() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	var old_sink: CleanupConfigureNullJournalSink = CleanupConfigureNullJournalSink.new()
	var replacement_sink: MemoryJournalSink = MemoryJournalSink.new()
	old_sink.trace = trace
	assert_true(trace.configure_journal_sink(old_sink), "旧 journal sink 应配置成功。")
	old_sink.clear_on_flush = true

	assert_false(
		trace.configure_journal_sink(replacement_sink),
		"旧 sink 清理回调主动置空时，外层替换必须中止。"
	)
	assert_true(old_sink.configure_null_result, "旧 sink 的清理回调应能请求置空。")
	assert_false(
		GFVariantData.get_option_bool(trace.get_debug_snapshot(), "journal_configured", true),
		"清理回调的置空结果不应被外层替换覆盖。"
	)
	assert_true(
		trace.configure_journal_sink(replacement_sink),
		"清理回调结束后应允许调用方显式重试替换。"
	)


func test_session_trace_rejects_journal_profile_weaker_than_sink_boundary() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	var sink: PrivacyJournalSink = PrivacyJournalSink.new()
	trace.redaction_profile = GFReportValueCodec.REDACTION_PROFILE_DEBUG
	assert_false(
		trace.configure_journal_sink(sink),
		"debug 轨迹不能连接到要求 privacy 的外发 sink。"
	)
	assert_false(
		GFVariantData.get_option_bool(trace.get_debug_snapshot(), "journal_configured", true),
		"不安全的 profile 组合不得部分配置 sink。"
	)

	trace.redaction_profile = GFReportValueCodec.REDACTION_PROFILE_PRIVACY
	assert_true(trace.configure_journal_sink(sink), "privacy 轨迹应满足 privacy sink 边界。")
	assert_true(trace.register_channel(&"state"), "状态通道应注册成功。")
	var _session_id: StringName = trace.start_session(&"journal-profile")
	sink.output_profile = "unsupported"
	var _dynamic_profile_recorded: Dictionary = trace.record_event(&"state", &"dynamic_sink_profile")
	sink.output_profile = GFReportValueCodec.REDACTION_PROFILE_PRIVACY
	trace.redaction_profile = GFReportValueCodec.REDACTION_PROFILE_DEBUG
	var _recorded: Dictionary = trace.record_event(
		&"state",
		&"snapshot",
		{ "path": "res://private/player_state.json" }
	)
	var summary: Dictionary = GFVariantData.get_option_dictionary(trace.get_debug_snapshot(), "summary")

	assert_eq(sink.entries.size(), 0, "运行期 sink 声明变化或 trace profile 放宽后 journal 应 fail closed。")
	assert_eq(GFVariantData.get_option_int(summary, "journal_dropped_event_count"), 2, "两次不安全写入都应计入 journal 丢弃。")


func _get_variant_marker_value(source: Dictionary, key: String) -> String:
	var encoded: Dictionary = GFVariantData.get_option_dictionary(source, key)
	var marker: Dictionary = GFVariantData.get_option_dictionary(encoded, "__gf_variant__")
	return GFVariantData.get_option_string(marker, "value")


# --- 内部类 ---

class MemoryJournalSink extends GFLogSink:
	var entries: Array[Dictionary] = []
	var flush_count: int = 0
	var shutdown_count: int = 0

	func write(entry: Dictionary) -> void:
		entries.append(entry.duplicate(true))

	func flush() -> void:
		flush_count += 1

	func shutdown() -> void:
		shutdown_count += 1


class StatefulJournalSink extends MemoryJournalSink:
	var init_count: int = 0
	var active: bool = false

	func init(_owner: Object) -> void:
		init_count += 1
		active = true

	func write(entry: Dictionary) -> void:
		if active:
			super.write(entry)

	func shutdown() -> void:
		active = false
		super.shutdown()


class ReentrantJournalSink extends GFLogSink:
	var trace: GFSessionTraceUtility = null
	var write_count: int = 0

	func write(_entry: Dictionary) -> void:
		write_count += 1
		var _nested: Dictionary = trace.record_event(&"route", &"journal_reentered")


class LifecycleReentrantJournalSink extends MemoryJournalSink:
	var trace: GFSessionTraceUtility = null
	var clear_on_write: bool = false
	var write_count: int = 0

	func write(entry: Dictionary) -> void:
		write_count += 1
		super.write(entry)
		if clear_on_write:
			trace.clear_journal_sink(true)

	func flush() -> void:
		super.flush()
		if flush_count == 1:
			var _nested: Dictionary = trace.record_event(&"route", &"flush_reentered")


class ConfigureNullJournalSink extends MemoryJournalSink:
	var trace: GFSessionTraceUtility = null
	var configure_null_result: bool = false

	func write(entry: Dictionary) -> void:
		super.write(entry)
		configure_null_result = trace.configure_journal_sink(null)


class CleanupConfigureNullJournalSink extends MemoryJournalSink:
	var trace: GFSessionTraceUtility = null
	var clear_on_flush: bool = false
	var configure_null_result: bool = false

	func flush() -> void:
		super.flush()
		if clear_on_flush:
			clear_on_flush = false
			configure_null_result = trace.configure_journal_sink(null)


class PrivacyJournalSink extends MemoryJournalSink:
	var output_profile: String = GFReportValueCodec.REDACTION_PROFILE_PRIVACY

	func get_report_redaction_profile() -> String:
		return output_profile
