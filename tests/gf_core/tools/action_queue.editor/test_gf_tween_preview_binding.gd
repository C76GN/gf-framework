@tool

# 编辑器资源关联的公共能力回归；关联不执行样机或加载业务场景。
extends GutTest


func test_binding_is_editor_only_copied_and_does_not_execute_samples() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var adapter: CountingAdapter = CountingAdapter.new()
	var sample: GFTweenPreviewRegistration = registry.register_adapter(
		registration_owner,
		_descriptor("button"),
		adapter
	)
	var initial_values: Dictionary = { "feedback_scale": 0.985 }
	var binding: GFTweenPreviewRegistration = registry.register_binding(
		registration_owner,
		"res://motions/release.tres",
		&"button",
		initial_values,
		"Release"
	)
	assert_true(binding != null and binding.is_active())
	initial_values["feedback_scale"] = 1.2
	var declaration: Dictionary = registry.get_binding("res://motions/release.tres")
	var declared_initials: Dictionary = declaration["initial_values"]
	var declared_label: String = declaration["label"]
	assert_eq(
		declared_initials,
		{ "feedback_scale": 0.985 }
	)
	assert_eq(declared_label, "Release")
	declaration.clear()
	assert_false(registry.get_binding("res://motions/release.tres").is_empty())
	assert_eq(adapter.created, 0)
	binding.release()
	sample.release()


func test_binding_rejects_duplicate_paths_traversal_and_impure_initials() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var handle: GFTweenPreviewRegistration = registry.register_binding(
		registration_owner,
		"res://motions/a.tres",
		&"gf.preview.ui"
	)
	assert_true(handle != null)
	assert_null(
		registry.register_binding(
			registration_owner,
			"res://motions/a.tres",
			&"gf.preview.2d"
		)
	)
	for path: String in [
		"user://a.tres",
		"res://motions/../a.tres",
		"res://motions//a.tres",
		"res://",
		"res://./a.tres",
	]:
		assert_null(
			registry.register_binding(
				registration_owner,
				path,
				&"gf.preview.ui"
			)
		)
	assert_null(
		registry.register_binding(
			registration_owner,
			"res://impure.tres",
			&"gf.preview.ui",
			{ "size": registration_owner }
		)
	)
	assert_null(
		registry.register_binding(
			registration_owner,
			"res://nan.tres",
			&"gf.preview.ui",
			{ "size": Vector2(NAN, 1.0) }
		)
	)
	assert_null(
		registry.register_binding(
			registration_owner,
			"res://component.tres",
			&"gf.preview.ui",
			{ "size:x": 1.0 }
		)
	)
	assert_null(
		registry.register_binding(
			registration_owner,
			"res://bad_id.tres",
			&"unknown.target"
		)
	)
	handle.release()


func test_binding_owner_is_weak_and_old_handle_cannot_revoke_replacement() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var old: GFTweenPreviewRegistration = registry.register_binding(
		registration_owner,
		"res://motion.tres",
		&"gf.preview.ui"
	)
	var owner_ref: WeakRef = weakref(registration_owner)
	registration_owner = null
	assert_true(owner_ref.get_ref() == null)
	assert_false(old.is_active())
	var next_owner: RefCounted = RefCounted.new()
	var next: GFTweenPreviewRegistration = registry.register_binding(
		next_owner,
		"res://motion.tres",
		&"gf.preview.2d"
	)
	old.release()
	assert_true(next.is_active())
	next.release()
	next.release()
	assert_eq(
		registry.get_binding("res://motion.tres"),
		{}
	)


func test_binding_budget_and_handle_destruction_are_bounded() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var handles: Array[GFTweenPreviewRegistration] = []
	for index: int in range(256):
		var handle: GFTweenPreviewRegistration = registry.register_binding(
			registration_owner,
			"res://motion_%d.tres" % index,
			&"gf.preview.ui"
		)
		assert_not_null(handle)
		handles.append(handle)
	assert_null(
		registry.register_binding(
			registration_owner,
			"res://overflow.tres",
			&"gf.preview.ui"
		)
	)
	handles.clear()
	assert_eq(
		registry.get_binding("res://motion_0.tres"),
		{}
	)
	var next: GFTweenPreviewRegistration = registry.register_binding(
		registration_owner,
		"res://replacement.tres",
		&"gf.preview.ui"
	)
	assert_not_null(next)
	next.release()


