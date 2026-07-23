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


func test_session_trace_bounds_circular_metadata_at_every_public_recording_boundary() -> void:
	var circular_metadata: Dictionary = {}
	circular_metadata["self"] = circular_metadata
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	assert_true(
		trace.register_channel(&"state", { "metadata": circular_metadata }),
		"通道注册应有界编码循环 metadata。"
	)
	assert_true(
		trace.register_snapshot_provider(
			&"state_provider",
			&"state",
			func() -> Dictionary:
				return { "ready": true },
			{ "metadata": circular_metadata }
		),
		"Provider 注册应有界编码循环 metadata。"
	)
	var channel_catalog: Dictionary = trace.get_channel_catalog()
	var provider_catalog: Dictionary = trace.get_snapshot_provider_catalog()
	assert_true(
		JSON.stringify(channel_catalog).contains("<circular_reference>"),
		"通道目录不得保留循环引用。"
	)
	assert_true(
		JSON.stringify(provider_catalog).contains("<circular_reference>"),
		"Provider 目录不得保留循环引用。"
	)

	var _session_id: StringName = trace.start_session(&"circular-public-boundaries")
	var direct_result: Dictionary = trace.record_event(
		&"state",
		&"direct",
		{},
		{ "metadata": circular_metadata }
	)
	var capture_result: Dictionary = trace.capture_snapshot_provider(
		&"state_provider",
		{ "metadata": circular_metadata }
	)
	assert_true(GFVariantData.get_option_bool(direct_result, "ok"))
	assert_true(GFVariantData.get_option_bool(capture_result, "ok"))
	assert_true(
		JSON.stringify(direct_result).contains("<circular_reference>"),
		"直接事件 metadata 应编码为稳定循环引用标记。"
	)
	assert_true(
		JSON.stringify(capture_result).contains("<circular_reference>"),
		"Provider capture metadata 应编码为稳定循环引用标记。"
	)
	trace.dispose()


func test_session_trace_accepts_string_name_metadata_option_keys() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	assert_true(
		trace.register_channel(
			&"state",
			{ &"metadata": { "channel_value": 1 } }
		),
		"通道注册应接受 StringName metadata 选项键。"
	)
	assert_true(
		trace.register_snapshot_provider(
			&"state_provider",
			&"state",
			func() -> Dictionary:
				return { "ready": true },
			{ &"metadata": { "provider_value": 2 } }
		),
		"Provider 注册应接受 StringName metadata 选项键。"
	)
	var _session_id: StringName = trace.start_session(&"string-name-metadata")
	var direct_result: Dictionary = trace.record_event(
		&"state",
		&"direct",
		{},
		{ &"metadata": { "direct_value": 3 } }
	)
	var capture_result: Dictionary = trace.capture_snapshot_provider(
		&"state_provider",
		{ &"metadata": { "capture_value": 4 } }
	)
	var direct_event: Dictionary = GFVariantData.get_option_dictionary(direct_result, "event")
	var capture_event: Dictionary = GFVariantData.get_option_dictionary(capture_result, "event")
	var direct_metadata: Dictionary = GFVariantData.get_option_dictionary(direct_event, "metadata")
	var capture_metadata: Dictionary = GFVariantData.get_option_dictionary(capture_event, "metadata")

	assert_true(GFVariantData.get_option_bool(direct_result, "ok"), "直接事件应成功记录。")
	assert_true(GFVariantData.get_option_bool(capture_result, "ok"), "Provider capture 应成功记录。")
	assert_eq(
		GFVariantData.get_option_int(direct_metadata, "channel_value"),
		1,
		"直接事件应保留通道 metadata。"
	)
	assert_eq(
		GFVariantData.get_option_int(direct_metadata, "direct_value"),
		3,
		"直接事件应保留 StringName 键读取的调用 metadata。"
	)
	assert_eq(
		GFVariantData.get_option_int(capture_metadata, "channel_value"),
		1,
		"Provider capture 应保留通道 metadata。"
	)
	assert_eq(
		GFVariantData.get_option_int(capture_metadata, "provider_value"),
		2,
		"Provider capture 应保留注册 metadata。"
	)
	assert_eq(
		GFVariantData.get_option_int(capture_metadata, "capture_value"),
		4,
		"Provider capture 应保留 StringName 键读取的调用 metadata。"
	)
	trace.dispose()


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


