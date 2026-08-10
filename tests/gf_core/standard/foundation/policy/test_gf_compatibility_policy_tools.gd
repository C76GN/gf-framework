## 测试通用兼容性预检、artifact 新鲜度和激活事务。
extends GutTest

signal async_callback_placeholder


# --- 私有变量 ---

var _temp_paths: PackedStringArray = PackedStringArray()


# --- 测试生命周期 ---

func after_each() -> void:
	for path: String in _temp_paths:
		if FileAccess.file_exists(path):
			var _removed: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_temp_paths.clear()


# --- 测试用例 ---

func test_compatibility_profile_round_trips_capabilities() -> void:
	var profile: GFCompatibilityProfile = GFCompatibilityProfile.new()
	var _configured: GFCompatibilityProfile = profile.configure(
		&"desktop",
		"4.7.0",
		"6.0.0",
		PackedStringArray(["Windows", "Windows"]),
		PackedStringArray(["content_package", "offline_bundle"])
	)
	var _package_entry: Dictionary = profile.add_package(&"gf.standard.base", "6.0.0", {
		"kind": "standard",
	})
	var _artifact_entry: Dictionary = profile.add_artifact(&"registry", "user://registry.json", {
		"sha256": "abc",
	})

	var copy: GFCompatibilityProfile = GFCompatibilityProfile.from_dict(profile.to_dict())

	assert_true(copy.has_platform("Windows"), "Profile 应保留平台能力。")
	assert_true(copy.has_feature(&"offline_bundle"), "Profile 应保留功能能力。")
	assert_eq(
		GFVariantData.get_option_string(copy.get_package(&"gf.standard.base"), "version"),
		"6.0.0",
		"Profile 应保留包版本。"
	)
	assert_eq(
		GFVariantData.get_option_string(copy.get_artifact(&"registry"), "path"),
		"user://registry.json",
		"Profile 应保留 artifact 路径。"
	)


func test_compatibility_profile_replaces_entries_by_id() -> void:
	var profile: GFCompatibilityProfile = GFCompatibilityProfile.new()
	var _first_package: Dictionary = profile.add_package(&"gf.standard.base", "6.0.0")
	var _second_package: Dictionary = profile.add_package(&"gf.standard.base", "6.1.0")
	var _first_artifact: Dictionary = profile.add_artifact(&"registry", "user://old.json")
	var _second_artifact: Dictionary = profile.add_artifact(&"registry", "user://new.json")

	assert_eq(profile.packages.size(), 1, "相同 package id 应替换旧条目而不是追加重复条目。")
	assert_eq(
		GFVariantData.get_option_string(profile.get_package(&"gf.standard.base"), "version"),
		"6.1.0",
		"替换后的 package 版本应保留最新显式值。"
	)
	assert_eq(profile.artifacts.size(), 1, "相同 artifact id 应替换旧条目而不是追加重复条目。")
	assert_eq(
		GFVariantData.get_option_string(profile.get_artifact(&"registry"), "path"),
		"user://new.json",
		"替换后的 artifact 路径应保留最新显式值。"
	)


func test_preflight_reports_version_feature_and_package_mismatches() -> void:
	var profile: GFCompatibilityProfile = GFCompatibilityProfile.new()
	var _configured: GFCompatibilityProfile = profile.configure(
		&"runtime",
		"4.7.0",
		"6.0.0",
		PackedStringArray(["Windows"]),
		PackedStringArray(["content_package"])
	)
	var _package_entry: Dictionary = profile.add_package(&"gf.standard.base", "6.0.0")
	var preflight: GFCompatibilityPreflight = GFCompatibilityPreflight.new()
	var _preflight_configured: GFCompatibilityPreflight = preflight.configure("Package preflight", profile)

	var _godot_check: Dictionary = preflight.require_godot_version("4.8.0")
	var _feature_check: Dictionary = preflight.require_features(PackedStringArray(["offline_bundle"]))
	var _package_check: Dictionary = preflight.require_package(&"gf.standard.base", "6.1.0")
	var report: Dictionary = preflight.get_report()

	assert_false(GFVariantData.get_option_bool(report, "ok"), "不满足版本、功能或包要求时预检应失败。")
	assert_eq(GFVariantData.get_option_int(report, "check_count"), 3, "每个显式要求都应留下检查记录。")
	assert_false(_find_issue(report, "godot_version_below_minimum").is_empty(), "Godot 版本不足应有稳定 issue kind。")
	assert_false(_find_issue(report, "feature_missing").is_empty(), "功能缺失应有稳定 issue kind。")
	assert_false(_find_issue(report, "package_version_below_minimum").is_empty(), "包版本不足应有稳定 issue kind。")


