@tool

# 项目素材工作台。目录、缩略图、个人偏好与共享目录分别拥有生命周期。
extends VBoxContainer


# --- 常量 ---

## 构造与 Workspace 一致的页根、工具栏和详情控件。
## [br]
## @api private
const _UI_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")

## 创建从 Godot 已有文件索引分帧读取完整项目目录的子节点。
## [br]
## @api private
const _SOURCE_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_project_asset_source.gd")

## 创建限制原生预览并发并隔离视图代次的页面专用队列。
## [br]
## @api private
const _QUEUE_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_thumbnail_queue.gd")

## 创建能够按页面有效性禁用原生资源拖放的素材列表。
## [br]
## @api private
const _GRID_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_browser_grid.gd")

## 读写当前项目的个人编辑器偏好，收藏与最近使用不写入共享目录。
## [br]
## @api private
const _PREFERENCES_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_browser_preferences.gd")

## 创建独立源资源的表格编辑页，维护各资源的保存基线。
## [br]
## @api private
const _TABLES_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_resource_tables.gd")

## 将共享目录条目替换封装为宿主原生 Undo 命令；命令执行不隐式保存文件。
## [br]
## @api private
const _CATALOG_COMMAND_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_asset_catalog_edit_command.gd")

## 标注并校验页面所持的单次分页任务类型，页面负责取消后继续持有并回收其线程。
## [br]
## @api private
const _PAGE_QUERY_SCRIPT = preload("res://addons/gf/tools/asset_browser/gf_asset_browser_page_query.gd")

## 类型选项下标对应的 Godot 类型名；空字符串表示全部类型，顺序必须与界面标题一致。
## [br]
## @api private
const _TYPE_FILTERS: PackedStringArray = ["", "PackedScene", "Texture2D", "AudioStream", "Material", "Mesh", "Resource"]


# --- 私有变量 ---

## 宿主授予的编辑与资源交接能力；撤销时置空并使旧异步回调失效，保留尚未保存的内存草稿。
## [br]
## @api private
var _context: GFEditorToolContext = null

## 页面专用的目录与查询模型，提供版本核对和纯数据分页任务。
## [br]
## @api private
var _model: GFAssetBrowserModel = GFAssetBrowserModel.new()

## 页面树拥有的项目索引读取器；刷新、隐藏或撤销上下文时取消未发布的扫描。
## [br]
## @api private
var _source: _SOURCE_SCRIPT = _SOURCE_SCRIPT.new()

## 页面独占的预览请求与缓存队列；隐藏时暂停，文件变化时清缓存，撤销上下文时停止接收结果。
## [br]
## @api private
var _queue: _QUEUE_SCRIPT = _QUEUE_SCRIPT.new()

## 页面树拥有的素材卡片列表；旧卡片可暂留显示，资源动作须等待完整有效的新页。
## [br]
## @api private
var _grid: _GRID_SCRIPT = _GRID_SCRIPT.new()

## 页面树拥有的源资源表格；上下文撤销只停止编辑能力，不丢弃其未保存资源及保存基线。
## [br]
## @api private
var _tables: _TABLES_SCRIPT = _TABLES_SCRIPT.new()

## 最近一次完整成功扫描的项目目录；失效时可保留对象，但必须有有效快照标记才允许发布。
## [br]
## @api private
var _project_catalog: GFAssetCatalog = GFAssetCatalog.new()

## 用户显式打开或新建的共享目录原资源；编辑和 Undo 修改此对象，另行显式保存到磁盘。
## [br]
## @api private
var _shared_catalog: GFAssetCatalog = null

## 当前共享目录的独立项目文件路径，用于显式保存和项目条目的共享元数据来源标记。
## [br]
## @api private
var _shared_path: String = ""

## 共享目录加载或最近保存成功时的条目哈希；用于脏状态比较，不是可恢复的数据快照。
## [br]
## @api private
var _shared_saved_fingerprint: int = 0

## 最近发布给查询模型的视图目录，条目来自源目录副本；用卡片资产身份查回选择内容。
## [br]
## @api private
var _catalog: GFAssetCatalog = GFAssetCatalog.new()