func test_session_trace_recipe_configures_channels_checkpoints_and_snapshot_defaults() -> void:
	var channel: GFSessionTraceChannelDefinition = GFSessionTraceChannelDefinition.new()
	var _configured_channel: GFSessionTraceChannelDefinition = channel.configure(
		&"route",
		{ "max_events": 4 }
	)
	var checkpoint: GFSessionTraceCheckpoint = GFSessionTraceCheckpoint.new()
	var _configured_checkpoint: GFSessionTraceCheckpoint = checkpoint.configure(
		&"route_failure",
		PackedStringArray(["route_state"]),
		{ "metadata": { "trigger": &"error" } }
	)
	var recipe: GFSessionTraceRecipe = GFSessionTraceRecipe.new()
	var _configured_recipe: GFSessionTraceRecipe = recipe.configure(
		&"ui_route_failure",
		[channel],
		[checkpoint],
		{
			"max_events": 8,
			"max_event_buffer_bytes": 64 * 1024,
			"max_event_bytes": 4 * 1024,
			"snapshot_limit": 1,
			"include_context": false,
		}
	)
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	var applied: Dictionary = trace.apply_recipe(recipe)
	var provider_calls: Array[int] = [0]
	assert_true(
		trace.register_snapshot_provider(
			&"route_state",
			&"route",
			func() -> Dictionary:
				provider_calls[0] += 1
				return { "route_id": &"settings" },
		),
		"配方通道应用后应允许注册运行时 Provider。"
	)
	var _session_id: StringName = trace.start_session(&"recipe-session")
	var _opened: Dictionary = trace.record_event(&"route", &"opened", { "route_id": &"settings" })
	var checkpoint_result: Dictionary = trace.capture_recipe_checkpoint(recipe, &"route_failure")
	var snapshot: Dictionary = trace.build_recipe_snapshot(recipe)
	var debug_snapshot: Dictionary = trace.get_debug_snapshot()
	var events: Array = GFVariantData.get_option_array(snapshot, "events")

	assert_true(GFVariantData.get_option_bool(applied, "ok"), "合法配方应原子应用。")
	assert_true(trace.has_channel(&"route"), "配方应注册声明通道。")
	assert_true(GFVariantData.get_option_bool(checkpoint_result, "ok"), "必需 Provider 成功时检查点应成功。")
	assert_eq(provider_calls[0], 1, "检查点应按声明执行 Provider 一次。")
	assert_eq(events.size(), 1, "配方快照应应用默认 limit。")
	assert_false(snapshot.has("context"), "配方快照应应用 include_context=false。")
	assert_eq(
		GFVariantData.get_option_string_name(snapshot, "recipe_id"),
		&"ui_route_failure",
		"快照应标明配方身份。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(debug_snapshot, "configured_recipe_id"),
		&"ui_route_failure",
		"调试快照应暴露当前配方身份。"
	)
	trace.dispose()
	trace = null
	recipe = null
	checkpoint = null
	channel = null


