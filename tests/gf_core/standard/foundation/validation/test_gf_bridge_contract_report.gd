extends GutTest

const GF_BRIDGE_CONTRACT_REPORT_SCRIPT = preload("res://addons/gf/standard/foundation/validation/gf_bridge_contract_report.gd")


# --- 测试用例 ---

func test_bridge_contract_report_detects_coverage_drift() -> void:
	var report: Dictionary = GF_BRIDGE_CONTRACT_REPORT_SCRIPT.from_entries(
		[
			{
				"contract_id": &"config.resolve",
				"signature": "Dictionary(request) -> Variant",
			},
			{
				"contract_id": &"analytics.submit",
				"signature": "Dictionary(event) -> void",
				"allow_multiple": true,
			},
			{
				"contract_id": &"optional.preview",
				"required": false,
			},
		],
		[
			{
				"adapter_id": &"config.handler.a",
				"contract_id": &"config.resolve",
				"signature": "Dictionary(request) -> Variant",
			},
			{
				"adapter_id": &"config.handler.b",
				"contract_id": &"config.resolve",
				"signature": "Dictionary(request) -> Variant",
			},
			{
				"adapter_id": &"analytics.adapter",
				"contract_id": &"analytics.submit",
				"signature": "String(event) -> void",
			},
			{
				"adapter_id": &"orphan.adapter",
				"contract_id": &"unknown.bridge",
			},
		],
		{
			"subject": "Bridge coverage",
		}
	)
	var issue_counts: Dictionary = GFVariantData.get_option_dictionary(report, "issue_counts_by_kind")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "签名不匹配默认是 error。")
	assert_eq(GFVariantData.get_option_int(report, "covered_count"), 2, "有启用适配器的契约应计入 covered。")
	assert_eq(GFVariantData.get_option_int(report, "compatible_count"), 1, "签名匹配的契约才应计入 compatible。")
	assert_eq(GFVariantData.get_option_int(report, "optional_missing_count"), 1, "可选契约缺失应只进入 optional_missing 计数。")
	assert_eq(GFVariantData.get_option_int(report, "extra_count"), 1, "未知契约适配器应计入 extra。")
	assert_eq(GFVariantData.get_option_int(report, "duplicate_count"), 1, "默认不允许多适配器的契约应报告重复覆盖。")
	assert_eq(GFVariantData.get_option_int(report, "mismatch_count"), 1, "签名不一致应计入 mismatch。")
	assert_eq(GFVariantData.get_option_int(issue_counts, "bridge_adapter_extra"), 1, "未知契约 issue kind 应稳定。")
	assert_eq(GFVariantData.get_option_int(issue_counts, "bridge_adapter_duplicate"), 1, "重复适配器 issue kind 应稳定。")
	assert_eq(GFVariantData.get_option_int(issue_counts, "bridge_adapter_signature_mismatch"), 1, "签名不匹配 issue kind 应稳定。")
	assert_eq(GFVariantData.get_option_array(report, "compatible"), ["config.resolve"], "compatible 列表应只包含完全匹配的契约。")


func test_optional_missing_contracts_do_not_fail_by_default() -> void:
	var report: Dictionary = GF_BRIDGE_CONTRACT_REPORT_SCRIPT.from_entries(
		[
			{
				"contract_id": &"editor.preview",
				"required": false,
			},
		],
		[],
		{
			"subject": "Optional bridge coverage",
		}
	)

	assert_true(GFVariantData.get_option_bool(report, "healthy"), "只有可选契约缺失时报告应保持健康。")
	assert_eq(GFVariantData.get_option_int(report, "optional_missing_count"), 1, "可选缺失仍应进入计数，方便工具展示。")
	assert_true(GFVariantData.get_option_array(report, "issues").is_empty(), "默认不为可选缺失生成 issue。")


func test_missing_contract_issues_use_contract_kind_field() -> void:
	var report: Dictionary = GF_BRIDGE_CONTRACT_REPORT_SCRIPT.from_entries(
		[
			{
				"contract_id": &"required.sync",
				"kind": &"runtime_bridge",
			},
			{
				"contract_id": &"optional.preview",
				"kind": &"editor_bridge",
				"required": false,
			},
		],
		[],
		{
			"report_optional_missing": true,
		}
	)
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var required_issue: Dictionary = GFVariantData.as_dictionary(issues[0])
	var optional_issue: Dictionary = GFVariantData.as_dictionary(issues[1])

	assert_eq(GFVariantData.get_option_string(required_issue, "kind"), "bridge_contract_missing", "issue kind 字段应保留验证类型。")
	assert_eq(GFVariantData.get_option_string_name(required_issue, "contract_kind"), &"runtime_bridge", "契约类型应写入 contract_kind。")
	assert_false(required_issue.has("kind") and GFVariantData.get_option_string_name(required_issue, "kind") == &"runtime_bridge", "契约类型不应覆盖 issue kind。")
	assert_eq(GFVariantData.get_option_string_name(optional_issue, "contract_kind"), &"editor_bridge", "可选缺失也应写入 contract_kind。")


