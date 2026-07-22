## 测试 GFDiagnosticsUtility 的快照与命令调度。
extends GutTest


## 验证诊断命令注册后可统一执行。
func test_diagnostics_command_executes() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	diagnostics.init()

	var result: Dictionary = diagnostics.execute_command(&"diagnostics.performance")
	var performance_value: Dictionary = GFVariantData.as_dictionary(result["value"])

	assert_true(GFVariantData.get_option_bool(result, "ok"), "内置性能诊断命令应执行成功。")
	assert_true(performance_value.has("fps"), "性能快照应包含 fps。")
	assert_true(diagnostics.has_command(&"diagnostics.scene"), "Diagnostics 应注册只读场景树快照命令。")
	assert_true(diagnostics.has_command(&"diagnostics.signals"), "Diagnostics 应注册只读信号图快照命令。")


## 验证场景树快照只采集结构摘要并遵守深度限制。
func test_diagnostics_collects_read_only_scene_tree_snapshot() -> void:
	var root: Node = Node.new()
	root.name = "Root"
	var child: Node = Node.new()
	child.name = "Child"
	var grandchild: Node = Node.new()
	grandchild.name = "Grandchild"
	root.add_child(child)
	child.add_child(grandchild)
	add_child_autofree(root)

	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var snapshot: Dictionary = diagnostics.collect_scene_tree_snapshot(root, {
		"max_depth": 1,
		"max_nodes": 8,
		"include_groups": true,
	})
	var root_data: Dictionary = GFVariantData.as_dictionary(snapshot["root"])
	var children: Array = GFVariantData.as_array(root_data["children"])
	var child_data: Dictionary = GFVariantData.as_dictionary(children[0])

	assert_true(GFVariantData.get_option_bool(snapshot, "available"), "传入根节点时场景树快照应可用。")
	assert_eq(GFVariantData.get_option_string(root_data, "name"), "Root", "快照应记录节点名称。")
	assert_eq(GFVariantData.get_option_string(child_data, "name"), "Child", "快照应记录直接子节点。")
	assert_true(GFVariantData.get_option_bool(child_data, "depth_limit_reached"), "超过深度的子树应只标记截断，不继续展开。")
	assert_true(GFVariantData.get_option_bool(snapshot, "truncated"), "达到深度限制时顶层快照应标记截断。")


func test_diagnostics_scene_tree_snapshot_can_redact_paths() -> void:
	var root: SignalEmitter = SignalEmitter.new()
	root.name = "RedactedRoot"
	add_child_autofree(root)

	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var snapshot: Dictionary = diagnostics.collect_scene_tree_snapshot(root, {
		"redact_paths": true,
		"include_script_path": true,
		"include_owner_path": true,
	})
	var root_data: Dictionary = GFVariantData.as_dictionary(snapshot["root"])

	assert_eq(GFVariantData.get_option_string(snapshot, "root_path"), "<redacted>", "共享快照可隐藏 root_path。")
	assert_eq(GFVariantData.get_option_string(root_data, "path"), "<redacted>", "共享快照可隐藏节点 path。")
	if not GFVariantData.get_option_string(root_data, "script_path").is_empty():
		assert_eq(GFVariantData.get_option_string(root_data, "script_path"), "<redacted>", "共享快照可隐藏脚本路径。")


## 验证诊断命令等级默认只允许观察类命令。
func test_diagnostics_command_tier_denies_control_by_default() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var _command_registered: bool = diagnostics.register_command(
		self,
		&"runtime.pause",
		func(_args: Dictionary) -> Dictionary:
			return { "paused": true },
		"暂停运行时。",
		GFDiagnosticsUtility.CommandTier.CONTROL
	)

	var result: Dictionary = diagnostics.execute_command(&"runtime.pause")
	var metadata: Dictionary = GFVariantData.as_dictionary(result["metadata"])

	assert_false(GFVariantData.get_option_bool(result, "ok"), "默认等级不应允许 CONTROL 命令。")
	assert_eq(GFVariantData.get_option_string(metadata, "tier_name"), "control", "失败结果应包含命令等级。")


## 验证诊断命令可要求 token 认证。
func test_diagnostics_command_requires_auth_token() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	diagnostics.set_auth_token("secret")
	var _command_registered: bool = diagnostics.register_command(self, &"diagnostics.test", func(_args: Dictionary) -> String:
		return "ok"
	)

	var rejected: Dictionary = diagnostics.execute_command(&"diagnostics.test")
	var accepted: Dictionary = diagnostics.execute_command(&"diagnostics.test", { "auth_token": "secret" })

	assert_false(GFVariantData.get_option_bool(rejected, "ok"), "缺少 token 时命令应被拒绝。")
	assert_true(GFVariantData.get_option_bool(accepted, "ok"), "提供正确 token 时命令应执行。")


func test_diagnostics_command_schema_validates_arguments_and_defaults() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var _command_registered: bool = diagnostics.register_command(
		self,
		&"runtime.limit",
		func(args: Dictionary) -> Dictionary:
			return { "limit": args["limit"] },
		"读取限制值。",
		GFDiagnosticsUtility.CommandTier.OBSERVE,
		{
			"parameters": [
				{
					"name": "limit",
					"type": "int",
					"required": true,
					"default": 3,
					"min": 1,
					"max": 5,
				},
			],
		}
	)

	var defaulted: Dictionary = diagnostics.execute_command(&"runtime.limit")
	var rejected: Dictionary = diagnostics.execute_command(&"runtime.limit", { "limit": 8 })
	var defaulted_value: Dictionary = GFVariantData.as_dictionary(defaulted["value"])

	assert_true(GFVariantData.get_option_bool(defaulted, "ok"), "带默认值的必填参数缺省时应使用默认值。")
	assert_eq(GFVariantData.get_option_int(defaulted_value, "limit"), 3, "命令回调应收到填充默认值后的参数。")
	assert_false(GFVariantData.get_option_bool(rejected, "ok"), "超出 schema 范围的参数应被拒绝。")
	assert_true(GFVariantData.get_option_string(rejected, "error").contains("error"), "参数校验失败应返回校验摘要。")