func test_session_trace_recipe_detects_definition_and_runtime_drift() -> void:
	var channel: GFSessionTraceChannelDefinition = GFSessionTraceChannelDefinition.new()
	var _configured_channel: GFSessionTraceChannelDefinition = channel.configure(
		&"save",
		{ "max_events": 2 }
	)
	var checkpoint: GFSessionTraceCheckpoint = GFSessionTraceCheckpoint.new()
	var _configured_checkpoint: GFSessionTraceCheckpoint = checkpoint.configure(
		&"save_failure",
		PackedStringArray(["save_state"])
	)
	var recipe: GFSessionTraceRecipe = GFSessionTraceRecipe.new()
	var _configured_recipe: GFSessionTraceRecipe = recipe.configure(
		&"save_failure",
		[channel],
		[checkpoint]
	)
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	assert_true(GFVariantData.get_option_bool(trace.apply_recipe(recipe), "ok"), "配方应成功应用。")

	recipe.snapshot_limit = 3
	var changed_recipe_snapshot: Dictionary = trace.build_recipe_snapshot(recipe)
	assert_eq(
		GFVariantData.get_option_string_name(changed_recipe_snapshot, "error_code"),
		&"recipe_changed",
		"应用后修改配方资源应被检测。"
	)
	recipe.snapshot_limit = 0
	assert_true(
		trace.register_channel(&"save", { "max_events": 7 }),
		"测试应能模拟绕过配方修改运行时通道。"
	)
	var drifted_snapshot: Dictionary = trace.build_recipe_snapshot(recipe)
	var reapplied_after_drift: Dictionary = trace.apply_recipe(recipe)
	assert_eq(
		GFVariantData.get_option_string_name(drifted_snapshot, "error_code"),
		&"recipe_runtime_drift",
		"运行时通道与配方漂移时应 fail closed。"
	)
	assert_false(
		GFVariantData.get_option_bool(reapplied_after_drift, "ok", true),
		"运行时已漂移时不得把重复应用报告为幂等成功。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(reapplied_after_drift, "error_code"),
		&"recipe_runtime_drift",
		"重复应用应复核运行时指纹。"
	)
	trace.dispose()
	trace = null
	recipe = null
	checkpoint = null
	channel = null


func test_session_trace_recipe_owns_the_complete_channel_catalog() -> void:
	var channel: GFSessionTraceChannelDefinition = GFSessionTraceChannelDefinition.new()
	var _configured_channel: GFSessionTraceChannelDefinition = channel.configure(&"declared")
	var recipe: GFSessionTraceRecipe = GFSessionTraceRecipe.new()
	var _configured_recipe: GFSessionTraceRecipe = recipe.configure(
		&"exclusive_channels",
		[channel]
	)
	var preconfigured_trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	assert_true(
		preconfigured_trace.register_channel(&"unmanaged"),
		"故障注入通道应注册成功。"
	)
	var rejected: Dictionary = preconfigured_trace.apply_recipe(recipe)
	assert_false(
		GFVariantData.get_option_bool(rejected, "ok", true),
		"配方不得接纳未声明的既有通道。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(rejected, "error_code"),
		&"unmanaged_channel_conflict",
		"未声明通道应返回稳定错误码。"
	)
	assert_true(preconfigured_trace.has_channel(&"unmanaged"), "拒绝应用不得修改既有目录。")
	assert_false(preconfigured_trace.has_channel(&"declared"), "拒绝应用不得部分注册配方通道。")

	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	assert_true(GFVariantData.get_option_bool(trace.apply_recipe(recipe), "ok"), "干净目录应应用成功。")
	assert_true(trace.register_channel(&"added_later"), "测试应能模拟应用后新增通道。")
	var drifted_snapshot: Dictionary = trace.build_recipe_snapshot(recipe)
	assert_eq(
		GFVariantData.get_option_string_name(drifted_snapshot, "error_code"),
		&"recipe_runtime_drift",
		"应用后新增通道必须让配方快照 fail closed。"
	)
	assert_true(trace.unregister_channel(&"added_later"), "测试应恢复表面相同的通道目录。")
	var restored_snapshot: Dictionary = trace.build_recipe_snapshot(recipe)
	assert_eq(
		GFVariantData.get_option_string_name(restored_snapshot, "error_code"),
		&"recipe_runtime_drift",
		"配置被改动后即使恢复原值，也必须保留单调漂移证据。"
	)
	preconfigured_trace.dispose()
	trace.dispose()