## 当前项目个人偏好的内存状态，保存范围、类型、插件过滤及有界收藏和最近使用列表。
## [br]
## @api private
var _state: Dictionary = {}

## 请求页号，查询完成后改为报告夹取后的实际页号；刷新、搜索或集合切换回到第一页。
## [br]
## @api private
var _page: int = 1

## 最近一次完整页面报告的页数，用于翻页边界；新查询完成前翻页按钮禁用。
## [br]
## @api private
var _page_count: int = 0

## 当前整页预览订阅返回的视图代次，迟到的其他页预览不得更新卡片。
## [br]
## @api private
var _preview_generation: int = 0

## 目录快照已失效的标记；可保留旧显示，但禁止选择交接、拖放及基于旧目录的编辑。
## [br]
## @api private
var _stale: bool = true

## 项目索引是否已有本轮完整成功快照；刷新、隐藏、索引变化或上下文撤销都会清除。
## [br]
## @api private
var _project_snapshot_valid: bool = false

## 每次更换或释放宿主上下文时递增；查询、菜单和文件对话框据此拒绝旧能力授权下的回调。
## [br]
## @api private
var _context_generation: int = 0

## 合并同一轮多个刷新触发的延迟调用标记；执行前清除，再检查页面是否仍可刷新。
## [br]
## @api private
var _refresh_queued: bool = false

## 项目目录范围输入框，同时用于索引过滤与按需引用扫描范围。
## [br]
## @api private
var _scope: LineEdit = null

## 最多 512 字符的搜索输入框；文本变化触发延迟分页查询，不重新扫描项目文件索引。
## [br]
## @api private
var _search: LineEdit = null

## 与类型常量表同序的筛选选项；变更后重建项目扫描或共享目录视图。
## [br]
## @api private
var _types: OptionButton = null

## 选择项目索引或共享目录作为视图来源的控件，下标分别为零和一。
## [br]
## @api private
var _sources: OptionButton = null

## 全部、个人收藏、最近使用三种 ID 集合筛选，作用于已发布目录的分页查询。
## [br]
## @api private
var _collection: OptionButton = null

## 是否纳入 res://addons 资源的个人筛选选项，变更后重新刷新目录。
## [br]
## @api private
var _addons: CheckBox = null

## 展示扫描、查询、保存及交接结果的页面状态行，由各操作更新最近状态。
## [br]
## @api private
var _status: Label = null

## 整页卡片构建完成后显示实际页号、页数及查询结果数。
## [br]
## @api private
var _page_label: Label = null

## 显示共享目录路径及相对最近成功保存基线的脏状态。
## [br]
## @api private
var _catalog_label: Label = null

## 显示所选条目详情或按需引用扫描报告；查询开始和资源失效时提示旧内容不可继续使用。
## [br]
## @api private
var _details: TextEdit = null

## 待应用到所选资产的共享标签文本；应用时拆分中英文逗号并去除空项与重复项。
## [br]
## @api private
var _tags: LineEdit = null

## 待应用到所选资产的共享备注文本，不会因编辑输入框而自动修改或保存共享目录。
## [br]
## @api private
var _notes: LineEdit = null

## 页面树拥有的素材浏览与源资源表格页签容器。
## [br]
## @api private
var _tabs: TabContainer = null

## 页面按需创建的共享目录文件对话框；上下文变化时关闭并排队释放，选择回调绑定创建时的上下文代次。
## [br]
## @api private
var _catalog_dialog: EditorFileDialog = null

## 当前文件对话框是创建新目录还是加载已有目录；创建路径禁止覆盖现有文件。
## [br]
## @api private
var _dialog_create: bool = false

## 上一页动作按钮，查询期间禁用，整页完成后按实际页号恢复可用性。
## [br]
## @api private
var _previous_button: Button = null

## 下一页动作按钮，查询期间禁用，整页完成后按实际页数恢复可用性。
## [br]
## @api private
var _next_button: Button = null

