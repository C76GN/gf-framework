@tool

## GFAssetBrowserModel: 资产浏览器的无界面状态模型。
##
## 持有隔离的 GFAssetCatalog 快照、查询代际和稳定 ID 选择，供项目编辑器
## 页面自行决定布局、来源注入和资源物化策略。本模型不扫描目录、不下载、
## 不导入资源，也不拥有 provider 或缓存。
## [br]
## catalog、query、selection 与 preview 通知共用非重入 FIFO 队列。同步
## listener 触发的嵌套 mutation 只会排到队尾；当前 signal 的全部 listener
## 返回后才按提交顺序继续发布冻结参数。dispose() 会丢弃尚未派发的队尾通知。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 11.0.0
class_name GFAssetBrowserModel
extends RefCounted


# --- 信号 ---

## 隔离目录成功替换后发出。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param catalog_revision: 新目录 revision。
## [br]
## @param query_generation: 新查询 generation。
signal catalog_changed(catalog_revision: int, query_generation: int)

## 查询条件实际变化后发出。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param query_generation: 新查询 generation。
signal query_changed(query_generation: int)

## 稳定资产选择实际变化后发出。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param asset_id: 新选择；空 ID 表示没有选择。
signal selection_changed(asset_id: StringName)

## 当前代际的预览任务进入终态后发出。
##
## 被目录、查询或新预览代际淘汰的旧任务不会发布结果。报告与预览计划的
## Dictionary / Array 容器只读；Image / ImageTexture 等引擎对象句柄仍由
## listener 按只读引用使用。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param report: 预览终态报告。
## [br]
## @schema report: 闭合 Dictionary，精确包含 asset_id: StringName、preview_generation: int、catalog_revision: int、query_generation: int、state: StringName、result、error: String 和 cancel_reason: StringName。result 只能是 null、Image、ImageTexture，或精确包含 ok: true、generated_count: 非负 int、cancelled: bool、changes: Array 的 MeshLibrary plan；generated_count 必须等于 changes 数量且最多为 MAX_RESULT_COUNT，每个 change 精确包含非负 item_id: int、可空 old_preview: Texture2D 和非空 new_preview: Texture2D。所有 Dictionary / Array 容器只读；Image / Texture2D 是无法冻结的 Engine Object 句柄，listener 必须按只读引用使用。
signal preview_resolved(report: Dictionary)


# --- 常量 ---

## 单个模型快照允许的最大资产数。
## [br]
## @api public
## [br]
## @since 11.0.0
const MAX_CATALOG_ENTRIES: int = 10_000

## 查询文本允许的最大字符数。
## [br]
## @api public
## [br]
## @since 11.0.0
const MAX_QUERY_LENGTH: int = 512

## 单页允许返回的最大资产数。
## [br]
## @api public
## [br]
## @since 11.0.0
const MAX_PAGE_SIZE: int = 100

## 一次查询允许保留的最大匹配资产数。
## [br]
## @api public
## [br]
## @since 11.0.0
const MAX_RESULT_COUNT: int = 10_000

const _MAX_FILTER_ASSET_IDS: int = 10_000
const _MAX_ASSET_ID_LENGTH: int = 512
const _MAX_CATALOG_VALUE_NODES: int = 1_000_000
const _MAX_CATALOG_METADATA_DEPTH: int = 16
const _MAX_CATALOG_COLLECTION_ITEMS: int = 4096
const _MAX_CATALOG_TEXT_LENGTH: int = 8192
const _MAX_CATALOG_TEXT_BYTES: int = 16 * 1024 * 1024
const _MAX_SUMMARY_BYTES: int = 32 * 1024
const _MAX_SUMMARY_NODES: int = 512
const _MAX_SUMMARY_COLLECTION_ITEMS: int = 128
const _MAX_SUMMARY_STRING_LENGTH: int = 4096
const _PREVIEW_PLAN_KEY_COUNT: int = 4
const _PREVIEW_PLAN_CHANGE_KEY_COUNT: int = 3
const _NOTIFICATION_CATALOG_CHANGED: StringName = &"catalog_changed"
const _NOTIFICATION_QUERY_CHANGED: StringName = &"query_changed"
const _NOTIFICATION_SELECTION_CHANGED: StringName = &"selection_changed"
const _NOTIFICATION_PREVIEW_RESOLVED: StringName = &"preview_resolved"


