## GFInputSequenceTrigger: 动作序列触发器。
##
## 按顺序观察一组前置动作的 just-started 状态，全部完成后当前输入活跃时触发。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputSequenceTrigger
extends GFInputTrigger


# --- 常量 ---

## 提供输入运行时实例的有效性检查。
## [br]
## @api private
## [br]
const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")

## 分支配置签名在触发器运行时状态字典中的键名。
## [br]
## @api private
## [br]
const _BRANCH_CONFIGURATION_SIGNATURE_KEY: String = "branch_configuration_signature"


# --- 导出变量 ---

## 当前动作触发前必须依次开始的动作列表。
## [br]
## @api public
## [br]
## @schema required_action_ids: Array[StringName] of action ids that must start in order before this trigger can fire.
@export var required_action_ids: Array[StringName] = []

## 可选输入序列分支。非空时优先使用分支配置，required_action_ids 保持兼容旧资源。
## [br]
## @api public
@export var branches: Array[GFInputSequenceBranch] = []

## 相邻步骤允许的最大间隔。小于等于 0 表示不限制。
## [br]
## @api public
@export var max_gap_seconds: float = 0.4:
	set(value):
		max_gap_seconds = maxf(value, 0.0)

## 玩家级动作是否只检查同一玩家。启用且 player_index 有效时，runtime 必须提供
## 完整 player-specific active/started/completed/duration 协议，否则序列不推进。
## 所有序列都要求 runtime 提供动作边沿版本，避免重复消费同一次输入。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var player_scoped: bool = true


# --- 私有变量 ---

## 从兼容字段 required_action_ids 构建的单分支缓存。
## [br]
## @api private
## [br]
var _required_branch_cache: Array[GFInputSequenceBranch] = []

## 缓存对应的动作 ID 与间隔配置签名。
## [br]
## @api private
## [br]
var _required_branch_cache_signature: String = ""


# --- 公共方法 ---

## 重置输入触发器运行时状态。
## [br]
## @api public
## [br]
## @param state: 触发器运行时状态字典。
## [br]
## @schema state: Dictionary，由输入运行时持有，包含 sequence_index、gap_elapsed、completed 和 branch_states。
func reset_trigger_state(state: Dictionary) -> void:
	state.clear()
	state["sequence_index"] = 0
	state["gap_elapsed"] = 0.0
	state["completed"] = false
	state["branch_states"] = []
	state[_BRANCH_CONFIGURATION_SIGNATURE_KEY] = ""


## 准备输入动作运行时状态。
## [br]
## @api public
## [br]
## @param _action_id: 当前输入动作标识，默认实现不直接使用。
## [br]
## @param input_runtime: 输入映射运行时。
## [br]
## @param player_index: 玩家索引。
## [br]
## @param state: 触发器运行时状态字典。
## [br]
## @schema state: Dictionary，由输入运行时持有，包含 input_runtime: Object 和 player_index: int。
func prepare_runtime(
	_action_id: StringName,
	input_runtime: Object,
	player_index: int,
	state: Dictionary
) -> void:
	state["input_runtime"] = input_runtime
	state["player_index"] = player_index


## 更新运行时状态。
## [br]
## @api public
## [br]
## @param raw_active: 原始输入是否处于激活状态。
## [br]
## @param _value: 输入值，默认实现不直接使用。
## [br]
## @param delta: 本帧时间增量（秒）。
## [br]
## @param state: 触发器运行时状态字典。
## [br]
## @schema _value: Variant，由当前输入映射产生的动作值。
## [br]
## @schema state: Dictionary，由输入运行时持有，包含分支进度字段。
## [br]
## @return 触发状态。
func update(raw_active: bool, _value: Variant, delta: float, state: Dictionary) -> TriggerState:
	var effective_branches: Array[GFInputSequenceBranch] = _get_effective_branches()
	_ensure_branch_configuration_state(state, effective_branches)
	if effective_branches.is_empty():
		return TriggerState.TRIGGERED if raw_active else TriggerState.INACTIVE

	_advance_branches(state, delta, effective_branches)
	if _has_completed_branch(state) and raw_active:
		_reset_all_branch_progress(state)
		return TriggerState.TRIGGERED

	return TriggerState.ONGOING if raw_active else TriggerState.INACTIVE