func test_duplicate_contract_id_does_not_amplify_missing_counts() -> void:
	var report: Dictionary = GF_BRIDGE_CONTRACT_REPORT_SCRIPT.from_entries(
		[
			{
				"contract_id": &"config.resolve",
			},
			{
				"contract_id": &"config.resolve",
			},
		],
		[]
	)
	var issue_counts: Dictionary = GFVariantData.get_option_dictionary(report, "issue_counts_by_kind")

	assert_eq(GFVariantData.get_option_int(report, "contract_count"), 1, "重复 contract_id 不应进入有效契约集合。")
	assert_eq(GFVariantData.get_option_int(report, "invalid_count"), 1, "重复契约应作为无效契约计数。")
	assert_eq(GFVariantData.get_option_int(report, "missing_count"), 1, "重复契约不应放大缺失计数。")
	assert_eq(GFVariantData.get_option_int(issue_counts, "bridge_contract_duplicate"), 1, "重复契约应有稳定 issue kind。")
	assert_eq(GFVariantData.get_option_int(issue_counts, "bridge_contract_missing"), 1, "缺失契约只应报告一次。")


func test_capability_requirements_make_adapter_incompatible() -> void:
	var report: Dictionary = GF_BRIDGE_CONTRACT_REPORT_SCRIPT.from_entries(
		[
			{
				"contract_id": &"platform.share",
				"capabilities": PackedStringArray(["image", "text"]),
			},
		],
		[
			{
				"adapter_id": &"share.text_only",
				"contract_id": &"platform.share",
				"capabilities": PackedStringArray(["text"]),
			},
		]
	)
	var issue_counts: Dictionary = GFVariantData.get_option_dictionary(report, "issue_counts_by_kind")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺少必需能力应让报告失败。")
	assert_eq(GFVariantData.get_option_int(report, "covered_count"), 1, "有适配器时仍算 covered。")
	assert_eq(GFVariantData.get_option_int(report, "compatible_count"), 0, "能力不完整时不算 compatible。")
	assert_eq(GFVariantData.get_option_int(issue_counts, "bridge_adapter_capability_missing"), 1, "缺少能力应有稳定 issue kind。")


func test_make_object_adapter_entry_reports_compatible_surface() -> void:
	var adapter: ObjectBridgeFixture = ObjectBridgeFixture.new()
	var adapter_entry: Dictionary = GF_BRIDGE_CONTRACT_REPORT_SCRIPT.make_object_adapter_entry(
		&"bridge.fixture",
		PackedStringArray(["platform.share"]),
		adapter,
		{
			"required_methods": PackedStringArray(["submit"]),
			"required_signals": PackedStringArray(["submitted"]),
			"capabilities": PackedStringArray(["text"]),
		}
	)
	var report: Dictionary = GF_BRIDGE_CONTRACT_REPORT_SCRIPT.from_entries(
		[
			{
				"contract_id": &"platform.share",
				"capabilities": PackedStringArray(["text"]),
			},
		],
		[adapter_entry]
	)
	var adapters: Array = GFVariantData.get_option_array(report, "adapters")
	var normalized_adapter: Dictionary = GFVariantData.as_dictionary(adapters[0])
	var metadata: Dictionary = GFVariantData.get_option_dictionary(normalized_adapter, "metadata")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "surface 完整的对象适配器应通过契约报告。")
	assert_eq(GFVariantData.get_option_array(report, "compatible"), ["platform.share"], "对象适配器应覆盖目标契约。")
	assert_true(GFVariantData.get_option_bool(metadata, "valid_target"), "metadata 应记录对象有效。")
	assert_true(GFVariantData.get_option_packed_string_array(metadata, "missing_methods").is_empty(), "完整 surface 不应报告缺失方法。")
	assert_true(GFVariantData.get_option_packed_string_array(metadata, "missing_signals").is_empty(), "完整 surface 不应报告缺失信号。")