func test_diagnostics_command_rejects_non_finite_numeric_parameter() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var _command_registered: bool = diagnostics.register_command(
		self,
		&"runtime.scale",
		func(args: Dictionary) -> Dictionary:
			return { "scale": GFVariantData.get_option_float(args, "scale") },
		"读取缩放。",
		GFDiagnosticsUtility.CommandTier.OBSERVE,
		{
			"parameters": [
				{
					"name": "scale",
					"type": "float",
				},
			],
		}
	)

	var result: Dictionary = diagnostics.execute_command(&"runtime.scale", { "scale": NAN })
	var metadata: Dictionary = GFVariantData.get_option_dictionary(result, "metadata")
	var validation: Dictionary = GFVariantData.get_option_dictionary(metadata, "validation")

	assert_false(GFVariantData.get_option_bool(result, "ok"), "诊断命令不应接受 NaN 参数。")
	assert_true(GFVariantData.get_option_string(validation, "summary").contains("parameter_non_finite"), "校验报告应说明非有限数值。")


func test_diagnostics_command_can_be_disabled_and_exported_json_safe() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var _command_registered: bool = diagnostics.register_command(self, &"runtime.vector", func(_args: Dictionary) -> Dictionary:
		return { "position": Vector3(1.0, 2.0, 3.0) }
	)

	var disabled_ok: bool = diagnostics.set_command_enabled(&"runtime.vector", false)
	var disabled: Dictionary = diagnostics.execute_command(&"runtime.vector")
	var _set_command_enabled_result_121: Variant = diagnostics.set_command_enabled(&"runtime.vector", true)
	var json_safe: Dictionary = diagnostics.execute_command_json_safe(&"runtime.vector")
	var value: Dictionary = GFVariantData.as_dictionary(json_safe["value"])
	var position: Dictionary = GFVariantData.as_dictionary(value["position"])

	assert_true(disabled_ok, "已注册命令应可被禁用。")
	assert_false(GFVariantData.get_option_bool(disabled, "ok"), "禁用命令不应执行回调。")
	assert_true(position.has(GFVariantJsonCodec.JSON_MARKER_KEY), "JSON-safe 命令结果应编码 Godot Variant。")


## 验证诊断快照可读取架构生命周期状态。
func test_diagnostics_collects_architecture_snapshot() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	await arch.register_utility_instance(diagnostics)
	await arch.init()

	var snapshot: Dictionary = diagnostics.collect_snapshot({
		"include_recent_logs": false,
	})
	var architecture: Dictionary = GFVariantData.as_dictionary(snapshot["architecture"])

	assert_true(architecture.has("utilities"), "架构快照应包含 Utility 状态。")

	arch.dispose()


## 验证诊断快照会聚合已注册工具的 get_debug_snapshot。
func test_diagnostics_collects_tool_debug_snapshots() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var timer: GFTimerUtility = GFTimerUtility.new()
	var action_queue: GFActionQueueSystem = GFActionQueueSystem.new()
	await arch.register_utility_instance(timer)
	await arch.register_utility_instance(diagnostics)
	await arch.register_system_instance(action_queue)
	await arch.init()
	assert_true(
		diagnostics.publish_tool_snapshot(self, &"download", { "pending_count": 0 }),
		"外部贡献应能发布 download 快照。"
	)

	var _execute_after_result_161: Variant = timer.execute_after(1.0, func() -> void:
		pass
	)
	var snapshot: Dictionary = diagnostics.collect_snapshot({
		"include_recent_logs": false,
	})
	var tools: Dictionary = GFVariantData.as_dictionary(snapshot["tools"])
	var timer_snapshot: Dictionary = GFVariantData.as_dictionary(tools[&"timer"])

	assert_true(tools.has(&"timer"), "工具快照应包含 TimerUtility。")
	assert_true(tools.has(&"download"), "工具快照应包含外部注册的 Download provider。")
	assert_true(tools.has(&"action_queue"), "工具快照应包含 ActionQueueSystem。")
	assert_eq(GFVariantData.get_option_int(timer_snapshot, "pending_count"), 1, "Timer 快照应保留工具自身诊断数据。")

	arch.dispose()


## 验证诊断快照会使用已注册的构建信息工具。
func test_diagnostics_collects_build_info_snapshot() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var build_info_utility: GFBuildInfoUtility = GFBuildInfoUtility.new()
	await arch.register_utility_instance(build_info_utility)
	await arch.register_utility_instance(diagnostics)
	await arch.init()
	var build_info: GFBuildInfo = GFBuildInfo.new()
	build_info.project_name = "GF Test"
	build_info.build_id = "diagnostics-build"
	build_info_utility.set_build_info(build_info)

	var snapshot: Dictionary = diagnostics.collect_snapshot({
		"include_recent_logs": false,
	})
	var build: Dictionary = GFVariantData.as_dictionary(snapshot["build"])
	var tools: Dictionary = GFVariantData.as_dictionary(snapshot["tools"])

	assert_eq(GFVariantData.get_option_string(build, "build_id"), "diagnostics-build", "诊断快照应使用 BuildInfoUtility 的稳定副本。")
	assert_true(tools.has(&"build_info"), "工具快照应包含 BuildInfoUtility。")

	arch.dispose()


