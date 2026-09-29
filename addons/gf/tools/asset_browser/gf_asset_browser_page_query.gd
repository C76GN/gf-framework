@tool

# 单次默认字段分页查询。页面拥有帧调度与线程回收，任务独占纯数据评分线程。
extends RefCounted


# --- 私有变量 ---

var _owner: WeakRef = null
var _catalog: GFAssetCatalog = null
var _project_items: Callable = Callable()
var _request: Dictionary = {}
var _context: Dictionary = {}
var _filter: Dictionary = {}
var _ids: PackedStringArray = PackedStringArray()
var _listing_ids: PackedStringArray = PackedStringArray()
var _reports: Array[Dictionary] = []
var _candidates: Array[Dictionary] = []
var _items: Array[Dictionary] = []
var _page_ids: PackedStringArray = PackedStringArray()
var _result: Dictionary = {}
var _stage: StringName = &"unconfigured"
var _stage_usec: Dictionary = {}
var _cursor: int = 0
var _input_count: int = 0
var _total_count: int = 0
var _page: int = 1
var _page_count: int = 0
var _page_start: int = 0
var _page_end: int = 0
var _peak_step_usec: int = 0
var _peak_operation_usec: int = 0
var _last_step_items: int = 0
var _last_step_usec: int = 0
var _taken: bool = false
var _thread: Thread = null
var _worker_mutex: Mutex = Mutex.new()
var _worker_cancelled: bool = false
var _worker_phase: StringName = &"none"
var _worker_score_usec: int = 0
var _worker_sort_usec: int = 0
var _error: String = ""


# --- 框架内部方法 ---

## 配置单次查询；模型提供独立目录和有界摘要投影，页面拥有该任务。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param owner: 模型弱引用，用于每步核对目录和查询代次。
## [br]
## @param catalog: 模型持有的完整独立目录快照。
## [br]
## @param request: 已由模型规范化的查询请求。
## [br]
## @schema request: Dictionary with catalog_revision: int, query_generation: int, query: String, asset_ids: PackedStringArray, page: int, page_size: int and limit: int.
## [br]
## @param project_items: 模型提供的纯摘要编码函数，接收 Array 并返回 Array[Dictionary]。
func configure(owner: WeakRef, catalog: GFAssetCatalog, request: Dictionary, project_items: Callable) -> void:
	_owner = owner
	_catalog = catalog
	_request = request.duplicate(true)
	_project_items = project_items
	_stage = &"prepare"


## 在项目数和时间双预算内推进；一个不可分割的数据操作允许越过时间预算。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param max_items: 本次最多执行的数据操作数，限制在 1 到 256。
## [br]
## @param max_usec: 本次时间预算，限制在 1 到 16000 微秒。
## [br]
## @param allow_worker: 页面没有尚未回收的线程时才允许启动工作线程。
## [br]
## @return 已完成或已取消时为 true。
func step(max_items: int = 16, max_usec: int = 2000, allow_worker: bool = true) -> bool:
	if _stage in [&"done", &"cancelled", &"failed", &"unconfigured"]:
		return true
	if not _is_current():
		cancel()
		return true
	var started: int = Time.get_ticks_usec()
	var item_limit: int = clampi(max_items, 1, 256)
	var time_limit: int = clampi(max_usec, 1, 16000)
	_last_step_items = 0
	while _last_step_items < item_limit and _stage not in [&"done", &"cancelled", &"failed"]:
		if (_stage == &"worker_pending" and not allow_worker) or (_stage == &"worker" and _thread != null and _thread.is_alive()):
			break
		if _last_step_items > 0 and Time.get_ticks_usec() - started >= time_limit:
			break
		var stage: StringName = _stage
		var operation_started: int = Time.get_ticks_usec()
		_advance_one()
		var operation_usec: int = Time.get_ticks_usec() - operation_started
		_stage_usec[stage] = GFVariantData.get_option_int(_stage_usec, stage) + operation_usec
		_peak_operation_usec = maxi(_peak_operation_usec, operation_usec)
		_last_step_items += 1
		if not _is_current():
			cancel()
	_last_step_usec = Time.get_ticks_usec() - started
	_peak_step_usec = maxi(_peak_step_usec, _last_step_usec)
	return _stage in [&"done", &"cancelled", &"failed"]


## 立即取消发布并通知线程退出；拥有线程时，页面仍须调用 reap_worker 或 join_worker 完成回收。
## [br]
## @api framework_internal
## [br]
## @since unreleased
func cancel() -> void:
	_worker_mutex.lock()
	_worker_cancelled = true
	_worker_mutex.unlock()
	_stage = &"cancelled"
	_result.clear()
	_release_work()
	_owner = null
	_project_items = Callable()


## 检查任务是否仍拥有需要回收的线程，包括已经结束但尚未 join 的线程。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 尚需回收线程时为 true。
func has_worker() -> bool:
	return _thread != null