## 显式保存共享目录的按钮；宿主上下文撤销时禁用，不触发源资源保存。
## [br]
## @api private
var _catalog_save_button: Button = null

## 接收工具提供的资源动作菜单；每次弹出重新按当前选择查询动作，撤销授权时清空。
## [br]
## @api private
var _resource_actions: MenuButton = null

## 最近构建动作菜单时的路径选择快照；点击时须与当前选择一致，防止向接收工具交接旧选择。
## [br]
## @api private
var _resource_menu_paths: PackedStringArray = PackedStringArray()

## 最近菜单构建所属的上下文代次，清空菜单时设为无效值。
## [br]
## @api private
var _resource_menu_context_generation: int = -1

## 菜单项持续递增的 ID，重建菜单不复用旧 ID，使迟到点击无法命中新动作。
## [br]
## @api private
var _resource_menu_next_id: int = 0

## 最近展示详情的首个所选资产身份；开始或完成新页时清空，实际多选身份仍由当前页卡片读取。
## [br]
## @api private
var _selected_id: StringName = &""

## 入树时连接可见性信号的宿主窗口引用，退树时断开；页面不拥有或释放窗口。
## [br]
## @api private
var _owner_window: Window = null

## 当前分帧分页任务；取消后若仍持有线程，转入待回收列表而不能直接丢弃。
## [br]
## @api private
var _page_query: _PAGE_QUERY_SCRIPT = null

## 已取消但尚未回收线程的任务强引用；每帧尝试非阻塞回收，退树时逐一等待结束。
## [br]
## @api private
var _retired_queries: Array[_PAGE_QUERY_SCRIPT] = []

## 从安排查询到整页卡片完成期间保持为真，覆盖输入延迟、线程评分和分批构卡阶段。
## [br]
## @api private
var _query_pending: bool = false

## 整页卡片已完成且未被取消的标记；与目录及上下文有效性共同决定是否允许读取资源选择。
## [br]
## @api private
var _page_ready: bool = false

## 搜索文本变化后的剩余防抖秒数；每帧扣减，取消查询时归零。
## [br]
## @api private
var _query_delay: float = 0.0

## 安排当前分页时捕获的宿主上下文代次；查询推进、构卡和完成时均核对授权未变化。
## [br]
## @api private
var _query_context_generation: int = -1

## 每次取消递增的页面操作序号；外部回调可能同步重入，返回后用它判断原流程是否已被替换。
## [br]
## @api private
var _query_serial: int = 0

## 最近一次任务推进的诊断快照；新查询清空，取消后保留以便显示该任务的失败原因。
## [br]
## @api private
var _query_progress: Dictionary = {}

## 已取回但尚未完成构卡的分页报告；含请求版本，构卡前和发布整页前再次核对。
## [br]
## @api private
var _card_report: Dictionary = {}

## 当前报告中与卡片下标同序的资产身份；页面完成后保留以解析多选，取消时清空。
## [br]
## @api private
var _card_ids: PackedStringArray = PackedStringArray()

## 与报告共享的页面摘要数组，供分批创建卡片；取消时换新数组，避免修改原报告容器。
## [br]
## @api private
var _card_items: Array = []

## 已构建卡片的资源路径序列；整页完成后一次提交预览订阅，取消时丢弃。
## [br]
## @api private
var _card_paths: PackedStringArray = PackedStringArray()

## 下一张待构建卡片的下标；每次接收新报告时归零，跨帧继续推进。
## [br]
## @api private
var _card_cursor: int = 0

## 本轮分页构卡单步的最大耗时，用于诊断卡片创建的帧预算。
## [br]
## @api private
var _peak_card_step_usec: int = 0


# --- Godot 生命周期方法 ---

## 构造页面控件并连接本页索引、预览和可见性信号；项目索引读取器作为子节点随页面管理。
## [br]
## @api private
func _init() -> void:
	name = "GFAssetBrowser"
	_UI_SCRIPT.apply_page_root(self)
	_build_ui()
	add_child(_source)
	var _complete_connection: int = _source.completed.connect(_on_source_completed)
	var _invalidated_connection: int = _source.invalidated.connect(_on_source_invalidated)
	var _preview_connection: int = _queue.preview_ready.connect(_on_preview_ready)
	var _visibility_connection: int = visibility_changed.connect(_on_visibility_changed)