## 验证诊断监控注册表可采样、预设和导出。
func test_diagnostics_monitor_registry_collects_custom_monitor() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	diagnostics.init()
	assert_true(diagnostics.register_monitor(self, &"test.value", {
		"label": "Value",
		"group": "Tests",
	}), "有效监控项应注册成功。")
	assert_true(diagnostics.publish_monitor_sample(self, &"test.value", 7), "监控项应接受 owner 发布的采样值。")
	assert_true(diagnostics.register_monitor_preset(&"test", PackedStringArray(["test.value"])), "监控预设应注册成功。")

	var snapshot: Dictionary = diagnostics.collect_monitor_snapshot(PackedStringArray(["test.value"]))
	var monitors: Dictionary = GFVariantData.as_dictionary(snapshot["monitors"])
	var sample: Dictionary = GFVariantData.as_dictionary(monitors[&"test.value"])
	var preset_snapshot: Dictionary = diagnostics.collect_monitor_preset(&"test")
	var exported_text: String = diagnostics.export_monitor_snapshot(preset_snapshot, &"text")

	assert_eq(GFVariantData.get_option_int(sample, "value"), 7, "监控快照应包含已发布值。")
	assert_eq(GFVariantData.get_option_string_name(preset_snapshot, "preset_id"), &"test", "预设快照应记录预设 id。")
	assert_true("Value" in exported_text, "文本导出应包含监控标签。")


func test_diagnostics_monitor_json_export_is_report_safe() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var exported_json: String = diagnostics.export_monitor_snapshot({
		"monitors": {
			&"runtime.nan": {
				"label": "NaN",
				"group": "Runtime",
				"value": NAN,
				"valid": true,
			},
		},
	}, &"json")

	assert_true(exported_json.contains(GFVariantJsonCodec.JSON_MARKER_KEY), "监控 JSON 导出应编码 NaN。")
	assert_false(exported_json.contains("\"value\":null"), "监控 JSON 导出不应把 NaN 退化为 null。")


func test_diagnostics_debugger_bridge_state_and_catalog_are_available() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	diagnostics.init()

	var bridge_state: Dictionary = diagnostics.get_debugger_bridge_state()
	var catalog_value: Variant = diagnostics.call("_make_debugger_catalog")
	var catalog: Dictionary = GFVariantData.as_dictionary(catalog_value)
	var commands: Dictionary = GFVariantData.get_option_dictionary(catalog, "commands")
	var monitors: Dictionary = GFVariantData.get_option_dictionary(catalog, "monitors")

	assert_eq(GFVariantData.get_option_string_name(bridge_state, "capture_name"), GFDiagnosticsUtility.DEBUGGER_CAPTURE_NAME, "Debugger bridge 应暴露稳定 capture 名称。")
	assert_false(GFVariantData.get_option_bool(bridge_state, "allow_command_execution"), "Debugger bridge 默认不应允许执行诊断命令。")
	assert_true(commands.has(&"diagnostics.snapshot"), "Debugger catalog 应包含内置快照命令。")
	assert_true(monitors.has(&"performance.fps"), "Debugger catalog 应包含内置性能监控。")

	diagnostics.dispose()


func test_diagnostics_collects_external_published_snapshots() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	diagnostics.init()

	assert_true(diagnostics.publish_snapshot_section(self, &"runtime", {
		"enemy_count": 3,
	}), "外部快照分区应可发布。")
	assert_true(diagnostics.publish_tool_snapshot(self, &"runtime_tool", {
		"pending": 2,
	}), "外部工具快照应可发布。")
	var _monitor_registered: bool = diagnostics.register_monitor(self, &"runtime.pending")
	var _monitor_published: bool = diagnostics.publish_monitor_sample(self, &"runtime.pending", 2)
	assert_true(diagnostics.add_monitor_to_preset(&"tools", &"runtime.pending"), "外部监控项应可加入内置 tools 预设。")

	var snapshot: Dictionary = diagnostics.collect_snapshot({
		"include_recent_logs": false,
	})
	var runtime: Dictionary = GFVariantData.as_dictionary(snapshot["runtime"])
	var tools: Dictionary = GFVariantData.as_dictionary(snapshot["tools"])
	var tool_monitors: Dictionary = GFVariantData.as_dictionary(diagnostics.collect_monitor_preset(&"tools")["monitors"])

	var runtime_tool: Dictionary = GFVariantData.as_dictionary(tools[&"runtime_tool"])
	assert_eq(GFVariantData.get_option_int(runtime, "enemy_count"), 3, "外部快照分区应进入 collect_snapshot 顶层字段。")
	assert_eq(GFVariantData.get_option_int(runtime_tool, "pending"), 2, "外部工具快照应进入 tools 字段。")
	assert_true(tool_monitors.has(&"runtime.pending"), "追加到 tools 预设的外部监控项应可采样。")


func test_diagnostics_rejects_external_contributions_for_reserved_snapshot_keys() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	diagnostics.init()

	var section_registered: bool = diagnostics.publish_snapshot_section(self, &"build", { "fake": true })
	var tool_registered: bool = diagnostics.publish_tool_snapshot(self, &"timer", { "fake": true })
	var snapshot: Dictionary = diagnostics.collect_snapshot({
		"include_recent_logs": false,
	})
	var build: Dictionary = GFVariantData.get_option_dictionary(snapshot, "build")
	var tools: Dictionary = GFVariantData.get_option_dictionary(snapshot, "tools")

	assert_false(section_registered, "外部分区不应覆盖内置 build 字段。")
	assert_false(tool_registered, "外部工具快照不应覆盖内置 timer 字段。")
	assert_false(GFVariantData.get_option_bool(build, "fake"), "拒绝后的外部分区不应进入 build。")
	if tools.has(&"timer"):
		var timer_snapshot: Dictionary = GFVariantData.get_option_dictionary(tools, &"timer")
		assert_false(GFVariantData.get_option_bool(timer_snapshot, "fake"), "拒绝后的外部工具不应覆盖 timer。")