# --- 私有变量 ---

var _catalog: GFAssetCatalog = GFAssetCatalog.new()
var _catalog_revision: int = 0
var _query_generation: int = 0
var _query_text: String = ""
var _query_asset_ids: PackedStringArray = PackedStringArray()
var _selected_asset_id: StringName = &""
var _preview_generation: int = 0
var _active_preview_task: GFThumbnailRenderTask = null
var _active_preview_asset_id: StringName = &""
var _active_preview_catalog_revision: int = 0
var _active_preview_query_generation: int = 0
var _disposed: bool = false
var _pending_notifications: Array[Dictionary] = []
var _notification_dispatch_in_progress: bool = false


# --- 公共方法 ---

## 用隔离副本替换当前目录。
##
## 超过 MAX_CATALOG_ENTRIES 的目录会整体拒绝，不会静默截断。成功替换会
## 推进目录 revision 和查询 generation；已经不存在的选择会被清除。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param catalog: 要复制的资产目录。
## [br]
## @return: 替换报告。
## [br]
## @schema return: Dictionary with ok, changed, error, asset_count, catalog_revision, and query_generation.
func replace_catalog(catalog: GFAssetCatalog) -> Dictionary:
	var report: Dictionary = {
		"ok": false,
		"changed": false,
		"error": "invalid_catalog",
		"asset_count": 0,
		"catalog_revision": _catalog_revision,
		"query_generation": _query_generation,
	}
	if _disposed:
		report["error"] = "disposed"
		return report
	if catalog == null:
		return report
	report["asset_count"] = catalog.entries.size()
	var snapshot_report: Dictionary = _make_isolated_catalog_snapshot(catalog)
	if not _read_bool(snapshot_report, "ok"):
		var snapshot_error: Variant = snapshot_report.get("error", "invalid_catalog")
		if snapshot_error is String:
			report["error"] = snapshot_error
		return report
	var candidate_value: Variant = snapshot_report.get("catalog")
	if not candidate_value is GFAssetCatalog:
		return report
	var candidate_catalog: GFAssetCatalog = candidate_value

	_invalidate_active_preview(&"catalog_replaced")
	_catalog = candidate_catalog
	_catalog_revision += 1
	_query_generation += 1
	var previous_selection: StringName = _selected_asset_id
	if _selected_asset_id != &"" and not _catalog.has_entry(_selected_asset_id):
		_selected_asset_id = &""
	report["ok"] = true
	report["changed"] = true
	report["error"] = ""
	report["catalog_revision"] = _catalog_revision
	report["query_generation"] = _query_generation
	var notifications: Array[Dictionary] = [
		_make_notification(_NOTIFICATION_CATALOG_CHANGED, {
			"catalog_revision": _catalog_revision,
			"query_generation": _query_generation,
		}),
	]
	if previous_selection != _selected_asset_id:
		notifications.append(_make_notification(_NOTIFICATION_SELECTION_CHANGED, {
			"asset_id": _selected_asset_id,
		}))
	_publish_notifications(notifications)
	return report


## 选择当前目录中的稳定资产 ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param asset_id: 要选择的资产 ID；空 ID 用于清除选择。
## [br]
## @return: 选择请求有效时返回 true。
func select_asset(asset_id: StringName) -> bool:
	if _disposed:
		return false
	if asset_id == &"":
		if _selected_asset_id == &"":
			return true
		_selected_asset_id = &""
		_publish_notification(_make_notification(_NOTIFICATION_SELECTION_CHANGED, {
			"asset_id": _selected_asset_id,
		}))
		return true
	if not _catalog.has_entry(asset_id):
		return false
	if _selected_asset_id == asset_id:
		return true
	_selected_asset_id = asset_id
	_publish_notification(_make_notification(_NOTIFICATION_SELECTION_CHANGED, {
		"asset_id": _selected_asset_id,
	}))
	return true