## 入树后恢复个人范围与类型偏好，监听宿主窗口可见性，并在编辑器中接入原生预览服务和安排首次刷新。
## [br]
## @api private
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


## 先回收已取消任务，再按防抖、查询和构卡阶段分帧推进；旧线程未回收时不启动新的评分线程。
## 查询推进返回后核对操作序号，防止同步重入取消任务后继续使用旧结果。
## [br]
## @api private
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


## 撤销页面上下文并等待所有遗留评分线程回收，再断开共享目录及宿主窗口信号；不隐式保存草稿。
## [br]
## @api private
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

## 请求 Workspace 在贡献刷新时保留本页面及源资源保存基线，不隐式保存草稿。
## 贡献撤销时宿主只保留内存页并传入 null 上下文；精确恢复身份后重新授予编辑权限。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 源资源表或显式共享目录是否仍有未保存修改。
func has_unsaved_workspace_changes() -> bool:
	return _tables.has_unsaved_changes() or (_shared_catalog != null and _catalog_fingerprint() != _shared_saved_fingerprint)


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

## 建立素材浏览、资源表格和共享目录编辑控件，并将用户动作连接到页面处理函数；所有控件归页面树管理。
## [br]
## @api private
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


## 递增授权代次并停止查询、扫描和预览，关闭带旧上下文的菜单与对话框；保留共享目录和源资源的内存草稿。
## 取消后的线程仍由页面待回收列表持有，此处不阻塞等待。
## [br]
## @api private
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


## 隐藏并排队释放当前文件对话框，清除页面引用；已排队的选择回调另由上下文代次拦截。
## [br]
## @api private
func _close_catalog_dialog() -> void:
	if is_instance_valid(_catalog_dialog):
		_catalog_dialog.hide()
		_catalog_dialog.queue_free()
	_catalog_dialog = null


## 页面更新需同时处于编辑器、持有宿主授权且实际可见；目录及分页有效性由具体资源动作另行核对。
## [br]
## @api private
func _can_update_view() -> bool:
	return Engine.is_editor_hint() and _context != null and _is_view_visible()


## 同时检查页面入树、祖先可见性和所在窗口可见性，隐藏的 Workspace 窗口也视为不可见。
## [br]
## @api private
func _is_view_visible() -> bool:
	return is_inside_tree() and is_visible_in_tree() and get_window() != null and get_window().visible


## 更新目录失效标记；置为失效时取消分页，同时刷新拖放和资源交接菜单的可用性。
## [br]
## @api private
func _set_stale(value: bool) -> void:
	_stale = value
	if value:
		_cancel_page_query()
	_grid.set_resource_actions_enabled(not value and not _query_pending and _can_update_view())
	_clear_resource_actions()
	_refresh_resource_actions()


## 将连续的可见性或索引变化合并为一次延迟刷新，避免同一轮重复启动扫描。
## [br]
## @api private
func _schedule_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_run_queued_refresh.call_deferred()


## 消费延迟刷新标记，重新检查入树、控件可见性和上下文；已离开的页面不再刷新。
## [br]
## @api private
func _run_queued_refresh() -> void:
	_refresh_queued = false
	if is_inside_tree() and is_visible_in_tree() and _context != null:
		_refresh()


## 保存个人筛选状态并使旧目录、查询和预览失效；范围合法后重新扫描项目索引或发布已有共享目录。
## [br]
## @api private
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


## 从有效来源复制条目建立视图目录，按 UID 更新路径；项目视图仅叠加共享标签与备注，共享视图另按范围和类型过滤。
## 模型接受新目录后才发布页面并开始分页，不修改来源目录条目。
## [br]
## @api private
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


## 取消旧任务和选择资格，再为当前上下文安排分页；此处只进入待查询状态，实际工作由后续帧推进。
## [br]
## @api private
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


