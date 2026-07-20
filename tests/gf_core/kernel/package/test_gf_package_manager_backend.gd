extends GutTest


# --- 常量 ---

const GF_PACKAGE_MANAGER_BACKEND = preload("res://addons/gf/kernel/package/gf_package_manager_backend.gd")
const GF_PACKAGE_TRANSACTION_ENGINE = preload("res://addons/gf/kernel/package/gf_package_transaction_engine.gd")
const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const TEST_ROOT: String = "res://ai_analysis/tmp_package_manager_backend"


class BinaryReferenceResource:
	extends Resource

	@export var dependency: Resource


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_remove_path_recursive(TEST_ROOT)
	var _make_result: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT))


func after_each() -> void:
	_remove_path_recursive(TEST_ROOT)


# --- 测试用例 ---

func test_native_transaction_report_matches_shared_schema_contract() -> void:
	var schema: Dictionary = _read_json("res://addons/gf/kernel/package/gf_package_transaction_schema.json")
	var report: Dictionary = GF_PACKAGE_TRANSACTION_ENGINE.make_empty_report("recover")
	var expected_fields: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(schema, "report_fields")
	var actual_fields: PackedStringArray = PackedStringArray()
	for raw_key: Variant in report.keys():
		var _append_key: bool = actual_fields.append(GF_VARIANT_ACCESS.to_text(raw_key))
	expected_fields.sort()
	actual_fields.sort()

	assert_eq(GF_VARIANT_ACCESS.get_option_int(schema, "schema_version"), 1, "事务 schema 应使用当前版本。")
	assert_eq(actual_fields, expected_fields, "Godot 事务报告字段必须与共享 schema 完全一致。")


func test_native_recovery_blocks_live_transaction_owner() -> void:
	var project_root: String = TEST_ROOT.path_join("transaction_live_owner_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var interrupted: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		"manual",
		false,
		{ "simulate_transaction_crash_at": "after_prepared" }
	)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(interrupted, "ok"), "故障注入应留下 prepared journal。")
	var active_root: String = project_root.path_join(".gf/package_transactions/active")
	var journal_path: String = _latest_journal_path(active_root)
	var journal: Dictionary = _read_json(journal_path)
	journal["owner_pid"] = OS.get_process_id()
	journal["fault_injected"] = false
	_write_json(journal_path, journal)

	var blocked: Dictionary = GF_PACKAGE_MANAGER_BACKEND.recover_package_transaction(
		ProjectSettings.globalize_path(project_root)
	)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(blocked, "ok"), "恢复入口不得接管仍由活进程持有的事务。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(blocked, "outcome"), "blocked", "活事务应报告 blocked。")
	assert_true(_directory_exists(active_root), "并发阻断不能删除活动 journal。")

	journal["owner_pid"] = 0
	_write_json(journal_path, journal)
	var recovered: Dictionary = GF_PACKAGE_MANAGER_BACKEND.recover_package_transaction(
		ProjectSettings.globalize_path(project_root)
	)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(recovered, "ok"), "owner 失效后应允许恢复。")
	assert_false(_directory_exists(active_root), "恢复后应清理 active journal。")


func test_native_status_reports_cancelled_option() -> void:
	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		TEST_ROOT.path_join("missing_registry.json"),
		ProjectSettings.globalize_path(TEST_ROOT.path_join("cancelled_project")),
		".gf/packages.lock.json",
		{ "cancel_requested": true }
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "取消后的状态读取不应报告成功。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "cancelled"), "结果应明确标记 cancelled。")
	assert_true(GF_VARIANT_ACCESS.get_option_packed_string_array(result, "issues").has("Package manager operation was cancelled."), "结果应包含取消原因。")


func test_native_status_reads_local_registry_and_preset_preview() -> void:
	var project_root: String = TEST_ROOT.path_join("empty_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	_write_json(registry_path, _make_fixture_registry())

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var packages: Dictionary = _package_index(status)
	var preset_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(packages, "gf.preset.save")
	var install_preview: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(preset_entry, "install_preview")
	var to_install: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(install_preview, "to_install")
	var plan_entries: Array = GF_VARIANT_ACCESS.get_option_array(install_preview, "plan_entries")
	var plan_summary: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(install_preview, "plan_summary")
	var preset_plan_entry: Dictionary = _find_plan_entry(plan_entries, "gf.preset.save")
	var save_plan_entry: Dictionary = _find_plan_entry(plan_entries, "gf.extension.save")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "本地 registry 状态读取应成功。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(status, "backend"), "godot_native", "状态页应标明使用 Godot 原生后端。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status, "package_count"), 5, "状态页应列出 registry 中的全部包。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status, "installed_count"), 0, "空项目不应报告已安装包。")
	assert_true(to_install.has("gf.kernel"), "preset 安装预览应展开 kernel 依赖。")
	assert_true(to_install.has("gf.standard.storage"), "preset 安装预览应展开 standard 依赖。")
	assert_true(to_install.has("gf.extension.save"), "preset 安装预览应展开扩展包。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(plan_summary, "entry_count"), plan_entries.size(), "计划摘要应统计逐包条目。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(preset_plan_entry, "action"), "install", "请求的 preset 应报告 install 动作。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(preset_plan_entry, "requested"), "根请求包应标记 requested。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(save_plan_entry, "action"), "install", "依赖扩展包应报告 install 动作。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(save_plan_entry, "requested"), "依赖包不应误标记 requested。")
	assert_true(GF_VARIANT_ACCESS.get_option_packed_string_array(save_plan_entry, "decision_reasons").has("dependency"), "依赖包应暴露 dependency 计划原因。")


func test_native_status_exposes_dependency_uninstall_blocker() -> void:
	var project_root: String = TEST_ROOT.path_join("dependency_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var lockfile_path: String = project_root.path_join(".gf/packages.lock.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_json(registry_path, registry)
	_write_json(lockfile_path, _make_planned_lockfile(registry, PackedStringArray(["gf.extension.save"])))

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var storage_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(_package_index(status), "gf.standard.storage")
	var uninstall_preview: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(storage_entry, "uninstall_preview")
	var blocked: Array = GF_VARIANT_ACCESS.get_option_array(uninstall_preview, "blocked")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(storage_entry, "installed"), "被扩展依赖的 standard 包应显示已安装。")
	assert_true(GF_VARIANT_ACCESS.get_option_packed_string_array(storage_entry, "reason").has("dependency"), "共享依赖应保留 dependency reason。")
	assert_true(GF_VARIANT_ACCESS.get_option_packed_string_array(storage_entry, "required_by").has("gf.extension.save"), "状态应展示 required_by 边。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(uninstall_preview, "ok"), "仍被依赖的包不应允许普通卸载。")
	assert_true(_blocked_contains_reason(blocked, "required_by"), "卸载预览应暴露 required_by 阻断。")


func test_native_status_exposes_project_reference_uninstall_blocker() -> void:
	var project_root: String = TEST_ROOT.path_join("reference_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_package_archive(
		registry,
		"gf.standard.storage",
		{
			"addons/gf/standard/utilities/storage/gf_storage_fixture.gd": "class_name GFStorageUtility\nextends RefCounted\n",
		}
	)
	_write_json(registry_path, registry)
	var install_result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.standard.storage"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	_write_text(
		project_root.path_join("scripts/use_storage.gd"),
		"extends Node\nvar storage: GFStorageUtility\n"
	)

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var storage_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(_package_index(status), "gf.standard.storage")
	var uninstall_preview: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(storage_entry, "uninstall_preview")
	var blocked: Array = GF_VARIANT_ACCESS.get_option_array(uninstall_preview, "blocked")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(install_result, "ok"), "测试 fixture 应通过真实安装生成完整 lockfile。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "项目引用扫描不应让状态读取失败。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(uninstall_preview, "ok"), "仍被项目脚本引用的包不应允许普通卸载。")
	assert_true(_blocked_contains_reason(blocked, "project_references"), "卸载预览应暴露项目引用阻断。")


func test_native_install_local_archives_writes_files_and_lockfile() -> void:
	var project_root: String = TEST_ROOT.path_join("install_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))
	var installed: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "installed")
	var registry_source: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "registry_source")
	var save_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(installed, "gf.extension.save")
	var save_files: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(save_entry, "files")
	var save_file_metadata: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(save_entry, "file_metadata")
	var save_fixture_metadata: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(
		save_file_metadata,
		"addons/gf/extensions/save/gf_save_fixture.gd"
	)

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "Godot 原生后端应能安装本地 archive 闭包。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(result, "backend"), "godot_native", "安装结果应标记 Godot 原生后端。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(result, "installed_file_count"), 4, "四个非 preset 包各包含一个 fixture 文件。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "lockfile_written"), "真实安装应最后写入 lockfile。")
	assert_true(_file_exists(project_root.path_join("addons/gf/kernel/core/gf_core_fixture.gd")), "kernel fixture 应写入项目。")
	assert_true(_file_exists(project_root.path_join("addons/gf/standard/foundation/gf_base_fixture.gd")), "standard base fixture 应写入项目。")
	assert_true(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "extension fixture 应写入项目。")
	assert_true(installed.has("gf.standard.storage"), "lockfile 应记录扩展依赖的 standard 包。")
	assert_true(save_files.has("addons/gf/extensions/save/gf_save_fixture.gd"), "lockfile 应记录包安装文件清单。")
	assert_true(GF_VARIANT_ACCESS.get_option_int(save_fixture_metadata, "size_bytes") > 0, "lockfile 应记录安装文件大小。")
	assert_false(GF_VARIANT_ACCESS.get_option_string(save_fixture_metadata, "sha256").is_empty(), "lockfile 应记录安装文件 sha256。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(registry_source, "source"), registry_path, "lockfile 应记录安装使用的 registry 来源。")


func test_native_install_cleans_hidden_archive_staging_files() -> void:
	var project_root: String = TEST_ROOT.path_join("hidden_archive_install_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_package_archive(
		registry,
		"gf.extension.save",
		{
			"addons/gf/extensions/save/.gdignore": "# Keep authoring-only files outside the Godot resource graph.\n",
			"addons/gf/extensions/save/gf_save_fixture.gd": "extends RefCounted\n",
		}
	)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var staging_files: PackedStringArray = PackedStringArray()
	_collect_files_absolute(
		ProjectSettings.globalize_path(project_root.path_join(".gf/t")),
		staging_files
	)

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "合法隐藏文件不应阻断 package 安装。")
	assert_true(_file_exists(project_root.path_join("addons/gf/extensions/save/.gdignore")), "隐藏 package 文件必须安装到最终目标。")
	assert_true(staging_files.is_empty(), "事务完成后不得在 .gf/t 留下隐藏 staging 文件：%s" % [staging_files])


func test_native_verify_accepts_round_tripped_lockfile_integer_fields() -> void:
	var project_root: String = TEST_ROOT.path_join("verify_round_trip_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var install_result: Dictionary = _install_fixture_save(registry_path, project_root)

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var lockfile_verify: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(status, "lockfile_verify")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(install_result, "ok"), "测试 fixture 应先完成安装。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "原生后端必须接受自身 JSON round-trip 后的整数 schema 字段。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(lockfile_verify, "ok"), "round-trip lockfile 的完整 identity schema 应通过验证。")


func test_native_install_refuses_to_overwrite_unowned_existing_gf_file() -> void:
	var project_root: String = TEST_ROOT.path_join("install_unowned_existing_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	_write_text(
		project_root.path_join("addons/gf/kernel/core/gf_core_fixture.gd"),
		"extends RefCounted\nconst PROJECT_FILE := true\n"
	)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var issues: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(result, "issues")

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "安装不应覆盖 lockfile 未拥有的 GF 目标文件。")
	assert_true(_issues_contain(issues, "not owned by the lockfile"), "未归属目标文件应进入 issues。")
	assert_false(_file_exists(project_root.path_join(".gf/packages.lock.json")), "失败安装不能写 lockfile。")
	assert_true(_read_text(project_root.path_join("addons/gf/kernel/core/gf_core_fixture.gd")).contains("PROJECT_FILE"), "原项目文件应保持不变。")


func test_native_install_adopts_complete_matching_extracted_kernel() -> void:
	var project_root: String = TEST_ROOT.path_join("install_unowned_matching_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	_write_text(
		project_root.path_join("addons/gf/kernel/core/gf_core_fixture.gd"),
		"extends RefCounted\n"
	)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))
	var installed: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "installed")
	var kernel_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(installed, "gf.kernel")
	var kernel_reasons: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(kernel_entry, "reason")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "首次安装应接管与可信归档完整一致的已解压 gf.kernel。")
	assert_true(installed.has("gf.kernel"), "接管后 lockfile 应记录 gf.kernel ownership。")
	assert_true(kernel_reasons.has("bundled"), "被接管的 bootstrap kernel 应保持 bundled reason。")
	assert_eq(_read_text(project_root.path_join("addons/gf/kernel/core/gf_core_fixture.gd")), "extends RefCounted\n", "接管不得改变已解压内核内容。")


func test_native_install_selects_concrete_packages_by_kind_filters() -> void:
	var project_root: String = TEST_ROOT.path_join("selector_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(),
		registry_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		"manual",
		false,
		{
			"all_concrete": true,
			"exclude_kinds": PackedStringArray(["extension"]),
		}
	)
	var lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))
	var installed: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "installed")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "安装选择器应能在没有显式 package id 时选择目标。")
	assert_true(installed.has("gf.kernel"), "all_concrete 应包含 kernel。")
	assert_true(installed.has("gf.standard.base"), "all_concrete 应包含 standard。")
	assert_true(installed.has("gf.standard.storage"), "all_concrete 应包含另一个 standard。")
	assert_false(installed.has("gf.extension.save"), "exclude_kinds 应排除 extension。")
	assert_false(installed.has("gf.preset.save"), "all_concrete 不应安装 preset。")