func test_unique_candidate_and_ambiguity_are_resolved_before_playback() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var context: GFTweenPreviewContext = GFTweenPreviewContext.new()
	var ui: GFTweenActionConfig = _config(
		"size",
		Vector2(128.0, 96.0)
	)
	context.configure(ui, registry)
	assert_eq(
		_target_id(context),
		&"gf.preview.ui"
	)
	assert_true(_supported(context))
	var ambiguous: GFTweenActionConfig = _config("position:x", 10.0)
	context.configure(ambiguous, registry)
	assert_eq(
		_target_id(context),
		&""
	)
	assert_false(_supported(context))
	var reason: String = context.get_target()["reason"]
	assert_true(reason.contains("多个"))
	assert_true(context.select_target(&"gf.preview.3d"))
	var reopened: GFTweenPreviewContext = GFTweenPreviewContext.new()
	reopened.configure(ambiguous, registry)
	assert_eq(
		_target_id(reopened),
		&"gf.preview.3d"
	)


func test_explicit_binding_disambiguates_and_overrides_initial_state() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var adapter: CountingAdapter = CountingAdapter.new()
	var sample: GFTweenPreviewRegistration = registry.register_adapter(
		registration_owner,
		_descriptor("button"),
		adapter
	)
	var config: GFTweenActionConfig = _config("feedback_scale", 1.0)
	config.resource_path = "res://motion_release.tres"
	var binding: GFTweenPreviewRegistration = registry.register_binding(
		registration_owner,
		config.resource_path,
		&"button",
		{ "feedback_scale": 0.985 },
		"Release"
	)
	var context: GFTweenPreviewContext = GFTweenPreviewContext.new()
	context.configure(config, registry)
	assert_eq(
		_target_id(context),
		&"button"
	)
	assert_eq(
		_target_label(context),
		"Release"
	)
	assert_eq(
		_initial_values(context),
		{ "feedback_scale": 0.985 }
	)
	assert_eq(
		_record_initial(context),
		0.985
	)
	assert_eq(
		adapter.created,
		0,
		"Compatibility checking never invokes factories"
	)
	assert_true(context.set_initial_value(&"feedback_scale", 0.8))
	assert_eq(
		_target_label(context),
		"Release"
	)
	assert_eq(
		_record_initial(context),
		0.8
	)
	assert_false(context.set_initial_value(&"feedback_scale", 2.0))
	assert_eq(
		_record_initial(context),
		0.8
	)
	assert_false(config.has_meta(&"preview"))
	assert_eq(
		_step_target(config),
		1.0
	)
	binding.release()
	sample.release()


func test_missing_or_incompatible_binding_never_silently_chooses_another_sample() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var config: GFTweenActionConfig = _config("size", Vector2.ONE)
	config.resource_path = "res://missing_preview.tres"
	var binding: GFTweenPreviewRegistration = registry.register_binding(
		registration_owner,
		config.resource_path,
		&"missing"
	)
	var context: GFTweenPreviewContext = GFTweenPreviewContext.new()
	context.configure(config, registry)
	assert_eq(
		_target_id(context),
		&"missing"
	)
	assert_false(
		_supported(context),
		"The compatible native UI target cannot replace declared intent"
	)
	var binding_lease: int = context.get_target()["binding_lease"]
	assert_gt(binding_lease, 0)
	binding.release()
	context.refresh()
	assert_eq(
		_target_id(context),
		&"gf.preview.ui"
	)
	var incompatible: GFTweenPreviewRegistration = registry.register_binding(
		registration_owner,
		config.resource_path,
		&"gf.preview.2d"
	)
	context.refresh()
	assert_eq(
		_target_id(context),
		&"gf.preview.2d"
	)
	assert_false(_supported(context))
	incompatible.release()


func test_late_adapter_and_replacement_are_resolved_without_executing_hooks() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var config: GFTweenActionConfig = _config("feedback_scale", 1.0)
	config.resource_path = "res://late.tres"
	var binding: GFTweenPreviewRegistration = registry.register_binding(
		registration_owner,
		config.resource_path,
		&"button"
	)
	var context: GFTweenPreviewContext = GFTweenPreviewContext.new()
	context.configure(config, registry)
	assert_false(_supported(context))
	var adapter: CountingAdapter = CountingAdapter.new()
	var sample: GFTweenPreviewRegistration = registry.register_adapter(
		registration_owner,
		_descriptor("button"),
		adapter
	)
	context.refresh()
	assert_true(_supported(context))
	var old_lease: int = context.get_target()["lease"]
	sample.release()
	context.refresh()
	assert_false(_supported(context))
	var replacement: GFTweenPreviewRegistration = registry.register_adapter(
		registration_owner,
		_descriptor("button"),
		adapter
	)
	context.refresh()
	assert_true(_supported(context))
	var new_lease: int = context.get_target()["lease"]
	assert_ne(new_lease, old_lease)
	assert_eq(adapter.created, 0)
	replacement.release()
	binding.release()


