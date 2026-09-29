@tool

# 项目素材工作台。目录、缩略图、个人偏好与共享目录分别拥有生命周期。
extends VBoxContainer


# --- 常量 ---

const _UI_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")
const _SOURCE_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_project_asset_source.gd")
const _QUEUE_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_thumbnail_queue.gd")
const _GRID_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_browser_grid.gd")
const _PREFERENCES_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_browser_preferences.gd")
const _TABLES_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_resource_tables.gd")
const _CATALOG_COMMAND_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_catalog_edit_command.gd")
const _PAGE_QUERY_SCRIPT = preload("res://addons/gf/tools/asset_browser/gf_asset_browser_page_query.gd")
const _TYPE_FILTERS: PackedStringArray = ["", "PackedScene", "Texture2D", "AudioStream", "Material", "Mesh", "Resource"]


# --- 私有变量 ---

var _context: GFEditorToolContext = null
var _model: GFAssetBrowserModel = GFAssetBrowserModel.new()
var _source: _SOURCE_SCRIPT = _SOURCE_SCRIPT.new()
var _queue: _QUEUE_SCRIPT = _QUEUE_SCRIPT.new()
var _grid: _GRID_SCRIPT = _GRID_SCRIPT.new()
var _tables: _TABLES_SCRIPT = _TABLES_SCRIPT.new()
var _project_catalog: GFAssetCatalog = GFAssetCatalog.new()
var _shared_catalog: GFAssetCatalog = null
var _shared_path: String = ""
var _shared_saved_fingerprint: int = 0
var _catalog: GFAssetCatalog = GFAssetCatalog.new()
var _state: Dictionary = {}
var _page: int = 1
var _page_count: int = 0
var _preview_generation: int = 0
var _stale: bool = true
var _project_snapshot_valid: bool = false
var _context_generation: int = 0
var _refresh_queued: bool = false
var _scope: LineEdit = null
var _search: LineEdit = null
var _types: OptionButton = null
var _sources: OptionButton = null
var _collection: OptionButton = null
var _addons: CheckBox = null
var _status: Label = null
var _page_label: Label = null
var _catalog_label: Label = null
var _details: TextEdit = null
var _tags: LineEdit = null
var _notes: LineEdit = null
var _tabs: TabContainer = null
var _catalog_dialog: EditorFileDialog = null
var _dialog_create: bool = false
var _previous_button: Button = null
var _next_button: Button = null
var _catalog_save_button: Button = null
var _resource_actions: MenuButton = null
var _resource_menu_paths: PackedStringArray = PackedStringArray()
var _resource_menu_context_generation: int = -1
var _resource_menu_next_id: int = 0
var _selected_id: StringName = &""
var _owner_window: Window = null
var _page_query: _PAGE_QUERY_SCRIPT = null
var _retired_queries: Array[_PAGE_QUERY_SCRIPT] = []
var _query_pending: bool = false
var _page_ready: bool = false
var _query_delay: float = 0.0
var _query_context_generation: int = -1
var _query_serial: int = 0
var _query_progress: Dictionary = {}
var _card_report: Dictionary = {}
var _card_ids: PackedStringArray = PackedStringArray()
var _card_items: Array = []
var _card_paths: PackedStringArray = PackedStringArray()
var _card_cursor: int = 0
var _peak_card_step_usec: int = 0


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "GFAssetBrowser"
	_UI_SCRIPT.apply_page_root(self)
	_build_ui()
	add_child(_source)
	var _complete_connection: int = _source.completed.connect(_on_source_completed)
	var _invalidated_connection: int = _source.invalidated.connect(_on_source_invalidated)
	var _preview_connection: int = _queue.preview_ready.connect(_on_preview_ready)
	var _visibility_connection: int = visibility_changed.connect(_on_visibility_changed)


func _ready() -> void:
	_owner_window = get_window()
	if _owner_window != null:
		var _window_connection: int = _owner_window.visibility_changed.connect(_on_visibility_changed)
	_state = _PREFERENCES_SCRIPT.load_state()
	_scope.text = GFVariantData.get_option_string(_state, "scope", "res://")
	_addons.set_pressed_no_signal(GFVariantData.get_option_bool(_state, "include_addons"))
	var stored_type: String = GFVariantData.get_option_string(_state, "type_filter")
	var type_index: int = _TYPE_FILTERS.find(stored_type)
	_types.select(maxi(type_index, 0))
	if Engine.is_editor_hint():
		_queue.setup(EditorInterface.get_resource_previewer())
		_schedule_refresh()


