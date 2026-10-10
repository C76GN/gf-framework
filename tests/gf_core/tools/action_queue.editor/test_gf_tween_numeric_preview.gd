@tool

# 显式目录、租约与隔离样机的黑盒回归；使用真实 Node 生命周期，不运行来源方法。
extends GutTest


const _VIEWPORT_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/gf_tween_preview_viewport.gd")
const _PANEL_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/gf_tween_preview_panel.gd")
const _RECORDS_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_property_records.gd")


func test_closed_registration_descriptor_and_duplicate_id_are_atomic() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var adapter: RecordingAdapter = RecordingAdapter.new()
	var descriptor: Dictionary = _descriptor("closed")
	var handle: GFTweenPreviewRegistration = registry.register_adapter(registration_owner, descriptor, adapter)
	assert_true(handle != null and handle.is_active())
	assert_eq(adapter.created.size(), 0, "Registration never executes adapter hooks")
	assert_true(registry.register_adapter(registration_owner, descriptor, adapter) == null)
	var unknown: Dictionary = _descriptor("unknown")
	unknown["business"] = registration_owner
	assert_true(registry.register_adapter(registration_owner, unknown, adapter) == null)
	assert_eq(registry.get_descriptors().size(), 1)
	handle.release()
	handle.release()
	assert_false(handle.is_active())
	assert_eq(registry.get_descriptors(), [])


func test_description_and_search_snapshots_do_not_mutate_registration() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var descriptor: Dictionary = _descriptor("detached")
	var handle: GFTweenPreviewRegistration = registry.register_adapter(registration_owner, descriptor, RecordingAdapter.new())
	assert_true(handle != null)
	descriptor.clear()
	var descriptions: Array[Dictionary] = registry.get_descriptors()
	descriptions[0]["label"] = "Changed"
	var records: Array[Dictionary] = registry.get_property_records(&"detached", "PROG")
	assert_eq(records.size(), 1)
	records[0]["initial"] = 42.0
	var published_label: Variant = registry.get_descriptors()[0]["label"]
	assert_true(published_label is String)
	if published_label is String:
		var label: String = published_label
		assert_eq(label, "Progress specimen")
	var published_initial: Variant = registry.get_property_records(&"detached")[0]["initial"]
	assert_true(published_initial is float)
	if published_initial is float:
		var initial_value: float = published_initial
		assert_eq(initial_value, 0.0)
	assert_eq(registry.get_property_records(&"detached", "missing"), [])
	assert_eq(registry.get_property_records(&"detached", "x".repeat(129)), [])
	handle.release()


func test_owner_expiration_and_old_handle_cannot_revoke_new_registration() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var old_handle: GFTweenPreviewRegistration = registry.register_adapter(registration_owner, _descriptor("lease"), RecordingAdapter.new())
	var owner_ref: WeakRef = weakref(registration_owner)
	registration_owner = null
	assert_true(owner_ref.get_ref() == null, "Registry must not strongly retain owner")
	assert_false(old_handle.is_active())
	var next_owner: RefCounted = RefCounted.new()
	var new_handle: GFTweenPreviewRegistration = registry.register_adapter(next_owner, _descriptor("lease", 2), RecordingAdapter.new())
	assert_true(new_handle != null and new_handle.is_active())
	old_handle.release()
	assert_true(new_handle.is_active())
	new_handle.release()


func test_handle_destruction_releases_registration_and_directory_budget_is_finite() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var handle: GFTweenPreviewRegistration = registry.register_adapter(registration_owner, _descriptor("auto_release"), RecordingAdapter.new())
	assert_true(handle != null)
	handle = null
	assert_eq(registry.get_descriptors(), [])
	var handles: Array[GFTweenPreviewRegistration] = []
	for index: int in range(32):
		var accepted: GFTweenPreviewRegistration = registry.register_adapter(registration_owner, _descriptor("bounded_%d" % index), RecordingAdapter.new())
		assert_true(accepted != null)
		handles.append(accepted)
	assert_true(registry.register_adapter(registration_owner, _descriptor("overflow"), RecordingAdapter.new()) == null)
	assert_eq(registry.get_descriptors().size(), 32)
	for accepted: GFTweenPreviewRegistration in handles:
		accepted.release()