func test_preflight_package_presence_does_not_require_version_range() -> void:
	var profile: GFCompatibilityProfile = GFCompatibilityProfile.new()
	var _package_entry: Dictionary = profile.add_package(&"gf.standard.base", "")
	var preflight: GFCompatibilityPreflight = GFCompatibilityPreflight.new().configure("Package presence", profile)

	var check: Dictionary = preflight.require_package(&"gf.standard.base")
	var report: Dictionary = preflight.get_report()

	assert_true(GFVariantData.get_option_bool(check, "ok"), "只要求包存在时不应把空版本视为错误。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "包存在检查通过时预检报告应通过。")
	assert_eq(GFVariantData.get_option_string_name(check, "kind"), &"package", "无版本范围时检查类型应是 package presence。")


func test_preflight_reports_artifact_presence_and_path_mismatches() -> void:
	var profile: GFCompatibilityProfile = GFCompatibilityProfile.new()
	var _declared_artifact: Dictionary = profile.add_artifact(&"native_bridge", "res://native/bridge.gdip")
	var _pathless_artifact: Dictionary = profile.add_artifact(&"generated_manifest")
	var preflight: GFCompatibilityPreflight = GFCompatibilityPreflight.new().configure("Artifact preflight", profile)

	var present_check: Dictionary = preflight.require_artifact(&"native_bridge", {
		"expected_path": "res://native/bridge.gdip",
	})
	var _missing_check: Dictionary = preflight.require_artifact(&"native_library")
	var _pathless_check: Dictionary = preflight.require_artifact(&"generated_manifest", {
		"require_path": true,
	})
	var _mismatch_check: Dictionary = preflight.require_artifact(&"native_bridge", {
		"expected_path": "res://native/bridge.release.gdip",
	})
	var report: Dictionary = preflight.get_report()

	assert_true(GFVariantData.get_option_bool(present_check, "ok"), "artifact 声明和期望路径匹配时应通过。")
	assert_false(GFVariantData.get_option_bool(report, "ok"), "artifact 缺失或路径不匹配时预检应失败。")
	assert_eq(GFVariantData.get_option_int(report, "check_count"), 4, "每个 artifact 要求都应留下检查记录。")
	assert_false(_find_issue(report, "artifact_missing").is_empty(), "artifact 缺失应有稳定 issue kind。")
	assert_false(_find_issue(report, "artifact_path_missing").is_empty(), "要求路径但声明为空时应有稳定 issue kind。")
	assert_false(_find_issue(report, "artifact_path_mismatch").is_empty(), "artifact 路径不匹配应有稳定 issue kind。")


func test_preflight_compares_canonical_artifact_paths() -> void:
	var profile: GFCompatibilityProfile = GFCompatibilityProfile.new()
	var _declared_artifact: Dictionary = profile.add_artifact(&"native_bridge", "res://native/../native\\bridge.gdip")
	var preflight: GFCompatibilityPreflight = GFCompatibilityPreflight.new().configure("Artifact preflight", profile)

	var check: Dictionary = preflight.require_artifact(&"native_bridge", {
		"expected_path": "res://native/bridge.gdip",
	})
	var report: Dictionary = preflight.get_report()

	assert_true(GFVariantData.get_option_bool(check, "ok"), "等价资源路径应先规范化再比较。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "规范化等价路径不应产生 mismatch issue。")


func test_preflight_checks_declared_artifact_file_metadata_without_installing() -> void:
	var artifact_path: String = _write_temp_text("native_artifact", "native bridge")
	var profile: GFCompatibilityProfile = GFCompatibilityProfile.new()
	var _artifact: Dictionary = profile.add_artifact(&"native_bridge", artifact_path, {
		"kind": "native_library",
	})
	var preflight: GFCompatibilityPreflight = GFCompatibilityPreflight.new().configure("Native artifact preflight", profile)

	var ok_check: Dictionary = preflight.require_artifact(&"native_bridge", {
		"expected_kind": &"native_library",
		"require_file_exists": true,
		"expected_sha256": FileAccess.get_sha256(artifact_path),
		"expected_size_bytes": _read_file_size(artifact_path),
	})
	var _missing_file_check: Dictionary = preflight.require_artifact(&"native_bridge", {
		"check_id": &"native_bridge_bad_file",
		"expected_kind": &"gdextension",
		"expected_sha256": "0000000000000000000000000000000000000000000000000000000000000000",
		"expected_size_bytes": 999,
	})
	var report: Dictionary = preflight.get_report()

	assert_true(GFVariantData.get_option_bool(ok_check, "ok"), "存在且 metadata 匹配的 artifact 应通过。")
	assert_false(GFVariantData.get_option_bool(report, "ok"), "kind/hash/size 不匹配时预检应失败。")
	assert_false(_find_issue(report, "artifact_kind_mismatch").is_empty(), "kind 不匹配应有稳定 issue kind。")
	assert_false(_find_issue(report, "artifact_sha256_mismatch").is_empty(), "sha256 不匹配应有稳定 issue kind。")
	assert_false(_find_issue(report, "artifact_size_mismatch").is_empty(), "size 不匹配应有稳定 issue kind。")


func test_preflight_semver_prerelease_is_below_release() -> void:
	var profile: GFCompatibilityProfile = GFCompatibilityProfile.new()
	var _configured: GFCompatibilityProfile = profile.configure(&"runtime", "4.7.0", "6.0.0-rc1")
	var preflight: GFCompatibilityPreflight = GFCompatibilityPreflight.new().configure("Framework prerelease", profile)

	var _check: Dictionary = preflight.require_framework_version("6.0.0")
	var report: Dictionary = preflight.get_report()

	assert_false(GFVariantData.get_option_bool(report, "ok"), "SemVer prerelease 应低于同号正式版。")
	assert_false(_find_issue(report, "framework_version_below_minimum").is_empty(), "预发布版本不足应报告 below_minimum。")


func test_preflight_compares_numeric_prerelease_identifiers_without_int64_overflow() -> void:
	var ordered_identifiers: PackedStringArray = PackedStringArray([
		"9223372036854775807",
		"9223372036854775808",
		"9223372036854775809",
		"9999999999999999999",
		"10000000000000000000",
		"18446744073709551615",
		"18446744073709551616",
	])

	for index: int in range(ordered_identifiers.size() - 1):
		var lower: String = "1.0.0-%s" % ordered_identifiers[index]
		var higher: String = "1.0.0-%s" % ordered_identifiers[index + 1]
		assert_false(_framework_version_is_at_least(lower, higher), "较小 numeric prerelease 不得满足较大 minimum：%s < %s。" % [lower, higher])
		assert_true(_framework_version_is_at_least(higher, lower), "较大 numeric prerelease 应满足较小 minimum：%s > %s。" % [higher, lower])


func test_preflight_rejects_malformed_semver_instead_of_coercing_it() -> void:
	var profile: GFCompatibilityProfile = GFCompatibilityProfile.new()
	var _configured: GFCompatibilityProfile = profile.configure(&"runtime", "4.x", "6.0.0")
	var preflight: GFCompatibilityPreflight = GFCompatibilityPreflight.new().configure("Malformed version", profile)
	var _actual_check: Dictionary = preflight.require_godot_version("4.0.0")
	var _requirement_check: Dictionary = preflight.require_framework_version("6.0")
	var report: Dictionary = preflight.get_report()

	assert_false(_find_issue(report, "godot_version_invalid").is_empty(), "非法实际版本应与范围不满足区分。")
	assert_false(_find_issue(report, "framework_version_requirement_invalid").is_empty(), "非法版本要求不应被补零成普通 SemVer。")


func test_artifact_freshness_report_detects_hash_and_source_digest_mismatch() -> void:
	var artifact_path: String = _write_temp_text("freshness", "actual artifact")
	var builder: GFArtifactFreshnessReport = GFArtifactFreshnessReport.new()
	var _configured: GFArtifactFreshnessReport = builder.configure("Artifact test")
	var _artifact_entry: Dictionary = builder.add_artifact(&"config_json", artifact_path, {
		"expected_sha256": "0000000000000000000000000000000000000000000000000000000000000000",
		"expected_size_bytes": 999,
		"recorded_source_digest": "old-source",
		"current_source_digest": "new-source",
	})

	var report: Dictionary = builder.get_report()

	assert_false(GFVariantData.get_option_bool(report, "ok"), "artifact 元数据不匹配时报告应失败。")
	assert_false(_find_issue(report, "artifact_size_mismatch").is_empty(), "大小不匹配应有稳定 issue kind。")
	assert_false(_find_issue(report, "artifact_sha256_mismatch").is_empty(), "sha256 不匹配应有稳定 issue kind。")
	assert_false(_find_issue(report, "artifact_source_digest_mismatch").is_empty(), "source digest 过期应有稳定 issue kind。")
	assert_eq(GFVariantData.get_option_int(report, "stale_count"), 1, "同一 artifact 多项不匹配仍应只计一个 stale artifact。")


func test_artifact_freshness_report_accepts_matching_metadata() -> void:
	var artifact_path: String = _write_temp_text("freshness_ok", "actual artifact")
	var builder: GFArtifactFreshnessReport = GFArtifactFreshnessReport.new()
	var _artifact_entry: Dictionary = builder.add_artifact(&"config_json", artifact_path, {
		"expected_sha256": FileAccess.get_sha256(artifact_path).to_lower(),
		"expected_size_bytes": _read_file_size(artifact_path),
		"recorded_source_digest": "same-source",
		"current_source_digest": "same-source",
	})

	var report: Dictionary = builder.get_report()

	assert_true(GFVariantData.get_option_bool(report, "ok"), "artifact 元数据匹配时报告应通过。")
	assert_eq(GFVariantData.get_option_int(report, "existing_count"), 1, "存在的 artifact 应计入 existing_count。")


func test_artifact_freshness_include_options_do_not_skip_expected_validation() -> void:
	var artifact_path: String = _write_temp_text("freshness_projection", "actual artifact")
	var builder: GFArtifactFreshnessReport = GFArtifactFreshnessReport.new()
	var _artifact_entry: Dictionary = builder.add_artifact(&"config_json", artifact_path, {
		"expected_sha256": "0000000000000000000000000000000000000000000000000000000000000000",
		"minimum_modified_time": 9223372036854775807,
	})

	var report: Dictionary = builder.get_report({
		"include_sha256": false,
		"include_modified_time": false,
		"warnings_as_errors": true,
	})
	var result_artifacts: Array = GFVariantData.get_option_array(report, "artifacts")
	var artifact: Dictionary = GFVariantData.as_dictionary(result_artifacts[0])
	var hash_issue: Dictionary = _find_issue(report, "artifact_sha256_mismatch")
	var time_issue: Dictionary = _find_issue(report, "artifact_older_than_source")

	assert_false(GFVariantData.get_option_bool(report, "ok", true), "展示字段关闭时 expected 完整性条件仍必须执行。")
	assert_true(GFVariantData.get_option_bool(artifact, "stale"), "hash/time 任一不匹配都应标记 stale。")
	assert_false(artifact.has("sha256"), "include_sha256=false 应只隐藏输出字段。")
	assert_false(artifact.has("modified_time"), "include_modified_time=false 应只隐藏输出字段。")
	assert_false(hash_issue.is_empty(), "错误 expected hash 不得静默跳过。")
	assert_false(time_issue.is_empty(), "minimum modified time 不得静默跳过。")
	assert_false(hash_issue.has("actual_sha256"), "include_sha256=false 也不得从 issue 泄露实际 hash。")
	assert_false(time_issue.has("actual_modified_time"), "include_modified_time=false 也不得从 issue 泄露实际时间。")


func test_artifact_freshness_report_rejects_explicit_invalid_sha256() -> void:
	var artifact_path: String = _write_temp_text("freshness_invalid_sha", "actual artifact")
	var builder: GFArtifactFreshnessReport = GFArtifactFreshnessReport.new()
	var _artifact_entry: Dictionary = builder.add_artifact(&"config_json", artifact_path, {
		"expected_sha256": "abc",
	})

	var report: Dictionary = builder.get_report()

	assert_false(GFVariantData.get_option_bool(report, "ok"), "显式但非法的 SHA-256 不能降级为不校验。")
	assert_false(_find_issue(report, "artifact_sha256_invalid").is_empty(), "非法完整性元数据应有稳定 issue kind。")


func test_activation_transaction_rolls_back_applied_steps_on_failure() -> void:
	var events: PackedStringArray = PackedStringArray()
	var transaction: GFActivationTransaction = GFActivationTransaction.new()
	var _configured: GFActivationTransaction = transaction.configure(&"activate_content", "Content activation")
	var _first_added: bool = transaction.add_step(
		&"mount_registry",
		func(_context: Dictionary) -> bool:
			var _appended: bool = events.append("apply:mount")
			return true,
		func(_context: Dictionary) -> bool:
			var _appended: bool = events.append("rollback:mount")
			return true
	)
	var _second_added: bool = transaction.add_step(
		&"swap_catalog",
		func(_context: Dictionary) -> Dictionary:
			var _appended: bool = events.append("apply:swap")
			return {
				"ok": false,
				"kind": &"catalog_swap_failed",
				"message": "swap failed",
			}
	)

	var report: Dictionary = transaction.commit({ "profile": "test" })

	assert_false(GFVariantData.get_option_bool(report, "ok"), "任一步骤应用失败时事务报告应失败。")
	assert_eq(GFVariantData.get_option_string_name(report, "state"), GFActivationTransaction.STATE_ROLLED_BACK, "失败后应回滚已应用步骤。")
	assert_eq(events, PackedStringArray(["apply:mount", "apply:swap", "rollback:mount"]), "回滚应按已应用步骤逆序执行。")
	assert_false(_find_issue(report, "catalog_swap_failed").is_empty(), "步骤失败 issue 应进入事务报告。")
	assert_false(transaction.is_step_applied(&"swap_catalog"), "失败步骤不应被标记为已应用。")


func test_activation_transaction_reports_missing_required_rollback() -> void:
	var events: PackedStringArray = PackedStringArray()
	var transaction: GFActivationTransaction = GFActivationTransaction.new()
	var _configured: GFActivationTransaction = transaction.configure(&"activate_without_rollback")
	var _first_added: bool = transaction.add_step(
		&"write_cache",
		func(_context: Dictionary) -> bool:
			var _appended: bool = events.append("apply:cache")
			return true
	)
	var _second_added: bool = transaction.add_step(
		&"publish_cache",
		func(_context: Dictionary) -> bool:
			var _appended: bool = events.append("apply:publish")
			return false
	)

	var report: Dictionary = transaction.commit()

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺少必要 rollback 时事务报告应失败。")
	assert_eq(GFVariantData.get_option_string_name(report, "state"), GFActivationTransaction.STATE_FAILED, "无法完整回滚时事务应进入 failed。")
	assert_false(_find_issue(report, "missing_rollback_callback").is_empty(), "缺少 rollback callback 应有稳定 issue kind。")


func test_activation_transaction_commits_all_steps_when_successful() -> void:
	var events: PackedStringArray = PackedStringArray()
	var transaction: GFActivationTransaction = GFActivationTransaction.new()
	var _configured: GFActivationTransaction = transaction.configure(&"activate_config")
	var _first_added: bool = transaction.add_step(
		&"prepare_config",
		func(_context: Dictionary) -> bool:
			var _appended: bool = events.append("apply:prepare")
			return true
	)
	var _second_added: bool = transaction.add_step(
		&"publish_config",
		func(_context: Dictionary) -> bool:
			var _appended: bool = events.append("apply:publish")
			return true
	)

	var report: Dictionary = transaction.commit()

	assert_true(GFVariantData.get_option_bool(report, "ok"), "全部步骤成功时事务报告应通过。")
	assert_eq(GFVariantData.get_option_string_name(report, "state"), GFActivationTransaction.STATE_COMMITTED, "全部步骤成功后应进入 committed。")
	assert_eq(events, PackedStringArray(["apply:prepare", "apply:publish"]), "成功事务不应执行回滚。")


func test_activation_transaction_commit_is_terminal_and_not_reapplied() -> void:
	var events: PackedStringArray = PackedStringArray()
	var transaction: GFActivationTransaction = GFActivationTransaction.new()
	var _configured: GFActivationTransaction = transaction.configure(&"activate_once")
	var _step_added: bool = transaction.add_step(
		&"publish",
		func(_context: Dictionary) -> bool:
			var _appended: bool = events.append("apply")
			return true
	)

	var first_report: Dictionary = transaction.commit()
	var second_report: Dictionary = transaction.commit()

	assert_true(GFVariantData.get_option_bool(first_report, "ok"), "首次提交应成功。")
	assert_true(GFVariantData.get_option_bool(second_report, "ok"), "已提交事务再次读取报告应保持成功状态。")
	assert_eq(events, PackedStringArray(["apply"]), "已提交事务不能重复执行 step。")
	assert_false(transaction.add_step(&"late", func() -> void: pass), "committed 终态不应接受新步骤。")


func test_activation_transaction_prepare_cannot_reopen_terminal_state() -> void:
	var counts: Dictionary = { "apply": 0 }
	var transaction: GFActivationTransaction = GFActivationTransaction.new()
	var _step_added: bool = transaction.add_step(
		&"publish",
		func(_context: Dictionary) -> bool:
			counts["apply"] = GFVariantData.get_option_int(counts, "apply") + 1
			return true
	)

	var _first_report: Dictionary = transaction.commit()
	var prepare_report: Dictionary = transaction.prepare()
	var second_report: Dictionary = transaction.commit()

	assert_eq(GFVariantData.get_option_int(counts, "apply"), 1, "terminal prepare 不得让已提交 step 再执行。")
	assert_eq(transaction.state, GFActivationTransaction.STATE_COMMITTED, "无效 prepare 不得改变 committed 终态。")
	assert_false(GFVariantData.get_option_bool(prepare_report, "ok", true), "terminal prepare 应结构化拒绝。")
	assert_eq(GFVariantData.get_option_string(prepare_report, "error"), "transaction_not_reusable", "terminal prepare 应给出稳定错误。")
	assert_true(GFVariantData.get_option_bool(second_report, "ok"), "无效 prepare 不应污染已提交事务的既有成功报告。")


func test_activation_transaction_prepare_rejects_rolled_back_and_failed_states() -> void:
	var rolled_back: GFActivationTransaction = GFActivationTransaction.new()
	var _rolled_step_added: bool = rolled_back.add_step(
		&"publish",
		func(_context: Dictionary) -> bool:
			return true,
		func(_context: Dictionary) -> bool:
			return true
	)
	var _committed_report: Dictionary = rolled_back.commit()
	var _rolled_back_report: Dictionary = rolled_back.rollback()
	var rolled_prepare_report: Dictionary = rolled_back.prepare()

	var failed: GFActivationTransaction = GFActivationTransaction.new()
	var _failed_step_added: bool = failed.add_step(
		&"validate",
		func(_context: Dictionary) -> bool:
			return true,
		Callable(),
		{
			"validate_callback": func(_context: Dictionary) -> bool:
				return false,
		}
	)
	var _failed_report: Dictionary = failed.prepare()
	var failed_prepare_report: Dictionary = failed.prepare()

	assert_eq(rolled_back.state, GFActivationTransaction.STATE_ROLLED_BACK, "prepare 不得重新打开 rolled_back 终态。")
	assert_eq(failed.state, GFActivationTransaction.STATE_FAILED, "prepare 不得重新打开 failed 终态。")
	assert_eq(
		GFVariantData.get_option_string(rolled_prepare_report, "error"),
		"transaction_not_reusable",
		"rolled_back 终态应结构化拒绝 prepare。"
	)
	assert_eq(
		GFVariantData.get_option_string(failed_prepare_report, "error"),
		"transaction_not_reusable",
		"failed 终态应结构化拒绝 prepare。"
	)


func test_activation_transaction_rejects_callback_reentrancy_without_duplicate_side_effects() -> void:
	var transaction: GFActivationTransaction = GFActivationTransaction.new()
	var counts: Dictionary = {
		"validate": 0,
		"apply": 0,
		"rollback": 0,
	}
	var attempted: Dictionary = {
		"validate": false,
		"apply": false,
		"rollback": false,
	}
	var nested_reports: Dictionary = {}
	var _step_added: bool = transaction.add_step(
		&"publish",
		func(_context: Dictionary) -> bool:
			counts["apply"] = GFVariantData.get_option_int(counts, "apply") + 1
			if not GFVariantData.get_option_bool(attempted, "apply"):
				attempted["apply"] = true
				nested_reports["commit"] = transaction.commit()
			transaction.clear()
			return true,
		func(_context: Dictionary) -> bool:
			counts["rollback"] = GFVariantData.get_option_int(counts, "rollback") + 1
			if not GFVariantData.get_option_bool(attempted, "rollback"):
				attempted["rollback"] = true
				nested_reports["rollback"] = transaction.rollback()
			return true,
		{
			"validate_callback": func(_context: Dictionary) -> bool:
				counts["validate"] = GFVariantData.get_option_int(counts, "validate") + 1
				if not GFVariantData.get_option_bool(attempted, "validate"):
					attempted["validate"] = true
					nested_reports["prepare"] = transaction.prepare()
				return true,
		}
	)

	var commit_report: Dictionary = transaction.commit()
	var rollback_report: Dictionary = transaction.rollback()

	assert_true(GFVariantData.get_option_bool(commit_report, "ok"), "被拒绝的嵌套调用不应使合法外层提交失败。")
	assert_true(GFVariantData.get_option_bool(rollback_report, "ok"), "合法外层 rollback 应完成。")
	assert_eq(counts, { "validate": 1, "apply": 1, "rollback": 1 }, "每个 phase callback 在一个 transition 中最多执行一次。")
	for operation: String in ["prepare", "commit", "rollback"]:
		var nested_report: Dictionary = GFVariantData.get_option_dictionary(nested_reports, operation)
		assert_false(GFVariantData.get_option_bool(nested_report, "ok", true), "嵌套 %s 必须失败关闭。" % operation)
		assert_eq(GFVariantData.get_option_string(nested_report, "error"), "transition_in_progress", "嵌套调用应给出统一 transition 错误。")
	assert_eq(transaction.state, GFActivationTransaction.STATE_ROLLED_BACK, "callback 中的 clear 不得重置 in-flight 事务。")
	transaction.clear()


func test_activation_transaction_freezes_steps_after_prepare() -> void:
	var transaction: GFActivationTransaction = GFActivationTransaction.new()
	var _initial_step: bool = transaction.add_step(&"initial", func() -> void: pass)
	var report: Dictionary = transaction.prepare()

	assert_true(GFVariantData.get_option_bool(report, "ok"), "初始事务应成功 prepare。")
	assert_false(transaction.add_step(&"late", func() -> void: pass), "prepared 事务的步骤集合必须冻结。")


func test_activation_transaction_rejects_async_callback_results() -> void:
	var transaction: GFActivationTransaction = GFActivationTransaction.new()
	var _configured: GFActivationTransaction = transaction.configure(&"activate_async_callback")
	var _step_added: bool = transaction.add_step(
		&"validate_async",
		func(_context: Dictionary) -> bool:
			return true,
		Callable(),
		{
			"validate_callback": func(_context: Dictionary) -> Signal:
				return async_callback_placeholder,
		}
	)

	var report: Dictionary = transaction.prepare()

	assert_false(GFVariantData.get_option_bool(report, "ok"), "同步事务不应隐式接受 async callback。")
	assert_eq(GFVariantData.get_option_string_name(report, "state"), GFActivationTransaction.STATE_FAILED, "async callback 应使事务进入 failed。")
	assert_false(
		_find_issue(report, String(GFActivationTransaction.KIND_ASYNC_CALLBACK_UNSUPPORTED)).is_empty(),
		"async callback 应报告稳定 unsupported issue kind。"
	)


# --- 私有/辅助方法 ---

func _write_temp_text(label: String, text: String) -> String:
	var directory_path: String = "res://ai_analysis/godot_logs"
	var _directory_created: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory_path))
	var path: String = "%s/gf_%s_%d.txt" % [directory_path, label, Time.get_ticks_usec()]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试文件应可写入。")
	if file != null:
		var _stored: bool = file.store_string(text)
		file.close()
	var _tracked: bool = _temp_paths.append(path)
	return path


func _read_file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size_bytes: int = int(file.get_length())
	file.close()
	return size_bytes


func _framework_version_is_at_least(actual: String, minimum: String) -> bool:
	var profile: GFCompatibilityProfile = GFCompatibilityProfile.new()
	profile.framework_version = actual
	var preflight: GFCompatibilityPreflight = GFCompatibilityPreflight.new().configure("SemVer comparison", profile)
	var check: Dictionary = preflight.require_framework_version(minimum)
	return GFVariantData.get_option_bool(check, "ok", false)


func _find_issue(report: Dictionary, kind: String) -> Dictionary:
	for issue_value: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return issue
	return {}
