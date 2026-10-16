## 以固定项目策略验证快照、检查点与迁移三层边界，不向框架添加项目业务规则。
extends GutTest

const RECIPE_SCRIPT = preload("res://tests/gf_core/extensions/dialogue/fixtures/project_checkpoint_recipe.gd")


func test_exact_snapshot_restores_same_content_but_never_accepts_new_revision() -> void:
	var original: GFDialogueResource = _resource("chapter-1@1", &"reward_claimed")
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var context: GFDialogueContext = GFDialogueContext.new(
		null,
		{ "coins": 5, "reward_claimed": true }
	)
	var first: GFDialogueLine = runner.start(
		original,
		&"reward_claimed",
		context
	)
	var snapshot: Dictionary = runner.create_runtime_snapshot()
	assert_false(snapshot.is_empty())
	var restored: GFDialogueRunner = GFDialogueRunner.new()
	assert_same(
		restored.restore_runtime_snapshot(original, snapshot),
		first
	)
	var changed: GFDialogueResource = _resource("chapter-1@2", &"chapter_1_after_reward")
	assert_null(
		runner.restore_runtime_snapshot(
			changed,
			snapshot,
			context
		)
	)
	assert_same(
		runner.get_current_line(),
		first,
		"指纹不匹配必须保留原会话；不尝试猜测新行。"
	)
	assert_eq(
		context.values,
		{ "coins": 5, "reward_claimed": true }
	)


func test_explicit_migration_opens_checkpoint_without_replaying_preceding_mutation() -> void:
	var saved: Dictionary = _legacy_save()
	var saved_copy: Dictionary = saved.duplicate(true)
	var resource: GFDialogueResource = _resource("chapter-1@2", &"chapter_1_after_reward")
	var result: Dictionary = RECIPE_SCRIPT.prepare_checkpoint(resource, saved)
	assert_true(GFVariantData.get_option_bool(result, "success"))
	assert_eq(
		saved,
		saved_copy,
		"迁移不得原地改写输入存档。"
	)
	var runner_value: Variant = result.get("runner")
	var context_value: Variant = result.get("context")
	assert_true(runner_value is GFDialogueRunner)
	assert_true(context_value is GFDialogueContext)
	if not runner_value is GFDialogueRunner or not context_value is GFDialogueContext:
		return
	var runner: GFDialogueRunner = runner_value
	var context: GFDialogueContext = context_value
	assert_eq(
		runner.get_current_line().line_id,
		&"chapter_1_after_reward"
	)
	assert_eq(
		GFVariantData.get_option_int(context.values, "balance"),
		5
	)
	assert_false(
		context.mutation_handler.is_valid(),
		"准备阶段不安装可能影响外部状态的 handler。"
	)
	assert_true(RECIPE_SCRIPT.claim_reward_once(context))
	assert_eq(
		GFVariantData.get_option_int(context.values, "balance"),
		5,
		"显式 effect receipt 阻止项目奖励再次入账。"
	)
	assert_eq(
		GFVariantData.get_option_array(context.values, "effect_ids"),
		["chapter-1.reward"]
	)
	assert_false(
		runner.create_runtime_snapshot().is_empty(),
		"候选成功后可为新内容创建自己的严格快照。"
	)
	var current: Dictionary = GFVariantData.get_option_dictionary(result, "save")
	assert_true(
		GFVariantData.get_option_bool(
			RECIPE_SCRIPT.prepare_checkpoint(resource, current),
			"success"
		),
		"当前版本检查点也走同一显式策略。"
	)


func test_unmapped_or_invalid_save_never_changes_active_session() -> void:
	var old_resource: GFDialogueResource = _resource("chapter-1@1", &"reward_claimed")
	var active: GFDialogueRunner = GFDialogueRunner.new()
	var active_context: GFDialogueContext = GFDialogueContext.new(
		null,
		{ "coins": 8 }
	)
	var old_line: GFDialogueLine = active.start(
		old_resource,
		&"reward_claimed",
		active_context
	)
	var resource: GFDialogueResource = _resource("chapter-1@2", &"chapter_1_after_reward")
	var unknown_version: Dictionary = _legacy_save()
	unknown_version["schema_version"] = 3
	var unknown_checkpoint: Dictionary = _legacy_save()
	unknown_checkpoint["checkpoint_id"] = "unpublished"
	var invalid_state: Dictionary = _legacy_save()
	invalid_state["project_state"] = { "coins": 5.5, "reward_claimed": true }
	for saved: Dictionary in [
		unknown_version,
		unknown_checkpoint,
		invalid_state,
	]:
		var copy: Dictionary = saved.duplicate(true)
		var result: Dictionary = RECIPE_SCRIPT.prepare_checkpoint(resource, saved)
		assert_false(GFVariantData.get_option_bool(result, "success"))
		assert_eq(saved, copy)
		assert_same(
			active.get_current_line(),
			old_line
		)
		assert_eq(
			active_context.values,
			{ "coins": 8 }
		)


func test_project_checkpoint_rejects_automatic_or_condition_dependent_targets() -> void:
	var current: Dictionary = RECIPE_SCRIPT.migrate_save(_legacy_save())
	var resource: GFDialogueResource = _resource("chapter-1@2", &"chapter_1_after_reward")
	var checkpoint: GFDialogueLine = resource.get_line(&"chapter_1_after_reward")
	checkpoint.kind = GFDialogueLine.LineKind.MUTATION
	checkpoint.mutation_id = &"claim_reward"
	assert_false(
		GFVariantData.get_option_bool(
			RECIPE_SCRIPT.prepare_checkpoint(resource, current),
			"success"
		)
	)
	checkpoint.kind = GFDialogueLine.LineKind.TEXT
	checkpoint.condition_id = &"project_state_check"
	assert_false(
		GFVariantData.get_option_bool(
			RECIPE_SCRIPT.prepare_checkpoint(resource, current),
			"success"
		)
	)
	checkpoint.condition_id = &""
	var response: GFDialogueResponse = GFDialogueResponse.new()
	response.response_id = &"continue"
	response.condition_id = &"project_state_check"
	checkpoint.responses.append(response)
	assert_false(
		GFVariantData.get_option_bool(
			RECIPE_SCRIPT.prepare_checkpoint(resource, current),
			"success"
		)
	)


func _legacy_save() -> Dictionary:
	return {
		"schema_version": 1,
		"content_revision": "chapter-1@1",
		"checkpoint_id": "reward_claimed",
		"project_state": { "coins": 5, "reward_claimed": true },
	}


func _resource(revision: String, checkpoint_id: StringName) -> GFDialogueResource:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"grant_reward"
	resource.metadata = { "content_revision": revision }
	var mutation: GFDialogueLine = GFDialogueLine.new()
	mutation.line_id = &"grant_reward"
	mutation.kind = GFDialogueLine.LineKind.MUTATION
	mutation.mutation_id = &"claim_reward"
	mutation.next_line_id = checkpoint_id
	resource.set_line(mutation)
	var checkpoint: GFDialogueLine = GFDialogueLine.new()
	checkpoint.line_id = checkpoint_id
	checkpoint.text = "Reward already claimed"
	resource.set_line(checkpoint)
	return resource