func test_session_trace_recipe_fingerprint_tracks_runtime_redaction_semantics() -> void:
	var channel: GFSessionTraceChannelDefinition = GFSessionTraceChannelDefinition.new()
	var _configured_channel: GFSessionTraceChannelDefinition = channel.configure(&"support")
	var checkpoint: GFSessionTraceCheckpoint = GFSessionTraceCheckpoint.new()
	var _configured_checkpoint: GFSessionTraceCheckpoint = checkpoint.configure(
		&"support_capture",
		PackedStringArray(["support_state"]),
		{ "metadata": { "source_path": "res://private/first.cfg" } }
	)
	var recipe: GFSessionTraceRecipe = GFSessionTraceRecipe.new()
	var _configured_recipe: GFSessionTraceRecipe = recipe.configure(
		&"support_recipe",
		[channel],
		[checkpoint],
		{ "redaction_profile": GFReportValueCodec.REDACTION_PROFILE_DEBUG }
	)
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	assert_true(GFVariantData.get_option_bool(trace.apply_recipe(recipe), "ok"), "调试配方应成功应用。")

	checkpoint.metadata["source_path"] = "res://private/second.cfg"
	var changed: Dictionary = trace.build_recipe_snapshot(recipe)

	assert_eq(
		GFVariantData.get_option_string_name(changed, "error_code"),
		&"recipe_changed",
		"指纹必须按实际运行时脱敏 profile 检测检查点 metadata 变化。"
	)
	trace.dispose()


func test_session_trace_recipe_bounds_circular_metadata_without_recursion() -> void:
	var circular_metadata: Dictionary = {}
	circular_metadata["self"] = circular_metadata
	var channel: GFSessionTraceChannelDefinition = GFSessionTraceChannelDefinition.new()
	var _configured_channel: GFSessionTraceChannelDefinition = channel.configure(
		&"circular",
		{ "metadata": circular_metadata }
	)
	var checkpoint: GFSessionTraceCheckpoint = GFSessionTraceCheckpoint.new()
	var _configured_checkpoint: GFSessionTraceCheckpoint = checkpoint.configure(
		&"circular_capture",
		PackedStringArray(["circular_state"]),
		{ "metadata": circular_metadata }
	)
	var recipe: GFSessionTraceRecipe = GFSessionTraceRecipe.new()
	var _configured_recipe: GFSessionTraceRecipe = recipe.configure(
		&"circular_recipe",
		[channel],
		[checkpoint],
		{ "metadata": circular_metadata }
	)
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	assert_true(
		GFVariantData.get_option_bool(trace.apply_recipe(recipe), "ok"),
		"循环资源 metadata 应先被有界编码，再安全应用配方。"
	)
	assert_true(
		trace.register_snapshot_provider(
			&"circular_state",
			&"circular",
			func() -> Dictionary:
				return { "ready": true },
		),
		"配方通道应允许注册检查点 Provider。"
	)
	var _session_id: StringName = trace.start_session(&"circular-metadata")
	var checkpoint_result: Dictionary = trace.capture_recipe_checkpoint(
		recipe,
		&"circular_capture",
		{ "metadata": circular_metadata }
	)
	var results: Dictionary = GFVariantData.get_option_dictionary(
		checkpoint_result,
		"results"
	)
	var provider_result: Dictionary = GFVariantData.get_option_dictionary(
		results,
		&"circular_state"
	)
	var event: Dictionary = GFVariantData.get_option_dictionary(provider_result, "event")

	assert_true(GFVariantData.get_option_bool(checkpoint_result, "ok"))
	assert_true(GFVariantData.get_option_bool(provider_result, "ok"))
	assert_true(
		JSON.stringify(event).contains("<circular_reference>"),
		"循环 metadata 应编码为稳定截断标记，不得保留循环引用。"
	)
	trace.dispose()