func test_numeric_preview_pause_seek_reset_and_source_preservation() -> void:
	var registration_owner: RefCounted = RefCounted.new()
	var adapter: RecordingAdapter = RecordingAdapter.new()
	var handle: GFTweenPreviewRegistration = GFTweenPreviewRegistry.get_shared().register_adapter(registration_owner, _descriptor("preview_flow"), adapter)
	var config: GFTweenActionConfig = _config()
	var step: GFTweenActionStep = config.steps[0]
	step.marker_id = &"must_not_execute"
	var viewport: GFTweenPreviewViewport = _viewport()
	assert_true(viewport.configure_adapter(config, &"preview_flow"))
	assert_eq(viewport.get_initial_values(), {"progress": 0.0})
	assert_true(viewport.play())
	viewport.advance(0.25)
	assert_eq(viewport.get_current_values(), {"progress": 0.25})
	viewport.pause()
	viewport.advance(0.5)
	assert_eq(viewport.get_current_values(), {"progress": 0.25})
	step.target_value = 10.0
	assert_true(viewport.seek(0.5))
	assert_eq(viewport.get_current_values(), {"progress": 0.5}, "Seek uses frozen values")
	assert_eq(viewport.get_state(), &"paused")
	assert_true(viewport.play_direction(true))
	viewport.advance(0.25)
	assert_eq(viewport.get_current_values(), {"progress": 0.25})
	viewport.stop()
	assert_eq(viewport.get_current_values(), {"progress": 0.25})
	viewport.reset_preview()
	assert_eq(viewport.get_current_values(), {"progress": 0.0})
	assert_false(viewport.has_session())
	assert_eq(config.steps[0], step)
	assert_true(step.target_value is float)
	if step.target_value is float:
		var target_value: float = step.target_value
		assert_eq(target_value, 10.0)
	assert_eq(step.marker_id, &"must_not_execute")
	assert_eq(config.duration_scale, 1.0)
	viewport.dispose_preview()
	viewport.dispose_preview()
	handle.release()


func test_numeric_finish_restore_and_endpoint_seek_have_distinct_semantics() -> void:
	var registration_owner: RefCounted = RefCounted.new()
	var handle: GFTweenPreviewRegistration = GFTweenPreviewRegistry.get_shared().register_adapter(registration_owner, _descriptor("finish"), RecordingAdapter.new())
	var config: GFTweenActionConfig = _config()
	config.restore_initial_values_on_finish = true
	var viewport: GFTweenPreviewViewport = _viewport()
	assert_true(viewport.configure_adapter(config, &"finish"))
	assert_true(viewport.play())
	assert_true(viewport.seek(1.0))
	assert_eq(viewport.get_current_values(), {"progress": 1.0})
	assert_eq(viewport.get_state(), &"paused")
	assert_true(viewport.play())
	assert_eq(viewport.get_state(), &"finished")
	assert_eq(viewport.get_current_values(), {"progress": 0.0})
	viewport.dispose_preview()
	handle.release()


func test_owner_and_revision_change_invalidate_old_session_and_release_sample() -> void:
	var registration_owner: RefCounted = RefCounted.new()
	var adapter: RecordingAdapter = RecordingAdapter.new()
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.get_shared()
	var handle: GFTweenPreviewRegistration = registry.register_adapter(registration_owner, _descriptor("revision"), adapter)
	var viewport: GFTweenPreviewViewport = _viewport()
	assert_true(viewport.configure_adapter(_config(), &"revision"))
	assert_true(viewport.play())
	var old_sample: WeakRef = adapter.created[0]
	handle.release()
	var next_handle: GFTweenPreviewRegistration = registry.register_adapter(registration_owner, _descriptor("revision", 2), adapter)
	viewport.advance(0.0)
	assert_eq(viewport.get_state(), &"error")
	assert_false(viewport.has_session())
	assert_eq(viewport.get_current_values(), {})
	await wait_process_frames(1)
	assert_true(old_sample.get_ref() == null)
	assert_true(viewport.configure_adapter(_config(), &"revision"))
	assert_true(viewport.play())
	registration_owner = null
	viewport.advance(0.0)
	assert_eq(viewport.get_state(), &"error")
	assert_false(next_handle.is_active())
	viewport.dispose_preview()
	next_handle.release()


