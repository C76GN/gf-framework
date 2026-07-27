extends GutTest

const GF_ASSET_SLOT_SCRIPT = preload(
	"res://addons/gf/standard/utilities/assets/gf_asset_slot.gd"
)
const GF_RESOURCE_IDENTITY_SCRIPT = preload(
	"res://addons/gf/standard/utilities/assets/gf_resource_identity.gd"
)


func test_configure_commits_stable_identity_and_initial_generation() -> void:
	var identity: GFResourceIdentity = _make_identity("Resource")
	identity.metadata = { "source": "original" }
	var initial_resource: Resource = Resource.new()
	var slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()

	assert_true(
		slot.configure(identity, initial_resource),
		"有效身份和兼容初始资源应成功配置槽位。"
	)
	assert_eq(slot.get_generation(), 1, "成功配置是首次状态提交。")
	assert_eq(slot.get_resource(), initial_resource, "槽位应直接强持有初始资源。")
	assert_eq(slot.get_type_hint(), "Resource", "未覆盖时应采用身份 type_hint。")
	assert_false(slot.configure(identity), "槽位只允许成功配置一次。")

	identity.cache_key = "mutated://outside"
	identity.metadata["source"] = "mutated"
	var first_snapshot: GFResourceIdentity = slot.get_resource_identity()
	assert_ne(
		first_snapshot.cache_key,
		identity.cache_key,
		"配置后修改外部身份不得污染槽位。"
	)
	assert_eq(
		GFVariantData.get_option_string(first_snapshot.metadata, "source"),
		"original",
		"身份 metadata 应深复制。"
	)

	first_snapshot.cache_key = "mutated://snapshot"
	assert_ne(
		slot.get_resource_identity().cache_key,
		first_snapshot.cache_key,
		"身份 getter 也必须返回副本。"
	)


func test_failed_configuration_is_atomic_and_can_be_retried() -> void:
	var slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()
	var typed_identity: GFResourceIdentity = _make_identity("GFAssetCatalog")

	assert_false(slot.is_configured(), "新槽位尚未配置。")
	assert_false(slot.is_released(), "未配置与不可逆释放终态必须保持区分。")
	assert_eq(slot.get_generation(), 0, "未配置槽位 generation 应为 0。")
	assert_false(
		slot.configure(typed_identity, Resource.new()),
		"类型不兼容的初始资源应被拒绝。"
	)
	assert_eq(slot.get_generation(), 0, "失败配置不得推进 generation。")
	assert_null(slot.get_resource_identity(), "失败配置不得提交身份。")

	var catalog: GFAssetCatalog = GFAssetCatalog.new()
	assert_true(slot.configure(typed_identity, catalog), "失败后仍应允许有效配置。")
	assert_true(slot.is_configured())
	assert_eq(slot.get_generation(), 1, "首次成功配置应只推进一次。")


func test_explicit_type_hint_override_controls_replacements() -> void:
	var slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()
	var catalog: GFAssetCatalog = GFAssetCatalog.new()
	var identity: GFResourceIdentity = _make_identity("Resource")

	assert_true(
		slot.configure(identity, catalog, null, "  GFAssetCatalog  "),
		"显式 type_hint 应覆盖身份提示并规范化空白。"
	)
	assert_eq(slot.get_type_hint(), "GFAssetCatalog")
	assert_true(slot.accepts_resource(GFAssetCatalog.new()))
	assert_false(slot.accepts_resource(Resource.new()))
	assert_false(
		slot.replace(Resource.new()),
		"不兼容资源不得改变槽位。"
	)
	assert_eq(slot.get_generation(), 1, "类型失败不得推进 generation。")

	var native_slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()
	assert_true(
		native_slot.configure(_make_identity("Texture2D"), ImageTexture.new()),
		"类型校验应支持 Godot 原生继承关系。"
	)

	var script_resource: GFAssetCatalog = GFAssetCatalog.new()
	var resource_script: Script = _get_script(script_resource.get_script())
	assert_not_null(resource_script)
	var script_path_slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()
	assert_true(
		script_path_slot.configure(
			_make_identity(resource_script.resource_path),
			script_resource
		),
		"类型校验应支持脚本资源路径。"
	)
	assert_true(script_path_slot.replace(GFAssetCatalog.new()))