func test_native_install_dry_run_validates_archives_without_mutating_project() -> void:
	var project_root: String = TEST_ROOT.path_join("dry_run_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		"manual",
		true
	)
	var plan_entries: Array = GF_VARIANT_ACCESS.get_option_array(result, "plan_entries")
	var plan_summary: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(result, "plan_summary")
	var save_entry: Dictionary = _find_plan_entry(plan_entries, "gf.extension.save")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "dry-run 应完成计划与 archive 元数据校验。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "dry_run"), "结果应标记 dry-run。")
	assert_false(plan_entries.is_empty(), "dry-run 结果应暴露逐包计划条目。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(save_entry, "action"), "install", "dry-run 计划应说明目标包会被安装。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(save_entry, "requested"), "dry-run 计划应保留根请求包。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(plan_summary, "archive_required_count"), 4, "计划摘要应统计需要 archive 校验的包。")
	assert_false(_file_exists(project_root.path_join(".gf/packages.lock.json")), "dry-run 不应写 lockfile。")
	assert_false(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "dry-run 不应写包文件。")


func test_native_install_rejects_lockfile_path_outside_project_root() -> void:
	var project_root: String = TEST_ROOT.path_join("escaped_lockfile_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root),
		"../outside.lock"
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "lockfile 路径不能越过项目根目录。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(result, "issues"),
			"Lockfile path must stay inside project root"
		),
		"越界 lockfile 路径应进入 issues。"
	)
	assert_false(_file_exists(TEST_ROOT.path_join("outside.lock")), "越界 lockfile 失败时不能写入项目外文件。")


func test_native_status_rejects_unsafe_registry_package_ids() -> void:
	var project_root: String = TEST_ROOT.path_join("unsafe_id_status_project")
	var registry_path: String = TEST_ROOT.path_join("unsafe_id_registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	var packages: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(registry, "packages")
	var save_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(packages, "gf.extension.save")
	packages["gf.extension.save/../../escape"] = save_entry
	var _erase_save: bool = packages.erase("gf.extension.save")
	registry["packages"] = packages
	_write_json(registry_path, registry)

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var package_index: Dictionary = _package_index(status)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "不安全 package id 应让 registry 状态失败。")
	assert_false(package_index.has("gf.extension.save/../../escape"), "不安全 package id 不能进入可安装列表。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(status, "issues"),
			"invalid package id"
		),
		"非法 package id 应进入 issues。"
	)


func test_native_update_all_installed_updates_changed_package_without_manual_pinning_dependency() -> void:
	var project_root: String = TEST_ROOT.path_join("update_all_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var install_result: Dictionary = _install_fixture_save(registry_path, project_root)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(install_result, "ok"), "测试 fixture 应先完成安装。")

	_write_package_archive(
		registry,
		"gf.standard.storage",
		{
			"addons/gf/standard/utilities/storage/gf_storage_fixture.gd": "extends RefCounted\nconst UPDATED_FIXTURE := true\n",
		}
	)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.update_packages(
		PackedStringArray(),
		registry_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		true
	)
	var to_update: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(result, "to_update")
	var updated_packages: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(result, "updated_packages")
	var storage_source: String = _read_text(project_root.path_join("addons/gf/standard/utilities/storage/gf_storage_fixture.gd"))
	var lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))
	var installed: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "installed")
	var storage_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(installed, "gf.standard.storage")
	var storage_reasons: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(storage_entry, "reason")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "更新全部已安装包应成功。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "all_installed"), "结果应标记 update-all。")
	assert_true(to_update.has("gf.standard.storage"), "变更 sha 的已安装包应出现在 to_update。")
	assert_true(updated_packages.has("gf.standard.storage"), "变更包应出现在 updated_packages。")
	assert_true(storage_source.contains("UPDATED_FIXTURE"), "更新应覆盖 package 文件。")
	assert_true(storage_reasons.has("dependency"), "被依赖包更新后仍应保留 dependency reason。")
	assert_false(storage_reasons.has("manual"), "update-all 不应把依赖包误标为 manual。")


func test_native_update_all_installed_ignores_lockfile_key_order_only_changes() -> void:
	var project_root: String = TEST_ROOT.path_join("update_all_lockfile_order_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var lockfile_path: String = project_root.path_join(".gf/packages.lock.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var install_result: Dictionary = _install_fixture_save(registry_path, project_root)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(install_result, "ok"), "测试 fixture 应先完成安装。")
	var lockfile: Dictionary = _read_json(lockfile_path)
	var scrambled_lockfile: Dictionary = {}
	var installed: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "installed")
	var scrambled_installed: Dictionary = {}
	var installed_keys: PackedStringArray = _sorted_dictionary_keys(installed)
	installed_keys.reverse()
	for package_id: String in installed_keys:
		scrambled_installed[package_id] = GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
	scrambled_lockfile["installed"] = scrambled_installed
	if lockfile.has("registry_source"):
		scrambled_lockfile["registry_source"] = GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "registry_source")
	scrambled_lockfile["framework_version"] = GF_VARIANT_ACCESS.get_option_string(lockfile, "framework_version")
	scrambled_lockfile["schema_version"] = GF_VARIANT_ACCESS.get_option_int(lockfile, "schema_version")
	_write_json(lockfile_path, scrambled_lockfile)
	var before_text: String = _read_text(lockfile_path)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.update_packages(
		PackedStringArray(),
		registry_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		true
	)
	var after_text: String = _read_text(lockfile_path)

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "无 payload 变化的 update-all 应成功。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "lockfile_written"), "仅 key 顺序不同不应触发 lockfile 写入。")
	assert_eq(after_text, before_text, "仅 key 顺序不同的 lockfile 应保持原文本。")


func test_native_update_removes_obsolete_package_files_when_old_hash_matches() -> void:
	var project_root: String = TEST_ROOT.path_join("update_obsolete_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var install_result: Dictionary = _install_fixture_save(registry_path, project_root)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(install_result, "ok"), "测试 fixture 应先完成安装。")

	_write_package_archive(
		registry,
		"gf.extension.save",
		{
			"addons/gf/extensions/save/gf_save_fixture_v2.gd": "extends RefCounted\nconst UPDATED_FIXTURE := true\n",
		}
	)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.update_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))
	var installed: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "installed")
	var save_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(installed, "gf.extension.save")
	var save_files: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(save_entry, "files")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "更新应能清理旧版本已移除的 package 文件。")
	assert_false(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "旧版本移除的文件应被删除。")
	assert_true(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture_v2.gd")), "新版本文件应被写入。")
	assert_false(save_files.has("addons/gf/extensions/save/gf_save_fixture.gd"), "lockfile 不应保留旧文件清单。")
	assert_true(save_files.has("addons/gf/extensions/save/gf_save_fixture_v2.gd"), "lockfile 应记录新文件清单。")


func test_native_update_refuses_to_delete_modified_obsolete_package_file() -> void:
	var project_root: String = TEST_ROOT.path_join("update_modified_obsolete_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var install_result: Dictionary = _install_fixture_save(registry_path, project_root)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(install_result, "ok"), "测试 fixture 应先完成安装。")
	_write_text(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd"), "extends RefCounted\nconst USER_MODIFIED := true\n")

	_write_package_archive(
		registry,
		"gf.extension.save",
		{
			"addons/gf/extensions/save/gf_save_fixture_v2.gd": "extends RefCounted\nconst UPDATED_FIXTURE := true\n",
		}
	)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.update_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "用户改动过的旧文件不能被 update 静默删除。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(result, "issues"),
			"obsolete installed file was modified"
		),
		"拒绝删除用户改动文件时应进入 issues。"
	)
	assert_true(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "被用户改动的旧文件应保留。")
	assert_false(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture_v2.gd")), "拒绝更新时不应写入新文件。")


func test_native_update_refuses_to_overwrite_modified_existing_package_file() -> void:
	var project_root: String = TEST_ROOT.path_join("update_modified_existing_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var install_result: Dictionary = _install_fixture_save(registry_path, project_root)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(install_result, "ok"), "测试 fixture 应先完成安装。")
	var fixture_path: String = project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")
	_write_text(fixture_path, "extends RefCounted\nconst USER_MODIFIED := true\n")

	_write_package_archive(
		registry,
		"gf.extension.save",
		{
			"addons/gf/extensions/save/gf_save_fixture.gd": "extends RefCounted\nconst UPDATED_FIXTURE := true\n",
		}
	)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.update_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "用户改动过的同路径文件不能被 update 静默覆盖。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(result, "issues"),
			"installed file was modified"
		),
		"拒绝覆盖用户改动文件时应进入 issues。"
	)
	assert_true(_read_text(fixture_path).contains("USER_MODIFIED"), "拒绝更新时应保留用户改动内容。")


func test_native_install_existing_package_refuses_to_overwrite_modified_existing_package_file() -> void:
	var project_root: String = TEST_ROOT.path_join("install_existing_modified_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var install_result: Dictionary = _install_fixture_save(registry_path, project_root)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(install_result, "ok"), "测试 fixture 应先完成安装。")
	var fixture_path: String = project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")
	_write_text(fixture_path, "extends RefCounted\nconst USER_MODIFIED := true\n")

	_write_package_archive(
		registry,
		"gf.extension.save",
		{
			"addons/gf/extensions/save/gf_save_fixture.gd": "extends RefCounted\nconst UPDATED_FIXTURE := true\n",
		}
	)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "已安装包通过 install 变更时也不能覆盖用户改动。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(result, "issues"),
			"installed file was modified"
		),
		"拒绝覆盖用户改动文件时应进入 install issues。"
	)
	assert_true(_read_text(fixture_path).contains("USER_MODIFIED"), "拒绝 install-as-update 时应保留用户改动内容。")


func test_native_install_uses_compact_staging_under_long_project_root() -> void:
	var long_project_name: String = "long_project_%s" % "x".repeat(70)
	var project_root: String = TEST_ROOT.path_join(long_project_name)
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)

	var result: Dictionary = _install_fixture_save(registry_path, project_root)

	assert_true(
		GF_VARIANT_ACCESS.get_option_bool(result, "ok"),
		"原生 staging 的内部命名不应让较长项目路径越过 Windows 路径预算：%s" % str(result.get("issues", []))
	)
	assert_true(
		FileAccess.file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")),
		"长项目路径安装应落地扩展 payload。"
	)


func test_native_install_existing_dependency_manual_pin_writes_only_lockfile() -> void:
	var project_root: String = TEST_ROOT.path_join("install_existing_dependency_pin_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var install_result: Dictionary = _install_fixture_save(registry_path, project_root)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(install_result, "ok"), "测试 fixture 应先完成安装。")
	var baseline_lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))
	var baseline_installed: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(baseline_lockfile, "installed")
	var baseline_storage_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(baseline_installed, "gf.standard.storage")
	var baseline_storage_metadata: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(baseline_storage_entry, "file_metadata")
	var storage_fixture_path: String = project_root.path_join("addons/gf/standard/utilities/storage/gf_storage_fixture.gd")
	_write_text(storage_fixture_path, "extends RefCounted\nconst USER_MODIFIED := true\n")
	_remove_path_recursive(TEST_ROOT.path_join("registry/packages/gf-standard-storage.zip"))

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.standard.storage"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))
	var installed: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "installed")
	var storage_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(installed, "gf.standard.storage")
	var storage_metadata: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(storage_entry, "file_metadata")
	var storage_reasons: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(storage_entry, "reason")
	var to_update: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(result, "to_update")
	var plan_entries: Array = GF_VARIANT_ACCESS.get_option_array(result, "plan_entries")
	var storage_plan_entry: Dictionary = _find_plan_entry(plan_entries, "gf.standard.storage")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "已安装依赖被手动 install 时应只补 manual reason。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "lockfile_written"), "metadata-only install 应写入 lockfile。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(result, "installed_file_count"), 0, "metadata-only install 不应复制 package 文件。")
	assert_true(to_update.is_empty(), "仅 reason 变化不应进入 payload update 计划。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(storage_plan_entry, "action"), "metadata", "仅 reason 变化应在计划中标记为 metadata。")
	assert_true(storage_reasons.has("dependency"), "依赖 reason 应保留。")
	assert_true(storage_reasons.has("manual"), "手动安装已存在依赖时应补 manual reason。")
	assert_eq(storage_metadata, baseline_storage_metadata, "metadata-only install 必须保留未更新 payload 的完整安装基线。")
	assert_true(_read_text(storage_fixture_path).contains("USER_MODIFIED"), "metadata-only install 不应触碰已安装文件。")


func test_native_install_existing_package_removes_obsolete_files_like_update() -> void:
	var project_root: String = TEST_ROOT.path_join("install_existing_obsolete_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var install_result: Dictionary = _install_fixture_save(registry_path, project_root)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(install_result, "ok"), "测试 fixture 应先完成安装。")

	_write_package_archive(
		registry,
		"gf.extension.save",
		{
			"addons/gf/extensions/save/gf_save_fixture_v2.gd": "extends RefCounted\nconst UPDATED_FIXTURE := true\n",
		}
	)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))
	var installed: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "installed")
	var save_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(installed, "gf.extension.save")
	var save_files: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(save_entry, "files")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "已安装包通过 install 变更时应复用 update 的旧文件清理语义。")
	assert_false(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "install-as-update 应清理旧版本移除的文件。")
	assert_true(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture_v2.gd")), "install-as-update 应写入新版本文件。")
	assert_false(save_files.has("addons/gf/extensions/save/gf_save_fixture.gd"), "lockfile 不应保留旧文件清单。")
	assert_true(save_files.has("addons/gf/extensions/save/gf_save_fixture_v2.gd"), "lockfile 应记录新文件清单。")


func test_native_update_rejects_uninstalled_package_without_mutating_project() -> void:
	var project_root: String = TEST_ROOT.path_join("update_missing_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.update_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "未安装包不能通过 update 隐式安装。")
	assert_true(_issues_contain(GF_VARIANT_ACCESS.get_option_packed_string_array(result, "issues"), "Package is not installed"), "错误应提示使用 install 新增包。")
	assert_false(_file_exists(project_root.path_join(".gf/packages.lock.json")), "失败的 update 不能写 lockfile。")
	assert_false(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "失败的 update 不能写 package 文件。")


func test_native_status_marks_incompatible_registry_packages_not_installable() -> void:
	var project_root: String = TEST_ROOT.path_join("old_framework_status_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_set_registry_framework_range(registry, "9.0.0", "10.0.0")
	_write_json(registry_path, registry)
	_write_project_plugin_cfg(project_root, "1.0.0")

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var save_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(_package_index(status), "gf.extension.save")
	var install_preview: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(save_entry, "install_preview")

	assert_false(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "旧 GF 项目读取要求更高框架版本的 registry 应报告失败。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(save_entry, "can_install"), "不兼容包不应在状态页显示为可安装。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(install_preview, "ok"), "不兼容包的安装预览应失败。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(status, "issues"),
			"minimum_framework_version 9.0.0"
		),
		"状态 issues 应说明所需 GF 最小版本。"
	)


func test_native_status_orders_development_prerelease_before_stable_version() -> void:
	var project_root: String = TEST_ROOT.path_join("development_prerelease_status_project")
	var registry_path: String = TEST_ROOT.path_join("registry/development_prerelease.json")
	var registry: Dictionary = _make_fixture_registry()
	_set_registry_framework_range(registry, "8.2.0", "9.0.0")
	_write_json(registry_path, registry)
	_write_project_plugin_cfg(project_root, "8.2.0-dev.0")

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "SemVer prerelease 必须排在同 core 的稳定版本之前。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(status, "issues"),
			"minimum_framework_version 8.2.0"
		),
		"不兼容报告应保留稳定版本下界。"
	)


