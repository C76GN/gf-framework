## 测试通用 2D 网格生成管线。
extends GutTest


# --- 测试方法 ---

func test_grid_generation_pipeline_applies_selection_steps() -> void:
	var candidates: Array[Vector2i] = GFGridGenerationPipeline2D.make_rect_candidates(Vector2i.ZERO, Vector2i(3, 2))
	var selection: GFGridSelection2D = GFGridSelection2D.new()
	selection.use_bounds = true
	selection.bounds_position = Vector2i(1, 0)
	selection.bounds_size = Vector2i(2, 1)
	var step: GFGridGenerationStep2D = GFGridGenerationStep2D.new()
	step.selection = selection
	step.value = "edge"
	var pipeline: GFGridGenerationPipeline2D = GFGridGenerationPipeline2D.new()
	pipeline.fill_default_value = true
	pipeline.default_value = "empty"
	pipeline.add_step(step)

	var grid: Dictionary = pipeline.generate(candidates)

	assert_eq(GFVariantData.get_option_string(grid, Vector2i(0, 0)), "empty", "未选中格子应保留默认值。")
	assert_eq(GFVariantData.get_option_string(grid, Vector2i(1, 0)), "edge", "选中格子应写入步骤值。")
	assert_eq(GFVariantData.get_option_string(grid, Vector2i(2, 0)), "edge", "矩形选择器应覆盖边界内格子。")
	assert_eq(grid.size(), 6, "默认填充应覆盖全部候选格子。")


func test_grid_generation_step_can_use_value_callback_and_erase() -> void:
	var candidates: Array[Vector2i] = GFGridGenerationPipeline2D.make_rect_candidates(Vector2i.ZERO, Vector2i(2, 1))
	var write_step: GFGridGenerationStep2D = GFGridGenerationStep2D.new()
	write_step.value_callback = func(cell: Vector2i, _previous_value: Variant, context: Dictionary) -> Variant:
		return GFVariantData.get_option_int(context, "base", 0) + cell.x
	var erase_selection: GFGridSelection2D = GFGridSelection2D.new()
	erase_selection.included_cells = [Vector2i(0, 0)]
	var erase_step: GFGridGenerationStep2D = GFGridGenerationStep2D.new()
	erase_step.selection = erase_selection
	erase_step.erase_cells = true
	var pipeline: GFGridGenerationPipeline2D = GFGridGenerationPipeline2D.new()
	pipeline.steps = [write_step, erase_step]

	var grid: Dictionary = pipeline.generate(candidates, { "base": 10 })

	assert_false(grid.has(Vector2i(0, 0)), "擦除步骤应移除选中格子。")
	assert_eq(GFVariantData.get_option_int(grid, Vector2i(1, 0)), 11, "值回调应能基于上下文生成通用值。")


