## 测试资产目录运行时的事务挂载、所有权和快照隔离契约。
extends GutTest


# --- 测试用例 ---

func test_mount_provider_commits_snapshot_and_unmount_is_idempotent() -> void:
	var runtime: GFAssetCatalogRuntime = GFAssetCatalogRuntime.new()
	runtime.init()
	var source_catalog: GFAssetCatalog = _make_catalog(&"ui.save", "res://ui/save.png", &"provider")
	var provider: StaticCatalogProvider = StaticCatalogProvider.new()
	provider.setup(&"provider", source_catalog)

	var mount: GFAssetCatalogMount = runtime.mount_provider(&"feature.ui", &"toolbar", provider)
	var revision_after_mount: int = runtime.get_revision()
	var _mutated_source: bool = source_catalog.set_entry(
		_make_entry(&"ui.load", "res://ui/load.png", &"provider")
	)

	assert_true(mount.is_active(), "成功 mount 应返回活动句柄。")
	assert_eq(mount.get_owner_id(), &"feature.ui")
	assert_eq(mount.get_mount_id(), &"toolbar")
	assert_eq(runtime.get_catalog().get_all_ids(), PackedStringArray(["ui.save"]))
	assert_eq(revision_after_mount, 1)
	assert_true(mount.unmount())
	assert_false(mount.unmount(), "重复 unmount 必须无副作用。")
	assert_false(mount.is_active())
	assert_eq(runtime.get_catalog().get_all_ids(), PackedStringArray())
	assert_eq(runtime.get_revision(), revision_after_mount + 1)


func test_mount_rejects_duplicate_assets_without_mutating_committed_state() -> void:
	var runtime: GFAssetCatalogRuntime = GFAssetCatalogRuntime.new()
	runtime.init()
	var first_mount: GFAssetCatalogMount = runtime.mount_catalog(
		&"feature.a",
		&"first",
		_make_catalog(&"shared.icon", "res://first.png", &"first"),
		10
	)
	var revision_before_failure: int = runtime.get_revision()
	var failed_mount: GFAssetCatalogMount = runtime.mount_catalog(
		&"feature.b",
		&"second",
		_make_catalog(&"shared.icon", "res://second.png", &"second"),
		100
	)
	var committed_entry: GFAssetCatalogEntry = runtime.get_catalog().get_entry(&"shared.icon")

	assert_true(first_mount.is_active())
	assert_false(failed_mount.is_active(), "默认冲突策略必须 fail-closed。")
	assert_eq(failed_mount.get_status(), GFAssetCatalogMount.STATUS_CONFLICT)
	assert_eq(runtime.get_revision(), revision_before_failure, "失败 mount 不得推进 revision。")
	assert_false(GFVariantData.get_option_bool(runtime.get_last_report(), "ok"))
	assert_eq(runtime.get_mounts().size(), 1)
	assert_not_null(committed_entry)
	if committed_entry != null:
		assert_eq(committed_entry.primary_path, "res://first.png")


func test_explicit_high_priority_conflict_policy_is_deterministic() -> void:
	var runtime: GFAssetCatalogRuntime = GFAssetCatalogRuntime.new()
	var configured_runtime: GFAssetCatalogRuntime = runtime.configure(
		GFAssetCatalogRuntime.CONFLICT_KEEP_HIGH_PRIORITY
	)
	configured_runtime.init()

	var low_mount: GFAssetCatalogMount = runtime.mount_catalog(
		&"feature.low",
		&"low",
		_make_catalog(&"shared.icon", "res://low.png", &"low"),
		1
	)
	var high_mount: GFAssetCatalogMount = runtime.mount_catalog(
		&"feature.high",
		&"high",
		_make_catalog(&"shared.icon", "res://high.png", &"high"),
		100
	)
	var entry: GFAssetCatalogEntry = runtime.get_catalog().get_entry(&"shared.icon")

	assert_true(low_mount.is_active())
	assert_true(high_mount.is_active())
	assert_not_null(entry)
	if entry != null:
		assert_eq(entry.primary_path, "res://high.png", "显式覆盖策略应稳定选择高优先级 mount。")