func test_diagnostics_registries_enforce_owner_safe_replace_and_unregister() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var first_owner: RegistrationOwner = RegistrationOwner.new()
	var other_owner: RegistrationOwner = RegistrationOwner.new()
	var first_command: Callable = Callable(first_owner, "execute_command")
	var other_command: Callable = Callable(other_owner, "execute_command")

	assert_true(diagnostics.register_command(first_owner, &"owned.command", first_command), "首个 owner 应能注册命令。")
	assert_true(diagnostics.register_command(first_owner, &"owned.command", first_command), "同一 owner 应能更新自己的命令。")
	assert_false(diagnostics.register_command(other_owner, &"owned.command", other_command), "其他 owner 不应覆盖已有命令。")
	assert_false(diagnostics.unregister_command(other_owner, &"owned.command"), "其他 owner 不应注销已有命令。")
	assert_true(diagnostics.has_command(&"owned.command"), "被拒绝的注销不应移除命令。")
	assert_true(diagnostics.unregister_command(first_owner, &"owned.command"), "当前 owner 应能注销自己的命令。")

	assert_true(diagnostics.register_monitor(first_owner, &"owned.monitor"), "首个 owner 应能注册监控项。")
	assert_false(diagnostics.register_monitor(other_owner, &"owned.monitor"), "其他 owner 不应覆盖已有监控项。")
	assert_false(diagnostics.publish_monitor_sample(other_owner, &"owned.monitor", 2), "其他 owner 不应发布监控采样。")
	assert_true(diagnostics.publish_monitor_sample(first_owner, &"owned.monitor", 1), "当前 owner 应能发布监控采样。")
	assert_false(diagnostics.unregister_monitor(other_owner, &"owned.monitor"), "其他 owner 不应注销已有监控项。")
	assert_true(diagnostics.unregister_monitor(first_owner, &"owned.monitor"), "当前 owner 应能注销自己的监控项。")

	assert_true(diagnostics.publish_snapshot_section(first_owner, &"owned_section", { "value": 1 }), "首个 owner 应能发布快照分区。")
	assert_false(diagnostics.publish_snapshot_section(other_owner, &"owned_section", { "value": 2 }), "其他 owner 不应覆盖快照分区。")
	assert_false(diagnostics.remove_snapshot_section(other_owner, &"owned_section"), "其他 owner 不应移除快照分区。")
	assert_true(diagnostics.remove_snapshot_section(first_owner, &"owned_section"), "当前 owner 应能移除快照分区。")

	assert_true(diagnostics.publish_tool_snapshot(first_owner, &"owned_tool", { "value": 1 }), "首个 owner 应能发布工具快照。")
	assert_false(diagnostics.publish_tool_snapshot(other_owner, &"owned_tool", { "value": 2 }), "其他 owner 不应覆盖工具快照。")
	assert_false(diagnostics.remove_tool_snapshot(other_owner, &"owned_tool"), "其他 owner 不应移除工具快照。")
	assert_true(diagnostics.remove_tool_snapshot(first_owner, &"owned_tool"), "当前 owner 应能移除工具快照。")


func test_snapshot_collection_never_executes_published_callable_values() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	diagnostics.init()
	var state: CallableValueState = CallableValueState.new()
	assert_true(diagnostics.publish_snapshot_section(state, &"callable_value", {
		"callback": Callable(state, "get_value"),
	}), "Callable 可作为待报告数据发布。")

	var snapshot: Dictionary = diagnostics.collect_snapshot({
		"include_monitors": false,
		"include_recent_logs": false,
	})

	assert_true(snapshot.has("callable_value"), "已发布分区应进入快照。")
	assert_eq(state.call_count, 0, "collect_snapshot 不得执行外部 Callable。")


func test_snapshot_publication_respects_structural_budgets_and_keeps_last_good_value() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	diagnostics.init()
	assert_true(diagnostics.publish_snapshot_section(self, &"bounded", {
		"values": [1, 2],
	}), "预算内快照应发布成功。")
	diagnostics.max_contribution_collection_items = 2
	assert_false(diagnostics.publish_snapshot_section(self, &"bounded", {
		"values": [1, 2, 3],
	}), "超过结构预算的更新应被拒绝。")

	var snapshot: Dictionary = diagnostics.collect_snapshot({
		"include_monitors": false,
		"include_recent_logs": false,
	})
	var section: Dictionary = GFVariantData.get_option_dictionary(snapshot, "bounded")
	var values: Array = GFVariantData.get_option_array(section, "values")

	assert_eq(values, [1, 2], "发布失败后应保留上一份有效快照。")


func test_released_contribution_owner_is_pruned_before_collection() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	diagnostics.init()
	var contribution_owner: RegistrationOwner = RegistrationOwner.new()
	assert_true(diagnostics.publish_snapshot_section(contribution_owner, &"released", {
		"value": 1,
	}), "有效 owner 应能发布分区。")
	contribution_owner = null

	var snapshot: Dictionary = diagnostics.collect_snapshot({
		"include_monitors": false,
		"include_recent_logs": false,
	})

	assert_false(snapshot.has("released"), "owner 释放后的分区不应进入快照。")
	assert_false(diagnostics.has_snapshot_section(&"released"), "失效 owner 的注册应被清理。")