func test_replace_commits_before_signal_and_rejects_no_ops() -> void:
	var slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()
	var initial_resource: Resource = Resource.new()
	var replacement: Resource = Resource.new()
	assert_true(slot.configure(_make_identity(), initial_resource))
	watch_signals(slot)

	var observations: Dictionary = {}
	var on_replaced: Callable = func(
		previous_resource: Resource,
		current_resource: Resource,
		generation: int
	) -> void:
		observations["previous"] = previous_resource
		observations["current"] = current_resource
		observations["slot_resource"] = slot.get_resource()
		observations["generation"] = generation
	var connect_error: Error = slot.resource_replaced.connect(on_replaced) as Error
	assert_eq(connect_error, OK)

	assert_true(slot.replace(replacement))
	assert_eq(slot.get_resource(), replacement)
	assert_eq(slot.get_generation(), 2)
	assert_eq(
		_get_resource(observations, "previous"),
		initial_resource
	)
	assert_eq(
		_get_resource(observations, "current"),
		replacement
	)
	assert_eq(
		_get_resource(observations, "slot_resource"),
		replacement,
		"监听器应只观察到已提交的新状态。"
	)
	assert_eq(GFVariantData.get_option_int(observations, "generation"), 2)
	assert_signal_emitted_with_parameters(
		slot,
		"resource_replaced",
		[initial_resource, replacement, 2]
	)

	assert_false(slot.replace(replacement), "相同实例替换应为 no-op。")
	assert_false(slot.replace(null), "空替换应被拒绝。")
	assert_eq(slot.get_generation(), 2, "no-op 不得推进 generation。")
	assert_signal_emit_count(slot, "resource_replaced", 1)
	slot.resource_replaced.disconnect(on_replaced)


func test_release_is_terminal_and_drops_strong_resource_reference() -> void:
	var resource: Resource = Resource.new()
	var resource_ref: WeakRef = weakref(resource)
	var slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()
	assert_true(slot.configure(_make_identity(), resource))
	resource = null
	assert_not_null(_get_weak_object(resource_ref), "活动槽位应强持有当前资源。")

	assert_true(slot.release(), "首次释放应提交终态。")
	assert_true(slot.is_released())
	assert_false(slot.has_resource())
	assert_eq(slot.get_generation(), 2)
	assert_null(_get_weak_object(resource_ref), "释放后不应继续持有资源。")
	assert_false(slot.release(), "重复释放应幂等返回 false。")
	assert_false(slot.replace(Resource.new()), "释放后不得再次替换。")
	assert_eq(slot.get_generation(), 2, "终态操作不得推进 generation。")


func test_release_signal_reports_empty_slot_commit() -> void:
	var slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()
	assert_true(slot.configure(_make_identity()))
	watch_signals(slot)

	assert_true(slot.release(), "空槽位也应允许显式提交释放。")
	assert_signal_emitted_with_parameters(slot, "released", [null, 2])
	assert_signal_emit_count(slot, "released", 1)


func test_release_listener_observes_terminal_state_and_owner_disconnect() -> void:
	var lifecycle_owner: Node = Node.new()
	add_child(lifecycle_owner)
	var initial_resource: Resource = Resource.new()
	var slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()
	assert_true(slot.configure(_make_identity(), initial_resource, lifecycle_owner))
	var observations: Dictionary = {}
	var on_released: Callable = func(
		previous_resource: Resource,
		generation: int
	) -> void:
		observations["previous_resource"] = previous_resource
		observations["resource"] = slot.get_resource()
		observations["released"] = slot.is_released()
		observations["generation"] = generation
		observations["owner_connection_count"] = (
			lifecycle_owner.tree_exited.get_connections().size()
		)
	var connect_error: Error = slot.released.connect(on_released) as Error
	assert_eq(connect_error, OK)

	assert_true(slot.release())
	assert_eq(_get_resource(observations, "previous_resource"), initial_resource)
	assert_null(_get_resource(observations, "resource"))
	assert_true(GFVariantData.get_option_bool(observations, "released"))
	assert_eq(GFVariantData.get_option_int(observations, "generation"), 2)
	assert_eq(
		GFVariantData.get_option_int(observations, "owner_connection_count", -1),
		0,
		"released 监听器只能观察到 owner 监听已经解除的终态。"
	)

	slot.released.disconnect(on_released)
	lifecycle_owner.queue_free()
	await get_tree().process_frame