func test_native_status_accepts_newer_development_prerelease_within_range() -> void:
	var project_root: String = TEST_ROOT.path_join("newer_development_prerelease_status_project")
	var registry_path: String = TEST_ROOT.path_join("registry/newer_development_prerelease.json")
	var registry: Dictionary = _make_fixture_registry()
	_set_registry_framework_range(registry, "8.2.0-dev.0", "9.0.0")
	_write_json(registry_path, registry)
	_write_project_plugin_cfg(project_root, "8.2.0-dev.1")

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_true(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "更高 dev 序号应满足较低预发布下界并保持低于稳定上界。")


func test_native_status_rejects_next_compatibility_line_prerelease() -> void:
	var project_root: String = TEST_ROOT.path_join("next_line_prerelease_status_project")
	var registry_path: String = TEST_ROOT.path_join("registry/next_line_prerelease.json")
	var registry: Dictionary = _make_fixture_registry()
	_set_registry_framework_range(registry, "8.1.0", "9.0.0")
	_write_json(registry_path, registry)
	_write_project_plugin_cfg(project_root, "9.0.0-dev.0")

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "下一兼容线的预发布版本必须达到稳定排他上界。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(status, "issues"),
			"maximum_framework_version_exclusive 9.0.0"
		),
		"排他上界应覆盖相同 core 的预发布版本。"
	)


func test_native_status_rejects_malformed_non_empty_framework_version() -> void:
	var project_root: String = TEST_ROOT.path_join("malformed_framework_version_status_project")
	var registry_path: String = TEST_ROOT.path_join("registry/malformed_framework_version.json")
	var registry: Dictionary = _make_fixture_registry()
	_set_registry_framework_range(registry, "8.1.0", "9.0.0")
	_write_json(registry_path, registry)
	_write_project_plugin_cfg(project_root, "not-a-version")

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "非空损坏版本不能伪装成 bootstrap 项目绕过兼容性。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(status, "issues"),
			"target GF framework version is not SemVer: not-a-version"
		),
		"状态报告应明确指出损坏的当前框架版本。"
	)


func test_native_status_rejects_non_semver_version_prefix() -> void:
	var project_root: String = TEST_ROOT.path_join("prefixed_framework_version_status_project")
	var registry_path: String = TEST_ROOT.path_join("registry/prefixed_framework_version.json")
	var registry: Dictionary = _make_fixture_registry()
	_set_registry_framework_range(registry, "8.1.0", "9.0.0")
	_write_json(registry_path, registry)
	_write_project_plugin_cfg(project_root, "v8.2.0")

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "框架版本必须是严格 SemVer，不能接受 tag 风格前缀。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(status, "issues"),
			"target GF framework version is not SemVer: v8.2.0"
		),
		"版本前缀错误应进入状态报告。"
	)


func test_native_status_rejects_non_ascii_semver_digits() -> void:
	var project_root: String = TEST_ROOT.path_join("non_ascii_framework_version_status_project")
	var registry_path: String = TEST_ROOT.path_join("registry/non_ascii_framework_version.json")
	var registry: Dictionary = _make_fixture_registry()
	_set_registry_framework_range(registry, "8.1.0", "9.0.0")
	_write_json(registry_path, registry)
	_write_project_plugin_cfg(project_root, "8.2.0-\u0661")

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "SemVer 标识符只能使用 ASCII 数字。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(status, "issues"),
			"target GF framework version is not SemVer"
		),
		"非 ASCII 数字应作为版本格式错误报告。"
	)


func test_native_status_compares_semver_core_without_integer_overflow() -> void:
	var project_root: String = TEST_ROOT.path_join("large_semver_core_status_project")
	var registry_path: String = TEST_ROOT.path_join("registry/large_semver_core.json")
	var registry: Dictionary = _make_fixture_registry()
	_set_registry_framework_range(registry, "9223372036854775808.0.0", "")
	_write_json(registry_path, registry)
	_write_project_plugin_cfg(project_root, "9223372036854775807.0.0")

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "SemVer core 比较不能经过 int32/int64 截断。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(status, "issues"),
			"minimum_framework_version 9223372036854775808.0.0"
		),
		"超大合法数字标识符应保持正确的版本顺序。"
	)


func test_default_registry_source_matches_current_framework_version() -> void:
	var previous_override: String = OS.get_environment(GF_PACKAGE_MANAGER_BACKEND.DEFAULT_REGISTRY_SOURCE_ENV)
	OS.set_environment(GF_PACKAGE_MANAGER_BACKEND.DEFAULT_REGISTRY_SOURCE_ENV, "")
	var registry_source_url: String = GF_PACKAGE_MANAGER_BACKEND.get_default_registry_source_url()
	OS.set_environment(GF_PACKAGE_MANAGER_BACKEND.DEFAULT_REGISTRY_SOURCE_ENV, previous_override)
	var plugin_config: ConfigFile = ConfigFile.new()
	assert_eq(plugin_config.load("res://addons/gf/plugin.cfg"), OK, "测试应能读取当前框架版本。")
	var framework_version: String = str(plugin_config.get_value("plugin", "version", "")).strip_edges()

	assert_eq(
		registry_source_url,
		GF_PACKAGE_MANAGER_BACKEND._default_registry_source_url_for_version(framework_version),
		"默认 registry source 必须与当前框架版本通道一致。"
	)


func test_default_registry_source_version_resolution_distinguishes_release_channels() -> void:
	assert_eq(
		GF_PACKAGE_MANAGER_BACKEND._default_registry_source_url_for_version("9.0.0"),
		GF_PACKAGE_MANAGER_BACKEND.DEFAULT_REGISTRY_SOURCE_RELEASE_URL_TEMPLATE % "9.0.0",
		"稳定版本必须固定到同版本 GitHub Release。"
	)
	assert_eq(
		GF_PACKAGE_MANAGER_BACKEND._default_registry_source_url_for_version("9.0.0-dev.0"),
		GF_PACKAGE_MANAGER_BACKEND.DEFAULT_REGISTRY_SOURCE_LATEST_URL,
		"开发版本不能拼接一个尚不存在的版本化 GitHub Release URL。"
	)
	assert_eq(
		GF_PACKAGE_MANAGER_BACKEND._default_registry_source_url_for_version("invalid"),
		GF_PACKAGE_MANAGER_BACKEND.DEFAULT_REGISTRY_SOURCE_LATEST_URL,
		"无法解析的版本必须回退到 latest source。"
	)


func test_default_registry_source_honors_environment_override() -> void:
	var previous_override: String = OS.get_environment(GF_PACKAGE_MANAGER_BACKEND.DEFAULT_REGISTRY_SOURCE_ENV)
	var override_url: String = "https://packages.example.test/gf-registry-source.json"
	OS.set_environment(GF_PACKAGE_MANAGER_BACKEND.DEFAULT_REGISTRY_SOURCE_ENV, override_url)
	var registry_source_url: String = GF_PACKAGE_MANAGER_BACKEND.get_default_registry_source_url()
	OS.set_environment(GF_PACKAGE_MANAGER_BACKEND.DEFAULT_REGISTRY_SOURCE_ENV, previous_override)

	assert_eq(registry_source_url, override_url, "显式 registry source 覆盖必须优先于版本解析。")


func test_native_install_rejects_incompatible_registry_without_mutating_project() -> void:
	var project_root: String = TEST_ROOT.path_join("old_framework_install_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_set_registry_framework_range(registry, "9.0.0", "10.0.0")
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	_write_project_plugin_cfg(project_root, "1.0.0")

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "旧 GF 项目不应安装要求更高框架版本的包。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(result, "issues"),
			"minimum_framework_version 9.0.0"
		),
		"安装 issues 应说明所需 GF 最小版本。"
	)
	assert_false(_file_exists(project_root.path_join(".gf/packages.lock.json")), "兼容性失败不能写 lockfile。")
	assert_false(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "兼容性失败不能写项目文件。")


func test_native_install_checksum_failure_does_not_mutate_project() -> void:
	var project_root: String = TEST_ROOT.path_join("checksum_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	var packages: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(registry, "packages")
	var save_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(packages, "gf.extension.save")
	save_entry["sha256"] = "0000"
	packages["gf.extension.save"] = save_entry
	registry["packages"] = packages
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "checksum mismatch 应阻止安装。")
	assert_false(_file_exists(project_root.path_join(".gf/packages.lock.json")), "checksum 失败不能写 lockfile。")
	assert_false(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "checksum 失败不能写项目文件。")


func test_native_install_rejects_local_registry_external_archive_references() -> void:
	var external_project_root: String = TEST_ROOT.path_join("local_external_archive_project")
	var escape_project_root: String = TEST_ROOT.path_join("local_escape_archive_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	var packages: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(registry, "packages")
	var save_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(packages, "gf.extension.save")

	save_entry["archive"] = "res://addons/gf/extensions/save.zip"
	packages["gf.extension.save"] = save_entry
	registry["packages"] = packages
	_write_json(registry_path, registry)
	var external_result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(external_project_root)
	)

	save_entry["archive"] = "../outside-save.zip"
	packages["gf.extension.save"] = save_entry
	registry["packages"] = packages
	_write_json(registry_path, registry)
	var escape_result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(escape_project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(external_result, "ok"), "本地 registry 不应接受 res:// archive。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(external_result, "issues"),
			"local registry archive must be a relative file path in the local registry bundle"
		),
		"外部本地 archive 引用应进入 issues。"
	)
	assert_false(_file_exists(external_project_root.path_join(".gf/packages.lock.json")), "外部 archive 引用失败不能写 lockfile。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(escape_result, "ok"), "本地 registry archive 不应能越过 registry 目录。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(escape_result, "issues"),
			"local registry archive path escapes"
		),
		"越界 archive 相对路径应进入 issues。"
	)
	assert_false(_file_exists(escape_project_root.path_join(".gf/packages.lock.json")), "越界 archive 失败不能写 lockfile。")


func test_native_install_allows_local_registry_sibling_packages_directory() -> void:
	var project_root: String = TEST_ROOT.path_join("local_sibling_packages_project")
	var distribution_root: String = TEST_ROOT.path_join("local_sibling_distribution")
	var registry_root: String = distribution_root.path_join("registry")
	var registry_path: String = registry_root.path_join("index.json")
	var registry: Dictionary = _make_fixture_registry()
	_rewrite_registry_archives_for_offline_bundle(registry)
	_write_fixture_archives_at(registry, registry_root)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "本地 registry 应允许同一分发根下的 sibling packages 目录。")
	assert_true(_file_exists(project_root.path_join(".gf/packages.lock.json")), "sibling packages 安装应写入 lockfile。")
	assert_true(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "sibling packages 安装应写入包文件。")