## 主线程非阻塞回收已结束的线程；活跃线程保留给页面下一帧继续回收。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 任务已不再拥有线程时为 true。
func reap_worker() -> bool:
	if _thread == null:
		return true
	if _thread.is_alive():
		return false
	_collect_worker_result()
	return true


## 在页面退树时取消并等待唯一线程结束；纯数据排序不可中断，可能等待其有限尾部。
## [br]
## @api framework_internal
## [br]
## @since unreleased
func join_worker() -> void:
	cancel()
	if _thread != null:
		_collect_worker_result()


## 一次性交还完整页面的所有权；未完成、已取消或代次过期时为空。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 与模型 get_page 相同形状的页面数据，不再由任务保留。
## [br]
## @schema return: Dictionary with catalog_revision, query_generation, query, page, page_size, page_count, total_count, has_previous, has_next, asset_ids and items, or an empty Dictionary.
func take_result() -> Dictionary:
	if _stage != &"done" or _taken or not _is_current():
		return {}
	_taken = true
	var result: Dictionary = _result
	_result = {}
	_owner = null
	_project_items = Callable()
	return result


## 获取纯数据进度和实际耗时，供界面与有界性能观察使用。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 不包含候选、资源或模型引用的进度副本。
## [br]
## @schema return: Dictionary with stage, scanned, input_count, matched_count, last_step_items, last_step_usec, peak_step_usec, peak_operation_usec, stage_usec, worker_owned: bool, worker_phase: StringName, worker_score_usec: int, worker_sort_usec: int and error: String.
func get_progress() -> Dictionary:
	_worker_mutex.lock()
	var worker_phase: StringName = _worker_phase
	_worker_mutex.unlock()
	return {
		"stage": _stage, "scanned": _cursor, "input_count": _input_count, "matched_count": _total_count,
		"last_step_items": _last_step_items, "last_step_usec": _last_step_usec,
		"peak_step_usec": _peak_step_usec, "peak_operation_usec": _peak_operation_usec,
		"stage_usec": _stage_usec.duplicate(),
		"worker_owned": has_worker(), "worker_phase": worker_phase,
		"worker_score_usec": _worker_score_usec, "worker_sort_usec": _worker_sort_usec, "error": _error,
	}


# --- 私有/辅助方法 ---

func _is_current() -> bool:
	if _owner == null:
		return false
	var owner_value: Variant = _owner.get_ref()
	if not owner_value is GFAssetBrowserModel:
		return false
	var model: GFAssetBrowserModel = owner_value
	return model.is_page_query_current(
		GFVariantData.get_option_int(_request, "catalog_revision"),
		GFVariantData.get_option_int(_request, "query_generation")
	)


func _advance_one() -> void:
	match _stage:
		&"prepare":
			for asset_id: String in GFVariantData.get_option_packed_string_array(_request, "asset_ids"):
				_filter[asset_id] = true
			if _filter.is_empty():
				_ids = _catalog.get_all_ids()
			else:
				for asset_id: String in _filter:
					var _appended: bool = _ids.append(asset_id)
				_ids.sort()
			_input_count = _ids.size()
			_context = GFAssetCatalog.make_default_search_context(GFVariantData.get_option_string(_request, "query"))
			_stage = &"candidates"
			if _filter.is_empty() and GFVariantData.get_option_string(_request, "query").strip_edges().is_empty():
				_listing_ids = _ids
				_cursor = _ids.size()
				_prepare_page()
		&"candidates":
			_advance_candidates()
		&"worker_pending":
			_start_worker()
		&"worker":
			var _reaped: bool = reap_worker()
		&"summary":
			_advance_summary()
		&"finish":
			_finish()


func _advance_candidates() -> void:
	if _cursor >= _ids.size():
		if not _candidates.is_empty():
			_stage = &"worker_pending"
		else:
			_prepare_page()
		return
	var asset_id: String = _ids[_cursor]
	_cursor += 1
	if not _catalog.has_entry(StringName(asset_id)):
		return
	if GFVariantData.get_option_string(_request, "query").strip_edges().is_empty():
		var _appended: bool = _listing_ids.append(asset_id)
	else:
		var candidate: Dictionary = _catalog.make_default_search_candidate(StringName(asset_id))
		_candidates.append(candidate)


func _start_worker() -> void:
	_thread = Thread.new()
	var error: Error = _thread.start(_run_worker.bind(_candidates, _context))
	if error != OK:
		_thread = null
		_error = "worker_start_failed: " + error_string(error)
		_stage = &"failed"
		_release_work()
		return
	# 将独占纯数据容器交给线程；主线程只通过 Mutex 访问取消与阶段标记。
	_candidates = []
	_context = {}
	_stage = &"worker"