func test_bad_declared_initials_are_rejected_without_fallback_or_config_writes() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var sample: GFTweenPreviewRegistration = registry.register_adapter(
		registration_owner,
		_descriptor("button"),
		CountingAdapter.new()
	)
	var config: GFTweenActionConfig = _config("feedback_scale", 1.0)
	config.resource_path = "res://bad_initial.tres"
	var binding: GFTweenPreviewRegistration = registry.register_binding(
		registration_owner,
		config.resource_path,
		&"button",
		{ "feedback_scale": 2.0 }
	)
	var context: GFTweenPreviewContext = GFTweenPreviewContext.new()
	context.configure(config, registry)
	assert_false(_supported(context))
	assert_eq(
		_target_id(context),
		&"button"
	)
	assert_eq(
		_step_target(config),
		1.0
	)
	binding.release()
	sample.release()


func test_same_descriptor_replacement_refreshes_the_lease_without_an_intermediate_refresh() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var old_adapter: CountingAdapter = CountingAdapter.new()
	var old: GFTweenPreviewRegistration = registry.register_adapter(
		registration_owner,
		_descriptor("button"),
		old_adapter
	)
	var config: GFTweenActionConfig = _config("feedback_scale", 1.0)
	var context: GFTweenPreviewContext = GFTweenPreviewContext.new()
	context.configure(config, registry)
	var old_lease: int = context.get_target()["lease"]
	assert_eq(
		old_adapter.created,
		0,
		"Resolution does not execute the factory"
	)
	var panel: GFTweenPreviewPanel = GFTweenPreviewPanel.new()
	panel.configure(config, context)
	add_child_autofree(panel)
	panel.set_process(false)
	assert_eq(old_adapter.created, 1)
	var old_sample: WeakRef = old_adapter.samples[0]
	old.release()
	var replacement_adapter: CountingAdapter = CountingAdapter.new()
	var replacement: GFTweenPreviewRegistration = registry.register_adapter(
		registration_owner,
		_descriptor("button"),
		replacement_adapter
	)
	context.refresh()
	var replacement_lease: int = context.get_target()["lease"]
	assert_true(_supported(context))
	assert_gt(
		replacement_lease,
		old_lease,
		"Identical descriptions do not preserve a retired owner's lease"
	)
	assert_true(context.is_target_current())
	assert_eq(old_adapter.created, 1)
	assert_eq(
		replacement_adapter.created,
		1,
		"The panel prepares exactly one replacement sample"
	)
	await get_tree().process_frame
	assert_true(
		old_sample.get_ref() == null,
		"The retired sample is physically released"
	)
	panel.dispose_preview()
	replacement.release()


func test_initial_value_correction_can_repair_a_relative_plan_envelope() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var sample: GFTweenPreviewRegistration = registry.register_adapter(
		registration_owner,
		_descriptor("button"),
		CountingAdapter.new()
	)
	var config: GFTweenActionConfig = _config("feedback_scale", 0.8)
	config.steps[0].as_relative = true
	config.resource_path = "res://initial_repair.tres"
	var binding: GFTweenPreviewRegistration = registry.register_binding(
		registration_owner,
		config.resource_path,
		&"button"
	)
	var context: GFTweenPreviewContext = GFTweenPreviewContext.new()
	context.configure(config, registry)
	assert_false(
		_supported(context),
		"The initial 1.0 plus relative 0.8 exceeds the declared maximum 1.5"
	)
	assert_true(
		context.set_initial_value(&"feedback_scale", 0.5),
		"A valid correction must reach full candidate validation"
	)
	assert_true(_supported(context))
	assert_eq(
		_initial_values(context),
		{ "feedback_scale": 0.5 }
	)
	assert_eq(
		_step_target(config),
		0.8,
		"Correcting the sample initial does not edit runtime configuration"
	)
	binding.release()
	sample.release()