func _process(delta: float) -> void:
	_reap_queries()
	if not _query_pending:
		return
	if not _can_update_view() or _query_context_generation != _context_generation:
		_cancel_page_query()
		return
	_query_delay = maxf(_query_delay - delta, 0.0)
	if _query_delay > 0.0:
		return
	if not _card_report.is_empty():
		_build_card_batch()
		return
	if _page_query == null:
		_start_page_query()
	if _page_query == null:
		return
	var serial: int = _query_serial
	var finished: bool = _page_query.step(128, 2000, _retired_queries.is_empty())
	if serial != _query_serial or _page_query == null:
		return
	_query_progress = _page_query.get_progress()
	_status.text = "正在查询资源：%d / %d" % [GFVariantData.get_option_int(_query_progress, "scanned"), GFVariantData.get_option_int(_query_progress, "input_count")]
	if not finished:
		return
	var report: Dictionary = _page_query.take_result()
	if report.is_empty() or not _is_page_report_current(report):
		_cancel_page_query()
		var error: String = GFVariantData.get_option_string(_query_progress, "error")
		if not error.is_empty():
			_status.text = "查询失败，请重试：" + error
		return
	_page_query = null
	_card_report = report
	_card_ids = GFVariantData.get_option_packed_string_array(report, "asset_ids")
	var items_value: Variant = report.get("items")
	if items_value is Array:
		_card_items = items_value
	_card_paths.clear()
	_card_cursor = 0
	_grid.clear()


func _exit_tree() -> void:
	_release_context()
	for task: _PAGE_QUERY_SCRIPT in _retired_queries:
		task.join_worker()
	_retired_queries.clear()
	_disconnect_shared_catalog()
	if is_instance_valid(_owner_window) and _owner_window.visibility_changed.is_connected(_on_visibility_changed):
		_owner_window.visibility_changed.disconnect(_on_visibility_changed)
	_owner_window = null


# --- 框架内部方法 ---

## 接收宿主上下文；撤销上下文时停止索引与预览提交。
## [br]
## @api framework_internal
## [br]
## @param context: 当前宿主上下文或 null。
func set_editor_context(context: GFEditorToolContext) -> void:
	_context_generation += 1
	_cancel_page_query()
	_clear_resource_actions()
	_close_catalog_dialog()
	_context = context
	_tables.set_editor_context(context)
	_catalog_save_button.disabled = context == null
	if context == null:
		_release_context()
	elif is_inside_tree() and Engine.is_editor_hint():
		_queue.setup(EditorInterface.get_resource_previewer())
		_schedule_refresh()


## 为宿主资源动作提供当前显式选择，不暴露另一工具的对象。
## [br]
## @api framework_internal
## [br]
## @return 当前卡片对应的项目资源路径。
func get_selected_resource_paths() -> PackedStringArray:
	return PackedStringArray() if _stale or _query_pending or not _page_ready or not _can_update_view() else _grid.get_selected_resource_paths()


## 返回可观察页面状态，供编辑器验收和宿主状态显示使用。
## [br]
## @api framework_internal
## [br]
## @return 页面快照。
## [br]
## @schema return: Dictionary with stale, query_pending, page_ready, query_progress, worker_count, peak_card_step_usec, entry_count, visible_count, page, shared_path and selected_paths.
func get_snapshot() -> Dictionary:
	return {"stale": _stale, "query_pending": _query_pending, "page_ready": _page_ready, "query_progress": _query_progress.duplicate(true), "worker_count": _retired_queries.size() + (1 if _page_query != null and _page_query.has_worker() else 0), "peak_card_step_usec": _peak_card_step_usec, "entry_count": _catalog.entries.size(), "visible_count": _grid.item_count, "page": _page, "shared_path": _shared_path, "selected_paths": get_selected_resource_paths()}


# --- 私有/辅助方法 ---