func test_adapter_submission_rebinding_and_disposal_cannot_publish_old_success() -> void:
	var registration_owner: RefCounted = RefCounted.new()
	var adapter: RecordingAdapter = RecordingAdapter.new()
	var handle: GFTweenPreviewRegistration = GFTweenPreviewRegistry.get_shared().register_adapter(registration_owner, _descriptor("reentrant"), adapter)
	var viewport: GFTweenPreviewViewport = _viewport()
	assert_true(viewport.configure_adapter(_config(), &"reentrant"))
	adapter.callback = func() -> void: viewport.configure(_config(), 0)
	assert_false(viewport.play())
	assert_eq(viewport.get_state(), &"idle")
	assert_eq(viewport.get_initial_values(), GFTweenPreviewPlan.get_initial_values(0))
	assert_false(viewport.has_session())
	assert_true(viewport.configure_adapter(_config(), &"reentrant"))
	assert_true(viewport.play())
	adapter.callback = func() -> void: viewport.dispose_preview()
	assert_false(viewport.seek(0.5))
	assert_eq(viewport.get_current_values(), {})
	assert_eq(viewport.get_state(), &"idle")
	handle.release()


func test_adapter_returning_attached_sample_is_rejected_without_stealing_it() -> void:
	var registration_owner: RefCounted = RefCounted.new()
	var existing: Control = Control.new()
	add_child_autofree(existing)
	var adapter: AttachedAdapter = AttachedAdapter.new()
	adapter.existing = existing
	var handle: GFTweenPreviewRegistration = GFTweenPreviewRegistry.get_shared().register_adapter(registration_owner, _descriptor("attached"), adapter)
	var viewport: GFTweenPreviewViewport = _viewport()
	assert_false(viewport.configure_adapter(_config(), &"attached"))
	assert_eq(existing.get_parent(), self)
	assert_false(existing.is_queued_for_deletion())
	viewport.dispose_preview()
	handle.release()


func test_sample_node_and_depth_budgets_accept_boundaries_and_release_rejected_trees() -> void:
	var registration_owner: RefCounted = RefCounted.new()
	var adapter: BudgetAdapter = BudgetAdapter.new()
	var handle: GFTweenPreviewRegistration = GFTweenPreviewRegistry.get_shared().register_adapter(registration_owner, _descriptor("sample_budget"), adapter)
	var viewport: GFTweenPreviewViewport = _viewport()
	for count: int in [128, 129]:
		adapter.node_count = count
		adapter.depth = 1
		assert_eq(viewport.configure_adapter(_config(), &"sample_budget"), count == 128)
		viewport.dispose_preview()
		await wait_process_frames(2)
		assert_true(adapter.created.get_ref() == null, "Accepted and rejected samples must both be released")
	for depth: int in [8, 9]:
		adapter.node_count = 1
		adapter.depth = depth
		assert_eq(viewport.configure_adapter(_config(), &"sample_budget"), depth == 8)
		viewport.dispose_preview()
		await wait_process_frames(2)
		assert_true(adapter.created.get_ref() == null, "Depth rejection must release its unparented tree")
	handle.release()


func test_custom_whole_group_rejection_and_local_initial_bounds() -> void:
	var registration_owner: RefCounted = RefCounted.new()
	var handle: GFTweenPreviewRegistration = GFTweenPreviewRegistry.get_shared().register_adapter(registration_owner, _descriptor("reject_group"), RecordingAdapter.new())
	var config: GFTweenActionConfig = _config()
	var _bad: GFTweenActionStep = config.add_property_step(^"source:value", 0.5, 1.0)
	var viewport: GFTweenPreviewViewport = _viewport()
	assert_true(viewport.configure_adapter(config, &"reject_group"))
	assert_false(viewport.play())
	assert_false(viewport.has_session())
	assert_eq(viewport.get_current_values(), {"progress": 0.0})
	assert_false(viewport.set_initial_value(&"progress", 200.0))
	assert_false(viewport.set_initial_value(&"progress", 1))
	assert_eq(viewport.get_initial_values(), {"progress": 0.0})
	assert_true(viewport.set_initial_value(&"progress", 0.25))
	assert_eq(viewport.get_current_values(), {"progress": 0.25})
	viewport.dispose_preview()
	handle.release()


