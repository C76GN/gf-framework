@tool

# 单次默认字段分页查询。页面拥有帧调度与线程回收，任务独占纯数据评分线程。
extends RefCounted


# --- 私有变量 ---

## 弱引用发起模型，用于核对目录修订和查询代次；此字段不持有模型强引用，取消或交付结果后断开。
## [br]
## @api private
var _owner: WeakRef = null

## 主线程构建候选与页摘要所用的模型目录引用；工作线程不访问它，完成或取消后释放此引用。
## [br]
## @api private
var _catalog: GFAssetCatalog = null

## 将单个目录摘要投影为页面条目的主线程回调；取消或交付后清除，不再保留已结束任务的投影入口。
## [br]
## @api private
var _project_items: Callable = Callable()

## 配置时深复制的请求快照，保存过滤、分页参数及判定结果仍有效的两个版本号。
## [br]
## @api private
var _request: Dictionary = {}

## 默认搜索的纯数据上下文；启动线程时转交原容器并替换本字段，避免主线程清理线程输入。
## [br]
## @api private
var _context: Dictionary = {}

## 请求资产 ID 的去重集合；空集合表示枚举整个目录，准备阶段据此构造有序输入。
## [br]
## @api private
var _filter: Dictionary = {}

## 本次待检查的资产 ID 序列；过滤请求会先排序，游标按此序列逐项构建候选。
## [br]
## @api private
var _ids: PackedStringArray = PackedStringArray()

## 空搜索词的目录浏览顺序，绕过评分线程；摘要阶段按分页区间读取。
## [br]
## @api private
var _listing_ids: PackedStringArray = PackedStringArray()

## 回收线程后接收的已排序匹配报告，仅主线程用其选取当前页，交付结果前清空。
## [br]
## @api private
var _reports: Array[Dictionary] = []

## 主线程逐项生成的纯数据评分候选；启动线程时移交原数组，本字段换成新数组。
## [br]
## @api private
var _candidates: Array[Dictionary] = []

## 当前页已成功投影的条目；完成时直接装入结果，清理工作区须换新数组而非清空结果所持容器。
## [br]
## @api private
var _items: Array[Dictionary] = []

## 与已投影页面条目同序的资产 ID；仅成功投影后追加，完成时随结果交付。
## [br]
## @api private
var _page_ids: PackedStringArray = PackedStringArray()

## 完成后的单次交付报告；take_result 转移容器并置空，取消则丢弃尚未交付的结果。
## [br]
## @api private
var _result: Dictionary = {}

## 主线程分帧状态机阶段；done、failed、cancelled 为终态，worker 阶段等待线程回收。
## [br]
## @api private
var _stage: StringName = &"unconfigured"

## 按推进前的阶段累计主线程操作耗时；线程评分与排序时间另记，不计入此表。
## [br]
## @api private
var _stage_usec: Dictionary = {}

## 已消费的输入 ID 数，也是候选构建的下一位置；页摘要另用页内起点推进。
## [br]
## @api private
var _cursor: int = 0

## 准备阶段确定的输入 ID 总数，用于进度报告，可能包含后来因目录无条目而跳过的 ID。
## [br]
## @api private
var _input_count: int = 0

## 应用请求 limit 后的可分页结果总数，不等同于当前页成功投影条目数。
## [br]
## @api private
var _total_count: int = 0

## 按实际页数夹取后的结果页号；无结果时仍使用第一页。
## [br]
## @api private
var _page: int = 1

## 由截断后结果数和请求页大小计算的页数；无结果时为零。
## [br]
## @api private
var _page_count: int = 0

## 下一条待投影结果的绝对下标，从当前页起点开始，仅在投影成功后递增。
## [br]
## @api private
var _page_start: int = 0

## 当前页结果区间的排他上界；起点到达此处后进入结果装配阶段。
## [br]
## @api private
var _page_end: int = 0

## 所有已执行 step 的最大主线程耗时，供页面诊断帧预算超出情况。
## [br]
## @api private
var _peak_step_usec: int = 0

## 单次阶段推进的最大耗时；预算只在操作之间检查，因此单项操作可能超过帧预算。
## [br]
## @api private
var _peak_operation_usec: int = 0

## 最近一次实际执行 step 的阶段推进次数，包含状态切换，并非严格的资产处理数。
## [br]
## @api private
var _last_step_items: int = 0