func test_lazy_diagnostic_provider_runs_only_when_explicitly_requested() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	diagnostics.init()
	var provider: CountingDiagnosticProvider = CountingDiagnosticProvider.new()
	var _configured_provider: GFDiagnosticSnapshotProvider = provider.configure(&"game.runtime")

	assert_true(
		diagnostics.register_diagnostic_provider(self, provider),
		"有效的惰性诊断 Provider 应注册成功。"
	)
	var ordinary_snapshot: Dictionary = diagnostics.collect_snapshot({
		"include_monitors": false,
		"include_recent_logs": false,
	})
	assert_eq(provider.call_count, 0, "普通快照不得隐式执行项目 Provider。")
	assert_false(ordinary_snapshot.has("diagnostic_providers"), "未请求 Provider 时不应生成空分区。")

	var requested_snapshot: Dictionary = diagnostics.collect_snapshot({
		"include_monitors": false,
		"include_recent_logs": false,
		"diagnostic_provider_ids": PackedStringArray(["game.runtime"]),
		"diagnostic_provider_request": { "reason": &"support_report" },
	})
	var provider_batch: Dictionary = GFVariantData.get_option_dictionary(
		requested_snapshot,
		"diagnostic_providers"
	)
	var results: Dictionary = GFVariantData.get_option_dictionary(provider_batch, "results")
	var provider_result: Dictionary = GFVariantData.get_option_dictionary(results, &"game.runtime")
	var value: Dictionary = GFVariantData.get_option_dictionary(provider_result, "value")

	assert_eq(provider.call_count, 1, "显式请求应只执行一次 Provider。")
	assert_true(GFVariantData.get_option_bool(provider_result, "ok"), "合法 Provider 结果应采集成功。")
	assert_eq(GFVariantData.get_option_int(value, "pending"), 2, "Provider 值应进入有界结果。")
	assert_eq(provider.last_reason, &"support_report", "调用请求应作为临时上下文传给 Provider。")

	diagnostics.dispose()


func test_lazy_diagnostic_provider_rejects_result_after_registry_changes_during_callback() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	diagnostics.init()
	var provider: DisposingDiagnosticProvider = DisposingDiagnosticProvider.new()
	var _configured_provider: GFDiagnosticSnapshotProvider = provider.configure(&"game.disposing")
	provider.diagnostics = diagnostics
	assert_true(diagnostics.register_diagnostic_provider(self, provider), "故障注入 Provider 应注册成功。")

	var batch: Dictionary = diagnostics.collect_diagnostic_providers(
		PackedStringArray(["game.disposing"])
	)
	var results: Dictionary = GFVariantData.get_option_dictionary(batch, "results")
	var provider_result: Dictionary = GFVariantData.get_option_dictionary(results, &"game.disposing")

	assert_false(GFVariantData.get_option_bool(provider_result, "ok", true), "注册表变化后不得接纳旧结果。")
	assert_eq(
		GFVariantData.get_option_string_name(provider_result, "error_code"),
		&"provider_registration_changed",
		"回调期间释放应返回稳定失败码。"
	)
	assert_false(diagnostics.has_diagnostic_provider(&"game.disposing"), "dispose 后 Provider 应失效。")


func test_lazy_diagnostic_provider_batch_reports_request_truncation_without_extra_calls() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	diagnostics.max_diagnostic_providers = 1
	var first_provider: CountingDiagnosticProvider = CountingDiagnosticProvider.new()
	var second_provider: CountingDiagnosticProvider = CountingDiagnosticProvider.new()
	var _first_configured_provider: GFDiagnosticSnapshotProvider = first_provider.configure(&"game.first")
	var _second_configured_provider: GFDiagnosticSnapshotProvider = second_provider.configure(&"game.second")
	assert_true(diagnostics.register_diagnostic_provider(self, first_provider), "首个 Provider 应注册成功。")
	diagnostics.max_diagnostic_providers = 2
	assert_true(diagnostics.register_diagnostic_provider(self, second_provider), "第二个 Provider 应注册成功。")
	diagnostics.max_diagnostic_providers = 1

	var batch: Dictionary = diagnostics.collect_diagnostic_providers(
		PackedStringArray(["game.first", "game.second"])
	)

	assert_false(GFVariantData.get_option_bool(batch, "ok", true), "截断批次不能伪装成完整成功。")
	assert_eq(GFVariantData.get_option_int(batch, "requested_count"), 2, "报告应保留调用方提交数量。")
	assert_eq(GFVariantData.get_option_int(batch, "executed_count"), 1, "执行数量应服从硬上限。")
	assert_eq(GFVariantData.get_option_int(batch, "omitted_count"), 1, "报告应显式暴露遗漏数量。")
	assert_eq(
		GFVariantData.get_option_string_name(batch, "error_code"),
		&"provider_request_limit_exceeded",
		"超限批次应返回稳定错误码。"
	)
	assert_eq(first_provider.call_count, 1, "上限内 Provider 应执行一次。")
	assert_eq(second_provider.call_count, 0, "被截断 Provider 不得执行。")


func test_lazy_diagnostic_provider_isolates_duration_budget_failure() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var slow_provider: SlowDiagnosticProvider = SlowDiagnosticProvider.new()
	var healthy_provider: CountingDiagnosticProvider = CountingDiagnosticProvider.new()
	var _configured_slow_provider: GFDiagnosticSnapshotProvider = slow_provider.configure(
		&"game.slow",
		{ "max_duration_usec": 100 }
	)
	var _configured_healthy_provider: GFDiagnosticSnapshotProvider = healthy_provider.configure(
		&"game.healthy"
	)
	assert_true(diagnostics.register_diagnostic_provider(self, slow_provider), "慢 Provider 应注册成功。")
	assert_true(diagnostics.register_diagnostic_provider(self, healthy_provider), "健康 Provider 应注册成功。")

	var batch: Dictionary = diagnostics.collect_diagnostic_providers(
		PackedStringArray(["game.slow", "game.healthy"])
	)
	var results: Dictionary = GFVariantData.get_option_dictionary(batch, "results")
	var slow_result: Dictionary = GFVariantData.get_option_dictionary(results, &"game.slow")
	var healthy_result: Dictionary = GFVariantData.get_option_dictionary(results, &"game.healthy")

	assert_false(GFVariantData.get_option_bool(batch, "ok", true), "任一 Provider 失败时批次应失败。")
	assert_eq(GFVariantData.get_option_int(batch, "success_count"), 1, "健康 Provider 应继续成功。")
	assert_eq(GFVariantData.get_option_int(batch, "failure_count"), 1, "超时 Provider 应独立计入失败。")
	assert_eq(
		GFVariantData.get_option_string_name(slow_result, "error_code"),
		&"provider_duration_budget_exceeded",
		"超出时长预算应返回稳定错误码。"
	)
	assert_true(GFVariantData.get_option_bool(healthy_result, "ok"), "前一个 Provider 失败不应中断后续采集。")
	assert_eq(healthy_provider.call_count, 1, "健康 Provider 应执行一次。")
	diagnostics.dispose()