func test_native_install_archive_path_audit_failure_does_not_mutate_project() -> void:
	var project_root: String = TEST_ROOT.path_join("audit_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_package_archive(
		registry,
		"gf.extension.save",
		{
			"outside.txt": "bad",
		}
	)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "archive 路径越界应阻止安装。")
	assert_false(_file_exists(project_root.path_join(".gf/packages.lock.json")), "路径审计失败不能写 lockfile。")
	assert_false(_file_exists(project_root.path_join("outside.txt")), "路径审计失败不能写越界文件。")


func test_native_install_rejects_archive_entry_with_leading_slash() -> void:
	var project_root: String = TEST_ROOT.path_join("leading_slash_archive_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_package_archive(
		registry,
		"gf.extension.save",
		{
			"/addons/gf/extensions/save/gf_save_fixture.gd": "bad",
		}
	)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "绝对 archive entry 应阻止安装。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(result, "issues"),
			"unsafe archive entry path"
		),
		"绝对 archive entry 应进入安装 issues。"
	)
	assert_false(_file_exists(project_root.path_join(".gf/packages.lock.json")), "绝对路径审计失败不能写 lockfile。")
	assert_false(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "绝对路径审计失败不能写项目文件。")


func test_native_install_external_tool_payload_failure_does_not_mutate_project() -> void:
	var project_root: String = TEST_ROOT.path_join("external_tool_payload_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_package_archive(
		registry,
		"gf.extension.save",
		{
			"addons/gf/extensions/save/install.py": "# fixture\n",
			"addons/gf/extensions/save/package.json": "{}\n",
		}
	)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "运行时包夹带 Python/npm 工具载荷应阻止安装。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(result, "issues"),
			"external tool payload"
		),
		"外部工具载荷应进入安装 issues。"
	)
	assert_false(_file_exists(project_root.path_join(".gf/packages.lock.json")), "外部工具载荷审计失败不能写 lockfile。")
	assert_false(_file_exists(project_root.path_join("addons/gf/extensions/save/install.py")), "外部工具载荷审计失败不能写项目文件。")


func test_native_install_copy_failure_rolls_back_files_and_lockfile() -> void:
	var project_root: String = TEST_ROOT.path_join("rollback_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		"manual",
		false,
		{ "simulate_copy_failure_after": 2 }
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "模拟复制失败应让安装失败。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "rolled_back"), "复制失败应报告已回滚。")
	assert_false(_file_exists(project_root.path_join(".gf/packages.lock.json")), "复制失败不能写 lockfile。")
	assert_false(_file_exists(project_root.path_join("addons/gf/kernel/core/gf_core_fixture.gd")), "复制失败应删除已创建文件。")
	assert_false(_file_exists(project_root.path_join("addons/gf/standard/foundation/gf_base_fixture.gd")), "复制失败应回滚已复制依赖文件。")


func test_native_transaction_failure_before_lockfile_replace_rolls_back_payload() -> void:
	var project_root: String = TEST_ROOT.path_join("transaction_lockfile_failure_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		"manual",
		false,
		{ "simulate_transaction_failure_at": "before_lockfile_replace" }
	)
	var transaction: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(result, "transaction")

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "lockfile 替换前故障应让安装失败。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(transaction, "rolled_back"), "事务引擎应通过持久备份回滚 payload。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(transaction, "recovery_required"), "同步回滚成功后不应遗留恢复任务。")
	assert_false(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "回滚后不应保留新 payload。")
	assert_false(_file_exists(project_root.path_join(".gf/packages.lock.json")), "lockfile 替换前故障不应写入 lockfile。")
	assert_false(_directory_exists(project_root.path_join(".gf/package_transactions/active")), "完整回滚后不应保留 active journal。")


func test_native_recovery_blocks_three_way_payload_conflict() -> void:
	var project_root: String = TEST_ROOT.path_join("transaction_three_way_conflict_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)

	var interrupted: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		"manual",
		false,
		{ "simulate_transaction_crash_at": "after_payload_applied" }
	)
	var modified_path: String = project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")
	_write_text(modified_path, "extends RefCounted\nconst PROJECT_EDIT := true\n")

	var recovery: Dictionary = GF_PACKAGE_MANAGER_BACKEND.recover_package_transaction(
		ProjectSettings.globalize_path(project_root)
	)
	var recovery_issues: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(recovery, "issues")

	assert_false(GF_VARIANT_ACCESS.get_option_bool(interrupted, "ok"), "故障注入应留下待恢复事务。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(recovery, "ok"), "恢复遇到 planned/current/original 三方冲突必须阻断。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(recovery, "outcome"), "recovery_failed", "三方冲突应进入 recovery_failed。")
	assert_true(_issues_contain(recovery_issues, "matches neither original nor planned"), "恢复报告应说明三方状态冲突。")
	assert_true(_read_text(modified_path).contains("PROJECT_EDIT"), "冲突恢复不得覆盖项目修改。")
	assert_true(_directory_exists(project_root.path_join(".gf/package_transactions/active")), "冲突事务应保留 journal 供人工处理。")


func test_native_recovery_rolls_back_crash_after_lockfile_replace() -> void:
	var project_root: String = TEST_ROOT.path_join("transaction_replace_crash_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)

	var interrupted: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		"manual",
		false,
		{ "simulate_transaction_crash_at": "after_lockfile_replace" }
	)
	var interrupted_transaction: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(interrupted, "transaction")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(interrupted, "ok"), "模拟进程中断不应报告安装成功。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(interrupted_transaction, "recovery_required"), "lockfile 替换后中断必须保留 recovery journal。")
	assert_true(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "中断窗口中 payload 已经落盘。")
	assert_true(_file_exists(project_root.path_join(".gf/packages.lock.json")), "中断窗口中 planned lockfile 已经替换。")
	assert_true(_directory_exists(project_root.path_join(".gf/package_transactions/active")), "中断后必须保留 active journal 与持久备份。")

	var status_after_crash: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var recovery: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(status_after_crash, "transaction_recovery")
	var second_recovery: Dictionary = GF_PACKAGE_MANAGER_BACKEND.recover_package_transaction(
		ProjectSettings.globalize_path(project_root)
	)

	assert_true(GF_VARIANT_ACCESS.get_option_bool(recovery, "ok"), "未写 committed journal 的事务应可恢复。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(recovery, "outcome"), "recovered_rollback", "不确定提交窗口应回滚到旧状态。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(recovery, "rolled_back"), "恢复报告应标记已回滚。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(status_after_crash, "ok"), "status 应在自动恢复完成后继续读取一致状态。")
	assert_false(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "恢复应移除中断安装写入的 payload。")
	assert_false(_file_exists(project_root.path_join(".gf/packages.lock.json")), "恢复应还原原先不存在的 lockfile。")
	assert_false(_directory_exists(project_root.path_join(".gf/package_transactions/active")), "恢复完成后应清理 active journal。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(second_recovery, "outcome"), "none", "重复恢复必须幂等。")


func test_native_recovery_finalizes_committed_transaction_without_rollback() -> void:
	var project_root: String = TEST_ROOT.path_join("transaction_committed_crash_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)

	var interrupted: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		"manual",
		false,
		{ "simulate_transaction_crash_at": "after_lockfile_committed" }
	)
	var recovery: Dictionary = GF_PACKAGE_MANAGER_BACKEND.recover_package_transaction(
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(interrupted, "ok"), "模拟 committed 后进程中断不应产生正常返回。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(recovery, "ok"), "完整提交状态应能安全收尾。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(recovery, "outcome"), "recovered_commit", "committed journal 应保留新状态并只做清理。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(recovery, "rolled_back"), "已提交且校验通过的事务不应回滚。")
	assert_true(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "已提交事务恢复后应保留 payload。")
	assert_true(_file_exists(project_root.path_join(".gf/packages.lock.json")), "已提交事务恢复后应保留 lockfile。")
	assert_false(_directory_exists(project_root.path_join(".gf/package_transactions/active")), "提交收尾后应清理 active journal。")


func test_native_status_reads_http_registry_and_caches_registry() -> void:
	var project_root: String = TEST_ROOT.path_join("http_status_project")
	var http_root: String = TEST_ROOT.path_join("http_status_server")
	var registry_root: String = http_root.path_join("registry")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives_at(registry, registry_root)
	_write_json(registry_root.path_join("index.json"), registry)
	var server: HttpFixtureServer = _start_http_fixture_server(http_root)

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		server.url("registry/index.json"),
		ProjectSettings.globalize_path(project_root)
	)
	server.stop()
	var cached_registry: Dictionary = _read_json_absolute(GF_VARIANT_ACCESS.get_option_string(status, "registry"))
	var packages: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(cached_registry, "packages")
	var save_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(packages, "gf.extension.save")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "Godot 原生后端应能读取 HTTP registry。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(status, "registry_remote"), "HTTP registry 状态应标记 remote。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status, "package_count"), 5, "HTTP registry 应列出全部 fixture 包。")
	assert_true(_cache_has_file(project_root.path_join(".gf/package_workspace/registries"), ".json"), "未绑定 integrity 的 HTTP registry 应写入项目 workspace。")
	assert_false(_file_exists(project_root.path_join(".gf/package_cache/.gf-package-cache.json")), "没有 artifact 写入时不应提前创建 cache marker。")
	assert_true(GF_VARIANT_ACCESS.get_option_string(save_entry, "archive").begins_with("http://127.0.0.1:"), "相对 archive URL 应在缓存 registry 中重写为 HTTP URL。")


func test_native_status_rejects_http_registry_local_archive_reference() -> void:
	var project_root: String = TEST_ROOT.path_join("http_local_archive_status_project")
	var http_root: String = TEST_ROOT.path_join("http_local_archive_status_server")
	var registry_root: String = http_root.path_join("registry")
	var registry: Dictionary = _make_fixture_registry()
	var packages: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(registry, "packages")
	var save_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(packages, "gf.extension.save")
	save_entry["archive"] = "res://addons/gf/extensions/save.zip"
	packages["gf.extension.save"] = save_entry
	registry["packages"] = packages
	_write_json(registry_root.path_join("index.json"), registry)
	var server: HttpFixtureServer = _start_http_fixture_server(http_root)

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		server.url("registry/index.json"),
		ProjectSettings.globalize_path(project_root)
	)
	server.stop()
	var issues: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(status, "issues")

	assert_false(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "HTTP registry 不能声明本地 archive 引用。")
	assert_true(_issues_contain(issues, "remote registry archive reference is not allowed"), "本地 archive 引用应进入 issues。")


func test_native_status_reuses_verified_http_registry_cache_from_source_metadata() -> void:
	var project_root: String = TEST_ROOT.path_join("http_source_cache_project")
	var http_root: String = TEST_ROOT.path_join("http_source_cache_server")
	var registry_root: String = http_root.path_join("registry")
	var source_path: String = TEST_ROOT.path_join("http_source_cache/source.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives_at(registry, registry_root)
	_write_json(registry_root.path_join("index.json"), registry)
	var registry_absolute: String = ProjectSettings.globalize_path(registry_root.path_join("index.json")).replace("\\", "/")
	var server: HttpFixtureServer = _start_http_fixture_server(http_root)
	_write_json(source_path, {
		"schema_version": 1,
		"default_channel": "stable",
		"channels": {
			"stable": {
				"registry": server.url("registry/index.json"),
				"registry_sha256": FileAccess.get_sha256(registry_absolute).to_lower(),
				"registry_size_bytes": _file_size_absolute(registry_absolute),
				"mirrors": [],
			},
		},
	})

	var first_status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		source_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		{ "channel": "stable" }
	)
	server.stop()
	var second_status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		source_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		{ "channel": "stable" }
	)

	assert_true(GF_VARIANT_ACCESS.get_option_bool(first_status, "ok"), "第一次读取应下载并缓存 HTTP registry。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(second_status, "ok"), "source metadata 未变时应能在 HTTP 服务停止后复用 verified registry cache。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(second_status, "package_count"), 5, "复用缓存后仍应列出全部 fixture 包。")
	assert_true(_cache_has_file(project_root.path_join(".gf/package_cache/objects/sha256"), ".json"), "verified registry 应进入内容寻址 artifact store。")
	var cache_report: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(second_status, "cache")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(cache_report, "mode"), "project_local", "默认缓存模式应明确报告 project_local。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(cache_report, "marker_valid"), "缓存报告应确认项目 marker 有效。")