func test_only_edited_initial_keys_override_a_replacement_resource_binding() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var adapter: CountingAdapter = CountingAdapter.new()
	var sample: GFTweenPreviewRegistration = registry.register_adapter(
		registration_owner,
		_two_property_descriptor("button"),
		adapter
	)
	var config: GFTweenActionConfig = _config("feedback_scale", 1.0)
	config.resource_path = "res://initial_binding_replacement.tres"
	var binding: GFTweenPreviewRegistration = registry.register_binding(
		registration_owner,
		config.resource_path,
		&"button",
		{ "feedback_scale": 0.985, "opacity": 0.4 }
	)
	var context: GFTweenPreviewContext = GFTweenPreviewContext.new()
	context.configure(config, registry)
	assert_true(_supported(context))
	assert_eq(
		_initial_values(context),
		{ "feedback_scale": 0.985, "opacity": 0.4 }
	)
	var old_lease: int = context.get_target()["binding_lease"]
	assert_true(context.set_initial_value(&"feedback_scale", 0.8))
	assert_eq(
		_initial_values(context),
		{ "feedback_scale": 0.8, "opacity": 0.4 }
	)
	binding.release()
	var replacement: GFTweenPreviewRegistration = registry.register_binding(
		registration_owner,
		config.resource_path,
		&"button",
		{ "feedback_scale": 1.1, "opacity": 0.7 }
	)
	context.refresh()
	var new_lease: int = context.get_target()["binding_lease"]
	assert_gt(
		new_lease,
		old_lease,
		"The new declaration has a distinct binding lease"
	)
	assert_true(_supported(context))
	assert_eq(
		_initial_values(context),
		{ "feedback_scale": 0.8, "opacity": 0.7 },
		"Only the author-edited key overrides the new declaration"
	)
	var reopened: GFTweenPreviewContext = GFTweenPreviewContext.new()
	reopened.configure(config, registry)
	assert_eq(
		_initial_values(reopened),
		{ "feedback_scale": 0.8, "opacity": 0.7 },
		"Inspector reconstruction restores edited keys, not old effective defaults"
	)
	assert_eq(
		_step_target(config),
		1.0,
		"Preview initial edits do not change the runtime step"
	)
	assert_eq(
		adapter.created,
		0,
		"Resolution and lease replacement do not invoke sample factories"
	)
	replacement.release()
	sample.release()


func test_only_explicit_initial_keys_override_a_replacement_adapter_descriptor() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var adapter: CountingAdapter = CountingAdapter.new()
	var sample: GFTweenPreviewRegistration = registry.register_adapter(
		registration_owner,
		_two_property_descriptor("button"),
		adapter
	)
	var config: GFTweenActionConfig = _config("feedback_scale", 1.0)
	var context: GFTweenPreviewContext = GFTweenPreviewContext.new()
	context.configure(config, registry)
	assert_eq(
		_target_id(context),
		&"button"
	)
	assert_true(_supported(context))
	var old_lease: int = context.get_target()["lease"]
	# An explicitly supplied value remains intentional even when it equals the old default.
	assert_true(context.set_initial_value(&"feedback_scale", 1.0))
	sample.release()
	var replacement: GFTweenPreviewRegistration = registry.register_adapter(
		registration_owner,
		_two_property_descriptor(
			"button",
			2,
			1.2,
			0.6
		),
		adapter
	)
	context.refresh()
	var new_lease: int = context.get_target()["lease"]
	assert_gt(
		new_lease,
		old_lease,
		"The descriptor replacement has a distinct adapter lease"
	)
	assert_true(_supported(context))
	assert_eq(
		_initial_values(context),
		{ "feedback_scale": 1.0, "opacity": 0.6 },
		"Untouched descriptor defaults follow the new registration"
	)
	var reopened: GFTweenPreviewContext = GFTweenPreviewContext.new()
	reopened.configure(config, registry)
	assert_eq(
		_initial_values(reopened),
		{ "feedback_scale": 1.0, "opacity": 0.6 },
		"The selection cache stores only explicit author overrides"
	)
	assert_eq(
		_step_target(config),
		1.0
	)
	assert_eq(adapter.created, 0)
	replacement.release()