## 最近一次实际执行 step 的主线程耗时；终态直接返回时保留上次测量值。
## [br]
## @api private
var _last_step_usec: int = 0

## 成功取走结果后的单次交付锁；此任务不支持重新配置后复用。
## [br]
## @api private
var _taken: bool = false

## 任务独占的评分线程；非空也可能表示已结束但未回收，宿主必须持有任务直到 wait_to_finish 完成。
## [br]
## @api private
var _thread: Thread = null

## 仅保护跨线程取消标记和诊断阶段；候选、上下文及报告通过独占移交避免并发访问。
## [br]
## @api private
var _worker_mutex: Mutex = Mutex.new()

## 协作取消标记；评分逐项检查，排序只能在开始前与完成后检查，置位本身不会等待线程。
## [br]
## @api private
var _worker_cancelled: bool = false

## Mutex 保护的工作线程诊断阶段，主线程可读取进度，但不以此代替线程存活检查。
## [br]
## @api private
var _worker_phase: StringName = &"none"

## 线程回收时读取的评分耗时；在评分中途取消、结果未带计时时保持零。
## [br]
## @api private
var _worker_score_usec: int = 0

## 线程回收时读取的排序耗时；未进入排序的取消结果不提供该耗时。
## [br]
## @api private
var _worker_sort_usec: int = 0

## 最近的线程启动、结果形状或页面投影失败原因，随进度返回给宿主诊断。
## [br]
## @api private
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

## 同时核对弱引用模型仍存活、目录修订及查询代次，防止旧任务向已经变化的页面交付结果。
## [br]
## @api private
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


## 在主线程推进一次准备、候选、线程回收或摘要操作；空查询可直接采用目录顺序，跳过评分线程。
## [br]
## @api private
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


## 消费一个输入 ID，跳过目录中不存在的条目；空查询只记录浏览顺序，非空查询积累纯数据候选。
## [br]
## @api private
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


## 启动任务独占评分线程并移交候选和上下文原容器；启动失败则进入失败终态并释放主线程工作区。
## [br]
## @api private
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


## 在线程独占的纯数据上评分并保持同步查询的排序算法；逐项评分可取消，排序期间只能等待其完成。
## 完成报告交由主线程回收，不访问模型、目录或编辑器对象。
## [br]
## @api private
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


## 等待并回收现存线程，读取计时后再次核对取消和请求版本；仅有效的报告可继续分页。
## 常规逐帧回收先确认线程结束，退树 join 路径则允许此处等待尚未完成的排序。
## [br]
## @api private
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


## 在 Mutex 下读取协作取消标记，供工作线程的评分与排序边界使用。
## [br]
## @api private
func _is_worker_cancelled() -> bool:
	_worker_mutex.lock()
	var cancelled: bool = _worker_cancelled
	_worker_mutex.unlock()
	return cancelled


## 在 Mutex 下更新可供主线程轮询的诊断阶段；此标记不承担任务完成或线程回收的判定。
## [br]
## @api private
func _set_worker_phase(phase: StringName) -> void:
	_worker_mutex.lock()
	_worker_phase = phase
	_worker_mutex.unlock()


## 对浏览列表或已排序匹配结果先应用 limit，再夹取页号并设置摘要区间；请求页大小由模型预先规范化。
## [br]
## @api private
func _prepare_page() -> void:
	var listing: bool = GFVariantData.get_option_string(_request, "query").strip_edges().is_empty()
	_total_count = mini(_listing_ids.size() if listing else _reports.size(), GFVariantData.get_option_int(_request, "limit"))
	var page_size: int = GFVariantData.get_option_int(_request, "page_size")
	_page_count = ceili(float(_total_count) / float(page_size)) if _total_count > 0 else 0
	_page = clampi(GFVariantData.get_option_int(_request, "page"), 1, maxi(_page_count, 1))
	_page_start = (_page - 1) * page_size
	_page_end = mini(_page_start + page_size, _total_count)
	_stage = &"summary"


## 在主线程投影一个当前页摘要；回调必须返回恰好一个字典，否则整项查询失败并释放工作区。
## [br]
## @api private
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


## 将页条目及请求版本装配为单次交付报告，再释放中间数据；结果的实际交付仍须通过 take_result 版本检查。
## [br]
## @api private
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


## 释放主线程目录和中间容器；对可能已被结果持有的页条目换新容器，不清空已移交的结果，也不回收线程。
## [br]
## @api private
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