# --- 私有/辅助方法 ---

## 过滤出有效的显式分支；没有有效显式分支时，将兼容字段 required_action_ids 转为单分支。
## [br]
## @api private
## [br]
func _get_effective_branches() -> Array[GFInputSequenceBranch]:
	var result: Array[GFInputSequenceBranch] = []
	for branch: GFInputSequenceBranch in branches:
		if branch != null and branch.is_valid_branch():
			result.append(branch)
	if not result.is_empty():
		return result
	if required_action_ids.is_empty():
		return result
	return _get_required_action_branches()


## 验证运行时查询能力和玩家协议后，为每个有效分支取得状态并推进其序列。
## [br]
## @api private
## [br]
func _advance_branches(
	state: Dictionary,
	delta: float,
	effective_branches: Array[GFInputSequenceBranch]
) -> void:
	var input_runtime: Object = _get_input_runtime(state)
	if input_runtime == null or not input_runtime.has_method("get_action_edge_revision_for_framework"):
		return
	var player_index: int = _get_runtime_player_index(state)
	if player_scoped and player_index >= 0 and not _has_complete_player_query_protocol(input_runtime):
		return

	var branch_states: Array[Dictionary] = _get_branch_states(state, effective_branches.size())
	for branch_index: int in range(effective_branches.size()):
		var branch: GFInputSequenceBranch = effective_branches[branch_index]
		if branch == null:
			continue
		_advance_branch(branch_states[branch_index], branch, input_runtime, delta, player_index)


## 按动作列表和默认间隔签名缓存兼容分支；配置变化或缓存为空时重新构建。
## [br]
## @api private
## [br]
func _get_required_action_branches() -> Array[GFInputSequenceBranch]:
	var signature: String = _make_required_action_signature()
	if _required_branch_cache_signature != signature or _required_branch_cache.is_empty():
		_required_branch_cache_signature = signature
		_required_branch_cache.clear()
		_required_branch_cache.append(GFInputSequenceBranch.from_action_ids(required_action_ids, max_gap_seconds))
	var result: Array[GFInputSequenceBranch] = []
	for branch: GFInputSequenceBranch in _required_branch_cache:
		result.append(branch)
	return result


## 将默认间隔和 required_action_ids 依次编码为兼容分支缓存签名。
## [br]
## @api private
## [br]
func _make_required_action_signature() -> String:
	var parts: PackedStringArray = PackedStringArray()
	_append_signature_part(parts, str(max_gap_seconds))
	for action_id: StringName in required_action_ids:
		_append_signature_part(parts, String(action_id))
	return "|".join(parts)


## 将字符串长度和值追加为一个带长度前缀的签名片段。
## [br]
## @api private
## [br]
func _append_signature_part(parts: PackedStringArray, value: String) -> void:
	var _append_result: bool = parts.append("%d:%s" % [value.length(), value])