## 设置浏览查询和可选资产 ID 闭集。
##
## 资产 ID 会去重并排序。超长查询、超量过滤 ID 或超长 ID 会整体拒绝，
## 被拒绝的输入不会推进 generation。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param query_text: 交给 GFAssetCatalog 的文本查询。
## [br]
## @param asset_ids: 可选查询闭集；为空时查询整个目录。
## [br]
## @return: 查询更新报告。
## [br]
## @schema return: Dictionary with ok, changed, error, query_generation, query, and filter_count.
func set_query(
	query_text: String,
	asset_ids: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var report: Dictionary = {
		"ok": false,
		"changed": false,
		"error": "",
		"query_generation": _query_generation,
		"query": _query_text,
		"filter_count": _query_asset_ids.size(),
	}
	if _disposed:
		report["error"] = "disposed"
		return report
	if query_text.length() > MAX_QUERY_LENGTH:
		report["error"] = "query_too_long"
		return report
	if asset_ids.size() > _MAX_FILTER_ASSET_IDS:
		report["error"] = "filter_limit_exceeded"
		return report
	if not _are_asset_ids_valid(asset_ids):
		report["error"] = "invalid_asset_id"
		return report
	var normalized_ids: PackedStringArray = _normalize_asset_ids(asset_ids)
	if _query_text == query_text and _query_asset_ids == normalized_ids:
		report["ok"] = true
		return report

	_invalidate_active_preview(&"query_changed")
	_query_text = query_text
	_query_asset_ids = normalized_ids
	_query_generation += 1
	report["ok"] = true
	report["changed"] = true
	report["query_generation"] = _query_generation
	report["query"] = _query_text
	report["filter_count"] = _query_asset_ids.size()
	_publish_notification(_make_notification(_NOTIFICATION_QUERY_CHANGED, {
		"query_generation": _query_generation,
	}))
	return report


## 获取当前选择的稳定资产 ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 当前选择；没有选择时返回空 StringName。
func get_selected_asset_id() -> StringName:
	return _selected_asset_id


## 获取当前目录 revision。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 从 0 开始、成功替换后递增的 revision。
func get_catalog_revision() -> int:
	return _catalog_revision


## 获取当前查询 generation。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 从 0 开始、目录或查询变化后递增的 generation。
func get_query_generation() -> int:
	return _query_generation


## 提交与目录资产关联的缩略图请求。
##
## 调用方负责把资产物化为 GFThumbnailRenderRequest；模型只校验稳定 ID，
## 并通过 GFThumbnailRenderer 管理一个当前代际任务。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param asset_id: 当前目录中的稳定资产 ID。
## [br]
## @param renderer: 执行请求的缩略图渲染器。
## [br]
## @param request: 已由调用方构建的渲染请求。
## [br]
## @return: 当前代际任务；输入无效时返回 null。
func request_preview(
	asset_id: StringName,
	renderer: GFThumbnailRenderer,
	request: GFThumbnailRenderRequest
) -> GFThumbnailRenderTask:
	if (
		_disposed
		or asset_id == &""
		or not _catalog.has_entry(asset_id)
		or renderer == null
		or not is_instance_valid(renderer)
		or request == null
		or not request.is_valid()
	):
		return null

	_preview_generation += 1
	_cancel_active_preview(&"superseded")
	var task: GFThumbnailRenderTask = renderer.submit_render_request(request)
	_active_preview_task = task
	_active_preview_asset_id = asset_id
	_active_preview_catalog_revision = _catalog_revision
	_active_preview_query_generation = _query_generation
	var completion_callback: Callable = _on_preview_task_completed.bind(
		asset_id,
		_preview_generation,
		_catalog_revision,
		_query_generation
	)
	if task.is_finished():
		_resolve_preview_task(
			task,
			asset_id,
			_preview_generation,
			_catalog_revision,
			_query_generation
		)
		return task
	var connected: Error = task.completed.connect(
		completion_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if connected != OK:
		_cancel_active_preview(&"completion_connect_failed")
		return null
	if task.is_finished():
		if task.completed.is_connected(completion_callback):
			task.completed.disconnect(completion_callback)
		_resolve_preview_task(
			task,
			asset_id,
			_preview_generation,
			_catalog_revision,
			_query_generation
		)
	return task


## 取消当前预览任务。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param reason: 取消原因。
## [br]
## @return: 本次调用是否发出新的取消请求。
func cancel_preview(reason: StringName = &"cancelled") -> bool:
	if _disposed or _active_preview_task == null:
		return false
	return _active_preview_task.cancel(reason)


## 获取预览请求的当前代际。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 从 0 开始、新预览或主动失效时递增的 generation。
func get_preview_generation() -> int:
	return _preview_generation


## 获取当前仍未完成的预览任务。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 当前任务；没有任务时返回 null。
func get_active_preview_task() -> GFThumbnailRenderTask:
	return _active_preview_task


## 释放模型持有的预览任务。
##
## dispose() 是终态操作；调用后目录、查询、选择和预览写入口均会拒绝新请求。
## [br]
## @api public
## [br]
## @since 11.0.0
func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	_pending_notifications.clear()
	_invalidate_active_preview(&"disposed")


## 获取当前目录的分页摘要。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param page: 从 1 开始的页码。
## [br]
## @param page_size: 每页数量。
## [br]
## @return: 分页浏览报告。
## [br]
## @schema return: Dictionary with catalog_revision, query_generation, query, page, page_size, page_count, total_count, has_previous, has_next, asset_ids, and items.
func get_page(page: int = 1, page_size: int = 50) -> Dictionary:
	var bounded_page_size: int = clampi(page_size, 1, MAX_PAGE_SIZE)
	var catalog_page: Dictionary = _catalog.search_page(_query_text, page, bounded_page_size, {
		"asset_ids": _query_asset_ids,
		"limit": MAX_RESULT_COUNT,
		"include_summaries": true,
		"summary_options": { "include_metadata": true },
	})
	return {
		"catalog_revision": _catalog_revision,
		"query_generation": _query_generation,
		"query": _query_text,
		"page": _read_int(catalog_page, "page", 1),
		"page_size": _read_int(catalog_page, "page_size", bounded_page_size),
		"page_count": _read_int(catalog_page, "page_count"),
		"total_count": _read_int(catalog_page, "total_count"),
		"has_previous": _read_bool(catalog_page, "has_previous"),
		"has_next": _read_bool(catalog_page, "has_next"),
		"asset_ids": _read_packed_string_array(catalog_page, "asset_ids"),
		"items": _make_page_items(_read_array(catalog_page, "summaries")),
	}


# --- 私有/辅助方法 ---

static func _make_notification(
	notification_type: StringName,
	payload: Dictionary
) -> Dictionary:
	var event_record: Dictionary = payload
	event_record["type"] = notification_type
	event_record.make_read_only()
	return event_record


func _publish_notification(event_record: Dictionary) -> void:
	var notifications: Array[Dictionary] = [event_record]
	_publish_notifications(notifications)


func _publish_notifications(notifications: Array[Dictionary]) -> void:
	if _disposed or notifications.is_empty():
		return
	_pending_notifications.append_array(notifications)
	if _notification_dispatch_in_progress:
		return
	_notification_dispatch_in_progress = true
	var notification_index: int = 0
	while notification_index < _pending_notifications.size() and not _disposed:
		var event_record: Dictionary = _pending_notifications[notification_index]
		notification_index += 1
		_dispatch_notification(event_record)
	_pending_notifications.clear()
	_notification_dispatch_in_progress = false


func _dispatch_notification(event_record: Dictionary) -> void:
	var type_value: Variant = event_record.get("type", &"")
	if not type_value is StringName:
		return
	var notification_type: StringName = type_value
	match notification_type:
		_NOTIFICATION_CATALOG_CHANGED:
			catalog_changed.emit(
				_read_int(event_record, "catalog_revision"),
				_read_int(event_record, "query_generation")
			)
		_NOTIFICATION_QUERY_CHANGED:
			query_changed.emit(_read_int(event_record, "query_generation"))
		_NOTIFICATION_SELECTION_CHANGED:
			var asset_id_value: Variant = event_record.get("asset_id", &"")
			if asset_id_value is StringName:
				var asset_id: StringName = asset_id_value
				selection_changed.emit(asset_id)
		_NOTIFICATION_PREVIEW_RESOLVED:
			var report_value: Variant = event_record.get("report", {})
			if report_value is Dictionary:
				var report: Dictionary = report_value
				preview_resolved.emit(report)

static func _make_isolated_catalog_snapshot(catalog: GFAssetCatalog) -> Dictionary:
	if catalog.entries.size() > MAX_CATALOG_ENTRIES:
		return {
			"ok": false,
			"error": "catalog_entry_limit_exceeded",
		}
	var state: Dictionary = {
		"value_count": 0,
		"text_bytes": 0,
	}
	var asset_id_lookup: Dictionary = {}
	var validated_entries: Array[GFAssetCatalogEntry] = []
	for entry: GFAssetCatalogEntry in catalog.entries:
		var validation_error: String = _validate_catalog_entry(
			entry,
			state,
			asset_id_lookup
		)
		if not validation_error.is_empty():
			return {
				"ok": false,
				"error": validation_error,
			}
		validated_entries.append(entry)

	var candidate_catalog: GFAssetCatalog = GFAssetCatalog.new()
	for entry: GFAssetCatalogEntry in validated_entries:
		candidate_catalog.entries.append(_copy_catalog_entry(entry))
	candidate_catalog.mark_index_dirty()
	candidate_catalog.rebuild_index()
	return {
		"ok": true,
		"error": "",
		"catalog": candidate_catalog,
	}


static func _validate_catalog_entry(
	entry: GFAssetCatalogEntry,
	state: Dictionary,
	asset_id_lookup: Dictionary
) -> String:
	if entry == null:
		return "invalid_catalog_entry"
	var asset_id_text: String = String(entry.asset_id)
	if (
		asset_id_text.is_empty()
		or asset_id_text != asset_id_text.strip_edges()
		or asset_id_text.length() > _MAX_ASSET_ID_LENGTH
	):
		return "invalid_catalog_asset_id"
	if asset_id_lookup.has(asset_id_text):
		return "duplicate_catalog_asset_id"
	asset_id_lookup[asset_id_text] = true

	var entry_texts: Array[String] = [
		asset_id_text,
		entry.title,
		entry.description,
		String(entry.category),
		entry.primary_path,
		entry.type_hint,
		entry.preview_path,
		String(entry.source_id),
	]
	for text_value: String in entry_texts:
		var text_error: String = _reserve_catalog_text(
			text_value,
			state,
			"catalog_entry"
		)
		if not text_error.is_empty():
			return text_error
	var tags_error: String = _validate_catalog_text_array(entry.tags, state)
	if not tags_error.is_empty():
		return tags_error
	var resource_ids_error: String = _validate_catalog_text_array(
		entry.resource_entry_ids,
		state
	)
	if not resource_ids_error.is_empty():
		return resource_ids_error
	return _validate_catalog_metadata_value(entry.metadata, state, [], 0)


static func _validate_catalog_text_array(
	values: PackedStringArray,
	state: Dictionary
) -> String:
	if values.size() > _MAX_CATALOG_COLLECTION_ITEMS:
		return "catalog_entry_collection_limit_exceeded"
	for text_value: String in values:
		var error: String = _reserve_catalog_text(
			text_value,
			state,
			"catalog_entry"
		)
		if not error.is_empty():
			return error
	return ""


static func _validate_catalog_metadata_value(
	value: Variant,
	state: Dictionary,
	active_references: Array,
	depth: int
) -> String:
	if depth > _MAX_CATALOG_METADATA_DEPTH:
		return "catalog_metadata_depth_limit_exceeded"
	if value is Array or value is Dictionary:
		if _find_catalog_active_reference(active_references, value) >= 0:
			return "catalog_metadata_cycle"
	var count_error: String = _consume_catalog_value_node(state, "catalog_metadata")
	if not count_error.is_empty():
		return count_error

	match typeof(value):
		TYPE_STRING:
			var string_value: String = value
			return _reserve_catalog_text(string_value, state, "catalog_metadata", false)
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return _reserve_catalog_text(str(value), state, "catalog_metadata", false)
		TYPE_ARRAY:
			var array_value: Array = value
			if array_value.size() > _MAX_CATALOG_COLLECTION_ITEMS:
				return "catalog_metadata_collection_limit_exceeded"
			active_references.append(array_value)
			for item: Variant in array_value:
				var item_error: String = _validate_catalog_metadata_value(
					item,
					state,
					active_references,
					depth + 1
				)
				if not item_error.is_empty():
					var _removed_array_reference_on_error: Variant = active_references.pop_back()
					return item_error
			var _removed_array_reference: Variant = active_references.pop_back()
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			if dictionary_value.size() > _MAX_CATALOG_COLLECTION_ITEMS:
				return "catalog_metadata_collection_limit_exceeded"
			active_references.append(dictionary_value)
			for key: Variant in dictionary_value:
				var key_error: String = _validate_catalog_metadata_value(
					key,
					state,
					active_references,
					depth + 1
				)
				if not key_error.is_empty():
					var _removed_dictionary_reference_on_key_error: Variant = active_references.pop_back()
					return key_error
				var item_error: String = _validate_catalog_metadata_value(
					dictionary_value[key],
					state,
					active_references,
					depth + 1
				)
				if not item_error.is_empty():
					var _removed_dictionary_reference_on_value_error: Variant = active_references.pop_back()
					return item_error
			var _removed_dictionary_reference: Variant = active_references.pop_back()
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, \
		TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			var packed_size: int = len(value)
			if packed_size > _MAX_CATALOG_COLLECTION_ITEMS:
				return "catalog_metadata_collection_limit_exceeded"
			return _consume_catalog_value_nodes(state, packed_size, "catalog_metadata")
		TYPE_PACKED_STRING_ARRAY:
			var packed_strings: PackedStringArray = value
			if packed_strings.size() > _MAX_CATALOG_COLLECTION_ITEMS:
				return "catalog_metadata_collection_limit_exceeded"
			for text_value: String in packed_strings:
				var text_error: String = _reserve_catalog_text(
					text_value,
					state,
					"catalog_metadata"
				)
				if not text_error.is_empty():
					return text_error
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return "catalog_metadata_unsupported_value"
	return ""


static func _reserve_catalog_text(
	value: String,
	state: Dictionary,
	prefix: String,
	consume_node: bool = true
) -> String:
	if consume_node:
		var count_error: String = _consume_catalog_value_node(state, prefix)
		if not count_error.is_empty():
			return count_error
	if value.length() > _MAX_CATALOG_TEXT_LENGTH:
		return "%s_text_limit_exceeded" % prefix
	var value_bytes: int = value.to_utf8_buffer().size()
	var consumed_bytes: int = _read_int(state, "text_bytes")
	if value_bytes > _MAX_CATALOG_TEXT_BYTES - consumed_bytes:
		return "%s_byte_limit_exceeded" % prefix
	state["text_bytes"] = consumed_bytes + value_bytes
	return ""


static func _consume_catalog_value_node(state: Dictionary, prefix: String) -> String:
	return _consume_catalog_value_nodes(state, 1, prefix)


static func _consume_catalog_value_nodes(
	state: Dictionary,
	count: int,
	prefix: String
) -> String:
	var consumed_count: int = _read_int(state, "value_count")
	if count > _MAX_CATALOG_VALUE_NODES - consumed_count:
		return "%s_value_limit_exceeded" % prefix
	state["value_count"] = consumed_count + count
	return ""


static func _find_catalog_active_reference(references: Array, value: Variant) -> int:
	for index: int in range(references.size()):
		if is_same(references[index], value):
			return index
	return -1


static func _copy_catalog_entry(source: GFAssetCatalogEntry) -> GFAssetCatalogEntry:
	var copy: GFAssetCatalogEntry = GFAssetCatalogEntry.new()
	copy.asset_id = source.asset_id
	copy.title = source.title
	copy.description = source.description
	copy.tags = source.tags.duplicate()
	copy.category = source.category
	copy.primary_path = source.primary_path
	copy.type_hint = source.type_hint
	copy.preview_path = source.preview_path
	copy.resource_entry_ids = source.resource_entry_ids.duplicate()
	copy.source_id = source.source_id
	copy.metadata = source.metadata.duplicate(true)
	return copy

static func _read_int(data: Dictionary, key: String, fallback: int = 0) -> int:
	var value: Variant = data.get(key, fallback)
	if value is int:
		var int_value: int = value
		return int_value
	return fallback


static func _read_bool(data: Dictionary, key: String, fallback: bool = false) -> bool:
	var value: Variant = data.get(key, fallback)
	if value is bool:
		var bool_value: bool = value
		return bool_value
	return fallback


static func _read_array(data: Dictionary, key: String) -> Array:
	var value: Variant = data.get(key, [])
	if value is Array:
		var array_value: Array = value
		return array_value.duplicate(true)
	return []


static func _read_packed_string_array(data: Dictionary, key: String) -> PackedStringArray:
	var value: Variant = data.get(key, PackedStringArray())
	if value is PackedStringArray:
		var array_value: PackedStringArray = value
		return array_value.duplicate()
	return PackedStringArray()


static func _normalize_asset_ids(asset_ids: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var seen_ids: Dictionary = {}
	for asset_id_text: String in asset_ids:
		var normalized: String = asset_id_text.strip_edges()
		if normalized.is_empty() or seen_ids.has(normalized):
			continue
		seen_ids[normalized] = true
		var _appended: bool = result.append(normalized)
	result.sort()
	return result


static func _are_asset_ids_valid(asset_ids: PackedStringArray) -> bool:
	for asset_id_text: String in asset_ids:
		var normalized: String = asset_id_text.strip_edges()
		if (
			normalized.is_empty()
			or asset_id_text != normalized
			or asset_id_text.length() > _MAX_ASSET_ID_LENGTH
		):
			return false
	return true


static func _make_page_items(raw_items: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var encode_options: Dictionary = GFReportValueCodec.make_redaction_options(
		GFReportValueCodec.REDACTION_PROFILE_DEBUG,
		{
			"path_redaction": "none",
			"max_depth": 8,
			"max_string_length": _MAX_SUMMARY_STRING_LENGTH,
			"max_collection_items": _MAX_SUMMARY_COLLECTION_ITEMS,
			"max_packed_length": _MAX_SUMMARY_COLLECTION_ITEMS,
			"max_total_nodes": _MAX_SUMMARY_NODES,
			"max_total_bytes": _MAX_SUMMARY_BYTES,
		}
	)
	for raw_item: Variant in raw_items:
		if raw_item is Dictionary:
			var item: Dictionary = raw_item
			result.append(GFReportValueCodec.to_report_dictionary(item, encode_options))
	return result


func _invalidate_active_preview(reason: StringName) -> void:
	if _active_preview_task == null:
		return
	_preview_generation += 1
	_cancel_active_preview(reason)


func _cancel_active_preview(reason: StringName) -> void:
	var task: GFThumbnailRenderTask = _active_preview_task
	_active_preview_task = null
	_active_preview_asset_id = &""
	_active_preview_catalog_revision = 0
	_active_preview_query_generation = 0
	if task != null and not task.is_finished():
		var _cancelled: bool = task.cancel(reason)


func _is_current_preview_task(
	task: GFThumbnailRenderTask,
	asset_id: StringName,
	preview_generation: int,
	catalog_revision: int,
	query_generation: int
) -> bool:
	return (
		task != null
		and task == _active_preview_task
		and asset_id == _active_preview_asset_id
		and preview_generation == _preview_generation
		and catalog_revision == _active_preview_catalog_revision
		and query_generation == _active_preview_query_generation
		and catalog_revision == _catalog_revision
		and query_generation == _query_generation
	)


func _resolve_preview_task(
	task: GFThumbnailRenderTask,
	asset_id: StringName,
	preview_generation: int,
	catalog_revision: int,
	query_generation: int
) -> void:
	if not _is_current_preview_task(
		task,
		asset_id,
		preview_generation,
		catalog_revision,
		query_generation
	):
		return
	_active_preview_task = null
	_active_preview_asset_id = &""
	_active_preview_catalog_revision = 0
	_active_preview_query_generation = 0
	var state: StringName = &"failed"
	if task.is_succeeded():
		state = &"succeeded"
	elif task.is_cancelled():
		state = &"cancelled"
	var preview_result_report: Dictionary = _make_frozen_preview_result(
		task.get_result(),
		not task.is_succeeded()
	)
	var preview_result: Variant = preview_result_report.get("result")
	var preview_error: String = task.get_error()
	if not _read_bool(preview_result_report, "ok"):
		state = &"failed"
		preview_error = GFVariantData.get_option_string(
			preview_result_report,
			"error"
		)
	var report: Dictionary = {
		"asset_id": asset_id,
		"preview_generation": preview_generation,
		"catalog_revision": catalog_revision,
		"query_generation": query_generation,
		"state": state,
		"result": preview_result,
		"error": preview_error,
		"cancel_reason": task.get_cancel_reason(),
	}
	report.make_read_only()
	_publish_notification(_make_notification(_NOTIFICATION_PREVIEW_RESOLVED, {
		"report": report,
	}))


static func _make_frozen_preview_result(
	value: Variant,
	allow_null: bool
) -> Dictionary:
	if value == null:
		return {
			"ok": allow_null,
			"result": null,
			"error": "" if allow_null else "invalid_preview_result",
		}
	if value is Image or value is ImageTexture:
		return {
			"ok": true,
			"result": value,
			"error": "",
		}
	if not value is Dictionary:
		return {
			"ok": false,
			"result": null,
			"error": "invalid_preview_result",
		}
	var plan: Dictionary = value
	return _make_frozen_preview_plan(plan)


static func _make_frozen_preview_plan(plan: Dictionary) -> Dictionary:
	if (
		plan.size() != _PREVIEW_PLAN_KEY_COUNT
		or not plan.has("ok")
		or not plan.has("generated_count")
		or not plan.has("cancelled")
		or not plan.has("changes")
		or not plan["ok"] is bool
		or not plan["generated_count"] is int
		or not plan["cancelled"] is bool
		or not plan["changes"] is Array
	):
		return _make_invalid_preview_result("invalid_preview_plan")
	var plan_ok: bool = plan["ok"]
	var generated_count: int = plan["generated_count"]
	var cancelled: bool = plan["cancelled"]
	var changes: Array = plan["changes"]
	if changes.size() > MAX_RESULT_COUNT:
		return _make_invalid_preview_result(
			"preview_plan_change_limit_exceeded"
		)
	if not plan_ok or generated_count < 0 or generated_count != changes.size():
		return _make_invalid_preview_result("invalid_preview_plan")

	var frozen_changes: Array = []
	for change_value: Variant in changes:
		if not change_value is Dictionary:
			return _make_invalid_preview_result("invalid_preview_plan")
		var change: Dictionary = change_value
		if (
			change.size() != _PREVIEW_PLAN_CHANGE_KEY_COUNT
			or not change.has("item_id")
			or not change.has("old_preview")
			or not change.has("new_preview")
			or not change["item_id"] is int
		):
			return _make_invalid_preview_result("invalid_preview_plan")
		var item_id: int = change["item_id"]
		var old_preview: Variant = change["old_preview"]
		var new_preview: Variant = change["new_preview"]
		if (
			item_id < 0
			or (old_preview != null and not old_preview is Texture2D)
			or not new_preview is Texture2D
		):
			return _make_invalid_preview_result("invalid_preview_plan")
		var frozen_change: Dictionary = {
			"item_id": item_id,
			"old_preview": old_preview,
			"new_preview": new_preview,
		}
		frozen_change.make_read_only()
		frozen_changes.append(frozen_change)
	frozen_changes.make_read_only()
	var frozen_plan: Dictionary = {
		"ok": plan_ok,
		"generated_count": generated_count,
		"cancelled": cancelled,
		"changes": frozen_changes,
	}
	frozen_plan.make_read_only()
	return {
		"ok": true,
		"result": frozen_plan,
		"error": "",
	}


static func _make_invalid_preview_result(error_text: String) -> Dictionary:
	return {
		"ok": false,
		"result": null,
		"error": error_text,
	}


# --- 信号处理函数 ---

func _on_preview_task_completed(
	task: GFThumbnailRenderTask,
	asset_id: StringName,
	preview_generation: int,
	catalog_revision: int,
	query_generation: int
) -> void:
	_resolve_preview_task(
		task,
		asset_id,
		preview_generation,
		catalog_revision,
		query_generation
	)