func test_native_external_cache_requires_mode_and_owned_marker() -> void:
	var project_root: String = TEST_ROOT.path_join("external_cache_policy_project")
	var registry_path: String = TEST_ROOT.path_join("external_cache_policy_registry/index.json")
	var external_root: String = ProjectSettings.globalize_path(TEST_ROOT.path_join("external_cache_policy_shared")).replace("\\", "/")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives_at(registry, TEST_ROOT.path_join("external_cache_policy_registry"))
	_write_json(registry_path, registry)

	var implicit_result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		{ "cache_dir": external_root }
	)
	var unowned_result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		{
			"cache_mode": "external_read_only",
			"cache_dir": external_root,
		}
	)
	var init_result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.initialize_package_cache(external_root)
	var owned_result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		{
			"cache_mode": "external_read_only",
			"cache_dir": external_root,
		}
	)
	var cache_report: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(owned_result, "cache")

	assert_false(GF_VARIANT_ACCESS.get_option_bool(implicit_result, "ok"), "cache_dir 不得隐式授权外部目录。")
	assert_true(_issues_contain(GF_VARIANT_ACCESS.get_option_packed_string_array(implicit_result, "issues"), "project_local cache mode only permits"), "裸外部路径应报告 project_local 边界。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(unowned_result, "ok"), "外部模式不得接管无 marker 目录。")
	assert_true(_issues_contain(GF_VARIANT_ACCESS.get_option_packed_string_array(unowned_result, "issues"), "missing its GF marker"), "无 marker 外部目录应给出显式初始化提示。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(init_result, "ok"), "显式 cache-init 应创建外部缓存 marker。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(owned_result, "ok"), "带有效 marker 的外部只读缓存应允许使用。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(cache_report, "mode"), "external_read_only", "结果应报告外部只读模式。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(cache_report, "read_only"), "外部只读模式不得被报告为可写共享缓存。")
	assert_true(GF_VARIANT_ACCESS.get_option_string(cache_report, "artifact_write_root").contains("external_cache_policy_project/.gf/package_cache"), "外部只读未命中应写回项目本地缓存。")


func test_native_cache_init_rejects_non_empty_unowned_directory() -> void:
	var external_root: String = TEST_ROOT.path_join("external_cache_non_empty")
	_write_text(external_root.path_join("sentinel.txt"), "owned by another tool\n")

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.initialize_package_cache(
		ProjectSettings.globalize_path(external_root).replace("\\", "/")
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "cache-init 不得接管已有未知内容的目录。")
	assert_true(_issues_contain(GF_VARIANT_ACCESS.get_option_packed_string_array(result, "issues"), "Refusing to claim a non-empty directory"), "拒绝接管应明确报告目录 ownership 问题。")
	assert_true(_file_exists(external_root.path_join("sentinel.txt")), "拒绝初始化不得修改未知目录内容。")


func test_native_external_shared_cache_is_reused_read_only_across_projects() -> void:
	var first_project_root: String = TEST_ROOT.path_join("external_cache_writer_project")
	var second_project_root: String = TEST_ROOT.path_join("external_cache_reader_project")
	var external_root: String = ProjectSettings.globalize_path(TEST_ROOT.path_join("external_cache_shared_store")).replace("\\", "/")
	var http_root: String = TEST_ROOT.path_join("external_cache_shared_server")
	var registry_root: String = http_root.path_join("registry")
	var source_path: String = TEST_ROOT.path_join("external_cache_shared_source/source.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives_at(registry, registry_root)
	_write_json(registry_root.path_join("index.json"), registry)
	var registry_absolute: String = ProjectSettings.globalize_path(registry_root.path_join("index.json")).replace("\\", "/")
	var server: HttpFixtureServer = _start_http_fixture_server(http_root)
	_write_json(source_path, {
		"schema_version": 1,
		"default_channel": "stable",
		"channels": {
			"stable": {
				"registry": server.url("registry/index.json"),
				"registry_sha256": FileAccess.get_sha256(registry_absolute).to_lower(),
				"registry_size_bytes": _file_size_absolute(registry_absolute),
				"mirrors": [],
			},
		},
	})
	var init_result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.initialize_package_cache(external_root)
	var writer_status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		source_path,
		ProjectSettings.globalize_path(first_project_root),
		".gf/packages.lock.json",
		{
			"channel": "stable",
			"cache_mode": "external_shared_rw",
			"cache_dir": external_root,
		}
	)
	server.stop()
	var reader_status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		source_path,
		ProjectSettings.globalize_path(second_project_root),
		".gf/packages.lock.json",
		{
			"channel": "stable",
			"cache_mode": "external_read_only",
			"cache_dir": external_root,
		}
	)
	var reader_cache: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(reader_status, "cache")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(init_result, "ok"), "测试共享缓存应能显式初始化。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(writer_status, "ok"), "共享读写模式应提交 verified registry artifact。")
	assert_true(_cache_has_file(external_root.path_join("objects/sha256"), ".json"), "外部共享缓存应保存内容寻址 registry artifact。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(reader_status, "ok"), "HTTP 服务停止后外部只读模式应复用共享 artifact。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(reader_status, "package_count"), 5, "跨项目共享读取应保留 registry 内容。")
	assert_true(GF_VARIANT_ACCESS.get_option_string(reader_cache, "artifact_write_root").contains("external_cache_reader_project/.gf/package_cache"), "只读共享 cache 的写根必须落回当前项目。")


func test_native_status_rejects_tampered_verified_http_registry_cache() -> void:
	var project_root: String = TEST_ROOT.path_join("http_source_cache_tamper_project")
	var http_root: String = TEST_ROOT.path_join("http_source_cache_tamper_server")
	var registry_root: String = http_root.path_join("registry")
	var source_path: String = TEST_ROOT.path_join("http_source_cache_tamper/source.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives_at(registry, registry_root)
	_write_json(registry_root.path_join("index.json"), registry)
	var registry_absolute: String = ProjectSettings.globalize_path(registry_root.path_join("index.json")).replace("\\", "/")
	var registry_sha: String = FileAccess.get_sha256(registry_absolute).to_lower()
	var server: HttpFixtureServer = _start_http_fixture_server(http_root)
	_write_json(source_path, {
		"schema_version": 1,
		"default_channel": "stable",
		"channels": {
			"stable": {
				"registry": server.url("registry/index.json"),
				"registry_sha256": registry_sha,
				"registry_size_bytes": _file_size_absolute(registry_absolute),
				"mirrors": [],
			},
		},
	})

	var first_status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		source_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		{ "channel": "stable" }
	)
	var cache_path: String = project_root.path_join(
		".gf/package_cache/objects/sha256/%s/%s.json" % [registry_sha.substr(0, 2), registry_sha]
	)
	if _file_exists(cache_path):
		_write_text(cache_path, "{ \"schema_version\": 2, \"packages\": {} }\n")
	server.stop()
	var second_status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		source_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		{ "channel": "stable" }
	)

	assert_true(GF_VARIANT_ACCESS.get_option_bool(first_status, "ok"), "第一次读取应成功写入 verified cache。")
	assert_true(_file_exists(cache_path), "测试应找到内容寻址 registry artifact。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(second_status, "ok"), "缓存 JSON 被篡改后不应复用 verified cache。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(second_status, "package_count"), 0, "拒绝篡改缓存后不应列出 package。")


func test_native_status_reads_offline_bundle_zip_and_caches_registry() -> void:
	var project_root: String = TEST_ROOT.path_join("offline_bundle_status_project")
	var bundle_path: String = TEST_ROOT.path_join("bundle/gf-package-offline-bundle.zip")
	var registry: Dictionary = _make_fixture_registry()
	_write_offline_bundle(registry, bundle_path)

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		bundle_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_true(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "Godot 原生后端应能直接读取 offline bundle zip。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(status, "registry_remote"), "本地 offline bundle registry 不应标记 remote。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status, "package_count"), 5, "offline bundle 应列出全部 fixture 包。")
	assert_true(GF_VARIANT_ACCESS.get_option_string(status, "registry").contains("/offline_bundles/"), "offline bundle registry 应解包到项目缓存。")
	assert_true(GF_VARIANT_ACCESS.get_option_string(status, "registry_offline_bundle").ends_with("gf-package-offline-bundle.zip"), "状态应报告离线 bundle zip 路径。")
	assert_true(GF_VARIANT_ACCESS.get_option_string(status, "registry_offline_bundle_extracted").contains("/offline_bundles/"), "状态应报告离线 bundle 解包目录。")


func test_native_status_rejects_offline_bundle_entry_path_over_limits() -> void:
	var project_root: String = TEST_ROOT.path_join("offline_bundle_long_path_project")
	var bundle_path: String = TEST_ROOT.path_join("bundle_long_path/gf-package-offline-bundle.zip")
	var long_entry_path: String = "packages/%s.zip" % _repeat_text("a", 600)
	_write_zip_entries(bundle_path, {
		"registry/index.json": "{}",
		long_entry_path: "not a real package archive",
	})

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		bundle_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "offline bundle entry path 超限时应拒绝读取。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status, "package_count"), 0, "bundle 校验失败时不应继续列包。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(status, "issues"),
			"Offline bundle entry path is too long"
		),
		"超长 bundle entry path 应进入 issues。"
	)


func test_native_status_selects_http_registry_source_channel_mirror() -> void:
	var project_root: String = TEST_ROOT.path_join("http_source_project")
	var http_root: String = TEST_ROOT.path_join("http_source_server")
	var registry_root: String = http_root.path_join("registry")
	var source_root: String = http_root.path_join("source")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives_at(registry, registry_root)
	_write_json(registry_root.path_join("index.json"), registry)
	var registry_absolute: String = ProjectSettings.globalize_path(registry_root.path_join("index.json")).replace("\\", "/")
	_write_json(source_root.path_join("source.json"), {
		"schema_version": 1,
		"default_channel": "stable",
		"channels": {
			"stable": {
				"registry": "../missing/index.json",
				"registry_sha256": FileAccess.get_sha256(registry_absolute).to_lower(),
				"registry_size_bytes": _file_size_absolute(registry_absolute),
				"mirrors": ["../registry/index.json"],
			},
		},
	})
	var server: HttpFixtureServer = _start_http_fixture_server(http_root)

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		server.url("source/source.json"),
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		{ "channel": "stable" }
	)
	server.stop()

	assert_true(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "source manifest 主 registry 不可用时应通过 mirror 读取状态。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(status, "registry_remote"), "source manifest mirror 状态应标记 remote registry。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(status, "registry_channel"), "stable", "source manifest 状态应报告选中的 channel。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status, "registry_mirror_index", -2), 0, "source manifest 应报告命中的 mirror 索引。")
	assert_true(GF_VARIANT_ACCESS.get_option_string(status, "registry_source_manifest").begins_with("http://127.0.0.1:"), "source manifest 诊断应保留 manifest URL。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(status, "registry_source_sha256"), FileAccess.get_sha256(registry_absolute).to_lower(), "source manifest 状态应报告 registry sha256。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status, "registry_source_size_bytes"), _file_size_absolute(registry_absolute), "source manifest 状态应报告 registry 大小。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status, "package_count"), 5, "source manifest mirror 应列出全部 fixture 包。")
	assert_true(_cache_has_file(project_root.path_join(".gf/package_cache/objects/sha256"), ".json"), "带 integrity 的 mirror registry 应进入内容寻址 artifact store。")
	assert_true(_cache_has_file(project_root.path_join(".gf/package_workspace/registries"), ".json"), "source manifest 与派生 registry 应留在项目 workspace。")


func test_native_status_rejects_registry_source_invalid_mirrors() -> void:
	var project_root: String = TEST_ROOT.path_join("source_invalid_mirrors_project")
	var registry_path: String = TEST_ROOT.path_join("source_invalid_mirrors_registry/index.json")
	var source_path: String = TEST_ROOT.path_join("source_invalid_mirrors/gf-registry-source.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives_at(registry, TEST_ROOT.path_join("source_invalid_mirrors_registry"))
	_write_json(registry_path, registry)
	var registry_absolute: String = ProjectSettings.globalize_path(registry_path).replace("\\", "/")
	_write_json(source_path, {
		"schema_version": 1,
		"default_channel": "stable",
		"channels": {
			"stable": {
				"registry": "../source_invalid_mirrors_registry/index.json",
				"registry_sha256": FileAccess.get_sha256(registry_absolute).to_lower(),
				"registry_size_bytes": _file_size_absolute(registry_absolute),
				"mirrors": [123, ""],
			},
		},
	})

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		source_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "source manifest mirrors 含非法项时应拒绝读取状态。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status, "package_count"), 0, "非法 mirrors 不能被宽松转换后继续列包。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(status, "issues"),
			"mirror must be a string"
		),
		"非字符串 mirror 应进入 issues。"
	)
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(status, "issues"),
			"mirror must be non-empty"
		),
		"空 mirror 应进入 issues。"
	)


func test_native_status_rejects_registry_source_channel_hash_mismatch() -> void:
	var project_root: String = TEST_ROOT.path_join("http_source_hash_mismatch_project")
	var http_root: String = TEST_ROOT.path_join("http_source_hash_mismatch_server")
	var registry_root: String = http_root.path_join("registry")
	var source_root: String = http_root.path_join("source")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives_at(registry, registry_root)
	_write_json(registry_root.path_join("index.json"), registry)
	var registry_absolute: String = ProjectSettings.globalize_path(registry_root.path_join("index.json")).replace("\\", "/")
	_write_json(source_root.path_join("source.json"), {
		"schema_version": 1,
		"default_channel": "stable",
		"channels": {
			"stable": {
				"registry": "../registry/index.json",
				"registry_sha256": "0000000000000000000000000000000000000000000000000000000000000000",
				"registry_size_bytes": _file_size_absolute(registry_absolute),
				"mirrors": [],
			},
		},
	})
	var server: HttpFixtureServer = _start_http_fixture_server(http_root)

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		server.url("source/source.json"),
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		{ "channel": "stable" }
	)
	server.stop()

	assert_false(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "source manifest 的 registry sha256 不匹配时应拒绝读取状态。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status, "package_count"), 0, "registry source 完整性失败时不应列出 package。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(status, "issues"),
			"registry sha256 does not match registry source metadata"
		),
		"source manifest 完整性错误应进入 issues。"
	)