func test_lazy_diagnostic_provider_rejects_result_when_owner_is_released_during_collection() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var registration_owner: RegistrationOwner = RegistrationOwner.new()
	var provider: OwnerReleasingDiagnosticProvider = OwnerReleasingDiagnosticProvider.new()
	var _configured_provider: GFDiagnosticSnapshotProvider = provider.configure(
		&"game.owner_releasing"
	)
	provider.owner_holder.append(registration_owner)
	assert_true(
		diagnostics.register_diagnostic_provider(registration_owner, provider),
		"owner 存活时应允许注册 Provider。"
	)
	registration_owner = null

	var batch: Dictionary = diagnostics.collect_diagnostic_providers(
		PackedStringArray(["game.owner_releasing"])
	)
	var results: Dictionary = GFVariantData.get_option_dictionary(batch, "results")
	var provider_result: Dictionary = GFVariantData.get_option_dictionary(
		results,
		&"game.owner_releasing"
	)

	assert_false(GFVariantData.get_option_bool(provider_result, "ok", true), "owner 在回调中释放后不得接纳结果。")
	assert_eq(
		GFVariantData.get_option_string_name(provider_result, "error_code"),
		&"provider_registration_changed",
		"owner 生命周期变化应返回稳定失败码。"
	)
	assert_false(diagnostics.has_diagnostic_provider(&"game.owner_releasing"), "失效注册应立即清理。")
	diagnostics.dispose()


func test_lazy_diagnostic_provider_isolates_reentrant_collection() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var provider: ReentrantDiagnosticProvider = ReentrantDiagnosticProvider.new()
	var _configured_provider: GFDiagnosticSnapshotProvider = provider.configure(&"game.reentrant")
	provider.diagnostics = diagnostics
	assert_true(diagnostics.register_diagnostic_provider(self, provider), "重入故障注入 Provider 应注册成功。")

	var batch: Dictionary = diagnostics.collect_diagnostic_providers(
		PackedStringArray(["game.reentrant"])
	)
	var results: Dictionary = GFVariantData.get_option_dictionary(batch, "results")
	var provider_result: Dictionary = GFVariantData.get_option_dictionary(results, &"game.reentrant")

	assert_true(GFVariantData.get_option_bool(provider_result, "ok"), "外层 Provider 结果仍应成功。")
	assert_eq(provider.call_count, 1, "重入请求不得再次执行同一 Provider。")
	assert_eq(provider.nested_error_code, &"provider_reentrant", "内层请求应得到稳定重入失败码。")
	diagnostics.dispose()
	provider.diagnostics = null


func test_lazy_diagnostic_provider_rejects_oversized_value_without_leaking_raw_data() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	diagnostics.max_contribution_collection_items = 2
	var provider: OversizedValueDiagnosticProvider = OversizedValueDiagnosticProvider.new()
	var _configured_provider: GFDiagnosticSnapshotProvider = provider.configure(&"game.oversized")
	assert_true(diagnostics.register_diagnostic_provider(self, provider), "超预算故障注入 Provider 应注册成功。")

	var batch: Dictionary = diagnostics.collect_diagnostic_providers(
		PackedStringArray(["game.oversized"])
	)
	var results: Dictionary = GFVariantData.get_option_dictionary(batch, "results")
	var provider_result: Dictionary = GFVariantData.get_option_dictionary(results, &"game.oversized")

	assert_false(GFVariantData.get_option_bool(provider_result, "ok", true), "超预算值必须 fail closed。")
	assert_eq(
		GFVariantData.get_option_string_name(provider_result, "error_code"),
		&"provider_value_rejected",
		"超预算值应返回稳定失败码。"
	)
	var rejected_value: Variant = GFVariantData.get_option_value(provider_result, "value")
	assert_true(rejected_value == null, "失败报告不得回显未验收的原始值。")
	diagnostics.dispose()


func test_lazy_diagnostic_provider_rejects_circular_metadata_without_recursion() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var circular_metadata: Dictionary = {}
	circular_metadata["self"] = circular_metadata
	var invalid_definition: CountingDiagnosticProvider = CountingDiagnosticProvider.new()
	var _configured_invalid_definition: GFDiagnosticSnapshotProvider = invalid_definition.configure(
		&"game.circular_definition",
		{ "metadata": circular_metadata }
	)
	assert_false(
		diagnostics.register_diagnostic_provider(self, invalid_definition),
		"循环目录 metadata 应由结构预算稳定拒绝。"
	)

	var result_provider: CircularMetadataDiagnosticProvider = (
		CircularMetadataDiagnosticProvider.new()
	)
	var _configured_result_provider: GFDiagnosticSnapshotProvider = result_provider.configure(
		&"game.circular_result"
	)
	assert_true(
		diagnostics.register_diagnostic_provider(self, result_provider),
		"无循环目录 metadata 的 Provider 应注册成功。"
	)
	var batch: Dictionary = diagnostics.collect_diagnostic_providers(
		PackedStringArray(["game.circular_result"])
	)
	var results: Dictionary = GFVariantData.get_option_dictionary(batch, "results")
	var provider_result: Dictionary = GFVariantData.get_option_dictionary(
		results,
		&"game.circular_result"
	)

	assert_false(GFVariantData.get_option_bool(provider_result, "ok", true))
	assert_eq(
		GFVariantData.get_option_string_name(provider_result, "error_code"),
		&"provider_metadata_rejected",
		"循环结果 metadata 应在聚合边界返回稳定失败码。"
	)
	assert_true(
		GFVariantData.get_option_value(provider_result, "value") == null,
		"未验收的循环结果不得进入报告。"
	)
	diagnostics.dispose()