func _build_ui() -> void:
	var source_row: HBoxContainer = _UI_SCRIPT.make_toolbar()
	add_child(source_row)
	_sources = OptionButton.new()
	_sources.add_item("项目资源")
	_sources.add_item("共享目录")
	source_row.add_child(_sources)
	var _sources_connection: int = _sources.item_selected.connect(_on_filter_selected)
	_scope = LineEdit.new()
	_scope.placeholder_text = "res:// 范围目录"
	_scope.text = "res://"
	_scope.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_row.add_child(_scope)
	var _scope_connection: int = _scope.text_submitted.connect(_on_scope_submitted)
	_addons = CheckBox.new()
	_addons.text = "包含插件"
	source_row.add_child(_addons)
	var _addons_connection: int = _addons.toggled.connect(_on_addons_toggled)
	source_row.add_child(_UI_SCRIPT.make_button("刷新", "读取 Godot 已有资源索引", _refresh))
	var query_row: HBoxContainer = _UI_SCRIPT.make_toolbar()
	add_child(query_row)
	_search = LineEdit.new()
	_search.name = "AssetSearch"
	_search.max_length = 512
	_search.placeholder_text = "搜索名称、路径、共享标签…"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	query_row.add_child(_search)
	var _search_connection: int = _search.text_changed.connect(_on_search_changed)
	_types = OptionButton.new()
	for caption: String in ["全部类型", "场景", "图片", "音频", "材质", "网格", "资源"]:
		_types.add_item(caption)
	query_row.add_child(_types)
	var _types_connection: int = _types.item_selected.connect(_on_filter_selected)
	_collection = OptionButton.new()
	for caption: String in ["全部", "个人收藏", "最近使用"]:
		_collection.add_item(caption)
	query_row.add_child(_collection)
	var _collection_connection: int = _collection.item_selected.connect(_on_collection_selected)
	_status = _UI_SCRIPT.make_summary_label("打开后读取项目导入索引；无需创建目录或 Provider。")
	add_child(_status)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tabs)
	var browser: VBoxContainer = VBoxContainer.new()
	browser.name = "素材"
	_tabs.add_child(browser)
	_grid.name = "AssetGrid"
	_grid.select_mode = ItemList.SELECT_MULTI
	_grid.icon_mode = ItemList.ICON_MODE_TOP
	_grid.fixed_icon_size = Vector2i(96, 96)
	_grid.fixed_column_width = 160
	_grid.max_text_lines = 2
	_grid.max_columns = 0
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	browser.add_child(_grid)
	var _selection_connection: int = _grid.multi_selected.connect(_on_grid_selected)
	var _activated_connection: int = _grid.item_activated.connect(_on_grid_activated)
	var page_row: HBoxContainer = _UI_SCRIPT.make_toolbar()
	browser.add_child(page_row)
	_previous_button = _UI_SCRIPT.make_button("上一页", "每页最多 100 项", _previous_page)
	page_row.add_child(_previous_button)
	_page_label = _UI_SCRIPT.make_summary_label()
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_row.add_child(_page_label)
	_next_button = _UI_SCRIPT.make_button("下一页", "每页最多 100 项", _next_page)
	page_row.add_child(_next_button)
	var action_row: HFlowContainer = HFlowContainer.new()
	browser.add_child(action_row)
	action_row.add_child(_UI_SCRIPT.make_button("打开", "场景在原生编辑器打开，其他资源交给 Inspector", _open_selected))
	action_row.add_child(_UI_SCRIPT.make_button("定位文件", "在 Godot FileSystem 中定位", _locate_selected))
	action_row.add_child(_UI_SCRIPT.make_button("收藏 / 取消", "仅保存个人编辑器偏好", _toggle_favorites))
	action_row.add_child(_UI_SCRIPT.make_button("表格编辑", "只编辑显式选择的独立源 tres/res", _open_tables))
	action_row.add_child(_UI_SCRIPT.make_button("依赖 / 引用", "按需有界扫描，不作为安全删除证明", _inspect_references))
	_resource_actions = MenuButton.new()
	_resource_actions.name = "ResourceActions"
	_resource_actions.text = "发送到工具"
	_resource_actions.tooltip_text = "接收工具声明可用动作；交接资源后继续在目标工具操作。"
	_resource_actions.hide()
	action_row.add_child(_resource_actions)
	var action_popup: PopupMenu = _resource_actions.get_popup()
	var _popup_connection: int = action_popup.about_to_popup.connect(_refresh_resource_actions)
	var _action_connection: int = action_popup.id_pressed.connect(_on_resource_action_pressed)
	_details = _UI_SCRIPT.make_details_output(110.0)
	browser.add_child(_details)
	_tables.name = "资源表格"
	_tabs.add_child(_tables)
	var catalog_row: HBoxContainer = _UI_SCRIPT.make_toolbar()
	add_child(catalog_row)
	catalog_row.add_child(_UI_SCRIPT.make_button("新建共享目录", "显式选择保存位置", _create_catalog))
	catalog_row.add_child(_UI_SCRIPT.make_button("打开共享目录", "读取已有 GFAssetCatalog", _open_catalog))
	_catalog_save_button = _UI_SCRIPT.make_button("保存共享目录", "只保存目录，不修改源素材或导入结果", _save_catalog)
	_catalog_save_button.disabled = true
	catalog_row.add_child(_catalog_save_button)
	_catalog_label = _UI_SCRIPT.make_summary_label("未选择共享目录；收藏属于个人。")
	add_child(_catalog_label)
	var tag_row: HBoxContainer = _UI_SCRIPT.make_toolbar()
	add_child(tag_row)
	_tags = LineEdit.new()
	_tags.name = "SharedAssetTags"
	_tags.placeholder_text = "共享标签，逗号分隔"
	_tags.max_length = 2048
	_tags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_row.add_child(_tags)
	_notes = LineEdit.new()
	_notes.name = "SharedAssetNotes"
	_notes.placeholder_text = "共享备注"
	_notes.max_length = 4096
	_notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_row.add_child(_notes)
	tag_row.add_child(_UI_SCRIPT.make_button("应用到所选", "修改所选条目；原生 Undo，另行保存目录", _apply_shared_fields))


func _release_context() -> void:
	_context_generation += 1
	_cancel_page_query()
	_clear_resource_actions()
	_close_catalog_dialog()
	_source.cancel()
	_queue.dispose()
	_tables.release_context()
	_context = null
	_catalog_save_button.disabled = true
	_project_snapshot_valid = false
	_set_stale(true)