func test_node_owner_exit_releases_slot_without_retaining_slot() -> void:
	var lifecycle_owner: Node = Node.new()
	add_child(lifecycle_owner)
	var slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()
	assert_true(slot.configure(_make_identity(), Resource.new(), lifecycle_owner))
	watch_signals(slot)

	lifecycle_owner.queue_free()
	await get_tree().process_frame

	assert_true(slot.is_released(), "Node owner 退出树后应自动释放槽位。")
	assert_eq(slot.get_generation(), 2)
	assert_signal_emit_count(slot, "released", 1)

	var second_owner: Node = Node.new()
	add_child(second_owner)
	var unowned_slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()
	assert_true(unowned_slot.configure(_make_identity(), Resource.new(), second_owner))
	var slot_ref: WeakRef = weakref(unowned_slot)
	unowned_slot = null
	assert_null(_get_weak_object(slot_ref), "owner 监听不得反向强持有槽位。")
	assert_eq(
		second_owner.tree_exited.get_connections().size(),
		0,
		"槽位释放自身时应由 Godot 自动移除 owner 上的目标连接。"
	)
	second_owner.queue_free()
	await get_tree().process_frame


func test_node_owner_must_be_inside_tree_before_configuration() -> void:
	var lifecycle_owner: Node = Node.new()
	var slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()

	assert_false(
		slot.configure(_make_identity(), Resource.new(), lifecycle_owner),
		"树外 Node 不能提供有效的退出树生命周期边界。"
	)
	assert_false(slot.is_configured(), "失败配置不得提交部分 owner 状态。")
	assert_eq(slot.get_generation(), 0)

	add_child(lifecycle_owner)
	assert_true(
		slot.configure(_make_identity(), Resource.new(), lifecycle_owner),
		"同一槽位在 owner 进入树后应允许重试配置。"
	)
	lifecycle_owner.queue_free()
	await get_tree().process_frame
	assert_true(slot.is_released())


func test_ref_counted_owner_is_released_lazily_on_access() -> void:
	var lifecycle_owner: SlotOwner = SlotOwner.new()
	var owner_ref: WeakRef = weakref(lifecycle_owner)
	var slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()
	assert_true(slot.configure(_make_identity(), Resource.new(), lifecycle_owner))
	watch_signals(slot)

	lifecycle_owner = null
	assert_null(_get_weak_object(owner_ref), "槽位不得强持有普通 Object owner。")
	assert_true(slot.is_released(), "后续访问应检测弱 owner 已释放并提交终态。")
	assert_eq(slot.get_generation(), 2)
	assert_signal_emit_count(slot, "released", 1)

	var explicit_owner: SlotOwner = SlotOwner.new()
	var explicit_slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()
	assert_true(
		explicit_slot.configure(_make_identity(), Resource.new(), explicit_owner)
	)
	explicit_owner = null
	assert_true(
		explicit_slot.release(),
		"owner 已释放时，显式 release 仍应报告本次终态提交成功。"
	)
	assert_eq(explicit_slot.get_generation(), 2)


func test_signal_notification_rejects_reentrant_mutations() -> void:
	var slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()
	assert_true(slot.configure(_make_identity(), Resource.new()))
	var replacement: Resource = Resource.new()
	var observations: Dictionary = {}
	var on_replaced: Callable = func(
		_previous_resource: Resource,
		_current_resource: Resource,
		_generation: int
	) -> void:
		observations["replace_result"] = slot.replace(Resource.new())
		observations["release_result"] = slot.release()
		observations["resource"] = slot.get_resource()
		observations["generation"] = slot.get_generation()
	var connect_error: Error = slot.resource_replaced.connect(on_replaced) as Error
	assert_eq(connect_error, OK)

	assert_true(slot.replace(replacement))
	assert_false(
		GFVariantData.get_option_bool(observations, "replace_result", true),
		"通知期间不得嵌套替换。"
	)
	assert_false(
		GFVariantData.get_option_bool(observations, "release_result", true),
		"通知期间不得嵌套释放。"
	)
	assert_eq(
		_get_resource(observations, "resource"),
		replacement
	)
	assert_eq(GFVariantData.get_option_int(observations, "generation"), 2)
	assert_false(slot.is_released())
	slot.resource_replaced.disconnect(on_replaced)