func test_lazy_diagnostic_provider_failed_registration_does_not_lock_definition() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	diagnostics.max_diagnostic_providers = 0
	var provider: CountingDiagnosticProvider = CountingDiagnosticProvider.new()
	var _configured_provider: GFDiagnosticSnapshotProvider = provider.configure(&"game.before_retry")

	assert_false(
		diagnostics.register_diagnostic_provider(self, provider),
		"达到注册上限时应拒绝 Provider。"
	)
	provider.provider_id = &"game.after_retry"
	diagnostics.max_diagnostic_providers = 1
	assert_true(
		diagnostics.register_diagnostic_provider(self, provider),
		"失败注册不应锁死 Provider，修正定义后应能重试。"
	)
	assert_true(diagnostics.has_diagnostic_provider(&"game.after_retry"), "重试应使用修正后的身份。")
	diagnostics.dispose()


func test_lazy_diagnostic_provider_rejects_negative_duration_budget_without_disabling_guard() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var provider: CountingDiagnosticProvider = CountingDiagnosticProvider.new()
	var _configured_provider: GFDiagnosticSnapshotProvider = provider.configure(
		&"game.invalid_duration",
		{ "max_duration_usec": -1 }
	)

	assert_false(
		GFVariantData.get_option_bool(provider.validate_provider(), "ok", true),
		"负时长预算不得被静默改成 0 的无限制语义。"
	)
	assert_false(
		diagnostics.register_diagnostic_provider(self, provider),
		"非法时长预算不得进入 Provider 注册表。"
	)
	provider.max_duration_usec = 1_000
	assert_true(
		diagnostics.register_diagnostic_provider(self, provider),
		"修正预算后应允许注册，失败尝试不得锁定定义。"
	)
	diagnostics.dispose()


func test_lazy_diagnostic_provider_deduplicates_requests_without_reporting_limit_loss() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var provider: CountingDiagnosticProvider = CountingDiagnosticProvider.new()
	var _configured_provider: GFDiagnosticSnapshotProvider = provider.configure(&"game.duplicate")
	assert_true(diagnostics.register_diagnostic_provider(self, provider), "去重测试 Provider 应注册成功。")

	var batch: Dictionary = diagnostics.collect_diagnostic_providers(
		PackedStringArray(["game.duplicate", " game.duplicate "])
	)

	assert_true(GFVariantData.get_option_bool(batch, "ok"), "重复 ID 去重不应伪装成容量截断。")
	assert_eq(GFVariantData.get_option_int(batch, "requested_count"), 2, "应保留原始请求项数。")
	assert_eq(GFVariantData.get_option_int(batch, "unique_request_count"), 1, "应报告唯一合法 ID 数。")
	assert_eq(GFVariantData.get_option_int(batch, "duplicate_count"), 1, "应报告去重数量。")
	assert_eq(GFVariantData.get_option_int(batch, "omitted_count"), 0, "去重项不属于容量遗漏。")
	assert_eq(provider.call_count, 1, "重复 ID 只应执行一次。")
	diagnostics.dispose()


func test_lazy_diagnostic_provider_rejects_unbounded_shared_request_before_callbacks() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	diagnostics.max_contribution_collection_items = 2
	var provider: CountingDiagnosticProvider = CountingDiagnosticProvider.new()
	var _configured_provider: GFDiagnosticSnapshotProvider = provider.configure(&"game.request_guard")
	assert_true(diagnostics.register_diagnostic_provider(self, provider), "请求预算测试 Provider 应注册成功。")

	var batch: Dictionary = diagnostics.collect_diagnostic_providers(
		PackedStringArray(["game.request_guard"]),
		{ "values": [1, 2, 3] }
	)

	assert_false(GFVariantData.get_option_bool(batch, "ok", true), "超预算共享 request 必须 fail closed。")
	assert_eq(
		GFVariantData.get_option_string_name(batch, "error_code"),
		&"provider_request_rejected",
		"共享 request 被拒绝时应返回稳定批次错误码。"
	)
	assert_eq(GFVariantData.get_option_int(batch, "executed_count"), 0, "非法 request 不得执行任何 Provider。")
	assert_eq(provider.call_count, 0, "预算预检必须早于项目回调。")
	diagnostics.dispose()


func test_lazy_diagnostic_provider_rejects_oversized_raw_id_list_before_callbacks() -> void:
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var provider: CountingDiagnosticProvider = CountingDiagnosticProvider.new()
	var _configured_provider: GFDiagnosticSnapshotProvider = provider.configure(&"game.raw_request_guard")
	assert_true(diagnostics.register_diagnostic_provider(self, provider), "原始列表预算测试 Provider 应注册成功。")
	var provider_ids: PackedStringArray = PackedStringArray()
	for _index: int in range(1025):
		var _id_appended: bool = provider_ids.append("game.raw_request_guard")

	var batch: Dictionary = diagnostics.collect_diagnostic_providers(provider_ids)

	assert_false(GFVariantData.get_option_bool(batch, "ok", true), "超大原始 ID 列表必须 fail closed。")
	assert_eq(
		GFVariantData.get_option_string_name(batch, "error_code"),
		&"provider_request_size_exceeded",
		"原始列表超限应返回稳定批次错误码。"
	)
	assert_eq(GFVariantData.get_option_int(batch, "executed_count"), 0, "超限列表不得执行任何 Provider。")
	assert_eq(provider.call_count, 0, "原始列表硬上限必须早于去重和项目回调。")
	diagnostics.dispose()


