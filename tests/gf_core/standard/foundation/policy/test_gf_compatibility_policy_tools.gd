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


func _find_issue(report: Dictionary, kind: String) -> Dictionary:
	for issue_value: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return issue
	return {}
