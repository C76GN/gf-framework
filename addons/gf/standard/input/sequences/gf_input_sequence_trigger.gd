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

const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")
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

## 玩家级动作是否只检查同一玩家。
## [br]
## @api public
@export var player_scoped: bool = true


# --- 私有变量 ---

var _required_branch_cache: Array[GFInputSequenceBranch] = []
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


func _advance_branches(
	state: Dictionary,
	delta: float,
	effective_branches: Array[GFInputSequenceBranch]
) -> void:
	var input_runtime: Object = _get_input_runtime(state)
	if input_runtime == null:
		return

	var branch_states: Array[Dictionary] = _get_branch_states(state, effective_branches.size())
	for branch_index: int in range(effective_branches.size()):
		var branch: GFInputSequenceBranch = effective_branches[branch_index]
		if branch == null:
			continue
		_advance_branch(branch_states[branch_index], branch, input_runtime, delta, _get_runtime_player_index(state))


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


func _make_required_action_signature() -> String:
	var parts: PackedStringArray = PackedStringArray()
	_append_signature_part(parts, str(max_gap_seconds))
	for action_id: StringName in required_action_ids:
		_append_signature_part(parts, String(action_id))
	return "|".join(parts)


func _append_signature_part(parts: PackedStringArray, value: String) -> void:
	var _append_result: bool = parts.append("%d:%s" % [value.length(), value])


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


func _get_input_runtime(state: Dictionary) -> Object:
	return _INSTANCE_GUARD._get_live_object(GFVariantData.get_option_value(state, "input_runtime"))


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

	if step.trigger_on_release and _was_action_just_completed(input_runtime, step.action_id, player_index):
		elapsed = maxf(elapsed, _get_last_completed_duration(input_runtime, step.action_id, player_index))
		branch_state["step_elapsed"] = elapsed
		branch_state["step_started"] = false
		branch_state["step_was_active"] = false
		if elapsed >= step.min_hold_seconds:
			return true
		_reset_branch_progress(branch_state)
		return false

	if just_started or (not started and is_active and (step.trigger_on_release or step.min_hold_seconds > 0.0)):
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


func _resolve_gap_seconds(step: GFInputSequenceStep, branch: GFInputSequenceBranch) -> float:
	if step != null and step.max_gap_seconds >= 0.0:
		return step.max_gap_seconds
	if branch != null and branch.max_gap_seconds >= 0.0:
		return branch.max_gap_seconds
	return max_gap_seconds


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


func _resolve_completed_gap_seconds(branch: GFInputSequenceBranch) -> float:
	if branch != null and branch.max_gap_seconds >= 0.0:
		return branch.max_gap_seconds
	return max_gap_seconds


func _get_valid_steps(branch: GFInputSequenceBranch) -> Array[GFInputSequenceStep]:
	var result: Array[GFInputSequenceStep] = []
	if branch == null:
		return result
	for step: GFInputSequenceStep in branch.steps:
		if step != null and step.action_id != &"":
			result.append(step)
	return result


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


func _make_branch_state() -> Dictionary:
	return {
		"sequence_index": 0,
		"gap_elapsed": 0.0,
		"completed": false,
		"step_elapsed": 0.0,
		"step_started": false,
		"step_was_active": false,
	}


func _has_completed_branch(state: Dictionary) -> bool:
	var branch_states: Array = GFVariantData.get_option_array(state, "branch_states")
	for branch_state_value: Variant in branch_states:
		var branch_state: Dictionary = GFVariantData.as_dictionary(branch_state_value)
		if _is_branch_completed(branch_state):
			return true
	return false


func _is_action_active(input_runtime: Object, action_id: StringName, player_index: int) -> bool:
	if player_scoped and player_index >= 0 and input_runtime.has_method("is_action_active_for_player"):
		return GFVariantData.to_bool(input_runtime.call("is_action_active_for_player", player_index, action_id))
	if input_runtime.has_method("is_action_active"):
		return GFVariantData.to_bool(input_runtime.call("is_action_active", action_id))
	return false


func _was_action_just_started(input_runtime: Object, action_id: StringName, player_index: int) -> bool:
	if player_scoped and player_index >= 0 and input_runtime.has_method("was_action_just_started_for_player"):
		return GFVariantData.to_bool(input_runtime.call("was_action_just_started_for_player", player_index, action_id))
	if input_runtime.has_method("was_action_just_started"):
		return GFVariantData.to_bool(input_runtime.call("was_action_just_started", action_id))
	return false


func _was_action_just_completed(input_runtime: Object, action_id: StringName, player_index: int) -> bool:
	if player_scoped and player_index >= 0 and input_runtime.has_method("was_action_just_completed_for_player"):
		return GFVariantData.to_bool(input_runtime.call("was_action_just_completed_for_player", player_index, action_id))
	if input_runtime.has_method("was_action_just_completed"):
		return GFVariantData.to_bool(input_runtime.call("was_action_just_completed", action_id))
	return false


func _get_last_completed_duration(input_runtime: Object, action_id: StringName, player_index: int) -> float:
	if player_scoped and player_index >= 0 and input_runtime.has_method("get_last_completed_duration_for_player"):
		return GFVariantData.to_float(input_runtime.call("get_last_completed_duration_for_player", player_index, action_id))
	if input_runtime.has_method("get_last_completed_duration"):
		return GFVariantData.to_float(input_runtime.call("get_last_completed_duration", action_id))
	return 0.0


func _reset_all_branch_progress(state: Dictionary) -> void:
	state["sequence_index"] = 0
	state["gap_elapsed"] = 0.0
	state["completed"] = false
	var branch_states: Array = GFVariantData.get_option_array(state, "branch_states")
	state["branch_states"] = branch_states
	for branch_state_value: Variant in branch_states:
		if branch_state_value is Dictionary:
			_reset_branch_progress(GFVariantData.as_dictionary(branch_state_value))


func _reset_branch_progress(branch_state: Dictionary) -> void:
	branch_state["sequence_index"] = 0
	branch_state["gap_elapsed"] = 0.0
	branch_state["completed"] = false
	branch_state["step_elapsed"] = 0.0
	branch_state["step_started"] = false
	branch_state["step_was_active"] = false


func _get_runtime_player_index(state: Dictionary) -> int:
	return GFVariantData.get_option_int(state, "player_index", -1)


func _is_branch_completed(branch_state: Dictionary) -> bool:
	return GFVariantData.get_option_bool(branch_state, "completed")


func _get_branch_sequence_index(branch_state: Dictionary) -> int:
	return GFVariantData.get_option_int(branch_state, "sequence_index")


func _was_step_active(branch_state: Dictionary) -> bool:
	return GFVariantData.get_option_bool(branch_state, "step_was_active")


func _has_step_started(branch_state: Dictionary) -> bool:
	return GFVariantData.get_option_bool(branch_state, "step_started")


func _get_step_elapsed(branch_state: Dictionary) -> float:
	return GFVariantData.get_option_float(branch_state, "step_elapsed")


func _get_gap_elapsed(branch_state: Dictionary) -> float:
	return GFVariantData.get_option_float(branch_state, "gap_elapsed")