func test_owner_unmount_and_dispose_deactivate_all_handles() -> void:
	var runtime: GFAssetCatalogRuntime = GFAssetCatalogRuntime.new()
	runtime.init()
	var first_mount: GFAssetCatalogMount = runtime.mount_catalog(
		&"feature.ui",
		&"first",
		_make_catalog(&"ui.first", "res://first.png", &"first")
	)
	var second_mount: GFAssetCatalogMount = runtime.mount_catalog(
		&"feature.ui",
		&"second",
		_make_catalog(&"ui.second", "res://second.png", &"second")
	)
	var other_mount: GFAssetCatalogMount = runtime.mount_catalog(
		&"feature.other",
		&"other",
		_make_catalog(&"other", "res://other.png", &"other")
	)

	assert_eq(runtime.unmount_owner(&"feature.ui"), 2)
	assert_false(first_mount.is_active())
	assert_false(second_mount.is_active())
	assert_true(other_mount.is_active())
	assert_eq(runtime.get_catalog().get_all_ids(), PackedStringArray(["other"]))

	runtime.dispose()
	assert_false(other_mount.is_active(), "runtime dispose 必须使外部 handle 进入终态。")
	assert_eq(other_mount.get_status(), GFAssetCatalogMount.STATUS_DISPOSED)
	assert_eq(runtime.get_catalog().get_all_ids(), PackedStringArray())


func test_runtime_retains_active_mount_handle_until_owner_unmounts() -> void:
	var runtime: GFAssetCatalogRuntime = GFAssetCatalogRuntime.new()
	runtime.init()
	var mount: GFAssetCatalogMount = runtime.mount_catalog(
		&"feature.retained",
		&"retained",
		_make_catalog(&"retained", "res://retained.tres", &"retained")
	)
	var weak_mount: WeakRef = weakref(mount)
	mount = null
	var retained_value: Variant = weak_mount.get_ref()

	assert_true(retained_value is GFAssetCatalogMount, "Runtime 必须强持有活动 Mount，避免不可管理的存活目录。")
	assert_eq(runtime.get_mounts().size(), 1)
	assert_eq(runtime.unmount_owner(&"feature.retained"), 1)
	assert_eq(runtime.get_mounts().size(), 0)


func test_mount_catalog_replacement_is_atomic_and_preserves_handle_identity() -> void:
	var runtime: GFAssetCatalogRuntime = GFAssetCatalogRuntime.new()
	runtime.init()
	var mount: GFAssetCatalogMount = runtime.mount_catalog(
		&"feature.a",
		&"primary",
		_make_catalog(&"first", "res://first.tres", &"primary")
	)
	var first_revision: int = runtime.get_revision()

	assert_true(runtime.replace_mount_catalog(
		mount,
		_make_catalog(&"replacement", "res://replacement.tres", &"primary")
	))
	assert_true(mount.is_active())
	assert_eq(mount.get_catalog().get_all_ids(), PackedStringArray(["replacement"]))
	assert_eq(runtime.get_revision(), first_revision + 1)

	var other_mount: GFAssetCatalogMount = runtime.mount_catalog(
		&"feature.b",
		&"other",
		_make_catalog(&"other", "res://other.tres", &"other")
	)
	var revision_before_conflict: int = runtime.get_revision()
	assert_false(runtime.replace_mount_catalog(
		mount,
		_make_catalog(&"other", "res://conflict.tres", &"primary")
	), "冲突替换必须保留上一份 Mount 和聚合目录。")
	assert_true(other_mount.is_active())
	assert_eq(runtime.get_revision(), revision_before_conflict)
	assert_eq(mount.get_catalog().get_all_ids(), PackedStringArray(["replacement"]))
	assert_eq(runtime.get_catalog().get_all_ids(), PackedStringArray(["other", "replacement"]))