func test_bridge_report_has_explicit_redacted_json_export() -> void:
	var adapter: ObjectBridgeFixture = ObjectBridgeFixture.new()
	var adapter_entry: Dictionary = GF_BRIDGE_CONTRACT_REPORT_SCRIPT.make_object_adapter_entry(
		&"bridge.fixture",
		PackedStringArray(["platform.share"]),
		adapter
	)
	var builder: GFBridgeContractReport = GFBridgeContractReport.new()
	var _contract: Dictionary = builder.add_contract(&"platform.share")
	var _adapter: Dictionary = builder.add_adapter(&"bridge.fixture", &"platform.share", adapter_entry)
	var report: Dictionary = builder.get_json_compatible_report({}, GFReportValueCodec.make_redaction_options(
		GFReportValueCodec.REDACTION_PROFILE_PUBLIC
	))
	var json_text: String = JSON.stringify(report)

	assert_false(json_text.contains("res://"), "public JSON 导出不应泄漏适配器脚本路径。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "脱敏导出不应改变契约判定。")


func test_make_object_adapter_entry_disables_incomplete_surface() -> void:
	var adapter: ObjectBridgeFixture = ObjectBridgeFixture.new()
	var adapter_entry: Dictionary = GF_BRIDGE_CONTRACT_REPORT_SCRIPT.make_object_adapter_entry(
		&"bridge.incomplete",
		PackedStringArray(["platform.share"]),
		adapter,
		{
			"required_methods": PackedStringArray(["missing_method"]),
			"required_signals": PackedStringArray(["missing_signal"]),
		}
	)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(adapter_entry, "metadata")
	var report: Dictionary = GF_BRIDGE_CONTRACT_REPORT_SCRIPT.from_entries(
		[
			{
				"contract_id": &"platform.share",
			},
		],
		[adapter_entry]
	)

	assert_false(GFVariantData.get_option_bool(adapter_entry, "enabled"), "缺失 surface 的对象适配器应标记为 disabled。")
	assert_eq(GFVariantData.get_option_packed_string_array(metadata, "missing_methods"), PackedStringArray(["missing_method"]), "metadata 应列出缺失方法。")
	assert_eq(GFVariantData.get_option_packed_string_array(metadata, "missing_signals"), PackedStringArray(["missing_signal"]), "metadata 应列出缺失信号。")
	assert_false(GFVariantData.get_option_bool(report, "ok"), "必需契约只有 disabled adapter 时仍应失败。")
	assert_eq(GFVariantData.get_option_int(report, "missing_count"), 1, "disabled adapter 不应计入覆盖。")


func test_request_handler_registry_report_reuses_bridge_contract_shape() -> void:
	var registry: GFRequestHandlerRegistry = GFRequestHandlerRegistry.new()
	var handler: Callable = func(request: Dictionary) -> Dictionary:
		return {
			"request_type": GFVariantData.get_option_string_name(request, "request_type"),
		}
	var _registered: Dictionary = registry.register_handler(&"config.resolve", handler)

	var entries: Dictionary = GFRequestHandlerRegistry.make_bridge_contract_entries(
		PackedStringArray(["config.resolve", "save.commit"]),
		registry
	)
	var report: Dictionary = GF_BRIDGE_CONTRACT_REPORT_SCRIPT.report_request_handlers(
		PackedStringArray(["config.resolve", "save.commit"]),
		registry
	)

	assert_eq(GFVariantData.get_option_array(entries, "contract_entries").size(), 2, "请求 handler 模块应负责构建契约条目。")
	assert_eq(GFVariantData.get_option_array(entries, "adapter_entries").size(), 1, "请求 handler 模块应负责构建 adapter 条目。")
	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺少必需 handler 时请求覆盖报告应失败。")
	assert_eq(GFVariantData.get_option_array(report, "covered"), ["config.resolve"], "已注册 handler 应进入 covered。")
	assert_eq(GFVariantData.get_option_array(report, "missing"), ["save.commit"], "未注册 handler 应进入 missing。")
	assert_eq(GFVariantData.get_option_int(report, "missing_count"), 1, "缺少 handler 应进入 missing 计数。")


# --- 内部类 ---

class ObjectBridgeFixture:
	extends RefCounted

	signal submitted

	func submit(_payload: Dictionary) -> void:
		pass


	func emit_submitted(payload: Dictionary) -> void:
		submitted.emit(payload)