func test_diagnostic_provider_failure_result_bounds_untrusted_error_details() -> void:
	var result: GFDiagnosticProviderResult = GFDiagnosticProviderResult.failed(
		&" invalid error code ",
		"x".repeat(2048)
	)

	assert_eq(result.get_error_code(), &"provider_failed", "非法错误码应归一为稳定兜底码。")
	assert_eq(result.get_error_message().length(), 1024, "错误说明应在进入聚合器前限制长度。")


## 验证内置工具监控预设可采样。
func test_diagnostics_builtin_tools_monitor_preset() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var timer: GFTimerUtility = GFTimerUtility.new()
	await arch.register_utility_instance(timer)
	await arch.register_utility_instance(diagnostics)
	await arch.init()

	var snapshot: Dictionary = diagnostics.collect_monitor_preset(&"tools")
	var monitors: Dictionary = GFVariantData.as_dictionary(snapshot["monitors"])

	assert_true(diagnostics.has_monitor_preset(&"tools"), "Diagnostics 应注册 tools 监控预设。")
	assert_true(monitors.has(&"tools.timer"), "tools 预设应包含 Timer 监控项。")

	arch.dispose()


func test_diagnostics_collects_signal_graph_snapshot() -> void:
	var root: Node = Node.new()
	root.name = "Root"
	var emitter: SignalEmitter = SignalEmitter.new()
	emitter.name = "Emitter"
	root.add_child(emitter)
	var _connect_result_279: Variant = emitter.ping.connect(func() -> void:
		pass
	)
	add_child_autofree(root)

	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var graph: Dictionary = diagnostics.collect_signal_graph_snapshot(root, { "include_index": true })
	var index: Dictionary = GFVariantData.as_dictionary(graph["index"])
	var ping_connection_count: int = 0
	var connections: Array = GFVariantData.get_option_array(graph, "connections")
	for connection_variant: Variant in connections:
		var connection: Dictionary = GFVariantData.as_dictionary(connection_variant)
		if connection.is_empty():
			continue
		if (
			GFVariantData.get_option_string(connection, "source_path").ends_with("Emitter")
			and GFVariantData.get_option_string(connection, "signal") == "ping"
		):
			ping_connection_count += 1

	assert_true(GFVariantData.get_option_bool(graph, "ok"), "传入根节点时信号图应可用。")
	assert_eq(ping_connection_count, 1, "运行时连接应进入信号图。")
	assert_true(index.has("by_source"), "include_index 应附加按来源节点索引。")


# --- 内部类 ---

class SignalEmitter:
	extends Node

	signal ping


class RegistrationOwner extends RefCounted:
	func execute_command(_args: Dictionary) -> Dictionary:
		return { "ok": true }


class CallableValueState extends RefCounted:
	var call_count: int = 0

	func get_value() -> int:
		call_count += 1
		return call_count


class CountingDiagnosticProvider extends GFDiagnosticSnapshotProvider:
	var call_count: int = 0
	var last_reason: StringName = &""

	func _collect_snapshot(request: Dictionary = {}) -> GFDiagnosticProviderResult:
		call_count += 1
		last_reason = GFVariantData.get_option_string_name(request, "reason")
		return GFDiagnosticProviderResult.succeeded({ "pending": 2 })


class DisposingDiagnosticProvider extends GFDiagnosticSnapshotProvider:
	var diagnostics: GFDiagnosticsUtility = null

	func _collect_snapshot(_request: Dictionary = {}) -> GFDiagnosticProviderResult:
		diagnostics.dispose()
		return GFDiagnosticProviderResult.succeeded({ "stale": true })


class SlowDiagnosticProvider extends GFDiagnosticSnapshotProvider:
	func _collect_snapshot(_request: Dictionary = {}) -> GFDiagnosticProviderResult:
		OS.delay_usec(2_000)
		return GFDiagnosticProviderResult.succeeded({ "too_slow": true })


class OwnerReleasingDiagnosticProvider extends GFDiagnosticSnapshotProvider:
	var owner_holder: Array[RefCounted] = []

	func _collect_snapshot(_request: Dictionary = {}) -> GFDiagnosticProviderResult:
		owner_holder.clear()
		return GFDiagnosticProviderResult.succeeded({ "stale": true })


class ReentrantDiagnosticProvider extends GFDiagnosticSnapshotProvider:
	var diagnostics: GFDiagnosticsUtility = null
	var call_count: int = 0
	var nested_error_code: StringName = &""

	func _collect_snapshot(_request: Dictionary = {}) -> GFDiagnosticProviderResult:
		call_count += 1
		var nested_batch: Dictionary = diagnostics.collect_diagnostic_providers(
			PackedStringArray([String(provider_id)])
		)
		var nested_results: Dictionary = GFVariantData.get_option_dictionary(
			nested_batch,
			"results"
		)
		var nested_result: Dictionary = GFVariantData.get_option_dictionary(
			nested_results,
			provider_id
		)
		nested_error_code = GFVariantData.get_option_string_name(nested_result, "error_code")
		return GFDiagnosticProviderResult.succeeded({ "nested_rejected": true })


class OversizedValueDiagnosticProvider extends GFDiagnosticSnapshotProvider:
	func _collect_snapshot(_request: Dictionary = {}) -> GFDiagnosticProviderResult:
		return GFDiagnosticProviderResult.succeeded({ "values": [1, 2, 3] })


class CircularMetadataDiagnosticProvider extends GFDiagnosticSnapshotProvider:
	func _collect_snapshot(_request: Dictionary = {}) -> GFDiagnosticProviderResult:
		var circular_metadata: Dictionary = {}
		circular_metadata["self"] = circular_metadata
		return GFDiagnosticProviderResult.succeeded(
			{ "should_not_escape": true },
			circular_metadata
		)
