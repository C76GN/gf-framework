## GFGridGenerationPipeline2D: 通用 2D 网格生成管线。
##
## 以候选格子为输入，按步骤输出 `Dictionary[Vector2i, Variant]`。
## 适合程序化生成的中间数据层，不绑定任何具体节点、资源或玩法类型。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFGridGenerationPipeline2D
extends Resource


# --- 导出变量 ---

## 生成步骤。
## [br]
## @api public
@export var steps: Array[GFGridGenerationStep2D] = []

## 是否在执行步骤前为全部候选格子写入默认值。
## [br]
## @api public
@export var fill_default_value: bool = false

## 默认值。
## [br]
## @api public
## [br]
## @schema default_value: Variant value written before steps when fill_default_value is enabled.
@export var default_value: Variant = null

## 管线元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary extension metadata for the generation pipeline.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 从矩形范围生成候选格子。
## [br]
## @api public
## [br]
## @param position: 范围起点。
## [br]
## @param size: 范围尺寸。
## [br]
## @return 候选格子。
static func make_rect_candidates(position: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if size.x <= 0 or size.y <= 0:
		return result
	for y: int in range(position.y, position.y + size.y):
		for x: int in range(position.x, position.x + size.x):
			result.append(Vector2i(x, y))
	return result


## 执行生成管线。
## [br]
## @api public
## [br]
## @param candidates: 候选格子。
## [br]
## @param context: 项目自定义上下文。
## [br]
## @schema context: Dictionary project-defined generation context.
## [br]
## @return 生成结果字典，key 为 Vector2i。
## [br]
## @schema return: Dictionary mapping Vector2i cells to generated values.
func generate(candidates: Array[Vector2i], context: Dictionary = {}) -> Dictionary:
	var grid: Dictionary = {}
	var _apply_result: Dictionary = _apply_to_grid_internal(grid, candidates, context, true, false)
	return grid


## 执行生成管线，并返回执行报告。
## [br]
## @api public
## [br]
## @since 4.2.0
## [br]
## @param candidates: 候选格子。
## [br]
## @param context: 项目自定义上下文。
## [br]
## @schema context: Dictionary project-defined generation context.
## [br]
## @return 执行报告，包含生成结果和步骤统计。
## [br]
## @schema return: Dictionary with ok, grid, candidate_count, initial_grid_count, default_filled_count, final_grid_count, configured_step_count, applied_step_count, skipped_step_count, changed_count, elapsed_usec, metadata, and steps.
func generate_with_report(candidates: Array[Vector2i], context: Dictionary = {}) -> Dictionary:
	var grid: Dictionary = {}
	return _apply_to_grid_internal(grid, candidates, context, true, true)


## 在已有网格上执行生成管线。
## [br]
## @api public
## [br]
## @param grid: 目标网格字典，key 为 Vector2i。
## [br]
## @schema grid: Dictionary mapping Vector2i cells to generated values; mutated in place.
## [br]
## @param candidates: 候选格子。
## [br]
## @param context: 项目自定义上下文。
## [br]
## @schema context: Dictionary project-defined generation context.
## [br]
## @return 目标网格本身。
## [br]
## @schema return: Dictionary same grid instance passed to the method.
func apply_to_grid(
	grid: Dictionary,
	candidates: Array[Vector2i],
	context: Dictionary = {}
) -> Dictionary:
	var _apply_result: Dictionary = _apply_to_grid_internal(grid, candidates, context, false, false)
	return grid


## 在已有网格上执行生成管线，并返回执行报告。
## [br]
## @api public
## [br]
## @since 4.2.0
## [br]
## @param grid: 目标网格字典，key 为 Vector2i。
## [br]
## @schema grid: Dictionary mapping Vector2i cells to generated values; mutated in place.
## [br]
## @param candidates: 候选格子。
## [br]
## @param context: 项目自定义上下文。
## [br]
## @schema context: Dictionary project-defined generation context.
## [br]
## @return 执行报告，grid 字段为传入的目标网格。
## [br]
## @schema return: Dictionary with ok, grid, candidate_count, initial_grid_count, default_filled_count, final_grid_count, configured_step_count, applied_step_count, skipped_step_count, changed_count, elapsed_usec, metadata, and steps.
func apply_to_grid_with_report(
	grid: Dictionary,
	candidates: Array[Vector2i],
	context: Dictionary = {}
) -> Dictionary:
	return _apply_to_grid_internal(grid, candidates, context, false, true)


## 添加生成步骤。
## [br]
## @api public
## [br]
## @param step: 生成步骤。
func add_step(step: GFGridGenerationStep2D) -> void:
	if step == null:
		return
	steps.append(step)


## 清空生成步骤。
## [br]
## @api public
func clear_steps() -> void:
	steps.clear()


## 获取诊断快照。
## [br]
## @api public
## [br]
## @return 诊断字典。
## [br]
## @schema return: Dictionary with step_count, fill_default_value, metadata, and steps.
func get_debug_snapshot() -> Dictionary:
	var step_snapshots: Array[Dictionary] = []
	for step: GFGridGenerationStep2D in steps:
		if step != null:
			step_snapshots.append(step.get_debug_snapshot())
	return {
		"step_count": steps.size(),
		"fill_default_value": fill_default_value,
		"metadata": metadata.duplicate(true),
		"steps": step_snapshots,
	}


# --- 私有/辅助方法 ---

func _apply_to_grid_internal(
	grid: Dictionary,
	candidates: Array[Vector2i],
	context: Dictionary,
	overwrite_default_values: bool,
	collect_report: bool
) -> Dictionary:
	var started_usec: int = Time.get_ticks_usec() if collect_report else 0
	var initial_grid_count: int = grid.size() if collect_report else 0
	var default_filled_count: int = _fill_default_values(grid, candidates, overwrite_default_values)
	var step_reports: Array[Dictionary] = []
	var applied_step_count: int = 0
	var skipped_step_count: int = 0
	var changed_count: int = 0

	for step_index: int in range(steps.size()):
		var step: GFGridGenerationStep2D = steps[step_index]
		if step == null:
			if collect_report:
				step_reports.append(_make_skipped_step_report(step_index, &"null_step", grid.size()))
				skipped_step_count += 1
			continue

		var step_started_usec: int = 0
		var grid_size_before: int = 0
		if collect_report:
			step_started_usec = Time.get_ticks_usec()
			grid_size_before = grid.size()
		var step_changed_count: int = step.apply(grid, candidates, context)
		if collect_report:
			var step_elapsed_usec: int = Time.get_ticks_usec() - step_started_usec
			applied_step_count += 1
			changed_count += step_changed_count
			step_reports.append(_make_applied_step_report(
				step,
				step_index,
				step_changed_count,
				grid_size_before,
				grid.size(),
				step_elapsed_usec
			))

	if not collect_report:
		return {
			"ok": true,
			"grid": grid,
		}
	return {
		"ok": true,
		"grid": grid,
		"candidate_count": candidates.size(),
		"initial_grid_count": initial_grid_count,
		"default_filled_count": default_filled_count,
		"final_grid_count": grid.size(),
		"configured_step_count": steps.size(),
		"applied_step_count": applied_step_count,
		"skipped_step_count": skipped_step_count,
		"changed_count": changed_count,
		"elapsed_usec": Time.get_ticks_usec() - started_usec,
		"metadata": metadata.duplicate(true),
		"steps": step_reports,
	}


func _fill_default_values(
	grid: Dictionary,
	candidates: Array[Vector2i],
	overwrite_default_values: bool
) -> int:
	if not fill_default_value:
		return 0

	var filled_count: int = 0
	for cell: Vector2i in candidates:
		if not overwrite_default_values and grid.has(cell):
			continue
		grid[cell] = GFVariantData.duplicate_variant(default_value)
		filled_count += 1
	return filled_count


func _make_applied_step_report(
	step: GFGridGenerationStep2D,
	step_index: int,
	step_changed_count: int,
	grid_size_before: int,
	grid_size_after: int,
	step_elapsed_usec: int
) -> Dictionary:
	return {
		"index": step_index,
		"step_id": step.step_id,
		"skipped": false,
		"reason": &"",
		"changed_count": step_changed_count,
		"grid_size_before": grid_size_before,
		"grid_size_after": grid_size_after,
		"elapsed_usec": step_elapsed_usec,
		"metadata": step.metadata.duplicate(true),
	}


func _make_skipped_step_report(step_index: int, reason: StringName, grid_size: int) -> Dictionary:
	return {
		"index": step_index,
		"step_id": &"",
		"skipped": true,
		"reason": reason,
		"changed_count": 0,
		"grid_size_before": grid_size,
		"grid_size_after": grid_size,
		"elapsed_usec": 0,
		"metadata": {},
	}