func _close_catalog_dialog() -> void:
	if is_instance_valid(_catalog_dialog):
		_catalog_dialog.hide()
		_catalog_dialog.queue_free()
	_catalog_dialog = null


func _can_update_view() -> bool:
	return Engine.is_editor_hint() and _context != null and _is_view_visible()


func _is_view_visible() -> bool:
	return is_inside_tree() and is_visible_in_tree() and get_window() != null and get_window().visible


func _set_stale(value: bool) -> void:
	_stale = value
	if value:
		_cancel_page_query()
	_grid.set_resource_actions_enabled(not value and not _query_pending and _can_update_view())
	_clear_resource_actions()
	_refresh_resource_actions()


func _schedule_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_run_queued_refresh.call_deferred()


func _run_queued_refresh() -> void:
	_refresh_queued = false
	if is_inside_tree() and is_visible_in_tree() and _context != null:
		_refresh()


func _refresh() -> void:
	if not Engine.is_editor_hint() or _context == null:
		return
	_store_view_state()
	_page = 1
	_project_snapshot_valid = false
	_set_stale(true)
	_source.cancel()
	_queue.pause()
	_queue.invalidate()
	var normalized_scope: String = _scope.text.strip_edges().simplify_path()
	if not normalized_scope.begins_with("res://") or normalized_scope.contains(".."):
		_status.text = "范围必须是项目内的 res:// 目录。"
		return
	if _sources.selected == 1:
		if _shared_catalog == null:
			_status.text = "请打开或新建共享目录。"
			return
		_publish_catalog()
		return
	_status.text = "正在读取 Godot 索引：%s；上次结果暂不可用于编辑。" % _scope.text
	_source.start_scan(_scope.text, _TYPE_FILTERS[_types.selected], _addons.button_pressed)


func _publish_catalog() -> void:
	if not _can_update_view() or (_sources.selected == 0 and not _project_snapshot_valid):
		_set_stale(true)
		return
	var next_catalog: GFAssetCatalog = GFAssetCatalog.new()
	var source_catalog: GFAssetCatalog = _shared_catalog if _sources.selected == 1 else _project_catalog
	if source_catalog == null:
		return
	var shared_by_id: Dictionary = {}
	if _shared_catalog != null:
		for shared_entry: GFAssetCatalogEntry in _shared_catalog.entries:
			if shared_entry != null:
				shared_by_id[shared_entry.asset_id] = shared_entry
	for source_entry: GFAssetCatalogEntry in source_catalog.entries:
		if source_entry == null:
			continue
		var entry: GFAssetCatalogEntry = source_entry.duplicate_entry()
		var identity: String = String(entry.asset_id)
		if identity.begins_with("uid://"):
			var uid: int = ResourceUID.text_to_id(identity)
			if uid >= 0 and ResourceUID.has_id(uid):
				entry.primary_path = ResourceUID.get_id_path(uid)
		if _sources.selected == 1:
			if not entry.primary_path.begins_with("res://"):
				continue
			if not _addons.button_pressed and entry.primary_path.begins_with("res://addons/"):
				continue
			var scope_path: String = _scope.text.simplify_path().trim_suffix("/")
			if scope_path != "res:" and not (entry.primary_path == scope_path or entry.primary_path.begins_with(scope_path + "/")):
				continue
			if not _SOURCE_SCRIPT.matches_type(entry.type_hint, _TYPE_FILTERS[_types.selected]):
				continue
		elif shared_by_id.has(entry.asset_id):
			var shared_value: Variant = shared_by_id[entry.asset_id]
			if shared_value is GFAssetCatalogEntry:
				var shared_entry: GFAssetCatalogEntry = shared_value
				entry.tags = shared_entry.tags.duplicate()
				entry.description = shared_entry.description
				entry.metadata["shared_catalog"] = _shared_path
		next_catalog.entries.append(entry)
	var report: Dictionary = _model.replace_catalog(next_catalog)
	if not GFVariantData.get_option_bool(report, "ok"):
		_set_stale(true)
		_status.text = "目录不可发布，旧结果已过期：%s" % GFVariantData.get_option_string(report, "error")
		return
	_catalog = next_catalog
	_set_stale(false)
	_render_page()


func _render_page() -> void:
	_cancel_page_query()
	if not _can_update_view():
		return
	_query_pending = true
	_query_progress = {}
	_peak_card_step_usec = 0
	_query_context_generation = _context_generation
	_previous_button.disabled = true
	_next_button.disabled = true
	_selected_id = &""
	_details.text = "正在查询；完成前旧选择不可用于资源操作。"
	_status.text = "正在准备资源查询…"


