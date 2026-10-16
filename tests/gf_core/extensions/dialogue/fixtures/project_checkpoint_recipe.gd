## 示例项目的固定章节恢复策略；不是 GF 通用存档 API。
## 这里只接受项目明确发布过的两个版本与一个已领取奖励检查点。
extends RefCounted


## 将已验证的项目存档转换为当前版本，未知映射失败，不修改输入。
static func migrate_save(saved: Dictionary) -> Dictionary:
	var schema: Variant = saved.get("schema_version")
	var revision: Variant = saved.get("content_revision")
	var checkpoint: Variant = saved.get("checkpoint_id")
	var state_value: Variant = saved.get("project_state")
	if (
		not schema is int
		or not revision is String
		or not checkpoint is String
		or not state_value is Dictionary
	):
		return {}
	var state: Dictionary = state_value
	if (
		schema == 1
		and revision == "chapter-1@1"
		and checkpoint == "reward_claimed"
	):
		var coins: Variant = state.get("coins")
		var claimed: Variant = state.get("reward_claimed")
		if (
			not coins is int
			or coins < 0
			or not claimed is bool
			or claimed != true
		):
			return {}
		# 该项目 v1 的 true 明确表示奖励已提交；只能迁移这一已发布含义。
		var saved_coins: int = coins
		return _current_save(
			saved_coins,
			["chapter-1.reward"]
		)
	if (
		schema == 2
		and revision == "chapter-1@2"
		and checkpoint == "after_reward"
	):
		var balance: Variant = state.get("balance")
		var effects: Variant = state.get("effect_ids")
		if (
			not balance is int
			or balance < 0
			or not effects is Array
		):
			return {}
		var effect_ids: Array = effects
		if (
			effect_ids.size() != 1
			or not effect_ids[0] is String
			or effect_ids[0] != "chapter-1.reward"
		):
			return {}
		var saved_balance: int = balance
		return _current_save(
			saved_balance,
			["chapter-1.reward"]
		)
	return {}


## 准备独立候选会话；不接收旧 Runner、旧 Context 或外部业务回调。
## 此检查点必须是无条件 TEXT，准备期间不接外部信号订阅者，也不推进后继。
static func prepare_checkpoint(resource: GFDialogueResource, saved: Dictionary) -> Dictionary:
	var current: Dictionary = migrate_save(saved)
	if current.is_empty():
		return { "success": false, "reason": "unsupported_save" }
	if resource == null or resource.metadata.get("content_revision") != "chapter-1@2":
		return { "success": false, "reason": "wrong_content_revision" }
	if not GFVariantData.get_option_bool(
		resource.validate_resource(),
		"ok"
	):
		return { "success": false, "reason": "invalid_resource" }
	var line: GFDialogueLine = resource.get_line(&"chapter_1_after_reward")
	if (
		line == null
		or line.kind != GFDialogueLine.LineKind.TEXT
		or line.condition_id != &""
	):
		return { "success": false, "reason": "unsafe_checkpoint" }
	for response: GFDialogueResponse in line.responses:
		if response == null or response.condition_id != &"":
			return { "success": false, "reason": "unsafe_checkpoint" }
	var context: GFDialogueContext = GFDialogueContext.new(
		null,
		GFVariantData.get_option_dictionary(current, "project_state")
	)
	var candidate: GFDialogueRunner = GFDialogueRunner.new()
	if candidate.start(
		resource,
		line.line_id,
		context
	) != line:
		return { "success": false, "reason": "start_rejected" }
	return {
		"success": true,
		"runner": candidate,
		"context": context,
		"save": current,
	}


## 只接收本项目已校验的 Context；余额与 receipt 一次替换，不模拟外部支付或磁盘事务。
static func claim_reward_once(context: GFDialogueContext) -> bool:
	var state: Dictionary = context.values
	var effect_ids: Array = GFVariantData.get_option_array(state, "effect_ids")
	if effect_ids.has("chapter-1.reward"):
		return true
	var next_state: Dictionary = state.duplicate(true)
	var next_effect_ids: Array = effect_ids.duplicate()
	next_effect_ids.append("chapter-1.reward")
	next_state["balance"] = GFVariantData.get_option_int(state, "balance") + 5
	next_state["effect_ids"] = next_effect_ids
	context.values = next_state
	return true


static func _current_save(balance: int, effect_ids: Array[String]) -> Dictionary:
	return {
		"schema_version": 2,
		"content_revision": "chapter-1@2",
		"checkpoint_id": "after_reward",
		"project_state": { "balance": balance, "effect_ids": effect_ids.duplicate() },
	}
