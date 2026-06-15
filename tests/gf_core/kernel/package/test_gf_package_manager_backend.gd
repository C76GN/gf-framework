extends GutTest


# --- 常量 ---

const GF_PACKAGE_MANAGER_BACKEND = preload("res://addons/gf/kernel/package/gf_package_manager_backend.gd")
const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const TEST_ROOT: String = "res://ai_analysis/tmp_package_manager_backend"


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_remove_path_recursive(TEST_ROOT)
	var _make_result: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT))


func after_each() -> void:
	_remove_path_recursive(TEST_ROOT)


# --- 测试用例 ---

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

	assert_true(GF_VARIANT_ACCESS.get_option_bool(status, "ok"), "本地 registry 状态读取应成功。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(status, "backend"), "godot_native", "状态页应标明使用 Godot 原生后端。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status, "package_count"), 5, "状态页应列出 registry 中的全部包。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status, "installed_count"), 0, "空项目不应报告已安装包。")
	assert_true(to_install.has("gf.kernel"), "preset 安装预览应展开 kernel 依赖。")
	assert_true(to_install.has("gf.standard.storage"), "preset 安装预览应展开 standard 依赖。")
	assert_true(to_install.has("gf.extension.save"), "preset 安装预览应展开扩展包。")


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
	var lockfile_path: String = project_root.path_join(".gf/packages.lock.json")
	var registry: Dictionary = _make_fixture_registry()
	_write_json(registry_path, registry)
	_write_json(lockfile_path, _make_planned_lockfile(registry, PackedStringArray(["gf.standard.storage"])))
	_write_text(
		project_root.path_join("addons/gf/standard/utilities/storage/gf_storage_utility.gd"),
		"class_name GFStorageUtility\nextends RefCounted\n"
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
	var save_entry: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(installed, "gf.extension.save")
	var save_files: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(save_entry, "files")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "Godot 原生后端应能安装本地 archive 闭包。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(result, "backend"), "godot_native", "安装结果应标记 Godot 原生后端。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(result, "installed_file_count"), 4, "四个非 preset 包各包含一个 fixture 文件。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "lockfile_written"), "真实安装应最后写入 lockfile。")
	assert_true(_file_exists(project_root.path_join("addons/gf/kernel/core/gf_core_fixture.gd")), "kernel fixture 应写入项目。")
	assert_true(_file_exists(project_root.path_join("addons/gf/standard/foundation/gf_base_fixture.gd")), "standard base fixture 应写入项目。")
	assert_true(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "extension fixture 应写入项目。")
	assert_true(installed.has("gf.standard.storage"), "lockfile 应记录扩展依赖的 standard 包。")
	assert_true(save_files.has("addons/gf/extensions/save/gf_save_fixture.gd"), "lockfile 应记录包安装文件清单。")


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

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "dry-run 应完成计划、archive 校验和 staging。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "dry_run"), "结果应标记 dry-run。")
	assert_false(_file_exists(project_root.path_join(".gf/packages.lock.json")), "dry-run 不应写 lockfile。")
	assert_false(_file_exists(project_root.path_join("addons/gf/extensions/save/gf_save_fixture.gd")), "dry-run 不应写包文件。")


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
	assert_true(_cache_has_file(project_root.path_join(".gf/package_cache/registries"), ".json"), "HTTP registry 应写入 registry cache。")
	assert_true(GF_VARIANT_ACCESS.get_option_string(save_entry, "archive").begins_with("http://127.0.0.1:"), "相对 archive URL 应在缓存 registry 中重写为 HTTP URL。")


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
	assert_true(_cache_has_file(project_root.path_join(".gf/package_cache/registries"), ".json"), "source manifest 与 mirror registry 都应写入 registry cache。")


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
		"channels": {
			"stable": {
				"registry": "../signature_registry/index.json",
				"registry_sha256": FileAccess.get_sha256(registry_absolute).to_lower(),
				"registry_size_bytes": _file_size_absolute(registry_absolute),
				"registry_signature_url": "gf-registry.sig",
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
	assert_true(_cache_has_file(project_root.path_join(".gf/package_cache/archives"), ".zip"), "远程 archive 应写入 archive cache。")
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
	assert_true(_cache_has_file(project_root.path_join(".gf/package_cache/offline_bundles"), ".zip"), "offline bundle package archives 应解包到项目缓存。")


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


# --- 私有/辅助方法 ---

func _make_fixture_registry() -> Dictionary:
	return {
		"schema_version": 1,
		"framework_version": "unreleased",
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
				"enable_extension": "gf.save",
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


func _package_archive_path(package_entry: Dictionary, registry_root: String = TEST_ROOT.path_join("registry")) -> String:
	var archive_relative: String = GF_VARIANT_ACCESS.get_option_string(package_entry, "archive")
	return ProjectSettings.globalize_path(registry_root.path_join(archive_relative)).replace("\\", "/")


func _package_index(status: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_entry: Variant in GF_VARIANT_ACCESS.get_option_array(status, "packages"):
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			var package_id: String = GF_VARIANT_ACCESS.get_option_string(entry, "id")
			result[package_id] = entry
	return result


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


func _collect_files_absolute(path: String, result: PackedStringArray) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
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


func _file_exists(path: String) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(path))


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