func _start_page_query() -> void:
	var serial: int = _query_serial
	var filter_ids: PackedStringArray = PackedStringArray()
	if _collection.selected > 0:
		filter_ids = GFVariantData.get_option_packed_string_array(_state, "favorites" if _collection.selected == 1 else "recent")
		if filter_ids.is_empty():
			filter_ids = PackedStringArray(["__gf_asset_browser_empty_collection__"])
	var query_report: Dictionary = _model.set_query(_search.text, filter_ids)
	if serial != _query_serial:
		return
	if not GFVariantData.get_option_bool(query_report, "ok"):
		_cancel_page_query()
		_status.text = "搜索条件无效。"
		return
	if not _can_update_view() or _query_context_generation != _context_generation:
		_cancel_page_query()
		return
	var task: RefCounted = _model.create_page_query(_page, 100)
	if task is _PAGE_QUERY_SCRIPT:
		_page_query = task
	else:
		_cancel_page_query()


func _cancel_page_query() -> void:
	_query_serial += 1
	if _page_query != null:
		_page_query.cancel()
		if _page_query.has_worker():
			_retired_queries.append(_page_query)
	_page_query = null
	_query_pending = false
	_page_ready = false
	_query_delay = 0.0
	_card_report.clear()
	_card_ids.clear()
	_card_items = []
	_card_paths.clear()
	_grid.set_resource_actions_enabled(false)
	_queue.pause()
	_clear_resource_actions()


func _reap_queries() -> void:
	for index: int in range(_retired_queries.size() - 1, -1, -1):
		if _retired_queries[index].reap_worker():
			_retired_queries.remove_at(index)


func _is_page_report_current(report: Dictionary) -> bool:
	return _can_update_view() and _query_context_generation == _context_generation and _model.is_page_query_current(
		GFVariantData.get_option_int(report, "catalog_revision"), GFVariantData.get_option_int(report, "query_generation")
	)


func _build_card_batch() -> void:
	if not _is_page_report_current(_card_report):
		_cancel_page_query()
		return
	var started: int = Time.get_ticks_usec()
	var count: int = 0
	while _card_cursor < _card_ids.size() and count < 16:
		if count > 0 and Time.get_ticks_usec() - started >= 2000:
			break
		var item: Dictionary = GFVariantData.as_dictionary(_card_items[_card_cursor])
		_card_cursor += 1
		count += 1
		var path: String = GFVariantData.get_option_string(item, "primary_path")
		var type_hint: String = GFVariantData.get_option_string(item, "type_hint")
		var title: String = GFVariantData.get_option_string(item, "title", path.get_file())
		var icon: Texture2D = _grid.get_theme_icon(type_hint if _grid.has_theme_icon(type_hint, "EditorIcons") else "Object", "EditorIcons")
		var item_index: int = _grid.add_item(title, icon)
		_grid.set_item_metadata(item_index, path)
		_grid.set_item_tooltip(item_index, "%s\n%s\n%s" % [path, type_hint, ", ".join(GFVariantData.get_option_packed_string_array(item, "tags"))])
		var _appended: bool = _card_paths.append(path)
	_peak_card_step_usec = maxi(_peak_card_step_usec, Time.get_ticks_usec() - started)
	if _card_cursor < _card_ids.size():
		return
	_finish_page_render()


func _finish_page_render() -> void:
	if not _is_page_report_current(_card_report):
		_cancel_page_query()
		return
	var page_report: Dictionary = _card_report
	var serial: int = _query_serial
	_card_report = {}
	_page = GFVariantData.get_option_int(page_report, "page", 1)
	_page_count = GFVariantData.get_option_int(page_report, "page_count")
	_query_pending = false
	_page_ready = true
	_grid.set_resource_actions_enabled(not _stale)
	if _stale:
		_queue.pause()
	else:
		_preview_generation = _queue.request_visible(_card_paths)
	if serial != _query_serial or not _is_page_report_current(page_report):
		return
	_previous_button.disabled = _page <= 1
	_next_button.disabled = _page >= _page_count
	_page_label.text = "第 %d / %d 页 · %d 项" % [_page, maxi(_page_count, 1), GFVariantData.get_option_int(page_report, "total_count")]
	_status.text = "%s · %d 项完整快照%s" % [_scope.text, _catalog.entries.size(), "（旧结果已过期）" if _stale else ""]
	if _grid.item_count == 0:
		_status.text += "；没有匹配资源。调整范围、筛选，或打开共享目录。"
	_selected_id = &""
	_details.text = "选择素材查看身份、路径、类型与元数据。"
	_clear_resource_actions()
	_refresh_resource_actions()


func _clear_resource_actions() -> void:
	_resource_menu_paths.clear()
	_resource_menu_context_generation = -1
	if _resource_actions == null:
		return
	_resource_actions.get_popup().hide()
	_resource_actions.get_popup().clear()
	_resource_actions.disabled = true