func test_initial_value_correction_cannot_erase_an_unknown_declared_property() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	var sample: GFTweenPreviewRegistration = registry.register_adapter(
		registration_owner,
		_descriptor("button"),
		CountingAdapter.new()
	)
	var config: GFTweenActionConfig = _config("feedback_scale", 1.0)
	config.resource_path = "res://invalid_declaration.tres"
	var binding: GFTweenPreviewRegistration = registry.register_binding(
		registration_owner,
		config.resource_path,
		&"button",
		{ "unknown_property": 0.0 }
	)
	var context: GFTweenPreviewContext = GFTweenPreviewContext.new()
	context.configure(config, registry)
	assert_false(_supported(context))
	assert_false(
		context.set_initial_value(&"feedback_scale", 0.5),
		"Another root override cannot silently discard an invalid declaration"
	)
	assert_false(_supported(context))
	binding.release()
	sample.release()


func test_controlled_degree_bindings_use_the_same_frozen_rotation_initials_as_the_property_directory() -> void:
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var registration_owner: RefCounted = RefCounted.new()
	for kind: int in [0, 2]:
		var property_name: String = "rotation_degrees" if kind == 0 else "rotation_degrees:y"
		var target_id: StringName = &"gf.preview.2d" if kind == 0 else &"gf.preview.3d"
		var initial_rotation: Variant = deg_to_rad(30.0)
		if kind == 2:
			initial_rotation = Vector3(
				10.0,
				20.0,
				30.0
			) * (PI / 180.0)
		var config: GFTweenActionConfig = _config(property_name, 90.0)
		config.enable_playback_control = true
		config.resource_path = "res://degree_binding_%d.tres" % kind
		var binding: GFTweenPreviewRegistration = registry.register_binding(
			registration_owner,
			config.resource_path,
			target_id,
			{ "rotation": initial_rotation }
		)
		var context: GFTweenPreviewContext = GFTweenPreviewContext.new()
		context.configure(config, registry)
		assert_true(_supported(context))
		var records: Array[Dictionary] = context.get_property_records(property_name)
		assert_false(records.is_empty())
		var displayed_initial: Variant = records[0]["initial"]
		assert_true(displayed_initial is float)
		if displayed_initial is float:
			var initial_degrees: float = displayed_initial
			assert_almost_eq(
				initial_degrees,
				30.0 if kind == 0 else 20.0,
				0.00001
			)
		binding.release()


func _target_id(context: GFTweenPreviewContext) -> StringName:
	var identifier: StringName = context.get_target()["id"]
	return identifier


func _target_label(context: GFTweenPreviewContext) -> String:
	var label: String = context.get_target()["label"]
	return label


func _supported(context: GFTweenPreviewContext) -> bool:
	var supported: bool = context.get_target()["supported"]
	return supported


func _initial_values(context: GFTweenPreviewContext) -> Dictionary:
	var initial_values: Dictionary = context.get_target()["initial_values"]
	return initial_values


func _record_initial(context: GFTweenPreviewContext) -> float:
	var initial: float = context.get_property_records()[0]["initial"]
	return initial


func _step_target(config: GFTweenActionConfig) -> float:
	var value: float = config.steps[0].target_value
	return value


func _descriptor(identifier: String) -> Dictionary:
	return {
		"id": identifier,
		"revision": 1,
		"label": "Button",
		"properties": [
			{
				"name": "feedback_scale",
				"type": TYPE_FLOAT,
				"initial": 1.0,
				"minimum": 0.5,
				"maximum": 1.5,
			},
		],
	}


func _two_property_descriptor(
	identifier: String,
	revision: int = 1,
	feedback_initial: float = 1.0,
	opacity_initial: float = 0.25
) -> Dictionary:
	return {
		"id": identifier,
		"revision": revision,
		"label": "Button",
		"properties": [
			{
				"name": "feedback_scale",
				"type": TYPE_FLOAT,
				"initial": feedback_initial,
				"minimum": 0.5,
				"maximum": 1.5,
			},
			{
				"name": "opacity",
				"type": TYPE_FLOAT,
				"initial": opacity_initial,
				"minimum": 0.0,
				"maximum": 1.0,
			},
		],
	}


func _config(property_name: String, target: Variant) -> GFTweenActionConfig:
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	var step: GFTweenActionStep = GFTweenActionStep.new()
	step.property_name = NodePath(property_name)
	step.target_value = target
	step.duration = 1.0
	step.transition_type = Tween.TRANS_LINEAR
	config.steps = [step]
	return config


class CountingAdapter extends GFTweenPreviewAdapter:
	var created: int = 0
	var samples: Array[WeakRef] = []

	func _create_sample() -> Control:
		created += 1
		var sample: Control = Control.new()
		samples.append(weakref(sample))
		return sample