func test_native_status_rejects_registry_source_signature_metadata_before_verification() -> void:
	var project_root: String = TEST_ROOT.path_join("signature_source_project")
	var registry_path: String = TEST_ROOT.path_join("signature_registry/index.json")
	var source_path: String = TEST_ROOT.path_join("signature_source/gf-registry-source.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives_at(registry, TEST_ROOT.path_join("signature_registry"))
	_write_json(registry_path, registry)
	var registry_absolute: String = ProjectSettings.globalize_path(registry_path).replace("\\", "/")
	_write_json(source_path, {
		"schema_version": 1,
		"default_channel": "stable",
		"public_key": "future-key",
		"channels": {
			"stable": {
				"registry": "../signature_registry/index.json",
				"registry_sha256": FileAccess.get_sha256(registry_absolute).to_lower(),
				"registry_size_bytes": _file_size_absolute(registry_absolute),
				"registry_signature_url": "gf-registry.sig",
				"signature_public_key": "future-channel-key",
				"mirrors": [],
			},
		},
	})

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		source_path,
		ProjectSettings.globalize_path(project_root)
	)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "未实现原生签名验证前，source manifest 签名字段应被拒绝。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status, "package_count"), 0, "不支持的签名字段不能被静默忽略后继续列包。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(status, "issues"),
			"signature field is not supported until native verification is implemented"
		),
		"不支持的签名字段应进入 issues。"
	)
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(status, "issues"),
			"public_key"
		),
		"source root public_key 应被拒绝。"
	)
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(status, "issues"),
			"signature_public_key"
		),
		"source channel signature_public_key 应被拒绝。"
	)


func test_native_status_rejects_registry_package_signature_metadata_before_verification() -> void:
	var project_root: String = TEST_ROOT.path_join("signature_package_project")
	var registry_path: String = TEST_ROOT.path_join("signature_package_registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	var packages: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(registry, "packages")
	var save_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(packages, "gf.extension.save")
	save_entry["signature_url"] = "gf-extension-save.zip.sig"
	packages["gf.extension.save"] = save_entry
	registry["packages"] = packages
	_write_json(registry_path, registry)

	var status: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_status(
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var package_index: Dictionary = _package_index(status)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "未实现原生签名验证前，registry package 签名字段应被拒绝。")
	assert_false(package_index.has("gf.extension.save"), "含不支持签名字段的 package 不能进入可安装包列表。")
	assert_true(
		_issues_contain(
			GF_VARIANT_ACCESS.get_option_packed_string_array(status, "issues"),
			"Registry package signature field is not supported until native verification is implemented"
		),
		"不支持的 package 签名字段应进入 issues。"
	)


func test_native_install_http_archives_writes_files_lockfile_and_cache() -> void:
	var project_root: String = TEST_ROOT.path_join("http_install_project")
	var http_root: String = TEST_ROOT.path_join("http_install_server")
	var registry_root: String = http_root.path_join("registry")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives_at(registry, registry_root)
	_write_json(registry_root.path_join("index.json"), registry)
	var server: HttpFixtureServer = _start_http_fixture_server(http_root)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		server.url("registry/index.json"),
		ProjectSettings.globalize_path(project_root)
	)
	server.stop()
	var lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))
	var installed: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "installed")
	var save_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(installed, "gf.extension.save")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "Godot 原生后端应能从 HTTP registry 安装 archive 闭包。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(result, "installed_file_count"), 4, "远程安装应复制四个 fixture 文件。")
	assert_true(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "远程安装应写入扩展文件。")
	assert_true(_cache_has_file(project_root.path_join(".gf/package_cache/objects/sha256"), ".zip"), "远程 archive 应写入内容寻址 artifact store。")
	assert_true(GF_VARIANT_ACCESS.get_option_string(save_entry, "archive").begins_with("http://127.0.0.1:"), "lockfile 应记录解析后的远程 archive URL。")
	assert_true(GF_VARIANT_ACCESS.get_option_packed_string_array(save_entry, "files").has("addons/gf/extensions/save/gf_save_fixture.gd"), "lockfile 应记录远程安装文件清单。")


func test_native_install_offline_bundle_zip_writes_files_lockfile_and_cache() -> void:
	var project_root: String = TEST_ROOT.path_join("offline_bundle_install_project")
	var bundle_path: String = TEST_ROOT.path_join("bundle_install/gf-package-offline-bundle.zip")
	var registry: Dictionary = _make_fixture_registry()
	_write_offline_bundle(registry, bundle_path)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.preset.save"]),
		bundle_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		"preset"
	)
	var lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))
	var installed: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "installed")
	var preset_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(installed, "gf.preset.save")
	var save_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(installed, "gf.extension.save")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "Godot 原生后端应能直接从 offline bundle zip 安装 preset 闭包。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(result, "installed_file_count"), 4, "offline bundle preset 安装应复制四个实体包 fixture 文件。")
	assert_true(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "offline bundle 安装应写入扩展文件。")
	assert_true(_file_exists(project_root.path_join("addons/gf/standard/utilities/storage/gf_storage_fixture.gd")), "offline bundle 安装应写入 standard 依赖文件。")
	assert_true(installed.has("gf.preset.save"), "lockfile 应记录 preset 根包。")
	assert_true(GF_VARIANT_ACCESS.get_option_packed_string_array(preset_entry, "files").is_empty(), "preset lock entry 不应拥有物理文件。")
	assert_true(GF_VARIANT_ACCESS.get_option_string(save_entry, "archive").begins_with("../packages/"), "lockfile 应保留离线 bundle registry 的本地相对 archive。")
	assert_true(GF_VARIANT_ACCESS.get_option_string(result, "registry_offline_bundle").ends_with("gf-package-offline-bundle.zip"), "安装结果应报告离线 bundle zip 路径。")
	assert_true(_cache_has_file(project_root.path_join(".gf/package_workspace/offline_bundles"), ".zip"), "offline bundle package archives 应解包到项目 workspace。")


func test_native_install_http_archive_download_failure_does_not_mutate_project() -> void:
	var project_root: String = TEST_ROOT.path_join("http_missing_archive_project")
	var http_root: String = TEST_ROOT.path_join("http_missing_archive_server")
	var registry_root: String = http_root.path_join("registry")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives_at(registry, registry_root)
	var packages: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(registry, "packages")
	var save_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(packages, "gf.extension.save")
	save_entry["archive"] = "packages/missing-save.zip"
	packages["gf.extension.save"] = save_entry
	registry["packages"] = packages
	_write_json(registry_root.path_join("index.json"), registry)
	var server: HttpFixtureServer = _start_http_fixture_server(http_root)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		server.url("registry/index.json"),
		ProjectSettings.globalize_path(project_root)
	)
	server.stop()

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "远程 archive 下载失败应让安装失败。")
	assert_false(_file_exists(project_root.path_join(".gf/packages.lock.json")), "远程下载失败不能写 lockfile。")
	assert_false(_file_exists(project_root.path_join("addons/gf/kernel/core/gf_core_fixture.gd")), "远程下载失败不能提前写依赖文件。")
	assert_false(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "远程下载失败不能写目标扩展文件。")


func test_native_uninstall_removes_extension_and_pruned_dependencies() -> void:
	var project_root: String = TEST_ROOT.path_join("uninstall_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var install_fixture_result: Dictionary = _install_fixture_save(registry_path, project_root)
	assert_false(install_fixture_result.is_empty(), "测试 fixture 安装结果不应为空。")

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.uninstall_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))
	var installed: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "installed")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "Godot 原生后端应能卸载本地 package。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(result, "backend"), "godot_native", "卸载结果应标记 Godot 原生后端。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "lockfile_written"), "真实卸载应最后写入 lockfile。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(result, "removed_file_count"), 3, "卸载 save 后应删除 save、storage、base 三个 fixture 文件。")
	assert_false(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "扩展文件应被删除。")
	assert_false(_file_exists(project_root.path_join("addons/gf/standard/utilities/storage/gf_storage_fixture.gd")), "不再需要的 standard storage 应被剪枝删除。")
	assert_false(_file_exists(project_root.path_join("addons/gf/standard/foundation/gf_base_fixture.gd")), "不再需要的 standard base 应被剪枝删除。")
	assert_true(_file_exists(project_root.path_join("addons/gf/kernel/core/gf_core_fixture.gd")), "kernel bundled 文件应保留。")
	assert_false(installed.has("gf.extension.save"), "lockfile 应移除 save 包。")
	assert_false(installed.has("gf.standard.storage"), "lockfile 应移除被剪枝的 storage 包。")
	assert_true(installed.has("gf.kernel"), "lockfile 应保留 kernel。")


func test_native_uninstall_rejects_modified_installed_file() -> void:
	var project_root: String = TEST_ROOT.path_join("uninstall_modified_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var install_result: Dictionary = _install_fixture_save(registry_path, project_root)
	var lockfile_path: String = project_root.path_join(".gf/packages.lock.json")
	var before_lockfile: Dictionary = _read_json(lockfile_path)
	var modified_path: String = project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")
	_write_text(modified_path, "extends RefCounted\nconst PROJECT_EDIT := true\n")

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.uninstall_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var issues: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(result, "issues")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(install_result, "ok"), "测试 fixture 应先完成安装。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "原生卸载不得删除已被项目修改的受管文件。")
	assert_true(_issues_contain(issues, "modified; refusing to delete"), "卸载结果应报告 modified-file ownership 冲突。")
	assert_true(_read_text(modified_path).contains("PROJECT_EDIT"), "阻断卸载必须保留项目修改。")
	assert_eq(_read_json(lockfile_path), before_lockfile, "阻断卸载不能修改 lockfile。")


func test_native_uninstall_blocks_pruned_dependency_with_project_reference() -> void:
	var project_root: String = TEST_ROOT.path_join("uninstall_pruned_dependency_reference_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var install_fixture_result: Dictionary = _install_fixture_save(registry_path, project_root)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(install_fixture_result, "ok"), "测试 fixture 应先完成安装。")
	_write_text(
		project_root.path_join("scripts/uses_storage.gd"),
		"extends Node\nconst StorageFixture = preload(\"res://addons/gf/standard/utilities/storage/gf_storage_fixture.gd\")\n"
	)

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.uninstall_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))
	var installed: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "installed")
	var plan: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(result, "plan")
	var blocked: Array = GF_VARIANT_ACCESS.get_option_array(plan, "blocked")

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "自动剪枝依赖仍被项目引用时应阻断卸载事务。")
	assert_true(_blocked_contains_reason(blocked, "project_references"), "被剪枝依赖的项目引用应进入 blocked。")
	assert_true(installed.has("gf.extension.save"), "阻断卸载时 lockfile 不应移除根包。")
	assert_true(installed.has("gf.standard.storage"), "阻断卸载时 lockfile 不应移除被引用依赖。")
	assert_true(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "阻断卸载时扩展文件应保留。")
	assert_true(_file_exists(project_root.path_join("addons/gf/standard/utilities/storage/gf_storage_fixture.gd")), "阻断卸载时被引用依赖文件应保留。")


func test_native_uninstall_blocks_pruned_dependency_referenced_by_binary_resource() -> void:
	var project_root: String = TEST_ROOT.path_join("uninstall_binary_dependency_reference_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var install_fixture_result: Dictionary = _install_fixture_save(registry_path, project_root)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(install_fixture_result, "ok"), "测试 fixture 应先完成安装。")
	var dependency_path: String = project_root.path_join(
		"addons/gf/standard/utilities/storage/gf_storage_fixture.gd"
	)
	var consumer_path: String = project_root.path_join("resources/uses_storage.res")
	var _make_resource_directory_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(consumer_path.get_base_dir())
	)
	var consumer: BinaryReferenceResource = BinaryReferenceResource.new()
	consumer.dependency = ResourceLoader.load(dependency_path)
	assert_not_null(consumer.dependency, "测试应能加载待卸载包脚本资源。")
	assert_eq(ResourceSaver.save(consumer, consumer_path), OK, "测试应能保存二进制项目引用。")

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.uninstall_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))
	var installed: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "installed")
	var plan: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(result, "plan")
	var blocked: Array = GF_VARIANT_ACCESS.get_option_array(plan, "blocked")
	consumer.dependency = null

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "二进制资源引用被剪枝依赖时应阻断卸载事务。")
	assert_true(_blocked_contains_reason(blocked, "project_references"), "二进制资源引用应进入 project_references blocker。")
	assert_true(installed.has("gf.extension.save"), "阻断卸载时 lockfile 不应移除根包。")
	assert_true(installed.has("gf.standard.storage"), "阻断卸载时 lockfile 不应移除二进制资源引用的依赖。")


func test_native_uninstall_dry_run_does_not_mutate_project() -> void:
	var project_root: String = TEST_ROOT.path_join("uninstall_dry_run_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var install_fixture_result: Dictionary = _install_fixture_save(registry_path, project_root)
	assert_false(install_fixture_result.is_empty(), "测试 fixture 安装结果不应为空。")
	var before_lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.uninstall_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		false,
		true
	)
	var after_lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "卸载 dry-run 应成功生成计划。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "dry_run"), "结果应标记 dry-run。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(result, "planned_file_count"), 3, "dry-run 应报告计划删除文件数量。")
	assert_eq(after_lockfile, before_lockfile, "dry-run 不应修改 lockfile。")
	assert_true(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "dry-run 不应删除扩展文件。")
	assert_true(_file_exists(project_root.path_join("addons/gf/standard/utilities/storage/gf_storage_fixture.gd")), "dry-run 不应删除依赖文件。")