## 将搜索词和个人集合提交模型，再创建最多 100 项的页任务；空集合使用不存在的哨兵 ID，避免被当成全目录查询。
## 模型调用后重新核对取消序号和上下文，拒绝同步重入后失去资格的任务。
## [br]
## @api private
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


## 使本轮操作序号失效并取消任务；仍持有线程的任务移入回收列表，清空页数据并撤销预览和资源动作资格。
## 保留旧卡片显示及最近诊断，不在此处等待线程或清空源资源草稿。
## [br]
## @api private
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


## 逐帧非阻塞回收已取消且线程结束的任务；倒序移除确保未完成任务继续被页面强引用持有。
## [br]
## @api private
func _reap_queries() -> void:
	for index: int in range(_retired_queries.size() - 1, -1, -1):
		if _retired_queries[index].reap_worker():
			_retired_queries.remove_at(index)


## 页面报告须同时匹配当前宿主授权、模型目录修订和查询代次，且页面仍可见可更新。
## [br]
## @api private
func _is_page_report_current(report: Dictionary) -> bool:
	return _can_update_view() and _query_context_generation == _context_generation and _model.is_page_query_current(
		GFVariantData.get_option_int(report, "catalog_revision"), GFVariantData.get_option_int(report, "query_generation")
	)


## 在有效报告上每帧构建最多 16 张卡片，首项后按 2 毫秒预算停止；整页完成前不开放资源操作或提交预览。
## [br]
## @api private
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


## 再次核对报告后开放完整页面并订阅其预览；订阅调用返回后重查操作序号，防止重入后更新旧页状态。
## [br]
## @api private
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


## 丢弃菜单选择快照和上下文资格，隐藏并清空已有菜单项，阻止迟到点击沿用旧选择。
## [br]
## @api private
func _clear_resource_actions() -> void:
	_resource_menu_paths.clear()
	_resource_menu_context_generation = -1
	if _resource_actions == null:
		return
	_resource_actions.get_popup().hide()
	_resource_actions.get_popup().clear()
	_resource_actions.disabled = true


## 按当前可用路径重新向宿主查询接收动作，并记录本次选择和上下文；菜单 ID 持续递增，禁用不可用动作。
## [br]
## @api private
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


## 从完整有效页面的卡片资产 ID 解析当前多选条目；返回视图目录条目引用，不按路径去重或复制条目。
## [br]
## @api private
func _selected_entries() -> Array[GFAssetCatalogEntry]:
	var entries: Array[GFAssetCatalogEntry] = []
	if _stale or _query_pending or not _page_ready or not _can_update_view():
		return entries
	# 多个资产可以引用同一路径；选择身份来自本页卡片，路径去重仅用于原生资源动作。
	for index: int in _grid.get_selected_items():
		if index < 0 or index >= _card_ids.size():
			continue
		var entry: GFAssetCatalogEntry = _catalog.get_entry(StringName(_card_ids[index]))
		if entry != null:
			entries.append(entry)
	return entries


## 将当前范围、类型和插件开关合入个人偏好，并连同收藏与最近使用保存到项目编辑器元数据。
## [br]
## @api private
func _store_view_state() -> void:
	_state["scope"] = _scope.text
	_state["type_filter"] = _TYPE_FILTERS[_types.selected]
	_state["include_addons"] = _addons.button_pressed
	_PREFERENCES_SCRIPT.save_state(_state)


## 将此刻有效的页面多选记为最近使用；可能导致页面切换的交接路径需在调用前保存条目后另行记录。
## [br]
## @api private
func _record_recent() -> void:
	_record_recent_entries(_selected_entries())


## 将给定资产身份依次移到最近使用列表头并截取 100 项；按传入顺序插入，因此最后一项排在最前，随后持久化个人偏好。
## [br]
## @api private
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


## 验证当前首个资源路径仍存在后交给原生场景编辑器或 Inspector；打开前记录当前多选为最近使用。
## [br]
## @api private
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