## 编码全局间隔、玩家作用域、分支顺序及有效步骤配置，用于检测运行时配置变化。
## [br]
## @api private
## [br]
func _make_branch_configuration_signature(effective_branches: Array[GFInputSequenceBranch]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	_append_signature_part(parts, str(max_gap_seconds))
	_append_signature_part(parts, "1" if player_scoped else "0")
	_append_signature_part(parts, str(effective_branches.size()))
	for branch: GFInputSequenceBranch in effective_branches:
		_append_signature_part(parts, str(branch.max_gap_seconds))
		var steps: Array[GFInputSequenceStep] = _get_valid_steps(branch)
		_append_signature_part(parts, str(steps.size()))
		for step: GFInputSequenceStep in steps:
			_append_signature_part(parts, String(step.action_id))
			_append_signature_part(parts, str(step.max_gap_seconds))
			_append_signature_part(parts, str(step.min_hold_seconds))
			_append_signature_part(parts, "1" if step.trigger_on_release else "0")
	return "|".join(parts)


## 分支配置签名变化时重置顶层进度和分支状态，并保存新签名。
## [br]
## @api private
## [br]
func _ensure_branch_configuration_state(
	state: Dictionary,
	effective_branches: Array[GFInputSequenceBranch]
) -> void:
	var signature: String = _make_branch_configuration_signature(effective_branches)
	if GFVariantData.get_option_string(state, _BRANCH_CONFIGURATION_SIGNATURE_KEY) == signature:
		return
	state["sequence_index"] = 0
	state["gap_elapsed"] = 0.0
	state["completed"] = false
	state["branch_states"] = []
	state[_BRANCH_CONFIGURATION_SIGNATURE_KEY] = signature


## 推进单个分支；处理已完成分支的超时间隔、当前步骤的超时间隔及步骤完成后的游标状态。
## [br]
## @api private
## [br]
func _advance_branch(
	branch_state: Dictionary,
	branch: GFInputSequenceBranch,
	input_runtime: Object,
	delta: float,
	player_index: int
) -> void:
	if _is_branch_completed(branch_state):
		_advance_completed_branch_gap(branch_state, branch, delta)
		return

	var sequence_index: int = _get_branch_sequence_index(branch_state)
	var steps: Array[GFInputSequenceStep] = _get_valid_steps(branch)
	if sequence_index >= steps.size():
		branch_state["completed"] = true
		return

	var current_step: GFInputSequenceStep = steps[sequence_index]
	if _should_reset_for_gap(branch_state, current_step, branch, delta):
		_reset_branch_progress(branch_state)
		sequence_index = 0
		current_step = steps[sequence_index]

	if _advance_step(branch_state, current_step, input_runtime, delta, player_index):
		sequence_index += 1
		branch_state["sequence_index"] = sequence_index
		branch_state["gap_elapsed"] = 0.0
		branch_state["step_elapsed"] = 0.0
		branch_state["step_started"] = false
		branch_state["step_was_active"] = false
		if sequence_index >= steps.size():
			branch_state["completed"] = true


## 从触发器状态读取 input_runtime 并通过实例守卫取得仍有效的对象。
## [br]
## @api private
## [br]
func _get_input_runtime(state: Dictionary) -> Object:
	return _INSTANCE_GUARD._get_live_object(GFVariantData.get_option_value(state, "input_runtime"))


## 按步骤的开始/释放条件和最短保持时长消费动作边沿并更新步骤计时状态。
## 释放步骤检查完成边沿与最近完成时长；未达保持时长或保持中的步骤过早释放时重置当前分支。
## [br]
## @api private
## [br]
func _advance_step(
	branch_state: Dictionary,
	step: GFInputSequenceStep,
	input_runtime: Object,
	delta: float,
	player_index: int
) -> bool:
	if step == null or step.action_id == &"":
		return true

	var is_active: bool = _is_action_active(input_runtime, step.action_id, player_index)
	var was_active: bool = _was_step_active(branch_state)
	var started: bool = _has_step_started(branch_state)
	var elapsed: float = _get_step_elapsed(branch_state)
	var just_started: bool = _was_action_just_started(input_runtime, step.action_id, player_index)

	if (
		step.trigger_on_release
		and _was_action_just_completed(input_runtime, step.action_id, player_index)
		and _consume_action_edge(branch_state, input_runtime, step.action_id, player_index, true)
	):
		elapsed = maxf(elapsed, _get_last_completed_duration(input_runtime, step.action_id, player_index))
		branch_state["step_elapsed"] = elapsed
		branch_state["step_started"] = false
		branch_state["step_was_active"] = false
		if elapsed >= step.min_hold_seconds:
			return true
		_reset_branch_progress(branch_state)
		return false

	var may_start: bool = just_started or (
		not started and is_active and (step.trigger_on_release or step.min_hold_seconds > 0.0)
	)
	if may_start and _consume_action_edge(branch_state, input_runtime, step.action_id, player_index, false):
		started = true
		elapsed = maxf(delta, 0.0) if is_active else 0.0
	elif started and is_active:
		elapsed += maxf(delta, 0.0)

	branch_state["step_started"] = started
	branch_state["step_elapsed"] = elapsed
	branch_state["step_was_active"] = is_active

	if step.trigger_on_release:
		if started and was_active and not is_active:
			if elapsed >= step.min_hold_seconds:
				return true
			_reset_branch_progress(branch_state)
		return false

	if not started:
		return false
	if step.min_hold_seconds <= 0.0:
		return true
	if is_active and elapsed >= step.min_hold_seconds:
		return true
	if not is_active and was_active:
		_reset_branch_progress(branch_state)
	return false


## 读取动作边沿修订号，并仅在其高于分支状态已消费修订时保存并返回 true。
## [br]
## @api private
## [br]
func _consume_action_edge(
	branch_state: Dictionary,
	input_runtime: Object,
	action_id: StringName,
	player_index: int,
	completed: bool
) -> bool:
	var revision: int = GFVariantData.to_int(input_runtime.call(
		"get_action_edge_revision_for_framework",
		action_id,
		player_index if player_scoped else -1,
		completed
	))
	var key: String = "consumed_completed_edges" if completed else "consumed_started_edges"
	var consumed_edges: Dictionary = GFVariantData.get_option_dictionary(branch_state, key)
	if revision <= GFVariantData.get_option_int(consumed_edges, action_id):
		return false
	consumed_edges[action_id] = revision
	branch_state[key] = consumed_edges
	return true


## 仅对尚未开始的后续步骤累计 gap；超出解析后的间隔时返回 true。
## [br]
## @api private
## [br]
func _should_reset_for_gap(
	branch_state: Dictionary,
	step: GFInputSequenceStep,
	branch: GFInputSequenceBranch,
	delta: float
) -> bool:
	if _get_branch_sequence_index(branch_state) <= 0:
		return false
	if _has_step_started(branch_state):
		return false

	var gap_seconds: float = _resolve_gap_seconds(step, branch)
	if gap_seconds <= 0.0:
		return false

	var gap_elapsed: float = _get_gap_elapsed(branch_state) + maxf(delta, 0.0)
	branch_state["gap_elapsed"] = gap_elapsed
	return gap_elapsed > gap_seconds


## 按步骤、分支、触发器的顺序选择第一个非负最大间隔。
## [br]
## @api private
## [br]
func _resolve_gap_seconds(step: GFInputSequenceStep, branch: GFInputSequenceBranch) -> float:
	if step != null and step.max_gap_seconds >= 0.0:
		return step.max_gap_seconds
	if branch != null and branch.max_gap_seconds >= 0.0:
		return branch.max_gap_seconds
	return max_gap_seconds


## 为已完成分支继续累计允许间隔，超过间隔时重置分支进度。
## [br]
## @api private
## [br]
func _advance_completed_branch_gap(
	branch_state: Dictionary,
	branch: GFInputSequenceBranch,
	delta: float
) -> void:
	var gap_seconds: float = _resolve_completed_gap_seconds(branch)
	if gap_seconds <= 0.0:
		return
	var gap_elapsed: float = _get_gap_elapsed(branch_state) + maxf(delta, 0.0)
	branch_state["gap_elapsed"] = gap_elapsed
	if gap_elapsed > gap_seconds:
		_reset_branch_progress(branch_state)


## 已完成分支优先使用其非负间隔，否则使用触发器默认间隔。
## [br]
## @api private
## [br]
func _resolve_completed_gap_seconds(branch: GFInputSequenceBranch) -> float:
	if branch != null and branch.max_gap_seconds >= 0.0:
		return branch.max_gap_seconds
	return max_gap_seconds


## 返回分支中非空且 action_id 非空的步骤。
## [br]
## @api private
## [br]
func _get_valid_steps(branch: GFInputSequenceBranch) -> Array[GFInputSequenceStep]:
	var result: Array[GFInputSequenceStep] = []
	if branch == null:
		return result
	for step: GFInputSequenceStep in branch.steps:
		if step != null and step.action_id != &"":
			result.append(step)
	return result


## 将 branch_states 数量调整到分支数，填补或替换无效项并返回类型化字典数组。
## [br]
## @api private
## [br]
func _get_branch_states(state: Dictionary, branch_count: int) -> Array[Dictionary]:
	var branch_states: Array = GFVariantData.get_option_array(state, "branch_states")
	while branch_states.size() < branch_count:
		branch_states.append(_make_branch_state())
	while branch_states.size() > branch_count:
		branch_states.pop_back()
	state["branch_states"] = branch_states
	var typed_states: Array[Dictionary] = []
	for index: int in range(branch_states.size()):
		var branch_state_value: Variant = branch_states[index]
		if branch_state_value is Dictionary:
			typed_states.append(GFVariantData.as_dictionary(branch_state_value))
		else:
			var replacement: Dictionary = _make_branch_state()
			branch_states[index] = replacement
			typed_states.append(replacement)
	return typed_states


## 创建包含步骤索引、间隔、完成标记和当前步骤计时字段的初始状态。
## [br]
## @api private
## [br]
func _make_branch_state() -> Dictionary:
	return {
		"sequence_index": 0,
		"gap_elapsed": 0.0,
		"completed": false,
		"step_elapsed": 0.0,
		"step_started": false,
		"step_was_active": false,
	}


## 检查 branch_states 中是否至少有一个分支已完成。
## [br]
## @api private
## [br]
func _has_completed_branch(state: Dictionary) -> bool:
	var branch_states: Array = GFVariantData.get_option_array(state, "branch_states")
	for branch_state_value: Variant in branch_states:
		var branch_state: Dictionary = GFVariantData.as_dictionary(branch_state_value)
		if _is_branch_completed(branch_state):
			return true
	return false


## 玩家作用域有效时调用玩家活跃查询；否则调用全局查询，缺少所需方法时返回 false。
## [br]
## @api private
## [br]
func _is_action_active(input_runtime: Object, action_id: StringName, player_index: int) -> bool:
	if player_scoped and player_index >= 0:
		if not input_runtime.has_method("is_action_active_for_player"):
			return false
		return GFVariantData.to_bool(input_runtime.call("is_action_active_for_player", player_index, action_id))
	if input_runtime.has_method("is_action_active"):
		return GFVariantData.to_bool(input_runtime.call("is_action_active", action_id))
	return false


## 按当前作用域读取动作 just-started 标记；查询方法缺失时返回 false。
## [br]
## @api private
## [br]
func _was_action_just_started(input_runtime: Object, action_id: StringName, player_index: int) -> bool:
	if player_scoped and player_index >= 0:
		if not input_runtime.has_method("was_action_just_started_for_player"):
			return false
		return GFVariantData.to_bool(input_runtime.call("was_action_just_started_for_player", player_index, action_id))
	if input_runtime.has_method("was_action_just_started"):
		return GFVariantData.to_bool(input_runtime.call("was_action_just_started", action_id))
	return false


## 按当前作用域读取动作 just-completed 标记；查询方法缺失时返回 false。
## [br]
## @api private
## [br]
func _was_action_just_completed(input_runtime: Object, action_id: StringName, player_index: int) -> bool:
	if player_scoped and player_index >= 0:
		if not input_runtime.has_method("was_action_just_completed_for_player"):
			return false
		return GFVariantData.to_bool(input_runtime.call("was_action_just_completed_for_player", player_index, action_id))
	if input_runtime.has_method("was_action_just_completed"):
		return GFVariantData.to_bool(input_runtime.call("was_action_just_completed", action_id))
	return false


## 按当前作用域读取动作最近完成时长；查询方法缺失时返回 0。
## [br]
## @api private
## [br]
func _get_last_completed_duration(input_runtime: Object, action_id: StringName, player_index: int) -> float:
	if player_scoped and player_index >= 0:
		if not input_runtime.has_method("get_last_completed_duration_for_player"):
			return 0.0
		return GFVariantData.to_float(input_runtime.call("get_last_completed_duration_for_player", player_index, action_id))
	if input_runtime.has_method("get_last_completed_duration"):
		return GFVariantData.to_float(input_runtime.call("get_last_completed_duration", action_id))
	return 0.0


## 检查运行时是否提供玩家活跃、开始边沿、完成边沿和最近完成时长四种查询。
## [br]
## @api private
## [br]
func _has_complete_player_query_protocol(input_runtime: Object) -> bool:
	return (
		input_runtime.has_method("is_action_active_for_player")
		and input_runtime.has_method("was_action_just_started_for_player")
		and input_runtime.has_method("was_action_just_completed_for_player")
		and input_runtime.has_method("get_last_completed_duration_for_player")
	)


## 重置顶层序列进度，并重置数组中每个字典分支的步骤与计时字段。
## [br]
## @api private
## [br]
func _reset_all_branch_progress(state: Dictionary) -> void:
	state["sequence_index"] = 0
	state["gap_elapsed"] = 0.0
	state["completed"] = false
	var branch_states: Array = GFVariantData.get_option_array(state, "branch_states")
	state["branch_states"] = branch_states
	for branch_state_value: Variant in branch_states:
		if branch_state_value is Dictionary:
			_reset_branch_progress(GFVariantData.as_dictionary(branch_state_value))


## 将分支步骤索引、间隔、完成和当前步骤计时标记恢复初值。
## 其他状态键（包括已消费边沿修订记录）保持不变。
## [br]
## @api private
## [br]
func _reset_branch_progress(branch_state: Dictionary) -> void:
	branch_state["sequence_index"] = 0
	branch_state["gap_elapsed"] = 0.0
	branch_state["completed"] = false
	branch_state["step_elapsed"] = 0.0
	branch_state["step_started"] = false
	branch_state["step_was_active"] = false


## 读取运行时状态中的玩家索引；缺失时返回 -1。
## [br]
## @api private
## [br]
func _get_runtime_player_index(state: Dictionary) -> int:
	return GFVariantData.get_option_int(state, "player_index", -1)


## 读取分支状态的 completed 标记。
## [br]
## @api private
## [br]
func _is_branch_completed(branch_state: Dictionary) -> bool:
	return GFVariantData.get_option_bool(branch_state, "completed")


## 读取分支当前步骤索引。
## [br]
## @api private
## [br]
func _get_branch_sequence_index(branch_state: Dictionary) -> int:
	return GFVariantData.get_option_int(branch_state, "sequence_index")


## 读取当前步骤上一更新中的动作活跃标记。
## [br]
## @api private
## [br]
func _was_step_active(branch_state: Dictionary) -> bool:
	return GFVariantData.get_option_bool(branch_state, "step_was_active")


## 读取当前步骤是否已观察到有效开始边沿。
## [br]
## @api private
## [br]
func _has_step_started(branch_state: Dictionary) -> bool:
	return GFVariantData.get_option_bool(branch_state, "step_started")


## 读取当前步骤已累计的保持时长。
## [br]
## @api private
## [br]
func _get_step_elapsed(branch_state: Dictionary) -> float:
	return GFVariantData.get_option_float(branch_state, "step_elapsed")


## 读取当前分支步骤间隔累计时长。
## [br]
## @api private
## [br]
func _get_gap_elapsed(branch_state: Dictionary) -> float:
	return GFVariantData.get_option_float(branch_state, "gap_elapsed")