func _refresh_resource_actions() -> void:
	if _resource_actions == null:
		return
	var popup: PopupMenu = _resource_actions.get_popup()
	popup.clear()
	_resource_menu_paths = get_selected_resource_paths()
	_resource_menu_context_generation = _context_generation
	var actions: Array[Dictionary] = []
	if _context != null:
		actions = _context.get_resource_actions(_resource_menu_paths)
	_resource_actions.visible = not actions.is_empty()
	_resource_actions.disabled = _stale or _query_pending or not _can_update_view() or _resource_menu_paths.is_empty()
	for action: Dictionary in actions:
		var index: int = popup.item_count
		popup.add_item(GFVariantData.get_option_string(action, "title"), _resource_menu_next_id)
		_resource_menu_next_id += 1
		popup.set_item_metadata(index, GFVariantData.get_option_string(action, "action_id"))
		popup.set_item_disabled(index, not GFVariantData.get_option_bool(action, "available"))
		popup.set_item_tooltip(index, GFVariantData.get_option_string(action, "reason"))


func _on_resource_action_pressed(item_id: int) -> void:
	if _stale or _query_pending or not _can_update_view() or _resource_menu_context_generation != _context_generation:
		return
	var popup: PopupMenu = _resource_actions.get_popup()
	var index: int = popup.get_item_index(item_id)
	if index < 0 or popup.is_item_disabled(index) or _resource_menu_paths != get_selected_resource_paths():
		return
	var action_id: String = GFVariantData.to_text(popup.get_item_metadata(index))
	var paths: PackedStringArray = _resource_menu_paths.duplicate()
	var entries: Array[GFAssetCatalogEntry] = _selected_entries()
	var generation: int = _context_generation
	# 导航可能立即隐藏本页并清空菜单，因此只使用调用前独立保存的选择。
	var report: Dictionary = _context.request_resource_action(action_id, paths)
	if generation != _context_generation or _context == null:
		return
	if GFVariantData.get_option_bool(report, "ok"):
		_record_recent_entries(entries)
	_status.text = GFVariantData.get_option_string(report, "message", "已交接所选资源。" if GFVariantData.get_option_bool(report, "ok") else "接收工具未完成交接；请刷新后重试。")


func _selected_entries() -> Array[GFAssetCatalogEntry]:
	var paths: PackedStringArray = get_selected_resource_paths()
	var entries: Array[GFAssetCatalogEntry] = []
	for entry: GFAssetCatalogEntry in _catalog.entries:
		if entry != null and paths.has(entry.primary_path):
			entries.append(entry)
	return entries


func _store_view_state() -> void:
	_state["scope"] = _scope.text
	_state["type_filter"] = _TYPE_FILTERS[_types.selected]
	_state["include_addons"] = _addons.button_pressed
	_PREFERENCES_SCRIPT.save_state(_state)


func _record_recent() -> void:
	_record_recent_entries(_selected_entries())


func _record_recent_entries(entries: Array[GFAssetCatalogEntry]) -> void:
	var recent: PackedStringArray = GFVariantData.get_option_packed_string_array(_state, "recent")
	for entry: GFAssetCatalogEntry in entries:
		var identity: String = String(entry.asset_id)
		var old_index: int = recent.find(identity)
		if old_index >= 0:
			recent.remove_at(old_index)
		var _inserted: int = recent.insert(0, identity)
	_state["recent"] = recent.slice(0, 100)
	_store_view_state()


func _open_selected() -> void:
	if not Engine.is_editor_hint() or _stale:
		return
	var paths: PackedStringArray = get_selected_resource_paths()
	if paths.is_empty():
		return
	var path: String = paths[0]
	if not ResourceLoader.exists(path):
		_status.text = "资源已不存在，请刷新：" + path
		return
	_record_recent()
	var resource: Resource = ResourceLoader.load(path)
	if resource is PackedScene:
		EditorInterface.open_scene_from_path(path)
	else:
		if resource != null:
			EditorInterface.edit_resource(resource)


func _locate_selected() -> void:
	var paths: PackedStringArray = get_selected_resource_paths()
	if Engine.is_editor_hint() and not paths.is_empty():
		EditorInterface.get_file_system_dock().navigate_to_path(paths[0])


func _toggle_favorites() -> void:
	var favorites: PackedStringArray = GFVariantData.get_option_packed_string_array(_state, "favorites")
	for entry: GFAssetCatalogEntry in _selected_entries():
		var identity: String = String(entry.asset_id)
		var old_index: int = favorites.find(identity)
		if old_index >= 0:
			favorites.remove_at(old_index)
		elif favorites.size() < 1000:
			var _appended: bool = favorites.append(identity)
	_state["favorites"] = favorites
	_store_view_state()
	_status.text = "个人收藏已保存：%d 项；UID 资源移动后按身份重新定位。" % favorites.size()
	if _collection.selected == 1:
		_render_page()


func _open_tables() -> void:
	if _stale or _context == null:
		_status.text = "请等待有效资源快照。"
		return
	var paths: PackedStringArray = get_selected_resource_paths()
	if paths.is_empty():
		return
	_record_recent()
	var _report: Dictionary = _tables.show_paths(paths, _context)
	_tabs.current_tab = 1