## 在 Godot FileSystem 面板定位有效选择中的第一个资源路径，不加载或修改资源。
## [br]
## @api private
func _locate_selected() -> void:
	var paths: PackedStringArray = get_selected_resource_paths()
	if Engine.is_editor_hint() and not paths.is_empty():
		EditorInterface.get_file_system_dock().navigate_to_path(paths[0])


## 按资产身份逐项切换当前选择的个人收藏，新增不超过 1000 项；收藏筛选视图需重新分页反映变化。
## [br]
## @api private
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


## 将有效选择和当前宿主上下文交给源资源表格，并切换到表格页；具体路径准入与未保存修改保护由表格负责。
## [br]
## @api private
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


## 对唯一有效资源按需执行有界依赖与引用扫描，将证据和覆盖限制写入详情；未发现引用不能作为安全删除证明。
## [br]
## @api private
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


## 以创建模式打开共享目录路径选择，后续仅允许写入不存在的独立项目 .tres 文件。
## [br]
## @api private
func _create_catalog() -> void:
	_show_catalog_dialog(true)


## 以加载模式打开共享目录路径选择，后续校验资源类型与目录内容后才替换当前目录。
## [br]
## @api private
func _open_catalog() -> void:
	_show_catalog_dialog(false)


## 仅在页面有权限且当前共享目录无未保存修改时显示路径对话框；新建对话框的回调捕获当前上下文代次。
## [br]
## @api private
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


## 显式保存当前共享目录到已选路径，只有成功后才更新脏状态基线；不保存源素材或导入结果。
## [br]
## @api private
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


## 复制共享目录完整条目，仅替换所选资产的标签与备注，并补入尚未共享的所选条目；超过容量时整次拒绝。
## 通过宿主 Undo 命令提交内存修改，保留原共享标题、预览及自定义元数据，保存文件需另行触发。
## [br]
## @api private
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
	var tags: PackedStringArray = PackedStringArray()
	for raw_tag: String in _tags.text.replace("，", ",").split(",", false):
		var tag: String = raw_tag.strip_edges()
		if not tag.is_empty() and not tags.has(tag):
			var _appended: bool = tags.append(tag)
	# 共享目录拥有完整条目；项目视图只是投影，不能覆盖其标题、预览或自定义元数据。
	var existing_ids: Dictionary = {}
	for shared_entry: GFAssetCatalogEntry in _shared_catalog.entries:
		if shared_entry == null:
			continue
		var entry: GFAssetCatalogEntry = shared_entry.duplicate_entry()
		existing_ids[entry.asset_id] = true
		if selected_ids.has(entry.asset_id):
			entry.tags = tags.duplicate()
			entry.description = _notes.text
		entries.append(entry)
	for source_entry: GFAssetCatalogEntry in selected:
		if existing_ids.has(source_entry.asset_id):
			continue
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


## 断开当前共享目录的页面变更监听，供切换目录或退树使用；不释放目录引用、不保存或撤销修改。
## [br]
## @api private
func _disconnect_shared_catalog() -> void:
	if _shared_catalog != null and _shared_catalog.changed.is_connected(_on_shared_catalog_changed):
		_shared_catalog.changed.disconnect(_on_shared_catalog_changed)


## 按条目顺序对共享目录的序列化字典计算哈希，保留空条目位置；仅作为脏状态判据，不保存可恢复副本。
## [br]
## @api private
func _catalog_fingerprint() -> int:
	var values: Array = []
	if _shared_catalog != null:
		for entry: GFAssetCatalogEntry in _shared_catalog.entries:
			if entry != null:
				values.append(entry.to_dict())
			else:
				values.append(null)
	return hash(values)


## 以共享目录当前条目哈希和最近成功保存基线比较，更新路径旁的已保存或未保存提示。
## [br]
## @api private
func _update_catalog_label() -> void:
	_catalog_label.text = "%s · %s" % [_shared_path, "未保存修改" if _catalog_fingerprint() != _shared_saved_fingerprint else "已保存"]


## 将请求页号减一但不低于第一页，并取消旧页后安排新分页。
## [br]
## @api private
func _previous_page() -> void:
	_page = maxi(_page - 1, 1)
	_render_page()


