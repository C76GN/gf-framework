@tool

# 创建时的明确用途必须跨 Inspector 重建保留，不能改变未声明资源的歧义保护。
extends GutTest


const _CREATOR_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/gf_tween_editor_actions.gd")
const _PRESETS_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/presets/gf_tween_authoring_presets.gd")


func test_created_resources_keep_the_explicit_kind_without_runtime_metadata() -> void:
	var creator: RefCounted = _CREATOR_SCRIPT.new()
	if not _has_creation_handoff(creator):
		return
	var ids: Array[StringName] = [&"gf.preview.2d", &"gf.preview.ui", &"gf.preview.3d"]
	for kind: int in range(3):
		var config: GFTweenActionConfig = GFTweenActionConfig.new()
		config.steps = _PRESETS_SCRIPT.create_steps("move_by", kind)
		var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
		var before: Dictionary = GFTweenPreviewPlan.capture(config, kind).steps[0].duplicate(true)
		var remembered: Variant = creator.call("remember_created_preview", config, kind, registry)
		var creation_remembered: bool = remembered is bool and remembered == true
		assert_true(creation_remembered)
		var context: GFTweenPreviewContext = GFTweenPreviewContext.new()
		context.configure(config, registry)
		var target: Dictionary = context.get_target()
		var selected_kind_matches: bool = target.get("id") is StringName and target.get("id") == ids[kind]
		assert_true(selected_kind_matches)
		assert_true(_supported(target))
		assert_eq(GFTweenPreviewPlan.capture(config, kind).steps[0], before)
		assert_eq(config.get_meta_list().size(), 0)
		var reopened: GFTweenPreviewContext = GFTweenPreviewContext.new()
		reopened.configure(config, registry)
		var reopened_kind_matches: bool = reopened.get_target().get("id") is StringName and reopened.get_target().get("id") == ids[kind]
		assert_true(reopened_kind_matches)


func test_creation_handoff_does_not_guess_for_an_unrelated_resource() -> void:
	var creator: RefCounted = _CREATOR_SCRIPT.new()
	if not _has_creation_handoff(creator):
		return
	var created: GFTweenActionConfig = GFTweenActionConfig.new()
	created.steps = _PRESETS_SCRIPT.create_steps("move_by", 1)
	var unrelated: GFTweenActionConfig = created.duplicate_config()
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var remembered: Variant = creator.call("remember_created_preview", created, 1, registry)
	var creation_remembered: bool = remembered is bool and remembered == true
	assert_true(creation_remembered)
	var context: GFTweenPreviewContext = GFTweenPreviewContext.new()
	context.configure(unrelated, registry)
	var unrelated_kind_not_selected: bool = context.get_target().get("id") is StringName and context.get_target().get("id") == &""
	assert_true(unrelated_kind_not_selected)
	assert_false(_supported(context.get_target()))
	var reason_value: Variant = context.get_target().get("reason")
	assert_true(reason_value is String)
	if reason_value is String:
		var reason: String = reason_value
		assert_true(reason.contains("多个兼容"))


func test_invalid_creation_kind_does_not_change_a_previous_editor_selection() -> void:
	var creator: RefCounted = _CREATOR_SCRIPT.new()
	if not _has_creation_handoff(creator):
		return
	var config: GFTweenActionConfig = GFTweenActionConfig.new()
	config.steps = _PRESETS_SCRIPT.create_steps("move_by", 1)
	var registry: GFTweenPreviewRegistry = GFTweenPreviewRegistry.new()
	var remembered: Variant = creator.call("remember_created_preview", config, 1, registry)
	var creation_remembered: bool = remembered is bool and remembered == true
	assert_true(creation_remembered)
	for invalid_kind: int in [-1, 3, 50]:
		var rejected: Variant = creator.call("remember_created_preview", config, invalid_kind, registry)
		var invalid_kind_rejected: bool = rejected is bool and rejected == false
		assert_true(invalid_kind_rejected)
	var context: GFTweenPreviewContext = GFTweenPreviewContext.new()
	context.configure(config, registry)
	var prior_kind_preserved: bool = context.get_target().get("id") is StringName and context.get_target().get("id") == &"gf.preview.ui"
	assert_true(prior_kind_preserved)


func _has_creation_handoff(creator: RefCounted) -> bool:
	var available: bool = creator.has_method("remember_created_preview")
	assert_true(available, "Creating a Tween must hand its explicit preview purpose to the editor session.")
	return available


func _supported(target: Dictionary) -> bool:
	var value: Variant = target.get("supported")
	return value is bool and value == true