func _inspect_references() -> void:
	var paths: PackedStringArray = get_selected_resource_paths()
	if paths.size() != 1 or _stale:
		_status.text = "请在有效快照中选择一个资源。"
		return
	var path: String = paths[0]
	var dependencies: Dictionary = GFResourceRegistryTools.build_dependency_report(path, {"max_scan_depth": 16, "max_dependency_paths": 1000})
	var references: Dictionary = GFProjectReferenceScanner.scan_references([{"id": path, "root_path": path}], {
		"scan_roots": [_scope.text], "max_scanned_files": 2000, "max_file_bytes": 1_048_576,
		"max_total_bytes": 8_388_608, "max_references_per_target": 100, "max_weak_references_per_target": 100,
	})
	_details.text = "扫描范围：%s\n包含已验证、静态及弱引用证据。动态路径可能无法确定；未发现引用不表示可安全删除。\n\n%s" % [_scope.text, JSON.stringify({"dependencies": dependencies, "references": references}, "  ")]
	_status.text = "引用检查完成%s；刷新或源文件变化后结果过期。" % ("（覆盖不完整）" if GFVariantData.get_option_bool(references, "partial_scan") else "")


func _create_catalog() -> void:
	_show_catalog_dialog(true)


func _open_catalog() -> void:
	_show_catalog_dialog(false)


func _show_catalog_dialog(create: bool) -> void:
	if not _can_update_view():
		return
	if _shared_catalog != null and _catalog_fingerprint() != _shared_saved_fingerprint:
		_status.text = "共享目录有未保存修改，请先保存；原生 Undo 可恢复编辑。"
		return
	if _catalog_dialog == null:
		_catalog_dialog = EditorFileDialog.new()
		_catalog_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		_catalog_dialog.filters = PackedStringArray(["*.tres ; GF Asset Catalog"])
		add_child(_catalog_dialog)
		var _selected_connection: int = _catalog_dialog.file_selected.connect(_on_catalog_path_selected.bind(_context_generation))
	_dialog_create = create
	_catalog_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE if create else EditorFileDialog.FILE_MODE_OPEN_FILE
	_catalog_dialog.title = "新建共享目录" if create else "打开共享目录"
	_catalog_dialog.popup_centered_ratio(0.6)


func _save_catalog() -> void:
	if not _can_update_view():
		return
	if _shared_catalog == null or _shared_path.is_empty():
		_status.text = "先新建或打开共享目录。"
		return
	var error: Error = ResourceSaver.save(_shared_catalog, _shared_path)
	if error != OK:
		_status.text = "共享目录保存失败：" + error_string(error)
		return
	_shared_saved_fingerprint = _catalog_fingerprint()
	_update_catalog_label()
	_status.text = "共享目录已保存：" + _shared_path


func _apply_shared_fields() -> void:
	if _shared_catalog == null or _context == null or _stale:
		_status.text = "请先选择共享目录和有效资源。"
		return
	var selected: Array[GFAssetCatalogEntry] = _selected_entries()
	if selected.is_empty():
		return
	var entries: Array[GFAssetCatalogEntry] = []
	var selected_ids: Dictionary = {}
	for entry: GFAssetCatalogEntry in selected:
		selected_ids[entry.asset_id] = true
	for entry: GFAssetCatalogEntry in _shared_catalog.entries:
		if entry != null and not selected_ids.has(entry.asset_id):
			entries.append(entry.duplicate_entry())
	var tags: PackedStringArray = PackedStringArray()
	for raw_tag: String in _tags.text.replace("，", ",").split(",", false):
		var tag: String = raw_tag.strip_edges()
		if not tag.is_empty() and not tags.has(tag):
			var _appended: bool = tags.append(tag)
	for source_entry: GFAssetCatalogEntry in selected:
		var entry: GFAssetCatalogEntry = source_entry.duplicate_entry()
		entry.tags = tags.duplicate()
		entry.description = _notes.text
		entry.source_id = &"shared_catalog"
		entries.append(entry)
	if entries.size() > 10_000:
		_status.text = "共享目录超过 10,000 项，未修改。"
		return
	var command: _CATALOG_COMMAND_SCRIPT = _CATALOG_COMMAND_SCRIPT.new()
	command.configure_catalog(_shared_catalog, entries)
	var error: Error = _context.commit_command(command)
	if error != OK:
		_status.text = "共享字段修改失败：" + error_string(error)


func _disconnect_shared_catalog() -> void:
	if _shared_catalog != null and _shared_catalog.changed.is_connected(_on_shared_catalog_changed):
		_shared_catalog.changed.disconnect(_on_shared_catalog_changed)


func _catalog_fingerprint() -> int:
	var values: Array = []
	if _shared_catalog != null:
		for entry: GFAssetCatalogEntry in _shared_catalog.entries:
			if entry != null:
				values.append(entry.to_dict())
			else:
				values.append(null)
	return hash(values)