func test_grid_generation_pipeline_report_tracks_steps_and_counts() -> void:
	var candidates: Array[Vector2i] = GFGridGenerationPipeline2D.make_rect_candidates(Vector2i.ZERO, Vector2i(3, 1))
	var write_selection: GFGridSelection2D = GFGridSelection2D.new()
	write_selection.included_cells = [Vector2i(0, 0), Vector2i(1, 0)]
	var write_step: GFGridGenerationStep2D = GFGridGenerationStep2D.new()
	write_step.step_id = &"write"
	write_step.selection = write_selection
	write_step.value = &"filled"
	write_step.metadata = { "phase": "write" }
	var erase_selection: GFGridSelection2D = GFGridSelection2D.new()
	erase_selection.included_cells = [Vector2i(0, 0)]
	var erase_step: GFGridGenerationStep2D = GFGridGenerationStep2D.new()
	erase_step.step_id = &"erase"
	erase_step.selection = erase_selection
	erase_step.erase_cells = true
	var pipeline: GFGridGenerationPipeline2D = GFGridGenerationPipeline2D.new()
	pipeline.fill_default_value = true
	pipeline.default_value = &"empty"
	pipeline.metadata = { "domain": "test" }
	pipeline.steps.append(write_step)
	pipeline.steps.append(null)
	pipeline.steps.append(erase_step)

	var report: Dictionary = pipeline.generate_with_report(candidates)
	var grid: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(report, "grid"))
	var step_reports: Array = GFVariantData.get_option_array(report, "steps")
	var write_report: Dictionary = GFVariantData.as_dictionary(step_reports[0])
	var skipped_report: Dictionary = GFVariantData.as_dictionary(step_reports[1])
	var erase_report: Dictionary = GFVariantData.as_dictionary(step_reports[2])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "报告式生成应成功完成。")
	assert_eq(GFVariantData.get_option_int(report, "candidate_count"), 3, "报告应记录候选格子数量。")
	assert_eq(GFVariantData.get_option_int(report, "initial_grid_count"), 0, "新生成报告的初始网格数量应为 0。")
	assert_eq(GFVariantData.get_option_int(report, "default_filled_count"), 3, "默认填充数量应进入报告。")
	assert_eq(GFVariantData.get_option_int(report, "final_grid_count"), 2, "报告应记录最终网格大小。")
	assert_eq(GFVariantData.get_option_int(report, "configured_step_count"), 3, "报告应记录配置步骤数量。")
	assert_eq(GFVariantData.get_option_int(report, "applied_step_count"), 2, "非空步骤应计入已应用步骤。")
	assert_eq(GFVariantData.get_option_int(report, "skipped_step_count"), 1, "空步骤应计入跳过步骤。")
	assert_eq(GFVariantData.get_option_int(report, "changed_count"), 3, "步骤修改数量应聚合到报告。")
	assert_true(GFVariantData.get_option_int(report, "elapsed_usec") >= 0, "报告应记录总耗时。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.get_option_dictionary(report, "metadata"), "domain"), "test", "报告应复制管线元数据。")
	assert_eq(grid.size(), 2, "报告中的 grid 应包含生成结果。")
	assert_false(grid.has(Vector2i(0, 0)), "擦除步骤仍应修改结果网格。")
	assert_eq(GFVariantData.get_option_string_name(write_report, "step_id"), &"write", "步骤报告应记录 step_id。")
	assert_eq(GFVariantData.get_option_int(write_report, "changed_count"), 2, "写入步骤应记录修改数量。")
	assert_false(GFVariantData.get_option_bool(write_report, "skipped"), "已应用步骤不应标记为 skipped。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.get_option_dictionary(write_report, "metadata"), "phase"), "write", "步骤报告应复制步骤元数据。")
	assert_true(GFVariantData.get_option_bool(skipped_report, "skipped"), "空步骤报告应标记为 skipped。")
	assert_eq(GFVariantData.get_option_string_name(skipped_report, "reason"), &"null_step", "空步骤跳过原因应稳定。")
	assert_eq(GFVariantData.get_option_int(erase_report, "grid_size_after"), 2, "步骤报告应记录步骤后网格大小。")


func test_apply_to_grid_with_report_mutates_existing_grid() -> void:
	var candidates: Array[Vector2i] = GFGridGenerationPipeline2D.make_rect_candidates(Vector2i.ZERO, Vector2i(2, 1))
	var step: GFGridGenerationStep2D = GFGridGenerationStep2D.new()
	step.value = &"generated"
	var pipeline: GFGridGenerationPipeline2D = GFGridGenerationPipeline2D.new()
	pipeline.fill_default_value = true
	pipeline.default_value = &"empty"
	pipeline.add_step(step)
	var grid: Dictionary = {
		Vector2i(0, 0): &"existing",
		Vector2i(9, 9): &"outside",
	}

	var report: Dictionary = pipeline.apply_to_grid_with_report(grid, candidates)
	var reported_grid: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(report, "grid"))

	assert_eq(GFVariantData.get_option_int(report, "initial_grid_count"), 2, "报告应记录传入网格的初始大小。")
	assert_eq(GFVariantData.get_option_int(report, "default_filled_count"), 1, "已有候选格子不应被默认值覆盖。")
	assert_eq(GFVariantData.get_option_int(report, "final_grid_count"), 3, "报告应记录已有网格被原地扩展后的大小。")
	assert_eq(GFVariantData.get_option_string_name(grid, Vector2i(0, 0)), &"generated", "后续步骤仍可覆盖已有候选格子。")
	assert_eq(GFVariantData.get_option_string_name(grid, Vector2i(9, 9)), &"outside", "候选范围外的已有格子应保留。")
	assert_eq(reported_grid, grid, "报告中的 grid 应反映同一次原地应用结果。")