## 将请求页号加一但不超过最近已知页数，并安排重新分页；最终页号由新报告再次夹取。
## [br]
## @api private
func _next_page() -> void:
	_page = mini(_page + 1, maxi(_page_count, 1))
	_render_page()


# --- 信号处理函数 ---

## 核对菜单 ID、上下文及选择仍有效后交接资源；调用前独立保存选择，因为接收工具导航可能同步隐藏本页。
## 返回后仅在上下文代次未变化时记录成功交接的最近使用项并更新提示。
## [br]
## @api private
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


## 仅在仍显示项目来源且页面可更新时接受扫描；失败保持旧目录失效，完整成功目录才获得发布资格。
## [br]
## @api private
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


## 原生文件索引变化后撤销项目快照及资源动作资格，清除预览内容缓存与旧引用提示，并合并安排刷新。
## [br]
## @api private
func _on_source_invalidated() -> void:
	_project_snapshot_valid = false
	_set_stale(true)
	_queue.pause()
	_queue.invalidate()
	_status.text = "Godot 资源索引已改变；预览与引用结果过期。"
	_details.text = "资源已变化，请重新选择后检查。"
	_schedule_refresh()


## 只接收当前有效整页的预览代次，更新所有引用该路径的卡片；原生预览为空时保留类型图标并补充提示。
## [br]
## @api private
func _on_preview_ready(path: String, texture: Texture2D, generation: int) -> void:
	if generation != _preview_generation or _query_pending or _stale or not _can_update_view():
		return
	for index: int in range(_grid.item_count):
		if _grid.get_item_metadata(index) == path:
			if texture != null:
				_grid.set_item_icon(index, texture)
			else:
				_grid.set_item_tooltip(index, _grid.get_item_tooltip(index) + "\nGodot 暂无原生预览，显示资源类型图标。")


## 页面或宿主窗口隐藏时取消索引、分页和预览订阅并撤销快照资格；重新显示时安排完整刷新。
## [br]
## @api private
func _on_visibility_changed() -> void:
	if not _is_view_visible():
		_source.cancel()
		_queue.pause()
		_project_snapshot_valid = false
		_set_stale(true)
	else:
		_schedule_refresh()


## 范围输入确认后从控件读取当前筛选并重新刷新目录，沿用统一范围校验。
## [br]
## @api private
func _on_scope_submitted(_text: String) -> void:
	_refresh()


## 插件资源开关变化后重新扫描或发布目录，使旧快照不能继续用于资源动作。
## [br]
## @api private
func _on_addons_toggled(_pressed: bool) -> void:
	_refresh()


## 资源来源或类型选项变化后重走目录刷新，共用控件当前值而不依赖信号参数。
## [br]
## @api private
func _on_filter_selected(_index: int) -> void:
	_refresh()


## 切换全部、收藏或最近使用集合时回到第一页，只重做查询，不重新读取项目文件索引。
## [br]
## @api private
func _on_collection_selected(_index: int) -> void:
	_page = 1
	_render_page()


## 搜索文本变化立即撤销旧选择并回到第一页，再等待 150 毫秒无新输入后启动查询。
## [br]
## @api private
func _on_search_changed(_text: String) -> void:
	_page = 1
	_render_page()
	_query_delay = 0.15


## 多选变化后重建资源交接菜单，并用有效选择中的首个条目更新模型选择、详情及共享字段输入框。
## [br]
## @api private
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


## 卡片激活复用当前有效选择的原生打开流程，不绕过路径存在性和页面资格检查。
## [br]
## @api private
func _on_grid_activated(_index: int) -> void:
	_open_selected()


## 拒绝旧上下文和非独立项目 .tres 路径；创建时禁止覆盖，加载后以临时模型校验目录内容。
## 通过校验才切换共享目录、建立保存基线及变更监听，并重新发布视图。
## [br]
## @api private
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


## 共享目录编辑或 Undo 发出变更时更新脏状态并重建视图，不隐式保存目录文件。
## [br]
## @api private
func _on_shared_catalog_changed() -> void:
	_update_catalog_label()
	_publish_catalog()