func test_owner_exit_during_replace_notification_releases_after_event() -> void:
	var lifecycle_owner: Node = Node.new()
	add_child(lifecycle_owner)
	var slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()
	assert_true(
		slot.configure(_make_identity(), Resource.new(), lifecycle_owner)
	)
	watch_signals(slot)
	var on_replaced: Callable = func(
		_previous_resource: Resource,
		_current_resource: Resource,
		_generation: int
	) -> void:
		var parent: Node = lifecycle_owner.get_parent()
		if parent != null:
			parent.remove_child(lifecycle_owner)
	var connect_error: Error = slot.resource_replaced.connect(on_replaced) as Error
	assert_eq(connect_error, OK)

	assert_true(slot.replace(Resource.new()))
	assert_true(
		slot.is_released(),
		"通知期间 owner 离树应在替换事件结束后提交释放。"
	)
	assert_eq(slot.get_generation(), 3)
	assert_signal_emit_count(slot, "resource_replaced", 1)
	assert_signal_emit_count(slot, "released", 1)

	slot.resource_replaced.disconnect(on_replaced)
	lifecycle_owner.free()


func test_worker_thread_calls_fail_closed_without_mutating_slot() -> void:
	var initial_resource: Resource = Resource.new()
	var replacement: Resource = Resource.new()
	var identity: GFResourceIdentity = _make_identity()
	var active_slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()
	var unconfigured_slot: GF_ASSET_SLOT_SCRIPT = GF_ASSET_SLOT_SCRIPT.new()
	assert_true(active_slot.configure(identity, initial_resource))
	var worker: Thread = Thread.new()
	var start_error: Error = worker.start(func() -> Dictionary:
		return {
			"configure": unconfigured_slot.configure(identity, replacement),
			"configured": active_slot.is_configured(),
			"identity": active_slot.get_resource_identity(),
			"resource": active_slot.get_resource(),
			"type_hint": active_slot.get_type_hint(),
			"generation": active_slot.get_generation(),
			"has_resource": active_slot.has_resource(),
			"released": active_slot.is_released(),
			"accepts": active_slot.accepts_resource(replacement),
			"replace": active_slot.replace(replacement),
			"release": active_slot.release(),
		}
	) as Error
	assert_eq(start_error, OK)
	var raw_report: Variant = worker.wait_to_finish()
	var report: Dictionary = GFVariantData.as_dictionary(raw_report)

	assert_false(GFVariantData.get_option_bool(report, "configure", true))
	assert_false(GFVariantData.get_option_bool(report, "configured", true))
	assert_true(GFVariantData.get_option_value(report, "identity") == null)
	assert_true(GFVariantData.get_option_value(report, "resource") == null)
	assert_eq(GFVariantData.get_option_string(report, "type_hint"), "")
	assert_eq(GFVariantData.get_option_int(report, "generation"), -1)
	assert_false(GFVariantData.get_option_bool(report, "has_resource", true))
	assert_true(GFVariantData.get_option_bool(report, "released", false))
	assert_false(GFVariantData.get_option_bool(report, "accepts", true))
	assert_false(GFVariantData.get_option_bool(report, "replace", true))
	assert_false(GFVariantData.get_option_bool(report, "release", true))
	assert_false(unconfigured_slot.is_configured())
	assert_true(active_slot.is_configured())
	assert_eq(active_slot.get_resource(), initial_resource)
	assert_eq(active_slot.get_generation(), 1)
	assert_false(active_slot.is_released())


# --- 私有/辅助方法 ---

func _make_identity(type_hint: String = "") -> GFResourceIdentity:
	return GF_RESOURCE_IDENTITY_SCRIPT.from_path(
		"res://virtual/live_asset_slot.tres",
		&"test.live_asset_slot",
		type_hint,
		{ "check_exists": false }
	)


func _get_resource(data: Dictionary, key: String) -> Resource:
	var value: Variant = GFVariantData.get_option_value(data, key)
	if value is Resource:
		return value
	return null


func _get_script(value: Variant) -> Script:
	if value is Script:
		return value
	return null


func _get_weak_object(object_ref: WeakRef) -> Object:
	if object_ref == null:
		return null
	var value: Variant = object_ref.get_ref()
	if value is Object:
		return value
	return null


# --- 内部类 ---

class SlotOwner:
	extends RefCounted