func test_null_provider_and_duplicate_mount_key_fail_without_partial_commit() -> void:
	var runtime: GFAssetCatalogRuntime = GFAssetCatalogRuntime.new()
	runtime.init()
	var null_provider: NullCatalogProvider = NullCatalogProvider.new()
	var _null_provider_configured: GFAssetCatalogSourceProvider = null_provider.configure(&"null")
	var provider_failure: GFAssetCatalogMount = runtime.mount_provider(
		&"feature.a",
		&"null",
		null_provider
	)
	var active_mount: GFAssetCatalogMount = runtime.mount_catalog(
		&"feature.a",
		&"stable",
		_make_catalog(&"stable", "res://stable.tres", &"stable")
	)
	var duplicate_mount: GFAssetCatalogMount = runtime.mount_catalog(
		&"feature.a",
		&"stable",
		_make_catalog(&"replacement", "res://replacement.tres", &"replacement")
	)

	assert_false(provider_failure.is_active())
	assert_eq(provider_failure.get_status(), GFAssetCatalogMount.STATUS_BUILD_FAILED)
	assert_true(active_mount.is_active())
	assert_false(duplicate_mount.is_active())
	assert_eq(duplicate_mount.get_status(), GFAssetCatalogMount.STATUS_DUPLICATE_MOUNT)
	assert_eq(runtime.get_catalog().get_all_ids(), PackedStringArray(["stable"]))


func test_rejected_provider_request_does_not_invoke_provider() -> void:
	var runtime: GFAssetCatalogRuntime = GFAssetCatalogRuntime.new()
	runtime.init()
	var provider: CountingCatalogProvider = CountingCatalogProvider.new()
	provider.setup(&"counting", _make_catalog(&"asset", "res://asset.tres", &"counting"))
	var first_mount: GFAssetCatalogMount = runtime.mount_provider(&"feature.a", &"stable", provider)
	var duplicate_mount: GFAssetCatalogMount = runtime.mount_provider(&"feature.a", &"stable", provider)
	runtime.dispose()
	var disposed_mount: GFAssetCatalogMount = runtime.mount_provider(&"feature.b", &"late", provider)

	assert_true(first_mount.get_status() == GFAssetCatalogMount.STATUS_DISPOSED)
	assert_eq(duplicate_mount.get_status(), GFAssetCatalogMount.STATUS_DUPLICATE_MOUNT)
	assert_eq(disposed_mount.get_status(), GFAssetCatalogMount.STATUS_DISPOSED)
	assert_eq(provider.build_count, 1, "Runtime 已知拒绝请求时不得执行 Provider。")


# --- 私有/辅助方法 ---

func _make_catalog(asset_id: StringName, path: String, source_id: StringName) -> GFAssetCatalog:
	var catalog: GFAssetCatalog = GFAssetCatalog.new()
	var _entry_set: bool = catalog.set_entry(_make_entry(asset_id, path, source_id))
	return catalog


func _make_entry(asset_id: StringName, path: String, source_id: StringName) -> GFAssetCatalogEntry:
	return GFAssetCatalogEntry.new().configure(asset_id, path, {"source_id": source_id})


class StaticCatalogProvider:
	extends GFAssetCatalogSourceProvider

	var _catalog: GFAssetCatalog = GFAssetCatalog.new()

	func setup(p_source_id: StringName, catalog: GFAssetCatalog) -> void:
		var _provider_configured: GFAssetCatalogSourceProvider = configure(p_source_id)
		_catalog = GFAssetCatalog.from_dict(catalog.to_dict())

	func build_catalog(_options: Dictionary = {}) -> GFAssetCatalog:
		return GFAssetCatalog.from_dict(_catalog.to_dict())


class NullCatalogProvider:
	extends GFAssetCatalogSourceProvider

	func build_catalog(_options: Dictionary = {}) -> GFAssetCatalog:
		return null


class CountingCatalogProvider:
	extends StaticCatalogProvider

	var build_count: int = 0

	func build_catalog(options: Dictionary = {}) -> GFAssetCatalog:
		build_count += 1
		return super.build_catalog(options)