func test_native_property_search_reuses_preview_whitelist_without_source_scan() -> void:
	for kind: int in range(3):
		var records: Array[Dictionary] = _RECORDS_SCRIPT.get_native_records(kind)
		assert_true(records.size() < 64)
		assert_eq(_RECORDS_SCRIPT.search(records, ""), records, "Empty query lists the complete finite catalog")
		var match_records: Array[Dictionary] = _RECORDS_SCRIPT.search(records, "POSITION")
		assert_false(match_records.is_empty())
		for record: Dictionary in match_records:
			var property_name: String = record["name"]
			assert_true(GFTweenPreviewPlan.get_properties(kind).has(property_name.get_slice(":", 0)))
		assert_eq(_RECORDS_SCRIPT.search(records, "unlisted"), [])
		assert_eq(_RECORDS_SCRIPT.search(records, "x".repeat(129)), [])


func test_panel_explicit_adapter_selection_and_registry_unload_clear_old_session() -> void:
	var registration_owner: RefCounted = RefCounted.new()
	var handle: GFTweenPreviewRegistration = GFTweenPreviewRegistry.get_shared().register_adapter(registration_owner, _descriptor("panel_choice"), RecordingAdapter.new())
	var panel: GFTweenPreviewPanel = _PANEL_SCRIPT.new()
	panel.configure(_config())
	add_child_autofree(panel)
	var picker: OptionButton = panel.find_child("TargetKind", true, false)
	assert_eq(picker.selected, 0, "Project registration does not steal native selection")
	picker.select(3)
	picker.item_selected.emit(3)
	var viewport: GFTweenPreviewViewport = panel.find_child("PreviewViewport", true, false)
	assert_true(viewport.play())
	handle.release()
	await wait_process_frames(2)
	assert_false(viewport.has_session())
	assert_eq(viewport.get_state(), &"error")
	panel.dispose_preview()


func _descriptor(id: String, revision: int = 1) -> Dictionary:
	return {"id": id, "revision": revision, "label": "Progress specimen", "properties": [{"name": "progress", "type": TYPE_FLOAT, "initial": 0.0, "minimum": -100.0, "maximum": 100.0}]}


func _config() -> GFTweenActionConfig:
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var step: GFTweenActionStep = config.add_property_step(^"progress", 1.0, 1.0)
	step.transition_type = Tween.TRANS_LINEAR
	return config


func _viewport() -> GFTweenPreviewViewport:
	var viewport: GFTweenPreviewViewport = _VIEWPORT_SCRIPT.new()
	add_child_autofree(viewport)
	return viewport


class RecordingAdapter extends GFTweenPreviewAdapter:
	var created: Array[WeakRef] = []
	var submitted: Array[Dictionary] = []
	var callback: Callable = Callable()

	func _create_sample() -> Control:
		var sample: ColorRect = ColorRect.new()
		sample.size = Vector2(32.0, 32.0)
		created.append(weakref(sample))
		return sample

	func _apply_sample(sample: Control, values: Dictionary) -> void:
		submitted.append(values.duplicate())
		sample.position.x = GFVariantData.get_option_float(values, "progress") * 100.0
		var next_callback: Callable = callback
		callback = Callable()
		if next_callback.is_valid():
			next_callback.call()


class AttachedAdapter extends GFTweenPreviewAdapter:
	var existing: Control = null

	func _create_sample() -> Control:
		return existing


class BudgetAdapter extends GFTweenPreviewAdapter:
	var node_count: int = 1
	var depth: int = 1
	var created: WeakRef = null

	func _create_sample() -> Control:
		var sample: Control = Control.new()
		created = weakref(sample)
		var parent: Control = sample
		for _index: int in range(1, depth):
			var child: Control = Control.new()
			parent.add_child(child)
			parent = child
		for _index: int in range(1, node_count):
			var child: Control = Control.new()
			sample.add_child(child)
		return sample