func test_session_trace_recipe_rejects_out_of_contract_numeric_budgets() -> void:
	var channel: GFSessionTraceChannelDefinition = GFSessionTraceChannelDefinition.new()
	var _configured_channel: GFSessionTraceChannelDefinition = channel.configure(&"bounded")
	var recipe: GFSessionTraceRecipe = GFSessionTraceRecipe.new()
	var _configured_recipe: GFSessionTraceRecipe = recipe.configure(&"bounded_recipe", [channel])

	recipe.max_events = -1
	assert_false(GFVariantData.get_option_bool(recipe.validate_recipe(), "ok", true), "负事件上限必须被拒绝。")
	recipe.max_events = 1_000_001
	assert_false(GFVariantData.get_option_bool(recipe.validate_recipe(), "ok", true), "超大事件上限必须被拒绝。")
	recipe.max_events = 512
	recipe.max_event_buffer_bytes = 1_073_741_825
	assert_false(GFVariantData.get_option_bool(recipe.validate_recipe(), "ok", true), "超大缓冲预算必须被拒绝。")
	recipe.max_event_buffer_bytes = 1024 * 1024
	recipe.max_event_bytes = 16_777_217
	assert_false(GFVariantData.get_option_bool(recipe.validate_recipe(), "ok", true), "超大单事件预算必须被拒绝。")
	recipe.max_event_bytes = 16 * 1024
	recipe.snapshot_limit = -1
	assert_false(GFVariantData.get_option_bool(recipe.validate_recipe(), "ok", true), "负快照上限必须被拒绝。")
	recipe.snapshot_limit = 0
	channel.max_events = -1
	assert_false(GFVariantData.get_option_bool(recipe.validate_recipe(), "ok", true), "负通道事件上限必须被拒绝。")
	channel.max_events = 0
	channel.max_event_bytes = 1
	assert_false(GFVariantData.get_option_bool(recipe.validate_recipe(), "ok", true), "低于安全包络的通道预算必须被拒绝。")
	channel.max_event_bytes = 0
	assert_true(GFVariantData.get_option_bool(recipe.validate_recipe(), "ok"), "恢复合法边界后配方应通过校验。")

	var invalid_configured_channel: GFSessionTraceChannelDefinition = (
		GFSessionTraceChannelDefinition.new().configure(
			&"invalid_configured_channel",
			{ "max_event_bytes": 1 }
		)
	)
	assert_false(
		GFVariantData.get_option_bool(invalid_configured_channel.validate_definition(), "ok", true),
		"configure() 不得把非法通道预算静默提升成合法值。"
	)
	var valid_channel: GFSessionTraceChannelDefinition = (
		GFSessionTraceChannelDefinition.new().configure(&"valid_configured_channel")
	)
	var invalid_configured_recipe: GFSessionTraceRecipe = GFSessionTraceRecipe.new().configure(
		&"invalid_configured_recipe",
		[valid_channel],
		[],
		{ "max_events": -1 }
	)
	assert_false(
		GFVariantData.get_option_bool(invalid_configured_recipe.validate_recipe(), "ok", true),
		"configure() 不得把非法配方预算静默改成禁用值。"
	)


func test_session_trace_recipe_rejects_nonempty_trace_without_mutation() -> void:
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	assert_true(trace.register_channel(&"existing", { "max_events": 3 }), "既有通道应注册成功。")
	var _session_id: StringName = trace.start_session(&"existing-session")
	var _recorded: Dictionary = trace.record_event(&"existing", &"before_recipe")
	var _stopped: Dictionary = trace.stop_session()
	var previous_catalog: Dictionary = trace.get_channel_catalog()
	var previous_max_events: int = trace.max_events

	var channel: GFSessionTraceChannelDefinition = GFSessionTraceChannelDefinition.new()
	var _configured_channel: GFSessionTraceChannelDefinition = channel.configure(
		&"recipe_channel",
		{ "max_events": 1 }
	)
	var recipe: GFSessionTraceRecipe = GFSessionTraceRecipe.new()
	var _configured_recipe: GFSessionTraceRecipe = recipe.configure(
		&"late_recipe",
		[channel],
		[],
		{ "max_events": 4 }
	)
	var result: Dictionary = trace.apply_recipe(recipe)

	assert_false(GFVariantData.get_option_bool(result, "ok", true), "已有会话历史时不得追认配方。")
	assert_eq(
		GFVariantData.get_option_string_name(result, "error_code"),
		&"trace_not_empty",
		"非空轨迹应返回稳定失败码。"
	)
	assert_eq(trace.get_channel_catalog(), previous_catalog, "拒绝应用后通道目录不得变化。")
	assert_eq(trace.max_events, previous_max_events, "拒绝应用后全局预算不得变化。")
	trace.dispose()