func _run_worker(candidates: Array[Dictionary], context: Dictionary) -> Dictionary:
	_set_worker_phase(&"score")
	var started: int = Time.get_ticks_usec()
	var reports: Array[Dictionary] = []
	for index: int in range(candidates.size()):
		if _is_worker_cancelled():
			return { "cancelled": true }
		var report: Dictionary = GFTextSearchScorer.score_ranking_candidate(candidates[index], context, index)
		if GFVariantData.get_option_bool(report, "matched"):
			reports.append(report)
	var score_usec: int = Time.get_ticks_usec() - started
	if _is_worker_cancelled():
		return { "cancelled": true, "score_usec": score_usec }
	_set_worker_phase(&"sort")
	started = Time.get_ticks_usec()
	# 保持同步接口的排序实现和近似比较顺序，避免更换算法改变非传递比较的结果。
	GFTextSearchScorer.sort_ranking_reports(reports)
	var sort_usec: int = Time.get_ticks_usec() - started
	var cancelled: bool = _is_worker_cancelled()
	_set_worker_phase(&"finished")
	return { "reports": [] if cancelled else reports, "cancelled": cancelled, "score_usec": score_usec, "sort_usec": sort_usec }


func _collect_worker_result() -> void:
	var value: Variant = _thread.wait_to_finish()
	_thread = null
	_set_worker_phase(&"finished")
	if not value is Dictionary:
		_error = "worker_result_invalid"
		_stage = &"failed"
		return
	var result: Dictionary = value
	_worker_score_usec = GFVariantData.get_option_int(result, "score_usec")
	_worker_sort_usec = GFVariantData.get_option_int(result, "sort_usec")
	if _stage == &"cancelled" or GFVariantData.get_option_bool(result, "cancelled") or not _is_current():
		cancel()
		return
	var reports_value: Variant = result.get("reports")
	if reports_value is Array[Dictionary]:
		_reports = reports_value
		_prepare_page()
	else:
		_error = "worker_reports_invalid"
		_stage = &"failed"


func _is_worker_cancelled() -> bool:
	_worker_mutex.lock()
	var cancelled: bool = _worker_cancelled
	_worker_mutex.unlock()
	return cancelled


func _set_worker_phase(phase: StringName) -> void:
	_worker_mutex.lock()
	_worker_phase = phase
	_worker_mutex.unlock()


func _prepare_page() -> void:
	var listing: bool = GFVariantData.get_option_string(_request, "query").strip_edges().is_empty()
	_total_count = mini(_listing_ids.size() if listing else _reports.size(), GFVariantData.get_option_int(_request, "limit"))
	var page_size: int = GFVariantData.get_option_int(_request, "page_size")
	_page_count = ceili(float(_total_count) / float(page_size)) if _total_count > 0 else 0
	_page = clampi(GFVariantData.get_option_int(_request, "page"), 1, maxi(_page_count, 1))
	_page_start = (_page - 1) * page_size
	_page_end = mini(_page_start + page_size, _total_count)
	_stage = &"summary"


func _advance_summary() -> void:
	if _page_start >= _page_end:
		_stage = &"finish"
		return
	var asset_id: String = ""
	if GFVariantData.get_option_string(_request, "query").strip_edges().is_empty():
		asset_id = _listing_ids[_page_start]
	else:
		var candidate: Dictionary = GFVariantData.get_option_dictionary(_reports[_page_start], "candidate")
		asset_id = GFVariantData.get_option_string(candidate, "asset_id")
	var summary: Dictionary = _catalog.make_asset_summary(StringName(asset_id), { "include_metadata": true })
	var projected: Variant = _project_items.call([summary])
	if projected is Array:
		var projected_items: Array = projected
		if projected_items.size() == 1 and projected_items[0] is Dictionary:
			var item: Dictionary = projected_items[0]
			_items.append(item)
			var _appended: bool = _page_ids.append(asset_id)
			_page_start += 1
			return
	_error = "page_item_projection_invalid"
	_stage = &"failed"
	_release_work()


func _finish() -> void:
	_result = {
		"catalog_revision": GFVariantData.get_option_int(_request, "catalog_revision"),
		"query_generation": GFVariantData.get_option_int(_request, "query_generation"),
		"query": GFVariantData.get_option_string(_request, "query"),
		"page": _page, "page_size": GFVariantData.get_option_int(_request, "page_size"),
		"page_count": _page_count, "total_count": _total_count,
		"has_previous": _page > 1 and _total_count > 0, "has_next": _page < _page_count,
		"asset_ids": _page_ids, "items": _items,
	}
	_stage = &"done"
	_release_work()


func _release_work() -> void:
	_catalog = null
	_context.clear()
	_filter.clear()
	_ids.clear()
	_listing_ids.clear()
	_reports.clear()
	_candidates.clear()
	_items = []
	_page_ids = PackedStringArray()