func test_native_uninstall_missing_file_list_is_rejected_without_deleting_files() -> void:
	var project_root: String = TEST_ROOT.path_join("uninstall_missing_files_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var install_fixture_result: Dictionary = _install_fixture_save(registry_path, project_root)
	assert_false(install_fixture_result.is_empty(), "测试 fixture 安装结果不应为空。")
	var extra_file: String = project_root.path_join("addons/gf/extensions/save/project_extra_file.gd")
	_write_text(extra_file, "extends Node\n")
	_remove_lockfile_files_for_packages(
		project_root,
		PackedStringArray(["gf.extension.save", "gf.standard.storage", "gf.standard.base"])
	)
	var before_lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.uninstall_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	var after_lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))
	var result_issues: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(result, "issues")

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "lockfile 缺少精确 files 清单时，卸载应拒绝执行。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(result, "removed_file_count"), 0, "拒绝卸载时不应删除任何文件。")
	assert_true(_issues_contain(result_issues, "missing the installed files list"), "结果应说明缺少 installed files 清单。")
	assert_eq(after_lockfile, before_lockfile, "拒绝卸载不应修改 lockfile。")
	assert_true(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "拒绝卸载不应删除扩展文件。")
	assert_true(_file_exists(project_root.path_join("addons/gf/standard/utilities/storage/gf_storage_fixture.gd")), "拒绝卸载不应删除依赖文件。")
	assert_true(_file_exists(extra_file), "拒绝卸载不应删除用户新增文件。")


func test_native_uninstall_delete_failure_rolls_back_files_and_lockfile() -> void:
	var project_root: String = TEST_ROOT.path_join("uninstall_rollback_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var install_fixture_result: Dictionary = _install_fixture_save(registry_path, project_root)
	assert_false(install_fixture_result.is_empty(), "测试 fixture 安装结果不应为空。")
	var before_lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))

	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.uninstall_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		false,
		false,
		{ "simulate_delete_failure_after": 1 }
	)
	var after_lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "模拟删除失败应让卸载失败。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "rolled_back"), "删除失败应报告已回滚。")
	assert_eq(after_lockfile, before_lockfile, "删除失败不能修改 lockfile。")
	assert_true(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "删除失败应恢复扩展文件。")
	assert_true(_file_exists(project_root.path_join("addons/gf/standard/utilities/storage/gf_storage_fixture.gd")), "删除失败应保留依赖文件。")


func test_native_recovery_restores_uninstall_payload_before_lockfile_commit() -> void:
	var project_root: String = TEST_ROOT.path_join("uninstall_transaction_crash_project")
	var registry_path: String = TEST_ROOT.path_join("registry/index.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_fixture_archives(registry)
	_write_json(registry_path, registry)
	var install_fixture_result: Dictionary = _install_fixture_save(registry_path, project_root)
	assert_false(install_fixture_result.is_empty(), "测试 fixture 安装结果不应为空。")
	var before_lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))

	var interrupted: Dictionary = GF_PACKAGE_MANAGER_BACKEND.uninstall_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root),
		".gf/packages.lock.json",
		false,
		false,
		{ "simulate_transaction_crash_at": "after_payload_applied" }
	)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(interrupted, "ok"), "模拟卸载 payload 落盘后中断不应报告成功。")
	assert_false(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "中断窗口中卸载 payload 已被删除。")

	var recovery: Dictionary = GF_PACKAGE_MANAGER_BACKEND.recover_package_transaction(
		ProjectSettings.globalize_path(project_root)
	)
	var after_lockfile: Dictionary = _read_json(project_root.path_join(".gf/packages.lock.json"))

	assert_true(GF_VARIANT_ACCESS.get_option_bool(recovery, "ok"), "未提交卸载事务应可恢复。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(recovery, "outcome"), "recovered_rollback", "未提交卸载应恢复旧 payload。")
	assert_eq(after_lockfile, before_lockfile, "恢复后 lockfile 应保持卸载前状态。")
	assert_true(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "恢复应从持久备份还原扩展文件。")
	assert_true(_file_exists(project_root.path_join("addons/gf/standard/utilities/storage/gf_storage_fixture.gd")), "恢复应从持久备份还原依赖文件。")


# --- 私有/辅助方法 ---

func _make_fixture_registry() -> Dictionary:
	var registry: Dictionary = {
		"schema_version": 2,
		"framework_version": "unreleased",
		"minimum_framework_version": "unreleased",
		"maximum_framework_version_exclusive": "",
		"packages": {
			"gf.kernel": {
				"version": "unreleased",
				"kind": "kernel",
				"display_name": "GF Kernel",
				"description": "Kernel fixture.",
				"dependencies": [],
				"paths": ["addons/gf/kernel/**"],
				"archive": "packages/gf-kernel.zip",
				"sha256": "",
				"size_bytes": 0,
			},
			"gf.standard.base": {
				"version": "unreleased",
				"kind": "standard",
				"display_name": "GF Standard Base",
				"description": "Base fixture.",
				"dependencies": ["gf.kernel"],
				"paths": ["addons/gf/standard/foundation/**"],
				"archive": "packages/gf-standard-base.zip",
				"sha256": "",
				"size_bytes": 0,
			},
			"gf.standard.storage": {
				"version": "unreleased",
				"kind": "standard",
				"display_name": "GF Standard Storage",
				"description": "Storage fixture.",
				"dependencies": ["gf.kernel", "gf.standard.base"],
				"paths": ["addons/gf/standard/utilities/storage/**"],
				"archive": "packages/gf-standard-storage.zip",
				"sha256": "",
				"size_bytes": 0,
			},
			"gf.extension.save": {
				"version": "unreleased",
				"kind": "extension",
				"display_name": "GF Save",
				"description": "Save fixture.",
				"dependencies": ["gf.kernel", "gf.standard.storage"],
				"paths": ["addons/gf/extensions/save/**"],
				"archive": "packages/gf-extension-save.zip",
				"sha256": "",
				"size_bytes": 0,
				"gf_extension_id": "gf.save",
			},
			"gf.preset.save": {
				"version": "unreleased",
				"kind": "preset",
				"display_name": "GF Save Preset",
				"description": "Save preset fixture.",
				"dependencies": [],
				"packages": ["gf.extension.save"],
				"paths": [],
			},
		},
	}
	var packages: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(registry, "packages")
	for package_id: String in _sorted_dictionary_keys(packages):
		var package_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(packages, package_id)
		package_entry["minimum_framework_version"] = "unreleased"
		package_entry["maximum_framework_version_exclusive"] = ""
		packages[package_id] = package_entry
	registry["packages"] = packages
	return registry


func _make_planned_lockfile(registry: Dictionary, package_ids: PackedStringArray) -> Dictionary:
	var packages: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(registry, "packages")
	var plan: Dictionary = GF_PACKAGE_MANAGER_BACKEND.make_install_plan(
		packages,
		{
			"schema_version": 1,
			"framework_version": "unreleased",
			"installed": {},
		},
		package_ids,
		"manual",
		TEST_ROOT.path_join(".gf/packages.lock.json")
	)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(plan, "ok"), "测试 fixture 应能生成安装计划。")
	var planned_lockfile: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(plan, "planned_lockfile")
	var installed: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(planned_lockfile, "installed")
	for package_id: String in _sorted_dictionary_keys(installed):
		var entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
		if GF_VARIANT_ACCESS.get_option_string(entry, "kind") == "preset":
			continue
		if not GF_VARIANT_ACCESS.get_option_packed_string_array(entry, "files").is_empty():
			continue
		var paths: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(entry, "paths")
		if paths.is_empty():
			continue
		var base_path: String = paths[0].replace("\\", "/")
		if base_path.ends_with("/**"):
			base_path = base_path.substr(0, base_path.length() - 3)
		if base_path.contains("*") or base_path.is_empty():
			base_path = "addons/gf"
		entry["files"] = [base_path.path_join("%s_fixture.gd" % package_id.replace(".", "_"))]
		installed[package_id] = entry
	planned_lockfile["installed"] = installed
	return planned_lockfile


func _set_registry_framework_range(registry: Dictionary, minimum_version: String, maximum_exclusive: String) -> void:
	registry["framework_version"] = minimum_version
	registry["minimum_framework_version"] = minimum_version
	registry["maximum_framework_version_exclusive"] = maximum_exclusive
	var packages: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(registry, "packages")
	for package_id: String in _sorted_dictionary_keys(packages):
		var package_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(packages, package_id)
		package_entry["minimum_framework_version"] = minimum_version
		package_entry["maximum_framework_version_exclusive"] = maximum_exclusive
		packages[package_id] = package_entry
	registry["packages"] = packages


func _write_project_plugin_cfg(project_root: String, framework_version: String) -> void:
	_write_text(
		project_root.path_join("addons/gf/plugin.cfg"),
		"[plugin]\nversion=\"%s\"\n" % framework_version
	)


func _write_fixture_archives(registry: Dictionary) -> void:
	_write_fixture_archives_at(registry, TEST_ROOT.path_join("registry"))


func _write_fixture_archives_at(registry: Dictionary, registry_root: String) -> void:
	_write_package_archive_at(
		registry,
		registry_root,
		"gf.kernel",
		{
			"addons/gf/kernel/core/gf_core_fixture.gd": "extends RefCounted\n",
		}
	)
	_write_package_archive_at(
		registry,
		registry_root,
		"gf.standard.base",
		{
			"addons/gf/standard/foundation/gf_base_fixture.gd": "extends RefCounted\n",
		}
	)
	_write_package_archive_at(
		registry,
		registry_root,
		"gf.standard.storage",
		{
			"addons/gf/standard/utilities/storage/gf_storage_fixture.gd": "extends RefCounted\n",
		}
	)
	_write_package_archive_at(
		registry,
		registry_root,
		"gf.extension.save",
		{
			"addons/gf/extensions/save/gf_save_fixture.gd": "extends RefCounted\n",
		}
	)


func _install_fixture_save(registry_path: String, project_root: String) -> Dictionary:
	var result: Dictionary = GF_PACKAGE_MANAGER_BACKEND.install_packages(
		PackedStringArray(["gf.extension.save"]),
		registry_path,
		ProjectSettings.globalize_path(project_root)
	)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "测试 fixture 应能安装 save 闭包。")
	return result


func _write_package_archive(registry: Dictionary, package_id: String, entries: Dictionary) -> void:
	_write_package_archive_at(registry, TEST_ROOT.path_join("registry"), package_id, entries)


func _write_package_archive_at(registry: Dictionary, registry_root: String, package_id: String, entries: Dictionary) -> void:
	var packages: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(registry, "packages")
	var package_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(packages, package_id)
	var archive_path: String = _package_archive_path(package_entry, registry_root)
	var make_error: Error = DirAccess.make_dir_recursive_absolute(archive_path.get_base_dir())
	assert_eq(make_error, OK, "测试应能创建 archive 目录。")

	var writer: ZIPPacker = ZIPPacker.new()
	var open_error: Error = writer.open(archive_path)
	assert_eq(open_error, OK, "测试应能创建 zip archive。")
	if open_error != OK:
		return
	for entry_path: String in _sorted_dictionary_keys(entries):
		var start_error: Error = writer.start_file(entry_path)
		assert_eq(start_error, OK, "测试应能创建 zip entry。")
		var content: String = GF_VARIANT_ACCESS.to_text(entries.get(entry_path, ""))
		var write_error: Error = writer.write_file(content.to_utf8_buffer())
		assert_eq(write_error, OK, "测试应能写入 zip entry。")
		var close_file_error: Error = writer.close_file()
		assert_eq(close_file_error, OK, "测试应能关闭 zip entry。")
	var close_error: Error = writer.close()
	assert_eq(close_error, OK, "测试应能关闭 zip archive。")

	package_entry["sha256"] = FileAccess.get_sha256(archive_path).to_lower()
	package_entry["size_bytes"] = _file_size_absolute(archive_path)
	packages[package_id] = package_entry
	registry["packages"] = packages


func _write_offline_bundle(registry: Dictionary, bundle_path: String) -> void:
	var source_root: String = TEST_ROOT.path_join("offline_bundle_source").path_join(bundle_path.get_base_dir().get_file())
	var registry_root: String = source_root.path_join("registry")
	var bundle_registry: Dictionary = registry.duplicate(true)
	_rewrite_registry_archives_for_offline_bundle(bundle_registry)
	_write_fixture_archives_at(bundle_registry, registry_root)
	_write_json(registry_root.path_join("index.json"), bundle_registry)
	_write_offline_bundle_zip(source_root, bundle_path)


func _rewrite_registry_archives_for_offline_bundle(registry: Dictionary) -> void:
	var packages: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(registry, "packages")
	for package_id: String in _sorted_dictionary_keys(packages):
		var entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(packages, package_id)
		var archive: String = GF_VARIANT_ACCESS.get_option_string(entry, "archive")
		if archive.is_empty():
			continue
		entry["archive"] = "../packages/%s" % archive.get_file()
		packages[package_id] = entry
	registry["packages"] = packages