func test_session_trace_recipe_checkpoint_distinguishes_optional_failures_and_continues() -> void:
	var channel: GFSessionTraceChannelDefinition = GFSessionTraceChannelDefinition.new()
	var _configured_channel: GFSessionTraceChannelDefinition = channel.configure(&"state")
	var optional_checkpoint: GFSessionTraceCheckpoint = GFSessionTraceCheckpoint.new()
	var _configured_optional_checkpoint: GFSessionTraceCheckpoint = optional_checkpoint.configure(
		&"optional_only",
		PackedStringArray(["missing_optional", "healthy"]),
		{ "optional_provider_ids": PackedStringArray(["missing_optional"]) }
	)
	var required_checkpoint: GFSessionTraceCheckpoint = GFSessionTraceCheckpoint.new()
	var _configured_required_checkpoint: GFSessionTraceCheckpoint = required_checkpoint.configure(
		&"required_failure",
		PackedStringArray(["missing_required", "healthy"])
	)
	var recipe: GFSessionTraceRecipe = GFSessionTraceRecipe.new()
	var _configured_recipe: GFSessionTraceRecipe = recipe.configure(
		&"checkpoint_policy",
		[channel],
		[optional_checkpoint, required_checkpoint]
	)
	var trace: GFSessionTraceUtility = GFSessionTraceUtility.new()
	assert_true(GFVariantData.get_option_bool(trace.apply_recipe(recipe), "ok"), "检查点配方应应用成功。")
	var provider_calls: Array[int] = [0]
	assert_true(
		trace.register_snapshot_provider(
			&"healthy",
			&"state",
			func() -> Dictionary:
				provider_calls[0] += 1
				return { "ready": true },
		),
		"健康 Provider 应注册成功。"
	)
	var _session_id: StringName = trace.start_session(&"checkpoint-session")

	var optional_result: Dictionary = trace.capture_recipe_checkpoint(recipe, &"optional_only")
	var required_result: Dictionary = trace.capture_recipe_checkpoint(recipe, &"required_failure")

	assert_true(GFVariantData.get_option_bool(optional_result, "ok"), "仅可选 Provider 失败时检查点应成功。")
	assert_eq(GFVariantData.get_option_int(optional_result, "optional_failure_count"), 1, "应统计可选失败。")
	assert_false(GFVariantData.get_option_bool(required_result, "ok", true), "必需 Provider 失败时检查点应失败。")
	assert_eq(GFVariantData.get_option_int(required_result, "required_failure_count"), 1, "应统计必需失败。")
	assert_eq(provider_calls[0], 2, "前序失败不得阻止后续健康 Provider 执行。")
	trace.dispose()


func test_session_trace_checkpoint_rejects_duplicate_optional_provider_ids() -> void:
	var checkpoint: GFSessionTraceCheckpoint = GFSessionTraceCheckpoint.new()
	var _configured_checkpoint: GFSessionTraceCheckpoint = checkpoint.configure(
		&"duplicate_optional",
		PackedStringArray(["state"]),
		{ "optional_provider_ids": PackedStringArray(["state", "state"]) }
	)

	var report: Dictionary = checkpoint.validate_checkpoint()
	assert_false(
		GFVariantData.get_option_bool(report, "ok", true),
		"可选 Provider 列表必须保持集合语义，不能接受重复 ID。"
	)


func test_session_trace_checkpoint_rejects_oversized_provider_list() -> void:
	var provider_ids: PackedStringArray = PackedStringArray()
	for index: int in range(257):
		var _id_appended: bool = provider_ids.append("provider_%d" % index)
	var checkpoint: GFSessionTraceCheckpoint = GFSessionTraceCheckpoint.new()
	var _configured_checkpoint: GFSessionTraceCheckpoint = checkpoint.configure(
		&"oversized",
		provider_ids
	)

	assert_false(
		GFVariantData.get_option_bool(checkpoint.validate_checkpoint(), "ok", true),
		"单检查点 Provider 列表必须有独立硬上限。"
	)


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
	trace.dispose()
	sink.trace = null


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