func _update_catalog_label() -> void:
	_catalog_label.text = "%s · %s" % [_shared_path, "未保存修改" if _catalog_fingerprint() != _shared_saved_fingerprint else "已保存"]


func _previous_page() -> void:
	_page = maxi(_page - 1, 1)
	_render_page()


func _next_page() -> void:
	_page = mini(_page + 1, maxi(_page_count, 1))
	_render_page()


# --- 信号处理函数 ---

func _on_source_completed(catalog: GFAssetCatalog, report: Dictionary) -> void:
	if not _can_update_view() or _sources.selected != 0:
		return
	if catalog == null:
		_project_snapshot_valid = false
		_set_stale(true)
		var status: String = GFVariantData.get_option_string(report, "status")
		_status.text = "资源范围超过 10,000 项，请缩小目录或类型；旧结果已过期。" if status == "capacity_exceeded" else "资源索引失败，旧结果已过期：" + status
		return
	_project_catalog = catalog
	_project_snapshot_valid = true
	_publish_catalog()


func _on_source_invalidated() -> void:
	_project_snapshot_valid = false
	_set_stale(true)
	_queue.pause()
	_queue.invalidate()
	_status.text = "Godot 资源索引已改变；预览与引用结果过期。"
	_details.text = "资源已变化，请重新选择后检查。"
	_schedule_refresh()


func _on_preview_ready(path: String, texture: Texture2D, generation: int) -> void:
	if generation != _preview_generation or _query_pending or _stale or not _can_update_view():
		return
	for index: int in range(_grid.item_count):
		if _grid.get_item_metadata(index) == path:
			if texture != null:
				_grid.set_item_icon(index, texture)
			else:
				_grid.set_item_tooltip(index, _grid.get_item_tooltip(index) + "\nGodot 暂无原生预览，显示资源类型图标。")


func _on_visibility_changed() -> void:
	if not _is_view_visible():
		_source.cancel()
		_queue.pause()
		_project_snapshot_valid = false
		_set_stale(true)
	else:
		_schedule_refresh()


func _on_scope_submitted(_text: String) -> void:
	_refresh()


func _on_addons_toggled(_pressed: bool) -> void:
	_refresh()


func _on_filter_selected(_index: int) -> void:
	_refresh()


func _on_collection_selected(_index: int) -> void:
	_page = 1
	_render_page()


func _on_search_changed(_text: String) -> void:
	_page = 1
	_render_page()
	_query_delay = 0.15


func _on_grid_selected(_index: int, _selected: bool) -> void:
	_clear_resource_actions()
	_refresh_resource_actions()
	var entries: Array[GFAssetCatalogEntry] = _selected_entries()
	if entries.is_empty():
		return
	var entry: GFAssetCatalogEntry = entries[0]
	_selected_id = entry.asset_id
	var _model_selected: bool = _model.select_asset(entry.asset_id)
	_details.text = JSON.stringify(entry.to_dict(), "  ")
	_tags.text = ", ".join(entry.tags)
	_notes.text = entry.description


func _on_grid_activated(_index: int) -> void:
	_open_selected()


func _on_catalog_path_selected(path: String, generation: int) -> void:
	if generation != _context_generation or not _can_update_view():
		return
	if not path.begins_with("res://") or path.contains("..") or path.contains("::") or path.get_extension().to_lower() != "tres":
		_status.text = "共享目录必须是项目内独立 .tres 文件。"
		return
	var catalog: GFAssetCatalog = null
	if _dialog_create:
		if FileAccess.file_exists(path):
			_status.text = "该文件已存在，请使用打开目录或选择新路径。"
			return
		catalog = GFAssetCatalog.new()
		var error: Error = ResourceSaver.save(catalog, path, ResourceSaver.FLAG_CHANGE_PATH)
		if error != OK:
			_status.text = "创建目录失败：" + error_string(error)
			return
		catalog.take_over_path(path)
	else:
		var resource: Resource = ResourceLoader.load(path)
		if resource is GFAssetCatalog:
			catalog = resource
	if catalog == null:
		_status.text = "所选资源不是 GFAssetCatalog。"
		return
	var validation_model: GFAssetBrowserModel = GFAssetBrowserModel.new()
	var report: Dictionary = validation_model.replace_catalog(catalog)
	validation_model.dispose()
	if not GFVariantData.get_option_bool(report, "ok"):
		_status.text = "目录无效：" + GFVariantData.get_option_string(report, "error")
		return
	_disconnect_shared_catalog()
	_shared_catalog = catalog
	_shared_path = path
	_shared_saved_fingerprint = _catalog_fingerprint()
	var _changed_connection: int = _shared_catalog.changed.connect(_on_shared_catalog_changed)
	_update_catalog_label()
	_publish_catalog()


func _on_shared_catalog_changed() -> void:
	_update_catalog_label()
	_publish_catalog()