func _write_offline_bundle_zip(source_root: String, bundle_path: String) -> void:
	var absolute_bundle_path: String = ProjectSettings.globalize_path(bundle_path).replace("\\", "/")
	var make_error: Error = DirAccess.make_dir_recursive_absolute(absolute_bundle_path.get_base_dir())
	assert_eq(make_error, OK, "测试应能创建 offline bundle 输出目录。")
	var writer: ZIPPacker = ZIPPacker.new()
	var open_error: Error = writer.open(absolute_bundle_path)
	assert_eq(open_error, OK, "测试应能创建 offline bundle zip。")
	if open_error != OK:
		return
	_write_zip_file_entry(writer, "registry/index.json", source_root.path_join("registry/index.json"))
	var package_dir_absolute: String = ProjectSettings.globalize_path(source_root.path_join("packages")).replace("\\", "/")
	var package_directory: DirAccess = DirAccess.open(package_dir_absolute)
	assert_not_null(package_directory, "测试应能打开 offline bundle packages 目录。")
	if package_directory != null:
		var list_error: Error = package_directory.list_dir_begin()
		assert_eq(list_error, OK, "测试应能枚举 offline bundle packages 目录。")
		if list_error == OK:
			while true:
				var file_name: String = package_directory.get_next()
				if file_name.is_empty():
					break
				if file_name == "." or file_name == ".." or package_directory.current_is_dir():
					continue
				_write_zip_file_entry(writer, "packages/%s" % file_name, source_root.path_join("packages").path_join(file_name))
			package_directory.list_dir_end()
	var close_error: Error = writer.close()
	assert_eq(close_error, OK, "测试应能关闭 offline bundle zip。")


func _write_zip_file_entry(writer: ZIPPacker, entry_path: String, source_path: String) -> void:
	var absolute_source_path: String = ProjectSettings.globalize_path(source_path).replace("\\", "/")
	var file: FileAccess = FileAccess.open(absolute_source_path, FileAccess.READ)
	assert_not_null(file, "测试应能读取 offline bundle 输入文件。")
	if file == null:
		return
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var start_error: Error = writer.start_file(entry_path)
	assert_eq(start_error, OK, "测试应能创建 offline bundle entry。")
	if start_error != OK:
		return
	var write_error: Error = writer.write_file(bytes)
	assert_eq(write_error, OK, "测试应能写入 offline bundle entry。")
	var close_file_error: Error = writer.close_file()
	assert_eq(close_file_error, OK, "测试应能关闭 offline bundle entry。")


func _write_zip_entries(zip_path: String, entries: Dictionary) -> void:
	var absolute_zip_path: String = ProjectSettings.globalize_path(zip_path).replace("\\", "/")
	var make_error: Error = DirAccess.make_dir_recursive_absolute(absolute_zip_path.get_base_dir())
	assert_eq(make_error, OK, "测试应能创建 zip 输出目录。")
	var writer: ZIPPacker = ZIPPacker.new()
	var open_error: Error = writer.open(absolute_zip_path)
	assert_eq(open_error, OK, "测试应能创建 zip 文件。")
	if open_error != OK:
		return
	for entry_path: String in _sorted_dictionary_keys(entries):
		var start_error: Error = writer.start_file(entry_path)
		assert_eq(start_error, OK, "测试应能创建 zip entry。")
		if start_error != OK:
			continue
		var entry_text: String = GF_VARIANT_ACCESS.to_text(entries.get(entry_path, ""))
		var write_error: Error = writer.write_file(entry_text.to_utf8_buffer())
		assert_eq(write_error, OK, "测试应能写入 zip entry。")
		var close_file_error: Error = writer.close_file()
		assert_eq(close_file_error, OK, "测试应能关闭 zip entry。")
	var close_error: Error = writer.close()
	assert_eq(close_error, OK, "测试应能关闭 zip 文件。")


func _repeat_text(text: String, count: int) -> String:
	var result: String = ""
	for _index: int in range(maxi(count, 0)):
		result += text
	return result


func _package_archive_path(package_entry: Dictionary, registry_root: String = TEST_ROOT.path_join("registry")) -> String:
	var archive_relative: String = GF_VARIANT_ACCESS.get_option_string(package_entry, "archive")
	var absolute_path: String = ProjectSettings.globalize_path(registry_root.path_join(archive_relative)).replace("\\", "/")
	return absolute_path.simplify_path()


func _package_index(status: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_entry: Variant in GF_VARIANT_ACCESS.get_option_array(status, "packages"):
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			var package_id: String = GF_VARIANT_ACCESS.get_option_string(entry, "id")
			result[package_id] = entry
	return result


func _find_plan_entry(entries: Array, package_id: String) -> Dictionary:
	for raw_entry: Variant in entries:
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			if GF_VARIANT_ACCESS.get_option_string(entry, "package_id") == package_id:
				return entry
	return {}


func _blocked_contains_reason(blocked: Array, reason: String) -> bool:
	for raw_item: Variant in blocked:
		if raw_item is Dictionary:
			var item: Dictionary = raw_item
			if GF_VARIANT_ACCESS.get_option_string(item, "reason") == reason:
				return true
	return false


func _issues_contain(issues: PackedStringArray, text: String) -> bool:
	for issue: String in issues:
		if issue.contains(text):
			return true
	return false


func _write_json(path: String, data: Dictionary) -> void:
	_write_text(path, JSON.stringify(data, "\t", false))


func _read_json(path: String) -> Dictionary:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	return _read_json_absolute(absolute_path)


func _read_json_absolute(absolute_path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
	assert_not_null(file, "测试应能读取 JSON 文件。")
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		var data: Dictionary = parsed
		return data
	return {}


func _remove_lockfile_files_for_packages(project_root: String, package_ids: PackedStringArray) -> void:
	var lockfile_path: String = project_root.path_join(".gf/packages.lock.json")
	var lockfile: Dictionary = _read_json(lockfile_path)
	var installed: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(lockfile, "installed")
	for package_id: String in package_ids:
		var entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(installed, package_id)
		if entry.is_empty():
			continue
		var _erased_files: bool = entry.erase("files")
		installed[package_id] = entry
	lockfile["installed"] = installed
	_write_json(lockfile_path, lockfile)


func _start_http_fixture_server(root_path: String) -> HttpFixtureServer:
	var server: HttpFixtureServer = HttpFixtureServer.new()
	var start_error: Error = server.start(ProjectSettings.globalize_path(root_path).replace("\\", "/"))
	assert_eq(start_error, OK, "测试 HTTP fixture server 应能启动。")
	return server


func _cache_has_file(path: String, suffix: String) -> bool:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return false
	var files: PackedStringArray = PackedStringArray()
	_collect_files_absolute(absolute_path, files)
	for file_path: String in files:
		if file_path.ends_with(suffix):
			return true
	return false


func _cache_file_with_suffix(path: String, suffix: String, excluded_suffix: String = "") -> String:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return ""
	var files: PackedStringArray = PackedStringArray()
	_collect_files_absolute(absolute_path, files)
	for file_path: String in files:
		if not file_path.ends_with(suffix):
			continue
		if not excluded_suffix.is_empty() and file_path.ends_with(excluded_suffix):
			continue
		return file_path
	return ""


func _collect_files_absolute(path: String, result: PackedStringArray) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	directory.include_hidden = true
	var list_error: Error = directory.list_dir_begin()
	if list_error != OK:
		return
	while true:
		var item_name: String = directory.get_next()
		if item_name.is_empty():
			break
		if item_name == "." or item_name == "..":
			continue
		var absolute_path: String = path.path_join(item_name)
		if directory.current_is_dir():
			_collect_files_absolute(absolute_path, result)
		else:
			var _append_file: bool = result.append(absolute_path)
	directory.list_dir_end()


func _write_text(path: String, text: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var directory_path: String = absolute_path.get_base_dir()
	var _make_result: Error = DirAccess.make_dir_recursive_absolute(directory_path)
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	assert_not_null(file, "测试应能写入 fixture 文件。")
	if file == null:
		return
	var _store_text_result: Variant = file.store_string(text)
	file.close()


func _read_text(path: String) -> String:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
	assert_not_null(file, "测试应能读取 fixture 文本文件。")
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _file_exists(path: String) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(path))


func _directory_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))


func _latest_journal_path(directory_path: String) -> String:
	var absolute_directory: String = ProjectSettings.globalize_path(directory_path)
	var directory: DirAccess = DirAccess.open(absolute_directory)
	assert_not_null(directory, "测试应能打开 active transaction 目录。")
	if directory == null:
		return ""
	var list_error: Error = directory.list_dir_begin()
	assert_eq(list_error, OK, "测试应能枚举 transaction journal。")
	var names: PackedStringArray = PackedStringArray()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.begins_with("journal-") and file_name.ends_with(".json"):
			var _append_name: bool = names.append(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
	names.sort()
	assert_false(names.is_empty(), "active transaction 应至少包含一个 journal snapshot。")
	if names.is_empty():
		return ""
	return absolute_directory.path_join(names[names.size() - 1])


func _file_size_absolute(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "测试应能读取 archive 大小。")
	if file == null:
		return -1
	var size: int = file.get_length()
	file.close()
	return size


func _sorted_dictionary_keys(data: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for raw_key: Variant in data.keys():
		var _append_key: bool = result.append(GF_VARIANT_ACCESS.to_text(raw_key))
	result.sort()
	return result


func _remove_path_recursive(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		var _remove_file_result: Error = DirAccess.remove_absolute(absolute_path)
		return
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var directory: DirAccess = DirAccess.open(absolute_path)
	if directory == null:
		return
	directory.include_hidden = true
	var list_error: Error = directory.list_dir_begin()
	if list_error == OK:
		while true:
			var item_name: String = directory.get_next()
			if item_name.is_empty():
				break
			if item_name == "." or item_name == "..":
				continue
			_remove_path_recursive(path.path_join(item_name))
		directory.list_dir_end()
	var _remove_dir_result: Error = DirAccess.remove_absolute(absolute_path)


# --- 内部类 ---

class HttpFixtureServer:
	extends RefCounted

	var root_path: String = ""
	var port: int = 0
	var _server: TCPServer = TCPServer.new()
	var _thread: Thread = Thread.new()
	var _stop_requested: bool = false


	func start(p_root_path: String) -> Error:
		root_path = p_root_path
		for offset: int in range(100):
			var candidate_port: int = 25000 + int(Time.get_ticks_usec() % 10000) + offset
			var listen_error: Error = _server.listen(candidate_port, "127.0.0.1")
			if listen_error != OK:
				continue
			port = candidate_port
			var start_error: Error = _thread.start(Callable(self, "_serve"))
			if start_error != OK:
				_server.stop()
				return start_error
			return OK
		return ERR_CANT_CREATE


	func stop() -> void:
		_stop_requested = true
		if _thread.is_started():
			_thread.wait_to_finish()
		_server.stop()


	func url(relative_path: String) -> String:
		var normalized: String = relative_path.strip_edges().replace("\\", "/")
		while normalized.begins_with("/"):
			normalized = normalized.substr(1)
		return "http://127.0.0.1:%d/%s" % [port, normalized]


	func _serve() -> void:
		while not _stop_requested:
			if not _server.is_connection_available():
				OS.delay_msec(5)
				continue
			var peer: StreamPeerTCP = _server.take_connection()
			if peer != null:
				_handle_peer(peer)


	func _handle_peer(peer: StreamPeerTCP) -> void:
		var request: String = _read_request(peer)
		var relative_path: String = _request_relative_path(request)
		var absolute_path: String = _safe_absolute_path(relative_path)
		if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
			_send_response(peer, 404, PackedByteArray())
			return
		var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
		if file == null:
			_send_response(peer, 500, PackedByteArray())
			return
		var bytes: PackedByteArray = file.get_buffer(file.get_length())
		file.close()
		_send_response(peer, 200, bytes)


	func _read_request(peer: StreamPeerTCP) -> String:
		var request: String = ""
		var deadline: int = Time.get_ticks_msec() + 3000
		while Time.get_ticks_msec() <= deadline:
			var available: int = peer.get_available_bytes()
			if available > 0:
				request += peer.get_utf8_string(available)
				if request.contains("\r\n\r\n"):
					return request
			OS.delay_msec(5)
		return request


	func _request_relative_path(request: String) -> String:
		var first_line_end: int = request.find("\r\n")
		var first_line: String = request if first_line_end < 0 else request.substr(0, first_line_end)
		var parts: PackedStringArray = first_line.split(" ", false)
		if parts.size() < 2:
			return ""
		var request_path: String = parts[1]
		var query_index: int = request_path.find("?")
		if query_index >= 0:
			request_path = request_path.substr(0, query_index)
		while request_path.begins_with("/"):
			request_path = request_path.substr(1)
		return request_path.uri_decode()


	func _safe_absolute_path(relative_path: String) -> String:
		var normalized: String = relative_path.strip_edges().replace("\\", "/")
		if normalized.is_empty() or normalized.contains(":"):
			return ""
		var parts: PackedStringArray = normalized.split("/", false)
		var safe_parts: PackedStringArray = PackedStringArray()
		for part: String in parts:
			if part.is_empty() or part == "." or part == "..":
				return ""
			var _append_part: bool = safe_parts.append(part)
		var absolute_path: String = root_path.path_join("/".join(safe_parts)).replace("\\", "/")
		if absolute_path == root_path or absolute_path.begins_with(root_path + "/"):
			return absolute_path
		return ""


	func _send_response(peer: StreamPeerTCP, status_code: int, body: PackedByteArray) -> void:
		var reason: String = "OK" if status_code == 200 else "Not Found"
		if status_code == 500:
			reason = "Internal Server Error"
		var header: String = (
			"HTTP/1.1 %d %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n"
			% [status_code, reason, body.size()]
		)
		var _header_error: Error = peer.put_data(header.to_utf8_buffer())
		if not body.is_empty():
			var _body_error: Error = peer.put_data(body)
		peer.disconnect_from_host()
