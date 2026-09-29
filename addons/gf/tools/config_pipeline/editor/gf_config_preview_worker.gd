# 后台只读取与解析冻结的纯值来源描述；不触碰编辑器、共享 Resource 或文件提交。
extends RefCounted


# --- 私有变量 ---

var _mutex: Mutex = Mutex.new()
var _cancelled: bool = false


# --- 框架内部方法 ---

## 请求取消；在有界读取/解析阶段边界生效，不能中断正在执行的解析器。
## [br]
## @api framework_internal
func cancel() -> void:
	_mutex.lock()
	_cancelled = true
	_mutex.unlock()


## 读取预览，返回至多 100 条原始记录和来源收据。
## [br]
## @api framework_internal
## [br]
## @param request: 独立来源快照。
## [br]
## @schema request: Dictionary，单源包含 generation、source_path、table_name、source_format、parse_options；批量预检包含 generation、sources，每个来源使用同一纯值结构。
## [br]
## @return: 布局结果及取消、代次、计时。
## [br]
## @schema return: Dictionary，单源包含 success、cancelled、generation、data、record_count、cell_count、source_receipt、read_msec、layout_msec；批量预检返回 success、generation、cell_count、receipts 或 error。
func run_request(request: Dictionary) -> Dictionary:
	if request.has("sources"):
		return _inspect_batch(request)
	var generation: int = GFVariantData.get_option_int(request, "generation")
	if _is_cancelled():
		return { "cancelled": true, "generation": generation }
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.source_path = GFVariantData.get_option_string(request, "source_path")
	source.table_name = GFVariantData.get_option_string_name(request, "table_name")
	source.source_format = GFVariantData.get_option_string_name(request, "source_format", &"auto")
	source.parse_options = GFVariantData.get_option_dictionary(request, "parse_options").duplicate(true)
	var start: int = Time.get_ticks_usec()
	var read_result: Dictionary = GFConfigPipelineReaderStage.new().read_source(source, { "max_source_file_bytes": 2 * 1024 * 1024, "max_xlsx_file_bytes": 2 * 1024 * 1024 })
	var read_msec: float = float(Time.get_ticks_usec() - start) / 1000.0
	if _is_cancelled():
		return { "cancelled": true, "generation": generation }
	start = Time.get_ticks_usec()
	var result: Dictionary = GFConfigPipelineLayoutStage.new().decode_source(source, read_result)
	result["read_msec"] = read_msec
	result["layout_msec"] = float(Time.get_ticks_usec() - start) / 1000.0
	result["generation"] = generation
	result["cancelled"] = _is_cancelled()
	var data: Variant = result.get("data")
	var records: Array = GFVariantData.as_array(data)
	if data is Dictionary:
		var keyed_records: Dictionary = data
		records = keyed_records.values()
	result["record_count"] = records.size()
	var cells: int = 0
	for record: Variant in records:
		if record is Dictionary:
			var row: Dictionary = record
			cells += row.size()
	result["cell_count"] = cells
	result["data"] = records.slice(0, 100)
	result["row_locations"] = GFVariantData.get_option_array(result, "row_locations").slice(0, 100)
	return result


# --- 私有/辅助方法 ---

func _inspect_batch(request: Dictionary) -> Dictionary:
	var total_cells: int = 0
	var receipts: Dictionary = {}
	for value: Variant in GFVariantData.get_option_array(request, "sources"):
		var source: Dictionary = GFVariantData.as_dictionary(value)
		source["generation"] = GFVariantData.get_option_int(request, "generation")
		var result: Dictionary = run_request(source)
		if _is_cancelled() or not GFVariantData.get_option_bool(result, "success"):
			return result
		total_cells += GFVariantData.get_option_int(result, "cell_count")
		if total_cells > 4000:
			return { "success": false, "generation": request["generation"], "error": "同步校验/提交上限为 4,000 个单元格；当前至少 %d。请复制等价 CLI，在独立终端按实际任务调整 --max-validation-cells 后执行。" % total_cells }
		receipts[GFVariantData.get_option_string(source, "source_path")] = GFVariantData.get_option_dictionary(result, "source_receipt")
	return { "success": true, "generation": request["generation"], "cell_count": total_cells, "receipts": receipts }


func _is_cancelled() -> bool:
	_mutex.lock()
	var result: bool = _cancelled
	_mutex.unlock()
	return result
